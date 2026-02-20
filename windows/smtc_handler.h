#ifndef SMTC_HANDLER_H_
#define SMTC_HANDLER_H_

#include <windows.h>
#include <systemmediatransportcontrolsinterop.h>
#include <windows.media.h>
#include <wrl.h>

#include <string>

#include "event_channel_handler.h"

// Wraps Windows SystemMediaTransportControls (SMTC) for media notification
// overlay (now-playing info, playback button handling).
class SmtcHandler {
 public:
  SmtcHandler();
  ~SmtcHandler();

  // Initialize SMTC for the given window. Returns true on success.
  bool Initialize(HWND hwnd, EventChannelHandler* event_handler);

  // Set now-playing metadata (title, artist, album).
  void SetMetadata(const std::string& title, const std::string& artist,
                   const std::string& album);

  // Update the displayed playback status.
  void SetPlaybackStatus(
      ABI::Windows::Media::MediaPlaybackStatus status);

  // Release all SMTC resources.
  void Dispose();

 private:
  // Button-pressed callback handler.
  HRESULT OnButtonPressed(
      ABI::Windows::Media::ISystemMediaTransportControls* sender,
      ABI::Windows::Media::ISystemMediaTransportControlsButtonPressedEventArgs*
          args);

  Microsoft::WRL::ComPtr<
      ABI::Windows::Media::ISystemMediaTransportControls>
      smtc_;
  EventRegistrationToken button_token_ = {};
  EventChannelHandler* event_handler_ = nullptr;
  bool initialized_ = false;
};

#endif  // SMTC_HANDLER_H_
