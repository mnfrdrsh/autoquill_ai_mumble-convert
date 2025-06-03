// permission_handler.h
#ifndef PERMISSION_HANDLER_H_
#define PERMISSION_HANDLER_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

class PermissionHandler {
 public:
  PermissionHandler(flutter::PluginRegistrarWindows* registrar);
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue>& method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);

 private:
  flutter::PluginRegistrarWindows* registrar_;
  void OpenMicrophoneSettings(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  // Add these:
  void CheckMicrophonePermission(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
  void RequestMicrophonePermission(std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

#endif  // PERMISSION_HANDLER_H_
