#include "include/av_player_windows/av_player_windows.h"

// This must be included before many other Windows headers.
#include <windows.h>

// COM / WASAPI for system volume
#include <endpointvolume.h>
#include <mmdeviceapi.h>

// Monitor brightness
#include <highlevelmonitorconfigurationapi.h>
#include <physicalmonitorenumerationapi.h>

#include <flutter/event_channel.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <string>

#include "event_channel_handler.h"
#include "media_player.h"
#include "smtc_handler.h"

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "Dxva2.lib")

namespace {

using flutter::EncodableMap;
using flutter::EncodableValue;

static const char kChannelName[] = "com.flutterplaza.av_player_windows";
static const char kEventChannelPrefix[] =
    "com.flutterplaza.av_player_windows/events/";

// =============================================================================
// Helper: extract typed values from EncodableMap
// =============================================================================

static int64_t GetInt(const EncodableMap& map, const char* key,
                      int64_t fallback = 0) {
  auto it = map.find(EncodableValue(std::string(key)));
  if (it != map.end()) {
    if (auto* val = std::get_if<int32_t>(&it->second))
      return static_cast<int64_t>(*val);
    if (auto* val = std::get_if<int64_t>(&it->second)) return *val;
  }
  return fallback;
}

static double GetDouble(const EncodableMap& map, const char* key,
                        double fallback = 0.0) {
  auto it = map.find(EncodableValue(std::string(key)));
  if (it != map.end()) {
    if (auto* val = std::get_if<double>(&it->second)) return *val;
    // Flutter sometimes sends int for doubles
    if (auto* val = std::get_if<int32_t>(&it->second))
      return static_cast<double>(*val);
    if (auto* val = std::get_if<int64_t>(&it->second))
      return static_cast<double>(*val);
  }
  return fallback;
}

static bool GetBool(const EncodableMap& map, const char* key,
                    bool fallback = false) {
  auto it = map.find(EncodableValue(std::string(key)));
  if (it != map.end()) {
    if (auto* val = std::get_if<bool>(&it->second)) return *val;
  }
  return fallback;
}

static std::string GetString(const EncodableMap& map, const char* key,
                             const std::string& fallback = "") {
  auto it = map.find(EncodableValue(std::string(key)));
  if (it != map.end()) {
    if (auto* val = std::get_if<std::string>(&it->second)) return *val;
  }
  return fallback;
}

// =============================================================================
// System volume (WASAPI / COM)
// =============================================================================

static double GetSystemVolume() {
  double volume = 0.0;
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  IMMDeviceEnumerator* enumerator = nullptr;
  HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                CLSCTX_ALL, __uuidof(IMMDeviceEnumerator),
                                reinterpret_cast<void**>(&enumerator));
  if (SUCCEEDED(hr)) {
    IMMDevice* device = nullptr;
    hr = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
    if (SUCCEEDED(hr)) {
      IAudioEndpointVolume* endpoint_volume = nullptr;
      hr = device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL,
                            nullptr,
                            reinterpret_cast<void**>(&endpoint_volume));
      if (SUCCEEDED(hr)) {
        float level = 0.0f;
        endpoint_volume->GetMasterVolumeLevelScalar(&level);
        volume = static_cast<double>(level);
        endpoint_volume->Release();
      }
      device->Release();
    }
    enumerator->Release();
  }

  CoUninitialize();
  return volume;
}

static void SetSystemVolume(double volume) {
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);

  IMMDeviceEnumerator* enumerator = nullptr;
  HRESULT hr = CoCreateInstance(__uuidof(MMDeviceEnumerator), nullptr,
                                CLSCTX_ALL, __uuidof(IMMDeviceEnumerator),
                                reinterpret_cast<void**>(&enumerator));
  if (SUCCEEDED(hr)) {
    IMMDevice* device = nullptr;
    hr = enumerator->GetDefaultAudioEndpoint(eRender, eConsole, &device);
    if (SUCCEEDED(hr)) {
      IAudioEndpointVolume* endpoint_volume = nullptr;
      hr = device->Activate(__uuidof(IAudioEndpointVolume), CLSCTX_ALL,
                            nullptr,
                            reinterpret_cast<void**>(&endpoint_volume));
      if (SUCCEEDED(hr)) {
        endpoint_volume->SetMasterVolumeLevelScalar(
            static_cast<float>(volume), nullptr);
        endpoint_volume->Release();
      }
      device->Release();
    }
    enumerator->Release();
  }

  CoUninitialize();
}

