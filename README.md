# FitX

FitX is an Android 15+ health-intelligence app built with Flutter. It combines
Health Connect history with optional phone motion sensors to calculate recovery,
sleep, strain, stress, and energy scores on device.

## Data architecture

- Health Connect is the source of truth for heart rate, HRV, sleep, workouts,
  calories, SpO2, respiratory rate, and daily step history.
- Health Connect's aggregate steps API is used to respect source priority and
  avoid double-counting a phone and wearable.
- The phone step counter, step detector, accelerometer, and gyroscope are
  exposed through a native Kotlin event stream for live workout tracking.
- Raw motion sensors are foreground-only. Keeping them active all day is both
  battery-intensive and less reliable than the Android health stack.
- Scores and personal baselines are stored locally in SQLite.

## Current product surface

The current app has five destinations: **Today, Recovery, Strain, Sleep, and
Profile**, using a light theme and bundled Inter typography.

Demo mode starts enabled and labels sample readings. Switch it off in Profile
to use the existing local data providers. Profile also exposes Health Connect
permission and sync controls. Missing real readings remain unavailable;
unsupported logging and insight controls explain their limitations.

The repository also retains domain models, engines, repositories, and Android
services for nutrition, workouts, journals, stress, energy, coaching, reminders,
backup, phone sleep tracking, and the home-screen widget. Their presence does
not mean all older screens are reachable from the current navigation.

There is no account, sign-in, remote analytics, or cloud coaching in FitX.
See [reference UI verification](REFERENCE_UI_VERIFICATION.md) for the latest
recorded checks and remaining device-testing limits.

## Getting started

Use Flutter with Dart compatible with the committed `pubspec.lock` (currently
Flutter >= 3.44.0 and Dart >= 3.12.0), an Android SDK with API 37 installed,
and a JDK compatible with the checked-in Android Gradle plugin. The Android
sources target Java 17 bytecode. Run `flutter doctor -v` to check your setup.
The app requires an Android 15+ (API 35+) device or emulator.

```sh
git clone https://github.com/zack005-design/fitx.git
cd fitx
flutter pub get
flutter run
```

Flutter creates machine-specific Android configuration locally. Keep
`pubspec.lock` committed to preserve the resolved dependency versions.
For real readings, configure Health Connect, turn off demo mode in Profile,
grant the requested permissions, and sync.

## Repository layout

- `lib/app/`: application entry and navigation shell.
- `lib/features/reference_ui/`: the current five-screen UI.
- `lib/core/`: models, engines, providers, repositories, and services.
- `android/`: native Android integration and build configuration.
- `assets/`: bundled fonts, font licenses, images, and food catalog.
- `test/`: unit/widget tests and historical golden baselines.
- `tool/`: reproducible food-catalog builder and its source data.

## Documentation

- [Current UI verification and limitations](REFERENCE_UI_VERIFICATION.md)
- [Light-theme screen design specification](BEVEL_STITCH_SCREEN_SPEC.md)
- [Sanctuary Vitality design reference](.stitch-reference/stitch_bevel_fitness_app_ui/sanctuary_vitality/DESIGN.md)
- [Android device verification checklist](DEVICE_TEST_CHECKLIST.md)
- [Food catalog provenance and nutrition fields](assets/data/README.md)
- [Historical design system](DESIGN.md)
- [Historical redesign plan](BEVEL_REDESIGN_PLAN.md)
- [Historical Phase 2 implementation](PHASE2_IMPLEMENTATION.md)
- [Historical feature roadmap](PHASED_FEATURE_ROADMAP.md)
- [September 14 UI audit and screenshots](artifacts/ui-audit/README.md)

Historical plans, audit screenshots, and test baselines describe earlier app
versions; consult the current UI verification first. The last recorded local
build used Flutter 3.47.2 with Dart 3.13.2. Raw emulator dumps,
build output, local databases, credentials, logs, and one-off repair scripts
are excluded from version control.

## On-device intelligence

The retained intelligence engine works as follows; the current navigation does
not expose the historical Private Coach screen.

The Private Coach is a deterministic local inference model, not a generative
chatbot. Version 2 combines recovery (32%), sleep (24%), energy (18%), low
stress (14%), and training balance (12%). It adjusts those weights by measured
signal reliability and renormalizes them when an input is unavailable. The
rolling 42-day model uses median absolute deviation for robust personalization,
exponentially weighted moving averages for recency, least-squares regression
for momentum and short forecasts, cross-signal interaction penalties, outlier
detection, pattern stability, and confidence calibration. The screen exposes
the confidence, history depth, forecast, trends, anomalies, and source readings.
It uses no API, network request, cloud model, or bundled third-party model.

## Personal release signing

The default Android application ID is `com.aniru.fitx.personal`; override it
with `-PFITX_APPLICATION_ID=your.unique.id` before first distribution. Copy
`android/key.properties.example` to `android/key.properties`, point it at your
private upload keystore, and build with `flutter build appbundle --release`.
When that private file is absent, release mode uses the debug key so personal
test installs still work; that fallback must not be uploaded to an app store.

## Verify

```sh
flutter analyze
flutter test
flutter build apk --debug
```

For the current UI's focused widget suite:

```sh
flutter test test/reference_app_test.dart test/reference_today_screen_test.dart test/reference_recovery_screen_test.dart test/reference_strain_screen_test.dart test/reference_sleep_screen_test.dart
```

The recorded verification covers this focused suite, analysis, and a debug
build. It does not establish that every historical test or golden passes with
the redesigned UI. Physical-device Health Connect checks remain outstanding.
