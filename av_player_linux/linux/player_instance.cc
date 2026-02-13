#include "player_instance.h"

#include <gst/video/video.h>

#include <cstring>

// =============================================================================
// Pixel buffer texture (FlPixelBufferTexture subclass)
// =============================================================================

struct _AvPipTexture {
  FlPixelBufferTexture parent_instance;
  uint8_t* buffer;
  int32_t width;
  int32_t height;
  GMutex mutex;
};

#define AV_PIP_TEXTURE(obj) \
  (G_TYPE_CHECK_INSTANCE_CAST((obj), av_pip_texture_get_type(), AvPipTexture))

G_DECLARE_FINAL_TYPE(AvPipTexture, av_pip_texture, AV_PIP, TEXTURE,
                     FlPixelBufferTexture)

static gboolean av_pip_texture_copy_pixels(FlPixelBufferTexture* texture,
                                            const uint8_t** out_buffer,
                                            uint32_t* width,
                                            uint32_t* height,
                                            GError** error) {
  AvPipTexture* self = AV_PIP_TEXTURE(texture);
  g_mutex_lock(&self->mutex);
  if (self->buffer == nullptr || self->width <= 0 || self->height <= 0) {
    g_mutex_unlock(&self->mutex);
    return FALSE;
  }
  *out_buffer = self->buffer;
  *width = static_cast<uint32_t>(self->width);
  *height = static_cast<uint32_t>(self->height);
  g_mutex_unlock(&self->mutex);
  return TRUE;
}

static void av_pip_texture_dispose(GObject* object) {
  AvPipTexture* self = AV_PIP_TEXTURE(object);
  g_mutex_lock(&self->mutex);
  g_free(self->buffer);
  self->buffer = nullptr;
  g_mutex_unlock(&self->mutex);
  g_mutex_clear(&self->mutex);
  G_OBJECT_CLASS(av_pip_texture_parent_class)->dispose(object);
}

static void av_pip_texture_class_init(AvPipTextureClass* klass) {
  FL_PIXEL_BUFFER_TEXTURE_CLASS(klass)->copy_pixels = av_pip_texture_copy_pixels;
  G_OBJECT_CLASS(klass)->dispose = av_pip_texture_dispose;
}

static void av_pip_texture_init(AvPipTexture* self) {
  g_mutex_init(&self->mutex);
  self->buffer = nullptr;
  self->width = 0;
  self->height = 0;
}

G_DEFINE_TYPE(AvPipTexture, av_pip_texture, fl_pixel_buffer_texture_get_type())

// =============================================================================
// PlayerInstance struct
// =============================================================================

struct _PlayerInstance {
  FlTextureRegistrar* texture_registrar;
  FlEventChannel* event_channel;
  AvPipTexture* texture;
  int64_t texture_id;

  GstElement* pipeline;   // playbin
  GstElement* video_sink; // appsink

  gboolean is_looping;
  double speed;
  gboolean is_initialized;
  gboolean is_disposed;
  int64_t duration_ms;

  guint position_timer_id;

  MprisController* mpris;
  gboolean notification_enabled;

  gchar* meta_title;
  gchar* meta_artist;
  gchar* meta_album;
  gchar* meta_art_url;
};

// =============================================================================
// Event helpers
// =============================================================================

static void send_event(PlayerInstance* inst, FlValue* event) {
  if (inst->is_disposed || inst->event_channel == nullptr) {
    fl_value_unref(event);
    return;
  }
  fl_event_channel_send(inst->event_channel, event, nullptr, nullptr);
  fl_value_unref(event);
}

static FlValue* make_event(const char* type) {
  FlValue* map = fl_value_new_map();
  fl_value_set_string_take(map, "type", fl_value_new_string(type));
  return map;
}

// =============================================================================
// MPRIS command callback
// =============================================================================

static void mpris_command_cb(const gchar* command, gint64 seek_position_ms,
                              gpointer user_data) {
  auto* inst = static_cast<PlayerInstance*>(user_data);
  if (inst->is_disposed) return;

  FlValue* event = make_event("mediaCommand");
  fl_value_set_string_take(event, "command", fl_value_new_string(command));
  if (strcmp(command, "seekTo") == 0) {
    fl_value_set_string_take(event, "seekPosition",
                              fl_value_new_int(seek_position_ms));
  }
  send_event(inst, event);
}

