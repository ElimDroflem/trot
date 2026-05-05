# Architecture

This is the technical architecture for Trot. Read this before planning any feature.

## High-level

Trot is a monorepo containing three things:
- **iOS app** — Swift 6 / SwiftUI / SwiftData + CloudKit / HealthKit
- **Web** — static landing page + Vercel Edge Function for the LLM proxy
- **Design reference** — mockups and assets exported from Claude Design

All three are deployed and developed independently but share the brand defined in `docs/brand.md`.

## Repository layout

```
trot/
├── CLAUDE.md
├── README.md
├── setup-guide.md
├── .gitignore
├── .claude/
│   └── skills/
│       └── trot-design/             # Project-scoped skill, loads on `claude` invocation
├── docs/
│   ├── spec.md
│   ├── architecture.md
│   ├── brand.md
│   ├── landing.md
│   ├── decisions.md
│   └── breed-table.md               # Breed-and-age safe-range data (drafted before onboarding code)
├── design-reference/
│   └── Trot Design System/          # Canonical design system from Claude Design
│       ├── README.md                # Long-form design guidance
│       ├── SKILL.md                 # Skill manifest (symlinked into .claude/skills/)
│       ├── colors_and_type.css      # SOURCE OF TRUTH for design tokens
│       ├── fonts/                   # Bricolage Grotesque (.woff2 for web, .ttf for iOS)
│       ├── assets/                  # Logo SVGs, AI-generated reference photos (do not ship)
│       ├── preview/                 # Token-explorer HTML cards
│       ├── snapshots/               # PNG captures of canonical screens for visual diff
│       └── ui_kits/
│           ├── ios-app/             # React-based interactive component reference (iOS)
│           └── landing/             # The trot.dog landing page source (drops into web/)
├── ios/                                 # iOS project root
│   └── Trot/                            # Xcode workspace folder (created by `Create New Project`)
│       ├── Trot.xcodeproj
│       ├── Trot/                        # App source (synchronized group, files auto-discovered)
│       │   ├── App/                     # App entry point (TrotApp.swift)
│       │   ├── Features/                # One folder per feature
│       │   │   ├── Onboarding/
│       │   │   ├── Home/
│       │   │   ├── Activity/
│       │   │   ├── Insights/
│       │   │   └── Profile/
│       │   ├── Core/
│       │   │   ├── Models/
│       │   │   ├── Services/
│       │   │   ├── Extensions/
│       │   │   └── DesignSystem/        # Swift mirrors of colors_and_type.css
│       │   ├── Resources/
│       │   │   ├── Fonts/               # Bricolage Grotesque .ttf
│       │   │   └── BreedData.json       # Loaded from docs/breed-table.md schema
│       │   ├── Assets.xcassets
│       │   ├── Info.plist
│       │   └── Trot.entitlements
│       ├── TrotTests/
│       └── TrotUITests/
└── web/                             # Single Vercel deployment for landing + backend
    ├── index.html                   # Landing page (sourced from ui_kits/landing/)
    ├── privacy.html
    ├── terms.html
    ├── styles.css
    ├── assets/
    ├── api/
    │   └── exercise-plan.ts         # Vercel Edge Function (LLM proxy)
    ├── package.json
    └── vercel.json
```

Each Feature folder in iOS contains its views, view models, and any feature-specific logic. Cross-feature work lives in Core.

## Auth and identity

Sign in with Apple is the auth primitive. iCloud is required — Trot's sync story depends on CloudKit private DB. If the user isn't signed into iCloud, onboarding directs them to Settings with framing that positions iCloud as the user's benefit, not Trot's limitation: "Trot syncs Luna's data to your iCloud so you don't lose it."

There is no `User` SwiftData model. The iCloud account is the user identity. One less moving part.

## Data models (SwiftData)

Initial models. Refine in plan mode before implementing.

- `Dog`: name, photo (`@Attribute(.externalStorage)`), breed, dateOfBirth, weight, sex, neuterStatus, healthConditions, activityLevel, dailyTargetMinutes, llmRationale (cached), archivedAt (nullable, for archive/memorialise)
- `Walk`: id, dogIDs (one walk → multiple dogs), startedAt (UTC), durationMinutes, distanceMeters (estimated, from HealthKit), source (passive/manual), notes
- `WalkWindow`: dogID, slot (earlyMorning/lunch/afternoon/evening), enabled

