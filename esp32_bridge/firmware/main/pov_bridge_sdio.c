/* pov_bridge_sdio.c — ESP32-C5 WiFi-to-SDIO bridge for POV3D streaming.
 *
 * Replaces the UART transport in pov_bridge.c with an SDIO slave interface.
 * Architecture:
 *
 *   [Host PC] --TCP:8888--> [ESP32-C5 WiFi STA] --SDIO 4-bit--> [Zynq SD0]
 *
 * - WiFi STA (same as pov_bridge.c, identical TCP server on :8888).
 * - mDNS: "pov-bridge.local" still advertised.
 * - Data from TCP socket is queued into SDIO slave TX FIFO (host->ESP32 from
 *   the SDIO point-of-view becomes ESP32->Zynq once Zynq pulls it via SDIO
 *   CMD53 block read).
 * - Data from SDIO slave RX FIFO (Zynq->ESP32, written by Zynq SDIO CMD53
 *   block write) is currently dropped on the WiFi side (no upstream channel
 *   used by POV3D yet, but we drain it to log frame ACKs / debug).
 *
 * SDIO block size: 512 B (standard SDIO). The PWFR 24B header + payload is
 * not interpreted here — the bridge is byte-transparent like the UART version.
 *
 * ESP32-C5 SDIO slave fixed IOMUX pins (验证: IDF v6.1
 * components/esp_hal_sd/esp32c5/include/soc/sdio_slave_pins.h, 与早期注释相反):
 *   CLK  = GPIO9
 *   CMD  = GPIO10   (注: 此前注释错写 GPIO8, 焊线必须按 GPIO10)
 *   D0   = GPIO8    (注: 此前注释错写 GPIO10)
 *   D1   = GPIO7
 *   D2   = GPIO14
 *   D3   = GPIO13
 * These do NOT conflict with the user-mentioned GPIO4/5 (free general IO on
 * ESP32-C5 with no strapping role). Strapping pin GPIO27 controls boot mode
 * only.
 *
 * Build with ESP-IDF v5.3+ (which adds ESP32-C5 SDIO slave support).
 */

#include <stdio.h>
#include <string.h>
#include "lwip/sockets.h"
#include "lwip/inet.h"
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include "freertos/stream_buffer.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_wifi.h"
#include "esp_system.h"
#include "esp_timer.h"
#include "nvs_flash.h"
#include "miniz.h"      /* ROM-resident: tinfl_decompress_mem_to_mem */
#include "driver/sdio_slave.h"
#include "driver/gpio.h"
#include "lwip/err.h"
#include "mdns.h"

#define WIFI_SSID          CONFIG_POV_WIFI_SSID
#define WIFI_PASS          CONFIG_POV_WIFI_PASSWORD
#define LISTEN_PORT        8888

/* SDIO slave configuration */
#define SDIO_BLOCK_SIZE    512
#define SDIO_TX_BUF_NUM    128    /* 128 * 512 = 64 KB TX ring (ESP -> Zynq);
                                   * 旧 8KB 限制 Zynq 一次 chunk drain ≤8KB → throughput cap */
#define SDIO_RX_BUF_NUM    8      /* 8  * 512 = 4 KB RX ring (Zynq -> ESP) */
#define SDIO_RX_BUF_SIZE   512

static const char *TAG = "pov_bridge_sdio";

/* ------------------------------------------------------------------ */
/* WiFi event handler                                                 */
/* ------------------------------------------------------------------ */
static EventGroupHandle_t s_wifi_event_group;
#define WIFI_CONNECTED_BIT BIT0

static void wifi_event_handler(void *arg, esp_event_base_t event_base,
                               int32_t event_id, void *event_data) {
    if (event_base == WIFI_EVENT) {
        if (event_id == WIFI_EVENT_STA_START) {
            vTaskDelay(pdMS_TO_TICKS(2000));   /* let AP scan-respond settle */
            esp_wifi_connect();
        } else if (event_id == WIFI_EVENT_STA_DISCONNECTED) {
            wifi_event_sta_disconnected_t *d = (wifi_event_sta_disconnected_t *)event_data;
            xEventGroupClearBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
            ESP_LOGW(TAG, "WiFi disconnected reason=%d, retrying in 5s", d->reason);
            vTaskDelay(pdMS_TO_TICKS(5000));   /* longer cooldown to avoid AP rate-limit */
            esp_wifi_connect();
        }
    } else if (event_base == IP_EVENT && event_id == IP_EVENT_STA_GOT_IP) {
        ip_event_got_ip_t *event = (ip_event_got_ip_t *)event_data;
        ESP_LOGI(TAG, "Got IP: " IPSTR, IP2STR(&event->ip_info.ip));
        xEventGroupSetBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
    }
}

