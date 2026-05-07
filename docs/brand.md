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
- "Luna says: walk?"
- "Your dog's adventure log."

## Brand essence

Trot exists to get dogs walked. Every day. Even on the wet Tuesday in February when the user doesn't want to go.

The user is a dog owner who already loves their dog and already knows they should walk them more. They don't need education. They need a reason to put the lead on *right now*. Trot gives them that reason — repeatedly, generously, in the dog's voice.

The app is a translator. We speak for Luna because Luna can't text you herself. That framing earns us licence: when Luna celebrates a walk, it's not the app cheerleading the human. It's the dog. Which lands differently.

Walking your dog daily is a moral good. So we use the tools we have — variable rewards, streaks, anticipation, loss aversion, dopamine, celebration — to make it happen. We don't apologise for that. The dog is better off, the user is better off, and the app earns its keep on every walk it produces.

## Principles

Five principles. Every visual and copy decision is judged against them.

1. **Get the walk.** Every screen, notification, and animation has one job: make the next walk happen. Anything that doesn't move that needle is noise and gets cut.

2. **Speak for the dog.** Luna is the protagonist *and* the voice. "Luna says…" beats "your dog needs…" every time. AI-generated dog-voice is honest about its origin — "Luna's diary, written by Trot from her walks" — never hidden, never embarrassed.

3. **Celebrate hard, routine soft.** Walk completed, landmark crossed, streak hit, milestone unlocked — turn the volume *up*. Bricolage Grotesque, exclamation marks, big springs, big type. Routine surfaces (settings, profile, edit forms) stay calm. The contrast is what makes celebration land. If everything shouts, nothing does.

4. **Earn the next walk.** Every interaction should make the next walk feel inevitable. Not "you should walk." More: "Luna's 240m from the Tea Hut. Let's go." Specific, time-bounded, dog-anchored, pulling the user forward instead of pushing them.

5. **No shame, no fake urgency.** We motivate by pull, not push. The user is never shamed for missing a day. Luna isn't "disappointed in you." Decay — the visual response to days without a walk — is quiet and sad-for-the-dog, never accusatory of the human. "Luna's been waiting" — yes. "You let Luna down" — never.

## Voice and tone

**Voice:** warm, plain English, occasionally dry, **excited when there's something to be excited about**. The kind of friend who knows your dog and texts you "BRIDGE TODAY?" at 7am because they know you'd want the nudge.

Trot has two speakers:
- **Trot itself** — the app's narrative voice. Used for facts, observations, settings, the routine of the daily loop.
- **Luna** (or whatever the dog is called) — generated dog-voice for celebration moments, push notifications, daily lines, walk diaries. Always credited as "Luna says…" or formatted as a diary entry, never blended in as if Luna typed it on her phone.

**Tone shifts by surface:**
- **Onboarding** — welcoming, fast, hooks the user before the form is finished. We just met Luna, we're already excited about her.
- **Daily routine surfaces** (Home outside celebration moments, Activity, settings) — matter-of-fact, supportive, dog-centric. Calm by design so celebrations land.
- **Celebrations** (every walk save, every landmark, every milestone, every streak tier) — **loud**. Bricolage Grotesque, exclamation marks allowed and encouraged, big motion, share-worthy by default. This is the dopamine surface. Do not whisper here.
- **Push notifications** — dog-voice when possible ("Luna's still hoping for a walk."), factual when not.
- **Decay states** (3+ days no walk) — quiet, sad-for-Luna, never accusatory. Volume goes *down*, not up.
- **Errors** — direct, practical, never alarming.

**Always:**
- Use the dog's name. Always. "Luna's been quiet today" hits harder than "your dog has been quiet today" every single time.
- Label dog-voice openly. "Luna says…", "From Luna:", "Luna's diary." Honesty makes it land harder, not less.
- Plain English. "30 minutes" not "a half-hour walking session."
- Specific over generic. "Beagles need 60-90 minutes daily" not "your dog needs regular exercise."
- Numbers when they pull. "240m to the Bench" beats "almost there."

