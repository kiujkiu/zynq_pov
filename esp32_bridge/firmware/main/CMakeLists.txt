idf_component_register(
    SRCS "pov_bridge.c"
    INCLUDE_DIRS "."
    REQUIRES
        nvs_flash
        esp_wifi
        esp_event
        esp_netif
        driver
        lwip
        mdns
)