static void wifi_init_sta(void) {
    s_wifi_event_group = xEventGroupCreate();
    ESP_ERROR_CHECK(esp_netif_init());
    ESP_ERROR_CHECK(esp_event_loop_create_default());
    esp_netif_create_default_wifi_sta();
    /* DHCP enabled by default - with 5G HT40 + WPA2 strict, handshake completes
     * cleanly so DHCP-OFFER/REQUEST/ACK lands. Remove static IP hack. */

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL);
    esp_event_handler_register(IP_EVENT,   IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL);

    wifi_config_t wifi_config = {
        .sta = {
            .ssid = WIFI_SSID,
            .password = WIFI_PASS,
            .threshold.authmode = WIFI_AUTH_WPA_WPA2_PSK,
            .pmf_cfg = { .capable = true, .required = false },
            .listen_interval = 1,
            .channel = 149,            /* 5G BSSID hint, iperf 验证可连 */
            .scan_method = WIFI_ALL_CHANNEL_SCAN,
        },
    };
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());
    /* 5G HT40 via 11n only — measured ~30 Mbps TCP vs ~15 Mbps on 2.4G HT20.
     * Must be set AFTER esp_wifi_start; plural API required for BAND_AUTO/5G_ONLY. */
    esp_wifi_set_protocols(WIFI_IF_STA, &(wifi_protocols_t){
        .ghz_2g = WIFI_PROTOCOL_11B | WIFI_PROTOCOL_11G | WIFI_PROTOCOL_11N,
        .ghz_5g = WIFI_PROTOCOL_11A | WIFI_PROTOCOL_11N,
    });
    esp_wifi_set_bandwidths(WIFI_IF_STA, &(wifi_bandwidths_t){
        .ghz_2g = WIFI_BW40,
        .ghz_5g = WIFI_BW40,
    });
    esp_wifi_set_ps(WIFI_PS_NONE);
    esp_wifi_set_band_mode(WIFI_BAND_MODE_5G_ONLY);
    ESP_LOGI(TAG, "WiFi STA started (5G HT40, 11n only, WPA_WPA2, PMF cap)");
}

/* Periodically log link details: RSSI, PHY mode, rate. Called after STA
 * GOT_IP so all rate-info is settled. */
static void log_wifi_link(void) {
    wifi_ap_record_t ap;
    if (esp_wifi_sta_get_ap_info(&ap) == ESP_OK) {
        ESP_LOGI(TAG, "AP link: ssid=%s rssi=%d ch=%u phy_11ax=%d 11n=%d",
                 (const char *)ap.ssid, ap.rssi, ap.primary,
                 ap.phy_11ax ? 1 : 0, ap.phy_11n ? 1 : 0);
    }
}

/* ------------------------------------------------------------------ */
/* mDNS — advertise pov-bridge.local                                  */
/* ------------------------------------------------------------------ */
static void start_mdns(void) {
    mdns_init();
    mdns_hostname_set("pov-bridge");
    mdns_instance_name_set("POV3D bridge (SDIO)");
    mdns_service_add(NULL, "_povbridge", "_tcp", LISTEN_PORT, NULL, 0);
    ESP_LOGI(TAG, "mDNS: pov-bridge.local:%d", LISTEN_PORT);
}

/* ------------------------------------------------------------------ */
/* SDIO slave init                                                    */
/* ------------------------------------------------------------------ */

/* RX buffer pool (Zynq -> ESP32 direction).
 * sdio_slave wants the user to register buffers ahead of time; the driver
 * fills them as the host (Zynq) writes blocks.
 * DMA_ATTR: buffers must be DMA-accessible (per IDF example).
 */
#include "esp_attr.h"
DMA_ATTR static uint8_t sdio_rx_pool[SDIO_RX_BUF_NUM][SDIO_RX_BUF_SIZE];

