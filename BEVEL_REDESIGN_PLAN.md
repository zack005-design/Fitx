# FitX → a focused, Bevel-inspired health app

> Historical plan, superseded on 2026-09-21 by the user-supplied Stitch screen references. Current implementation lives in `lib/features/reference_ui` with Today, Recovery, Strain, Sleep and Profile destinations. Light cards, Inter typography and the supplied screen layouts take precedence over this document. Existing health repositories remain the real-data source; demo mode is explicitly labeled.

## Product direction

FitX should become a calm daily health companion, not a collection of separate metric dashboards. The product should answer three questions in order:

1. **How am I doing today?** Recovery, sleep, strain, and the single most useful explanation.
2. **What should I do next?** A concrete training, recovery, sleep, or nutrition action.
3. **What is changing over time?** Trends and journal correlations grounded in real user data.

The goal is to borrow Bevel's strengths—clear hierarchy, restrained presentation, connected metrics, and progressive disclosure—without copying its branding, assets, wording, layouts pixel-for-pixel, or proprietary scoring.

## Current-state assessment

### Keep and build on

- Flutter, Riverpod, GoRouter, SQLite, Health Connect, and the existing repository/engine separation.
- Real Health Connect ingestion for sleep, heart rate, HRV, resting heart rate, SpO₂, respiratory rate, activity, and workouts.
- The five score domains: Recovery, Sleep, Strain, Stress, and Energy.
- Nutrition logging, barcode scanning, hydration, workout logging, local-first storage, notifications, Android widget, and personal baselines.
- The existing dark, metric-specific color idea: green recovery, purple sleep, orange strain, amber stress, cyan energy.

### Remove or demote

- Remove **Sleep**, **Strain**, and **Coach** as permanent bottom-navigation destinations. Sleep and strain are details of the daily story; they do not need equal navigation weight.
- Replace the current five-item glass pill navigation. It consumes too much height and makes every feature look equally important.
- Remove the current “Coach” screen from primary navigation until it is a real, data-grounded coaching experience. Rename the existing insights work to **Trends** and access it from Today/Profile.
- Remove decorative glass effects, excessive borders, uppercase labels, tiny text, and per-card glow where they do not communicate state.
- Remove unsupported claims such as “clinical-grade accuracy.”
- Remove or hide all simulated/fixed health content until it is backed by a model and source data. Known examples include the fixed 92% sleep consistency, target sleep window, power-nap card, prescribed workout content, named exercise sets, fixed intraday peak labels, and generic “optimal” vital interpretations.
- Avoid separate full screens for Stress, Energy, and Vitals unless a user taps through from Today. They remain secondary routes, not primary product pillars.

### Consolidate

- Combine daily score cards, stress, energy, vitals, hydration, and the daily recommendation into one configurable **Today** feed.
- Combine workout history, strain target, exercise logging, and active workout into **Train**.
- Combine current nutrition and hydration into **Nutrition**.
- Replace “Insights/Coach” with **Trends**, containing metric history and, later, journal correlations.
- Move data sources, calculation choices, permissions, profile, notifications, and appearance into **Settings**.

## Target information architecture

### Bottom navigation: four destinations

1. **Today** — daily overview and date navigation.
2. **Journal** — quick habit and context logging.
3. **Train** — strain target, recent activity, workout start/history.
4. **Nutrition** — calories, macros, hydration, meal timeline, add food.

Profile/avatar opens Settings. Today cards open Recovery, Sleep, Stress, Energy, Vitals, and Trends as secondary detail routes.

### Route map

```text
/
├── /today
│   ├── /recovery/:date
│   ├── /sleep/:date
│   ├── /stress/:date
│   ├── /energy/:date
│   ├── /vitals/:date
│   └── /trends/:metric
├── /journal/:date
│   └── /journal/insights
├── /train
│   ├── /train/start
│   ├── /train/session/:id
│   └── /train/history
├── /nutrition/:date
│   ├── /nutrition/add
│   └── /nutrition/scan
└── /settings
    ├── /settings/data-sources
    ├── /settings/calculations
    ├── /settings/notifications
    └── /settings/profile
```

Deep links should remain available for existing paths during migration, redirecting old `/strain`, `/sleep`, `/insights`, and `/workout` routes to their new equivalents.

## Screen changes

### 1. Today

The top viewport should deliver the entire daily answer without scrolling:

