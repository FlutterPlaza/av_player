#include "event_channel_handler.h"

#include <flutter/standard_method_codec.h>

EventChannelHandler::EventChannelHandler(
    flutter::BinaryMessenger* messenger,
    const std::string& channel_name) {
  channel_ = std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
      messenger, channel_name,
      &flutter::StandardMethodCodec::GetInstance());

  auto handler =
      std::make_unique<flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
          [this](const flutter::EncodableValue* arguments,
                 std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&&
                     events)
              -> std::unique_ptr<flutter::StreamHandlerError<
                  flutter::EncodableValue>> {
            std::lock_guard<std::mutex> lock(sink_mutex_);
            sink_ = std::move(events);
            return nullptr;
          },
          [this](const flutter::EncodableValue* arguments)
              -> std::unique_ptr<flutter::StreamHandlerError<
                  flutter::EncodableValue>> {
            std::lock_guard<std::mutex> lock(sink_mutex_);
            sink_.reset();
            return nullptr;
          });

  channel_->SetStreamHandler(std::move(handler));
}

EventChannelHandler::~EventChannelHandler() {
  std::lock_guard<std::mutex> lock(sink_mutex_);
  sink_.reset();
}

void EventChannelHandler::SendEvent(const flutter::EncodableMap& event) {
  std::lock_guard<std::mutex> lock(sink_mutex_);
  if (sink_) {
    sink_->Success(flutter::EncodableValue(event));
  }
}

void EventChannelHandler::SendError(const std::string& code,
                                     const std::string& message) {
  std::lock_guard<std::mutex> lock(sink_mutex_);
  if (sink_) {
    sink_->Error(code, message);
  }
}