static esp_err_t sdio_slave_setup(void) {
    /* Match IDF v6 SDIO slave example as closely as possible.
     * The example IS proven to work with Zynq host @ divisor=0xFF. */
    sdio_slave_config_t scfg = {
        .sending_mode    = SDIO_SLAVE_SEND_PACKET,
        .send_queue_size = SDIO_TX_BUF_NUM,
        .recv_buffer_size = SDIO_RX_BUF_SIZE,
        .event_cb        = NULL,
        /* Internal pullups for flying-wire setup (no external 10k pullups). */
        .flags           = SDIO_SLAVE_FLAG_INTERNAL_PULLUP,
    };
    esp_err_t err = sdio_slave_initialize(&scfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "sdio_slave_initialize: %s", esp_err_to_name(err));
        return err;
    }

    /* IDF example writes register 0 — possibly required for slave readiness */
    sdio_slave_write_reg(0, 0);

    /* Register RX buffers — driver will fill them as host writes blocks. */
    for (int i = 0; i < SDIO_RX_BUF_NUM; ++i) {
        sdio_slave_buf_handle_t h = sdio_slave_recv_register_buf(sdio_rx_pool[i]);
        if (h == NULL) {
            ESP_LOGE(TAG, "recv_register_buf #%d failed", i);
            return ESP_FAIL;
        }
        ESP_ERROR_CHECK(sdio_slave_recv_load_buf(h));
    }

    /* Enable all 8 host interrupt bits like IDF example */
    sdio_slave_set_host_intena(SDIO_SLAVE_HOSTINT_SEND_NEW_PACKET
                               | SDIO_SLAVE_HOSTINT_BIT0
                               | SDIO_SLAVE_HOSTINT_BIT1
                               | SDIO_SLAVE_HOSTINT_BIT2
                               | SDIO_SLAVE_HOSTINT_BIT3
                               | SDIO_SLAVE_HOSTINT_BIT4
                               | SDIO_SLAVE_HOSTINT_BIT5
                               | SDIO_SLAVE_HOSTINT_BIT6
                               | SDIO_SLAVE_HOSTINT_BIT7);

    err = sdio_slave_start();
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "sdio_slave_start: %s", esp_err_to_name(err));
        return err;
    }
    ESP_LOGI(TAG, "SDIO slave started (block %d, TX %d bufs, RX %d bufs)",
             SDIO_BLOCK_SIZE, SDIO_TX_BUF_NUM, SDIO_RX_BUF_NUM);
    return ESP_OK;
}

/* Send to SDIO master (Zynq) via send_queue (non-blocking). Multiple packets
 * fly in parallel; queue size = SDIO_TX_BUF_NUM. We drain finished entries
 * before queuing more. Larger packets (up to 4092B) saturate fewer slots. */
/* Non-blocking send_queue with small pool (8 × 2048 = 16 KB) — keeps
 * SDIO TX overlapping with WiFi RX, while leaving heap room for DFLT
 * decompressor (32 KB dict + ~11 KB state). */
#define SDIO_TX_PACKET   2048
#define SDIO_TX_POOL_N   8

/* Dual-task pipeline: server_task (recv from TCP) → sdio_stream (StreamBuffer)
 * → sdio_drain_task (alignment + sdio_tx_bytes). 取代 single-thread serialize
 * recv+tx cap ~100 KB/s, 让 recv 不被 sdio_tx 阻塞.
 *
 * Stream buffer size 128 KB: 跟 ESP32 SDIO TX ring 64KB + 一帧 30K compressed
 * 150KB 同量级, 一帧能基本 fit. recv_task push 满 stream → block on send;
 * 仍是 backpressure 但 decoupled from sdio_tx 实际推送时间. */
static StreamBufferHandle_t sdio_stream = NULL;
#define SDIO_STREAM_SIZE   (32 * 1024)  /* heap tight (ESP32-C5 173KB free); 32KB fits + 一帧 30K compressed=150KB 时 PC sendall backpressure 自动调度 */
#define SDIO_STREAM_TRIG   512  /* xStreamBufferReceive wakes when ≥ this many bytes */

static int sdio_tx_bytes(const uint8_t *buf, size_t len) {
    static uint8_t tx_pool[SDIO_TX_POOL_N][SDIO_TX_PACKET] __attribute__((aligned(4)));
    static int     tx_idx = 0;
    void *finished_arg;
    size_t remaining = len;
    const uint8_t *p = buf;
    while (remaining) {
        size_t chunk = remaining > SDIO_TX_PACKET ? SDIO_TX_PACKET : remaining;
        (void)sdio_slave_send_get_finished(&finished_arg, 0);
        memcpy(tx_pool[tx_idx], p, chunk);
        esp_err_t err = sdio_slave_send_queue(tx_pool[tx_idx], chunk,
                                              (void *)(uintptr_t)tx_idx,
                                              portMAX_DELAY);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "send_queue: %s", esp_err_to_name(err));
            return -1;
        }
        tx_idx = (tx_idx + 1) % SDIO_TX_POOL_N;
        p         += chunk;
        remaining -= chunk;
    }
    while (sdio_slave_send_get_finished(&finished_arg, 0) == ESP_OK) { }
    return (int)len;
}

