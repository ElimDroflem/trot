# Trot — v1 Specification

## Aim

Build an iOS app that promotes daily dog walking and keeps users coming back to stay accountable. Every design decision is judged against one question: does this get someone out the door on a wet Tuesday in February?

## Platform

iOS only for v1. iPhone first. iPad and Apple Watch out of scope. Android is a future consideration.

Built with Xcode 26.3+ and the iOS 26 SDK (mandatory for App Store as of April 2026). Deployment target: iOS 18.0. The first generation of SwiftData (iOS 17.0–17.3) had material CloudKit sync bugs; iOS 18 skips that bug surface entirely and the reach cost in 2026 is small.

Force light mode (`UIUserInterfaceStyle = Light` in Info.plist). The warm-cream brand surface is the visual identity; auto-switching to dark would defeat it. Dark mode is a v1.x or later exploration.

## Core principles

**The dog is the user, not the human.** Accounts are built around the dog. Stats, streaks, and progress belong to the dog. Opening Trot feels like checking on the pet, not yourself.

**Zero-effort baseline.** Walks should log without the user opening the app. Trot earns its place through insights, progression, and accountability — not through demanding interaction.

**Personalised but safe.** Exercise targets are tailored per dog, but generated from a vetted base table of breed and age guidance. Any LLM personalisation works within safe ranges, it does not invent the numbers.

**Hit the dog's needs, not arbitrary metrics.** Success is meeting the dog's daily exercise requirement consistently, not racking up steps or distance.

## User and account model

One human account holds multiple dogs. Each dog has its own profile, stats, streaks, and exercise plan.

**Dog profile fields:**
- Name
- Photo
- Breed (single or mixed, with primary breed selected)
- Age (date of birth, with life-stage flag: puppy, adult, senior)
- Weight
- Sex and neuter status
- Known health conditions (optional, free text plus common tickboxes — arthritis, hip dysplasia, brachycephalic breathing, etc.)
- Activity level baseline (low / moderate / high — user self-assessed)

## Onboarding flow

1. Sign in with Apple. iCloud required — if the user isn't signed in to iCloud, Trot directs them to Settings with copy framing it as a benefit ("Trot syncs Luna's data to your iCloud so you don't lose it.").
2. Add first dog — profile fields above.
3. Trot generates a daily exercise target. Base figure from `docs/breed-table.md`, then personalised within safe ranges by an LLM call routed through the Vercel proxy. Output is a target range in minutes with a short written rationale.
   - **On LLM failure** (network down, timeout, rate limit): onboarding does not block. Use the breed-table value, skip the rationale, retry on next app open. The proxy enforces an 8-second timeout.
4. User picks rough walk windows: Early morning (5-9), Lunchtime (11-2), Afternoon (2-6), Evening (6-10). Multi-select. Editable any time. Trot refines based on actual logged walks.
5. Permissions ask — HealthKit (motion and step data), Core Motion (walking activity states), notifications, plus the HealthKit background delivery entitlement. Framed around the dog: "so we can detect Luna's walks without you having to log them."
6. Done. User lands on the dog's home screen. Lifetime stats start at zero — Trot starts counting today, no backfill of pre-Trot history.

## Walk detection and logging

### Passive detection

Trot uses Core Motion (`CMMotionActivityManager`) as the primary signal for walking-state transitions, with HealthKit `HKObserverQuery` + `enableBackgroundDelivery` as the wake mechanism and `distanceWalkingRunning` for distance estimation. Monitoring is gated to the user's defined walk windows.

**The detection algorithm itself is technically open** — see decisions.md. Constraints captured:
- Core Motion as primary signal source (gives walking/running/stationary/automotive transitions, which step count alone does not)
- ≤3 minutes of stationary tolerated inside a walking session (sniff breaks, poo collection, lamp-post stops)
- ≤30 seconds of running tolerated inside a walking session (dog pulls, owner jogs after)
- Source filtering for Apple Watch workouts (treadmill, cycling) so they don't fire false positives
- Apple Watch users who manually start a walking workout follow a separate, more reliable detection path

**Known limitation:** within-window false positives for users whose jobs require walking (a postie who walks during their evening window) cannot be fully eliminated. The cost of a false positive is one dismissed notification.

When a walking session ends and the user has been still long enough to confirm session end, a local notification fires:

> "Looks like you just walked for 28 minutes. Was that with Luna?"

One tap confirms. The walk logs with duration, time of day, and a date stamp.