// =============================================================================
// GStreamer appsink callback (new-sample)
// =============================================================================

static GstFlowReturn on_new_sample(GstAppSink* sink, gpointer user_data) {
  auto* inst = static_cast<PlayerInstance*>(user_data);
  if (inst->is_disposed) return GST_FLOW_OK;

  GstSample* sample = gst_app_sink_pull_sample(sink);
  if (sample == nullptr) return GST_FLOW_OK;

  GstBuffer* buffer = gst_sample_get_buffer(sample);
  GstCaps* caps = gst_sample_get_caps(sample);
  GstVideoInfo info;
  if (!gst_video_info_from_caps(&info, caps)) {
    gst_sample_unref(sample);
    return GST_FLOW_OK;
  }

  int width = GST_VIDEO_INFO_WIDTH(&info);
  int height = GST_VIDEO_INFO_HEIGHT(&info);

  GstMapInfo map;
  if (gst_buffer_map(buffer, &map, GST_MAP_READ)) {
    AvPipTexture* tex = inst->texture;
    g_mutex_lock(&tex->mutex);

    size_t needed = static_cast<size_t>(width) * height * 4;
    if (tex->width != width || tex->height != height) {
      g_free(tex->buffer);
      tex->buffer = static_cast<uint8_t*>(g_malloc(needed));
      tex->width = width;
      tex->height = height;
    }

    size_t copy_size = (map.size < needed) ? map.size : needed;
    memcpy(tex->buffer, map.data, copy_size);

    g_mutex_unlock(&tex->mutex);
    gst_buffer_unmap(buffer, &map);

    fl_texture_registrar_mark_texture_frame_available(inst->texture_registrar,
                                                       FL_TEXTURE(tex));
  }

  gst_sample_unref(sample);
  return GST_FLOW_OK;
}

// =============================================================================
// GStreamer bus message handler
// =============================================================================

