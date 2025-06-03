// lib/core/services/flutter_overlay_service.dart
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'dart:convert';
import 'package:flutter/services.dart'; // Required for MethodCall

class FlutterOverlayService {
  int? _overlayWindowId;
  bool _isOverlayInitialized = false;
  bool _isCreatingOverlay = false; // Lock to prevent multiple creations

  Future<void> _ensureOverlayCreated() async {
    if (_overlayWindowId == null && !_isCreatingOverlay) {
      _isCreatingOverlay = true;
      try {
        // final allWindows = await DesktopMultiWindow.getAllSubWindowIds();
        // if (allWindows.isNotEmpty) {
        //   _overlayWindowId = allWindows.first;
        //   _isOverlayInitialized = true;
        //   print("FlutterOverlayService: Re-attaching to existing sub-window ID: $_overlayWindowId");
        // }
        // The re-attachment logic above is complex.
        // A simpler approach for now: always create if _overlayWindowId is null.

        if (_overlayWindowId == null) {
          final window = await DesktopMultiWindow.createWindow(jsonEncode({
            // Pass initial data if necessary, though overlay_main currently uses defaults
            // 'initialStatusText': 'Initializing...',
          }));
          _overlayWindowId = window.windowId;
          _isOverlayInitialized = true;
          // ignore: avoid_print
          print("FlutterOverlayService: Overlay window created with ID: $_overlayWindowId");
        }
      } finally {
        _isCreatingOverlay = false;
      }
    }
  }

  Future<dynamic> _handleMethodCallFromSubWindow(MethodCall call, int fromWindowId) async {
    if (fromWindowId == _overlayWindowId) { // Ensure message is from our known overlay
      if (call.method == "overlayWantsToClose") {
        // ignore: avoid_print
        print("FlutterOverlayService: Received 'overlayWantsToClose' from overlay window ID: $fromWindowId");

        // Hide the window from the main side as well, ensuring it's hidden
        await hide();

        // Reset internal state
        _overlayWindowId = null;
        _isOverlayInitialized = false; // Mark as not initialized so it can be recreated

        // IMPORTANT: Here, you would typically notify the relevant business logic
        // component (e.g., RecordingBloc, a Riverpod notifier, etc.)
        // that the recording/overlay action needs to be cancelled.
        // Example:
        // _recordingBloc.add(RecordingCancelledByOverlay());
        // ignore: avoid_print
        print("FlutterOverlayService: Recording cancellation logic should be triggered here.");
      }
      // Potentially handle other messages from the overlay in the future
    }
    return null;
  }

  Future<void> init() async {
    // Register handler for messages from any sub-window
    DesktopMultiWindow.setMethodCallHandler(_handleMethodCallFromSubWindow);
  }

  Future<void> show() async {
    await _ensureOverlayCreated();
    if (_overlayWindowId != null) {
      try {
        await DesktopMultiWindow.invokeMethod(_overlayWindowId!, "showOverlay", null);
      } catch (e) {
        // ignore: avoid_print
        print("FlutterOverlayService: Error showing overlay: $e. Re-creating.");
        _overlayWindowId = null; // Reset to allow re-creation
        _isOverlayInitialized = false;
        await _ensureOverlayCreated(); // Try creating again
        if (_overlayWindowId != null) { // If creation successful, try showing again
            await DesktopMultiWindow.invokeMethod(_overlayWindowId!, "showOverlay", null);
        }
      }
    }
  }

  Future<void> hide() async {
    if (_overlayWindowId != null && _isOverlayInitialized) {
      try {
        await DesktopMultiWindow.invokeMethod(_overlayWindowId!, "hideOverlay", null);
      } catch (e) {
        // ignore: avoid_print
        print("FlutterOverlayService: Error hiding overlay: $e. It might have been closed.");
        // If invoking hide fails, the window might have been closed. Reset state.
        _overlayWindowId = null;
        _isOverlayInitialized = false;
      }
    }
  }

  Future<void> updateData(Map<String, dynamic> data) async {
    await _ensureOverlayCreated();
    if (_overlayWindowId != null) {
      try {
        await DesktopMultiWindow.invokeMethod(_overlayWindowId!, "updateOverlayData", data);
      } catch (e) {
         // ignore: avoid_print
        print("FlutterOverlayService: Error updating overlay data: $e. Re-creating.");
        _overlayWindowId = null;
        _isOverlayInitialized = false;
        await _ensureOverlayCreated();
        if (_overlayWindowId != null) { // If creation successful, try updating again
            await DesktopMultiWindow.invokeMethod(_overlayWindowId!, "updateOverlayData", data);
        }
      }
    }
  }

  Future<void> closeOverlayWindow() async {
     if (_overlayWindowId != null && _isOverlayInitialized) {
         try {
            await DesktopMultiWindow.closeWindow(_overlayWindowId!);
         } catch (e) {
            // ignore: avoid_print
            print("FlutterOverlayService: Error closing overlay window: $e. It might have already been closed.");
         } finally {
            _overlayWindowId = null;
            _isOverlayInitialized = false;
            // ignore: avoid_print
            print("FlutterOverlayService: Overlay window state reset after close attempt.");
         }
     }
  }

  bool isInitialized() => _isOverlayInitialized;

  // Optional: A way to check if the overlay is currently "known" to be open
  // This doesn't guarantee it's visible, just that we have an ID.
  bool hasOverlayId() => _overlayWindowId != null;
}
