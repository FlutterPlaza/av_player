#ifndef PLAYER_INSTANCE_H_
#define PLAYER_INSTANCE_H_

#include <flutter_linux/flutter_linux.h>
#include <gst/gst.h>
#include <gst/app/gstappsink.h>

#include "mpris_controller.h"

// Opaque player instance managed by the main plugin.
typedef struct _PlayerInstance PlayerInstance;

// Create a new GStreamer-based player for the given URI.
// texture_registrar: used to register the FlPixelBufferTexture
// event_channel: may be nullptr initially (set later with setter)
PlayerInstance* player_instance_new(FlTextureRegistrar* texture_registrar,
                                     FlEventChannel* event_channel,
                                     const gchar* uri);

// Get the Flutter texture ID (set after registration).
int64_t player_instance_get_texture_id(PlayerInstance* instance);

// Set the event channel (call after getting texture_id to create correctly named channel).
void player_instance_set_event_channel(PlayerInstance* instance,
                                        FlEventChannel* event_channel);

// Playback control
void player_instance_play(PlayerInstance* instance);
void player_instance_pause(PlayerInstance* instance);
void player_instance_seek_to(PlayerInstance* instance, int64_t position_ms);
void player_instance_set_speed(PlayerInstance* instance, double speed);
void player_instance_set_looping(PlayerInstance* instance, gboolean looping);
void player_instance_set_volume(PlayerInstance* instance, double volume);

// Media metadata (delegates to MPRIS controller)
void player_instance_set_media_metadata(PlayerInstance* instance,
                                         const gchar* title,
                                         const gchar* artist,
                                         const gchar* album,
                                         const gchar* art_url);

// Enable/disable MPRIS notification
void player_instance_set_notification_enabled(PlayerInstance* instance,
                                               gboolean enabled);

// Dispose and free all resources.
void player_instance_dispose(PlayerInstance* instance);

#endif  // PLAYER_INSTANCE_H_