static gboolean on_bus_message(GstBus* bus, GstMessage* msg, gpointer user_data) {
  auto* inst = static_cast<PlayerInstance*>(user_data);
  if (inst->is_disposed) return TRUE;

  switch (GST_MESSAGE_TYPE(msg)) {
    case GST_MESSAGE_ERROR: {
      GError* err = nullptr;
      gchar* debug = nullptr;
      gst_message_parse_error(msg, &err, &debug);
      FlValue* event = make_event("error");
      fl_value_set_string_take(event, "message",
                                fl_value_new_string(err->message));
      fl_value_set_string_take(event, "code",
                                fl_value_new_string("GST_ERROR"));
      send_event(inst, event);
      g_error_free(err);
      g_free(debug);
      break;
    }
    case GST_MESSAGE_EOS: {
      FlValue* completed = make_event("completed");
      send_event(inst, completed);

      FlValue* state_event = make_event("playbackStateChanged");
      fl_value_set_string_take(state_event, "state",
                                fl_value_new_string("completed"));
      send_event(inst, state_event);

      if (inst->is_looping) {
        gst_element_seek_simple(inst->pipeline, GST_FORMAT_TIME,
                                 static_cast<GstSeekFlags>(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_KEY_UNIT),
                                 0);
        gst_element_set_state(inst->pipeline, GST_STATE_PLAYING);
      }
      break;
    }
    case GST_MESSAGE_STATE_CHANGED: {
      if (GST_MESSAGE_SRC(msg) != GST_OBJECT(inst->pipeline)) break;

      GstState old_state, new_state, pending;
      gst_message_parse_state_changed(msg, &old_state, &new_state, &pending);

      // Send initialized event once on first PAUSED
      if (new_state == GST_STATE_PAUSED && !inst->is_initialized) {
        inst->is_initialized = TRUE;

        // Query duration
        gint64 duration_ns = 0;
        if (gst_element_query_duration(inst->pipeline, GST_FORMAT_TIME, &duration_ns)) {
          inst->duration_ms = duration_ns / GST_MSECOND;
        }

        // Query video dimensions from appsink pad
        int width = 0, height = 0;
        GstPad* pad = gst_element_get_static_pad(inst->video_sink, "sink");
        if (pad != nullptr) {
          GstCaps* caps = gst_pad_get_current_caps(pad);
          if (caps != nullptr) {
            GstVideoInfo vinfo;
            if (gst_video_info_from_caps(&vinfo, caps)) {
              width = GST_VIDEO_INFO_WIDTH(&vinfo);
              height = GST_VIDEO_INFO_HEIGHT(&vinfo);
            }
            gst_caps_unref(caps);
          }
          gst_object_unref(pad);
        }

        FlValue* event = make_event("initialized");
        fl_value_set_string_take(event, "duration",
                                  fl_value_new_int(inst->duration_ms));
        fl_value_set_string_take(event, "width",
                                  fl_value_new_float(static_cast<double>(width)));
        fl_value_set_string_take(event, "height",
                                  fl_value_new_float(static_cast<double>(height)));
        fl_value_set_string_take(event, "textureId",
                                  fl_value_new_int(inst->texture_id));
        send_event(inst, event);

        FlValue* ready = make_event("playbackStateChanged");
        fl_value_set_string_take(ready, "state",
                                  fl_value_new_string("ready"));
        send_event(inst, ready);
      }

      // Map GStreamer state to our playback states
      if (inst->is_initialized) {
        const char* state_str = nullptr;
        if (new_state == GST_STATE_PLAYING)
          state_str = "playing";
        else if (new_state == GST_STATE_PAUSED && old_state == GST_STATE_PLAYING)
          state_str = "paused";

        if (state_str != nullptr) {
          FlValue* event = make_event("playbackStateChanged");
          fl_value_set_string_take(event, "state",
                                    fl_value_new_string(state_str));
          send_event(inst, event);

          if (inst->notification_enabled && inst->mpris) {
            const gchar* mpris_status =
                (strcmp(state_str, "playing") == 0) ? "Playing" : "Paused";
            mpris_controller_set_playback_status(inst->mpris, mpris_status);
          }
        }
      }
      break;
    }
    case GST_MESSAGE_BUFFERING: {
      gint percent = 0;
      gst_message_parse_buffering(msg, &percent);
      if (percent < 100) {
        FlValue* event = make_event("playbackStateChanged");
        fl_value_set_string_take(event, "state",
                                  fl_value_new_string("buffering"));
        send_event(inst, event);
      }
      break;
    }
    default:
      break;
  }

  return TRUE;
}

// =============================================================================
// Position polling timer (~200ms)
// =============================================================================

static gboolean position_timer_cb(gpointer user_data) {
  auto* inst = static_cast<PlayerInstance*>(user_data);
  if (inst->is_disposed) return G_SOURCE_REMOVE;

  gint64 pos_ns = 0;
  if (gst_element_query_position(inst->pipeline, GST_FORMAT_TIME, &pos_ns)) {
    gint64 pos_ms = pos_ns / GST_MSECOND;

    FlValue* event = make_event("positionChanged");
    fl_value_set_string_take(event, "position", fl_value_new_int(pos_ms));
    send_event(inst, event);

    // Update MPRIS position (microseconds)
    if (inst->notification_enabled && inst->mpris) {
      mpris_controller_set_position(inst->mpris, pos_ns / 1000);
    }
  }

  // Also check buffered level
  GstQuery* query = gst_query_new_buffering(GST_FORMAT_TIME);
  if (gst_element_query(inst->pipeline, query)) {
    gint64 start = 0, stop = 0;
    gst_query_parse_buffering_range(query, nullptr, &start, &stop, nullptr);
    if (stop > 0) {
      FlValue* event = make_event("bufferingUpdate");
      fl_value_set_string_take(event, "buffered",
                                fl_value_new_int(stop / GST_MSECOND));
      send_event(inst, event);
    }
  }
  gst_query_unref(query);

  return G_SOURCE_CONTINUE;
}

// =============================================================================
// Public API
// =============================================================================

