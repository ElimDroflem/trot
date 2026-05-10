# Decisions log

This file is the project's memory across sessions. When Claude resolves an open question or makes a new architectural decision, add it here with date and rationale.

---

## Resolved

### Brand pivot: dopamine over restraint — May 2026
**Decision:** Brand.md rewritten to support a retention-first stance. The original "warm but credible / no fake urgency / no cheerleading / no exclamation marks" posture is replaced with "celebrate hard, routine soft". Walking your dog daily is a moral good, so dopamine, variable rewards, loss aversion, streaks, and animation are tools we can use without apologising. Guardrails kept: never shame the user, never weaponise the dog relationship, never fake urgency in routine flows, no dog-pun copy.

Five new principles: Get the walk · Speak for the dog · Celebrate hard, routine soft · Earn the next walk · No shame, no fake urgency.

**Rationale:** Pressure-test of the v1 design surfaced that the original brand posture was anti-engagement — exclamation marks banned in celebration, motion treated as something to ration rather than spend, "calm not demanding" applied uniformly. The retention waterfall analysis (60-second cliff → first-walk cliff → day-2/day-7/day-30/day-90) needs *every surface* contributing to pulling the user back; brand restraint actively worked against that. The rewrite preserves what protects the user (no shaming, no manipulation in routine) and ditches what was anti-dopamine (no celebration volume, motion-as-restraint).

### LLM resurrected — central to v1, not v1.1 — May 2026
**Decision:** The Vercel LLM proxy is wired into v1 across multiple surfaces, with `LLMService.swift` on iOS as the single client. Six surfaces in v1: onboarding "first card", daily Home dog-voice line (24h cache), walk-complete dog message (no cache), Insights "Luna says…" (7d cache), weekly recap narrative (7d cache), decay messaging (3+ days no walk).

Reverses the earlier "LLM deferred to v1.1" decision. Replaces the templated `DogVoiceService.currentLine` as the *primary* path; templated stays as the fallback for offline / proxy down / first paint.

**Rationale:** The brand pivot's "speak for the dog" / dog-as-translator framing makes LLM-generated dog-voice the central retention mechanic, not a v1.1 bonus. Cost is negligible (~£0.025/dog/month with Haiku 4.5; £10 budget covers ~400 active dogs). User funded a £15 spend cap on Anthropic. API key in Vercel env vars only, never in iOS bundle. Honest framing — "Luna's diary, written by Trot" — leans in rather than hides AI origin.

### Decay lever, deceased-dog rule extended to 4 weeks — May 2026
**Decision:** The 14-day no-walks safeguard from the original spec extends to 28 days. Visual decay is *active* during use:
- 2-3 days no walk → photo card subtle warmth fade
- 4-7 days → stronger fade, photo card desaturates ~30%
- 8-14 days → greyscale-leaning, "asleep" overlay, dog-voice gets quieter
- 15-28 days → quiet copy, no dog-voice, no celebration nudges
- 28+ days → archive prompt ("Has something changed for Luna?"), then silent

8pm push fires only if no walks logged that day AND dog isn't in 15+ day quiet state.

**Rationale:** Loss aversion needs a visible lever — but the lever can't risk firing during grief. 14 days was conservative; the visual decay pattern wasn't designed. Pushing the safeguard to 28 days lets us use the 0-14 day window for genuine loss aversion (warmth fading, dog quieting) without exposing a grieving user to nags. Past 14 days the volume drops to near-zero; past 28 we ask gently rather than nag.

### Journey promoted to a dedicated tab — May 2026
**Decision:** Journey moves from a card on Home to a dedicated tab in the bottom bar (third of five: Today, Activity, Journey, Insights, Dog). Visual rebuilt: dog photo as breathing centerpiece with anticipation pulse, route name in display type, anticipation panel naming the next landmark, and a STRAIGHT-line landmark timeline at the bottom of the fold (replaces the curved Catmull-Rom path). Pure SwiftUI — commissioned animations are a v1.1 layer.

**Rationale:** The journey/expedition mechanic is the headline retention loop; it deserves a dedicated tab, not a Home card. The user's feedback on the curved JourneyCard was that it looked "gross and grim" — the straight-line treatment reads better at a glance and lets the dog photo (the brand's actual visual identity) carry the hero weight. Center-of-five tab placement reinforces "this is the engagement loop", visually distinctive from Today/Activity routine surfaces.

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

### Pre-Trot lifetime stats backfill — SUPERSEDED 2026-05-10
**Original decision:** Accept zero. Lifetime stats start at zero on day one. Onboarding frames it as "Trot starts counting today."

