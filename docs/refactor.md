# Trot — Refactor backlog

Working document for the refactor pass after the Story tab rebuild (2026-05-08). Read this in order. Each item lists what, why, where, and acceptance criteria. Items are roughly ordered by *do-first* — earlier items unblock or simplify later ones.

The session that produced this list shipped a major Story-mode rewrite + ripped the Journey/Route system. Code is functionally clean (build passes, zero warnings) but several structural debts accumulated. Fix in this order, plan-mode each item before code.

**Status as of 2026-05-10:** items 1, 3, 5, 10 ✅ shipped. Item 4 partially shipped (StoryServiceFinaleTests covers the new finale path; full `currentState` matrix still open). Items 2, 6, 7, 8, 9, 11–14 still open and best done as a single "spring clean" pass once features are locked.

---

## 1. ✅ SHIPPED 2026-05-08 — SwiftData migration: drop deprecated Dog journey fields

`Dog.activeRouteID`, `Dog.routeProgressMinutes`, `Dog.completedRouteIDs` are persisted SwiftData properties left over from the Journey/Route system that was deleted on 2026-05-08. They sit on the model with a `// MARK: - Journey state (DEPRECATED — pending SwiftData migration)` comment. Nothing in the running app reads them.

**Why this is item 1:** every other refactor that touches `Dog` (or Story-related models) is cleaner once these are gone. CloudKit-synced storage means we need a real migration with a versioning plan.

**Where:** `ios/Trot/Trot/Core/Models/Dog.swift`. SwiftData `Schema` versioning + a `MigrationPlan` per Apple's docs.

**Risk:** existing installs (the user's TestFlight devices, primarily — there's no production yet) have the old fields populated. Migration must be additive-then-subtractive across two SwiftData versions, OR a single destructive version-bump if we accept a one-time wipe (no production = acceptable IF user explicitly OKs).

**Acceptance:**
- Migration plan compiles + ships in DEBUG without crashing on launch
- Pre-migration dogs continue to load; post-migration dogs lack the journey fields
- DEBUG-only assertion that `Dog` no longer has the journey fields after migration
- CloudKit production schema NOT yet deployed — this is pre-launch

**Decision needed before starting:** destructive migration (simpler, requires user OK) vs additive-then-subtractive (safer, more work).

---

## 2. Long-file splits (CLAUDE.md rule: views > 200 lines should split)

10 files exceed 400 lines, several push past 500-700. Some are legitimately complex; some have clear extraction seams. Per `CLAUDE.md`: *"Split files early. SwiftUI view past 200 lines → break it up."*

Top offenders + suggested splits:

| File | Lines | Notes |
|---|---|---|
| `Features/Home/WeatherMoodLayer.swift` | 794 | Large per-condition rendering switch — extract per-condition layers into separate types in a `WeatherMoodLayer/` subfolder. |
| `Features/Insights/InsightsView.swift` | 752 | Multiple sections inline. Each tab section (lifetime stats, observations, recap-row, achievement-grid) can become its own file. |
| `Features/Home/HomeView.swift` | 737 | Tab bar config + sheet wiring + helper struct + Today-tab content. Extract `HomeTabBar`, `HomeSheets` into separate files. |
| `Features/Story/StoryView.swift` | 558 | Banner views (`GenerationStatusBanner`, `GenerationErrorBanner`) inline; `StoryHeader`, `EmptyStoryPlaceholder` private inline. Split into `StoryView+Banners.swift` and `StoryView+Helpers.swift`. The `pageInteraction(for:dog:)` method could move to a tiny VM. |
| `Features/Expedition/ExpeditionView.swift` | 550 | `StoryMilestoneToast` + `StoryMilestoneToastView` inline at the bottom — split into `ExpeditionView+StoryMilestoneToast.swift`. The `storyProgress` view + helpers could be a sub-component. |
| `Core/Services/StoryService.swift` | 546 | Six fallback prologues take ~200 lines. Extract into `StoryService+FallbackPrologues.swift`. |
| `Features/Onboarding/AddDogView.swift` | 542 | Multi-step form. Extract step views into separate files. |
| `Core/Services/LLMService.swift` | 524 | Each kind has its own static func + decoder. Extract `LLMService+Story.swift`, `LLMService+DogVoice.swift`, etc. |
| `Features/Home/WalkWindowTile.swift` | 504 | DEBUG synthetic-forecast helper alone is ~30 lines. Production `update`/`refreshLLMHeadline`/`toggleReminder` could split from rendering. |

**Acceptance per file:** post-split, no view file over ~250 lines. No public API changes (this is an internal reorg). Build clean. No warnings.

