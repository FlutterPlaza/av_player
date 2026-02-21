#include "include/av_player_linux/av_player_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gst/gst.h>
#include <gtk/gtk.h>

#include <cstring>
#include <fstream>
#include <map>
#include <string>

#include "messages.g.h"
#include "player_instance.h"
#include "system_controls.h"

static const char kEventChannelPrefix[] = "com.flutterplaza.av_player_linux/events/";

// =============================================================================
// Plugin struct
// =============================================================================

struct _FlAvPlayerPlugin {
  GObject parent_instance;

  FlPluginRegistrar* registrar;

  // Player instances keyed by texture ID.
  std::map<int64_t, PlayerInstance*>* players;
};

G_DEFINE_TYPE(FlAvPlayerPlugin, fl_av_player_plugin,
              g_object_get_type())

// =============================================================================
// Helpers
// =============================================================================

static PlayerInstance* find_player_by_id(FlAvPlayerPlugin* self,
                                         int64_t player_id) {
  auto it = self->players->find(player_id);
  if (it == self->players->end()) {
    return nullptr;
  }
  return it->second;
}

// =============================================================================
// Event channel listen/cancel callbacks
// =============================================================================

static FlMethodErrorResponse* on_event_listen(FlEventChannel* channel,
                                                FlValue* args,
                                                gpointer user_data) {
  return nullptr;  // Accept all listeners
}

static FlMethodErrorResponse* on_event_cancel(FlEventChannel* channel,
                                                FlValue* args,
                                                gpointer user_data) {
  return nullptr;
}

// =============================================================================
// Pigeon host API handler: create
// =============================================================================

static void handle_create(AvPlayerVideoSourceMessage* source,
                           AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                           gpointer user_data) {
  auto* self = FL_AV_PLAYER_PLUGIN(user_data);

  AvPlayerSourceType type = av_player_video_source_message_get_type_(source);

  // Build URI
  const char* uri = nullptr;
  g_autofree gchar* uri_buf = nullptr;

  switch (type) {
    case AV_PLAYER_SOURCE_TYPE_NETWORK: {
      const gchar* url = av_player_video_source_message_get_url(source);
      if (url == nullptr) {
        av_player_av_player_host_api_respond_error_create(
            response_handle, "INVALID_SOURCE",
            "Network source requires 'url'.", nullptr);
        return;
      }
      uri = url;
      break;
    }
    case AV_PLAYER_SOURCE_TYPE_FILE: {
      const gchar* path = av_player_video_source_message_get_file_path(source);
      if (path == nullptr) {
        av_player_av_player_host_api_respond_error_create(
            response_handle, "INVALID_SOURCE",
            "File source requires 'filePath'.", nullptr);
        return;
      }
      uri_buf = g_strdup_printf("file://%s", path);
      uri = uri_buf;
      break;
    }
    case AV_PLAYER_SOURCE_TYPE_ASSET: {
      const gchar* asset = av_player_video_source_message_get_asset_path(source);
      if (asset == nullptr) {
        av_player_av_player_host_api_respond_error_create(
            response_handle, "INVALID_SOURCE",
            "Asset source requires 'assetPath'.", nullptr);
        return;
      }
      // Assets are bundled in the flutter_assets directory relative to the executable
      g_autofree gchar* exe_dir = g_path_get_dirname("/proc/self/exe");
      gchar* resolved = g_file_read_link("/proc/self/exe", nullptr);
      if (resolved) {
        g_free(exe_dir);
        exe_dir = g_path_get_dirname(resolved);
        g_free(resolved);
      }
      uri_buf = g_strdup_printf("file://%s/data/flutter_assets/%s",
                                 exe_dir, asset);
      uri = uri_buf;
      break;
    }
    default:
      av_player_av_player_host_api_respond_error_create(
          response_handle, "INVALID_SOURCE", "Unknown source type.", nullptr);
      return;
  }

  FlTextureRegistrar* tex_reg =
      fl_plugin_registrar_get_texture_registrar(self->registrar);
  FlBinaryMessenger* messenger =
      fl_plugin_registrar_get_messenger(self->registrar);

  // Step 1: Create player with null event channel to get texture ID
  PlayerInstance* player = player_instance_new(tex_reg, nullptr, uri);
  int64_t texture_id = player_instance_get_texture_id(player);

  // Step 2: Create event channel with the correct name based on texture ID
  g_autofree gchar* event_channel_name =
      g_strdup_printf("%s%" G_GINT64_FORMAT, kEventChannelPrefix, texture_id);
  g_autoptr(FlStandardMethodCodec) event_codec = fl_standard_method_codec_new();
  FlEventChannel* event_ch = fl_event_channel_new(
      messenger, event_channel_name, FL_METHOD_CODEC(event_codec));
  fl_event_channel_set_stream_handlers(event_ch, on_event_listen,
                                        on_event_cancel, nullptr, nullptr);

  // Step 3: Set the event channel on the player
  player_instance_set_event_channel(player, event_ch);

  (*self->players)[texture_id] = player;

  av_player_av_player_host_api_respond_create(response_handle, texture_id);
}