**Original rationale:** Asking "how long have you had Luna?" and prorating fictional baseline minutes undermines the "doing right by your dog" tone. Clean zero is honest and less to build.

**Superseded by `Day-0 HealthKit history backfill` (2026-05-10).** The original decision's concern — fictional baselines from a "how long have you had the dog?" prompt — is preserved by sourcing data from HealthKit instead of the user. HealthKit walking history is real, the user's own, and not asked-about; backfilling it on day 0 turns "Trot starts counting today" (a feature) into "Bonnie has walked with you 84 hours over the past year" (a wow).

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
**Decision (revised May 2026):** Pay the $99 only at the very end of the build, when ready to verify background walk-detection wake on a real device. Not day one, not at "first HealthKit work" — the trigger is "I want to walk around the block and confirm iOS actually wakes my app in the background."

**Rationale:** Claude + Xcode + Swift is notoriously bug-prone, and v1 viability isn't yet proved. The $99 acts as a risk gate: build everything that can be built on a free Personal Team first (entire UI, design system, SwiftData local-only persistence, foreground HealthKit, LLM proxy, manual logging, streak engine, breed scoring, insights, every screen) and only spend the money when nothing else stands between the build and the final 10% of validation. If at the trigger point the project doesn't feel viable, £0 has been spent on Apple. If it does feel viable, £79 buys the final reliability check before TestFlight.

**What works on free Personal Team:** every UI flow; SwiftData (local only); HealthKit + Core Motion **in foreground**; local notifications when the app is open or recently active; LLM proxy; running on your own iPhone (re-signs every 7 days).

**What needs paid (small, well-defined swaps near the end):** Sign in with Apple capability, HealthKit background-delivery entitlement, CloudKit sync, TestFlight distribution.

**Replaces:** earlier rule that paid the $99 at "first HealthKit service work." That rule is obsolete given the new build sequence (see next entry).

### Build sequence: passive walk detection ships last
**Decision (May 2026):** Passive walk detection — HealthKitService, the state machine, the dedicated plan-mode session for the algorithm, and the paid Apple Developer Program — all move to the **end** of the v1 build, not the start.

**Rationale:** Strava and most fitness apps still default to manual start; manual logging is already a first-class flow in v1 (spec.md "Manual logging — Always available"). Sequencing passive detection last means everything else (data layer, every screen, streak engine, LLM personalisation, manual logging, weekly recap, insights) can be built and validated against a free Personal Team. Passive detection is the headline feature but not a blocker for proving the daily-loop product works.

**Caveat (do not lose):** the "wet Tuesday in February" qualitative test under manual-only logging is a *related but not identical* experience to v1 with passive detection on. Friction of manual logging is part of what passive detection eliminates. Pre-launch validation with friends and family will be provisional until passive detection is on. Don't read "I love it manually" as a guarantee that "I love it automatically" — they're related, not equivalent.

**Implication:** manual walk logging is the primary v1-development path. Walk detection algorithm work (currently still flagged Open) stays Open and gets planned at the end of the build, not before.

### Breed-table verification scope
**Decision:** All 30 entries in `docs/breed-table.md` are flagged `needs verification` with TODO source URLs. Verification is a single pre-launch pass, not a per-entry research session now. Onboarding can be built against the unverified table and the numbers replaced before TestFlight.

**Rationale:** The numbers in the draft are conservative and PDSA-aligned (puppy 5-min-per-month rule, KC tier categories for adults, fallback table for seniors, brachycephalic/sighthound/working-breed cautions baked in). Verifying 10 of 30 in-session would produce a mixed state still requiring the same pre-launch pass. Cleaner to keep the file uniformly "needs verification" and do the audit once, properly. The verification job is a couple of hours with a checklist, not a multi-day research project.

**Scope discipline:** v1 is about walks. The breed table covers exercise needs only — no nutrition, training, grooming, or general care data. Future features that need more guideline material add source coverage when those features ship, not in anticipation.

### Front-load delight, back-load discipline — May 2026
**Decision:** v1 is structured around the principle that habit apps which retain front-load reward and back-load discipline. Time-to-first-emotional-moment must be day 1, not day 7. A "first-week loop" of named milestone moments (first walk, first 50%, first 100%, first 100 lifetime minutes, first 3-day streak, first week) sits ahead of the long-term loops in `spec.md`. The Insights tab is populated from day 1 with a "Trot is learning Luna's patterns" progress state and a thin first observation by day 2-3. The breed-tailored rationale is an evergreen Home tile, not a one-shot at onboarding.

