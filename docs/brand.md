# Trot — Brand and design system

This document covers brand essence, voice, principles, and component usage rules.

**Design tokens (color, type, spacing, radius, shadow, motion) live in `design-reference/Trot Design System/colors_and_type.css`.** That file is the single source of truth. Swift extensions in `ios/Trot/Core/DesignSystem/` mirror it 1:1. CSS leads, Swift follows.

For long-form design guidance — palette philosophy, type philosophy, layout rules, hover/press states, elevation, capsules, transparency, iconography — see `design-reference/Trot Design System/README.md`.

---

## Name

**Trot.**

A dog's gait — the steady, rhythmic walking pace dogs settle into when they're moving with purpose. Single syllable, easy in any accent, distinctly canine without being literal or cliche. Suggests motion, daily rhythm, and momentum.

Pronounced as it reads. /trɒt/.

**Tagline options to test:**
- "Walks your dog, every day."
- "The daily walking habit, for your dog."
- "Built around your dog."

## Brand essence

Trot is the dog walking app that takes your dog's needs seriously. Warm, capable, never preachy. It's about doing right by your dog, not earning gold stars.

The user is a competent adult who loves their dog. Trot treats them that way. No condescension, no infantilising language, no fake urgency.

## Principles

These five principles guide every visual and copy decision. When in doubt, return to them.

1. **The dog comes first.** Every screen treats the dog as the user. Stats are the dog's stats. Streaks are the dog's streaks. The human is along for the ride.
2. **Confident, not chirpy.** Trot trusts its users. It doesn't cheerlead. No "Amazing!", no "You're crushing it!", no exclamation marks except in genuine celebration moments.
3. **Warm but credible.** Like a knowledgeable friend, not a marketing brochure. Real warmth, not performative cuteness.
4. **Daily ritual, not daily chore.** Trot should feel good to open. Calm, not demanding. Inviting, not naggy.
5. **Show, don't shout.** Color, type, and motion are used sparingly so they mean something. A streak milestone deserves a moment. A regular walk doesn't need fireworks.

## Voice and tone

**Voice:** warm, plain English, never preachy, occasionally dry. The kind of friend who knows a lot about dogs and shares it without lecturing.

**Tone shifts by context:**
- Onboarding: welcoming, clear, sets expectations honestly
- Daily flows: matter-of-fact, supportive
- Celebrations (streak milestones, weekly recaps): warm, slightly playful
- Errors and warnings: direct, practical, never alarming

**Always:**
- Use the dog's name. "Luna's been quiet today" hits harder than "Your dog has been quiet today."
- Plain English. "30 minutes" not "a half-hour walking session."
- Specific over generic. "Beagles need 60-90 minutes daily" not "your dog needs regular exercise."

**Never:**
- "Pawsome", "barktastic", "fur-ever", "ruff", or any pun on dog sounds or body parts
- Exclamation marks in regular flows
- Em dashes in copy
- "We" speaking on behalf of Trot ("we noticed..."). Be direct.
- Guilt-trip framing. "Luna hasn't walked enough" is fine. "Don't let Luna down" is not.

**Voice examples in practice:**

| Context | Wrong | Right |
|---|---|---|
| Walk detected | "Awesome walk! 🎉" | "28-minute walk. Was that with Luna?" |
| Streak hit 14 days | "Amazing streak!! Keep going!!" | "14 days. Luna's longest streak so far." |
| Under target | "Don't let Luna down today!" | "Luna's had 15 minutes today. Her target is 60." |
| Welcome | "Welcome to your fitness journey!" | "Tell us about your dog." |

---

## Tokens

All design tokens — color, type, spacing, radius, shadow, motion — live in `design-reference/Trot Design System/colors_and_type.css`. That file is authoritative.

**Token categories** (read the CSS for the actual values):
- Color: brand primary/secondary with pressed states, three surface levels, three text levels, on-primary/on-secondary, success/warning/error, divider, divider-strong, five tinted backgrounds. `--fg-1/2/3` and `--bg-1/2/3` semantic aliases.
- Type: Bricolage Grotesque (display, brand expression only) + SF Pro (UI). Sizes from caption (13px) to display-lg (48px). Leading and tracking tokens.
- Spacing: 4pt scale, `space-xs` (4) through `space-huge` (64).
- Radius: `sm` (8), `md` (12), `lg` (16), `xl` (24), `circle` (9999).
- Elevation: `shadow-card`, `shadow-elevated`, `shadow-pressed`.
- Motion: `ease-default` and `ease-celebration` cubic-béziers, `dur-default` (240ms) and `dur-celebration` (380ms).

**Dark mode is opt-in via `data-theme="dark"` on the web side. iOS forces light mode (`UIUserInterfaceStyle = Light` in Info.plist) for v1.** The dark token set in CSS exists for future expansion; no iOS asset catalog dark variants are defined.