// =============================================================================
// Pigeon host API handler: dispose
// =============================================================================

static void handle_dispose(int64_t player_id,
                            AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                            gpointer user_data) {
  auto* self = FL_AV_PLAYER_PLUGIN(user_data);
  auto it = self->players->find(player_id);
  if (it != self->players->end()) {
    player_instance_dispose(it->second);
    self->players->erase(it);
  }
  av_player_av_player_host_api_respond_dispose(response_handle);
}

// =============================================================================
// Pigeon host API handler: play
// =============================================================================

static void handle_play(int64_t player_id,
                         AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                         gpointer user_data) {
  auto* self = FL_AV_PLAYER_PLUGIN(user_data);
  PlayerInstance* p = find_player_by_id(self, player_id);
  if (p == nullptr) {
    av_player_av_player_host_api_respond_error_play(
        response_handle, "NO_PLAYER", "Player not found.", nullptr);
    return;
  }
  player_instance_play(p);
  av_player_av_player_host_api_respond_play(response_handle);
}

// =============================================================================
// Pigeon host API handler: pause
// =============================================================================

static void handle_pause(int64_t player_id,
                          AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                          gpointer user_data) {
  auto* self = FL_AV_PLAYER_PLUGIN(user_data);
  PlayerInstance* p = find_player_by_id(self, player_id);
  if (p == nullptr) {
    av_player_av_player_host_api_respond_error_pause(
        response_handle, "NO_PLAYER", "Player not found.", nullptr);
    return;
  }
  player_instance_pause(p);
  av_player_av_player_host_api_respond_pause(response_handle);
}

// =============================================================================
// Pigeon host API handler: seekTo
// =============================================================================

static void handle_seek_to(int64_t player_id,
                            int64_t position_ms,
                            AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                            gpointer user_data) {
  auto* self = FL_AV_PLAYER_PLUGIN(user_data);
  PlayerInstance* p = find_player_by_id(self, player_id);
  if (p == nullptr) {
    av_player_av_player_host_api_respond_error_seek_to(
        response_handle, "NO_PLAYER", "Player not found.", nullptr);
    return;
  }
  player_instance_seek_to(p, position_ms);
  av_player_av_player_host_api_respond_seek_to(response_handle);
}

// =============================================================================
// Pigeon host API handler: setPlaybackSpeed
// =============================================================================

static void handle_set_playback_speed(int64_t player_id,
                                       double speed,
                                       AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                                       gpointer user_data) {
  auto* self = FL_AV_PLAYER_PLUGIN(user_data);
  PlayerInstance* p = find_player_by_id(self, player_id);
  if (p == nullptr) {
    av_player_av_player_host_api_respond_error_set_playback_speed(
        response_handle, "NO_PLAYER", "Player not found.", nullptr);
    return;
  }
  player_instance_set_speed(p, speed);
  av_player_av_player_host_api_respond_set_playback_speed(response_handle);
}

// =============================================================================
// Pigeon host API handler: setLooping
// =============================================================================

