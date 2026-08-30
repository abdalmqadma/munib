# Contributing to Munib

Thank you for helping improve Munib. Contributions that improve reliability, accessibility, Arabic language support, testing and user experience are especially welcome.

## Before you start

1. Check existing issues and pull requests to avoid duplicate work.
2. Open an issue for a large feature or architectural change before implementation.
3. Never commit passwords, service account files, private API keys or signing keys.
4. Keep prayer time and religious content changes traceable to a reliable source.

## Local setup

```bash
git clone https://github.com/abdalmqadma/munib.git
cd munib
flutter pub get
flutter test
flutter run
```

Use your own Firebase project for local development by running `flutterfire configure`.

## Pull requests

1. Create a focused branch for your change.
2. Keep the change small enough to review clearly.
3. Run `flutter analyze` and `flutter test` before submitting.
4. Explain what changed, why it changed and how it was tested.
5. Include screenshots or a short recording when changing the interface.

By contributing, you agree that your contribution will be licensed under the MIT License used by this project.
