# Top-level CMakeLists for ESP-IDF project "pov_bridge".
# Build with ESP-IDF v5.4+ targeting ESP32-C5.
#
#   idf.py set-target esp32c5
#   idf.py build
#   idf.py -p COM5 flash monitor
#
cmake_minimum_required(VERSION 3.16)

include($ENV{IDF_PATH}/tools/cmake/project.cmake)
project(pov_bridge)