PlayerInstance* player_instance_new(FlTextureRegistrar* texture_registrar,
                                     FlEventChannel* event_channel,
                                     const gchar* uri) {
  auto* inst = g_new0(PlayerInstance, 1);
  inst->texture_registrar = FL_TEXTURE_REGISTRAR(g_object_ref(texture_registrar));
  inst->event_channel = event_channel ? FL_EVENT_CHANNEL(g_object_ref(event_channel)) : nullptr;
  inst->speed = 1.0;
  inst->is_looping = FALSE;
  inst->is_initialized = FALSE;
  inst->is_disposed = FALSE;

  // Create texture
  inst->texture = AV_PIP_TEXTURE(g_object_new(av_pip_texture_get_type(), nullptr));
  fl_texture_registrar_register_texture(texture_registrar, FL_TEXTURE(inst->texture));
  inst->texture_id = fl_texture_get_id(FL_TEXTURE(inst->texture));

  // Create GStreamer pipeline
  inst->pipeline = gst_element_factory_make("playbin", nullptr);

  // Build video sink: videoconvert ! video/x-raw,format=RGBA ! appsink
  GstElement* convert = gst_element_factory_make("videoconvert", nullptr);
  inst->video_sink = gst_element_factory_make("appsink", nullptr);

  GstCaps* caps = gst_caps_new_simple("video/x-raw", "format", G_TYPE_STRING,
                                        "RGBA", nullptr);
  g_object_set(inst->video_sink,
               "caps", caps,
               "emit-signals", TRUE,
               "sync", TRUE,
               "max-buffers", 1,
               "drop", TRUE,
               nullptr);
  gst_caps_unref(caps);

  GstAppSinkCallbacks callbacks = {};
  callbacks.new_sample = on_new_sample;
  gst_app_sink_set_callbacks(GST_APP_SINK(inst->video_sink), &callbacks, inst,
                              nullptr);

  GstElement* bin = gst_bin_new("video_sink_bin");
  gst_bin_add_many(GST_BIN(bin), convert, inst->video_sink, nullptr);
  gst_element_link(convert, inst->video_sink);

  GstPad* pad = gst_element_get_static_pad(convert, "sink");
  GstPad* ghost = gst_ghost_pad_new("sink", pad);
  gst_element_add_pad(bin, ghost);
  gst_object_unref(pad);

  g_object_set(inst->pipeline, "uri", uri, "video-sink", bin, nullptr);

  // Watch bus messages on the default main context
  GstBus* bus = gst_element_get_bus(inst->pipeline);
  gst_bus_add_watch(bus, on_bus_message, inst);
  gst_object_unref(bus);

  // Preroll to PAUSED to get video info
  gst_element_set_state(inst->pipeline, GST_STATE_PAUSED);

  // Start position polling
  inst->position_timer_id = g_timeout_add(200, position_timer_cb, inst);

  return inst;
}

int64_t player_instance_get_texture_id(PlayerInstance* instance) {
  return instance->texture_id;
}

void player_instance_set_event_channel(PlayerInstance* instance,
                                        FlEventChannel* event_channel) {
  if (instance->event_channel != nullptr) {
    g_object_unref(instance->event_channel);
  }
  instance->event_channel =
      event_channel ? FL_EVENT_CHANNEL(g_object_ref(event_channel)) : nullptr;
}

void player_instance_play(PlayerInstance* instance) {
  gst_element_set_state(instance->pipeline, GST_STATE_PLAYING);
  if (instance->speed != 1.0) {
    gint64 pos_ns = 0;
    gst_element_query_position(instance->pipeline, GST_FORMAT_TIME, &pos_ns);
    gst_element_seek(instance->pipeline, instance->speed, GST_FORMAT_TIME,
                      static_cast<GstSeekFlags>(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_ACCURATE),
                      GST_SEEK_TYPE_SET, pos_ns,
                      GST_SEEK_TYPE_NONE, -1);
  }
}

void player_instance_pause(PlayerInstance* instance) {
  gst_element_set_state(instance->pipeline, GST_STATE_PAUSED);
}

