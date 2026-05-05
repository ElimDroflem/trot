# Trot iOS UI kit

Click-through recreation of the Trot iOS app, matching `docs/spec.md` and `docs/brand.md`.

## Files

- `index.html` — the kit entry point. Includes a Tweaks panel for switching Home interpretations and adjusting today's data.
- `components.jsx` — reusable: `TrotButton`, `TrotCard`, `TrotProgressRing`, `TrotStreak`, `TrotWalkRow`, `TrotTabBar`, plus `trotTokens`.
- `home-variants.jsx` — three brand interpretations of the Home screen (per the design brief):
  1. **Warm + joyful** — sunny, photo-led, optimistic
  2. **Outdoorsy + grounded** — earthy, evergreen, paper-feel
  3. **Modern + confident** — type-driven, clean, premium
- `screens.jsx` — `ActivityScreen`, `WalkConfirmation` (sheet), `OnboardingDog`.
- `ios-frame.jsx` / `tweaks-panel.jsx` — starter components.

## Tweaks

Toggle the Tweaks switch in the toolbar to:
- Cycle the three Home interpretations
- Adjust minutes walked, target, streak length
- Show/hide the walk-confirmation sheet
- Switch between "view all screens" and a single focused screen

## Iconography

Lucide via CDN. On native iOS the equivalent SF Symbols are: `figure.walk` (footprints), `flame.fill`, `bell.fill`, `calendar`, `heart`, `lightbulb`, `gear`, `plus`.