The full state machine and signal-fusion logic is deferred to a dedicated plan-mode session before the HealthKitService is built. This is the engine of the app and deserves more than a paragraph.

### Manual logging

Always available. Use cases:
- User left their phone at home
- Walk happened outside their usual window
- Multiple dogs walked together (see below)
- User prefers manual logging

Manual entry takes: which dog (or dogs), date and time, duration, optional notes.

### Multiple dogs walked together

Default-on per dog. Every walk credits all of the user's active dogs by default. User unticks any dog that wasn't on the walk. Matches reality — if you have two dogs, they almost always go together.

### User adjustments

Everything is editable. Walk duration, walk time, the dog's daily exercise target, walk windows. Trot suggests targets but the user has final control.

## Engagement loops

### 1. Daily target with consistency-weighted scoring

The dog has a daily exercise target in minutes. Trot tracks percentage-of-needs-met, not just total minutes.

Going over target does not score higher than hitting it. 100% is the ceiling. This protects against over-walking puppies, seniors, and breeds that can be harmed by excessive exercise. The scoring treats "70 minutes daily for 7 days" as healthier than "490 minutes once a week" — consistency beats volume.

### 2. Streaks tied to the dog

"Luna's 14-day streak" — not the human's streak. Breaking it feels like letting the dog down.

**Mechanics, locked:**
- Each dog has its own streak, calculated independently. A walk credits all active dogs by default; if Dog B was unticked, Dog B gets a miss for that day.
- Day boundary is **local time** wherever the user currently is. Walks are credited to the day they started.
- A day counts as "walked" if the dog hit **≥50% of target** that day. Below 50% is a partial day.
- Partial days **burn the rest day**, they don't break the streak. This rewards effort over token attendance.
- One free rest day in any **rolling 7-day window** is allowed without breaking the streak. Rolling (not Mon-Sun fixed) is harder to game and feels fairer.
- Two missed days in a 7-day window break the streak.

For multi-dog households, this means three dogs can have three different streak counts visible. Home defaults to the most-recently-active dog; users switch via a top selector or horizontal swipe.

### Deceased-dog handling (v1 hard rule)

Designing a proper "memorialise" flow is deferred to v1.1. To prevent the worst-case scenario in v1 (a "Luna's quiet today" nudge fired weeks after a loss), v1 enforces a hard rule: **no notifications fire for any dog with zero walks in the last 14 days**. Streak silently freezes, no nudges, no "streak at risk" prompts. The user can manually archive the dog from profile settings.

### 3. Personalised insights

The longer the user has Trot, the better the insights:
- "Luna walks 22% more on weekends — she might benefit from longer weekday walks."
- "Tuesday is Luna's lowest-activity day this month."
- "Luna has been most active when you walk her before 8am."

Insights surface in the app, not via push notifications.

### 4. Dog-centric milestones

- Lifetime minutes walked
- Lifetime distance, sourced from HealthKit's `distanceWalkingRunning` (Apple's pedometer-derived distance — no GPS, no location tracking). Displayed as estimated, e.g. "≈42km."
- Walks completed
- Consecutive weeks at 80%+ of target
- "Luna has walked approximately the equivalent of London to Brighton" — milestones that translate stats into something emotionally legible. Marketing language allows for "approximately" because the estimate is rough by nature.

### 5. Identity reinforcement

Trot's language reinforces the user as a responsible owner doing right by their dog. Not "you're crushing it" — more "Luna is getting the exercise she needs."

### 6. Weekly recap as a fixed ritual

Sunday evening, Trot shows the dog's week:
- Total minutes walked
- Percentage of needs met across the week
- Comparison to last week
- Streak status
- One personalised insight
- A featured photo of the dog

## Notifications

All notification times are local to the user's current timezone (handles DST and travel automatically via `UNCalendarNotificationTrigger`). No user configuration in v1 — defaults are locked. Add to v1.1 candidate list if requested.

1. **Walk confirmation** — fires after passive detection identifies a likely walk. Most important notification — if everything else is disabled, this alone makes the app work.
2. **Under-target nudge** — fires at **19:00 local**, only if the dog has had <50% of target progress AND there is no walk currently in progress in HealthKit AND the day isn't already covered by the rest-day allowance. Factual, dog-focused. Example: "Luna has had 15 minutes today. Her target is 60." No shame, no exclamation marks. **Suppressed on Sundays** (the weekly recap takes precedence; double-buzz feels demanding).
3. **Streak milestone** — at 7, 14, 30 days. Fires at **09:00 local the morning after** the qualifying day completes, never at midnight.
4. **Weekly recap ready** — fires **Sunday 19:00 local**.
5. **Streak at risk** — deferred to v1.1 (see decisions log).

