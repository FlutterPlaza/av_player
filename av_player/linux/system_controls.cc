#include "system_controls.h"

#include <pulse/pulseaudio.h>

#include <cmath>
#include <cstdio>
#include <cstring>
#include <dirent.h>

// =============================================================================
// Volume (PulseAudio synchronous API via pa_mainloop)
// =============================================================================

struct VolumeData {
  double volume;
  gboolean done;
};

static void sink_info_cb(pa_context* c, const pa_sink_info* info, int eol,
                         void* userdata) {
  if (eol > 0 || info == nullptr) return;
  auto* data = static_cast<VolumeData*>(userdata);
  pa_volume_t avg = pa_cvolume_avg(&info->volume);
  data->volume = static_cast<double>(avg) / PA_VOLUME_NORM;
  data->done = TRUE;
}

static void context_state_get_cb(pa_context* c, void* userdata) {
  pa_context_state_t state = pa_context_get_state(c);
  if (state == PA_CONTEXT_READY) {
    auto* data = static_cast<VolumeData*>(userdata);
    pa_context_get_sink_info_by_name(c, "@DEFAULT_SINK@", sink_info_cb, data);
  } else if (state == PA_CONTEXT_FAILED || state == PA_CONTEXT_TERMINATED) {
    auto* data = static_cast<VolumeData*>(userdata);
    data->done = TRUE;
  }
}

double system_controls_get_volume() {
  VolumeData data = {0.0, FALSE};

  pa_mainloop* ml = pa_mainloop_new();
  pa_mainloop_api* api = pa_mainloop_get_api(ml);
  pa_context* ctx = pa_context_new(api, "av_pip_volume");
  pa_context_set_state_callback(ctx, context_state_get_cb, &data);
  pa_context_connect(ctx, nullptr, PA_CONTEXT_NOFLAGS, nullptr);

  while (!data.done) {
    pa_mainloop_iterate(ml, 1, nullptr);
  }

  pa_context_disconnect(ctx);
  pa_context_unref(ctx);
  pa_mainloop_free(ml);

  return data.volume;
}

struct SetVolumeData {
  double volume;
  gboolean done;
};

static void set_volume_success_cb(pa_context* c, int success, void* userdata) {
  auto* data = static_cast<SetVolumeData*>(userdata);
  data->done = TRUE;
}

static void context_state_set_cb(pa_context* c, void* userdata) {
  pa_context_state_t state = pa_context_get_state(c);
  if (state == PA_CONTEXT_READY) {
    auto* data = static_cast<SetVolumeData*>(userdata);
    pa_cvolume cv;
    pa_cvolume_set(&cv, 2, static_cast<pa_volume_t>(data->volume * PA_VOLUME_NORM));
    pa_context_set_sink_volume_by_name(c, "@DEFAULT_SINK@", &cv,
                                        set_volume_success_cb, data);
  } else if (state == PA_CONTEXT_FAILED || state == PA_CONTEXT_TERMINATED) {
    auto* data = static_cast<SetVolumeData*>(userdata);
    data->done = TRUE;
  }
}

void system_controls_set_volume(double volume) {
  if (volume < 0.0) volume = 0.0;
  if (volume > 1.0) volume = 1.0;

  SetVolumeData data = {volume, FALSE};

  pa_mainloop* ml = pa_mainloop_new();
  pa_mainloop_api* api = pa_mainloop_get_api(ml);
  pa_context* ctx = pa_context_new(api, "av_pip_volume");
  pa_context_set_state_callback(ctx, context_state_set_cb, &data);
  pa_context_connect(ctx, nullptr, PA_CONTEXT_NOFLAGS, nullptr);

  while (!data.done) {
    pa_mainloop_iterate(ml, 1, nullptr);
  }

  pa_context_disconnect(ctx);
  pa_context_unref(ctx);
  pa_mainloop_free(ml);
}

// =============================================================================
// Brightness (sysfs /sys/class/backlight)
// =============================================================================

static gboolean find_backlight_path(char* path_buf, size_t buf_size) {
  DIR* dir = opendir("/sys/class/backlight");
  if (dir == nullptr) return FALSE;

  struct dirent* entry;
  while ((entry = readdir(dir)) != nullptr) {
    if (entry->d_name[0] == '.') continue;
    snprintf(path_buf, buf_size, "/sys/class/backlight/%s", entry->d_name);
    closedir(dir);
    return TRUE;
  }
  closedir(dir);
  return FALSE;
}

static int read_sysfs_int(const char* path) {
  FILE* f = fopen(path, "r");
  if (f == nullptr) return -1;
  int value = 0;
  if (fscanf(f, "%d", &value) != 1) value = -1;
  fclose(f);
  return value;
}

static gboolean write_sysfs_int(const char* path, int value) {
  FILE* f = fopen(path, "w");
  if (f == nullptr) return FALSE;
  fprintf(f, "%d", value);
  fclose(f);
  return TRUE;
}

double system_controls_get_brightness() {
  char base[256];
  if (!find_backlight_path(base, sizeof(base))) return 0.5;

  char path[512];
  snprintf(path, sizeof(path), "%s/brightness", base);
  int current = read_sysfs_int(path);

  snprintf(path, sizeof(path), "%s/max_brightness", base);
  int max_val = read_sysfs_int(path);

  if (current < 0 || max_val <= 0) return 0.5;
  return static_cast<double>(current) / max_val;
}

void system_controls_set_brightness(double brightness) {
  if (brightness < 0.0) brightness = 0.0;
  if (brightness > 1.0) brightness = 1.0;

  char base[256];
  if (!find_backlight_path(base, sizeof(base))) return;

  char path[512];
  snprintf(path, sizeof(path), "%s/max_brightness", base);
  int max_val = read_sysfs_int(path);
  if (max_val <= 0) return;

  int target = static_cast<int>(round(brightness * max_val));

  snprintf(path, sizeof(path), "%s/brightness", base);
  write_sysfs_int(path, target);
}

// =============================================================================
// Wakelock (D-Bus org.freedesktop.ScreenSaver.Inhibit / UnInhibit)
// =============================================================================

static guint32 wakelock_cookie = 0;

void system_controls_set_wakelock(gboolean enabled) {
  g_autoptr(GError) error = nullptr;
  g_autoptr(GDBusConnection) conn =
      g_bus_get_sync(G_BUS_TYPE_SESSION, nullptr, &error);
  if (conn == nullptr) return;

  if (enabled && wakelock_cookie == 0) {
    g_autoptr(GVariant) result = g_dbus_connection_call_sync(
        conn,
        "org.freedesktop.ScreenSaver",
        "/org/freedesktop/ScreenSaver",
        "org.freedesktop.ScreenSaver",
        "Inhibit",
        g_variant_new("(ss)", "av_player", "Video playback"),
        G_VARIANT_TYPE("(u)"),
        G_DBUS_CALL_FLAGS_NONE,
        -1,
        nullptr,
        &error);
    if (result != nullptr) {
      g_variant_get(result, "(u)", &wakelock_cookie);
    }
  } else if (!enabled && wakelock_cookie != 0) {
    g_dbus_connection_call_sync(
        conn,
        "org.freedesktop.ScreenSaver",
        "/org/freedesktop/ScreenSaver",
        "org.freedesktop.ScreenSaver",
        "UnInhibit",
        g_variant_new("(u)", wakelock_cookie),
        nullptr,
        G_DBUS_CALL_FLAGS_NONE,
        -1,
        nullptr,
        &error);
    wakelock_cookie = 0;
  }
}