**Rationale:** Pressure-test of the v1 loops surfaced that everything (streaks, insights, lifetime milestones, weekly recap) only pays off in week 4+. Day 1 had nothing — log a walk, see "1 day", read a fraction. The discipline-first ordering is a known retention trap. Front-loading is not a "nice to have"; it's the difference between a user who returns on day 2 and one who doesn't.

**What this rules out:** any v1 design that pushes emotional payoff past week 1. Onboarding-only personalisation hits, "insights eventually", or "milestones once you reach them" all fail this rule.

**What this rules in:** the first-week loop in `spec.md`, the Home rationale tile, the Insights "learning" state. These are not stretch features — they are part of v1 scope.

**Rejected nearby option:** a Finch-style virtual chibi-dog companion. Strong retention mechanic in apps where the user has nothing else to project care onto — wrong fit for Trot, where the real dog is already the protagonist by spec. Also violates the brand "no kawaii / confident not chirpy" rules and would be 3-6 months of art + animation work, not a feature. Captured here so the question doesn't get re-litigated.

### First-week milestone ladder — locked — May 2026
**Decision:** The first-week ladder fires the following milestones, once per dog (not per user — adding a second dog later doesn't re-fire):

- First walk → in-app celebration
- First day at 50% of target → small home tile
- First day at 100% of target → in-app celebration
- First 100 lifetime minutes → small home tile
- First 3-day streak → in-app celebration
- First week (7 days from `dog.createdAt`) → in-app celebration, segues into first weekly recap

**Rationale:** Six beats across seven days gives roughly one moment per ~24 hours. Mix of effort-based (walks, target hits) and time-based (lifetime minutes, streak, week) so users on lighter activity still trigger something. "Per dog, not per user" matches the "dog-as-protagonist" framing and prevents multi-dog households from getting a flat experience on later additions.

**Implementation note:** these are surfaced in-app, not as push notifications. The existing 7/14/30-day streak-milestone notification (from `spec.md` notifications section) sits on top of this ladder, not in place of it. A new `MilestoneService` (or extension of `StreakService`) computes which beats have fired and which are still owed, persisted on `Dog` (probably as a `Set<MilestoneCode>` or per-flag Bools — implementation detail).

### Story tab as the post-walk progression spine — 2026-05-08
**Decision:** Story mode replaces the Journey/Route system entirely as the v1 post-walk progression. Each dog gets one AI-written book that grows by one page per walk, with two pages per local day max (page 1 unlocks at 50% of dailyTarget; page 2 at 100%). Six genres, locked per dog. Genre-themed atmosphere, page header strip, prose treatment, swipe reader. Author-channelling LLM prompt per genre.

**Rationale:** The Journey/Route system was a generic "minutes accumulating toward a named distance" loop — emotionally thin once the user realised the routes were not real walks they were doing. The story-per-dog model puts the dog in a continuous co-authored narrative the user has direct input on (path A/B + write/photo). Per-walk content + genre identity + author voice are far stronger retention levers than landmark-counting on a map. Decided after a working prototype showed the novelty wore off the route bar within two weeks of seed-data testing.

**Implementation:** `StoryService.currentState` is the state machine (noStory / awaitingFirstWalk / pageReady / caughtUp(.needMoreMinutes | .dailyCapHit) / chapterClosed). Pages persist as `StoryPage` SwiftData with a `Story` parent (one per dog), one `StoryChapter` per 5 pages. LLM via `LLMService.storyPage` (Sonnet 4.6 on the proxy) returns `{prose, choiceA, choiceB}`. Fallback to a templated prologue per genre when offline.

### Page cap: 2 per local day, milestone-gated — 2026-05-08
**Decision:** A user can generate at most two story pages in any local calendar day. Page 1 unlocks at minutes-walked-today >= 50% of dog's dailyTargetMinutes; page 2 at 100%. Beyond that, additional walks have no story-progression effect.

**Rationale:** Anti-grind. Without a cap, a 6-hour Saturday walk could generate dozens of pages, blowing the LLM budget AND emotionally cheapening the loop (one page per walk, dog-led pace). Tying page unlocks to the dog's actual exercise needs makes the story-mode reinforce rather than substitute the daily-target loop. 50%/100% are the same thresholds as the streak-day rule (≥50% of target counts as walked).

**Edge case:** a single big walk that crosses both thresholds at once unlocks both pages back-to-back — user picks page 1's path → page 2 generates → user picks page 2's path → daily cap. Decisions are visible-but-locked when below threshold (not hidden) so the user sees what's coming.

### LLM page length: 140-180 words / one iPhone screen — 2026-05-08
**Decision:** `story_page` prose target is 140-180 words, 2-3 paragraphs separated by `\n`. `max_tokens` 800. Prompt instructs the LLM to fit "exactly one iPhone screen of reading at body font."

**Rationale:** Two recalibrations to land here. Original 40-70 words was a teaser, not a page (user feedback: "this is one paragraph"). 220-280 words spilled past the iPhone screen and forced scrolling. 140-180 is the sweet spot — page card on the Story tab clamps to 4 lines for a teaser; tapping "Read more" opens a full-screen reader that fills the iPhone screen without scrolling. Six fallback prologues + chapter-close prologue use the same length spec.

### Author-channelling per genre — 2026-05-08
**Decision:** Each `StoryGenre.toneInstruction` ends with *"Channel <Author>'s voice: <one-line style note>. Don't mimic, don't pastiche — channel."* Picks: Christie (murder mystery), King (horror), Martin (fantasy), Herbert/Dune (sci-fi), Osman/Thursday Murder Club (cosy), Macfarlane (adventure).

**Rationale:** User feedback that the LLM-fallback prologues read as "structurally fantasy but vague" prompted a sharper voice anchor. Author cues give the LLM a recognisable register without forcing pastiche. The "Don't mimic" guard stops the model doing parody. Picks were user-confirmed; Macfarlane chosen over Bryson/Fermor for adventure because the modern-British-landscape register suits the "outdoor adventure across UK landscapes" brief.

### Picker calm + live atmosphere preview — 2026-05-08
**Decision:** Genre picker cards are uniform cream — same surface, same hairline border, one accent-tinted icon per card. The atmosphere layer behind the picker swaps to the highlighted genre when a card is tapped (selection lifted to `StoryView` via `@Binding`). Full genre theming (drop caps, scanlines, parchment, etc.) only blooms after Begin commits.

**Rationale:** First iteration painted every card with its full book chrome. User pushback: "looks like a complete mish-mash, way too much going on." The cards are a calm shelf, the *background* does the talking. Tap-to-preview gives the user a sense of choosing a world before committing. Reveal of the full book is the reward for picking.

### "Read more" pill + cross-chapter swipe reader — 2026-05-08
**Decision:** Story tab's page card shows a 4-line preview of the prose + a per-genre "Read more" pill. Tapping opens `StoryFullPageReader` — a `TabView .page` style swipe stack across every page in the story (not chapter-confined). Spine rows on the live tab are tappable into the same reader at that page's index.

**Rationale:** Page card on the Story tab needs to leave room for the chapter spine, decisions footer, and chapter shelf — clamped prose keeps the layout compact. The full reading experience is the iPhone-screen-sized reader. Cross-chapter swipe matches the user's mental model: "the book is one continuous thing, not a chaptered structure." Closed chapters retain their existing `StoryChapterReader` (vertical scroll all pages of one chapter) for cover-to-cover rereading.

### Walk-complete celebration enqueue-before-dismiss — 2026-05-08
**Decision:** `LogWalkSheet.save` and `ExpeditionView.finishWalk` enqueue the celebration onto `appState.pendingWalkCompletes` BEFORE calling `dismiss()`. The previous pattern (dismiss + `Task { sleep 350ms; enqueue }`) is removed.

**Rationale:** The 350ms-after-dismiss approach was a workaround for the SwiftUI z-order trap where the overlay (which lives on RootView) is hidden by a still-presenting sheet during dismiss animation. The trade-off was 350ms of dead air that read as *"the celebration only came after I closed the logging page."* New approach: enqueue first, sheet animates away, overlay is revealed from underneath in one continuous motion. Same total time-to-celebration; user perceives it as "tap save, see celebration."

### Story-mode walk-complete overlay — 2026-05-08
**Decision:** `WalkCompleteOverlay` renders **story progress** (minutes-today vs dog's dailyTarget with notches at 50%/100%) and a **PAGE 1 / PAGE 2 UNLOCKED stamp** when this walk crossed a milestone. Replaces the old route bar + landmark stamps + route-completed line.

**Rationale:** Once story mode owns post-walk progression, the celebration overlay must reflect that. The route bar showing "Finding your rhythm: 60/240 min" is meaningless under the new model. New shape on `PendingWalkComplete` carries `oldMinutesToday`, `newMinutesToday`, `targetMinutes`, `pagesAlreadyToday` — same compute as `StoryService.currentState` so the overlay's stamp logic mirrors the gating logic exactly.

### Journey/Route infrastructure deleted — 2026-05-08
**Decision:** All Journey/Route iOS code deleted: `JourneyView`, `JourneyService`, `JourneyService+Routes`, `ChapterMemoryService`, `DistanceTranslator`, `LandmarkRevealView`, `Routes.json`, `UKLandmarks.json`, `JourneyServiceTests`. Plus `LLMService.chapterMemory` and the matching `chapter_memory` proxy case.

**Rationale:** All five callers (AppState, LogWalkSheet, ExpeditionView, WalkCompleteOverlay, DebugSeed) rewired for story-mode in this session. JourneyView itself had been orphaned since the tab rename Journey → Story. Audit confirmed zero outside-tests references to the deleted symbols. Deleted in one commit so the diff is reviewable.

**Left for follow-up SwiftData migration:** `Dog.activeRouteID`, `routeProgressMinutes`, `completedRouteIDs`. Removing persisted fields is a CloudKit-aware schema change; deferred to refactor item 1.

### Never surface stored secrets to stdout — 2026-05-08
**Decision:** New rule in CLAUDE.md Security section: never run `git credential fill`, `cat .env`, `security find-generic-password -w`, or any command whose effect is to print a stored credential to stdout. Use metadata-only debugging when auth-requiring commands hang.

**Rationale:** During a `git push` debug, ran `git credential fill` to "verify creds were stored." That command's whole purpose is to write the secret to stdout for git's helpers — and so it leaked the user's GitHub OAuth token into the conversation transcript. Token had to be rotated. The rule + memory entry are durable backstops; CLAUDE.md spells out the metadata-only debug pattern so future sessions don't reach for the wrong tool when an auth-requiring command stalls.

### Decisions panel locked-but-visible — 2026-05-08
**Decision:** When a milestone hasn't been crossed yet, the decisions panel on the latest page renders the path buttons VISIBLE but DIMMED (45% opacity, padlock glyph replaces the per-genre path icon, tap is suppressed) plus a one-line lock explainer underneath: *"Walk Luna 18 more minutes to unlock the next page."*

**Rationale:** Three options were considered: hide the buttons until unlocked (anticipation lost), show them disabled with no explainer (users would assume bug), show them with explainer (chosen). The dimmed-with-explainer pattern gives users the *tease* of what's coming + the *exact rule* for unlocking it, reinforcing the "walk the dog → next page" loop.

### Pre-launch schema cleanup: destructive in-place V1 edit — 2026-05-08
**Decision:** When dropping persisted SwiftData properties pre-launch, edit `TrotSchemaV1` in place + bump `versionIdentifier` (e.g. `1.0.0` → `1.1.0`) and rely on SwiftData's lightweight migration. Do NOT snapshot the old class as a `DogV1`/`WalkV1`/etc. historical type into a frozen V1, define a parallel V2, and plumb a `MigrationStage` — that ceremony is reserved for the first schema change after CloudKit / TestFlight has shipped real user data.

The first application of this rule was the `firedMilestones` add (2026-05-06), where bumping V1→V2 hit *"Duplicate version checksums detected"* because both versions referenced the same live `Dog.self`. The second was this session's removal of `activeRouteID` / `routeProgressMinutes` / `completedRouteIDs` (refactor.md item 1), confirmed working — SwiftData lightweight-migrated the existing simulator store, dropped the three columns, and preserved Luna's row + every other field intact (verified by sqlite inspection of `default.store`'s `ZDOG` table).

**Rationale:** Pre-launch trigger conditions: `cloudKitDatabase: .none`, no TestFlight, population = developer's simulator + personal device. Risk of additive-then-subtractive is paying a couple of hours of ceremony for data preservation on devices that get wiped routinely anyway. Risk of in-place edit is a one-time fresh install if lightweight migration declines — cheap. Lightweight migration handles property removal automatically when the schema checksum bumps. The rule expires the moment CloudKit gets switched on or TestFlight ships; from that point forward all schema changes go through proper versioned migrations.

**Mechanics that work:** delete the property, bump `Schema.Version`, leave `TrotMigrationPlan.stages` empty, `MigrationPlan.schemas` stays `[TrotSchemaV1.self]`. A `Mirror`-based test in `TrotTests/DogModelTests.swift` acts as a tripwire if anyone reintroduces a removed field by accident.

**Subsequent applications (2026-05-09/10 session):** three more in-place migrations all worked cleanly under this pattern — `Story.sceneRaw` (1.1.0 → 1.2.0), `StoryChapter.seenAt` (1.2.0 → 1.3.0), and the book-length cluster `Story.finishedAt` + `title` + `closingLine` + `Dog.completedStories` (1.3.0 → 1.4.0). The pattern is now battle-tested for both adds and drops.

### Scene-setter step before page 1 — 2026-05-09
**Decision:** Between the genre-pick and the first LLM call, the user picks one of four genre-bound scenes (`StoryGenre.scenes`) — e.g. murder mystery: village fête / seaside hotel / old library / WI meeting. The pick persists on `Story.sceneRaw` and ships into the `story_page` proxy as `scenePrompt`, used to anchor page 1's opening lines. Nested under StoryGenre rather than a flat enum because scenes are intrinsically genre-bound.

**Rationale:** The "prologue is random — the user contributed nothing but a genre" problem. Best-practice scan of adjacent products (personalised kids' books, AI character makers, AI photo apps) showed: one constrained-choice tap is the sweet spot; user expects the input to *show up* in the output; two questions starts to feel like a form. Settling on ONE per-genre scene-question, 4 cards, ~3 seconds of friction. Real artwork is a v1.x swap that doesn't change the data model.

**What was rejected:** a second optional "Bonnie's nature in a word" personality picker. Held back as a v1.x candidate — only add if the scene-setter alone feels thin in playtest. Two questions risks the form-feel.

### Notification permission ask via walk-window reminder, not onboarding — 2026-05-10
**Decision:** No notification permission ask on launch and no forced onboarding step. The ask fires on the first "Remind me" tap on the walk-window tile (`WalkWindowTile.toggleReminder`). Once granted, `NotificationService.reschedule` picks up the other three scheduled types automatically (nudge, milestone, recap, morning-window) — permission is app-wide, not per-type. On denial, an inline "Notifications are off · Open Settings" hint sits under the capsule with `UIApplication.openSettingsURLString` deep link.

**Rationale:** First attempt at refactor item 5 (notification permission alert blocking first-launch) was a forced `OnboardingPermissionsView` between AddDog and Home, bundled with a Story-mode teaser. User pushback was sharp and clear: looked like sign-in, didn't motivate the ask, didn't explain Story mode well. The right pattern is a contextual trigger — the user explicitly opting in to a notification, which earns the prompt. The walk-window reminder is the cleanest such moment in v1; one-tap, user-initiated, intent unambiguous.

**What this rules out:** any future "ask permission on launch" or "forced screen bundling unrelated asks" pattern. If a future feature needs notifications, wire it to its own contextual moment (the user enabling that specific feature), not a global onboarding step.

### Story-mode discovery via Story-tab intro — 2026-05-10
**Decision:** The first time a user visits the Story tab without an active story (and without `UserPreferences.storyIntroSeen`), they see `StoryIntroView` — a one-screen explainer with three plain bullets ("one page per walk · six worlds · you steer it") and a Begin CTA that flips the flag. Subsequent Story-tab visits go straight to the genre picker (or active story). Discovery happens on the surface being discovered, not before it.

**Rationale:** Refactor item 10 ("onboarding doesn't mention Story mode"). Tried bundling Story-mode discovery into a forced onboarding screen; user pushback (see notification decision above) made it clear that discovery belongs ON the Story tab, not BEFORE it. Bottom-tab "Story" with the open-book icon already does most of the discovery work; the intro adds clean framing for the moment the user actually engages.

### Books are 5 chapters long, finished books archive — 2026-05-10
**Decision:** Each book is exactly 5 chapters × 5 pages = 25 pages. After chapter 5 closes, the proxy switches to a finale variant of `story_chapter_close` and returns a book title + book-closing line on top of the chapter wrap. The Story moves from `dog.story` (active) to `dog.completedStories` (cascade-delete `[Story]?` archive); `dog.story = nil`; the genre picker reappears on the Story tab. Completed books surface as `CompletedBooksShelf` below the genre picker. Per-genre `chaptersPerBook: Int` keeps the door open for varying pacing later.

**Rationale:** Books were rolling forever (chapter N → N+1 → ∞). No "finished" moment, no library, no way to start a fresh genre. 5 chapters at 1 page per walk + 50%/100% gating is roughly 2-4 weeks per book at typical use — frequent enough that the genre-pick moment recurs without feeling rushed; ~12 books per active dog per year.

**Bookshelf placement:** below the genre picker on the Story tab (vs separate Library tab vs sub-page). Same surface, no new bottom-tab, discoverable when you're already looking at story state. Tap → opens the book in the existing `StoryFullPageReader`.

**Storage shape:** two distinct cascade-delete relationships on `Dog` — `story: Story?` (active) and `completedStories: [Story]?` (archive). Avoided the "one collection, filter by finishedAt" alternative because it would have required updating every existing `dog.story` read site. The two-relationship model is symmetric, simple, and Story moves between them at the moment of finale via direct assignment.

### Course correct as a discipline — 2026-05-10
**Decision:** When the user pushes back hard on a design — especially with words like "confused", "didn't understand", "felt like X when it should be Y" — revert and redesign rather than patch. Keep the failed attempt in git history (don't rebase) so the trail of the course correct is visible.

**Rationale:** First attempt at refactor items 5 + 10 combined them into a forced onboarding screen. User pushback was unambiguous; right answer was to delete the screen, not to tweak it. Two distinct concerns (notification permission, Story-mode discovery) needed two distinct contextual triggers. Patching would have been quicker but would have entrenched a wrong shape. Pattern: when the feedback is conceptual ("wrong place", "wrong bundling"), revert; when feedback is detail ("typo", "wrong colour"), patch.

**Implementation note:** the sequence `cedbae2` (wrong design) → `5da822c` (revert + new design) → `242b072` (em-dash polish) is a useful pattern. Three tight commits, each reviewable, full provenance preserved.

### Strategic repositioning: book as lead, walking as cost — 2026-05-10
**Decision:** Trot is repositioned end-to-end as "an AI book about your dog that grows when you walk them" — not as a walking tracker with a story feature. The book leads marketing, leads onboarding, leads the App Store listing, leads the home view. Walking is reframed as the cost of the next page, not the thing the app does.

This supersedes the original positioning ("Trot detects walks automatically and tailors targets to your dog's breed, age, and health") which was a feature list and put Trot in a category (walking tracker) where free alternatives were stronger. The new positioning is a job-to-be-done ("tell me a story about my dog") in a category Trot effectively owns.

**Rationale:** Brutal product audit on 2026-05-10 surfaced three issues with the original v1 design — onboarding too long, cold start cliff before the wow, App Store positioning indistinguishable from generic tracker. All three converged on the same fix: Story mode is the actual product; everything else is supporting. Best practices in 2026 (Lensa-style instant-wow, Lapse-style social hook, Strava-style HealthKit history backfill) all confirmed the direction.

**What this rules in for v1:** Story-mode-on-day-0 (prologue lands during onboarding from profile alone, before the first walk); HealthKit history backfill on day 0; share cards on book completion; minimum-viable Trot Pro paid tier; App Store + landing-page positioning rewrite.

**What this defers / reverses:**
- Reverses "lifetime stats start at zero" (now: HealthKit backfill on day 0)
- Reverses "first-week milestone ladder as a separate UI surface" (now: woven into story mode page unlocks + chapter close + the streak/recap loops)
- Defers full breed-table-driven targets — generic-breed defaults cover 90% of value; ship simple, refine later
- Sci-fi / horror / fantasy genres can ship as v1.x content drops if the build budget tightens; cosy + mystery + adventure are the v1 minimum

### Onboarding compresses to two screens, prologue lands in under 90s — 2026-05-10
**Decision:** New onboarding shape: (1) sign in with Apple, (2) photo + name + breed, (3) genre pick, (4) scene pick, (5) prologue generates and displays, (6) permissions ask after the user has read page 1, (7) land on Story tab with locked path-choices. Postcode, DOB, weight, conditions, walk windows are deferred to optional in-app moments.

The minimum viable profile to generate a prologue is name + photo + breed. Everything else is requested when its absence becomes a tax on a specific feature ("add postcode for the daily walk-window forecast" / "tell us Bonnie's age so the story can know how old she is").

**Rationale:** Original onboarding asked for ten profile fields up front from a user who hadn't been sold yet. Lensa, Lapse, every successful 2026 onboarding gets to a wow in under three taps. The wow here is the prologue landing. Everything else is in service of getting there fast.

**Replaces:** the previous 6-step onboarding (gate → AddDog with full profile → walk windows → permissions → Home with empty stats). The deferred fields don't disappear — they get asked at the moment the user would benefit from them.

### Page-1 cliffhanger is a hard rule — 2026-05-10
**Decision:** The proxy `story_page` system prompt now enforces "every page ends on a hard hook for the next page — a discovery, a name spoken, a door opening, a sudden change, a sound heard. NOT a closing summary, NOT a tied-off scene." The prologue line escalates: "the reader has not walked the dog yet — this is their first taste of the book, and it has to be strong enough to send them out the door for the next page."

The fourth wall stays intact — the prose never mentions walking or the next page or the app. The UI handles the "walk to unlock" message via the dimmed-with-explainer decision panel. The prose alone earns the next walk.

**Rationale:** Story mode is the retention engine; cliffhanger discipline is what makes it actually retain. Previous prompt said "end on something that pulls the reader forward" which is too soft. The new rule names the exact shape (discovery / name / door / change / sound / question) and disallows the genre-generic fail mode ("they walked home"). Fallback prologues need to be re-audited against this rule on the next pass.

### Notification ask moves to the first earned moment — 2026-05-10
**Decision:** Notification permission is asked **after the user reads page 1 of the prologue**, not on the walk-window reminder toggle (which was the previous landing — see `Notification permission ask via walk-window reminder` above). The copy: "Want me to nudge you when there's a fresh page?" The user has just received value from the app; the ask is earned.

**Supersedes** the walk-window-reminder-toggle ask — that ask is now redundant once notifications are granted earlier in the flow. The reminder toggle still works for users who denied at onboarding (showing the inline "Open Settings" hint). The contextual reminder-toggle path is the fallback, not the primary.

**New primary notification: "story page-ready nudge".** When a walk crosses a page-unlock threshold (50% or 100% of target), a notification fires: "Bonnie's next page is ready." Direct deep-link into Story tab. This replaces the "under-target nudge" as the headline daily push because it earns more taps and aligns with the book-as-lead positioning.

### v1 gains share cards + paid tier — 2026-05-10
**Decision:** Two features previously deferred to v1.x are pulled into v1 scope:

**Share cards on book completion.** A finished book exports a beautifully designed card (dog photo, title, genre, stats line, closing line excerpt, "Made with Trot" mark) via `UIActivityViewController`. Without this, every install must come from paid acquisition or personal network. With it, finished books seed organic discovery — the single highest-leverage growth lever available pre-launch.

**Trot Pro at £3/month or £20/year.** Free tier covers core loop (one dog, one book at a time, all walking + streak features, last 30 days HealthKit backfill, watermarked share cards). Pro unlocks: full HealthKit history backfill, multiple active dogs, clean share cards, priority story generation. StoreKit 2.

**Rationale:** Free apps with LLM costs are unsustainable at scale; pet owners in 2026 are conditioned to pay for things they care about (BarkBox, FitBark, Whistle, Tractive). A small paid tier signals quality and funds the AI loop. The "no monetisation in v1" stance was a feature, not a virtue — adding the simplest viable paid tier strengthens v1 rather than compromising it.

**Out of scope for v1 still:** print-on-demand for finished books, public web URLs for shared books, couples accounts (the latter pulled out of v1 reluctantly — flagged as the highest-priority post-launch feature).

### App Store + landing positioning rewrite — 2026-05-10
**Decision:** Lead App Store metadata becomes:
- App Name: `Trot: A Book About Your Dog` (28 chars)
- Subtitle: `AI writes a page every walk` (28 chars)

Landing page hero leads with "AI writes your dog a book" (replacing "Daily walks for your dog"). Three feature blocks reorder: book first, walking second, personalisation third (was: walks-log-themselves first).

Backup variant if Apple review pushes back on the "Book About Your Dog" framing: `Trot: Walk to Write the Book` / `AI writes a story when you walk`.

**Supersedes** the previous metadata (`Trot: Daily Dog Walks` / `Build a daily walking habit`) which positioned Trot in the crowded walking-tracker category.

### Day-0 HealthKit history backfill — 2026-05-10
**Decision:** After the prologue lands and the user grants HealthKit, Trot pulls the last year of walking history from HealthKit and surfaces it as part of the dog's stats: "Bonnie has walked with you 84 hours over the past year." Insights tab uses this data immediately rather than the 7-day "learning" state.

**Reverses** the previous "Pre-Trot lifetime stats backfill: Accept zero" decision. That decision's rationale (avoid the awkward "how long have you had Luna?" question + prorated fictional baselines) is preserved by sourcing the data from HealthKit, not from the user — there's no fictional anything; it's the user's own walking history.

**Free tier sees the last 30 days; Pro sees the full year.** Backfill is a Pro-tier upsell and the day-0 wow.

**Rationale:** "Lifetime stats start at zero" was the single most retention-hostile choice in the original v1 design. Best-practice 2026 apps (Strava, Apple Fitness, Whoop) all backfill from HealthKit on day 0 — empty home screens are conversion killers. Trot's strongest day-0 wow is the prologue; the second-strongest is "Bonnie has walked with you 84 hours over the past year."

---

## Open

### Walk detection algorithm
**Question:** What is the precise state machine and signal-fusion logic that turns Core Motion + HealthKit data into reliable walk-detected events?

**Status:** Deferred to a dedicated plan-mode session at the **end** of the v1 build (per "Build sequence: passive walk detection ships last" above). Until that point, manual walk logging is the primary path and HealthKitService work does not begin.

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
