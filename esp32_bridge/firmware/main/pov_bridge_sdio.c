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
 * ESP32-C5 SDIO slave fixed IOMUX pins (per ESP32-C5 TRM, subject to
 * confirmation against final silicon):
 *   CLK  = GPIO9
 *   CMD  = GPIO8
 *   D0   = GPIO10
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
#include <sys/socket.h>
#include <netinet/in.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "freertos/queue.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_wifi.h"
#include "esp_system.h"
#include "nvs_flash.h"
#include "driver/sdio_slave.h"
#include "driver/gpio.h"
#include "lwip/err.h"
#include "mdns.h"

#define WIFI_SSID          CONFIG_POV_WIFI_SSID
#define WIFI_PASS          CONFIG_POV_WIFI_PASSWORD
#define LISTEN_PORT        8888

/* SDIO slave configuration */
#define SDIO_BLOCK_SIZE    512
#define SDIO_TX_BUF_NUM    16     /* 16 * 512 = 8 KB TX ring (ESP -> Zynq) */
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
            esp_wifi_connect();
        } else if (event_id == WIFI_EVENT_STA_DISCONNECTED) {
            esp_wifi_connect();
            xEventGroupClearBits(s_wifi_event_group, WIFI_CONNECTED_BIT);
            ESP_LOGW(TAG, "WiFi disconnected, retrying");
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

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    ESP_ERROR_CHECK(esp_wifi_init(&cfg));
    esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_event_handler, NULL);
    esp_event_handler_register(IP_EVENT,   IP_EVENT_STA_GOT_IP, &wifi_event_handler, NULL);

    wifi_config_t wifi_config = {
        .sta = {
            .ssid = WIFI_SSID,
            .password = WIFI_PASS,
            .threshold.authmode = WIFI_AUTH_WPA2_PSK,
        },
    };
    ESP_ERROR_CHECK(esp_wifi_set_mode(WIFI_MODE_STA));
    ESP_ERROR_CHECK(esp_wifi_set_config(WIFI_IF_STA, &wifi_config));
    ESP_ERROR_CHECK(esp_wifi_start());
    ESP_LOGI(TAG, "WiFi STA started, connecting to '%s'", WIFI_SSID);
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
 */
static uint8_t sdio_rx_pool[SDIO_RX_BUF_NUM][SDIO_RX_BUF_SIZE];

static esp_err_t sdio_slave_setup(void) {
    sdio_slave_config_t scfg = {
        .sending_mode    = SDIO_SLAVE_SEND_PACKET,
        .send_queue_size = SDIO_TX_BUF_NUM,
        .recv_buffer_size = SDIO_RX_BUF_SIZE,
        .event_cb        = NULL,
    };
    esp_err_t err = sdio_slave_initialize(&scfg);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "sdio_slave_initialize: %s", esp_err_to_name(err));
        return err;
    }

    /* Register RX buffers — driver will fill them as host writes blocks. */
    for (int i = 0; i < SDIO_RX_BUF_NUM; ++i) {
        sdio_slave_buf_handle_t h = sdio_slave_recv_register_buf(sdio_rx_pool[i]);
        if (h == NULL) {
            ESP_LOGE(TAG, "recv_register_buf #%d failed", i);
            return ESP_FAIL;
        }
        ESP_ERROR_CHECK(sdio_slave_recv_load_buf(h));
    }

    sdio_slave_set_host_intena(SDIO_SLAVE_HOSTINT_BIT0
                               | SDIO_SLAVE_HOSTINT_SEND_NEW_PACKET);

    err = sdio_slave_start();
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "sdio_slave_start: %s", esp_err_to_name(err));
        return err;
    }
    ESP_LOGI(TAG, "SDIO slave started (block %d, TX %d bufs, RX %d bufs)",
             SDIO_BLOCK_SIZE, SDIO_TX_BUF_NUM, SDIO_RX_BUF_NUM);
    return ESP_OK;
}

/* Send a buffer to SDIO master (Zynq) via sdio_slave_transmit.
 * Splits into <= SDIO_BLOCK_SIZE chunks; driver will pad last chunk.
 *
 * sdio_slave_transmit() copies the buffer into an internal descriptor and
 * returns when the host has finished reading it (blocking). For higher
 * throughput sdio_slave_send_queue() can be used with a completion poll.
 */
static int sdio_tx_bytes(const uint8_t *buf, size_t len) {
    size_t remaining = len;
    const uint8_t *p = buf;
    while (remaining) {
        size_t chunk = remaining > SDIO_BLOCK_SIZE ? SDIO_BLOCK_SIZE : remaining;
        esp_err_t err = sdio_slave_transmit((uint8_t *)p, chunk);
        if (err != ESP_OK) {
            ESP_LOGW(TAG, "sdio_slave_transmit: %s", esp_err_to_name(err));
            return -1;
        }
        p         += chunk;
        remaining -= chunk;
    }
    return (int)len;
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
    static uint8_t rx_buf[4096];

    while (1) {
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
        ESP_LOGI(TAG, "TCP listening on :%d", LISTEN_PORT);

        struct sockaddr_in cli;
        socklen_t cl = sizeof(cli);
        int client_fd = accept(listen_fd, (struct sockaddr *)&cli, &cl);
        if (client_fd < 0) {
            close(listen_fd);
            continue;
        }
        ESP_LOGI(TAG, "client connected: " IPSTR, IP2STR(&cli.sin_addr));

        /* Disable Nagle to reduce latency */
        int nodelay = 1;
        setsockopt(client_fd, IPPROTO_TCP, TCP_NODELAY, &nodelay, sizeof(nodelay));

        size_t total = 0;
        for (;;) {
            int n = recv(client_fd, rx_buf, sizeof(rx_buf), 0);
            if (n <= 0) break;
            if (sdio_tx_bytes(rx_buf, (size_t)n) < 0) {
                ESP_LOGW(TAG, "SDIO TX failed, dropping client");
                break;
            }
            total += n;
            if ((total >> 14) != ((total - n) >> 14)) {
                ESP_LOGI(TAG, "relayed %u bytes total", (unsigned)total);
            }
        }
        ESP_LOGI(TAG, "client closed (%u bytes total)", (unsigned)total);
        close(client_fd);
        close(listen_fd);
    }
}

/* ------------------------------------------------------------------ */
void app_main(void) {
    esp_err_t ret = nvs_flash_init();
    if (ret == ESP_ERR_NVS_NO_FREE_PAGES || ret == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        ESP_ERROR_CHECK(nvs_flash_erase());
        ret = nvs_flash_init();
    }
    ESP_ERROR_CHECK(ret);

    /* SDIO slave first — Zynq may already be probing the card. */
    ESP_ERROR_CHECK(sdio_slave_setup());

    wifi_init_sta();

    /* wait for IP */
    xEventGroupWaitBits(s_wifi_event_group, WIFI_CONNECTED_BIT,
                        pdFALSE, pdTRUE, portMAX_DELAY);
    start_mdns();

    xTaskCreate(sdio_rx_task, "sdio_rx", 4096, NULL, 6, NULL);
    xTaskCreate(server_task,  "server",  4096, NULL, 5, NULL);
}
