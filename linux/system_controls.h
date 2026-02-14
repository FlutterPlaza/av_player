#ifndef SYSTEM_CONTROLS_H_
#define SYSTEM_CONTROLS_H_

#include <gio/gio.h>

// Volume control (PulseAudio)
double system_controls_get_volume();
void system_controls_set_volume(double volume);

// Screen brightness (sysfs)
double system_controls_get_brightness();
void system_controls_set_brightness(double brightness);

// Wakelock (D-Bus org.freedesktop.ScreenSaver)
void system_controls_set_wakelock(gboolean enabled);

#endif  // SYSTEM_CONTROLS_H_
