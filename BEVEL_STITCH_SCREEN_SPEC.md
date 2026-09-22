# Bevel Vitality — Today Screen Design Spec

## Visual direction

Calm, clinical, premium iOS health dashboard. Use a light grouped canvas with white elevated cards, compact telemetry, and one dominant recovery score. The screen should feel trustworthy and measured rather than decorative.

## Canvas and surfaces

- Background: `#F2F2F7`
- Cards: `#FFFFFF`
- Primary text: `#1C1C1E`
- Secondary text: `#8E8E93`
- Dividers: `#E5E5EA`
- Card radius: 16–20px
- Card shadow: very soft ambient shadow only
- Safe horizontal margin: 16–20px

## Functional colors

- Active navigation / links: `#007AFF`
- Recovery / positive state: `#34C759`
- Strain / alert state: `#FF2D55`
- Sleep: `#5856D6`
- Respiratory / temperature: `#00C7BE`

## Screen structure

1. Header with avatar, `BEVEL VITALITY`, `Today`, and calendar affordance.
2. Dominant Daily Readiness card with green 88% recovery ring, “Optimal Recovery” copy, baseline delta, and suggested target strain.
3. Compact metric strip: HRV, RHR, Skin Temp.
4. Two-column cards: Day Strain and Sleep Rest.
5. Energy Bank card with progress bar, capacity, recharge estimate, and safe-until time.
6. Prescribed Protocol card with a single dark primary action and a Details action.
7. Clinical Biometrics list with Blood Oxygen, Respiratory Rate, and Vascular Strain rows.
8. Floating pill-shaped bottom navigation: Today, Recovery, Strain, Sleep, Profile.

## Typography

- Use a clean geometric sans such as Geist, Satoshi, or Outfit.
- Headings are compact and weight-led; avoid oversized marketing typography.
- Numeric values use tabular figures and tight tracking.
- Metadata uses uppercase labels with modest letter spacing.
- Body copy remains readable at 14–16px with relaxed line height.

## Interaction and motion

- Cards remain static; animate only score transitions, progress, opacity, and transforms.
- Use restrained spring feedback for buttons and navigation.
- Minimum touch target: 44×44px.
- No neon glow, glassmorphism, or decorative overlap.

## Content tone

Use concise observational language: “Optimal Recovery,” “primed for peak strain,” “Safe Until 23:30.” Avoid diagnostic claims, fake precision, emojis, and filler instructions.
