cmake_minimum_required(VERSION 3.10)
set(PROJECT_NAME "av_player")
project(${PROJECT_NAME} LANGUAGES CXX)

set(PLUGIN_NAME "${PROJECT_NAME}_plugin")

# Find GStreamer and PulseAudio via pkg-config
find_package(PkgConfig REQUIRED)
pkg_check_modules(GSTREAMER REQUIRED gstreamer-1.0 gstreamer-app-1.0 gstreamer-video-1.0)
pkg_check_modules(PULSE REQUIRED libpulse)

list(APPEND PLUGIN_SOURCES
  "av_player_linux_plugin.cc"
  "player_instance.cc"
  "mpris_controller.cc"
  "system_controls.cc"
)

add_library(${PLUGIN_NAME} SHARED
  ${PLUGIN_SOURCES}
)
apply_standard_settings(${PLUGIN_NAME})
set_target_properties(${PLUGIN_NAME} PROPERTIES
  CXX_VISIBILITY_PRESET hidden)
target_compile_definitions(${PLUGIN_NAME} PRIVATE FLUTTER_PLUGIN_IMPL)
target_include_directories(${PLUGIN_NAME} INTERFACE
  "${CMAKE_CURRENT_SOURCE_DIR}/include")

target_include_directories(${PLUGIN_NAME} PRIVATE
  ${GSTREAMER_INCLUDE_DIRS}
  ${PULSE_INCLUDE_DIRS}
)

target_link_libraries(${PLUGIN_NAME} PRIVATE flutter)
target_link_libraries(${PLUGIN_NAME} PRIVATE PkgConfig::GTK)
target_link_libraries(${PLUGIN_NAME} PRIVATE
  ${GSTREAMER_LIBRARIES}
  ${PULSE_LIBRARIES}
)
