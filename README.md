# ReelAI - Language Learning App

A TikTok-style mobile application focused on language learning through short-form video content.

## Features

- Learn languages through engaging short-form videos
- Personalized learning path based on skill level
- Track progress and maintain learning streaks
- Discover native speakers and teachers
- Practice listening comprehension at various speeds

## Getting Started

### Prerequisites

1. Flutter SDK (latest stable version)
2. Android Studio or VS Code with Flutter extensions
3. Firebase project

### Firebase Setup

1. Create a new Firebase project at [Firebase Console](https://console.firebase.google.com/)
2. Add Android app to your Firebase project:
   - Use package name: `com.example.gauntlet_project_3`
   - Download `google-services.json`
3. Enable Authentication methods:
   - Email/Password
   - Google Sign-in
4. Set up Cloud Firestore database

### Configuration

1. Copy `lib/firebase_options.template.dart` to `lib/firebase_options.dart`
2. Update the Firebase options with your project's configuration
3. Copy `android/app/google-services.template.json` to `android/app/google-services.json`
4. Update the file with your Firebase project's configuration

### Running the App

```bash
flutter pub get
flutter run
```

## Development

- `lib/screens/` - UI screens
- `lib/services/` - Business logic and Firebase services
- `lib/models/` - Data models
- `lib/widgets/` - Reusable widgets