/* ------------------------------------------------------------------ */
/* SDIO drain task: pop bytes from sdio_stream, accumulate to 512B    */
/* multiple in pass_buf, sdio_tx_bytes. Decouples recv (server_task)  */
/* from SDIO push, so PC TCP can sustain WiFi link speed while SDIO   */
/* drains at its own pace into 64KB ring buffer.                      */
/* ------------------------------------------------------------------ */
static void sdio_drain_task(void *pv) {
    static uint8_t scratch[8192];   /* read chunks from stream */
    static uint8_t pass_buf[8192];  /* 512B alignment buffer */
    size_t pass_pos = 0;
    ESP_LOGI(TAG, "sdio_drain_task started");
    while (1) {
        size_t n = xStreamBufferReceive(sdio_stream, scratch, sizeof(scratch),
                                        pdMS_TO_TICKS(100));
        if (n == 0) {
            /* Timeout — flush whatever 512-multiple we have */
            if (pass_pos >= 512) {
                size_t aligned = (pass_pos / 512) * 512;
                sdio_tx_bytes(pass_buf, aligned);
                size_t left = pass_pos - aligned;
                if (left > 0 && aligned < sizeof(pass_buf))
                    memmove(pass_buf, pass_buf + aligned, left);
                pass_pos = left;
            }
            continue;
        }
        /* Append n bytes to pass_buf, flush 512-multiples eagerly */
        size_t src_off = 0;
        while (src_off < n) {
            size_t cap = sizeof(pass_buf) - pass_pos;
            size_t take = n - src_off;
            if (take > cap) take = cap;
            if (take == 0) break;
            memcpy(pass_buf + pass_pos, scratch + src_off, take);
            pass_pos += take;
            src_off += take;
            if (pass_pos >= sizeof(pass_buf)) {
                size_t aligned = (pass_pos / 512) * 512;
                sdio_tx_bytes(pass_buf, aligned);
                size_t left = pass_pos - aligned;
                if (left > 0 && aligned > 0 && aligned < sizeof(pass_buf))
                    memmove(pass_buf, pass_buf + aligned, left);
                pass_pos = left;
            }
        }
        /* Eager flush of complete 512-blocks while still > 512 in pass_buf */
        if (pass_pos >= 512) {
            size_t aligned = (pass_pos / 512) * 512;
            sdio_tx_bytes(pass_buf, aligned);
            size_t left = pass_pos - aligned;
            if (left > 0 && aligned > 0 && aligned < sizeof(pass_buf))
                memmove(pass_buf, pass_buf + aligned, left);
            pass_pos = left;
        }
    }
}

/* ------------------------------------------------------------------ */
/* SDIO RX drain task (Zynq -> ESP32). Logs payload, currently unused */
/* upstream by POV3D protocol but useful for ACK / debug.             */
/* ------------------------------------------------------------------ */
static void sdio_rx_task(void *pv) {
    sdio_slave_buf_handle_t h;
    size_t recv_len;
    uint8_t *ptr;
    while (1) {
        esp_err_t err = sdio_slave_recv(&h, &ptr, &recv_len, portMAX_DELAY);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "sdio_slave_recv: %s", esp_err_to_name(err));
            continue;
        }
        ESP_LOGD(TAG, "SDIO RX %u B from host", (unsigned)recv_len);
        /* Re-arm buffer so driver can refill. */
        sdio_slave_recv_load_buf(h);
    }
}

