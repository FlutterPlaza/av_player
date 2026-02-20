#include "smtc_handler.h"

#include <windows.media.h>
#include <wrl.h>
#include <wrl/wrappers/corewrappers.h>

using namespace Microsoft::WRL;
using namespace Microsoft::WRL::Wrappers;
using namespace ABI::Windows::Media;

#pragma comment(lib, "RuntimeObject.lib")

// Helper: convert UTF-8 std::string to HSTRING.
static HRESULT Utf8ToHString(const std::string& str, HSTRING* out) {
  // Convert UTF-8 to wide string
  int wide_len = MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, nullptr, 0);
  if (wide_len == 0) return E_FAIL;
  std::wstring wide(wide_len - 1, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, str.c_str(), -1, &wide[0], wide_len);
  return WindowsCreateString(wide.c_str(), static_cast<UINT32>(wide.size()),
                              out);
}

SmtcHandler::SmtcHandler() = default;

SmtcHandler::~SmtcHandler() {
  Dispose();
}

bool SmtcHandler::Initialize(HWND hwnd, EventChannelHandler* event_handler) {
  if (initialized_) return true;
  event_handler_ = event_handler;

  // Get ISystemMediaTransportControlsInterop to obtain SMTC for our HWND
  ComPtr<ISystemMediaTransportControlsInterop> interop;
  HRESULT hr = Windows::Foundation::GetActivationFactory(
      HStringReference(
          RuntimeClass_Windows_Media_SystemMediaTransportControls)
          .Get(),
      &interop);
  if (FAILED(hr)) return false;

  hr = interop->GetForWindow(hwnd, IID_PPV_ARGS(&smtc_));
  if (FAILED(hr)) return false;

  // Enable the controls
  smtc_->put_IsEnabled(true);
  smtc_->put_IsPlayEnabled(true);
  smtc_->put_IsPauseEnabled(true);
  smtc_->put_IsNextEnabled(true);
  smtc_->put_IsPreviousEnabled(true);
  smtc_->put_IsStopEnabled(true);

  // Register button-pressed handler
  auto callback = Callback<
      ABI::Windows::Foundation::ITypedEventHandler<
          SystemMediaTransportControls*,
          SystemMediaTransportControlsButtonPressedEventArgs*>>(
      [this](ISystemMediaTransportControls* sender,
             ISystemMediaTransportControlsButtonPressedEventArgs* args)
          -> HRESULT { return OnButtonPressed(sender, args); });

  hr = smtc_->add_ButtonPressed(callback.Get(), &button_token_);
  if (FAILED(hr)) return false;

  initialized_ = true;
  return true;
}

void SmtcHandler::SetMetadata(const std::string& title,
                               const std::string& artist,
                               const std::string& album) {
  if (!smtc_) return;

  ComPtr<ISystemMediaTransportControlsDisplayUpdater> updater;
  HRESULT hr = smtc_->get_DisplayUpdater(&updater);
  if (FAILED(hr)) return;

  updater->put_Type(MediaPlaybackType_Music);

  ComPtr<IMusicDisplayProperties> music;
  hr = updater->get_MusicProperties(&music);
  if (FAILED(hr)) return;

  HSTRING h_title = nullptr;
  HSTRING h_artist = nullptr;
  HSTRING h_album = nullptr;

  if (SUCCEEDED(Utf8ToHString(title, &h_title))) {
    music->put_Title(h_title);
    WindowsDeleteString(h_title);
  }
  if (SUCCEEDED(Utf8ToHString(artist, &h_artist))) {
    music->put_Artist(h_artist);
    WindowsDeleteString(h_artist);
  }
  if (SUCCEEDED(Utf8ToHString(album, &h_album))) {
    music->put_AlbumArtist(h_album);
    WindowsDeleteString(h_album);
  }

  updater->Update();
}

void SmtcHandler::SetPlaybackStatus(MediaPlaybackStatus status) {
  if (!smtc_) return;
  smtc_->put_PlaybackStatus(status);
}

void SmtcHandler::Dispose() {
  if (smtc_ && initialized_) {
    smtc_->remove_ButtonPressed(button_token_);
    smtc_->put_IsEnabled(false);
  }
  smtc_.Reset();
  event_handler_ = nullptr;
  initialized_ = false;
}

HRESULT SmtcHandler::OnButtonPressed(
    ISystemMediaTransportControls* /*sender*/,
    ISystemMediaTransportControlsButtonPressedEventArgs* args) {
  if (!event_handler_) return S_OK;

  SystemMediaTransportControlsButton button;
  args->get_Button(&button);

  std::string command;
  switch (button) {
    case SystemMediaTransportControlsButton_Play:
      command = "play";
      break;
    case SystemMediaTransportControlsButton_Pause:
      command = "pause";
      break;
    case SystemMediaTransportControlsButton_Next:
      command = "next";
      break;
    case SystemMediaTransportControlsButton_Previous:
      command = "previous";
      break;
    case SystemMediaTransportControlsButton_Stop:
      command = "stop";
      break;
    default:
      return S_OK;
  }

  flutter::EncodableMap event;
  event[flutter::EncodableValue("type")] =
      flutter::EncodableValue("mediaCommand");
  event[flutter::EncodableValue("command")] =
      flutter::EncodableValue(command);
  event_handler_->SendEvent(event);

  return S_OK;
}
