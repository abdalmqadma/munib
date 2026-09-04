# Munib | منيب

<p align="center">
  <img src="preview_images/mockup.jpg" alt="Munib app mockup" width="100%">
</p>

Munib is an open source Android application built with Flutter and Dart. It combines prayer times, adhkar, Nafahat, notifications and home screen widgets in one focused experience that supports both Arabic and English.



## Project status 🟡

Munib is under active development and has not reached its first stable release. Features, setup steps and APIs may change while the application is being tested and improved.

## What Munib does 🕌

Munib is designed to make daily prayer information easy to reach without turning the experience into a collection of disconnected tools. The application focuses on clear interfaces in Arabic and English, reliable reminders and practical features that are useful throughout the day.

Current features include:

- Prayer times based on the selected location
- The next prayer time and a live countdown
- Multiple saved prayer locations
- Adhkar with daily progress
- Nafahat content and contextual reminders
- Prayer notifications and configurable settings
- Android home screen widgets in multiple sizes
- Firebase authentication and user profiles
- Arabic and English localization with RTL support

## Technology 🛠️

- Flutter and Dart
- Provider for state management
- Firebase Authentication, Firestore and Storage
- REST API for prayer times
- Hive and Shared Preferences for local data
- Native Android code for widgets and background functionality

## Project structure 📁

```text
lib/
├── core/                 App theme, colors, strings and localization
├── data/
│   ├── models/           Prayer schedule data models
│   └── services/         Authentication, location, notifications and widgets
├── presentation/
│   ├── providers/        Application state
│   ├── screens/          Main application screens
│   └── widgets/          Reusable interface components
└── main.dart             Application entry point
```

Platform specific Android and iOS configuration remains in the standard Flutter directories. GitHub Actions runs code analysis and tests without building APK artifacts.

## Getting started 🚀


### Run locally 💻

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

## Development showcase 📱

See the latest Munib interface and screen previews in this [LinkedIn post](https://www.linkedin.com/feed/update/urn:li:activity:7498806020450881536/).

## Contributing 🤝

Contributions, bug reports and improvement ideas are welcome. Read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request.

## Open source license 📄

Munib is open source software released under the [MIT License](LICENSE).

## Author ✍️

Built and maintained by [Abd Alhady Al Maqadma](https://www.linkedin.com/in/abdalmaqadma/).