/* ------------------------------------------------------------------ */
/* TCP server  (host PC -> ESP32 -> SDIO -> Zynq)                     */
/* ------------------------------------------------------------------ */
static void server_task(void *pv) {
    /* Big RX buf so a single recv() pulls a large chunk from lwIP socket buf,
     * cutting per-iter recv+sdio_tx serialization overhead. 32KB matches typical
     * TCP window scale + ESP32 SDIO TX ring (64KB) so one cycle fills half ring. */
    static uint8_t rx_buf[32768];

    /* Standard TCP server: listen on LISTEN_PORT for incoming connections from PC. */
    while (1) {
        ESP_LOGI(TAG, "server_task: creating socket...");
        int listen_fd = socket(AF_INET, SOCK_STREAM, 0);
        if (listen_fd < 0) {
            ESP_LOGE(TAG, "socket: %d", errno);
            vTaskDelay(pdMS_TO_TICKS(2000));
            continue;
        }
        int reuse = 1;
        setsockopt(listen_fd, SOL_SOCKET, SO_REUSEADDR, &reuse, sizeof(reuse));
        struct sockaddr_in addr = {0};
        addr.sin_family = AF_INET;
        addr.sin_addr.s_addr = htonl(INADDR_ANY);
        addr.sin_port = htons(LISTEN_PORT);
        if (bind(listen_fd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
            ESP_LOGE(TAG, "bind: %d", errno);
            close(listen_fd);
            vTaskDelay(pdMS_TO_TICKS(2000));
            continue;
        }
        listen(listen_fd, 1);
        ESP_LOGI(TAG, "TCP listening on :%d (accept blocking)", LISTEN_PORT);

        struct sockaddr_in cli;
        socklen_t cl = sizeof(cli);
        int client_fd = accept(listen_fd, (struct sockaddr *)&cli, &cl);
        if (client_fd < 0) {
            ESP_LOGW(TAG, "accept failed errno=%d", errno);
            close(listen_fd);
            continue;
        }
        { uint8_t *ip = (uint8_t *)&cli.sin_addr.s_addr; ESP_LOGI(TAG, "client connected: %u.%u.%u.%u", ip[0], ip[1], ip[2], ip[3]); }

        /* Disable Nagle to reduce latency */
        int nodelay = 1;
        setsockopt(client_fd, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));

        size_t total = 0;
        /* Modes: SINK (discard), DFLT (streaming zlib-inflate → SDIO), default = pass-thru. */
        int sink_mode = 0;
        int dflt_mode = 0;
        uint32_t dflt_clen = 0, dflt_ulen = 0;
        size_t   dflt_got = 0, dflt_sent = 0;
        tinfl_decompressor *dflt_dec = NULL;
        uint8_t *dflt_dict = NULL;   /* TINFL_LZ_DICT_SIZE rolling window */
        size_t   dflt_dict_pos = 0;
        /* Pending-flush buffer: accumulate inflate output to 512B-multiples
         * before sdio_tx_bytes — slave pads non-aligned writes with zeros,
         * corrupting the PMSH stream. */
        static uint8_t dflt_flush_buf[4096];
        size_t dflt_flush_pos = 0;
        int64_t t_first_us = esp_timer_get_time();
        int64_t t_last_log_us = t_first_us;
        for (;;) {
            int n = recv(client_fd, rx_buf, sizeof(rx_buf), 0);
            if (n <= 0) break;
            const uint8_t *p = rx_buf;
            int rem = n;

            /* Detect mode on first bytes of stream. */
            /* Mode detection: any time we're idle (no active inflate or sink),
             * try to parse magic header on incoming bytes. Removed `total==0`
             * gate — multiple DFLT frames in one TCP stream need re-detect
             * after each frame boundary. */
            if (!sink_mode && !dflt_mode && rem >= 4) {
                if (p[0]=='S' && p[1]=='I' && p[2]=='N' && p[3]=='K') {
                    sink_mode = 1; p += 4; rem -= 4;
                    ESP_LOGW(TAG, "SINK mode");
                } else if (rem >= 12 && p[0]=='D' && p[1]=='F' && p[2]=='L' && p[3]=='T') {
                    dflt_clen = (uint32_t)p[4] | ((uint32_t)p[5]<<8)
                              | ((uint32_t)p[6]<<16) | ((uint32_t)p[7]<<24);
                    dflt_ulen = (uint32_t)p[8] | ((uint32_t)p[9]<<8)
                              | ((uint32_t)p[10]<<16) | ((uint32_t)p[11]<<24);
                    /* Streaming inflate: alloc decompressor + 32KB dict. */
                    dflt_dec  = malloc(sizeof(tinfl_decompressor));
                    dflt_dict = malloc(TINFL_LZ_DICT_SIZE);
                    if (!dflt_dec || !dflt_dict) {
                        ESP_LOGW(TAG, "DFLT alloc fail (dec=%p dict=%p free=%u)",
                                 dflt_dec, dflt_dict,
                                 (unsigned)esp_get_free_heap_size());
                        free(dflt_dec); free(dflt_dict);
                        dflt_dec = NULL; dflt_dict = NULL;
                        break;
                    }
                    tinfl_init(dflt_dec);
                    dflt_dict_pos = 0; dflt_got = 0; dflt_sent = 0;
                    ESP_LOGI(TAG, "DFLT detect: clen=%u ulen=%u free=%u",
                             (unsigned)dflt_clen, (unsigned)dflt_ulen,
                             (unsigned)esp_get_free_heap_size());
                    dflt_mode = 1;
                    p += 12; rem -= 12;
                }
            }

            if (dflt_mode) {
                /* Streaming inflate: feed `rem` compressed bytes, drain output. */
                while (rem > 0) {
                    size_t in_consumed = rem;
                    size_t out_remain = TINFL_LZ_DICT_SIZE - dflt_dict_pos;
                    uint32_t flags = TINFL_FLAG_PARSE_ZLIB_HEADER
                                   | TINFL_FLAG_HAS_MORE_INPUT;
                    /* If this is the final byte of compressed stream, don't set HAS_MORE */
                    if (dflt_got + rem >= dflt_clen) flags &= ~TINFL_FLAG_HAS_MORE_INPUT;
                    tinfl_status st = tinfl_decompress(dflt_dec,
                            p, &in_consumed,
                            dflt_dict, dflt_dict + dflt_dict_pos, &out_remain,
                            flags);
                    if (out_remain > 0) {
                        /* Append to flush buf; send 512B-multiples to keep
                         * SDIO slave from padding mid-stream. */
                        size_t src_pos = 0;
                        while (src_pos < out_remain) {
                            size_t take = out_remain - src_pos;
                            if (take > sizeof(dflt_flush_buf) - dflt_flush_pos)
                                take = sizeof(dflt_flush_buf) - dflt_flush_pos;
                            memcpy(dflt_flush_buf + dflt_flush_pos,
                                   dflt_dict + dflt_dict_pos + src_pos, take);
                            dflt_flush_pos += take;
                            src_pos += take;
                            /* Flush whenever buf has full 512B blocks AND is full
                             * (or near full to make progress). */
                            if (dflt_flush_pos >= sizeof(dflt_flush_buf)) {
                                size_t aligned = (dflt_flush_pos / 512) * 512;
                                sdio_tx_bytes(dflt_flush_buf, aligned);
                                dflt_sent += aligned;
                                size_t left = dflt_flush_pos - aligned;
                                memmove(dflt_flush_buf, dflt_flush_buf + aligned, left);
                                dflt_flush_pos = left;
                            }
                        }
                        dflt_dict_pos = (dflt_dict_pos + out_remain) % TINFL_LZ_DICT_SIZE;
                    }
                    p += in_consumed;
                    rem -= in_consumed;
                    dflt_got += in_consumed;
                    if (st <= TINFL_STATUS_DONE) {
                        if (st < TINFL_STATUS_DONE) {
                            ESP_LOGW(TAG, "tinfl FAIL st=%d got=%u sent=%u",
                                     (int)st, (unsigned)dflt_got, (unsigned)dflt_sent);
                        } else {
                            /* Pad final tail to 512B and flush */
                            if (dflt_flush_pos > 0) {
                                size_t padded = ((dflt_flush_pos + 511) / 512) * 512;
                                memset(dflt_flush_buf + dflt_flush_pos, 0, padded - dflt_flush_pos);
                                sdio_tx_bytes(dflt_flush_buf, padded);
                                dflt_sent += padded;
                                dflt_flush_pos = 0;
                            }
                            ESP_LOGI(TAG, "DFLT done %u→%u",
                                     (unsigned)dflt_got, (unsigned)dflt_sent);
                        }
                        free(dflt_dec); free(dflt_dict);
                        dflt_dec = NULL; dflt_dict = NULL;
                        dflt_mode = 0; dflt_got = 0; total = 0;
                        break;
                    }
                    if (st == TINFL_STATUS_NEEDS_MORE_INPUT && in_consumed == 0) break;
                }
            } else if (!sink_mode && rem > 0) {
                /* Dual-task: push to sdio_stream, sdio_drain_task handles
                 * alignment + sdio_tx_bytes. Decouples recv from SDIO push.
                 * Block if stream buffer full (= backpressure to TCP).
                 * Null fallback: stream-buffer alloc failed → direct sdio_tx. */
                if (sdio_stream) {
                    size_t sent_b = 0;
                    while (sent_b < (size_t)rem) {
                        size_t n2 = xStreamBufferSend(sdio_stream,
                                                      p + sent_b, (size_t)rem - sent_b,
                                                      pdMS_TO_TICKS(500));
                        if (n2 == 0) {
                            ESP_LOGW(TAG, "sdio_stream send timeout (%u left)",
                                     (unsigned)((size_t)rem - sent_b));
                            break;
                        }
                        sent_b += n2;
                    }
                } else {
                    /* Fallback: single-task direct sdio_tx with alignment */
                    static uint8_t pass_buf[8192];
                    static size_t  pass_pos = 0;
                    size_t src_off = 0;
                    while (src_off < (size_t)rem && pass_pos < sizeof(pass_buf)) {
                        size_t take = (size_t)rem - src_off;
                        size_t cap  = sizeof(pass_buf) - pass_pos;
                        if (take > cap) take = cap;
                        if (take == 0) break;
                        memcpy(pass_buf + pass_pos, p + src_off, take);
                        pass_pos += take;
                        src_off += take;
                        if (pass_pos >= sizeof(pass_buf)) {
                            size_t aligned = (pass_pos / 512) * 512;
                            sdio_tx_bytes(pass_buf, aligned);
                            size_t left = pass_pos - aligned;
                            if (left > 0 && aligned > 0 && aligned < sizeof(pass_buf))
                                memmove(pass_buf, pass_buf + aligned, left);
                            pass_pos = left;
                        }
                    }
                    if (pass_pos >= 512) {
                        size_t aligned = (pass_pos / 512) * 512;
                        sdio_tx_bytes(pass_buf, aligned);
                        size_t left = pass_pos - aligned;
                        if (left > 0 && aligned > 0 && aligned < sizeof(pass_buf))
                            memmove(pass_buf, pass_buf + aligned, left);
                        pass_pos = left;
                    }
                }
            }
            total += n;
            int64_t now_us = esp_timer_get_time();
            if (now_us - t_last_log_us >= 1000000) {
                int64_t dt_us = now_us - t_first_us;
                ESP_LOGI(TAG, "rx %u B in %lld us (%.1f KB/s, %s)",
                         (unsigned)total, dt_us,
                         (double)total / ((double)dt_us / 1e6) / 1024.0,
                         sink_mode ? "SINK" : (dflt_mode ? "DFLT" : "BRIDGE"));
                t_last_log_us = now_us;
            }
        }
        ESP_LOGI(TAG, "client closed (%u bytes total)", (unsigned)total);
        close(client_fd);
        close(listen_fd);
    }
}

