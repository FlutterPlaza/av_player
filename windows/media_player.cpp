#include "media_player.h"

#include <mferror.h>
#include <mfmediaengine.h>

#include <sstream>

#pragma comment(lib, "Mfplat.lib")
#pragma comment(lib, "Mf.lib")
#pragma comment(lib, "Mfuuid.lib")
#pragma comment(lib, "d3d11.lib")
#pragma comment(lib, "dxgi.lib")

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
// SetEventHandler
// =============================================================================

void MediaPlayer::SetEventHandler(EventChannelHandler* handler) {
  event_handler_ = handler;
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

        // Create D3D11 textures for GPU-accelerated rendering
        if (video_width_ > 0 && video_height_ > 0) {
          CreateD3DTextures(video_width_, video_height_);
        }

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
        extra[flutter::EncodableValue("textureId")] =
            flutter::EncodableValue(texture_id_);
        SendEvent("initialized", extra);
      }
      break;
    }

    case MF_MEDIA_ENGINE_EVENT_PLAYING: {
      flutter::EncodableMap extra;
      extra[flutter::EncodableValue("state")] =
          flutter::EncodableValue("playing");
      SendEvent("playbackStateChanged", extra);
      break;
    }

    case MF_MEDIA_ENGINE_EVENT_PAUSE: {
      flutter::EncodableMap extra;
      extra[flutter::EncodableValue("state")] =
          flutter::EncodableValue("paused");
      SendEvent("playbackStateChanged", extra);
      break;
    }

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

    case MF_MEDIA_ENGINE_EVENT_BUFFERINGSTARTED: {
      flutter::EncodableMap extra;
      extra[flutter::EncodableValue("state")] =
          flutter::EncodableValue("buffering");
      SendEvent("playbackStateChanged", extra);
      break;
    }

    case MF_MEDIA_ENGINE_EVENT_BUFFERINGENDED:
      // No-op: PLAYING event will fire next and update state.
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

  // Initialize D3D11 device for hardware-accelerated video decoding
  D3D_FEATURE_LEVEL feature_level;
  UINT creation_flags = D3D11_CREATE_DEVICE_VIDEO_SUPPORT |
                        D3D11_CREATE_DEVICE_BGRA_SUPPORT;
  hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
                          creation_flags, nullptr, 0, D3D11_SDK_VERSION,
                          &d3d_device_, &feature_level, &d3d_context_);
  if (FAILED(hr)) {
    // Fallback without VIDEO_SUPPORT flag
    creation_flags = D3D11_CREATE_DEVICE_BGRA_SUPPORT;
    hr = D3D11CreateDevice(nullptr, D3D_DRIVER_TYPE_HARDWARE, nullptr,
                            creation_flags, nullptr, 0, D3D11_SDK_VERSION,
                            &d3d_device_, &feature_level, &d3d_context_);
    if (FAILED(hr)) return false;
  }

  // Enable multithread protection on the D3D device
  ID3D10Multithread* multithread = nullptr;
  hr = d3d_device_->QueryInterface(IID_PPV_ARGS(&multithread));
  if (SUCCEEDED(hr)) {
    multithread->SetMultithreadProtected(TRUE);
    multithread->Release();
  }

  // Create DXGI device manager for Media Foundation
  hr = MFCreateDXGIDeviceManager(&dxgi_reset_token_, &dxgi_manager_);
  if (FAILED(hr)) return false;

  hr = dxgi_manager_->ResetDevice(d3d_device_, dxgi_reset_token_);
  if (FAILED(hr)) return false;

  // Create Media Engine attributes
  IMFAttributes* attributes = nullptr;
  hr = MFCreateAttributes(&attributes, 4);
  if (FAILED(hr)) return false;

  hr = attributes->SetUnknown(MF_MEDIA_ENGINE_CALLBACK,
                               static_cast<IMFMediaEngineNotify*>(this));
  if (FAILED(hr)) {
    attributes->Release();
    return false;
  }

  // Set DXGI manager for hardware-accelerated decoding
  hr = attributes->SetUnknown(MF_MEDIA_ENGINE_DXGI_MANAGER, dxgi_manager_);
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

  // Convert URI to wide string using Win32 API (avoids deprecated codecvt)
  int wide_len =
      MultiByteToWideChar(CP_UTF8, 0, uri.c_str(), -1, nullptr, 0);
  if (wide_len == 0) return false;
  std::wstring wide_uri(wide_len - 1, L'\0');
  MultiByteToWideChar(CP_UTF8, 0, uri.c_str(), -1, &wide_uri[0], wide_len);

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
// D3D11 texture creation
// =============================================================================

