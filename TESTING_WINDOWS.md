# AutoQuill AI - Windows Port Testing Checklist

This document outlines the key areas to test for the Windows port of AutoQuill AI.

## 1. Installation (MSI Installer)

- [ ] **Install:** Does the MSI installer (created via `flutter_distributor`) install the application correctly?
- [ ] **Path:** Is the application installed in the expected directory (e.g., Program Files)?
- [ ] **Start Menu:** Is there a Start Menu entry created? Is it functional?
- [ ] **Add to PATH (Optional):** If the MSI was configured to add the app to PATH, does this work?
- [ ] **Uninstall:** Does uninstallation via "Add or remove programs" work cleanly and remove all installed files?

## 2. Application Launch & Basic Windowing

- [ ] **Main Window:** Does the main application window launch correctly?
- [ ] **Overlay Launch:** Does the Flutter-based overlay window launch when triggered (e.g., by starting a recording)?
- [ ] **Overlay Properties:** Is the overlay window frameless, always-on-top, and non-activating (doesn't steal focus)?
- [ ] **Overlay Dragging:** Can the overlay window be dragged to a new position?
- [ ] **Overlay Position Persistence:** Is the overlay window's position correctly saved after being moved and restored when the app (or overlay) restarts?
- [ ] **Overlay Close Button:** Does the overlay's close button work? Does it correctly signal the main app to cancel the current operation (e.g., stop recording)?

## 3. Core Transcription Modes

### Standard Transcription (e.g., Alt + Shift + Z)
- [ ] **Hotkey Start/Stop:** Does the configured hotkey correctly start and stop the recording?
- [ ] **Overlay Display:** Is the overlay displayed with the correct status ("REC ●", "Processing...", "Copied!"), mode text, and hotkey reminders?
- [ ] **Audio Capture & Transcription:** Is audio captured successfully and transcribed with acceptable accuracy?
- [ ] **Clipboard Copy:** Is the transcribed text automatically copied to the clipboard?
- [ ] **Auto-Pasting:** If a text field is focused when transcription completes, does the text paste automatically? (Test in multiple target applications)

### Push-to-Talk (e.g., Alt + Space)
- [ ] **Hotkey Record:** Does holding the hotkey start recording?
- [ ] **Release & Transcribe:** Does releasing the hotkey stop recording and trigger transcription?
- [ ] **Overlay Display (Hold):** Is the overlay displayed correctly while the hotkey is held?
- [ ] **Clipboard Copy:** Is the transcribed text copied to the clipboard upon release?

### AI Assistant Mode (e.g., Alt + Shift + S)
- [ ] **Context Capture:** Can text be selected in another application, and does pressing the hotkey correctly capture this selected text (likely via clipboard)?
- [ ] **Voice Instructions:** Can voice instructions be recorded after capturing text?
- [ ] **AI Processing:** Does the AI process the text based on voice instructions (e.g., summarize, rephrase)?
- [ ] **Result to Clipboard:** Is the processed text copied to the clipboard?

## 4. Permission Handling

### Microphone
- [ ] **Initial Access/Denial:** Test behavior when microphone access for the app is explicitly denied in Windows Settings (Privacy & Security > Microphone). Does the app handle this gracefully?
- [ ] **Guidance to Settings:** If access is denied, does the app provide clear guidance to the user to enable it in Windows Settings?
- [ ] **Open Settings Link:** Does the UI element that's supposed to open microphone settings (triggered by `PermissionService.openSystemPreferences(PermissionType.microphone)`) correctly open the Windows microphone privacy settings page (`ms-settings:privacy-microphone`)?

### Accessibility & Input Control (for Global Hotkeys & Text Insertion)
- [ ] **Global Hotkeys:** Do global hotkeys work reliably even when AutoQuill is not the focused application? Test with various target applications active.
- [ ] **Administrator Privileges:** If global hotkeys or text insertion into other apps fail, does running AutoQuill "as administrator" resolve these issues? Note findings.
- [ ] **Open Settings Link:** Does `PermissionService.openSystemPreferences(PermissionType.accessibility)` open the relevant Windows Ease of Access settings page (e.g., keyboard settings)?

### Screen Recording (if `screen_capturer` is used for AI context)
- [ ] **Functionality:** If the AI Assistant mode uses screen capture for context, does this feature work as expected on Windows?
- [ ] **Dependency Check:** Ensure the "C++ ATL for latest vXXX build tools" are installed as per prerequisites. Does the feature fail gracefully if this is missing (if testable)?
- [ ] **Open Settings Link:** Does `PermissionService.openSystemPreferences(PermissionType.screenRecording)` open the Windows screen capture privacy settings?

## 5. Smart Features

- [ ] **Auto-Punctuation:** Does the transcription include automatic punctuation? Is it accurate?
- [ ] **Phrase Replacement:** Configure and test custom phrase replacements/shortcuts.
- [ ] **API Integration (e.g., Groq):**
    - [ ] **Configuration:** Can API keys be successfully entered and saved in the settings?
    - [ ] **Online Transcription:** Does transcription using the configured cloud API work correctly?
    - [ ] **Offline Fallback:** If the internet connection is disabled, does the app fall back to any available basic/offline transcription mode, or handle the lack of connectivity gracefully?

## 6. Settings & Configuration

- [ ] **Hotkey Customization:** Can hotkeys for different modes be customized and saved? Do the new hotkeys work?
- [ ] **Hotkey Conflict Detection:** If the app has conflict detection, does it warn the user appropriately? (This might be harder to test without knowing specific conflicting keys).
- [ ] **Auto-Copy Settings:** Can the automatic copying of text to clipboard be configured (enabled/disabled)?
- [ ] **Theme Settings:** If any theme options (Light/Dark mode beyond system default) are intended for Windows, do they work?

## 7. Auto-Update System (Requires Test Feed Setup)

- [ ] **Setup:** Configure `autoUpdater.setFeedURL()` in the app to point to a test `appcast.xml` hosted locally or on a test server.
- [ ] **Version Staging:** Host an older version of the MSI and an `appcast.xml` file that points to a (dummy) newer version of the MSI.
- [ ] **Update Detection:** Does the application correctly detect that an update is available?
- [ ] **Update Download & Prompt:** Does it download the (dummy) update and prompt the user to install it?
- [ ] **Update Process:** Does the update process (triggered by WinSparkle) complete successfully? (This may only be fully testable with a real, signed update package).

## 8. General Stability & Performance

- [ ] **No Crashes/Freezes:** Use the application extensively. Does it run without crashing or freezing?
- [ ] **Resource Usage:** Monitor CPU and memory usage during idle times, recording, and transcription. Is it within acceptable limits?
- [ ] **Multi-App Interaction:** Test hotkeys, pasting, and context capture with a variety of target applications (e.g., Notepad, Word, Chrome, VS Code).
- [ ] **Error Handling:** Attempt to trigger error conditions (e.g., no internet for API, invalid API key, no microphone). Does the app display user-friendly error messages?

## 9. Localization/Language

- [ ] If multi-language support for transcription is a feature, test with different configured languages.
- [ ] Is the UI text (if any parts are localized beyond what Flutter handles) correct for the default language on Windows?

This checklist should provide a solid basis for verifying the Windows port.
