// lib/overlay_main.dart
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'dart:convert'; // For decoding args if needed later
import 'package:shared_preferences/shared_preferences.dart'; // For saving position
import 'package:desktop_multi_window/desktop_multi_window.dart';
import 'package:flutter/services.dart'; // Required for MethodCall

// UserDefaults keys for position persistence from original Swift
const String _positionXKey = "RecordingOverlayPositionX";
const String _positionYKey = "RecordingOverlayPositionY";


void main(List<String> args) {
  WidgetsFlutterBinding.ensureInitialized();
  _initOverlayWindow(args); // Pass args
  runApp(OverlayApp(args: args)); // Pass args
}

Future<void> _initOverlayWindow(List<String> argsFromMain) async {
  await windowManager.ensureInitialized();

  // Try to load saved position
  final prefs = await SharedPreferences.getInstance();
  final double? savedX = prefs.getDouble(_positionXKey);
  final double? savedY = prefs.getDouble(_positionYKey);
  Offset? initialPosition;
  if (savedX != null && savedY != null) {
    initialPosition = Offset(savedX, savedY);
  }

  WindowOptions windowOptions = const WindowOptions(
    size: Size(380, 120),
    alwaysOnTop: true,
    skipTaskbar: true,
    titleBarStyle: TitleBarStyle.hidden,
  );

  windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.setAsFrameless();
    await windowManager.setHasShadow(false);
    await windowManager.setBackgroundColor(Colors.transparent);
    if (initialPosition != null) {
      await windowManager.setPosition(initialPosition);
    }
    await windowManager.show();
  });
}

class OverlayApp extends StatefulWidget {
  final List<String> args; // To receive arguments
  const OverlayApp({super.key, required this.args});

  @override
  State<OverlayApp> createState() => _OverlayAppState();
}

class _OverlayAppState extends State<OverlayApp> with WindowListener, TickerProviderStateMixin {
  // Default values, will be updated by _overlayData
  String _statusText = "REC ●";
  String _modeText = "Standard Mode";
  String? _finishHotkeyText = "Finish: Alt+Shift+Z";
  String? _cancelHotkeyText = "Cancel: Esc";

  late AnimationController _blinkAnimationController;
  bool _showRecStatus = true; // Controls visibility for blinking

