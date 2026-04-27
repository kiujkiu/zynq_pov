/* pov_bridge.c — ESP32 WiFi-to-UART bridge for POV3D streaming.
 *
 * - Connects to WiFi (STA mode) using credentials in NVS or sdkconfig.
 * - Listens on TCP :8888.
 * - Anything received over TCP is forwarded byte-for-byte to UART (921600 baud).
 * - mDNS: advertises "pov-bridge.local" so host can find by name.
 *
 * Build with ESP-IDF v5.x. Place under your IDF project's main/.
 */

#include <stdio.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "esp_event.h"
#include "esp_log.h"
#include "esp_netif.h"
#include "esp_wifi.h"
#include "esp_system.h"
#include "nvs_flash.h"
#include "driver/uart.h"
#include "driver/gpio.h"
#include "lwip/err.h"
#include "mdns.h"

#define WIFI_SSID      CONFIG_POV_WIFI_SSID
#define WIFI_PASS      CONFIG_POV_WIFI_PASSWORD
#define UART_PORT      UART_NUM_1
#define UART_TX_PIN    GPIO_NUM_17
#define UART_RX_PIN    GPIO_NUM_16
#define UART_BAUD      921600
#define LISTEN_PORT    8888

static const char *TAG = "pov_bridge";

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
    mdns_instance_name_set("POV3D bridge");
    mdns_service_add(NULL, "_povbridge", "_tcp", LISTEN_PORT, NULL, 0);
    ESP_LOGI(TAG, "mDNS: pov-bridge.local:%d", LISTEN_PORT);
}

/* ------------------------------------------------------------------ */
/* UART init                                                          */
/* ------------------------------------------------------------------ */
static void uart_init(void) {
    uart_config_t cfg = {
        .baud_rate = UART_BAUD,
        .data_bits = UART_DATA_8_BITS,
        .parity    = UART_PARITY_DISABLE,
        .stop_bits = UART_STOP_BITS_1,
        .flow_ctrl = UART_HW_FLOWCTRL_DISABLE,
    };
    uart_driver_install(UART_PORT, 4096, 4096, 0, NULL, 0);
    uart_param_config(UART_PORT, &cfg);
    uart_set_pin(UART_PORT, UART_TX_PIN, UART_RX_PIN, UART_PIN_NO_CHANGE, UART_PIN_NO_CHANGE);
    ESP_LOGI(TAG, "UART %d: %d baud TX=GPIO%d RX=GPIO%d",
             UART_PORT, UART_BAUD, UART_TX_PIN, UART_RX_PIN);
}

/* ------------------------------------------------------------------ */
/* TCP server                                                         */
/* ------------------------------------------------------------------ */
static void server_task(void *pv) {
    char rx_buf[4096];

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
            uart_write_bytes(UART_PORT, rx_buf, n);
            total += n;
            if ((total >> 14) != ((total - n) >> 14)) {
                /* every 16 KB log */
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

    uart_init();
    wifi_init_sta();

    /* wait for IP */
    xEventGroupWaitBits(s_wifi_event_group, WIFI_CONNECTED_BIT,
                        pdFALSE, pdTRUE, portMAX_DELAY);
    start_mdns();
    xTaskCreate(server_task, "server", 4096, NULL, 5, NULL);
}
