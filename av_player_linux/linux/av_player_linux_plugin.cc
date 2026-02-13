#include "include/av_player_linux/av_player_plugin.h"

#include <flutter_linux/flutter_linux.h>
#include <gst/gst.h>
#include <gtk/gtk.h>

#include <cstring>
#include <map>

#include "player_instance.h"
#include "system_controls.h"

static const char kChannelName[] = "com.flutterplaza.av_player_linux";
static const char kEventChannelPrefix[] = "com.flutterplaza.av_player_linux/events/";

// =============================================================================
// Plugin struct
// =============================================================================

struct _FlAvPlayerPlugin {
  GObject parent_instance;

  FlPluginRegistrar* registrar;
  FlMethodChannel* channel;

  // Player instances keyed by texture ID.
  std::map<int64_t, PlayerInstance*>* players;
};

G_DEFINE_TYPE(FlAvPlayerPlugin, fl_av_player_plugin,
              g_object_get_type())

// =============================================================================
// Helpers
// =============================================================================

static FlMethodResponse* make_error(const char* code, const char* message) {
  return FL_METHOD_RESPONSE(
      fl_method_error_response_new(code, message, nullptr));
}

static FlMethodResponse* make_success(FlValue* result) {
  return FL_METHOD_RESPONSE(fl_method_success_response_new(result));
}

static int64_t get_player_id(FlValue* args) {
  FlValue* v = fl_value_lookup_string(args, "playerId");
  if (v == nullptr) return -1;
  return fl_value_get_int(v);
}