  // Placeholder for data passed from main window via method channel
  // This will be updated by messages from the main app later
  Map<String, dynamic> _overlayData = {
    "statusText": "REC ●",
    "modeText": "Standard Mode",
    "finishHotkey": "Finish: Alt+Shift+Z",
    "cancelHotkey": "Cancel: Esc",
    "isRecording": true, // Default to recording for initial blink
  };


  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);

    _blinkAnimationController = AnimationController(
      duration: const Duration(milliseconds: 700), // Blinking speed
      vsync: this,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          if (mounted) { // Check if widget is still in the tree
            setState(() {
              _showRecStatus = false;
            });
          }
          _blinkAnimationController.reverse();
        } else if (status == AnimationStatus.dismissed) {
          if (mounted) {
            setState(() {
              _showRecStatus = true;
            });
          }
          _blinkAnimationController.forward();
        }
      });

    // Initialize state from _overlayData (which acts as initial data for now)
    _updateStateFromOverlayData();

    // Initialize state from _overlayData (which acts as initial data for now)
    _updateStateFromOverlayData(); // Initialize with default/passed data

    if (_overlayData['isRecording'] == true && _overlayData['statusText'].toString().contains("●")) {
      _blinkAnimationController.forward();
    }

    // Register the method call handler
    DesktopMultiWindow.setMethodCallHandler(_handleMethodCallFromMain);
  }

  Future<dynamic> _handleMethodCallFromMain(MethodCall call, int fromWindowId) async {
    if (!mounted) return null; // Ensure widget is still in the tree

    // ignore: avoid_print
    print("OverlayWindow received: ${call.method} with args ${call.arguments}");

    switch (call.method) {
      case "showOverlay":
        await windowManager.show();
        break;
      case "hideOverlay":
        await windowManager.hide();
        break;
      case "updateOverlayData":
        if (call.arguments is Map) {
          final data = Map<String, dynamic>.from(call.arguments as Map);
          // Update _overlayData selectively or fully
          _overlayData = data;
          _updateStateFromOverlayData(); // Call the existing method to update UI
        }
        break;
      default:
        // ignore: avoid_print
        print("OverlayWindow: Unknown method ${call.method}");
    }
    return null;
  }

  // Example method to update state from data (will be called by method channel handler)
  // _updateStateFromOverlayData method (ensure it handles nulls gracefully from new data)
  void _updateStateFromOverlayData() {
    if (!mounted) return;
    setState(() {
      _statusText = _overlayData['statusText'] as String? ?? "REC ●";
      _modeText = _overlayData['modeText'] as String? ?? "Standard Mode";
      _finishHotkeyText = _overlayData['finishHotkey'] as String?;
      _cancelHotkeyText = _overlayData['cancelHotkey'] as String?;

      bool isRecording = _overlayData['isRecording'] as bool? ?? false;
      bool statusIndicatesRec = _statusText.contains("●");

      if (isRecording && statusIndicatesRec) {
        if (!_blinkAnimationController.isAnimating) {
          _blinkAnimationController.forward();
        }
      } else {
        if (_blinkAnimationController.isAnimating) {
          _blinkAnimationController.stop();
          // _blinkAnimationController.reset(); // Consider if reset is always needed
        }
        _showRecStatus = true;
      }
    });
  }


  @override
  void dispose() {
    windowManager.removeListener(this);
    _blinkAnimationController.dispose();
    super.dispose();
  }

  @override
  void onWindowMoved() async {
    final prefs = await SharedPreferences.getInstance();
    final position = await windowManager.getPosition();
    await prefs.setDouble(_positionXKey, position.dx);
    await prefs.setDouble(_positionYKey, position.dy);
    // print("Overlay position saved: $position"); // For debugging
  }

  @override
  Widget build(BuildContext context) {
    // Determine color for status text based on blinking state or content
    Color statusColor = Colors.white; // Default
    if (_statusText.contains("●")) { // Blinking REC dot
        statusColor = _showRecStatus ? Colors.redAccent : Colors.transparent;
    } else if (_statusText.toLowerCase().contains("copied") ||
               _statusText.toLowerCase().contains("completed") ||
               _statusText.toLowerCase().contains("finished")) {
        statusColor = Colors.greenAccent;
    } else if (_statusText.toLowerCase().contains("error") ||
               _statusText.toLowerCase().contains("failed")) {
        statusColor = Colors.orangeAccent; // Or some other error indicator color
    }


    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: Colors.transparent,
        body: GestureDetector(
          onPanStart: (details) {
            windowManager.startDragging();
          },
          child: Container(
            width: 380,
            height: 120,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.75),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.3), width: 1),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                )
              ]
            ),
            child: Stack(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  // Remove MainAxisAlignment.center to allow Spacer to push modeText to bottom
                  children: [
                    const SizedBox(height: 20), // Space for close button or just top padding
                    Text(
                      _statusText,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      // mainAxisAlignment: MainAxisAlignment.spaceBetween, // Keep for spacing
                      children: [
                        if (_finishHotkeyText != null && _finishHotkeyText!.isNotEmpty)
                          Expanded(
                            child: Text(
                              _finishHotkeyText!,
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        // Add spacer only if both hotkeys are present and finishHotkey is not empty
                        if (_finishHotkeyText != null && _finishHotkeyText!.isNotEmpty &&
                            _cancelHotkeyText != null && _cancelHotkeyText!.isNotEmpty)
                          const SizedBox(width: 10),
                        if (_cancelHotkeyText != null && _cancelHotkeyText!.isNotEmpty)
                          // Removed Expanded here if finishHotkeyText might be empty.
                          // If finishHotkeyText can be empty, cancelHotkeyText should not expand to fill its space.
                          // If only one hotkey is shown, it can take more space or be centered.
                          // For now, let's assume if one is present, it's okay for it not to be Expanded if the other is missing.
                          // This might need more sophisticated layout logic based on which hotkeys are present.
                          Text(
                            _cancelHotkeyText!,
                            style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                    const Spacer(), // Pushes modeText to the bottom
                    Align(
                      alignment: Alignment.bottomRight,
                      child: Text(
                        _modeText,
                        style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 12),
                      ),
                    ),
                  ],
                ),
                Positioned(
                  top: 0,
                  right: 0,
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: () {
                        // ignore: avoid_print
                        print("Overlay close button clicked - sending 'overlayWantsToClose' to main app.");
                        // Send a message to the main window (windowId 0)
                        DesktopMultiWindow.invokeMethod(
                          0, // Target windowId, 0 is typically the main window
                          "overlayWantsToClose", // Method name
                          null // Arguments (if any)
                        );
                        // Optionally, hide the window immediately from the overlay side too
                        // windowManager.hide();
                        // The main window can also command it to hide after processing "overlayWantsToClose"
                      },
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, color: Colors.white, size: 16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
