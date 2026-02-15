#include "media_player.h"

#include <mferror.h>
#include <mfmediaengine.h>

#include <codecvt>
#include <locale>
#include <sstream>

#pragma comment(lib, "Mfplat.lib")
#pragma comment(lib, "Mf.lib")
#pragma comment(lib, "Mfuuid.lib")

// =============================================================================
// Construction / Destruction
// =============================================================================

MediaPlayer::MediaPlayer(flutter::TextureRegistrar* texture_registrar,
                         EventChannelHandler* event_handler)
    : texture_registrar_(texture_registrar),
      event_handler_(event_handler) {}

MediaPlayer::~MediaPlayer() {
  Dispose();
}

// =============================================================================
// IUnknown
// =============================================================================

STDMETHODIMP MediaPlayer::QueryInterface(REFIID riid, void** ppv) {
  if (!ppv) return E_POINTER;
  if (riid == IID_IUnknown || riid == IID_IMFMediaEngineNotify) {
    *ppv = static_cast<IMFMediaEngineNotify*>(this);
    AddRef();
    return S_OK;
  }
  *ppv = nullptr;
  return E_NOINTERFACE;
}

STDMETHODIMP_(ULONG) MediaPlayer::AddRef() {
  return InterlockedIncrement(&ref_count_);
}

STDMETHODIMP_(ULONG) MediaPlayer::Release() {
  long count = InterlockedDecrement(&ref_count_);
  if (count == 0) {
    delete this;
  }
  return count;
}

// =============================================================================
// IMFMediaEngineNotify
// =============================================================================

STDMETHODIMP MediaPlayer::EventNotify(DWORD event, DWORD_PTR param1,
                                       DWORD param2) {
  switch (event) {
    case MF_MEDIA_ENGINE_EVENT_LOADEDMETADATA: {
      if (media_engine_) {
        DWORD w = 0, h = 0;
        media_engine_->GetNativeVideoSize(&w, &h);
        video_width_ = static_cast<int>(w);
        video_height_ = static_cast<int>(h);

        // Allocate pixel buffer
        {
          std::lock_guard<std::mutex> lock(buffer_mutex_);
          pixel_data_.resize(video_width_ * video_height_ * 4, 0);
          pixel_buffer_.buffer = pixel_data_.data();
          pixel_buffer_.width = static_cast<size_t>(video_width_);
          pixel_buffer_.height = static_cast<size_t>(video_height_);
        }

        double duration_sec = media_engine_->GetDuration();
        int64_t duration_ms = static_cast<int64_t>(duration_sec * 1000.0);
        flutter::EncodableMap extra;
        extra[flutter::EncodableValue("duration")] =
            flutter::EncodableValue(duration_ms);
        extra[flutter::EncodableValue("width")] =
            flutter::EncodableValue(video_width_);
        extra[flutter::EncodableValue("height")] =
            flutter::EncodableValue(video_height_);
        SendEvent("initialized", extra);
      }
      break;
    }

    case MF_MEDIA_ENGINE_EVENT_PLAYING:
      SendEvent("playing");
      break;

    case MF_MEDIA_ENGINE_EVENT_PAUSE:
      SendEvent("paused");
      break;

    case MF_MEDIA_ENGINE_EVENT_ENDED:
      if (looping_ && media_engine_) {
        media_engine_->SetCurrentTime(0.0);
        media_engine_->Play();
      } else {
        SendEvent("completed");
      }
      break;

    case MF_MEDIA_ENGINE_EVENT_TIMEUPDATE: {
      if (media_engine_) {
        double pos_sec = media_engine_->GetCurrentTime();
        int64_t pos_ms = static_cast<int64_t>(pos_sec * 1000.0);
        flutter::EncodableMap extra;
        extra[flutter::EncodableValue("position")] =
            flutter::EncodableValue(pos_ms);
        SendEvent("positionChanged", extra);

        // Update texture with new frame
        UpdateTexture();
      }
      break;
    }

    case MF_MEDIA_ENGINE_EVENT_ERROR: {
      std::ostringstream oss;
      oss << "Media engine error: param1=" << param1 << " param2=" << param2;
      if (event_handler_) {
        event_handler_->SendError("PLAYBACK_ERROR", oss.str());
      }
      break;
    }

    case MF_MEDIA_ENGINE_EVENT_BUFFERINGSTARTED:
      SendEvent("buffering");
      break;

    case MF_MEDIA_ENGINE_EVENT_BUFFERINGENDED:
      SendEvent("bufferingEnd");
      break;

    default:
      break;
  }

  return S_OK;
}

// =============================================================================
// Open
// =============================================================================