- Compact date control with left/right day swipe and calendar picker.
- One dominant score selected by context (Recovery in the morning, Strain later in the day), plus compact Sleep and Strain values.
- One sentence explaining the dominant score using actual contributors.
- One primary action, such as “Keep strain between 8–11,” “Aim for 8h 20m sleep,” or “Take a recovery day.”

Below the fold:

- Horizontal/compact score strip for Recovery, Sleep, Strain, Stress, and Energy.
- “What changed” card showing at most three real contributors versus personal baseline.
- Timeline of sleep, workouts, meals, and notable health events.
- Health monitor row with only available readings and explicit timestamps/source labels.
- Configurable modules. Users can reorder or hide Nutrition, Hydration, Stress, Energy, and Vitals summaries.

Empty states must explain what data is missing, where it comes from, and the next action. A score must never silently substitute a neutral default when required source data is absent.

### 2. Recovery detail

- Hero: score, status, date, confidence/calibration state.
- Contributors: HRV, RHR, sleep score, respiratory rate, and other supported inputs, each compared with the personal baseline.
- 7/30/90-day chart with baseline band and tap-to-inspect points.
- “Why this score” explanation generated from deterministic rules and actual deltas.
- Clearly label unavailable metrics instead of assigning them reassuring interpretations.

### 3. Sleep detail

- Hero: score, total sleep versus need, bedtime and wake time.
- A single readable stage timeline; stage totals beneath it.
- Contributors: duration, efficiency, consistency, interruptions, and sleep debt only when computable.
- 7/30/90-day duration/score trends.
- Remove fixed consistency, target window, and nap content until backed by stored data.

### 4. Train

- Today’s strain and a recovery-adjusted target range.
- Start-workout button as the primary action.
- Recent workouts and weekly load beneath it.
- Active workout becomes a dedicated full-screen flow with timer, live heart rate when available, exercises/sets, finish, and discard confirmation.
- Do not show example exercises as logged activity. Seeded exercises belong only in exercise search/templates.

### 5. Nutrition

- Top: calories and macro progress with a clear “remaining” state.
- One add button opens a bottom sheet: search, barcode, quick add, water, and caffeine.
- Meal timeline grouped by breakfast/lunch/dinner/snacks.
- Micronutrients and nutrition score are collapsed secondary sections.
- Keep the local South Indian food catalog, but label its coverage honestly and design search for future remote/provider expansion.

### 6. Journal

- Daytime, nighttime, and automatic sections.
- Default quick entries: alcohol, caffeine timing, late meal, hydration goal, illness, soreness, stress, mood, sunlight, screen time, and medication/supplements.
- Entry types: yes/no/neutral, scalar, number, time, and optional note.
- Automatic entries are derived from existing health/nutrition/workout data and cannot be edited as manual claims.
- Journal Insights unlock only after a minimum useful sample (recommended: at least 5 positive and 5 negative observations). Always say “associated with,” never imply causation.

### 7. Trends

- Metric picker and 7/30/90-day ranges.
- Score trend, baseline band, average, change, and data completeness.
- Correlations are a separate section and remain hidden until enough journal data exists.
- No fake AI chat. A future coach can sit above this data once responses can cite the user metrics used.

### 8. Onboarding and Settings

- Replace the single crowded onboarding screen with a short flow: value proposition → Health Connect → profile/goals → calibration explanation → notification choice.
- Permission requests occur in context and explain exactly why each category is needed.
- Add Data Sources and Calculations pages, including units, sleep goal, HR zones, baseline window, source priority, and missing-data diagnostics.
- Provide sample/demo mode explicitly if a data-filled preview is desired; never mix demo data with the real profile.

## Visual system

### Principles

- Calm, dense enough to be useful, and readable at a glance.
- Near-black neutral background, solid elevated surfaces, and color reserved for metric identity/status.
- Prefer hierarchy through spacing and typography over glass blur, outlines, and glow.
- One large visual per screen; supporting information uses rows, not a wall of cards.
- Minimum 14sp body text and 12sp secondary labels; avoid 8–10sp operational text.
- Minimum 44×44 logical-pixel tap targets and visible pressed/focus states.

### New tokens

Create semantic tokens rather than screen-local numbers:

- Spacing: 4, 8, 12, 16, 24, 32.
- Radius: 12 controls, 16 rows/cards, 24 hero modules.
- Type: 12 caption, 14 body-small, 16 body, 20 title, 28 heading, 48 score.
- Surfaces: canvas, surface-1, surface-2, selected, divider.
- Content: primary, secondary, muted, disabled.
- Metric roles: recovery, sleep, strain, stress, energy, nutrition.
- State roles: positive, caution, negative, unavailable, calibrating.