All notifications individually toggleable. The 14-day no-walks deceased-dog safeguard suppresses all per-dog notifications regardless of toggles.

## Key screens

**Home (the dog's screen).** Photo of the dog. Today's progress against target. Current streak. Quick access to log a manual walk.

**Activity.** History of walks. Calendar view showing daily target hit / partially hit / missed. Weekly and monthly aggregates.

**Insights.** Personalised observations, refreshed weekly.

**Dog profile.** Editable profile, exercise target, walk windows.

**Account.** Multiple dogs, settings, notifications, permissions.

## Tech summary

- **App:** Swift 6 with strict concurrency, SwiftUI, SwiftData + CloudKit, HealthKit + Core Motion, iOS 18.0+, light mode only
- **Auth:** Sign in with Apple. iCloud required.
- **Backend:** Single Vercel Edge Function as LLM proxy (called at onboarding and on profile changes only). Anthropic Haiku 4.5 model. 8s timeout. Hash-cached responses. Anonymous install tokens for rate limiting.
- **Observability:** MetricKit + Sentry. No product analytics in v1.
- **Tests:** Swift Testing framework
- **Landing page:** static HTML/CSS, deployed to Vercel alongside the backend
- **iOS CI:** Xcode Cloud (free tier, 25hr/month) on push to main

Distance estimates use HealthKit's pedometer-derived `distanceWalkingRunning` (no GPS, no location tracking), displayed as estimated.

## App Store metadata

- **App Name:** `Trot: Daily Dog Walks` (21 chars)
- **Subtitle:** `Build a daily walking habit` (27 chars)
- **Keyword field strategy:** dog walking, pet exercise, walking tracker, dog fitness, healthy dog, daily walk, beagle walk, puppy exercise, dog routine, breed exercise, dog wellness, walk reminder

Update these as the brand evolves and during ASO refinement.

## Launch market

UK only. High dog ownership, strong walking culture, single language, manageable size for refining the product before geographic expansion.

## Out of scope for v1

- Photo features and AI photo judging
- Couples and shared accounts
- Leaderboards (local, breed-based, or otherwise)
- Social features generally
- Location tracking and route mapping
- Couple coordination
- Vet, trainer, and welfare partnerships
- Health and behaviour tracking beyond exercise
- iPad, Apple Watch, Android
- Streak-at-risk notifications (deferred to v1.1)

## Success criteria for v1

There is no product analytics in v1, so success is measured qualitatively:

- Corey uses Trot daily for 3 months and the app feels good
- 5+ friends and family use it daily for 3 months without prompting
- App Store reviews mention the streak and the passive walk detection specifically as things that work
- Nobody asks "why doesn't it just …" about the core loop — confirmation, streak, target

If those signals are positive, build v1.1 with proper analytics (PostHog or similar) and chase the real numbers — the original quantitative criteria (>70% confirmation rate, 14+ day streaks at meaningful rates, month-3 and month-6 retention) become observable then.

If the qualitative signals are negative, no amount of analytics will save it.

---

## Future feature concepts

These are exploratory and will be improved, amended, or removed based on what is learned from v1. Nothing here is committed.

**Photo game.** Couples or individuals submit walk photos, an AI judge scores them with personality, weekly winners get featured.

**Couple accounts.** Shared dog, coordination of whose turn it is to walk. Shared streaks.

**Local leaderboards.** Hyper-local, breed-specific cohorts. Scored on percentage-of-needs-met, capped at 100%.

**Friend voting on photos.** Anonymous judging, async, weekly winners.

**Vet and welfare partnerships.** The "needs-met, capped at 100%" scoring is well-suited to clinical endorsement.

**Year-end recap.** Spotify Wrapped equivalent for the dog's year.

**Adoption-anniversary milestones, training records, vet reminders.** Expanding from walks to a fuller dog-life companion.

**Apple Watch and wearable integration.** Detect walks via watch directly, log without phone present.

**Location features.** Optional, opt-in route mapping. Discovery of new walking spots. Sniff-time tracking.

**Android.** Once iOS validates the core habit and unit economics work.

These features assume v1 succeeds in its core aim. If users do not form the daily walking habit through the v1 loops, none of these additions will save the product.
