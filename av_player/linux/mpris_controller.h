#ifndef MPRIS_CONTROLLER_H_
#define MPRIS_CONTROLLER_H_

#include <flutter_linux/flutter_linux.h>
#include <gio/gio.h>

// Callback invoked when MPRIS receives a media command from the desktop.
// command: "play", "pause", "next", "previous", "seekTo", "stop"
// seek_position_ms: valid only when command is "seekTo"
typedef void (*MprisCommandCallback)(const gchar* command,
                                      gint64 seek_position_ms,
                                      gpointer user_data);

typedef struct _MprisController MprisController;

// Create a new MPRIS2 controller. Registers on the session D-Bus as
// org.mpris.MediaPlayer2.av_pip
MprisController* mpris_controller_new(MprisCommandCallback callback,
                                       gpointer user_data);

// Free the controller and unregister from D-Bus.
void mpris_controller_free(MprisController* controller);

// Update the MPRIS Metadata property.
void mpris_controller_set_metadata(MprisController* controller,
                                    const gchar* title,
                                    const gchar* artist,
                                    const gchar* album,
                                    const gchar* art_url);

// Update the PlaybackStatus property ("Playing", "Paused", "Stopped").
void mpris_controller_set_playback_status(MprisController* controller,
                                           const gchar* status);

// Update the Position property (microseconds, per MPRIS spec).
void mpris_controller_set_position(MprisController* controller,
                                    gint64 position_us);

#endif  // MPRIS_CONTROLLER_H_