/* ------------------------------------------------------------------ */
/* UDP server :8889                                                    */
/*  - First packet header b"SINK" (4B) → discard mode (WiFi benchmark) */
/*  - First packet header b"BRDG" (4B) → forward payload to SDIO       */
/*  - Header b"FRAM" (8B + frame_size LE u32) → buffer entire frame,    */
/*       wait until complete, then forward atomically to SDIO          */
/*  - Otherwise: treat as raw bridge stream                            */
/* Why UDP for bridge: avoids TCP ACK RTT (~60ms) per chunk; assumes   */
/* short-distance reliable link. Loss = frame drop, retry next frame.  */
/* ------------------------------------------------------------------ */
#define UDP_PORT  8889
#define UDP_FRAME_MAX  (32 * 1024)  /* 32 KB FRAM mode buffer (ESP32-C5 heap tight) */
static uint8_t *udp_frame_buf;  /* allocated lazily from heap */
static void udp_sink_task(void *pv) {
    static uint8_t udp_rx_buf[4096];
    int s = socket(AF_INET, SOCK_DGRAM, 0);
    if (s < 0) { ESP_LOGE(TAG, "udp socket fail"); vTaskDelete(NULL); }
    int rcvbuf = 256 * 1024;
    setsockopt(s, SOL_SOCKET, SO_RCVBUF, &rcvbuf, sizeof(rcvbuf));
    struct sockaddr_in a = {0};
    a.sin_family = AF_INET;
    a.sin_addr.s_addr = htonl(INADDR_ANY);
    a.sin_port = htons(UDP_PORT);
    if (bind(s, (struct sockaddr *)&a, sizeof(a)) < 0) {
        ESP_LOGE(TAG, "udp bind fail"); close(s); vTaskDelete(NULL);
    }
    udp_frame_buf = malloc(UDP_FRAME_MAX);
    if (!udp_frame_buf) {
        size_t free_heap = esp_get_free_heap_size();
        ESP_LOGE(TAG, "UDP frame buf alloc %d fail (free=%u)", UDP_FRAME_MAX, (unsigned)free_heap);
        close(s); vTaskDelete(NULL);
    }
    ESP_LOGI(TAG, "UDP listening on :%d (SINK/BRDG/FRAM)", UDP_PORT);
    int sink = 0, brdg = 0;
    size_t fram_size = 0, fram_got = 0;
    int64_t t0 = esp_timer_get_time();
    int64_t t_last = t0;
    size_t total = 0, last_total = 0;
    for (;;) {
        int n = recv(s, udp_rx_buf, sizeof(udp_rx_buf), 0);
        if (n <= 0) continue;
        const uint8_t *p = udp_rx_buf;
        size_t len = n;

        /* Detect mode on first packet of a session. */
        if (!sink && !brdg && fram_size == 0 && len >= 4) {
            if (p[0]=='S' && p[1]=='I' && p[2]=='N' && p[3]=='K') {
                sink = 1; p += 4; len -= 4;
                ESP_LOGW(TAG, "UDP: SINK mode (discard)");
            } else if (p[0]=='B' && p[1]=='R' && p[2]=='D' && p[3]=='G') {
                brdg = 1; p += 4; len -= 4;
                ESP_LOGW(TAG, "UDP: BRDG mode (forward to SDIO)");
            } else if (p[0]=='F' && p[1]=='R' && p[2]=='A' && p[3]=='M' && len >= 8) {
                fram_size = (uint32_t)p[4] | ((uint32_t)p[5]<<8)
                          | ((uint32_t)p[6]<<16) | ((uint32_t)p[7]<<24);
                if (fram_size > UDP_FRAME_MAX) {
                    ESP_LOGW(TAG, "FRAM size %u > MAX, drop", (unsigned)fram_size);
                    fram_size = 0; continue;
                }
                fram_got = 0;
                p += 8; len -= 8;
                ESP_LOGW(TAG, "UDP: FRAM mode, expect %u B", (unsigned)fram_size);
            }
        }

        if (fram_size > 0) {
            size_t take = len;
            if (fram_got + take > fram_size) take = fram_size - fram_got;
            memcpy(udp_frame_buf + fram_got, p, take);
            fram_got += take;
            if (fram_got >= fram_size) {
                int64_t t_done = esp_timer_get_time();
                int sent = sdio_tx_bytes(udp_frame_buf, fram_size);
                int64_t t_sdio = esp_timer_get_time();
                ESP_LOGI(TAG, "FRAM done %u B → SDIO %d (recv→sdio %lld us)",
                         (unsigned)fram_size, sent, t_sdio - t_done);
                fram_size = 0; fram_got = 0;
            }
        } else if (brdg) {
            if (len > 0) sdio_tx_bytes(p, len);
        }
        /* else sink: discard */

        total += n;
        int64_t now = esp_timer_get_time();
        if (now - t_last >= 1000000) {
            int64_t dt = now - t_last;
            ESP_LOGI(TAG, "UDP rx: %u B/s (total %u)",
                     (unsigned)(total - last_total),
                     (unsigned)total);
            (void)dt;
            t_last = now;
            last_total = total;
        }
    }
}