Use system typography by default for Android performance and platform fit; if Inter remains, bundle the font rather than relying on a network fetch.

### Reusable components

- `AppPageScaffold`
- `DatePagerHeader`
- `ScoreHero`
- `ScoreChip`
- `MetricRow`
- `ContributorRow`
- `TrendChart`
- `DataStatusBanner`
- `SectionHeader`
- `PrimaryActionButton`
- `EmptyDataState`
- `AppBottomNavigation`
- `QuickLogSheet`

Each component needs loading, data, unavailable, error, and calibrating variants where applicable.

## Data and domain changes

### Correctness first

- Introduce a `MetricValue<T>`/`DataPoint<T>` shape containing value, time range, source, freshness, and quality/confidence.
- Make score computation return `available`, `calibrating`, or `unavailable` in addition to a number.
- Store daily raw aggregates required to reconstruct explanations; cached historical scores alone are insufficient for historical detail pages.
- Version score formulas and persist the formula version with every score.
- Separate daily snapshot refresh from background incremental sync.
- Normalize all day boundaries through one date/time service to avoid timezone and overnight-sleep errors.

### New persistence

- `daily_health_snapshots`
- `metric_samples` or typed aggregate tables with source metadata
- `journal_definitions`
- `journal_entries`
- `journal_correlations`
- `data_sources`
- `sync_state`
- `app_preferences`

Upgrade SQLite with explicit migrations; do not delete or silently rebuild the user database.

### Provider/controller changes

- Replace the monolithic `dailySummaryProvider` refresh path with repository-backed use cases: sync day, observe daily overview, compute score detail, and load trends.
- Use a single selected-date state shared by Today and detail screens.
- Keep write actions in controllers/notifiers; widgets should render view models and dispatch intents.
- Add clock and repository interfaces so dates, missing data, and score states are deterministic in tests.

## Codebase restructuring

```text
lib/
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── shell.dart
├── design_system/
│   ├── tokens/
│   ├── theme/
│   └── components/
├── domain/
│   ├── health/
│   ├── journal/
│   ├── nutrition/
│   └── training/
├── data/
│   ├── health_connect/
│   ├── database/
│   └── repositories/
└── features/
    ├── today/
    ├── score_detail/
    ├── journal/
    ├── train/
    ├── nutrition/
    ├── trends/
    ├── onboarding/
    └── settings/
```

Split the current 700–1,100-line feature files into page, controller/view-model, sections, and reusable components. Do this while rebuilding each feature, not as a separate big-bang rewrite.

## Implementation phases

### Phase 0 — truth and safety (2–3 days)

- Inventory every value rendered by every screen and tag it as live, derived, cached, seeded/demo, or fixed.
- Remove/hide fixed health interpretations and sample activity from production flows.
- Remove “clinical-grade” and other unsupported accuracy language.
- Define score availability/calibration rules and source-data requirements.
- Add regression tests for missing permissions, missing metrics, partial sleep, new user calibration, and historical dates.

**Exit:** No screen can present fabricated or defaulted health data as a real observation.

### Phase 1 — design foundation and shell (3–5 days)

- Build semantic design tokens and the reusable component set.
- Replace the glass pill with four-destination navigation.
- Extract router/shell from `main.dart`; add redirects for old routes.
- Add shared selected-date navigation and standard loading/error/empty states.
- Add golden tests at a small Android phone, target Xiaomi size, and large text scale.

**Exit:** New shell and components work end-to-end with existing screens temporarily embedded.

### Phase 2 — Today and score details (1–2 weeks)

- Rebuild Today around one daily narrative and progressive disclosure.
- Rebuild Recovery and Sleep first; then simplify Stress, Energy, and Vitals.
- Add contributor view models and historical raw daily snapshots.
- Add 7/30/90-day charts and data completeness indicators.
- Preserve Android widget updates but feed them through the new overview use case.

**Exit:** A user can understand today, the reason for each score, and its trend without encountering fixed content.

### Phase 3 — Train and Nutrition (1–2 weeks)

- Merge strain and workout into Train.
- Rework the active-workout state machine and persistence/recovery after app interruption.
- Simplify Nutrition, add the unified quick-log sheet, and make meal edits/deletes clear.
- Persist hydration through the repository as the single source of truth rather than split preferences/database state.

**Exit:** The two main logging loops are fast, recoverable, and reflected immediately on Today.

### Phase 4 — Journal and Trends (1–2 weeks)