static void handle_set_looping(int64_t player_id,
                                gboolean looping,
                                AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                                gpointer user_data) {
  auto* self = FL_AV_PLAYER_PLUGIN(user_data);
  PlayerInstance* p = find_player_by_id(self, player_id);
  if (p == nullptr) {
    av_player_av_player_host_api_respond_error_set_looping(
        response_handle, "NO_PLAYER", "Player not found.", nullptr);
    return;
  }
  player_instance_set_looping(p, looping);
  av_player_av_player_host_api_respond_set_looping(response_handle);
}

// =============================================================================
// Pigeon host API handler: setVolume
// =============================================================================

static void handle_set_volume(int64_t player_id,
                               double volume,
                               AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                               gpointer user_data) {
  auto* self = FL_AV_PLAYER_PLUGIN(user_data);
  PlayerInstance* p = find_player_by_id(self, player_id);
  if (p == nullptr) {
    av_player_av_player_host_api_respond_error_set_volume(
        response_handle, "NO_PLAYER", "Player not found.", nullptr);
    return;
  }
  player_instance_set_volume(p, volume);
  av_player_av_player_host_api_respond_set_volume(response_handle);
}

// =============================================================================
// Pigeon host API handler: isPipAvailable
// =============================================================================

static void handle_is_pip_available(AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                                     gpointer user_data) {
  av_player_av_player_host_api_respond_is_pip_available(response_handle, FALSE);
}

// =============================================================================
// Pigeon host API handler: enterPip
// =============================================================================

static void handle_enter_pip(AvPlayerEnterPipRequest* request,
                              AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                              gpointer user_data) {
  // PIP is not available on Linux
  av_player_av_player_host_api_respond_enter_pip(response_handle);
}

// =============================================================================
// Pigeon host API handler: exitPip
// =============================================================================

static void handle_exit_pip(int64_t player_id,
                             AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                             gpointer user_data) {
  // PIP is not available on Linux
  av_player_av_player_host_api_respond_exit_pip(response_handle);
}

// =============================================================================
// Pigeon host API handler: setMediaMetadata
// =============================================================================

static void handle_set_media_metadata(AvPlayerMediaMetadataRequest* request,
                                       AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                                       gpointer user_data) {
  auto* self = FL_AV_PLAYER_PLUGIN(user_data);
  int64_t player_id = av_player_media_metadata_request_get_player_id(request);
  PlayerInstance* p = find_player_by_id(self, player_id);
  if (p == nullptr) {
    av_player_av_player_host_api_respond_error_set_media_metadata(
        response_handle, "NO_PLAYER", "Player not found.", nullptr);
    return;
  }

  AvPlayerMediaMetadataMessage* metadata =
      av_player_media_metadata_request_get_metadata(request);

  const gchar* title = av_player_media_metadata_message_get_title(metadata);
  const gchar* artist = av_player_media_metadata_message_get_artist(metadata);
  const gchar* album = av_player_media_metadata_message_get_album(metadata);
  const gchar* art = av_player_media_metadata_message_get_artwork_url(metadata);

  player_instance_set_media_metadata(
      p,
      title ? title : "",
      artist ? artist : "",
      album ? album : "",
      art ? art : "");

  av_player_av_player_host_api_respond_set_media_metadata(response_handle);
}

// =============================================================================
// Pigeon host API handler: setNotificationEnabled
// =============================================================================

static void handle_set_notification_enabled(int64_t player_id,
                                             gboolean enabled,
                                             AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                                             gpointer user_data) {
  auto* self = FL_AV_PLAYER_PLUGIN(user_data);
  PlayerInstance* p = find_player_by_id(self, player_id);
  if (p == nullptr) {
    av_player_av_player_host_api_respond_error_set_notification_enabled(
        response_handle, "NO_PLAYER", "Player not found.", nullptr);
    return;
  }
  player_instance_set_notification_enabled(p, enabled);
  av_player_av_player_host_api_respond_set_notification_enabled(response_handle);
}

// =============================================================================
// Pigeon host API handler: setSystemVolume
// =============================================================================

static void handle_set_system_volume(double volume,
                                      AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                                      gpointer user_data) {
  system_controls_set_volume(volume);
  av_player_av_player_host_api_respond_set_system_volume(response_handle);
}

