# FitX UI audit — Android medium phone

Captured from the current debug APK on a 1080 × 2400 Android emulator on 2026-09-14.

## Verified issues

1. **Bottom navigation remains on detail routes.** The four-tab bar is visible on screens that `AppShell._showNavigation` explicitly excludes, including Recovery, Sleep, Stress, Energy, Trends, Vitals, Settings, Profile, Coach, Journal Insights, Workout, and Barcode Scanner. It reserves/overlays the bottom 189 px (`y=2148..2337`) and visibly hides lower content on screens such as Sleep, Stress, Vitals, and Journal Insights.
2. **Onboarding profile save can fail at runtime.** Tapping **Save profile** produced `DatabaseException(Cannot perform this operation because there is no current transaction.) sql 'ROLLBACK'`, originating while `DatabaseService.db` opened `fitx.db`. This prevented normal progression from onboarding step 3.
3. **Resumed onboarding can show the wrong page.** With a saved step of 3 or 4, the progress indicator restored to step 4/5 or 5/5 while the `PageView` still displayed step 1. The one-shot post-frame callback can run before `_pages.hasClients` and does not retry.

## Checks that passed

- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: 96 tests passed.
- No `RenderFlex overflowed` or other Flutter pixel-overflow diagnostics appeared during this sweep.
- On the tested 1080 × 2400 viewport, the individual cards, typography, fields, and primary actions were otherwise aligned consistently.

## Screenshots

### Onboarding

- [01 — Welcome](01_onboarding.png)
- [02 — Health Connect](02_health_connect.png)
- [03 — Profile](03_profile.png)
- [04 — Baseline](04_baseline.png)
- [05 — Notifications](05_notifications.png)

### Primary tabs

- [06 — Today](06_today.png)
- [06b — Today, lower content](06b_today_scrolled.png)
- [07 — Journal](07_journal.png)
- [08 — Train](08_train.png)
- [09 — Nutrition](09_nutrition.png)

### Health and intelligence

- [10 — Recovery](10_recovery.png)
- [11 — Sleep](11_sleep.png)
- [12 — Stress](12_stress.png)
- [13 — Energy](13_energy.png)
- [14 — Private coach](14_coach.png)
- [15 — Biological age / Healthspan](15_biological_age.png)
- [16 — Trends](16_trends.png)
- [17 — Vitals](17_vitals.png)

### Settings

- [18 — Settings](18_settings.png)
- [19 — Data sources](19_data_sources.png)
- [20 — Calculations](20_calculations.png)
- [21 — Notifications settings](21_notifications.png)
- [22 — Profile settings](22_profile_settings.png)

### Secondary flows

- [23 — Journal insights](23_journal_insights.png)
- [24 — Active workout](24_workout.png)
- [25 — Nutrition quick-log sheet](25_nutrition_log_sheet.png)
- [26 — Barcode scanner, permission denied state](26_barcode_scanner.png)

Date-specific routes reuse the same layouts and were not duplicated in the screenshot set. Redirect-only routes (`/strain`, `/workout`, `/insights`) were also not duplicated.
