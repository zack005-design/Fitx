# Design System: FitX Daily Health Intelligence

> Superseded for the current UI on 2026-09-21. The approved source is `C:/Users/aniru/Downloads/stitch_bevel_fitness_app_ui_v2/stitch_bevel_fitness_app_ui`, including each screen image/HTML and `sanctuary_vitality/DESIGN.md`. The implemented app uses light #F2F2F7 surfaces, white rounded cards, bundled Inter, and blue/green/rose/indigo metric accents. The historical dark direction below does not apply to `lib/features/reference_ui`. Demo readings are explicitly labeled and never written to health repositories.

## 1. Visual Theme & Atmosphere

FitX is a calm, tactile health dashboard that feels measured rather than medical and premium rather than ornamental. Density is **Daily App Balanced (6/10)**: the first viewport answers the day’s main question, while details unfold through clean rows and quiet sections. Variance is **Controlled Asymmetric (4/10)**: one dominant score anchors each page, with supporting metrics offset below it instead of arranged as equal tiles. Motion is **Restrained Fluid (4/10)**: short spring-like transitions clarify state changes without distracting from health data.

The interface is dark by default for wearable-adjacent daily use. It avoids translucent glass, neon glow, noisy gradients, and “control room” decoration. Hierarchy comes from type, spacing, and a single elevated hero surface.

## 2. Color Palette & Roles

- **Night Canvas** (`#0C0D0F`) — app background; never pure black.
- **Graphite Surface** (`#15171A`) — primary grouped surface and navigation.
- **Raised Graphite** (`#1D2024`) — selected rows, sheets, and the single hero module.
- **Pressed Graphite** (`#25292E`) — pressed and hover/focus-neutral state.
- **Chalk Ink** (`#F2F3F3`) — primary text and high-priority numbers.
- **Steel Ink** (`#A4A8AE`) — descriptions, timestamps, supporting labels.
- **Muted Ink** (`#6F747C`) — unavailable values and low-priority metadata.
- **Whisper Divider** (`#292D32`) — structural 1px separators.
- **Moss Action** (`#70B89A`) — the only interaction accent; primary buttons, active navigation, focus, links.

Metric colors are **data ink**, not interaction accents. They may appear only in charts, score arcs, and tiny state markers:

- Recovery data: `#79B995`
- Sleep data: `#9DA3C9`
- Strain data: `#D39A70`
- Stress data: `#C4A56B`
- Energy data: `#78AFC0`
- Nutrition data: `#A4AE78`
- Negative state: `#C97878`

No outer glows. No saturated purple or electric blue. Data colors never fill large buttons or page backgrounds.

## 3. Typography Rules

- **Display and body:** Outfit, weights 400–700. Headlines are track-tight and controlled; body copy uses relaxed 1.4–1.5 line height.
- **Numbers:** Outfit with tabular figures. Use a monospace only if a dense table is introduced later.
- **Scale:** 12 caption, 14 supporting body, 16 body, 20 section title, 28 page heading, 44–52 hero score.
- **Minimum operational text:** 12sp. Important explanations never drop below 14sp.
- **Line length:** explanatory copy stays below roughly 65 characters per line.
- **Banned:** Inter, generic serif fonts, all-caps paragraphs, 8–10sp operational controls.

## 4. Component Stylings

- **Primary buttons:** Moss Action fill, Night Canvas text, 16px radius, 52px height. Press state scales to 0.98 with a short ease-out/spring feel. No gradient or glow.
- **Secondary buttons:** transparent or Raised Graphite fill, Chalk Ink text, no border unless separation is unclear.
- **Cards:** only the dominant score or a true grouped module receives a filled rounded surface. Radius 20–24px. Repeated metrics use rows with dividers, not independent cards.
- **Navigation:** solid Graphite Surface, four destinations, 72px total height, small pill indicator using low-opacity Moss Action.
- **Inputs:** persistent label above, 16px radius, Raised Graphite fill, error/helper below. Focus is a 1px Moss Action outline.
- **Sheets:** Raised Graphite, 28px top radius, visible drag handle, one primary action maximum.
- **Charts:** thin data-color stroke, muted baseline/range, no gradient area glow. Every chart exposes range, average, and data completeness.
- **Loading:** skeleton blocks that match final geometry. Circular spinners are allowed only inside a compact button action.
- **Empty states:** icon or simple geometric composition, one precise explanation, and one relevant action. Never fill absent health values with zero.
- **Errors:** inline and recoverable, naming the failed source and offering retry/settings when applicable.

## 5. Layout Principles

- Mobile-first single-column layout with 20px page gutters.
- Spacing rhythm: 4, 8, 12, 16, 24, 32.
- One visual anchor per screen. Supporting data follows in rows or a timeline.
- No overlapping elements or absolute-positioned decorative layers.
- No three-equal-card score grid. Use a dominant metric plus a horizontal supporting strip or vertical list.
- Tap targets are at least 44×44 logical pixels.
- Respect edge-to-edge system insets on every Android device; no model-specific pixel assumptions.
- At large text scale, rows wrap vertically rather than clip or shrink text.
- Detail screens preserve the selected date and back-navigation context.

## 6. Motion & Interaction

- Default transition: 180–240ms ease-out with spring character (`stiffness ≈ 100`, `damping ≈ 20`).
- Animate only opacity and transforms for page/module entry.
- Score changes cross-fade and scale subtly; never spin or bounce.
- Lists may reveal with a maximum 25ms stagger and must render immediately under reduced-motion settings.
- Pull-to-refresh, button presses, and successful logs use restrained haptics.
- Perpetual motion is limited to genuinely active states such as an in-progress workout or current sync; static dashboards remain still.
- Reduced-motion preference disables nonessential transitions.

## 7. Content Rules

- State the observation, source, comparison, and next action in that order.
- Say “associated with,” never “caused by,” for journal correlations.
- Never diagnose, claim clinical accuracy, or prescribe training from incomplete data.
- Every health value has a source, time range, freshness, and availability state.
- Demo data exists only in an explicitly labeled demo mode and never shares storage with a real profile.
- Prefer plain terms: “Heart-rate data,” “Last synced,” “Building your baseline,” “No sleep data for this day.”

## 8. Anti-Patterns (Banned)

- No emojis.
- No Inter or serif typefaces.
- No pure black.
- No neon, outer glow, or glass-blur navigation.
- No large saturated metric-color backgrounds.
- No generic three-column/equal-card metric grids.
- No fake round numbers or fabricated sample health readings.
- No centered marketing hero inside the application.
- No excessive uppercase labels.
- No filler instructions such as “Swipe down” or “Scroll to explore.”
- No AI copywriting clichés such as “Elevate,” “Seamless,” “Unleash,” or “Next-Gen.”
- No unsupported “optimal,” “clinical-grade,” or diagnostic wording.
- No animated width/height/top/left properties.