// =============================================================================
// Pigeon host API handler: getSystemVolume
// =============================================================================

static void handle_get_system_volume(AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                                      gpointer user_data) {
  av_player_av_player_host_api_respond_get_system_volume(
      response_handle, system_controls_get_volume());
}

// =============================================================================
// Pigeon host API handler: setScreenBrightness
// =============================================================================

static void handle_set_screen_brightness(double brightness,
                                          AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                                          gpointer user_data) {
  system_controls_set_brightness(brightness);
  av_player_av_player_host_api_respond_set_screen_brightness(response_handle);
}

// =============================================================================
// Pigeon host API handler: getScreenBrightness
// =============================================================================

static void handle_get_screen_brightness(AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                                          gpointer user_data) {
  av_player_av_player_host_api_respond_get_screen_brightness(
      response_handle, system_controls_get_brightness());
}

// =============================================================================
// Pigeon host API handler: setWakelock
// =============================================================================

static void handle_set_wakelock(gboolean enabled,
                                 AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                                 gpointer user_data) {
  system_controls_set_wakelock(enabled);
  av_player_av_player_host_api_respond_set_wakelock(response_handle);
}

// =============================================================================
// Pigeon host API handler: setAbrConfig
// =============================================================================

static void handle_set_abr_config(AvPlayerSetAbrConfigRequest* request,
                                   AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                                   gpointer user_data) {
  auto* self = FL_AV_PLAYER_PLUGIN(user_data);
  int64_t player_id = av_player_set_abr_config_request_get_player_id(request);
  PlayerInstance* p = find_player_by_id(self, player_id);
  if (p == nullptr) {
    av_player_av_player_host_api_respond_error_set_abr_config(
        response_handle, "NO_PLAYER", "Player not found.", nullptr);
    return;
  }

  // ABR configuration acknowledged.
  // TODO: Apply ABR constraints to the GStreamer pipeline once
  // player_instance_get_pipeline() is exposed in player_instance.h.
  av_player_av_player_host_api_respond_set_abr_config(response_handle);
}

// =============================================================================
// Pigeon host API handler: getDecoderInfo
// =============================================================================

static void handle_get_decoder_info(int64_t player_id,
                                     AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                                     gpointer user_data) {
  // TODO: Inspect the GStreamer pipeline to detect hardware decoders once
  // player_instance_get_pipeline() is exposed in player_instance.h.
  // For now, report unknown/software decoding.
  g_autoptr(AvPlayerDecoderInfoMessage) info =
      av_player_decoder_info_message_new(FALSE, nullptr, nullptr);
  av_player_av_player_host_api_respond_get_decoder_info(response_handle, info);
}

// =============================================================================
// Pigeon host API handler: getSubtitleTracks
// =============================================================================

static void handle_get_subtitle_tracks(int64_t player_id,
                                        AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                                        gpointer user_data) {
  // TODO: Implement using GStreamer text pads.
  // Return empty list for now.
  g_autoptr(FlValue) empty_list = fl_value_new_list();
  av_player_av_player_host_api_respond_get_subtitle_tracks(response_handle, empty_list);
}

// =============================================================================
// Pigeon host API handler: selectSubtitleTrack
// =============================================================================

static void handle_select_subtitle_track(AvPlayerSelectSubtitleTrackRequest* request,
                                          AvPlayerAvPlayerHostApiResponseHandle* response_handle,
                                          gpointer user_data) {
  // TODO: Implement using GStreamer text pads.
  av_player_av_player_host_api_respond_select_subtitle_track(response_handle);
}

// =============================================================================
// Memory pressure polling
// =============================================================================