/* ------------------------------------------------------------------ */
void app_main(void) {
    /* WiFi internals spam INFO level, drowning our pov_bridge_sdio logs at
     * 115200 baud. Bump to WARN. */
    esp_log_level_set("wifi", ESP_LOG_WARN);
    esp_log_level_set("wifi_init", ESP_LOG_WARN);
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    /* SDIO slave first — Zynq may already be probing the card. */
    ESP_ERROR_CHECK(sdio_slave_setup());

#if 0  /* SDIO-only debug mode (set to 1 to skip WiFi for isolation testing) */
    ESP_LOGI(TAG, "[DEBUG] SDIO-only mode: WiFi disabled. Keeping main task alive.");
    while (1) { vTaskDelay(portMAX_DELAY); }
#else
    wifi_init_sta();

    /* Start TCP server immediately - bind to INADDR_ANY works without IP.
     * Office AP "undef" drops STA every ~10s before GOT_IP fires reliably,
     * so blocking here means listener never starts. lwIP accepts the bind/listen
     * even before DHCP completes; SYN packets get processed once IP is bound. */
    /* Dual-task 试过 (sdio_stream 32KB + sdio_drain_task) — ESP32-C5 single-core
     * RISC-V, 时间分片不并行, 实测 -50% (上下文切换开销 + stream cap 阻塞).
     * Revert single-task path, sdio_stream=NULL 让 server_task 走 fallback 直接
     * sdio_tx_bytes. drain task code 留作 future multi-core 芯片 reuse. */
    xTaskCreate(sdio_rx_task, "sdio_rx", 4096, NULL, 6, NULL);
    xTaskCreate(server_task,  "server",  16384, NULL, 5, NULL);  /* miniz inflate needs ~10K stack */

    /* Best-effort: wait briefly for IP for mdns/log. Don't block forever. */
    EventBits_t got = xEventGroupWaitBits(s_wifi_event_group, WIFI_CONNECTED_BIT,
                                          pdFALSE, pdTRUE, pdMS_TO_TICKS(15000));
    if (got & WIFI_CONNECTED_BIT) {
        vTaskDelay(pdMS_TO_TICKS(500));
        log_wifi_link();
        start_mdns();
    } else {
        ESP_LOGW(TAG, "No IP after 15s - TCP listener already started anyway");
    }
#endif
    /* udp_sink_task disabled — competes with TCP for CPU and lwIP queues.
     * Enable only for UDP-mode benchmarks. */
    /* xTaskCreate(udp_sink_task, "udp_sink", 4096, NULL, 5, NULL); */
}