**Usage rules:**
- One `--brand-primary` accent per screen, max two
- `--brand-secondary` (evergreen) is for grounding, not competing with primary
- Never use raw hex in code. Always reference the semantic token
- Pure circles for the dog photo and any dog-avatar component

## Iconography

**Default to SF Symbols.** Free, perfectly rendered, dynamic, accessible. They cover ~90% of needs.

**Custom illustration only for:**
- Empty states (genuine moments where personality matters)
- Onboarding hero illustrations
- Weekly recap moments
- The landing page hero

When custom illustration is needed, the style is line-based, slightly imperfect, warm. Never cartoonish, never corporate.

## Logo

**Locked.** The mark is the lowercase `o` with a coral spot inside its counter — the dot is the brand. Wordmark set in Bricolage Grotesque 700, `letter-spacing: -0.045em`. Source files at `design-reference/Trot Design System/assets/logo-{wordmark,icon,icon-mono}.svg`.

**Three lockups:**
- Wordmark (220×80 SVG): "Trot" with the coral spot in the `o`. Used for headers, in-app branding, landing page hero.
- App icon / standalone mark (100×100 SVG, exported to 1024×1024 PNG for the iOS asset catalog): the lowercase `o` with the spot, on a coral or cream tile. Tighter `o` treatment for the icon scale so the spot reads inside Apple's icon mask safe area.
- Mono stamp: same wordmark, spot recoloured to match text colour. For favicons and one-colour print.

**Rules:**
- Never re-letter the wordmark in another font
- Never tilt or skew
- Never add a tagline lockup
- Never use the spot as a standalone mark without the `o` around it
- The wordmark in SwiftUI is a custom `View` that overlays the spot at the right pixel inside the `o` — built once, reused everywhere. No attributed-string hacks.

## Photography and imagery

**The user's dog is the hero.** Their photo is large, well-cropped, never decorative.

**Stock photography style** (where we need it for marketing or empty states):
- Real dogs in real moments. Slightly imperfect lighting. Mid-walk, not posed.
- Mix of breeds, sizes, life stages
- Owner often partial — a hand on a lead, a knee, the dog from the owner's eye level
- Soft, warm, naturalistic light
- Avoid: studio-perfect grooming shots, professional dog modelling, anything that looks like a stock library

## Motion

Spring animations everywhere. iOS native feel.

- Default spring: `response: 0.4, dampingFraction: 0.8` — gentle, for state changes
- Celebration spring: `response: 0.5, dampingFraction: 0.6` — bouncier, for streak milestones, walk confirmations, weekly recap reveals

Web analogues are in `colors_and_type.css` as `--ease-default` and `--ease-celebration` with matching durations.

Things that don't need animation: regular state changes, scrolling, predictable transitions.
Things that do: streak increments, walk confirmations, weekly recap reveals, sheet presentations.

Motion is celebratory, never mandatory.

## Component principles

**Buttons:** primary, secondary, destructive, plain. No more variants in v1.

**Cards:** surface elevated by `radius.lg`, soft shadow, internal padding `space.md`. Never multiple cards stacking shadow effects.

**Inputs:** clear, large touch target (minimum 44pt height), label above, helper text below. Error states use `brand.error` and an icon.

**Lists:** prefer cards over plain rows for primary content (walks, dogs). Plain rows for settings and secondary content.

**Empty states:** always have one. Never show a blank screen with no context. An empty state has: an illustration or icon, a one-sentence explanation, a clear action.

---

## SwiftUI implementation

Token files live in `ios/Trot/Core/DesignSystem/` as Swift extensions. Each one mirrors `colors_and_type.css` 1:1. **CSS leads, Swift follows** — when a new token is needed, add it to the CSS first, then propagate to Swift.

The four files (planned, not yet built):
- `BrandColor.swift` — `extension Color` with one entry per CSS color token, asset-catalog backed
- `BrandFont.swift` — `extension Font` with display + title + body + caption. Display uses `Font.custom("BricolageGrotesque", ...)` with `relativeTo:` so Dynamic Type works
- `BrandTokens.swift` — `enum Space`, `enum Radius` with the CSS values mirrored as `CGFloat`
- `BrandMotion.swift` — `extension Animation` with `brandDefault` and `brandCelebration`
- `TrotLogo.swift` — the custom logo view that overlays the coral spot inside the lowercase `o` of the wordmark, scales correctly at any size

Views reference tokens (`Color.brandPrimary`, `Space.md`, `Radius.lg`, `.animation(.brandDefault, value: ...)`), never raw values.

**Bricolage Grotesque ships in the iOS bundle as `.ttf` (converted from the .woff2 source in the design system folder).** The asset catalog colors are light-only — no dark variants in v1.

---

## Web (landing page)

The landing page links `colors_and_type.css` directly — no duplicate variable definitions. The landing source lives at `design-reference/Trot Design System/ui_kits/landing/index.html` and drops into `web/`.

When tokens change, edit `colors_and_type.css` once. Both surfaces pick it up.