void player_instance_seek_to(PlayerInstance* instance, int64_t position_ms) {
  gint64 pos_ns = position_ms * GST_MSECOND;
  gst_element_seek(instance->pipeline, instance->speed, GST_FORMAT_TIME,
                    static_cast<GstSeekFlags>(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_ACCURATE),
                    GST_SEEK_TYPE_SET, pos_ns,
                    GST_SEEK_TYPE_NONE, -1);
}

void player_instance_set_speed(PlayerInstance* instance, double speed) {
  instance->speed = speed;
  // Apply immediately if playing
  GstState state;
  gst_element_get_state(instance->pipeline, &state, nullptr, 0);
  if (state == GST_STATE_PLAYING) {
    gint64 pos_ns = 0;
    gst_element_query_position(instance->pipeline, GST_FORMAT_TIME, &pos_ns);
    gst_element_seek(instance->pipeline, speed, GST_FORMAT_TIME,
                      static_cast<GstSeekFlags>(GST_SEEK_FLAG_FLUSH | GST_SEEK_FLAG_ACCURATE),
                      GST_SEEK_TYPE_SET, pos_ns,
                      GST_SEEK_TYPE_NONE, -1);
  }
}

void player_instance_set_looping(PlayerInstance* instance, gboolean looping) {
  instance->is_looping = looping;
}

void player_instance_set_volume(PlayerInstance* instance, double volume) {
  if (volume < 0.0) volume = 0.0;
  if (volume > 1.0) volume = 1.0;
  g_object_set(instance->pipeline, "volume", volume, nullptr);
}

void player_instance_set_media_metadata(PlayerInstance* instance,
                                         const gchar* title,
                                         const gchar* artist,
                                         const gchar* album,
                                         const gchar* art_url) {
  g_free(instance->meta_title);
  g_free(instance->meta_artist);
  g_free(instance->meta_album);
  g_free(instance->meta_art_url);
  instance->meta_title = g_strdup(title);
  instance->meta_artist = g_strdup(artist);
  instance->meta_album = g_strdup(album);
  instance->meta_art_url = g_strdup(art_url);

  if (instance->mpris) {
    mpris_controller_set_metadata(instance->mpris, title, artist, album, art_url);
  }
}

void player_instance_set_notification_enabled(PlayerInstance* instance,
                                               gboolean enabled) {
  instance->notification_enabled = enabled;

  if (enabled && instance->mpris == nullptr) {
    instance->mpris = mpris_controller_new(mpris_command_cb, instance);
    if (instance->meta_title || instance->meta_artist) {
      mpris_controller_set_metadata(instance->mpris,
                                     instance->meta_title,
                                     instance->meta_artist,
                                     instance->meta_album,
                                     instance->meta_art_url);
    }
  } else if (!enabled && instance->mpris != nullptr) {
    mpris_controller_free(instance->mpris);
    instance->mpris = nullptr;
  }
}

void player_instance_dispose(PlayerInstance* instance) {
  if (instance == nullptr || instance->is_disposed) return;
  instance->is_disposed = TRUE;

  if (instance->position_timer_id > 0) {
    g_source_remove(instance->position_timer_id);
    instance->position_timer_id = 0;
  }

  if (instance->mpris != nullptr) {
    mpris_controller_free(instance->mpris);
    instance->mpris = nullptr;
  }

  if (instance->pipeline != nullptr) {
    gst_element_set_state(instance->pipeline, GST_STATE_NULL);
    // Remove bus watch
    GstBus* bus = gst_element_get_bus(instance->pipeline);
    if (bus != nullptr) {
      gst_bus_remove_watch(bus);
      gst_object_unref(bus);
    }
    gst_object_unref(instance->pipeline);
    instance->pipeline = nullptr;
  }

  if (instance->texture != nullptr) {
    fl_texture_registrar_unregister_texture(instance->texture_registrar,
                                             FL_TEXTURE(instance->texture));
    g_object_unref(instance->texture);
    instance->texture = nullptr;
  }

  g_object_unref(instance->texture_registrar);
  if (instance->event_channel != nullptr)
    g_object_unref(instance->event_channel);

  g_free(instance->meta_title);
  g_free(instance->meta_artist);
  g_free(instance->meta_album);
  g_free(instance->meta_art_url);

  g_free(instance);
}
