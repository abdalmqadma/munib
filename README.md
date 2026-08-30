# Munib | منيب

Munib is an open source Android application built with Flutter and Dart. It combines prayer times, adhkar, notifications, home screen widgets and monthly prayer schedule import in one focused Arabic experience.

[![Flutter](https://img.shields.io/badge/Flutter-Dart-02569B?logo=flutter)](https://flutter.dev)
[![Platform](https://img.shields.io/badge/Platform-Android-3DDC84?logo=android)](https://www.android.com)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Status](https://img.shields.io/badge/Status-Active%20Development-F4B942)](#project-status)

## Project status

Munib is under active development and has not reached its first stable release. Features, setup steps and APIs may change while the application is being tested and improved.

## What Munib does

Munib is designed to make daily prayer information easy to reach without turning the experience into a collection of disconnected tools. The application focuses on clear Arabic interfaces, reliable reminders and practical features that are useful throughout the day.

Current features include:

- Prayer times based on the selected location
- The next prayer time and a live countdown
- Importing monthly prayer schedules from images with OCR
- A review step for OCR results that may need correction
- Adhkar and Nafahat content
- Prayer notifications and configurable settings
- Android home screen widgets in multiple sizes
- Firebase authentication and user profiles
- Arabic and English localization with RTL support

## Technology

- Flutter and Dart
- Provider for state management
- Firebase Authentication, Firestore and Storage
- REST APIs for prayer times and OCR processing
- Google ML Kit for text recognition
- Hive and Shared Preferences for local data
- Native Android code for widgets and background functionality

## Project structure

```text
lib/
  core/                  App theme, colors, strings and localization
  data/
    models/              Prayer schedule data models
    services/            Authentication, location, OCR, notifications and widgets
  presentation/
    providers/           Application state
    screens/             Main application screens
    widgets/             Reusable interface components
  main.dart              Application entry point
```

Platform specific Android and iOS configuration remains in the standard Flutter directories. Automated Android APK builds are configured in `.github/workflows`.

## Getting started

### Requirements

- Flutter stable with a Dart version compatible with `pubspec.yaml`
- Android Studio or another Flutter compatible editor
- JDK 17 for Android builds
- A Firebase project for authentication and profile features

### Run locally

```bash
git clone https://github.com/abdalmqadma/munib.git
cd munib
flutter pub get
flutter run
```

For development with your own Firebase project, install the FlutterFire CLI and run:

```bash
flutterfire configure
```

The OCR feature currently connects to a developer hosted backend and requires a valid Firebase ID token. Contributors who use another backend can update the endpoint and integration in `lib/data/services/ai_service.dart`.

## Development showcase

The latest interface update and eight screen preview are available in this [Munib development post on LinkedIn](https://www.linkedin.com/feed/update/urn:li:activity:7498806020450881536/).

## Roadmap

- Improve OCR accuracy and review handling
- Expand automated tests
- Improve accessibility and localization
- Continue reliability and performance testing
- Prepare the first stable Android release

## Contributing

Contributions, bug reports and improvement ideas are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## Open source license

Munib is open source software released under the [MIT License](LICENSE).

## Author

Built and maintained by [Abd Alhady Al Maqadma](https://www.linkedin.com/in/abdalmaqadma/).

Prayer times can vary according to location, calculation method and local authority. Users should verify times with a trusted local source when accuracy is critical.
