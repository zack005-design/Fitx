# FitX Android device verification

Run this checklist on at least one Android 15+ phone before a personal release.

## Health and permissions

1. Deny Health Connect access, open Data sources, and confirm every missing input has a useful recovery step.
2. Grant categories, history, and background access; sync twice and confirm the second sync keeps saved days and completes faster.
3. Revoke one category in Android settings and confirm FitX keeps the last valid saved day while reporting the failed read.

## Reminders and reboot

1. Set each reminder a few minutes ahead and verify its displayed time and delivery.
2. Reboot with reminders enabled, reopen FitX, and verify schedules still appear.
3. Change the phone time zone and confirm reminders follow local wall-clock time.
4. Disable exact alarms and verify the smart-alarm page explains approximate delivery.

## Sleep, motion, and battery

1. Start phone sleep tracking, lock the phone for at least 45 minutes, then stop and verify coverage and limitations are shown.
2. Force-close FitX during tracking, reopen it, and confirm the active session can be recovered.
3. Run an overnight battery test and record the battery percentage before and after.
4. Start a workout, add exercises and sets, force-close FitX, and confirm the same active workout reopens.

## Backup and restore

1. Create a backup with meals, a workout, journal entries, and settings.
2. Add a recognizable temporary record, choose Restore, inspect the date and record count, and confirm the temporary record is replaced.
3. Cancel both document pickers and confirm no data changes.
4. Try a non-FitX JSON file and confirm it is rejected before any data changes.

## Accessibility and release

1. Check every new screen with Android font size at maximum and with TalkBack enabled.
2. Verify touch targets, focus order, time-picker labels, error messages, and destructive confirmations.
3. Run `flutter analyze`, `flutter test`, and `flutter build apk --debug` before installing the final candidate.
