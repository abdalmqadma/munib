# Imsakia Upload Feature Archive

This branch preserves the Imsakia image/PDF upload feature that was removed from the MVP to avoid shipping unused OCR dependencies and a currently unreliable extraction API.

## Archived feature files

- `lib/presentation/screens/upload_screen.dart`
- `lib/presentation/screens/review_screen.dart`
- `lib/data/services/ocr_service.dart`
- OCR/extraction methods inside `lib/data/services/ai_service.dart`

## Dependencies used by the archived feature

These were removed from `main` when the feature was archived:

- `google_mlkit_text_recognition`
- `file_picker`
- `path_provider`
- `image`

`image_picker` remains in the app because it is also used by the profile photo flow.

## Safe restore procedure

Do not merge this archive branch directly into a future `main`, because `main` may have evolved since this archive was created.

Instead:

1. Create a new feature branch from the current `main`.
2. Restore the three archived feature files listed above from `archive/imsakia-upload-v1`.
3. Re-add the four dependencies to `pubspec.yaml` using versions compatible with the future Flutter version.
4. Reintroduce only the Imsakia OCR/extraction methods from the archived `ai_service.dart` into the current prayer API service. Do not overwrite future prayer-time logic wholesale.
5. Restore the upload entry points in the Home and Imsakia Settings screens.
6. Point the extraction client to the paid/stable OCR API and verify authentication, timeouts, image limits, and review handling.
7. Run `flutter analyze` and `flutter test`, then validate the Android native OCR integration before releasing.

## Git reference

Archive branch: `archive/imsakia-upload-v1`

Archive base commit: `cac449b512536520995edd7c3315958bd3c29e64`

The feature should be restored from this branch rather than rebuilt from scratch.
