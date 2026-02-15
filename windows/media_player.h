#ifndef MEDIA_PLAYER_H_
#define MEDIA_PLAYER_H_

#include <windows.h>
#include <mfapi.h>
#include <mfidl.h>
#include <mfmediaengine.h>

#include <flutter/texture_registrar.h>

#include <cstdint>
#include <functional>
#include <memory>
#include <mutex>
#include <string>
#include <vector>

#include "event_channel_handler.h"

// Callback type for player events sent to the Dart side.
using PlayerEventCallback = std::function<void(const flutter::EncodableMap&)>;

// Media Foundation-based video player that renders frames to a Flutter texture.
class MediaPlayer : public IMFMediaEngineNotify {
 public:
  MediaPlayer(flutter::TextureRegistrar* texture_registrar,
              EventChannelHandler* event_handler);
  ~MediaPlayer();

  // Open a media source (URL or file path).
  bool Open(const std::string& uri);

  // Playback control.
  void Play();
  void Pause();
  void SeekTo(int64_t position_ms);
  void SetPlaybackSpeed(double speed);
  void SetLooping(bool looping);
  void SetVolume(double volume);

  // Get the Flutter texture ID for this player.
  int64_t texture_id() const { return texture_id_; }

  // IUnknown
  STDMETHODIMP QueryInterface(REFIID riid, void** ppv) override;
  STDMETHODIMP_(ULONG) AddRef() override;
  STDMETHODIMP_(ULONG) Release() override;

  // IMFMediaEngineNotify
  STDMETHODIMP EventNotify(DWORD event, DWORD_PTR param1,
                            DWORD param2) override;

  // Dispose of all resources.
  void Dispose();

 private:
  void SendEvent(const std::string& type);
  void SendEvent(const std::string& type,
                 const flutter::EncodableMap& extra);
  void UpdateTexture();

  flutter::TextureRegistrar* texture_registrar_;
  EventChannelHandler* event_handler_;

  // Media Foundation
  IMFMediaEngine* media_engine_ = nullptr;
  IMFMediaEngineEx* media_engine_ex_ = nullptr;

  // Texture
  int64_t texture_id_ = -1;
  std::unique_ptr<flutter::TextureVariant> texture_;
  FlutterDesktopPixelBuffer pixel_buffer_ = {};
  std::vector<uint8_t> pixel_data_;
  std::mutex buffer_mutex_;

  // State
  bool looping_ = false;
  int video_width_ = 0;
  int video_height_ = 0;

  // COM ref count
  long ref_count_ = 1;
};

#endif  // MEDIA_PLAYER_H_