static gboolean check_memory_pressure(gpointer user_data) {
  (void)user_data;

  std::ifstream meminfo("/proc/meminfo");
  if (!meminfo.is_open()) return G_SOURCE_CONTINUE;

  long mem_total = 0, mem_available = 0;
  std::string line;
  while (std::getline(meminfo, line)) {
    if (line.find("MemTotal:") == 0) {
      sscanf(line.c_str(), "MemTotal: %ld", &mem_total);
    } else if (line.find("MemAvailable:") == 0) {
      sscanf(line.c_str(), "MemAvailable: %ld", &mem_available);
    }
  }

  if (mem_total <= 0) return G_SOURCE_CONTINUE;

  double free_pct = static_cast<double>(mem_available) / mem_total;
  const char* level = nullptr;
  if (free_pct < 0.05) {
    level = "critical";
  } else if (free_pct < 0.15) {
    level = "warning";
  }

  if (level != nullptr) {
    // TODO: Notify player instances of memory pressure once
    // player_instance_send_event() is exposed in player_instance.h.
    g_warning("av_player: memory pressure level=%s (%.1f%% free)", level,
              free_pct * 100.0);
  }

  return G_SOURCE_CONTINUE;
}

// =============================================================================
// VTable
// =============================================================================

static const AvPlayerAvPlayerHostApiVTable kVTable = {
    .create = handle_create,
    .dispose = handle_dispose,
    .play = handle_play,
    .pause = handle_pause,
    .seek_to = handle_seek_to,
    .set_playback_speed = handle_set_playback_speed,
    .set_looping = handle_set_looping,
    .set_volume = handle_set_volume,
    .is_pip_available = handle_is_pip_available,
    .enter_pip = handle_enter_pip,
    .exit_pip = handle_exit_pip,
    .set_media_metadata = handle_set_media_metadata,
    .set_notification_enabled = handle_set_notification_enabled,
    .set_system_volume = handle_set_system_volume,
    .get_system_volume = handle_get_system_volume,
    .set_screen_brightness = handle_set_screen_brightness,
    .get_screen_brightness = handle_get_screen_brightness,
    .set_wakelock = handle_set_wakelock,
    .set_abr_config = handle_set_abr_config,
    .get_decoder_info = handle_get_decoder_info,
    .get_subtitle_tracks = handle_get_subtitle_tracks,
    .select_subtitle_track = handle_select_subtitle_track,
};

// =============================================================================
// Plugin lifecycle
// =============================================================================

static void fl_av_player_plugin_dispose(GObject* object) {
  auto* self = FL_AV_PLAYER_PLUGIN(object);

  if (self->players) {
    for (auto& pair : *self->players) {
      player_instance_dispose(pair.second);
    }
    delete self->players;
    self->players = nullptr;
  }

  // Clear Pigeon method handlers
  FlBinaryMessenger* messenger =
      fl_plugin_registrar_get_messenger(self->registrar);
  av_player_av_player_host_api_clear_method_handlers(messenger, nullptr);

  g_clear_object(&self->registrar);

  G_OBJECT_CLASS(fl_av_player_plugin_parent_class)->dispose(object);
}

static void fl_av_player_plugin_class_init(
    FlAvPlayerPluginClass* klass) {
  G_OBJECT_CLASS(klass)->dispose = fl_av_player_plugin_dispose;
}

static void fl_av_player_plugin_init(
    FlAvPlayerPlugin* self) {}

FlAvPlayerPlugin* fl_av_player_plugin_new(
    FlPluginRegistrar* registrar) {
  FlAvPlayerPlugin* self = FL_AV_PLAYER_PLUGIN(
      g_object_new(fl_av_player_plugin_get_type(), nullptr));

  self->registrar = FL_PLUGIN_REGISTRAR(g_object_ref(registrar));
  self->players = new std::map<int64_t, PlayerInstance*>();

  // Initialize GStreamer (safe to call multiple times)
  gst_init(nullptr, nullptr);

  // Register Pigeon host API handlers
  FlBinaryMessenger* messenger =
      fl_plugin_registrar_get_messenger(registrar);
  av_player_av_player_host_api_set_method_handlers(
      messenger, nullptr, &kVTable,
      g_object_ref(self), g_object_unref);

  // Start memory pressure polling (every 5 seconds)
  g_timeout_add_seconds(5, check_memory_pressure, self);

  return self;
}

void av_player_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  FlAvPlayerPlugin* plugin =
      fl_av_player_plugin_new(registrar);
  g_object_unref(plugin);
}