**Never:**
- Shame the user. "Don't let Luna down" — never. "You let her down" — never. We do not weaponise the relationship between user and dog against the user.
- Fake urgency in routine flows. "Last chance!" for things that aren't actually time-limited. That's manipulation, not motivation.
- Pretend AI dog-voice is human-written. Lean in: "Luna's diary, written by Trot from her walks." Honesty is the brand here.
- Generic startup celebrations. "Amazing!", "You're crushing it!", "Way to go!". We celebrate *specific* things in *specific* dog-voice. "14 days with Luna. Her longest yet." not "Amazing! 14 days!"
- "Pawsome", "barktastic", "fur-ever", "ruff" — any pun on dog sounds or body parts. Still bad copy, even with the volume up.
- Em dashes in copy.
- "We" speaking on behalf of Trot ("we noticed…"). Be direct.

**Voice examples in practice:**

| Context | Wrong | Right |
|---|---|---|
| First walk save | "Walk logged." | "Luna's first walk with Trot. Let's go!" *(cinematic moment, share card generated)* |
| Walk save (routine) | "Walk logged." | "30 minutes with Luna. 240m closer to the Tea Hut!" *(with celebration animation)* |
| Streak hit 14 days | "14 days." | "14 days with Luna. Her longest yet." *(Bricolage, big type, celebration spring)* |
| Daily Home line | "Today's walks: 0/60 min." | "Luna says: bridge today?" *(LLM-generated, refreshed daily)* |
| Under target at 8pm | "Don't let Luna down today!" | "Luna's still hoping for a walk." *(dog-voice push)* |
| Decay, 5 days no walk | "You haven't walked Luna in 5 days." | "Luna's been waiting." *(quiet, photo card desaturating)* |
| Welcome | "Welcome to your fitness journey!" | "Show us Luna." *(photo upload first, fields after)* |
| Settings | "Adjust your preferences." | "Settings." *(routine surface, no flourish needed)* |

---

## Tokens

All design tokens — color, type, spacing, radius, shadow, motion — live in `design-reference/Trot Design System/colors_and_type.css`. That file is authoritative.

**Token categories** (read the CSS for the actual values):
- Color: brand primary/secondary with pressed states, three surface levels, three text levels, on-primary/on-secondary, success/warning/error, divider, divider-strong, five tinted backgrounds. `--fg-1/2/3` and `--bg-1/2/3` semantic aliases.
- Type: Bricolage Grotesque (display, brand expression and celebration moments) + SF Pro (UI). Sizes from caption (13px) to display-lg (48px). Leading and tracking tokens.
- Spacing: 4pt scale, `space-xs` (4) through `space-huge` (64).
- Radius: `sm` (8), `md` (12), `lg` (16), `xl` (24), `circle` (9999).
- Elevation: `shadow-card`, `shadow-elevated`, `shadow-pressed`.
- Motion: `ease-default` and `ease-celebration` cubic-béziers, `dur-default` (240ms) and `dur-celebration` (380ms).

**Dark mode is opt-in via `data-theme="dark"` on the web side. iOS forces light mode (`UIUserInterfaceStyle = Light` in Info.plist) for v1.** The dark token set in CSS exists for future expansion; no iOS asset catalog dark variants are defined.

**Usage rules:**
- One `--brand-primary` accent per routine screen. Celebration screens may saturate freely.
- `--brand-secondary` (evergreen) is for grounding, not competing with primary.
- Never use raw hex in code. Always reference the semantic token.
- Pure circles for the dog photo and any dog-avatar component.

## Iconography

**Default to SF Symbols.** Free, perfectly rendered, dynamic, accessible. They cover ~90% of needs.

**Custom illustration only for:**
- Empty states (genuine moments where personality matters)
- Onboarding hero illustrations
- Celebration moments (first walk, milestone unlocks, weekly recap, streak tiers)
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

**The user's dog is the hero.** Their photo is large, well-cropped, never decorative. In celebration moments the photo grows, gets a coral ring, or pulses — the dog itself is the visual anchor of every win.

