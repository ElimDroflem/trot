# Decisions log

This file is the project's memory across sessions. When Claude resolves an open question or makes a new architectural decision, add it here with date and rationale.

---

## Resolved

### Name — May 2026
**Decision:** Trot.

**Rationale:** Single syllable, distinctly canine (it's a dog gait), memorable, easy to say in any accent. Not crowded in the App Store dog-walking habit-tracker namespace. Plays well with the brand voice — warm, slightly playful, confident. Logo opportunities are open (no obvious cliche to fall back on).

App Store title structure: `Trot: Daily Dog Walks`. Subtitle: `Build a daily walking habit`.

### Tech stack — May 2026
**Decision:** Native Swift 6 / SwiftUI / SwiftData + CloudKit / HealthKit, with a Vercel Edge Function proxy for LLM calls.

**Rationale:** The app's core feature is background walk detection. Native HealthKit `HKObserverQuery` + `enableBackgroundDelivery` is the only reliable path for this — the most popular React Native HealthKit library explicitly doesn't support background processing. Apple's Xcode 26.3 has full Claude Agent SDK integration with visual verification of SwiftUI work, and Paul Hudson's agent skills (SwiftUI Pro, SwiftData Pro, Swift Concurrency Pro, Swift Testing Pro) close most of Claude's known Swift weak spots.

### Cloud sync
**Decision:** SwiftData with CloudKit sync.

**Rationale:** Free, Apple-native, removes the need for a database backend. Losing a 60-day streak when a user gets a new phone would be product-killing.

**Known traps to avoid:**
- Schema must be deployed in the CloudKit Console (Development → Production) before each App Store release. Silent sync failure otherwise.
- Use `initializeCloudKitSchema` in DEBUG only after model changes to ensure relationships sync correctly.
- iOS 26 introduced some sync issues for existing apps; new apps starting on iOS 26 SDK should be tested specifically for sync behaviour.

### Crash reporting
**Decision:** MetricKit (built-in, free) plus Sentry layered on top.

**Rationale:** MetricKit is free, native, privacy-preserving and gives crash/hang/jetsam reports automatically. Sentry adds real-time alerts and richer context. Combined cost: zero in v1.

### Backend for LLM call
**Decision:** Single Vercel Edge Function as proxy. Same Vercel project serves the landing page.

**Rationale:** API keys can't ship in an iOS app — they can be extracted from the IPA. The proxy holds the key and forwards requests. Vercel free tier covers v1 scale. One deployment for both landing page and backend keeps things simple.

### Onboarding walk windows UX
**Decision:** Four named slots — Early morning (5-9), Lunchtime (11-2), Afternoon (2-6), Evening (6-10). Multi-select.

**Rationale:** Simplest, fastest to set up. The app refines based on actual usage data over time anyway.

### Multi-dog walks default
**Decision:** Default-on per dog. Every walk credits all of the user's active dogs by default. User unticks any dog that wasn't on the walk.

**Rationale:** Matches reality. If you have two dogs, they almost always go together. Saves taps. Edge cases (one dog at the vet) are easy to handle by unticking.

### Streak rest day allowance
**Decision:** One free rest day per week without breaking the streak.

**Rationale:** Pure streaks punish too hard and people quit when broken. Forgiveness keeps the lever strong without making it brittle.

### Concurrency model
**Decision:** Swift 6 strict concurrency from day one.

**Rationale:** Industry consensus in 2026 is to start new apps in Swift 6 strict concurrency mode rather than migrating later. The migration cost is paid back quickly through reduced data-race crashes. Concurrency is exactly where Claude struggles most with Swift, so the Swift Concurrency Pro skill is installed to plug that gap.

### Testing framework
**Decision:** Swift Testing (`@Test`, `#expect`) — not XCTest.

**Rationale:** Swift Testing is the modern Apple-recommended framework. Better ergonomics, parameterised tests, async-first.

### Repository structure
**Decision:** Monorepo. iOS, web (landing + backend), docs, and design reference all in one repo.

**Rationale:** Solo developer building in the open. One place to manage, one URL to share on X and CV, easier to keep brand and code in sync. Vercel handles deployment from a subfolder cleanly.

### Landing page
**Decision:** Built using Claude Design output (HTML/CSS) directly — not as Claude Design reference. Same Vercel deployment as the backend.

**Rationale:** Unlike the iOS app where Claude Design output is reference only, for HTML the output IS the deliverable. Faster to ship, brand-consistent automatically, and lets the landing page go live before the iOS app is ready.

---

## Resolved — May 2026 grill session

The following decisions came out of a structured pressure-test of the project plan against the actual exported design system. All locked unless noted.

### Design system structure
**Decision:** `design-reference/Trot Design System/` is the canonical, single source of truth. Promoted from "one option among many" to authoritative. No parallel `design-reference/{logo,ios,landing}/` subfolders.

**Rationale:** Two folders to keep in sync is two folders that go stale. The exported design system is structurally rich enough (tokens, fonts, assets, ui_kits, snapshots) to serve every visual reference need. The original docs assumed PNG mockups — that assumption is now obsolete.

### Design tokens flow
**Decision:** `design-reference/Trot Design System/colors_and_type.css` is authoritative. Swift extensions in `ios/Trot/Core/DesignSystem/` mirror it 1:1. CSS leads, Swift follows.

**Rationale:** Token expansion happens in the design system (web tooling iterates faster than Swift). Mirroring keeps both surfaces aligned. The opposite flow (Swift first) would create a CSS-versus-Swift drift problem.

### Home screen variant
**Decision:** Outdoorsy + Grounded. Other two variants (Warm + Joyful, Modern + Confident) deleted from `home-variants.jsx`. No runtime toggle.

**Rationale:** The brief calls for warm-but-credible and confident-not-chirpy. Outdoorsy + Grounded fits the "morning walks" emotional tone best without trying too hard. Locked here because deferring meant Claude Code would have nothing to match.

### Logo direction
**Decision:** The lowercase `o` with a coral spot inside its counter — the dot is the brand. Bricolage Grotesque 700, `letter-spacing: -0.045em`. Tighter `o` treatment for the app icon (so the spot stays inside Apple's icon mask safe area).

**Rationale:** Specific enough to mean something, distinctive enough to be a real mark, satisfies the brand brief's "no paw prints, no silhouettes." The dot makes it Trot, not generic display type.

### Auth model
**Decision:** Sign in with Apple + iCloud required. No `User` SwiftData model — iCloud account is the user identity.

**Rationale:** CloudKit was chosen for the sync story; accommodating non-iCloud users defeats it. Sign in with Apple is the App Store-friendly auth primitive. The onboarding wall framing presents iCloud as a user benefit, not a Trot limitation.

### LLM model and failure UX
**Decision:** Anthropic Haiku 4.5. 8-second hard timeout. On failure, fall back to the breed-table value silently and retry on next app open. Cache responses (target + rationale) by hash of the dog profile; invalidate only on profile change.

**Rationale:** Haiku is ~10x cheaper than Sonnet for short-input narrow-output tasks like this and is fast enough to fit comfortably under an 8s timeout. Onboarding never blocks on a network call — the breed table is the floor.

### Streak mechanics
**Decision:** Rolling 7-day window, day boundary in local time, ≥50% of target counts as walked, partial days burn the rest day, two misses in a 7-day window break the streak. Each dog has its own streak.

**Rationale:** Rolling is harder to game and feels fairer than fixed Mon-Sun. ≥50% rewards effort over token attendance. Partial-burns prevent the "trying-and-being-punished" UX. Per-dog streaks are necessary for multi-dog households.

### Notification timing
**Decision:** Weekly recap fires Sunday 19:00 local. Under-target nudge fires 19:00 local with conditions (target progress <50%, no walk in progress, rest-day not used today, NOT Sundays). Streak milestones fire 09:00 local the morning after the qualifying day. No user configuration in v1.

**Rationale:** Real times are required for `UNCalendarNotificationTrigger`. Sunday suppression of the nudge prevents double-buzz when the recap also fires. 09:00 milestones avoid midnight buzzing. v1 ships locked defaults; v1.1 considers configuration if users ask.

### Distance estimation source
**Decision:** HealthKit `distanceWalkingRunning` (pedometer-derived, no GPS). Displayed as estimated, e.g. "≈42km."

**Rationale:** The original `duration × breed-typical pace` formula was off by a factor of 3 in either direction. Apple's pedometer is materially more accurate while still using zero location data, preserving the "no location tracking" architecture promise.

### iOS deployment target
**Decision:** iOS 18.0.

**Rationale:** SwiftData v1 (iOS 17.0–17.3) had material CloudKit sync bugs. iOS 17.5 is a halfway position that still leaves `#available` scaffolding. iOS 18 skips the entire SwiftData v1 generation. Real-world iOS 18 adoption was ~85% by April 2026 — the reach cost is small.

### Photo storage
**Decision:** SwiftData `@Attribute(.externalStorage)` for the photo property. Downscale on save: 1024px long edge, 80% JPEG, ~150-300KB target.

**Rationale:** Inline `Data` photos × multi-dog × CloudKit replication eats the user's free 5GB iCloud quota fast. External storage uses CKAsset under the hood and doesn't count against the 1MB record limit. Adding `.externalStorage` later is a migration — easier on day one.

### Force light mode for v1
**Decision:** `UIUserInterfaceStyle = Light` in Info.plist. No dark mode in v1. Asset catalog has light-only color values. Dark hex values stripped from brand.md.

**Rationale:** The warm cream surface is the visual identity. Letting iOS swap it for charcoal at night defeats the brand. Dark mode is a v1.x or later exploration with a proper dark-mode design pass.

### Deceased-dog handling (v1 only)
**Decision (v1):** Hard rule — no notifications fire for any dog with zero walks in the last 14 days. Streak silently freezes. User can manually archive from profile settings.

**Rationale:** A proper memorialise flow needs careful UX and copy and isn't worth designing for v1. The 14-day safeguard prevents the worst case (a "Luna's quiet today" nudge weeks after a loss) without requiring the full design pass now. Full memorialise UX is in the Open list below for v1.1.

### Pre-Trot lifetime stats backfill
**Decision:** Accept zero. Lifetime stats start at zero on day one. Onboarding frames it as "Trot starts counting today."

**Rationale:** Asking "how long have you had Luna?" and prorating fictional baseline minutes undermines the "doing right by your dog" tone. Clean zero is honest and less to build.

### Multi-dog Home navigation
**Decision:** Home defaults to the most-recently-active dog. User switches via top selector or horizontal swipe. Each dog has its own streak count visible.

**Rationale:** Single-dog focus is the primary case. Multi-dog households need cheap context switching, not a multi-dog dashboard.

### Missing-screen design strategy
**Decision:** Build screens not in the design system (Insights, Dog profile, Account, Walk windows picker, LLM result, Weekly recap, Streak milestone, empty states, manual log sheet, onboarding step 1, permissions screens, settings) directly in Claude Code, iterating from running builds. Round-trip back to Claude Design only if something feels visually off.

**Rationale:** The design system locks tokens, voice, layout rules, and four canonical references (Home, Activity, Walk Confirmation, Onboarding Dog). Pre-emptively designing 12+ screens that may change after the first iOS build wastes effort. Naming this as an explicit choice prevents kidding ourselves about coverage.

### Domain
**Decision (v1 build-in-the-open phase):** Use the free vercel.app subdomain. A real domain (`trot.dog` target, `trotapp.com` fallback) is registered closer to App Store submission.

**Rationale:** Building in the open doesn't need a custom domain on day one. The vercel.app URL is sharable and free. Locking in a domain before there's something for users to actually do at the URL is premature.

### Email service
**Decision:** Resend. Audiences for the contact list, Send for the launch-day broadcast. Existing account, no new vendor.

**Rationale:** MailerLite was the original recommendation for someone setting up from scratch, but Resend handles both audience capture and transactional/broadcast email in one service. Single dashboard, single API key. Form posts to a Vercel Edge Function (`web/api/subscribe.ts`) which calls Resend's contacts API.

### X handle
**Decision:** Personal handle (`@coreyrichardsn`) for v1, not a project handle.

**Rationale:** Build-in-the-open is a personal journey. Easier to point at the maker than to maintain a separate project account during pre-launch.

### Repository
**Decision:** GitHub, public.

**Rationale:** Build-in-the-open extends to the code. One repo, visible.

### iOS CI
**Decision:** Xcode Cloud, free tier (25 hours/month). Auto-builds on push to main, runs Swift Testing suite. TestFlight upload manual until pipeline is trusted.

**Rationale:** 25 hours/month is plenty for solo work. Free is correct for v1.

### Trot Design skill installation
**Decision:** Installed project-scoped at `.claude/skills/trot-design/` (symlink or copy from `design-reference/Trot Design System/`). Loads on `claude` invocation in this project.

**Rationale:** Skill travels with the repo. Anyone who clones gets it on first invocation. Hudson skills (swiftui-pro etc.) remain global because they're language tooling, not project-specific.

### Token flow rule
**Decision:** New design tokens are added to `colors_and_type.css` first, then mirrored to the Swift design system.

**Rationale:** CSS leads because the design system tooling iterates there. Reverse flow would cause drift.

### Design-system AI-generated images
**Decision:** The dog photos in `design-reference/Trot Design System/assets/` (`dog-luna.jpg`, `dog-walk-1.jpg`, `dog-walk-2.jpg`) are AI-generated reference images. They do NOT ship with the iOS app. The iOS asset catalog must never reference them.

**Rationale:** AI-generated images may carry training-data copyright risk. Reference-only use is fine. Default profile placeholder for the iOS app will be a generated illustration, commissioned or generated fresh, when needed.

### App Review constraints (HealthKit)
**Acknowledgement, not a decision:** First-time submitter + HealthKit + LLM proxy means stricter App Review scrutiny. Implications baked into the plan:
- Purpose strings (`NSHealthShareUsageDescription`, `NSHealthUpdateUsageDescription`) drafted carefully in plan-mode when Info.plist is set up, not as an afterthought
- Background-delivery justification text written ahead of submission, not the night before
- App Privacy questionnaire prep added to the pre-submission checklist
- 5–7 business-day budget for first review, not 24–48 hours
- TestFlight cycles planned around this, not around build cadence

### Privacy / GDPR posture
**Decision:** Treat the dog profile as personal data. Anthropic listed as a sub-processor in privacy.html. Proxy logs purged after 30 days, dog profile contents never logged. Right-to-erasure is satisfied by the user deleting their iCloud data + the proxy purging logs. Anonymous install tokens for rate limiting (not per-IP).

**Rationale:** Safer to treat as PII than not. Aligns with UK GDPR. Anonymous install tokens are a better identifier than IP for iOS NAT scenarios and reduce tracking concerns.

### No product analytics in v1
**Decision:** No PostHog/Mixpanel/Amplitude SDK in v1. Success criteria rewritten qualitatively in spec.md.

**Rationale:** Adds GDPR consent UX, sub-processor, drag. v1 is small enough to evaluate qualitatively. v1.1 adds proper analytics if v1 signals are positive.

### Apple Developer Program timing
**Decision:** Pay the $99 only when starting HealthKit service work (not day one).

**Rationale:** HealthKit doesn't work in the Simulator. Until HealthKit work begins, on-device testing isn't required and the developer account isn't needed. Concrete signal for when to spend the money.

### Breed-table verification scope
**Decision:** All 30 entries in `docs/breed-table.md` are flagged `needs verification` with TODO source URLs. Verification is a single pre-launch pass, not a per-entry research session now. Onboarding can be built against the unverified table and the numbers replaced before TestFlight.

**Rationale:** The numbers in the draft are conservative and PDSA-aligned (puppy 5-min-per-month rule, KC tier categories for adults, fallback table for seniors, brachycephalic/sighthound/working-breed cautions baked in). Verifying 10 of 30 in-session would produce a mixed state still requiring the same pre-launch pass. Cleaner to keep the file uniformly "needs verification" and do the audit once, properly. The verification job is a couple of hours with a checklist, not a multi-day research project.

**Scope discipline:** v1 is about walks. The breed table covers exercise needs only — no nutrition, training, grooming, or general care data. Future features that need more guideline material add source coverage when those features ship, not in anticipation.

---

## Open

### Walk detection algorithm
**Question:** What is the precise state machine and signal-fusion logic that turns Core Motion + HealthKit data into reliable walk-detected events?

**Status:** Deferred to a dedicated plan-mode session before HealthKitService is built. This is the engine of the app and deserves more than a paragraph in spec.md.

**Constraints already locked (do not lose in plan-mode):**
- Core Motion (`CMMotionActivityManager`) as primary signal source for walking-state transitions
- HealthKit `distanceWalkingRunning` as the distance signal
- ≤3 minutes stationary tolerated inside a session (sniff breaks)
- ≤30 seconds running tolerated inside a session (dog pulls)
- Source filtering for non-walking Apple Watch workouts
- Watch-logged walking workouts use a separate, more reliable path
- Background handler completes in ~15s
- DEBUG-only walk simulation as first-class part of HealthKitService
- Within-window false positives for labour-intensive jobs are a known accepted limitation

### Streak-at-risk notification
**Question:** How to schedule a "streak at risk" notification that fires only when actually relevant, given the app might not be running?

**Status:** Deferred to v1.1.

**Rationale:** This is the trickiest notification to build correctly and the easiest to get wrong. Ship the other four notifications first, validate they work in production, learn from real usage, then add it. Doing it badly (false alarms, fired at the wrong time) would be worse than not having it.

### Deceased-dog memorialise flow (v1.1)
**Question:** What does the full archive/memorialise UX look like? Sensitive copy, history preservation, post-loss user journey, removal from streak/notification eligibility, possibly a year-end retrospective for the dog's life.

**Status:** Deferred to v1.1. v1 covers the worst case via the 14-day safeguard (see Resolved above).

### Anthropic API key rotation
**Question:** What's the rotation strategy for the Anthropic API key in Vercel env? Recovery process if leaked?

**Status:** Operational concern, not a v1 blocker. Address before launch as part of the production-readiness checklist.

### Anti-tracking robustness for the rate-limit token
**Question:** Is the anonymous install token alone enough to prevent abuse, or is a separate proof-of-work / signed-request scheme needed?

**Status:** Acceptable for v1 at expected scale. Revisit if abuse appears.

---

## How to use this file

When Claude resolves an open question or makes a new architectural decision in a session, add it under **Resolved** with date and rationale. When a new architectural question arises that needs deferring, add it under **Open** with a clear question and reason for deferral.
