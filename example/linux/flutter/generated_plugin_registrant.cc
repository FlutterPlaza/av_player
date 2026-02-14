//
//  Generated file. Do not edit.
//

// clang-format off

#include "generated_plugin_registrant.h"

#include <av_player/av_player_plugin.h>

void fl_register_plugins(FlPluginRegistry* registry) {
  g_autoptr(FlPluginRegistrar) av_player_registrar =
      fl_plugin_registry_get_registrar_for_plugin(registry, "AvPlayerPlugin");
  av_player_plugin_register_with_registrar(av_player_registrar);
}