**Stock photography style** (where we need it for marketing or empty states):
- Real dogs in real moments. Slightly imperfect lighting. Mid-walk, not posed.
- Mix of breeds, sizes, life stages
- Owner often partial — a hand on a lead, a knee, the dog from the owner's eye level
- Soft, warm, naturalistic light
- Avoid: studio-perfect grooming shots, professional dog modelling, anything that looks like a stock library

## Motion

**Default is motion. Restraint is reserved.** This flips the v1 default — celebration is the rule for moments that matter, calm is the rule for routine surfaces.

**Springs:**
- **Default spring:** `response: 0.4, dampingFraction: 0.8` — gentle, for routine state changes
- **Celebration spring:** `response: 0.5, dampingFraction: 0.6` — bouncier, for any walk-related win
- **Anticipation pulse:** subtle `scaleEffect` repeat, for things-to-look-forward-to (next landmark, daily quest, near-streak-milestone)

Web analogues are in `colors_and_type.css` as `--ease-default` and `--ease-celebration` with matching durations.

**Things that animate (default):**
- Walk save → full celebration overlay, every time
- Landmark crossed → mid-walk toast, post-walk recap pulse
- Streak increment → number flips, ring fills
- Milestone unlock → ladder ceremony, share card animation
- Home screen open → dog photo subtle bobbing/breathing, target ring fills on appear
- Tab transitions, sheet presentations

**Things that don't animate (deliberate stillness):**
- Settings, profile, edit forms, account screens
- Errors (direct, no bounce)
- Decay states (slow fades only — sadness is calm)
- Scrolling, predictable list updates

The contrast is the point. If routine surfaces are calm, the celebration moments hit harder. Don't waste motion on the thirty-fifth scroll. Spend it on the win.

## Component principles

**Buttons:** primary, secondary, destructive, plain. No more variants in v1.

**Cards:** surface elevated by `radius.lg`, soft shadow, internal padding `space.md`. Never multiple cards stacking shadow effects.

**Inputs:** clear, large touch target (minimum 44pt height), label above, helper text below. Error states use `brand.error` and an icon.

**Lists:** prefer cards over plain rows for primary content (walks, dogs). Plain rows for settings and secondary content.

**Empty states:** always have one. Never show a blank screen with no context. An empty state has: an illustration or icon, a one-sentence explanation, a clear action. For dopamine surfaces (Insights pre-walk-1, Journey pre-route-start), the empty state is *itself* an anticipation hook ("Your first walk unlocks Luna's first observation.").

**Celebration overlays:** full-screen takeovers for moments-that-matter (first walk, route completion, milestone tiers). Always include the dog photo, always use Bricolage display type, always tap-to-dismiss, always emit a share card option for milestones the user might brag about.

---

## SwiftUI implementation

Token files live in `ios/Trot/Core/DesignSystem/` as Swift extensions. Each one mirrors `colors_and_type.css` 1:1. **CSS leads, Swift follows** — when a new token is needed, add it to the CSS first, then propagate to Swift.

The four files (planned, not yet built):
- `BrandColor.swift` — `extension Color` with one entry per CSS color token, asset-catalog backed
- `BrandFont.swift` — `extension Font` with display + title + body + caption. Display uses `Font.custom("BricolageGrotesque", ...)` with `relativeTo:` so Dynamic Type works
- `BrandTokens.swift` — `enum Space`, `enum Radius` with the CSS values mirrored as `CGFloat`
- `BrandMotion.swift` — `extension Animation` with `brandDefault`, `brandCelebration`, and `brandAnticipation`
- `TrotLogo.swift` — the custom logo view that overlays the coral spot inside the lowercase `o` of the wordmark, scales correctly at any size

Views reference tokens (`Color.brandPrimary`, `Space.md`, `Radius.lg`, `.animation(.brandCelebration, value: ...)`), never raw values.

**Bricolage Grotesque ships in the iOS bundle as `.ttf` (converted from the .woff2 source in the design system folder).** The asset catalog colors are light-only — no dark variants in v1.

---

## Web (landing page)

The landing page links `colors_and_type.css` directly — no duplicate variable definitions. The landing source lives at `design-reference/Trot Design System/ui_kits/landing/index.html` and drops into `web/`.

When tokens change, edit `colors_and_type.css` once. Both surfaces pick it up.