**Suggested order:** start with `LLMService` (least risky, pure-function service) to develop the splitting pattern, then services, then views. Don't try to split everything in one PR.

---

## 3. ✅ SHIPPED 2026-05-09 — Chapter-close overlay re-firing on fresh installs

`StoryService.unseenClosedChapter` keys "seen" state via `UserDefaults.standard.bool(forKey: "trot.story.chapterSeen.\(chapter.persistentModelID.hashValue)")`. The hash changes per app install (SwiftData persistentModelID is install-scoped, not user-scoped), so on every fresh install the seed's closed chapter gets re-celebrated.

**Symptom:** every reinstall shows "The Empty Plinth — Chapter 1 closed" celebration overlay before the user can do anything.

**Fix options:**
1. Move "seen" state to a SwiftData field on `StoryChapter` (e.g. `chapterSeenAt: Date?`). Survives reinstalls + CloudKit sync.
2. Key UserDefaults on a stable identity (chapter index + dog persistentModelID hash + story creation date).

Option 1 is correct. UserDefaults was always a workaround.

**Where:** `Core/Services/StoryService.swift` (`seenKey`, `markChapterSeen`, `unseenClosedChapter`), `Core/Models/StoryChapter.swift` (new field), and `Features/Story/StoryView.swift` (which calls `markChapterSeen`).

**Acceptance:**
- New field on StoryChapter
- Migration from existing UserDefaults seen-keys (read all matching keys, set field, delete keys)
- DebugSeed pre-marks the seed's closed chapter as seen on creation
- Reinstalling no longer re-fires the close overlay

---

## 4. ⚠️ PARTIAL — StoryService test coverage

**Status update 2026-05-10:** `StoryServiceFinaleTests` (8 tests) shipped alongside the book-length feature, covering `finishBook` field-stamping, relationship-swap, idempotency, fallback title, completed-stories sort. Full `currentState` matrix still open below.

**Original plan:**

`StoryService.currentState` was extended this session with milestone gating + page cap logic. Zero tests. We deleted `JourneyServiceTests.swift` (~150 lines) and added nothing. Net test count dropped.

**Tests needed:**
- `.noStory` when `dog.story == nil`
- `.awaitingFirstWalk` when `everWalked == false`
- `.caughtUp(.dailyCapHit)` when `pagesGeneratedToday >= 2`
- `.caughtUp(.needMoreMinutes(.halfTarget, ...))` when `pagesGeneratedToday == 0` && `minutesToday < halfTarget`
- `.caughtUp(.needMoreMinutes(.fullTarget, ...))` when `pagesGeneratedToday == 1` && `minutesToday < target`
- `.pageReady` when `pagesGeneratedToday == 0` && `minutesToday >= halfTarget`
- `.pageReady` when `pagesGeneratedToday == 1` && `minutesToday >= target`
- Edge: target = 1 (halfTarget clamps to 1)
- Edge: minutesToday = 0 with everWalked = true (different from awaitingFirstWalk)
- Edge: target = 0 (defensive — clamp to 1 internally)

**Where:** `ios/Trot/TrotTests/StoryServiceTests.swift` (new file). Use Swift Testing (`@Test`/`#expect`).

**Acceptance:** ≥10 tests, full-suite pass with `-parallel-testing-enabled NO -only-testing:TrotTests/StoryServiceTests`.

---

## 5. ✅ SHIPPED 2026-05-10 — Notification permission alert on every reinstall