// =============================================================================
// Screen brightness (Monitor Configuration API)
// =============================================================================

static double GetScreenBrightness() {
  HMONITOR monitor =
      MonitorFromWindow(GetDesktopWindow(), MONITOR_DEFAULTTOPRIMARY);
  DWORD num_monitors = 0;
  if (!GetNumberOfPhysicalMonitorsFromHMONITOR(monitor, &num_monitors) ||
      num_monitors == 0) {
    return 0.5;  // fallback
  }

  std::vector<PHYSICAL_MONITOR> monitors(num_monitors);
  if (!GetPhysicalMonitorsFromHMONITOR(monitor, num_monitors,
                                        monitors.data())) {
    return 0.5;
  }

  DWORD min_brightness = 0, cur_brightness = 0, max_brightness = 100;
  double result = 0.5;
  if (GetMonitorBrightness(monitors[0].hPhysicalMonitor, &min_brightness,
                           &cur_brightness, &max_brightness)) {
    if (max_brightness > min_brightness) {
      result = static_cast<double>(cur_brightness - min_brightness) /
               static_cast<double>(max_brightness - min_brightness);
    }
  }

  DestroyPhysicalMonitors(num_monitors, monitors.data());
  return result;
}

static void SetScreenBrightness(double brightness) {
  HMONITOR monitor =
      MonitorFromWindow(GetDesktopWindow(), MONITOR_DEFAULTTOPRIMARY);
  DWORD num_monitors = 0;
  if (!GetNumberOfPhysicalMonitorsFromHMONITOR(monitor, &num_monitors) ||
      num_monitors == 0) {
    return;
  }

  std::vector<PHYSICAL_MONITOR> monitors(num_monitors);
  if (!GetPhysicalMonitorsFromHMONITOR(monitor, num_monitors,
                                        monitors.data())) {
    return;
  }

  DWORD min_brightness = 0, cur_brightness = 0, max_brightness = 100;
  if (GetMonitorBrightness(monitors[0].hPhysicalMonitor, &min_brightness,
                           &cur_brightness, &max_brightness)) {
    DWORD target = min_brightness +
                   static_cast<DWORD>(brightness *
                                      (max_brightness - min_brightness));
    SetMonitorBrightness(monitors[0].hPhysicalMonitor, target);
  }

  DestroyPhysicalMonitors(num_monitors, monitors.data());
}

// =============================================================================
// Wakelock
// =============================================================================

static void SetWakelock(bool enabled) {
  if (enabled) {
    SetThreadExecutionState(ES_CONTINUOUS | ES_DISPLAY_REQUIRED |
                            ES_SYSTEM_REQUIRED);
  } else {
    SetThreadExecutionState(ES_CONTINUOUS);
  }
}

// =============================================================================
// Plugin class
// =============================================================================

class AvPlayerWindows : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows* registrar);

  explicit AvPlayerWindows(flutter::PluginRegistrarWindows* registrar);
  ~AvPlayerWindows() override;

 private:
  void HandleMethodCall(
      const flutter::MethodCall<EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<EncodableValue>> result);

  // Build a URI from the source map.
  std::string BuildUri(const EncodableMap& args);

  // Get the top-level HWND for the Flutter window.
  HWND GetFlutterWindowHwnd();

  flutter::PluginRegistrarWindows* registrar_;

  // Player instances keyed by texture ID.
  std::map<int64_t, std::unique_ptr<MediaPlayer>> players_;

  // Event channel handlers keyed by texture ID.
  std::map<int64_t, std::unique_ptr<EventChannelHandler>> event_handlers_;

  // SMTC handlers keyed by texture ID.
  std::map<int64_t, std::unique_ptr<SmtcHandler>> smtc_handlers_;
};

