# Build one of the three firmware variants. Default = SDIO bridge.
# Override via `idf.py -DPOV_FW=uart` or `-DPOV_FW=gpio_check`.

if(NOT DEFINED POV_FW)
    set(POV_FW "sdio")
endif()

if(POV_FW STREQUAL "sdio")
    set(POV_SRC "pov_bridge_sdio.c")
elseif(POV_FW STREQUAL "uart")
    set(POV_SRC "pov_bridge.c")
elseif(POV_FW STREQUAL "gpio_check")
    set(POV_SRC "gpio_check.c")
else()
    message(FATAL_ERROR "POV_FW must be one of: sdio, uart, gpio_check")
endif()

idf_component_register(
    SRCS "${POV_SRC}"
    INCLUDE_DIRS "."
    REQUIRES
        nvs_flash
        esp_wifi
        esp_event
        esp_netif
        mdns
        driver
        esp_driver_sdio
        esp_driver_gpio
        esp_timer
        lwip
)