- Add journal schema, definitions, quick logging, automatic entries, and history.
- Replace Coach/Insights with honest Trends.
- Implement correlations with sample thresholds, confidence/data-count display, and non-causal wording.

**Exit:** Users can connect behaviors to recovery/sleep only when enough real observations exist.

### Phase 5 — onboarding, background sync, polish (1 week)

- Ship staged onboarding and source/calculation settings.
- Add incremental background Health Connect sync and visible last-sync/source health.
- Add accessibility semantics, reduced-motion support, performance profiling, offline tests, and telemetry/privacy review.
- Update widget and notifications to match the new product language.

**Exit:** The daily loop stays current without manual refresh and remains understandable when sync fails.

## File-level migration map

| Current file | Change |
|---|---|
| `lib/main.dart` | Keep startup only; move router and shell into `lib/app/`. |
| `lib/core/theme/fitx_theme.dart` | Replace ad-hoc palette/type getters with semantic tokens and component themes. |
| `lib/core/theme/fitx_layout.dart` | Replace device-specific commentary/constants with adaptive insets and breakpoints. |
| `lib/core/widgets/bottom_nav_bar.dart` | Replace with four-item standard app navigation. |
| `lib/features/dashboard/dashboard_screen.dart` | Rebuild as `features/today/`; retain real summary and widget-update behavior. |
| `lib/features/recovery/recovery_screen.dart` | Split into page, hero, contributors, trends, and controller. |
| `lib/features/sleep/sleep_screen.dart` | Split and remove all fixed sections until backed by data. |
| `lib/features/strain/strain_screen.dart` | Merge real strain sections into Train; remove sample active-session UI. |
| `lib/features/workout/workout_screen.dart` | Move under Train and implement durable session state. |
| `lib/features/insights/insights_screen.dart` | Replace with Trends; remove pseudo-coaching and fixed intraday forecast. |
| `lib/features/nutrition/nutrition_screen.dart` | Split into overview, meal timeline, quick-log, and controller. |
| `lib/features/stress`, `energy`, `vitals` | Retain as secondary details using shared score-detail components. |
| `lib/features/onboarding/onboarding_screen.dart` | Replace with staged, permission-aware flow. |
| `lib/core/providers/providers.dart` | Split by domain and expose typed use cases/view models. |
| `lib/core/services/database_service.dart` | Add versioned migrations and new journal/snapshot/source tables. |
| `lib/core/repositories/health_repository.dart` | Return explicit data states and contributor/source metadata. |

## Verification strategy

- Unit tests for every score boundary, missing input, baseline window, and timezone/day-boundary rule.
- Repository tests using fake Health Connect and temporary SQLite databases.
- Widget tests for loading, unavailable, calibrating, partial, and full-data states.
- Golden tests for all core screens in dark mode, 1.0× and 1.3× text scale, and narrow/wide Android sizes.
- Navigation tests for all primary destinations, back behavior, deep-link redirects, and active workout.
- Integration tests for onboarding → permission result → first sync → Today; meal/hydration/workout logging; and journal correlation unlock.
- Run `flutter analyze`, `flutter test`, and debug/release Android builds in CI.
- Manual device QA for edge-to-edge insets, gesture navigation, Health Connect permission changes, offline mode, process death, and battery impact.

## Product acceptance criteria

- Today’s main scores and recommendation are understandable in under 10 seconds.
- Every displayed health number has a source, time range, freshness, and honest availability state.
- No fixed/demo value appears in a real user state.
- The top four daily actions are reachable in two taps: inspect a score, log journal, start workout, add food/water.
- Primary navigation contains no more than four destinations.
- Detail screens use the same date and preserve context when navigating back.
- All content remains readable at 1.3× text scale without clipping.
- Existing local user data survives database migration.
- Dashboard first meaningful paint and cached-day switching feel immediate; expensive sync work does not block the UI.
- Health data remains local by default, with explicit consent for any future remote coaching feature.

## Recommended first milestone

Build a vertical slice containing the new shell, Today, Recovery detail, shared date navigation, shared score components, and explicit data/calibration states. Do not start Journal or a coach until this slice is visually approved and every rendered value is traceable to real data. This creates the reusable pattern for the rest of the app and tackles the highest-value user loop first.

## Public reference points

- Bevel product overview: https://www.bevel.health/
- Bevel daily-data navigation: https://help.bevel.health/en/articles/10436737
- Bevel Journal behavior: https://help.bevel.health/en/articles/13318977
- Bevel Journal Insights sample threshold and correlation wording: https://help.bevel.health/en/articles/13319041