bool MediaPlayer::CreateD3DTextures(int width, int height) {
  if (!d3d_device_) return false;

  // Release previous textures if any
  if (render_texture_) {
    render_texture_->Release();
    render_texture_ = nullptr;
  }
  if (staging_texture_) {
    staging_texture_->Release();
    staging_texture_ = nullptr;
  }

  // Render target texture (GPU renders video frames here)
  D3D11_TEXTURE2D_DESC render_desc = {};
  render_desc.Width = static_cast<UINT>(width);
  render_desc.Height = static_cast<UINT>(height);
  render_desc.MipLevels = 1;
  render_desc.ArraySize = 1;
  render_desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
  render_desc.SampleDesc.Count = 1;
  render_desc.Usage = D3D11_USAGE_DEFAULT;
  render_desc.BindFlags = D3D11_BIND_RENDER_TARGET;

  HRESULT hr = d3d_device_->CreateTexture2D(&render_desc, nullptr,
                                              &render_texture_);
  if (FAILED(hr)) return false;

  // Staging texture (CPU-readable, for copying pixels to Flutter buffer)
  D3D11_TEXTURE2D_DESC staging_desc = {};
  staging_desc.Width = static_cast<UINT>(width);
  staging_desc.Height = static_cast<UINT>(height);
  staging_desc.MipLevels = 1;
  staging_desc.ArraySize = 1;
  staging_desc.Format = DXGI_FORMAT_B8G8R8A8_UNORM;
  staging_desc.SampleDesc.Count = 1;
  staging_desc.Usage = D3D11_USAGE_STAGING;
  staging_desc.CPUAccessFlags = D3D11_CPU_ACCESS_READ;

  hr = d3d_device_->CreateTexture2D(&staging_desc, nullptr,
                                      &staging_texture_);
  if (FAILED(hr)) {
    render_texture_->Release();
    render_texture_ = nullptr;
    return false;
  }

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
  event[flutter::EncodableValue("type")] = flutter::EncodableValue(type);
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

    if (render_texture_ && staging_texture_ && d3d_context_) {
      // GPU path: render to D3D11 texture, then copy to CPU-readable staging
      HRESULT hr = media_engine_->TransferVideoFrame(
          render_texture_, &src, &dst, &border);
      if (FAILED(hr)) return;

      // Copy render texture to staging texture (GPU → CPU-accessible)
      d3d_context_->CopyResource(staging_texture_, render_texture_);

      // Map the staging texture to read pixels
      D3D11_MAPPED_SUBRESOURCE mapped = {};
      hr = d3d_context_->Map(staging_texture_, 0, D3D11_MAP_READ, 0, &mapped);
      if (SUCCEEDED(hr)) {
        std::lock_guard<std::mutex> lock(buffer_mutex_);
        const UINT dst_pitch = static_cast<UINT>(video_width_) * 4;
        const uint8_t* src_data = static_cast<const uint8_t*>(mapped.pData);
        for (int row = 0; row < video_height_; ++row) {
          memcpy(pixel_data_.data() + row * dst_pitch,
                 src_data + row * mapped.RowPitch, dst_pitch);
        }
        d3d_context_->Unmap(staging_texture_, 0);
      }
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

  // Release D3D11 resources
  if (staging_texture_) {
    staging_texture_->Release();
    staging_texture_ = nullptr;
  }
  if (render_texture_) {
    render_texture_->Release();
    render_texture_ = nullptr;
  }
  if (dxgi_manager_) {
    dxgi_manager_->Release();
    dxgi_manager_ = nullptr;
  }
  if (d3d_context_) {
    d3d_context_->Release();
    d3d_context_ = nullptr;
  }
  if (d3d_device_) {
    d3d_device_->Release();
    d3d_device_ = nullptr;
  }

  MFShutdown();
}
