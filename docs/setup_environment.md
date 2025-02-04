# Environment Setup Checklist

Follow the checklist below to ensure your development environment for our Flutter and Firebase project on Windows 10 is properly set up. Check each task off as you complete them.

## Prerequisites
- [x] Windows 10 installed
- [x] Git installed
- [x] Node.js installed (for Firebase CLI)
- [x] Firebase account created
- [x] Java 17 (Temurin) installed and configured as default JDK

## 1. Install Flutter SDK
- [x] Download the latest stable version of the [Flutter SDK](https://flutter.dev/docs/get-started/install/windows).
- [x] Extract the Flutter SDK to a suitable location (e.g., C:\src\flutter).
- [x] Add Flutter to your system PATH:
  - [x] Right-click on 'This PC' and select Properties > Advanced system settings.
  - [x] Click on 'Environment Variables' and update the PATH variable to include the Flutter SDK's 'bin' directory.
- [x] Open a terminal and run `flutter doctor` to verify the installation. Follow any instructions to resolve issues.

## 2. Set Up Android Studio (for Emulators)
- [x] Download and install [Android Studio](https://developer.android.com/studio).
- [x] During installation, ensure you install the Android SDK, Android SDK Platform-Tools, and Android Virtual Device (AVD) Manager.
  - [x] Open Android Studio
  - [x] Go to Tools > SDK Manager
  - [x] Under "SDK Tools" tab, check "Android SDK Command-line Tools (latest)"
  - [x] Click "Apply" to install
- [x] Open Android Studio and navigate to Tools > AVD Manager to create and start an emulator.

## 3. Install Firebase CLI
- [x] Ensure Node.js is installed (download from [Node.js official website](https://nodejs.org/)).
- [x] Open a terminal and run:
  ```
  npm install -g firebase-tools
  ```
- [x] Log in to Firebase by running:
  ```
  firebase login
  ```

## 4. Configure Firebase with Flutter
- [x] Install the FlutterFire CLI by running:
  ```
  dart pub global activate flutterfire_cli
  ```
- [x] In your project root, run:
  ```
  flutterfire configure
  ```
  This command will guide you through selecting your Firebase project and setting up the necessary configuration files (e.g., google-services.json for Android and GoogleService-Info.plist for iOS).

## 5. Final Checks
- [x] Run `flutter doctor` again to ensure all dependencies are correctly set up.
- [x] Verify that your Firebase configuration files are included in your project as per the FlutterFire documentation.

## Conclusion
- [x] If you encounter any issues, refer to the [Flutter documentation](https://flutter.dev/docs) and [Firebase documentation](https://firebase.google.com/docs). 