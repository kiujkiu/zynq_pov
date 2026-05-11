/* gpio_check.c — ESP32-C5 GPIO power-on inventory.
 *
 * Stand-alone diagnostic app: at boot, dumps every GPIO's current input
 * level and pin configuration, then loops printing changes. Useful to
 * verify that GPIO4/GPIO5 (and the SDIO group GPIO6-11 on ESP32-C5) are
 * not externally driven before we route them to the SDIO slave.
 *
 * To build instead of pov_bridge.c, swap the source file in
 * firmware/main/CMakeLists.txt:
 *
 *     idf_component_register(SRCS "gpio_check.c" INCLUDE_DIRS ".")
 *
 * Then `idf.py flash monitor` and inspect the log.
 *
 * Strapping pins on ESP32-C5 (per datasheet, subject to revision):
 *   GPIO27 — boot mode (only pin with strapping role)
 *   all other GPIOs default to input with pull disabled
 *
 * Note: GPIO 0..3 and 12..28 are exposed on common ESP32-C5 dev kits.
 * SDIO IOMUX fixed pins (GPIO 7..10 + 13..14) cannot be remapped.
 */

#include <stdio.h>
#include "freertos/FreeRTOS.h"
#include "freertos/task.h"
#include "driver/gpio.h"
#include "esp_log.h"
#include "soc/gpio_num.h"

static const char *TAG = "gpio_check";

/* ESP32-C5 has GPIO 0..28 (29 pins, some reserved for flash/PSRAM).
 * We probe the whole range; the SoC returns 0 for unused pads.
 */
#define GPIO_MIN 0
#define GPIO_MAX 28

/* Per ESP32-C5 datasheet — pins reserved for SPI flash / PSRAM that we
 * must not touch. Adjust if a different package is used.
 */
static const int reserved_pins[] = {
    24, 25, 26, /* SPI flash CLK/CS/D0 on QFN40 — DO NOT PROBE */
    -1,
};

static int is_reserved(int gpio) {
    for (const int *p = reserved_pins; *p != -1; ++p) {
        if (*p == gpio) return 1;
    }
    return 0;
}

static const char *role_of(int gpio) {
    /* Quick legend so user sees the intent at a glance. */
    switch (gpio) {
        case 4:  return "free (user asked: not occupied)";
        case 5:  return "free (user asked: not occupied)";
        case 7:  return "SDIO D1 (fixed IOMUX)";
        case 8:  return "SDIO CMD (fixed IOMUX)";
        case 9:  return "SDIO CLK (fixed IOMUX)";
        case 10: return "SDIO D0 (fixed IOMUX)";
        case 13: return "SDIO D3 (fixed IOMUX)";
        case 14: return "SDIO D2 (fixed IOMUX)";
        case 27: return "STRAPPING — boot mode";
        case 11: return "general IO";
        default: return "general IO";
    }
}

static void gpio_dump(void) {
    printf("\n=== GPIO power-on dump (ESP32-C5) ===\n");
    printf("GPIO | level | role\n");
    printf("-----+-------+------------------------------------\n");
    for (int g = GPIO_MIN; g <= GPIO_MAX; ++g) {
        if (is_reserved(g)) {
            printf("%4d | RESVD | flash/PSRAM, skipped\n", g);
            continue;
        }
        gpio_config_t cfg = {
            .pin_bit_mask = 1ULL << g,
            .mode         = GPIO_MODE_INPUT,
            .pull_up_en   = GPIO_PULLUP_DISABLE,
            .pull_down_en = GPIO_PULLDOWN_DISABLE,
            .intr_type    = GPIO_INTR_DISABLE,
        };
        gpio_config(&cfg);
        int lvl = gpio_get_level(g);
        printf("%4d | %s | %s\n", g, lvl ? "  HI " : "  LO ", role_of(g));
    }
    printf("=====================================\n\n");
}

static void gpio_monitor_task(void *pv) {
    /* Poll periodically and only print when something changes. */
    uint32_t last_mask = 0;
    for (int g = GPIO_MIN; g <= GPIO_MAX; ++g) {
        if (is_reserved(g)) continue;
        if (gpio_get_level(g)) last_mask |= (1U << g);
    }
    while (1) {
        vTaskDelay(pdMS_TO_TICKS(500));
        uint32_t cur = 0;
        for (int g = GPIO_MIN; g <= GPIO_MAX; ++g) {
            if (is_reserved(g)) continue;
            if (gpio_get_level(g)) cur |= (1U << g);
        }
        uint32_t diff = cur ^ last_mask;
        if (diff) {
            for (int g = GPIO_MIN; g <= GPIO_MAX; ++g) {
                if (diff & (1U << g)) {
                    ESP_LOGI(TAG, "GPIO%d -> %s",
                             g, (cur & (1U << g)) ? "HI" : "LO");
                }
            }
            last_mask = cur;
        }
    }
}

void app_main(void) {
    gpio_dump();
    xTaskCreate(gpio_monitor_task, "gpio_mon", 4096, NULL, 4, NULL);
}
