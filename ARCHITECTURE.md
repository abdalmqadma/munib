# Munib Architecture

Munib is moving toward a feature-first, layered structure without introducing unnecessary abstractions.

## Goals

- Keep UI, state, business rules, and external services separated.
- Keep feature code close together.
- Prefer small focused classes over large providers or screens with mixed responsibilities.
- Extract widgets only when they are reused or meaningfully complex.
- Preserve behavior while refactoring; architecture changes should not silently change product behavior.

## Target structure

```text
lib/
  core/
    theme/
    localization/
    utils/

  features/
    prayer_times/
      data/
      domain/
      presentation/

    azkar/
      data/
      domain/
      presentation/

    nafahat/
      data/
      domain/
      presentation/

    notifications/
      data/
      domain/
      presentation/

    location/
      data/
      domain/
      presentation/

    auth/
      data/
      domain/
      presentation/

    settings/
      data/
      presentation/
```

Not every feature needs every layer. A layer should exist only when it has a real responsibility.

## Dependency direction

Preferred flow:

```text
Presentation -> Domain -> Data / platform adapters
```

Presentation may depend on domain models and controllers. Domain code should not import Flutter UI. Data code owns APIs, persistence, Firebase, geolocation, and platform-specific integrations.

## Current migration

The migration is incremental so existing screens keep working while code is moved safely.

Canonical feature locations now include:

- `lib/features/auth/data/auth_service.dart`
- `lib/features/azkar/data/azkar_data.dart`
- `lib/features/location/data/location_service.dart`
- `lib/features/location/data/place_search_service.dart`
- `lib/features/settings/presentation/theme_provider.dart`
- `lib/features/prayer_times/data/models/prayer_day.dart`
- `lib/features/prayer_times/data/widget_service.dart`
- `lib/features/prayer_times/domain/prayer_time_calculator.dart`
- `lib/features/notifications/data/adhan_bridge_service.dart`
- `lib/features/nafahat/data/nafahat_bridge_service.dart`

Legacy paths temporarily re-export migrated modules. New code should import the feature path directly. Compatibility exports can be removed after all consumers migrate.

Prayer-time calculation is now owned by a pure domain component and reused by both `PrayerProvider` and the home prayer widget instead of being duplicated in presentation code.

## Refactor priorities

1. Split notification settings and scheduling responsibilities out of `PrayerProvider`.
2. Move saved-location serialization/persistence out of `PrayerProvider`.
3. Break large screens into focused sections/widgets where that improves readability.
4. Move remaining cross-feature services into their owning features when the ownership is clear.
5. Keep adding focused unit tests around extracted business rules before removing legacy compatibility paths.

## Rules of thumb

- Do not create a new file for every `Container` or tiny widget.
- Do not add repository/use-case layers when they only forward one method with no boundary value.
- Do extract logic when it is reused, independently testable, talks to an external system, or makes a provider/screen carry multiple responsibilities.
- Prefer explicit names over generic names such as `Utils`, `Helper`, or `Manager` when a more specific role exists.
