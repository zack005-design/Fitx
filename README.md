<div align="center">

<img src="assets/images/app_logo.png" alt="FitX app icon" width="96" />

# FitX

### A clearer picture of your day. Built from your own signals.

Recovery, effort, and sleep — brought together on your phone.

**Android 15+ · Flutter · Health Connect · Local SQLite**

[Explore the app](#five-ways-to-read-your-day) · [Run it locally](#your-first-run) · [Read the docs](#the-project-notebook)

</div>

---

Your sleep record tells one part of the story. Your activity tells another.
FitX brings those signals into the same view, with daily estimates and personal
context you can inspect. Health Connect supplies the readings; FitX's local
engines turn available data into recovery, sleep, strain, stress, and energy
estimates.

The current interface is deliberately calm: a light canvas, rounded cards,
bundled Inter typography, and five destinations within reach.

## Five ways to read your day

| Destination | What you come here for |
| --- | --- |
| **Today** | A daily overview of available readiness, activity, sleep, and vital signals. |
| **Recovery** | A closer look at readiness and the readings behind it. |
| **Strain** | An overview of daily exertion and activity. |
| **Sleep** | A closer look at your recorded night and sleep estimates. |
| **Profile** | Switch between sample and real readings, connect Health Connect, and sync. |

> **Try the design first.** FitX starts in labeled demo mode. Open **Profile**
> and turn **Demo mode** off to use your own readings. Sample values are never
> written to your health history, and missing real readings stay unavailable.

This is a work in progress. Some logging and insight controls explain features
that are not yet available. Recovery needs enough personal baseline data.
Skin temperature and prescribed training windows are not available from the
current source integration.

## What FitX values

**Personal context.** Scores use available health inputs and personal baselines.
An unavailable reading should remain visible as a gap.

**Computation on your phone.** Health data and calculated summaries are stored
locally in SQLite. FitX has no user account, remote analytics, or cloud coaching.

**Traceable inputs.** Health Connect provides recorded health history. The food
catalog retains source information and distinguishes recipe calculations from
estimates. [Read the catalog notes](assets/data/README.md).

## Your first run

### Prepare your tools

The last recorded local build used **Flutter 3.47.2 / Dart 3.13.2**. The committed
lockfile requires Flutter **>= 3.44.0** and Dart **>= 3.12.0**.

You'll need an Android 15+ (API 35+) device or emulator, Android SDK API 37,
and a JDK compatible with the checked-in Android Gradle plugin. The Android
sources target Java 17 bytecode. Use `flutter doctor -v` to check your setup.

```sh
git clone https://github.com/zack005-design/Fitx.git
cd Fitx
flutter pub get
flutter run
```

Flutter creates machine-specific Android configuration locally. Keep
`pubspec.lock` committed so dependency versions remain reproducible.

### Bring in your readings

1. Configure Health Connect with the source apps you use.
2. Open **Profile** in FitX and turn **Demo mode** off.
3. Tap **Connect source** and grant the requested permissions.
4. Tap **Sync readings** to refresh the available data.

What appears depends on your source apps, permissions, recorded history, and
baseline coverage.

## Under the surface

Health Connect is the primary source for heart rate, HRV, sleep, workouts,
calories, SpO2, respiratory rate, and daily step history. The integration uses
its aggregate steps API to respect source priority and avoid counting the same
activity from both a phone and wearable.

The repository also contains native Kotlin integrations for optional phone
motion sensors. Raw motion sensing is intended for foreground sessions.
Models, engines, repositories, and Android services for nutrition, journals,
workouts, reminders, backups, phone sleep tracking, and the home-screen widget
remain in the codebase. These are broader than the features currently exposed
by the five-screen shell.

<details>
<summary><strong>A closer look at the retained intelligence engine</strong></summary>

The Private Coach engine is deterministic and runs locally. Its Version 2
starting weights are recovery (32%), sleep (24%), energy (18%), low stress
(14%), and training balance (12%). It adjusts those weights for signal
reliability and renormalizes them when inputs are unavailable.

Its rolling 42-day model combines robust personal baselines, recency weighting,
momentum, short forecasts, cross-signal interactions, outlier detection, pattern
stability, and confidence calibration. It uses no API, cloud model, or bundled
third-party model. The historical Private Coach screen is not exposed by the
current navigation.

</details>

### Find your way around the code

| Path | Responsibility |
| --- | --- |
| [`lib/app/`](lib/app/) | App setup and the five-destination shell |
| [`lib/features/reference_ui/`](lib/features/reference_ui/) | Current screens and theme |
| [`lib/core/`](lib/core/) | Models, scoring engines, providers, repositories, and services |
| [`android/`](android/) | Native integrations and Android build configuration |
| [`assets/`](assets/) | Fonts, font licenses, images, and the runtime food catalog |
| [`test/`](test/) | Unit and widget tests, plus historical golden baselines |
| [`tool/`](tool/) | Food-catalog builder and reproducible source data |

## Check your build

```sh
flutter analyze
flutter test
flutter build apk --debug
```

For the focused suite covering the current UI:

```sh
flutter test test/reference_app_test.dart test/reference_today_screen_test.dart test/reference_recovery_screen_test.dart test/reference_strain_screen_test.dart test/reference_sleep_screen_test.dart
```

The [September 22 verification record](REFERENCE_UI_VERIFICATION.md) reports
**23 focused widget tests passed**, clean analysis, and a successful debug APK
build. That is a dated verification record, not a live CI status. It does not
establish that every historical test or golden passes with the redesigned UI.
Physical-device Health Connect permission and sync checks remain outstanding.

### Build a signed bundle

Copy [`android/key.properties.example`](android/key.properties.example) to
`android/key.properties` and enter your private upload-keystore details.

```sh
flutter build appbundle --release
```

The default application ID is `com.aniru.fitx.personal`; the Android build
supports the `FITX_APPLICATION_ID` Gradle property for a custom ID. Choose your
distribution ID before your first release.

**Signing matters:** without `key.properties`, the current build falls back to
the debug key for personal test installs. Do not submit that bundle to an app
store. Keystores and private signing configuration are excluded from Git.

## The project notebook

Start with the current verification and design references. Earlier plans and
audit screenshots are preserved as a record of how FitX has changed.

### Current references

- [UI verification and known limits](REFERENCE_UI_VERIFICATION.md)
- [Light-theme screen specification](BEVEL_STITCH_SCREEN_SPEC.md)
- [Sanctuary Vitality design reference](.stitch-reference/stitch_bevel_fitness_app_ui/sanctuary_vitality/DESIGN.md)
- [Android device verification checklist](DEVICE_TEST_CHECKLIST.md)
- [Food catalog sources and nutrition fields](assets/data/README.md)

<details>
<summary><strong>Earlier design and implementation records</strong></summary>

- [Historical design system](DESIGN.md)
- [Redesign plan](BEVEL_REDESIGN_PLAN.md)
- [Phase 2 implementation](PHASE2_IMPLEMENTATION.md)
- [Feature roadmap](PHASED_FEATURE_ROADMAP.md)
- [September 14 UI audit and screenshots](artifacts/ui-audit/README.md)

These documents describe earlier versions. Their screens, completion notes,
and screenshots may differ from the current app.

</details>

---

Source, tests, assets, and documentation belong here. Build output, raw emulator
dumps, local databases, credentials, logs, and one-off repair scripts stay out
of version control.