`DebugSeed.seedIfEmpty` pre-fires the `firstWalk` milestone (so the user lands on a "Luna already has 6 walks" state). That milestone enqueues a celebration which triggers `UNUserNotificationCenter.requestAuthorization` (because permission hasn't been requested yet on a fresh install). Result: the iOS notification permission alert overlays the centre of the screen on every reinstall, blocking simctl screenshots.

**Fix options:**
1. Skip the auth request when the firstWalk milestone is pre-fired by seed (vs a real walk).
2. Move the auth request out of the celebration flow entirely — into onboarding (after Sign-in-with-Apple, before Add Dog).
3. Add `-DebugSkipNotifications YES` (already exists) to all simulator launch invocations.

Option 2 is correct — onboarding is where permission asks belong, not mid-celebration. Spec says auth should be requested at the dedicated permissions screen of onboarding.

**Where:** `RootView.swift` (currently calls `NotificationService.requestPermission()` from `.task(id: isPastGate)`), Onboarding flow.

**Acceptance:** notification permission alert no longer fires on first-launch celebrations. Onboarding has a dedicated permissions step that asks for notifications + HealthKit. Simulator screenshots clean.

---

## 6. Strict-MainActor `await` audit

The project uses `-default-isolation=MainActor` (Swift 6 strict-concurrency setting). Some files have legacy redundant `await` calls on `@MainActor` synchronous functions — these emit *"no 'async' operations occur within 'await' expression"* warnings. Last turn cleared 7 from `WalkWindowTile`. Same pattern likely lurks elsewhere.

**Where to look:** anywhere using `await update(...)` or `await load(...)` where the called func is `@MainActor` synchronous. Grep for `await ` in view files.

**Acceptance:** zero "no 'async' operations" warnings on a clean build.

---

## 7. `print()` calls audit

Project has scattered `print()` for diagnosis — some intentional (LLMService failure logging from this session), some leftovers. Per `CLAUDE.md`: *"No raw print() in production code paths."*

**Action:** grep all `print(` calls. For each:
- Keep + wrap in a logger if intentional diagnostic (LLMService failures qualify)
- Delete if leftover

**Where:** project-wide grep `print(`.

**Acceptance:** every remaining `print()` is gated `#if DEBUG` or routed through a Logger.

---

## 8. Memory hygiene + CLAUDE.md promotion candidates

Auto-memory has accumulated ~10 entries. Some are durable rules that belong in CLAUDE.md; some are stale.

**To audit:**
- `feedback_codesign_provenance_workaround.md` — durable build-system fact, not really "feedback." Could promote to CLAUDE.md under a "Build" section.
- `feedback_simulator_reinstall_routine.md` — covered by CLAUDE.md `## Discipline` already? Verify.
- `feedback_serial_xcodebuild_tests.md`, `feedback_targeted_tests_during_iteration.md` — both about test workflow. Could merge into one "Testing workflow" memory or promote to CLAUDE.md `## Testing`.
- `project_llm_deferred_to_v1_1.md` — STALE. LLM was un-deferred this session (now central to v1, see decisions.md). Delete.

**Where:** `~/.claude/projects/-Users-corey-Documents-Claude-Projects-Trot/memory/` + `MEMORY.md` index.

**Acceptance:** stale entries deleted + index updated; durable rules promoted to CLAUDE.md (delete the memory file once promoted, update MEMORY.md).

---

## 9. Brand voice audit on Story-mode surfaces

Story mode introduced a lot of new copy. Audit each line against `docs/brand.md` voice rules:
- WalkCompleteOverlay's `progressCaption` ("X min to today's first page" etc.)
- ExpeditionView's `storyProgressCaption`
- StoryView's `GenerationStatusBanner` headlines per genre
- StoryView's `GenerationErrorBanner`
- StoryPageReader's `whatNextLabel` and `readMoreLabel` per genre
- StoryGenerationProgress headlines + sublines per genre

**Look for:** em dashes (banned), shaming, fake urgency, dog-body puns, generic celebration language.

**Acceptance:** every line passes brand.md "Never" list; voice consistent across the whole story flow.

---

## 10. ✅ SHIPPED 2026-05-10 — Onboarding flow — has it kept up with story mode?

Story mode is now the headline progression. Does onboarding mention it? Set the user's expectation that picking a dog → get a book per dog?

**Where:** `Features/Onboarding/`. Particularly `AddDogView.swift` (542 lines).

**Acceptance:** onboarding mentions Story mode in voice that matches brand.md. The "what is this app" framing in onboarding aligns with what the user actually does after onboarding (Story tab is now central).

---

## Lower-priority items

11. **Force-light-mode audit.** `Info.plist` has `UIUserInterfaceStyle = Light`. New views added this session — confirm none accidentally bound to system color scheme.
12. **Photo storage audit.** Story page photos use `Data?` directly on the model. Per `CLAUDE.md` rule: *"Photos use `@Attribute(.externalStorage)` — never inline."* Verify `StoryPage.photo` follows this.
13. **Insights tab dead-code sweep.** With JourneyView gone, are there Insights-tab references to "route progress" / "landmarks" / "chapter memory" that need re-pointing at story state?
14. **Documentation: README.md** hasn't been touched this session. Check it doesn't reference Journey-mode features that no longer exist.

---

## Strategic-shift items (added 2026-05-10)

These items implement the book-as-lead repositioning captured in `decisions.md` "Strategic repositioning: book as lead, walking as cost". Each is a substantial feature deserving its own plan-mode session. Order matters — earlier items are prerequisites for later ones.

### S1. Story-mode-on-day-0 — generate the prologue during onboarding

**Highest-priority strategic item.** The wow moment moves from "your first walk → your first page" to "you finished onboarding → here's page 1." Replaces the current "no story → genre picker → scene picker → walk to unlock" flow on the noStory branch with: onboarding gathers the minimum profile, then drops the user straight into the genre picker, then the scene picker, then displays the prologue as the final onboarding screen with locked path-choices visible underneath.

**Where:** RootView routing, AddDogView (compresses to photo + name + breed only), new OnboardingStoryFlow that wraps StoryGenrePicker + StoryScenePicker + the prologue display, StoryService.pickGenre called from the onboarding context.

**Risk:** changes the onboarding mental model significantly. Plan-mode this thoroughly.

**Acceptance:** new install → 90 seconds to a generated prologue on screen. The user reads page 1 before they're asked for any permissions. The Story tab is the home view from the moment the prologue lands.

### S2. HealthKit history backfill on day 0

After the user grants HealthKit, pull the last year of `distanceWalkingRunning` + step samples and surface "Bonnie has walked with you 84 hours over the past year" on the Insights tab + as part of lifetime stats. Free tier sees the last 30 days; Pro sees the full year.

**Where:** new `HealthKitBackfillService` (or extension of HealthKitService when that ships); Insights tab to render the new stat; subscription gating on the year-vs-30-days split.

**Acceptance:** day-0 install + grant → Insights tab shows real numbers, not the 7-day "learning" state.

### S3. Share cards on book completion

Generate a shareable card at book finish: dog photo (hero) + book title + genre badge + stats line + closing-line excerpt + "Made with Trot" mark. Export via `UIActivityViewController` to Photos / Messages / Instagram / etc.

**Where:** new `BookShareCard` SwiftUI view rendered to UIImage via ImageRenderer, presented from `StoryFinaleOverlay`'s "Share" button (new) or available from any completed book on the bookshelf.

**Acceptance:** finished book → tap Share → native iOS share sheet with a beautifully designed card.

### S4. Trot Pro paid tier scaffolding

Single subscription product (`trot.pro.monthly` £3 or `trot.pro.annual` £20) via StoreKit 2. Free vs Pro gates: HealthKit backfill horizon (30d vs 1y), multiple active dogs, share-card watermark, story-generation queue priority. Subscription state lives on AppState; gating helpers wrap the relevant features.

**Where:** new `SubscriptionService`, paywall view (presented at upsell moments — not interruptive), gating sites in HealthKitBackfillService / Dog management / BookShareCard / StoryService.

**Acceptance:** purchase flow works in StoreKit sandbox; restore-purchases works; paywall can be dismissed without buying; non-Pro users hit clear, kind upsell messaging at gate points.

### S5. App Store + landing positioning rewrite (already partially done in docs)

Update the actual landing-page HTML in `web/index.html` to match the new headline + feature blocks captured in `docs/landing.md`. Update the iOS app's Info.plist `CFBundleDisplayName` and the App Store Connect metadata when next building for TestFlight. Keep the current "walking tracker" backup variant in source comments for review-rejection fallback.

**Where:** `web/index.html`, `web/styles.css` (if needed), iOS `Info.plist`, App Store Connect (manual when TestFlight build ships).

### S6. Notification ask moves to "first page read"

Currently asked on the walk-window reminder toggle (per `decisions.md` "Notification permission ask via walk-window reminder"). New primary trigger: after the user finishes reading the prologue on day 0, a one-time card appears with copy "Want me to nudge you when there's a fresh page?" and the Allow / Maybe later buttons. The walk-window reminder fallback path stays for users who decline.

**New notification kind: story page-ready.** When a walk crosses 50% or 100% of target and a page unlocks, fire a local notification "Bonnie's next page is ready." with deep-link to Story tab. Replaces the under-target nudge as the headline daily push.

**Where:** new card in `StoryView` that appears once after the prologue is read (gated on `UserPreferences.notificationAskShown`); `NotificationService` gains the page-ready scheduling; `WalkCompleteOverlay` enqueues the page-ready notification when its event has `pageUnlocked` non-nil.

### S7. Couples / shared accounts (highest post-launch priority — NOT v1)

Flagged here so it doesn't get lost. Two humans walking the same dog should both get credit. Uses CloudKit shared zones (or a server-mediated path). Plan-mode separately when v1 ships.

---

## Working agreement for the refactor session

Per `CLAUDE.md` workflow rules:
- Plan-mode each item before code
- Don't scope-creep into adjacent items
- Commit per item with a clear message
- Update `docs/decisions.md` if any architectural calls come out of the work
- Append to `docs/log.md` at the end of the session
- Run targeted tests during iteration; full suite once before commit
