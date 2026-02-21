#include "include/av_player_windows/av_player_windows.h"

// This must be included before many other Windows headers.
#include <windows.h>

// COM / WASAPI for system volume
#include <endpointvolume.h>
#include <mmdeviceapi.h>

// Monitor brightness
#include <highlevelmonitorconfigurationapi.h>
#include <physicalmonitorenumerationapi.h>

#include <d3d11.h>

#include <flutter/event_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>
#include <string>

#include "event_channel_handler.h"
#include "media_player.h"
#include "messages.g.h"
#include "smtc_handler.h"

#pragma comment(lib, "ole32.lib")
#pragma comment(lib, "Dxva2.lib")
#pragma comment(lib, "d3d11.lib")

namespace {

static const char kEventChannelPrefix[] =
    "com.flutterplaza.av_player_windows/events/";

// =============================================================================
// System volume (WASAPI / COM)
// =============================================================================

static double GetSystemVolumeLevel() {
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

static void SetSystemVolumeLevel(double volume) {
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

static double GetScreenBrightnessLevel() {
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

static void SetScreenBrightnessLevel(double brightness) {
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

static void SetWakelockState(bool enabled) {
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

class AvPlayerWindows : public flutter::Plugin,
                        public av_player_windows::AvPlayerHostApi {
 public:
  static void RegisterWithRegistrar(
      flutter::PluginRegistrarWindows* registrar);

  explicit AvPlayerWindows(flutter::PluginRegistrarWindows* registrar);
  ~AvPlayerWindows() override;

  // av_player_windows::AvPlayerHostApi implementation
  void Create(
      const av_player_windows::VideoSourceMessage& source,
      std::function<void(av_player_windows::ErrorOr<int64_t> reply)> result)
      override;
  void Dispose(
      int64_t player_id,
      std::function<void(std::optional<av_player_windows::FlutterError> reply)>
          result) override;
  void Play(
      int64_t player_id,
      std::function<void(std::optional<av_player_windows::FlutterError> reply)>
          result) override;
  void Pause(
      int64_t player_id,
      std::function<void(std::optional<av_player_windows::FlutterError> reply)>
          result) override;
  void SeekTo(
      int64_t player_id,
      int64_t position_ms,
      std::function<void(std::optional<av_player_windows::FlutterError> reply)>
          result) override;
  void SetPlaybackSpeed(
      int64_t player_id,
      double speed,
      std::function<void(std::optional<av_player_windows::FlutterError> reply)>
          result) override;
  void SetLooping(
      int64_t player_id,
      bool looping,
      std::function<void(std::optional<av_player_windows::FlutterError> reply)>
          result) override;
  void SetVolume(
      int64_t player_id,
      double volume,
      std::function<void(std::optional<av_player_windows::FlutterError> reply)>
          result) override;
  void IsPipAvailable(
      std::function<void(av_player_windows::ErrorOr<bool> reply)> result)
      override;
  void EnterPip(
      const av_player_windows::EnterPipRequest& request,
      std::function<void(std::optional<av_player_windows::FlutterError> reply)>
          result) override;
  void ExitPip(
      int64_t player_id,
      std::function<void(std::optional<av_player_windows::FlutterError> reply)>
          result) override;
  void SetMediaMetadata(
      const av_player_windows::MediaMetadataRequest& request,
      std::function<void(std::optional<av_player_windows::FlutterError> reply)>
          result) override;
  void SetNotificationEnabled(
      int64_t player_id,
      bool enabled,
      std::function<void(std::optional<av_player_windows::FlutterError> reply)>
          result) override;
  void SetSystemVolume(
      double volume,
      std::function<void(std::optional<av_player_windows::FlutterError> reply)>
          result) override;
  void GetSystemVolume(
      std::function<void(av_player_windows::ErrorOr<double> reply)> result)
      override;
  void SetScreenBrightness(
      double brightness,
      std::function<void(std::optional<av_player_windows::FlutterError> reply)>
          result) override;
  void GetScreenBrightness(
      std::function<void(av_player_windows::ErrorOr<double> reply)> result)
      override;
  void SetWakelock(
      bool enabled,
      std::function<void(std::optional<av_player_windows::FlutterError> reply)>
          result) override;
  void SetAbrConfig(
      const av_player_windows::SetAbrConfigRequest& request,
      std::function<void(std::optional<av_player_windows::FlutterError> reply)>
          result) override;
  void GetDecoderInfo(
      int64_t player_id,
      std::function<void(av_player_windows::ErrorOr<av_player_windows::DecoderInfoMessage> reply)>
          result) override;

 private:
  // Build a URI from the VideoSourceMessage.
  std::string BuildUri(const av_player_windows::VideoSourceMessage& source);

  // Get the top-level HWND for the Flutter window.
  HWND GetFlutterWindowHwnd();

  flutter::PluginRegistrarWindows* registrar_;

  // Player instances keyed by texture ID.
  std::map<int64_t, std::unique_ptr<MediaPlayer>> players_;

  // Event channel handlers keyed by texture ID.
  std::map<int64_t, std::unique_ptr<EventChannelHandler>> event_handlers_;

  // SMTC handlers keyed by texture ID.
  std::map<int64_t, std::unique_ptr<SmtcHandler>> smtc_handlers_;

  // Memory pressure monitoring
  HANDLE memory_notification_handle_ = nullptr;
  HANDLE memory_thread_handle_ = nullptr;
  bool memory_thread_running_ = false;
};

// static
void AvPlayerWindows::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto plugin = std::make_unique<AvPlayerWindows>(registrar);

  auto* plugin_pointer = plugin.get();
  av_player_windows::AvPlayerHostApi::SetUp(registrar->messenger(),
                                            plugin_pointer);

  registrar->AddPlugin(std::move(plugin));
}

AvPlayerWindows::AvPlayerWindows(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {
  CoInitializeEx(nullptr, COINIT_APARTMENTTHREADED);
  // Set up memory pressure monitoring
  memory_notification_handle_ =
      CreateMemoryResourceNotification(LowMemoryResourceNotification);
  if (memory_notification_handle_) {
    memory_thread_running_ = true;
    memory_thread_handle_ = CreateThread(
        nullptr, 0,
        [](LPVOID param) -> DWORD {
          auto* self = static_cast<AvPlayerWindows*>(param);
          while (self->memory_thread_running_) {
            DWORD wait_result = WaitForSingleObject(
                self->memory_notification_handle_, 5000);
            if (wait_result == WAIT_OBJECT_0 && self->memory_thread_running_) {
              // Low memory detected — post event to all players on main thread
              for (auto& pair : self->event_handlers_) {
                auto* handler = pair.second.get();
                if (handler) {
                  flutter::EncodableMap event;
                  event[flutter::EncodableValue("type")] =
                      flutter::EncodableValue("memoryPressure");
                  event[flutter::EncodableValue("level")] =
                      flutter::EncodableValue("critical");
                  handler->SendEvent(flutter::EncodableValue(event));
                }
              }
            }
          }
          return 0;
        },
        this, 0, nullptr);
  }
}

AvPlayerWindows::~AvPlayerWindows() {
  // Stop memory pressure monitoring
  memory_thread_running_ = false;
  if (memory_notification_handle_) {
    // Wake the thread so it can exit
    CloseHandle(memory_notification_handle_);
    memory_notification_handle_ = nullptr;
  }
  if (memory_thread_handle_) {
    WaitForSingleObject(memory_thread_handle_, 2000);
    CloseHandle(memory_thread_handle_);
    memory_thread_handle_ = nullptr;
  }
  smtc_handlers_.clear();
  players_.clear();
  event_handlers_.clear();
  CoUninitialize();
}

HWND AvPlayerWindows::GetFlutterWindowHwnd() {
  return registrar_->GetView()->GetNativeWindow();
}

std::string AvPlayerWindows::BuildUri(
    const av_player_windows::VideoSourceMessage& source) {
  switch (source.type()) {
    case av_player_windows::SourceType::kNetwork: {
      const std::string* url = source.url();
      return url ? *url : "";
    }
    case av_player_windows::SourceType::kFile: {
      const std::string* file_path = source.file_path();
      return file_path ? "file:///" + *file_path : "";
    }
    case av_player_windows::SourceType::kAsset: {
      const std::string* asset_path = source.asset_path();
      if (!asset_path) return "";
      // Assets are bundled relative to the executable in the
      // data/flutter_assets directory.
      char exe_path[MAX_PATH];
      GetModuleFileNameA(nullptr, exe_path, MAX_PATH);
      std::string exe_dir(exe_path);
      size_t last_sep = exe_dir.find_last_of("\\/");
      if (last_sep != std::string::npos) {
        exe_dir = exe_dir.substr(0, last_sep);
      }
      return "file:///" + exe_dir + "/data/flutter_assets/" + *asset_path;
    }
    default:
      return "";
  }
}

// =============================================================================
// AvPlayerHostApi implementation
// =============================================================================

void AvPlayerWindows::Create(
    const av_player_windows::VideoSourceMessage& source,
    std::function<void(av_player_windows::ErrorOr<int64_t> reply)> result) {
  std::string uri = BuildUri(source);
  if (uri.empty()) {
    result(av_player_windows::FlutterError("INVALID_SOURCE",
                                           "Could not build URI from source."));
    return;
  }

  auto* texture_registrar = registrar_->texture_registrar();

  // Create MediaPlayer without event handler first to get texture ID.
  auto player = std::unique_ptr<MediaPlayer>(
      new MediaPlayer(texture_registrar, nullptr));

  if (!player->Open(uri)) {
    result(av_player_windows::FlutterError("OPEN_FAILED",
                                           "Failed to open media source."));
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

  result(texture_id);
}

void AvPlayerWindows::Dispose(
    int64_t player_id,
    std::function<void(std::optional<av_player_windows::FlutterError> reply)>
        result) {
  smtc_handlers_.erase(player_id);
  auto it = players_.find(player_id);
  if (it != players_.end()) {
    it->second->Dispose();
    players_.erase(it);
  }
  event_handlers_.erase(player_id);
  result(std::nullopt);
}

void AvPlayerWindows::Play(
    int64_t player_id,
    std::function<void(std::optional<av_player_windows::FlutterError> reply)>
        result) {
  auto it = players_.find(player_id);
  if (it != players_.end()) {
    it->second->Play();
  }
  // Update SMTC playback status
  auto smtc_it = smtc_handlers_.find(player_id);
  if (smtc_it != smtc_handlers_.end()) {
    smtc_it->second->SetPlaybackStatus(
        ABI::Windows::Media::MediaPlaybackStatus_Playing);
  }
  result(std::nullopt);
}

void AvPlayerWindows::Pause(
    int64_t player_id,
    std::function<void(std::optional<av_player_windows::FlutterError> reply)>
        result) {
  auto it = players_.find(player_id);
  if (it != players_.end()) {
    it->second->Pause();
  }
  // Update SMTC playback status
  auto smtc_it = smtc_handlers_.find(player_id);
  if (smtc_it != smtc_handlers_.end()) {
    smtc_it->second->SetPlaybackStatus(
        ABI::Windows::Media::MediaPlaybackStatus_Paused);
  }
  result(std::nullopt);
}

void AvPlayerWindows::SeekTo(
    int64_t player_id,
    int64_t position_ms,
    std::function<void(std::optional<av_player_windows::FlutterError> reply)>
        result) {
  auto it = players_.find(player_id);
  if (it != players_.end()) {
    it->second->SeekTo(position_ms);
  }
  result(std::nullopt);
}

void AvPlayerWindows::SetPlaybackSpeed(
    int64_t player_id,
    double speed,
    std::function<void(std::optional<av_player_windows::FlutterError> reply)>
        result) {
  auto it = players_.find(player_id);
  if (it != players_.end()) {
    it->second->SetPlaybackSpeed(speed);
  }
  result(std::nullopt);
}

void AvPlayerWindows::SetLooping(
    int64_t player_id,
    bool looping,
    std::function<void(std::optional<av_player_windows::FlutterError> reply)>
        result) {
  auto it = players_.find(player_id);
  if (it != players_.end()) {
    it->second->SetLooping(looping);
  }
  result(std::nullopt);
}

void AvPlayerWindows::SetVolume(
    int64_t player_id,
    double volume,
    std::function<void(std::optional<av_player_windows::FlutterError> reply)>
        result) {
  auto it = players_.find(player_id);
  if (it != players_.end()) {
    it->second->SetVolume(volume);
  }
  result(std::nullopt);
}

void AvPlayerWindows::IsPipAvailable(
    std::function<void(av_player_windows::ErrorOr<bool> reply)> result) {
  result(false);
}

void AvPlayerWindows::EnterPip(
    const av_player_windows::EnterPipRequest& request,
    std::function<void(std::optional<av_player_windows::FlutterError> reply)>
        result) {
  // PIP is not available on Windows.
  result(std::nullopt);
}

void AvPlayerWindows::ExitPip(
    int64_t player_id,
    std::function<void(std::optional<av_player_windows::FlutterError> reply)>
        result) {
  // PIP is not available on Windows.
  result(std::nullopt);
}

void AvPlayerWindows::SetMediaMetadata(
    const av_player_windows::MediaMetadataRequest& request,
    std::function<void(std::optional<av_player_windows::FlutterError> reply)>
        result) {
  int64_t id = request.player_id();
  const av_player_windows::MediaMetadataMessage& metadata = request.metadata();

  auto smtc_it = smtc_handlers_.find(id);
  if (smtc_it != smtc_handlers_.end()) {
    std::string title = metadata.title() ? *metadata.title() : "";
    std::string artist = metadata.artist() ? *metadata.artist() : "";
    std::string album = metadata.album() ? *metadata.album() : "";
    smtc_it->second->SetMetadata(title, artist, album);
  }
  result(std::nullopt);
}

void AvPlayerWindows::SetNotificationEnabled(
    int64_t player_id,
    bool enabled,
    std::function<void(std::optional<av_player_windows::FlutterError> reply)>
        result) {
  if (enabled) {
    // Create SMTC handler if it doesn't exist
    if (smtc_handlers_.find(player_id) == smtc_handlers_.end()) {
      auto smtc = std::make_unique<SmtcHandler>();
      HWND hwnd = GetFlutterWindowHwnd();
      EventChannelHandler* handler = nullptr;
      auto eh_it = event_handlers_.find(player_id);
      if (eh_it != event_handlers_.end()) {
        handler = eh_it->second.get();
      }
      if (smtc->Initialize(hwnd, handler)) {
        smtc_handlers_[player_id] = std::move(smtc);
      }
    }
  } else {
    // Destroy SMTC handler
    smtc_handlers_.erase(player_id);
  }
  result(std::nullopt);
}

void AvPlayerWindows::SetSystemVolume(
    double volume,
    std::function<void(std::optional<av_player_windows::FlutterError> reply)>
        result) {
  SetSystemVolumeLevel(volume);
  result(std::nullopt);
}

void AvPlayerWindows::GetSystemVolume(
    std::function<void(av_player_windows::ErrorOr<double> reply)> result) {
  result(GetSystemVolumeLevel());
}

void AvPlayerWindows::SetScreenBrightness(
    double brightness,
    std::function<void(std::optional<av_player_windows::FlutterError> reply)>
        result) {
  SetScreenBrightnessLevel(brightness);
  result(std::nullopt);
}

void AvPlayerWindows::GetScreenBrightness(
    std::function<void(av_player_windows::ErrorOr<double> reply)> result) {
  result(GetScreenBrightnessLevel());
}

void AvPlayerWindows::SetWakelock(
    bool enabled,
    std::function<void(std::optional<av_player_windows::FlutterError> reply)>
        result) {
  SetWakelockState(enabled);
  result(std::nullopt);
}

void AvPlayerWindows::SetAbrConfig(
    const av_player_windows::SetAbrConfigRequest& request,
    std::function<void(std::optional<av_player_windows::FlutterError> reply)>
        result) {
  // Media Foundation has limited ABR control. Store config for reference.
  result(std::nullopt);
}

void AvPlayerWindows::GetDecoderInfo(
    int64_t player_id,
    std::function<void(av_player_windows::ErrorOr<av_player_windows::DecoderInfoMessage> reply)>
        result) {
  bool hw_accel = false;

  // Check if D3D11 video decode is available
  ID3D11Device* device = nullptr;
  D3D_FEATURE_LEVEL feature_level;
  HRESULT hr = D3D11CreateDevice(
      nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr, 0, nullptr, 0,
      D3D11_SDK_VERSION, &device, &feature_level, nullptr);
  if (SUCCEEDED(hr) && device) {
    ID3D11VideoDevice* video_device = nullptr;
    hr = device->QueryInterface(__uuidof(ID3D11VideoDevice),
                                reinterpret_cast<void**>(&video_device));
    if (SUCCEEDED(hr) && video_device) {
      hw_accel = true;
      video_device->Release();
    }
    device->Release();
  }

  av_player_windows::DecoderInfoMessage info(hw_accel);
  if (hw_accel) {
    info.set_decoder_name("D3D11");
  }
  result(info);
}

}  // namespace

void AvPlayerWindowsRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  AvPlayerWindows::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