static PlayerInstance* find_player(FlAvPlayerPlugin* self,
                                    FlValue* args,
                                    FlMethodResponse** error_out) {
  int64_t id = get_player_id(args);
  if (id < 0) {
    *error_out = make_error("INVALID_ARGS", "playerId is required.");
    return nullptr;
  }
  auto it = self->players->find(id);
  if (it == self->players->end()) {
    *error_out = make_error("NO_PLAYER", "Player not found.");
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
// Create handler
// =============================================================================

static FlMethodResponse* handle_create(FlAvPlayerPlugin* self,
                                         FlValue* args) {
  if (args == nullptr || fl_value_get_type(args) != FL_VALUE_TYPE_MAP)
    return make_error("INVALID_ARGS", "Arguments required.");

  FlValue* type_val = fl_value_lookup_string(args, "type");
  const char* type = type_val ? fl_value_get_string(type_val) : "network";

  // Build URI
  const char* uri = nullptr;
  g_autofree gchar* uri_buf = nullptr;

  if (strcmp(type, "network") == 0) {
    FlValue* url_val = fl_value_lookup_string(args, "url");
    if (url_val == nullptr)
      return make_error("INVALID_SOURCE", "Network source requires 'url'.");
    uri = fl_value_get_string(url_val);
  } else if (strcmp(type, "file") == 0) {
    FlValue* path_val = fl_value_lookup_string(args, "filePath");
    if (path_val == nullptr)
      return make_error("INVALID_SOURCE", "File source requires 'filePath'.");
    uri_buf = g_strdup_printf("file://%s", fl_value_get_string(path_val));
    uri = uri_buf;
  } else if (strcmp(type, "asset") == 0) {
    FlValue* asset_val = fl_value_lookup_string(args, "assetPath");
    if (asset_val == nullptr)
      return make_error("INVALID_SOURCE", "Asset source requires 'assetPath'.");
    // Assets are bundled in the flutter_assets directory relative to the executable
    g_autofree gchar* exe_dir = g_path_get_dirname("/proc/self/exe");
    gchar* resolved = g_file_read_link("/proc/self/exe", nullptr);
    if (resolved) {
      g_free(exe_dir);
      exe_dir = g_path_get_dirname(resolved);
      g_free(resolved);
    }
    uri_buf = g_strdup_printf("file://%s/data/flutter_assets/%s",
                               exe_dir, fl_value_get_string(asset_val));
    uri = uri_buf;
  } else {
    return make_error("INVALID_SOURCE", "Unknown source type.");
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

  return make_success(fl_value_new_int(texture_id));
}

// =============================================================================
// Method call handler
// =============================================================================

static void method_call_cb(FlMethodChannel* channel,
                            FlMethodCall* method_call,
                            gpointer user_data) {
  auto* self = FL_AV_PLAYER_PLUGIN(user_data);
  const gchar* method = fl_method_call_get_name(method_call);
  FlValue* args = fl_method_call_get_args(method_call);

  g_autoptr(FlMethodResponse) response = nullptr;

  // ---- Lifecycle ----
  if (strcmp(method, "create") == 0) {
    response = handle_create(self, args);

  } else if (strcmp(method, "dispose") == 0) {
    int64_t id = get_player_id(args);
    auto it = self->players->find(id);
    if (it != self->players->end()) {
      player_instance_dispose(it->second);
      self->players->erase(it);
    }
    response = make_success(nullptr);

  // ---- Playback ----
  } else if (strcmp(method, "play") == 0) {
    FlMethodResponse* err = nullptr;
    PlayerInstance* p = find_player(self, args, &err);
    if (p) { player_instance_play(p); response = make_success(nullptr); }
    else response = err;

  } else if (strcmp(method, "pause") == 0) {
    FlMethodResponse* err = nullptr;
    PlayerInstance* p = find_player(self, args, &err);
    if (p) { player_instance_pause(p); response = make_success(nullptr); }
    else response = err;

  } else if (strcmp(method, "seekTo") == 0) {
    FlMethodResponse* err = nullptr;
    PlayerInstance* p = find_player(self, args, &err);
    if (p) {
      FlValue* pos = fl_value_lookup_string(args, "position");
      player_instance_seek_to(p, pos ? fl_value_get_int(pos) : 0);
      response = make_success(nullptr);
    } else response = err;

  } else if (strcmp(method, "setPlaybackSpeed") == 0) {
    FlMethodResponse* err = nullptr;
    PlayerInstance* p = find_player(self, args, &err);
    if (p) {
      FlValue* v = fl_value_lookup_string(args, "speed");
      player_instance_set_speed(p, v ? fl_value_get_float(v) : 1.0);
      response = make_success(nullptr);
    } else response = err;

  } else if (strcmp(method, "setLooping") == 0) {
    FlMethodResponse* err = nullptr;
    PlayerInstance* p = find_player(self, args, &err);
    if (p) {
      FlValue* v = fl_value_lookup_string(args, "looping");
      player_instance_set_looping(p, v ? fl_value_get_bool(v) : FALSE);
      response = make_success(nullptr);
    } else response = err;

  } else if (strcmp(method, "setVolume") == 0) {
    FlMethodResponse* err = nullptr;
    PlayerInstance* p = find_player(self, args, &err);
    if (p) {
      FlValue* v = fl_value_lookup_string(args, "volume");
      player_instance_set_volume(p, v ? fl_value_get_float(v) : 1.0);
      response = make_success(nullptr);
    } else response = err;

  // ---- PIP (N/A on Linux) ----
  } else if (strcmp(method, "isPipAvailable") == 0) {
    response = make_success(fl_value_new_bool(FALSE));

  } else if (strcmp(method, "enterPip") == 0 || strcmp(method, "exitPip") == 0) {
    response = make_success(nullptr);

  // ---- System Controls ----
  } else if (strcmp(method, "setSystemVolume") == 0) {
    FlValue* v = fl_value_lookup_string(args, "volume");
    system_controls_set_volume(v ? fl_value_get_float(v) : 0.5);
    response = make_success(nullptr);

  } else if (strcmp(method, "getSystemVolume") == 0) {
    response = make_success(fl_value_new_float(system_controls_get_volume()));

  } else if (strcmp(method, "setScreenBrightness") == 0) {
    FlValue* v = fl_value_lookup_string(args, "brightness");
    system_controls_set_brightness(v ? fl_value_get_float(v) : 0.5);
    response = make_success(nullptr);

  } else if (strcmp(method, "getScreenBrightness") == 0) {
    response = make_success(fl_value_new_float(system_controls_get_brightness()));

  } else if (strcmp(method, "setWakelock") == 0) {
    FlValue* v = fl_value_lookup_string(args, "enabled");
    system_controls_set_wakelock(v ? fl_value_get_bool(v) : FALSE);
    response = make_success(nullptr);

  // ---- Media Session ----
  } else if (strcmp(method, "setMediaMetadata") == 0) {
    FlMethodResponse* err = nullptr;
    PlayerInstance* p = find_player(self, args, &err);
    if (p) {
      FlValue* title = fl_value_lookup_string(args, "title");
      FlValue* artist = fl_value_lookup_string(args, "artist");
      FlValue* album = fl_value_lookup_string(args, "album");
      FlValue* art = fl_value_lookup_string(args, "artworkUrl");
      player_instance_set_media_metadata(
          p,
          title ? fl_value_get_string(title) : "",
          artist ? fl_value_get_string(artist) : "",
          album ? fl_value_get_string(album) : "",
          art ? fl_value_get_string(art) : "");
      response = make_success(nullptr);
    } else response = err;

  } else if (strcmp(method, "setNotificationEnabled") == 0) {
    FlMethodResponse* err = nullptr;
    PlayerInstance* p = find_player(self, args, &err);
    if (p) {
      FlValue* v = fl_value_lookup_string(args, "enabled");
      player_instance_set_notification_enabled(p, v ? fl_value_get_bool(v) : FALSE);
      response = make_success(nullptr);
    } else response = err;

  // ---- Legacy ----
  } else if (strcmp(method, "getPlatformName") == 0) {
    response = make_success(fl_value_new_string("Linux"));

  } else {
    response = FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
  }

  g_autoptr(GError) error = nullptr;
  if (!fl_method_call_respond(method_call, response, &error))
    g_warning("Failed to send response: %s", error->message);
}

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

  g_clear_object(&self->channel);
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

  g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
  self->channel = fl_method_channel_new(
      fl_plugin_registrar_get_messenger(registrar),
      kChannelName, FL_METHOD_CODEC(codec));
  fl_method_channel_set_method_call_handler(
      self->channel, method_call_cb, g_object_ref(self), g_object_unref);

  return self;
}

void av_player_plugin_register_with_registrar(
    FlPluginRegistrar* registrar) {
  FlAvPlayerPlugin* plugin =
      fl_av_player_plugin_new(registrar);
  g_object_unref(plugin);
}
