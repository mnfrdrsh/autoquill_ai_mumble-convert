// permission_handler.cpp
#include "permission_handler.h"
#include <windows.h>
#include <shellapi.h>
#include <mmdeviceapi.h>
#include <functiondiscoverykeys_devpkey.h>
#include <atlbase.h> // For CComPtr
#include <string> // Required for std::wstring, std::string

PermissionHandler::PermissionHandler(flutter::PluginRegistrarWindows* registrar)
    : registrar_(registrar) {}

// Helper function for opening settings URIs
static void OpenSettingsUri(const std::wstring& uri, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>>& result) {
    HINSTANCE S_instance = ShellExecute(NULL, L"open", uri.c_str(), NULL, NULL, SW_SHOWNORMAL);
    if ((INT_PTR)S_instance > 32) {
        result->Success(nullptr);
    } else {
        // Convert wstring to string for the error message
        std::string uri_str(uri.begin(), uri.end());
        result->Error("FAILED_TO_OPEN_SETTINGS", "Could not open settings URI: " + uri_str);
    }
}

void PermissionHandler::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue>& method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  const auto* args = std::get_if<flutter::EncodableMap>(method_call.arguments());
  std::string type = "";

  if (args) {
      auto type_it = args->find(flutter::EncodableValue("type"));
      if (type_it != args->end() && std::holds_alternative<std::string>(type_it->second)) {
        type = std::get<std::string>(type_it->second);
      } else {
         result->Error("INVALID_ARGUMENTS", "Missing or invalid 'type' argument for method: " + method_call.method_name());
         return;
      }
  } else {
       result->Error("INVALID_ARGUMENTS", "Arguments map is missing for method: " + method_call.method_name());
       return;
  }

  if (method_call.method_name().compare("openSystemPreferences") == 0) {
    if (type.compare("microphone") == 0) {
      OpenSettingsUri(L"ms-settings:privacy-microphone", result);
    } else if (type.compare("accessibility") == 0) {
      OpenSettingsUri(L"ms-settings:easeofaccess-keyboard", result);
    } else if (type.compare("screenRecording") == 0) {
      OpenSettingsUri(L"ms-settings:privacy-screencapture", result);
    } else {
      result->NotImplemented();
    }
  } else if (method_call.method_name().compare("checkPermission") == 0) {
    if (type.compare("microphone") == 0) {
      CheckMicrophonePermission(std::move(result));
    } else if (type.compare("accessibility") == 0) {
      result->Success(flutter::EncodableValue("authorized"));
    } else if (type.compare("screenRecording") == 0) {
      result->Success(flutter::EncodableValue("authorized"));
    } else {
      result->NotImplemented();
    }
  } else if (method_call.method_name().compare("requestPermission") == 0) {
    if (type.compare("microphone") == 0) {
      RequestMicrophonePermission(std::move(result));
    } else if (type.compare("accessibility") == 0) {
      result->Success(flutter::EncodableValue("authorized"));
    } else if (type.compare("screenRecording") == 0) {
      result->Success(flutter::EncodableValue("authorized"));
    } else {
      result->NotImplemented();
    }
  } else {
    result->NotImplemented();
  }
}

void PermissionHandler::CheckMicrophonePermission(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    HRESULT hr_coinit = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    // S_FALSE means already initialized, S_OK means successfully initialized.
    // RPC_E_CHANGED_MODE means initialized with a different concurrency model.
    // We proceed if S_OK or S_FALSE. Fail on RPC_E_CHANGED_MODE or other errors.
    if (FAILED(hr_coinit) && hr_coinit != S_FALSE && hr_coinit != RPC_E_CHANGED_MODE) {
        result->Error("COM_INIT_FAILED", "Failed to initialize COM library. Error code: " + std::to_string(hr_coinit));
        return;
    }
    // If RPC_E_CHANGED_MODE, it means COM was initialized by something else in a way that might conflict.
    // Depending on context, one might choose to fail here or proceed cautiously.
    // For this specific use case (audio enumeration), it's often fine, but good to be aware.
    // If it FAILED and it's not S_FALSE (already init) and not RPC_E_CHANGED_MODE (can sometimes be ignored), then it's a problem.
    // A more robust check: only proceed if (SUCCEEDED(hr_coinit) || hr_coinit == RPC_E_CHANGED_MODE)
    // For now, let's stick to the original logic: proceed if not FAILED or if FAILED but it's RPC_E_CHANGED_MODE (which is an error code, so FAILED(RPC_E_CHANGED_MODE) is true)
    // The provided code was: if (FAILED(hr) && hr != RPC_E_CHANGED_MODE)
    // Corrected logic: We should only uninitialize if CoInitializeEx returned S_OK.
    // If it returned S_FALSE or RPC_E_CHANGED_MODE, this call didn't initialize COM, so it shouldn't uninitialize it.

    CComPtr<IMMDeviceEnumerator> pEnumerator;
    HRESULT hr_create = CoCreateInstance(__uuidof(MMDeviceEnumerator), NULL, CLSCTX_ALL,
                          __uuidof(IMMDeviceEnumerator), (void**)&pEnumerator);

    if (FAILED(hr_create)) {
        if (hr_coinit == S_OK) CoUninitialize(); // Only uninitialize if this call initialized COM
        result->Error("ENUMERATOR_FAILED", "Failed to create device enumerator. Error code: " + std::to_string(hr_create));
        return;
    }

    CComPtr<IMMDeviceCollection> pCollection;
    HRESULT hr_enum = pEnumerator->EnumAudioEndpoints(eCapture, DEVICE_STATE_ACTIVE, &pCollection);

    if (FAILED(hr_enum)) {
        if (hr_coinit == S_OK) CoUninitialize();
        result->Error("ENUMERATION_FAILED", "Failed to enumerate audio endpoints. Error code: " + std::to_string(hr_enum));
        return;
    }

    UINT count = 0;
    if (pCollection) {
        HRESULT hr_count = pCollection->GetCount(&count);
        if (FAILED(hr_count)) {
            if (hr_coinit == S_OK) CoUninitialize();
            result->Error("GET_COUNT_FAILED", "Failed to get device count. Error code: " + std::to_string(hr_count));
            return;
        }
    }

    if (hr_coinit == S_OK) CoUninitialize(); // Only uninitialize if this call initialized COM

    if (count > 0) {
        result->Success(flutter::EncodableValue("authorized"));
    } else {
        result->Success(flutter::EncodableValue("denied"));
    }
}

void PermissionHandler::RequestMicrophonePermission(
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
    CheckMicrophonePermission(std::move(result));
}

void PermissionHandlerRegisterWithRegistrar(
    flutter::PluginRegistrarWindows* registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "com.autoquill.permissions",
          &flutter::StandardMethodCodec::GetInstance());

  auto handler = std::make_unique<PermissionHandler>(registrar);
  auto* handler_ptr = handler.get();

  channel->SetMethodCallHandler(
      [handler_ptr](const auto& call, auto result) {
        handler_ptr->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(handler));
}