// static
void AvPlayerWindows::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<EncodableValue>>(
          registrar->messenger(), kChannelName,
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<AvPlayerWindows>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto& call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

AvPlayerWindows::AvPlayerWindows(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
}

AvPlayerWindows::~AvPlayerWindows() {
  smtc_handlers_.clear();
  players_.clear();
  event_handlers_.clear();
  CoUninitialize();
}

HWND AvPlayerWindows::GetFlutterWindowHwnd() {
  return registrar_->GetView()->GetNativeWindow();
}

std::string AvPlayerWindows::BuildUri(const EncodableMap& args) {
  std::string type = GetString(args, "type", "network");

  if (type == "network") {
    return GetString(args, "url");
  } else if (type == "file") {
    return "file:///" + GetString(args, "filePath");
  } else if (type == "asset") {
    // Assets are bundled relative to the executable in the
    // data/flutter_assets directory.
    char exe_path[MAX_PATH];
    GetModuleFileNameA(nullptr, exe_path, MAX_PATH);
    std::string exe_dir(exe_path);
    size_t last_sep = exe_dir.find_last_of("\\/");
    if (last_sep != std::string::npos) {
      exe_dir = exe_dir.substr(0, last_sep);
    }
    return "file:///" + exe_dir + "/data/flutter_assets/" +
           GetString(args, "assetPath");
  }
  return "";
}

void AvPlayerWindows::HandleMethodCall(
    const flutter::MethodCall<EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<EncodableValue>> result) {
  const std::string& method = method_call.method_name();
  const auto* args_ptr = method_call.arguments();
  EncodableMap args;
  if (args_ptr) {
    if (auto* map = std::get_if<EncodableMap>(args_ptr)) {
      args = *map;
    }
  }

  // ---- Lifecycle ----

  if (method == "create") {
    std::string uri = BuildUri(args);
    if (uri.empty()) {
      result->Error("INVALID_SOURCE", "Could not build URI from source.");
      return;
    }

    auto* texture_registrar = registrar_->texture_registrar();

    // Create MediaPlayer without event handler first to get texture ID.
    auto player = std::unique_ptr<MediaPlayer>(
        new MediaPlayer(texture_registrar, nullptr));

    if (!player->Open(uri)) {
      result->Error("OPEN_FAILED", "Failed to open media source.");
      return;
    }

    int64_t texture_id = player->texture_id();

    // Now create the event channel with the correct name.
    std::string event_channel_name =
        std::string(kEventChannelPrefix) + std::to_string(texture_id);
    auto event_handler = std::make_unique<EventChannelHandler>(
        registrar_->messenger(), event_channel_name);

    // Wire the event handler into the player so events reach Dart.
    player->SetEventHandler(event_handler.get());

    event_handlers_[texture_id] = std::move(event_handler);
    players_[texture_id] = std::move(player);

    result->Success(EncodableValue(texture_id));

  } else if (method == "dispose") {
    int64_t id = GetInt(args, "playerId");
    smtc_handlers_.erase(id);
    auto it = players_.find(id);
    if (it != players_.end()) {
      it->second->Dispose();
      players_.erase(it);
    }
    event_handlers_.erase(id);
    result->Success();

  // ---- Playback ----

  } else if (method == "play") {
    int64_t id = GetInt(args, "playerId");
    auto it = players_.find(id);
    if (it != players_.end()) {
      it->second->Play();
    }
    // Update SMTC playback status
    auto smtc_it = smtc_handlers_.find(id);
    if (smtc_it != smtc_handlers_.end()) {
      smtc_it->second->SetPlaybackStatus(
          ABI::Windows::Media::MediaPlaybackStatus_Playing);
    }
    result->Success();

  } else if (method == "pause") {
    int64_t id = GetInt(args, "playerId");
    auto it = players_.find(id);
    if (it != players_.end()) {
      it->second->Pause();
    }
    // Update SMTC playback status
    auto smtc_it = smtc_handlers_.find(id);
    if (smtc_it != smtc_handlers_.end()) {
      smtc_it->second->SetPlaybackStatus(
          ABI::Windows::Media::MediaPlaybackStatus_Paused);
    }
    result->Success();

  } else if (method == "seekTo") {
    int64_t id = GetInt(args, "playerId");
    auto it = players_.find(id);
    if (it != players_.end()) {
      int64_t position = GetInt(args, "position");
      it->second->SeekTo(position);
    }
    result->Success();

  } else if (method == "setPlaybackSpeed") {
    int64_t id = GetInt(args, "playerId");
    auto it = players_.find(id);
    if (it != players_.end()) {
      double speed = GetDouble(args, "speed", 1.0);
      it->second->SetPlaybackSpeed(speed);
    }
    result->Success();

  } else if (method == "setLooping") {
    int64_t id = GetInt(args, "playerId");
    auto it = players_.find(id);
    if (it != players_.end()) {
      bool looping = GetBool(args, "looping");
      it->second->SetLooping(looping);
    }
    result->Success();

  } else if (method == "setVolume") {
    int64_t id = GetInt(args, "playerId");
    auto it = players_.find(id);
    if (it != players_.end()) {
      double volume = GetDouble(args, "volume", 1.0);
      it->second->SetVolume(volume);
    }
    result->Success();

  // ---- PIP (N/A on Windows) ----

  } else if (method == "isPipAvailable") {
    result->Success(EncodableValue(false));

  } else if (method == "enterPip" || method == "exitPip") {
    result->Success();

  // ---- System Controls ----

  } else if (method == "setSystemVolume") {
    double volume = GetDouble(args, "volume", 0.5);
    SetSystemVolume(volume);
    result->Success();

  } else if (method == "getSystemVolume") {
    result->Success(EncodableValue(GetSystemVolume()));

  } else if (method == "setScreenBrightness") {
    double brightness = GetDouble(args, "brightness", 0.5);
    SetScreenBrightness(brightness);
    result->Success();

  } else if (method == "getScreenBrightness") {
    result->Success(EncodableValue(GetScreenBrightness()));

  } else if (method == "setWakelock") {
    bool enabled = GetBool(args, "enabled");
    SetWakelock(enabled);
    result->Success();

  // ---- Media Session ----

  } else if (method == "setMediaMetadata") {
    int64_t id = GetInt(args, "playerId");
    std::string title = GetString(args, "title");
    std::string artist = GetString(args, "artist");
    std::string album = GetString(args, "album");

    auto smtc_it = smtc_handlers_.find(id);
    if (smtc_it != smtc_handlers_.end()) {
      smtc_it->second->SetMetadata(title, artist, album);
    }
    result->Success();

  } else if (method == "setNotificationEnabled") {
    int64_t id = GetInt(args, "playerId");
    bool enabled = GetBool(args, "enabled");

    if (enabled) {
      // Create SMTC handler if it doesn't exist
      if (smtc_handlers_.find(id) == smtc_handlers_.end()) {
        auto smtc = std::make_unique<SmtcHandler>();
        HWND hwnd = GetFlutterWindowHwnd();
        EventChannelHandler* handler = nullptr;
        auto eh_it = event_handlers_.find(id);
        if (eh_it != event_handlers_.end()) {
          handler = eh_it->second.get();
        }
        if (smtc->Initialize(hwnd, handler)) {
          smtc_handlers_[id] = std::move(smtc);
        }
      }
    } else {
      // Destroy SMTC handler
      smtc_handlers_.erase(id);
    }
    result->Success();

  // ---- Legacy ----

  } else if (method == "getPlatformName") {
    result->Success(EncodableValue("Windows"));

  } else {
    result->NotImplemented();
  }
}

}  // namespace

void AvPlayerWindowsRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  AvPlayerWindows::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