All timestamps stored in UTC. Convert to local time on display only. The streak calculation operates in the user's current local time for day-boundary purposes.

CloudKit sync enabled at container level. Photos use external storage so they don't count against the 1MB record limit and are more efficient over the wire.

## Key services (iOS)

Each service is a single point of contact for that external system. Views and view models depend on protocols, services implement them. This makes mocking for tests trivial.

- **HealthKitService:** permission, observer query setup, Core Motion activity manager, walk detection state machine. Includes a DEBUG-only walk simulation affordance (synthetic `HKQuantitySample` injection + compressed-time state machine triggering) — first-class part of the service, not a hack. Without it every iteration is a 15-minute physical walk.
- **PersistenceService:** SwiftData container, CRUD wrappers, CloudKit configuration. Photos use `@Attribute(.externalStorage)` and are downscaled on save (1024px long edge, 80% JPEG, ~150-300KB target).
- **AuthService:** Sign in with Apple flow, iCloud-availability check, redirect-to-Settings prompt when iCloud is missing.
- **NotificationService:** permission, scheduling via `UNCalendarNotificationTrigger` (locale-aware), handling of confirmation taps. Enforces the 14-day no-walks safeguard for any dog (no notifications fire if a dog has zero walks in 14 days, regardless of toggles).
- **LLMService:** calls the Vercel proxy at `/api/exercise-plan`, returns personalised exercise plan. 8s timeout. On failure, falls back to the breed-table value silently and retries on next app open. Caches responses (target + rationale) by hash of the dog profile; only invalidates on profile change.
- **ExerciseTargetService:** combines `docs/breed-table.md` data + LLM output to produce daily targets within safe ranges. The LLM never invents the numbers — it picks within ranges the table defines.
- **StreakService:** streak calculation per dog, rolling-7-day rest-day logic, milestone detection at 7/14/30 days. Day boundary is local time. ≥50% of target counts as walked; below burns the rest day; two misses in a 7-day window break the streak.
- **InsightsService:** personalised observations from walk history.

## The walk detection flow

**This algorithm is open and deferred to a dedicated plan-mode session at the END of the v1 build, not the start.** See decisions.md → "Build sequence: passive walk detection ships last" and → "Walk detection algorithm." Until that session, manual walk logging is the primary path and `HealthKitService` is not built. The original algorithm sketched here was technically wrong and has been removed pending a proper design.

What's locked:

- **Wake mechanism:** `HKObserverQuery` + `enableBackgroundDelivery(for:frequency:)` with `.immediate`. Requires the `com.apple.developer.healthkit.background-delivery` entitlement. Background handler must complete within ~15 seconds.
- **Primary signal:** Core Motion (`CMMotionActivityManager`) for walking-state transitions.
- **Distance signal:** HealthKit `distanceWalkingRunning` (pedometer-derived, no GPS).
- **Tolerances** (see spec.md): ≤3-min stationary inside a session, ≤30s running inside a session.
- **Source filtering:** Apple Watch workouts of types other than walking should not fire detection.
- **DEBUG simulation:** see HealthKitService above.

**Known iOS constraints to plan around:**
- Background handler must complete within ~15 seconds or iOS terminates the app.
- iOS throttles background updates. Frequency of `.immediate` is a hint, not a guarantee.
- The app must not crash in background or iOS will reduce future wake frequency.
- Background app refresh must be enabled in Settings (handled at onboarding).
- HealthKit does not work in the iOS Simulator. Real-device testing is required from the moment HealthKitService development starts. Per the revised sequencing, this is at the **end** of the build — and it's the trigger for paying the Apple Developer Program ($99) at that point, not day one and not at first HealthKit work.

## Notifications

Five types in v1:
1. Walk confirmation (after passive detection)
2. Daily under-target nudge (mid-evening, only if needed)
3. Streak milestone (7, 14, 30 days)
4. Weekly recap (Sunday evening)
5. Streak-at-risk: deferred to v1.1 (see decisions log)

All use `UNUserNotificationCenter` local scheduling. No remote push for v1.

## Backend (Vercel)

A single Vercel project serves both the landing page (static files) and the LLM proxy (Edge Function). One deployment, one domain.

