# Trot Design System

Trot is a UK iOS app that helps dog owners walk their dogs every day. The dog is the user, not the human. The app feels warm, capable, and never preachy.

This design system is the source of truth for everything visual and verbal in Trot — across the iOS app, the landing page, and any future surfaces.

## Sources

This design system was derived from the Trot project codebase (mounted via File System Access). Specifically:

- `Trot/docs/brand.md` — the upstream brand & tokens doc (mirrored and extended here)
- `Trot/docs/spec.md` — product spec
- `Trot/docs/architecture.md` — technical architecture
- `Trot/docs/landing.md` — landing page brief
- `Trot/docs/decisions.md` — decisions log
- `Trot/CLAUDE.md` — working-style and engineering rules
- `Trot/design-reference/` — was empty at time of generation; this project produces the first round of visual reference

The reader of this design system is not assumed to have access to the codebase, but file paths are recorded so they can be re-pulled if needed.

---

## Product summary

Trot is iOS-only for v1, UK launch. Built around a single core habit: walk the dog every day, hit the dog's exercise needs, don't break the streak.

Surfaces:

- **iOS app** — SwiftUI / SwiftData + CloudKit / HealthKit. Passive walk detection, dog-centric stats, daily targets, streaks, weekly recap.
- **Landing page** — `trot.dog`. Single page: hero, three feature blocks, CTA, footer. Built from real HTML/CSS, not a framework.

