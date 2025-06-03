import 'dart:async';
import 'package:flutter/foundation.dart';
// import 'package:flutter/services.dart'; // MethodChannel no longer used directly here
import '../../presentation/bloc/recording_bloc.dart';
import '../../../hotkeys/core/hotkey_handler.dart';
import '../../../../main.dart'; // To access flutterOverlayService

class RecordingOverlayPlatform {
  // static const MethodChannel _channel =
  //     MethodChannel('com.autoquill.recording_overlay'); // Old channel
  static Timer? _levelUpdateTimer;
  static RecordingBloc? _recordingBloc; // Still used for cancel, might need rethink

  // Flag to track if any recording is currently in progress
  static bool isRecordingInProgress = false;

  /// Shows the recording overlay
  static Future<void> showOverlay() async {
    await showOverlayWithModeAndHotkeys("Standard Mode", null, 'Esc');
  }

  /// Shows the recording overlay with a specific mode label
  static Future<void> showOverlayWithMode(String mode) async {
    await showOverlayWithModeAndHotkeys(mode, null, 'Esc');
  }

  /// Shows the recording overlay with a specific mode label and hotkey information
  static Future<void> showOverlayWithModeAndHotkeys(
      String mode, String? finishHotkey, String? cancelHotkey) async {
    try {
      isRecordingInProgress = true;
      await flutterOverlayService.updateData({
        "statusText": "REC ●", // Default status when showing
        "modeText": mode,
        "finishHotkey": finishHotkey,
        "cancelHotkey": cancelHotkey,
        "isRecording": true,
      });
      await flutterOverlayService.show();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to show overlay with mode and hotkeys: $e');
      }
    }
  }

  /// Sets the RecordingBloc instance for handling button actions
  static void setRecordingBloc(RecordingBloc bloc) {
    _recordingBloc = bloc;
    // Set up the method channel handler when a recording bloc is provided
    // _setupMethodHandler(); // Old handler no longer needed for Flutter overlay
  }

  /// Initialize the platform - should be called early in app lifecycle
  static void initialize() {
    // _setupMethodHandler(); // Old handler no longer needed
  }

  /// Sets up the method channel handler for button actions from the overlay window
  static void _setupMethodHandler() {
    // _channel.setMethodCallHandler((call) async {
    //   switch (call.method) {
    //     case 'pauseRecording':
    //       if (_recordingBloc != null) {
    //         _recordingBloc!.add(PauseRecording());
    //       }
    //       break;
    //     case 'resumeRecording':
    //       if (_recordingBloc != null) {
    //         _recordingBloc!.add(ResumeRecording());
    //       }
    //       break;
    //     case 'stopRecording':
    //       if (_recordingBloc != null) {
    //         _recordingBloc!.add(StopRecording());
    //       }
    //       break;
    //     case 'restartRecording':
    //       if (_recordingBloc != null) {
    //         _recordingBloc!.add(RestartRecording());
    //       }
    //       break;
    //     case 'cancelRecording':
    //       // Handle close button cancellation using the same logic as Esc key
    //       await _handleCloseButtonCancellation();
    //       break;
    //   }
    // });
  }

  /// Handles close button cancellation by delegating to the hotkey handler's logic
  /// This might still be relevant if the overlay close button action is routed here.
  /// However, the Flutter overlay's close button currently just hides itself.
  /// Proper cancellation should be triggered from the overlay to FlutterOverlayService,
  /// then to RecordingBloc.
  static Future<void> _handleCloseButtonCancellation() async {
    try {
      HotkeyHandler.handleRecordingCancellation();
      if (kDebugMode) {
        print('Close button cancellation handled via HotkeyHandler');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error handling close button cancellation: $e');
      }
    }
  }

  /// Hides the recording overlay
  static Future<void> hideOverlay() async {
    try {
      isRecordingInProgress = false;
      _stopSendingAudioLevels(); // Still relevant if audio levels are a separate concern
      await flutterOverlayService.hide();
    } catch (e) {
      if (kDebugMode) {
        print('Failed to hide overlay: $e');
      }
    }
  }

  /// Sets the overlay text to "Recording stopped"
  static Future<void> setRecordingStopped() async {
    try {
      await flutterOverlayService.updateData({
        "statusText": "Recording stopped.",
        "isRecording": false,
        // modeText, finishHotkey, cancelHotkey might need to be preserved or cleared
        // For now, only updating relevant fields.
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to set recording stopped state: $e');
      }
    }
  }

  /// Sets the overlay text to "Processing audio"
  static Future<void> setProcessingAudio() async {
    try {
      await flutterOverlayService.updateData({
        "statusText": "Processing audio...",
        "isRecording": false, // Or true if blinking should continue
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to set processing audio state: $e');
      }
    }
  }

  /// Sets the overlay text to "Transcription copied"
  static Future<void> setTranscriptionCompleted() async {
    try {
      await flutterOverlayService.updateData({
        "statusText": "Transcription copied!",
        "isRecording": false,
      });
    } catch (e) {
      if (kDebugMode) {
        print('Failed to set transcription completed state: $e');
      }
    }
  }

  /// Updates the audio level in the overlay
  static Future<void> updateAudioLevel(double level) async {
    // try {
    //   // Non-blocking update - fire and forget
    //   // _channel
    //   //     .invokeMethod('updateAudioLevel', {'level': level}).catchError((e) {
    //   //   // Silently ignore errors for audio level updates as they're frequent
    //   // });
    // } on PlatformException catch (e) {
    //   // Silently ignore
    // }
    // Feature removed for now as Flutter overlay doesn't handle this method.
    // Could be re-added by passing 'audioLevel' in updateData if overlay implements a visualizer.
  }

  /// Starts sending periodic audio level updates
  /// The audioLevelProvider function should return the current audio level (0.0 to 1.0)
  static void startSendingAudioLevels(
      Future<double> Function() audioLevelProvider) {
    _stopSendingAudioLevels();
    _levelUpdateTimer =
        Timer.periodic(const Duration(milliseconds: 200), (timer) async {
      try {
        final level = await audioLevelProvider();
        // updateAudioLevel(level); // Call to commented out method
      } catch (e) {
        // Silently ignore errors
      }
    });
  }

  /// Stops sending audio level updates
  static void _stopSendingAudioLevels() {
    _levelUpdateTimer?.cancel();
    _levelUpdateTimer = null;
  }
}
