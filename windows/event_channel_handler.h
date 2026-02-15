#ifndef EVENT_CHANNEL_HANDLER_H_
#define EVENT_CHANNEL_HANDLER_H_

#include <flutter/encodable_value.h>
#include <flutter/event_channel.h>
#include <flutter/event_stream_handler_functions.h>

#include <functional>
#include <memory>
#include <mutex>
#include <string>

// Manages a per-player EventChannel and forwards events from the native
// MediaPlayer to the Dart side.
class EventChannelHandler {
 public:
  EventChannelHandler(flutter::BinaryMessenger* messenger,
                      const std::string& channel_name);
  ~EventChannelHandler();

  // Send an event map to the Dart side.  Thread-safe.
  void SendEvent(const flutter::EncodableMap& event);

  // Send an error to the Dart side.  Thread-safe.
  void SendError(const std::string& code, const std::string& message);

 private:
  std::unique_ptr<flutter::EventChannel<flutter::EncodableValue>> channel_;
  std::unique_ptr<flutter::EventSink<flutter::EncodableValue>> sink_;
  std::mutex sink_mutex_;
};

#endif  // EVENT_CHANNEL_HANDLER_H_