**LLM proxy (`web/api/exercise-plan.ts`):**

Accepts: dog profile (name, breed, age, weight, sex, neuter status, health conditions, activity level) + an anonymous install token.

Forwards to Anthropic API (Haiku 4.5 — short input, narrow constraints, ~10x cheaper than Sonnet) with a constrained prompt. The prompt references the breed-and-age safe-range table from `docs/breed-table.md` and instructs the LLM to personalise within those ranges only. Output is structured (target min/max, rationale string).

Returns: target range in minutes plus a short rationale string.

**Operational rules:**
- API key lives in Vercel environment variables, never in the iOS app.
- 8-second hard timeout. Anthropic Haiku is fast but degraded states happen.
- Rate limiting via **anonymous install tokens** (minted at first launch on the iOS client, stored in Keychain, sent with every request). Per-IP is too coarse for iOS NAT scenarios and starts to look like tracking.
- Logs retained 30 days. Never log dog profile contents — only request count, status code, error trace.
- Anthropic listed as a sub-processor in the privacy policy.

**Landing page:**

Static HTML/CSS at the root, sourced from `design-reference/Trot Design System/ui_kits/landing/`. Served directly by Vercel. See `docs/landing.md` for the brief.

## iOS CI

**Xcode Cloud, free tier (25 hours/month).** Auto-builds on push to main, runs Swift Testing suite. TestFlight upload remains manual until the pipeline is trusted.

The free tier is plenty for solo work. Defer paid tiers until v1 ships and there's a real reason.

## Design reference workflow

The canonical design system lives at `design-reference/Trot Design System/`. **One folder, one source of truth.** No parallel "logo / ios / landing" subfolders elsewhere.

**Token flow is CSS-first.** `colors_and_type.css` is authoritative. When a new token is needed:
1. Add it to `colors_and_type.css`
2. Mirror it to the Swift extensions in `ios/Trot/Core/DesignSystem/`
3. Reference the token by name in views

Never the other way round. The web and iOS surfaces share one mental model.

**Visual references for screens:**
- `snapshots/` — canonical PNG captures of locked screens, used by Claude Code for visual diff against SwiftUI Previews. Currently: Home (Outdoorsy + Grounded variant). More added as screens are designed.
- `ui_kits/ios-app/` — interactive React component kit. Useful as a "what does a TrotCard look like with these props" reference. Run via `python3 -m http.server` from inside the folder.
- `ui_kits/landing/` — the landing page source. Drops directly into `web/`.

**When asking Claude Code to build a screen:**
> "Build the Home screen. Match `design-reference/Trot Design System/snapshots/home.png`. Use tokens from `colors_and_type.css` mirrored to the Swift design system."

**For screens without a snapshot** (Insights, Dog profile, Account, Walk windows picker, LLM result screen, Weekly recap, Streak milestone, empty states): build from tokens, voice rules, and component principles, then iterate from running builds. We round-trip back to Claude Design only if something feels visually off after a working build exists. This is an explicit choice — see decisions.md.

**Trot Design as a Claude skill:** `.claude/skills/trot-design/` is symlinked or copied from `design-reference/Trot Design System/`. Loads on `claude` invocation in this project. Invoke `/trot-design` for visual work, components, brand decisions.

## Code patterns to follow (iOS)

- View models: `@Observable` class marked `@MainActor`. No `ObservableObject` or `@Published`.
- Services: actors when state is shared, structs/classes when not.
- Errors: typed throws where the error matters; generic where it doesn't.
- Views never construct their own services — services are passed in via initializer or environment.
- No singletons except where Apple's API forces it (e.g. `HKHealthStore`).

## Note on Xcode project files

The `.pbxproj` format is brittle and hard for any LLM to edit reliably. When project structure changes, prefer to use the Xcode UI for capability changes (HealthKit, iCloud, Background Modes, Push Notifications) and entitlement changes rather than asking Claude to edit the project file directly. Adding new Swift files inside the existing folder structure is fine for Claude to do.

## Skills to invoke during work

- `/swiftui-pro` when building or refactoring SwiftUI views
- `/swiftdata-pro` when defining models or working with CloudKit sync
- `/swift-concurrency-pro` when working with async/await, actors, or `@MainActor` boundaries
- `/swift-testing-pro` when writing tests