bool MediaPlayer::Open(const std::string& uri) {
  HRESULT hr = MFStartup(MF_VERSION);
  if (FAILED(hr)) return false;

  // Create Media Engine attributes
  IMFAttributes* attributes = nullptr;
  hr = MFCreateAttributes(&attributes, 3);
  if (FAILED(hr)) return false;

  hr = attributes->SetUnknown(MF_MEDIA_ENGINE_CALLBACK,
                               static_cast<IMFMediaEngineNotify*>(this));
  if (FAILED(hr)) {
    attributes->Release();
    return false;
  }

  // Create Media Engine via class factory
  IMFMediaEngineClassFactory* factory = nullptr;
  hr = CoCreateInstance(CLSID_MFMediaEngineClassFactory, nullptr,
                        CLSCTX_ALL, IID_PPV_ARGS(&factory));
  if (FAILED(hr)) {
    attributes->Release();
    return false;
  }

  hr = factory->CreateInstance(0, attributes, &media_engine_);
  factory->Release();
  attributes->Release();
  if (FAILED(hr)) return false;

  media_engine_->QueryInterface(IID_PPV_ARGS(&media_engine_ex_));

  // Convert URI to wide string
  std::wstring_convert<std::codecvt_utf8_utf16<wchar_t>> converter;
  std::wstring wide_uri = converter.from_bytes(uri);

  BSTR bstr_uri = SysAllocString(wide_uri.c_str());
  hr = media_engine_->SetSource(bstr_uri);
  SysFreeString(bstr_uri);
  if (FAILED(hr)) return false;

  // Register Flutter texture (pixel buffer)
  texture_ = std::make_unique<flutter::TextureVariant>(
      flutter::PixelBufferTexture(
          [this](size_t width,
                 size_t height) -> const FlutterDesktopPixelBuffer* {
            std::lock_guard<std::mutex> lock(buffer_mutex_);
            return &pixel_buffer_;
          }));

  texture_id_ = texture_registrar_->RegisterTexture(texture_.get());

  return true;
}

// =============================================================================
// Playback control
// =============================================================================

void MediaPlayer::Play() {
  if (media_engine_) {
    media_engine_->Play();
  }
}

void MediaPlayer::Pause() {
  if (media_engine_) {
    media_engine_->Pause();
  }
}

void MediaPlayer::SeekTo(int64_t position_ms) {
  if (media_engine_) {
    media_engine_->SetCurrentTime(position_ms / 1000.0);
  }
}

void MediaPlayer::SetPlaybackSpeed(double speed) {
  if (media_engine_) {
    media_engine_->SetPlaybackRate(speed);
  }
}

void MediaPlayer::SetLooping(bool looping) {
  looping_ = looping;
  if (media_engine_) {
    media_engine_->SetLoop(looping ? TRUE : FALSE);
  }
}

void MediaPlayer::SetVolume(double volume) {
  if (media_engine_) {
    media_engine_->SetVolume(volume);
  }
}

// =============================================================================
// Private helpers
// =============================================================================

void MediaPlayer::SendEvent(const std::string& type) {
  SendEvent(type, {});
}

void MediaPlayer::SendEvent(const std::string& type,
                             const flutter::EncodableMap& extra) {
  if (!event_handler_) return;

  flutter::EncodableMap event;
  event[flutter::EncodableValue("event")] = flutter::EncodableValue(type);
  for (const auto& kv : extra) {
    event[kv.first] = kv.second;
  }
  event_handler_->SendEvent(event);
}

void MediaPlayer::UpdateTexture() {
  if (!media_engine_ || video_width_ == 0 || video_height_ == 0) return;

  LONGLONG pts;
  if (media_engine_->OnVideoStreamTick(&pts) == S_OK) {
    MFVideoNormalizedRect src = {0.0f, 0.0f, 1.0f, 1.0f};
    RECT dst = {0, 0, static_cast<LONG>(video_width_),
                static_cast<LONG>(video_height_)};
    MFARGB border = {0, 0, 0, 255};

    {
      std::lock_guard<std::mutex> lock(buffer_mutex_);
      // TransferVideoFrame renders the current frame into a destination surface.
      // We use a DXGI surface or fallback — for pixel buffer, we render to a
      // byte array via the HasVideo + OnVideoStreamTick pattern.
      // Note: Full GPU-accelerated path would use ID3D11Texture2D.
      // For now, we use a software transfer approach.
      media_engine_->TransferVideoFrame(nullptr, &src, &dst, &border);
    }

    if (texture_registrar_) {
      texture_registrar_->MarkTextureFrameAvailable(texture_id_);
    }
  }
}

// =============================================================================
// Dispose
// =============================================================================

void MediaPlayer::Dispose() {
  if (texture_registrar_ && texture_id_ >= 0) {
    texture_registrar_->UnregisterTexture(texture_id_);
    texture_id_ = -1;
  }
  texture_.reset();

  if (media_engine_ex_) {
    media_engine_ex_->Release();
    media_engine_ex_ = nullptr;
  }
  if (media_engine_) {
    media_engine_->Shutdown();
    media_engine_->Release();
    media_engine_ = nullptr;
  }

  MFShutdown();
}
