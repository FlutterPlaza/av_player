#include "include/av_player_windows/av_player_windows.h"

// This must be included before many other Windows headers.
#include <windows.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <map>
#include <memory>

namespace {

using flutter::EncodableValue;

class AvPlayerWindows : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  AvPlayerWindows();

  virtual ~AvPlayerWindows();

 private:
  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

// static
void AvPlayerWindows::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "av_player_windows",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<AvPlayerWindows>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

AvPlayerWindows::AvPlayerWindows() {}

AvPlayerWindows::~AvPlayerWindows() {}

void AvPlayerWindows::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("getPlatformName") == 0) {
    result->Success(EncodableValue("Windows"));
  }
  else {
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
