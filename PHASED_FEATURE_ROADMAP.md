# FitX completion roadmap

## Phase 1 — Control and data safety ✅

- Editable times for morning, workout, wind-down, hydration, and smart-alarm reminders.
- Local JSON backup and restore through Android's document picker.
- A guarded action to erase FitX's locally stored personal data.

## Phase 2 — Faster daily logging ✅

- Favourite foods and saved meals.
- Repeat a previous meal or day.
- Reusable workout routines and a quicker workout start flow.

## Phase 3 — Weekly review ✅

- One seven-day review combining recovery, sleep, activity, nutrition, and journal signals.
- A clear weekly focus derived from available data, with missing-data explanations.

## Phase 4 — Data-source diagnostics ✅

- Per-metric source, freshness, and missing-input status.
- Direct recovery steps for permissions, stale sync, and unsupported readings.

## Phase 5 — Device hardening and release readiness ✅

- Real-device checks for overnight tracking, rebooted alarms, battery use, revoked permissions, and interrupted workouts.
- Accessibility, migration, backup compatibility, and release-build verification.

Automated checks cover app logic, migrations, accessibility layouts, Android
compilation, and debug packaging. `DEVICE_TEST_CHECKLIST.md` contains the final
physical-device checks because reboot, overnight battery, and wearable behavior
cannot be truthfully simulated by a unit test.