Key product principles (the dog is the user; confident, not chirpy; warm but credible; daily ritual; show, don't shout) are encoded into every visual and copy decision below.

---

## Content fundamentals

### Voice

Warm, plain English, never preachy, occasionally dry. Like a knowledgeable friend who shares what they know without lecturing.

### Tone shifts

- **Onboarding** — welcoming, clear, sets expectations honestly
- **Daily flows** — matter-of-fact, supportive
- **Celebrations** (streak milestones, weekly recaps) — warm, slightly playful
- **Errors / warnings** — direct, practical, never alarming

### Casing

Sentence case everywhere — UI labels, buttons, titles, navigation, push notifications. No Title Case for buttons. No SHOUTING. Numbers as digits ("30 minutes" not "thirty minutes").

### Person

Second person, addressing the human about their dog. The dog is referred to by name whenever possible.

- Right: "Luna's had 15 minutes today. Her target is 60."
- Wrong: "We noticed your dog has been quiet today."

Trot itself does not narrate in the first person plural ("we noticed…"). It talks directly.

### Always

- Use the dog's name. "Luna's been quiet today" hits harder than "Your dog has been quiet today."
- Plain English. "30 minutes" not "a half-hour walking session."
- Specific over generic. "Beagles need 60–90 minutes daily" not "your dog needs regular exercise."

### Never

- Dog puns: "Pawsome", "barktastic", "fur-ever", "ruff", or any pun on dog sounds or body parts
- Exclamation marks in regular flows (only in genuine celebration moments)
- Em dashes in copy
- "We" speaking on behalf of Trot — be direct
- Guilt-trip framing. "Luna hasn't walked enough" is fine. "Don't let Luna down" is not.
- Emoji in product copy

### Voice in practice

| Context | Wrong | Right |
|---|---|---|
| Walk detected | "Awesome walk! 🎉" | "28-minute walk. Was that with Luna?" |
| Streak hit 14 days | "Amazing streak!! Keep going!!" | "14 days. Luna's longest streak so far." |
| Under target | "Don't let Luna down today!" | "Luna's had 15 minutes today. Her target is 60." |
| Welcome | "Welcome to your fitness journey!" | "Tell us about your dog." |
| Empty activity | "No walks yet — let's get going!" | "No walks logged yet. Trot will detect them automatically once permissions are granted." |

### Numbers and units

- UK English. "kilometres", "metres", "favourite", "colour".
- Time of day in 24-hour where it's a window ("5–9"); 12-hour with am/pm in body copy.
- Minutes for walks. Hours only at weekly aggregate level.

---

## Logo

The Trot wordmark is **D1B canonical** (locked after a four-direction exploration: confident wordmark, dog silhouette, T-as-leash, and pawprint reframed). The chosen mark is the lowercase `o` with a coral spot inside its counter — the dot is the brand.

- **Wordmark** — "Trot" set in Bricolage Grotesque 700, letter-spacing `-0.045em`, with a small coral spot (`--brand-primary`) inside the counter of the lowercase `o`. The spot is the brand mark — it's what makes the logo feel like Trot and not like generic display type. Sizes `28px / 56px / 80px` are tuned in `preview/01-logo.html`.
- **App icon / standalone mark** — the lowercase `o` with the spot, on cream / coral / evergreen tile. The icon IS the dot inside the o; do not substitute a paw, a T, or a dog.
- **Mono stamp** — same wordmark, spot recoloured to match the text colour, for favicons and one-colour print.

Source files:

- `assets/logo-wordmark.svg` — primary wordmark (220×80)
- `assets/logo-icon.svg` — app icon on cream (100×100)
- `assets/logo-icon-mono.svg` — mono icon, uses `currentColor`
- `preview/01-logo.html` — full lockup grid (cream / coral / evergreen / dark / small / mono)

Rules: never re-letter the wordmark in another font, never tilt or skew, never add a tagline lockup, never use the spot as a standalone mark without the o around it.

---

## Visual foundations

### Palette philosophy

Three working ideas: **warmth** (the joy), **nature** (the walks), **calm** (the surfaces). The brand reads as a warm coral primary against a cream surface, with deep evergreen as a grounded counterweight. No cool grays, no pure black, no pure white in surfaces.

### Type philosophy

SF Pro for all UI — free, perfectly rendered, supports Dynamic Type and accessibility. The brand display face (**Bricolage Grotesque**) is reserved for moments of brand expression: onboarding, weekly recap headers, streak milestones, the landing page hero. Never used in regular UI chrome.

### Spacing

4pt base scale. Default screen padding `space.lg` (24). Default card padding `space.md` (16). Default vertical rhythm between sections `space.xl` (32). No magic numbers ever.

### Backgrounds

Surfaces are flat. The app surface is warm off-white (`#FAF7F2`), not pure white. Cards and sheets are pure white (`#FFFFFF`) and sit on the surface with a soft shadow. **No gradients, no patterns, no textures, no full-bleed marketing imagery in app chrome.** The dog photo is the visual hero — it's always the largest coloured element on the screen.

The landing page reuses the same surface tone. Hero imagery is one tightly-composed phone screenshot, never a stock photo backdrop.

### Imagery

The user's dog is the hero. Their photo is large, well-cropped, never decorative.

Stock photography (used sparingly, for marketing or empty states only):

- Real dogs in real moments. Slightly imperfect lighting. Mid-walk, not posed.
- Mix of breeds, sizes, life stages.
- Owner often partial — a hand on a lead, a knee, the dog from the owner's eye level.
- Soft, warm, naturalistic light.
- Avoid: studio-perfect grooming shots, professional dog modelling, anything that looks like a stock library.

Image colour vibe: warm, naturalistic. No heavy filters, no b&w, no synthetic grain. Cropping is generous and asymmetric — the dog can be off-centre, can run out of frame.

### Animation

Spring animations everywhere. Native iOS feel.

- **Default spring:** `response: 0.4, dampingFraction: 0.8` (gentle for state changes)
- **Celebration spring:** `response: 0.5, dampingFraction: 0.6` (slightly bouncier — streak milestones, walk confirmations, weekly recap reveals)

Things that get animation: streak increments, walk confirmations, weekly recap reveals, sheet presentations.
Things that don't: regular state changes, scrolling, predictable transitions.

Motion is celebratory, never mandatory. CSS analogues for the web: `cubic-bezier(0.32, 0.72, 0, 1)` over 240ms for default; `cubic-bezier(0.34, 1.56, 0.64, 1)` over 380ms for celebrations.

### Hover / press states

- **Hover (web):** primary buttons darken by ~6% (`color-mix(in oklab, var(--brand-primary), black 6%)`). Secondary surfaces lift via shadow, not by changing colour. Links underline on hover only — never by default.
- **Press (iOS and web):** buttons scale to 0.97 with the default spring. Cards scale to 0.99. Colour does not change on press.
- **Focus:** 2pt ring in `--brand-primary` at 35% alpha, offset 2pt. Always visible for keyboard.

### Borders, dividers, shadows

- Hairline dividers: `--brand-divider` (`#EAE3D9`) at 1px. Used between list rows, never on cards.
- Card border: none. Cards rely on shadow + radius.
- **Default card shadow:** `0 1px 2px rgba(31,27,22,0.04), 0 4px 16px rgba(31,27,22,0.06)`
- **Elevated shadow** (sheets, popovers): `0 12px 48px rgba(31,27,22,0.12)`
- Never stack shadows on stacked cards. The container gets the shadow; nested elements stay flat.
- No inner shadows.

### Capsules vs protection gradients

Capsules over protection gradients. When a control sits on top of a photo (e.g. "Log walk" button below the dog photo), the control is its own elevated capsule — pure white pill on shadow — not a darkening gradient over the image.

The only place a gradient appears: a very subtle bottom-fade on the dog photo card to keep edge text legible (`rgba(31,27,22,0) → rgba(31,27,22,0.35)`). Used only when text overlays the photo. Default is to keep text outside the photo entirely.

### Transparency and blur

Used sparingly. Sheet backdrops use a 35% black scrim, no blur. The iOS large nav bar uses a system material when content scrolls under it. No frosted-glass cards, no glassmorphism.

### Corner radii

| Token | Value | Usage |
|---|---|---|
| `radius.sm` | 8 | Pills, chips, small inputs |
| `radius.md` | 12 | Buttons, list cells |
| `radius.lg` | 16 | Cards, sheets |
| `radius.xl` | 24 | Hero cards, photo containers |

The dog photo and any dog-avatar are pure circles, no exceptions.

### Cards

Surface elevated white (`--brand-surface-elevated`), `radius.lg`, default shadow, `space.md` padding. No border. One card per logical chunk; never stack shadowed cards inside shadowed cards.

### Layout rules

- App: single column, full-width within the safe area, `space.lg` (24) horizontal padding.
- Top of every screen: large title (sentence case), then content. No breadcrumbs.
- Sticky elements: only the system tab bar. No sticky CTAs in the body.
- Bottom safe-area: a `space.lg` cushion below the last card so it doesn't kiss the tab bar.

### Empty states

Always present. An empty state has: an icon or simple illustration, a one-sentence explanation, a clear next action. Never a blank screen.

---

## Iconography

See **ICONOGRAPHY** below for full detail. Short version: **SF Symbols by default** for the iOS app. For the web (landing, this design system), we substitute **Lucide** as the closest open-stroke equivalent — Lucide is free, has matching stroke weights, and is CDN-available. This is a documented substitution; on Apple platforms, always prefer SF Symbols.

Custom illustration is allowed only for: empty states with personality, onboarding hero, weekly recap, the landing page hero. Style is line-based, slightly imperfect, warm. Never cartoonish, never corporate. Never use emoji or unicode characters as icons.

---

## Index

Files in this design system:

- `README.md` — this file
- `SKILL.md` — Agent Skill manifest (Claude Code compatible)
- `colors_and_type.css` — CSS custom properties for tokens + semantic styles (`--fg-1`, `--brand-primary`, `h1`, `p`, etc.)
- `fonts/` — Bricolage Grotesque variable font + license
- `assets/` — logos (SVG), placeholder dog photos, brand marks
- `preview/` — small HTML cards that populate the Design System tab
- `ui_kits/ios-app/` — interactive iOS UI kit recreating Home, Activity, Onboarding, Walk Confirmation
- `ui_kits/landing/` — interactive landing page recreation

### UI kits

| Kit | Path | Purpose |
|---|---|---|
| iOS app | `ui_kits/ios-app/index.html` | Click-through Home, Activity, Walk Confirmation, Onboarding |
| Landing | `ui_kits/landing/index.html` | The trot.dog single-page recreation |

