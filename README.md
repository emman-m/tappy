# Tappy Project Documentation

> This file serves as the main documentation for the Tappy project. As the project grows, all new features, usage instructions, and technical details should be documented here.

---

# Tappy Project - Features

1. **Local File Server**
   - Start/stop a local HTTP server on the device.
   - Displays server status (running/offline) and local IP address.
   - Shows a QR code for easy connection to the server from other devices.

2. **File Sharing**
   - Select and share multiple files from the device.
   - List of currently shared files is displayed.
   - Option to stop sharing all files at once.

3. **File Upload (from Web/PC)**
   - Web interface (upload.html) for uploading files to the device.
   - Supports multi-file upload.
   - User receives a dialog to accept or reject incoming files (single or batch).
   - Progress bar for each file being received.
   - Received files are saved to the device's Downloads folder.
   - List of files received in the current session is displayed.

4. **Logs and Notifications**
   - In-app log viewer for server and file transfer events.
   - Option to clear logs.
   - Local notifications for background service and file events.

5. **Permissions Handling**
   - Requests and handles storage and notification permissions (especially on Android).
   - Displays error messages if permissions are denied.

6. **Cross-Platform Support**
   - Built with Flutter for Android, iOS, Windows, Linux, and macOS (codebase includes platform folders).

7. **Background Service**
   - Server runs as a background service with notification support (Android).

8. **User Interface**
   - Modern Material 3 UI with light/dark theme support.
   - Progress indicators for uploads/downloads.
   - Dialogs for user actions (accept/reject uploads, clear logs, etc.).

---

# Setup & Build Instructions

## Prerequisites
- [Flutter SDK](https://flutter.dev/docs/get-started/install) (ensure it is in your PATH)
- Platform-specific requirements (Android Studio/Xcode/Visual Studio, etc.)

## Android
1. Run `flutter pub get` to fetch dependencies.
2. Connect an Android device or start an emulator.
3. Run `flutter run` or build an APK with `flutter build apk`.

## iOS
1. Run `flutter pub get`.
2. Open `ios/Runner.xcworkspace` in Xcode.
3. Set up signing and capabilities.
4. Run on a simulator or device, or build with `flutter build ios`.

## Windows
1. Ensure you have Visual Studio with Desktop development tools.
2. Run `flutter pub get`.
3. Run `flutter run -d windows` or build with `flutter build windows`.

## Linux
1. Install required dependencies for Flutter desktop (see [Flutter Linux setup](https://docs.flutter.dev/desktop#linux)).
2. Run `flutter pub get`.
3. Run `flutter run -d linux` or build with `flutter build linux`.

## macOS
1. Install Xcode and required tools.
2. Run `flutter pub get`.
3. Run `flutter run -d macos` or build with `flutter build macos`.

---

# Usage Instructions

1. **Start the App:** Launch Tappy on your device or desktop.
2. **Start the Server:** Tap the button to start the local file server. The server status and IP address will be displayed.
3. **Share Files:** Use the "Share Files" button to select files from your device to share.
4. **Upload from Web/PC:**
   - On your PC, connect to the displayed IP address in a browser.
   - Use the web interface to upload files to your device.
   - Accept or reject incoming files on your device when prompted.
5. **View Logs:** Tap the log icon to view server and file transfer logs.
6. **Stop Sharing:** Use the "Stop Sharing All" button to stop sharing files.

---

# Troubleshooting & Common Issues

- **Cannot Start Server:**
  - Ensure you have granted all required permissions (storage, network, notifications).
  - Restart the app or device if the server fails to start.
- **Cannot Access Server from PC:**
  - Make sure your device and PC are on the same local network.
  - Check firewall settings on your device and PC.
- **File Upload Fails:**
  - Check available storage space on your device.
  - Ensure you have accepted the file upload prompt.
- **Permissions Denied:**
  - Go to device settings and grant the necessary permissions manually.

---

# Permissions & Privacy Requirements

- **Storage Permission:** Required to read and write files on the device (especially on Android).
- **Notification Permission:** Required for background service notifications.
- **Network Access:** Required to run the local server and transfer files.
- **Privacy:** Files are only accessible on your local network. No data is sent to external servers.

---
