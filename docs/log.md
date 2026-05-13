# Trot — Session log

A lightweight "where are we" file. Read this when resuming work after a break. Update at the end of each substantive session.

**Format:** newest entry at the top. Each entry covers what was done, what was committed, what's next, and any blockers. Older entries (10+ sessions back) get compressed to a single line.

**This file is not auto-loaded into CLAUDE.md context** — it's read on demand to keep daily context costs low.

---

## 2026-05-10 → 2026-05-12 — Polish + DEBUG affordances for living with the new onboarding

Short follow-up session on top of the onboarding rebuild. The goal was to get the new flow into a "I can actually use this for a few days" state — Corey is parking the project to live with the build before deciding what's next. Three small fixes + the simulator media setup.

**Done — polish + DEBUG:**

- **"Restart onboarding" button in Profile → Debug Tools.** New `onboardingCard` section in `DebugToolsCard.swift` with a destructive button + confirmation. Wipes every dog/walk/window/story, resets `onboardingDone` / `onboardingMigrationDone` / `storyIntroSeen` UserDefaults flags, drains pending overlays, and bumps `AppState.debugRestartCounter` so RootView observes the change and flips `hasContinued` back to false synchronously. Result: tapping the button bounces the user from Home directly to the sign-in gate, where Continue runs the new flow end-to-end. No app kill required.
- **`trot://debug/reset` deep link parity.** `handleReset` now bumps the same `debugRestartCounter` and drains the same pending overlays, so the terminal path matches the in-app button. Anyone using `xcrun simctl openurl ... trot://debug/reset` lands on the gate immediately.
- **Prologue "Read the file" pill fix.** The pill on the prologue page card was a no-op in onboarding because `OnboardingFlowView` mounted `StoryPageReader` without an `onOpenFullReader` callback. Wired up a private `ProloguePageRef` Identifiable wrapper + a `.fullScreenCover(item:)` modifier that opens the existing `StoryFullPageReader` for the single prologue page. The pill now opens the iPhone-screen-sized reader, matching the Story tab's behaviour post-onboarding.
- **AI dog photos imported to the iPhone 17 simulator's Photos library** via `xcrun simctl addmedia`. `dog-luna.jpg` / `dog-walk-1.jpg` / `dog-walk-2.jpg` are now pickable from the onboarding photo step. The photos do NOT ship in the app bundle (per `decisions.md` → "Design-system AI-generated images") — they're simulator-only conveniences. **Gotcha:** `simctl addmedia` chokes on paths with spaces. Fix is to copy to `/tmp/` first.

**Tests:** 194 unit + 4 UI still passing. No new tests added — the polish is UI/DEBUG wiring around already-tested service logic.

**Build:** clean. App installed and verified on iPhone 17 simulator.

**Status of uncommitted work (working tree):**

- New files (4): `OnboardingFlowView.swift`, `OnboardingProfileStep.swift`, `OnboardingPermissionsStep.swift`, `OnboardingFlowResumeTests.swift`
- Modified (8): `RootView.swift`, `DebugDeepLinks.swift`, `AppState.swift`, `UserPreferences.swift`, `OnboardingGateView.swift`, `DebugToolsCard.swift`, `AddDogFormStateTests.swift`, `docs/log.md`

Nothing committed yet — Corey is reviewing the working tree before deciding what to bundle. Suggested commits if splitting cleanly:
1. UserPreferences + RootView routing + migration one-shot
2. OnboardingProfileStep + OnboardingPermissionsStep + OnboardingFlowView
3. RootView/AppState/DebugDeepLinks/DebugToolsCard restart-onboarding affordance
4. Tests + minimal-fields AddDogFormStateTests case
5. docs/log.md

Or one bundled commit for the whole onboarding rebuild — also fine for pre-launch.

**Next session pickup:**

- **Corey is parking the project to live with the new build for a few days.** Real use is the validation we need — does the prologue land emotionally on day 0, does the under-90s claim hold, does the "READ THE FILE" reader feel right, is the permissions ask landing in the right emotional moment, are the genre + scene picks well-named, does the picker UX feel calm or fussy. Qualitative read.
- **On return**, the open candidates from `decisions.md` 2026-05-10 are (highest leverage first):
  - **Day-0 HealthKit history backfill** — depends on `HealthKitService` which is held to end-of-build per `decisions.md`. The copy ("Bonnie has walked with you 84 hours over the past year") can be drafted ahead, but the data hookup waits.
  - **Cliffhanger prompt tightening** on the Vercel proxy. The new onboarding makes the prologue's quality more load-bearing. ~30-60 minute pass.
  - **Deferred-field in-app prompts** (postcode/DOB/weight/health) surfaced on Home/Profile with contextualised value framing. ~half-day chunk.
  - **Share cards on book completion** — pulled into v1 scope on 2026-05-10 but not yet built. Bigger chunk; UIActivityViewController + designed share card.
  - **Trot Pro paid tier** — pulled into v1 scope but a meaningful lift (StoreKit 2 + feature gating).
  - **App Store + landing copy update** to match the repositioning. Smaller chunk; mostly copywriting.
- **End-of-build chunks (held intentionally, decided 2026-05-10):** Sign in with Apple, CloudKit production turn-on, HealthKitService + walk detection algorithm, Apple Developer Program £79 spend. Trigger is still "I want to walk around the block and confirm iOS wakes my app in the background." Not yet.

**Blockers / open:** none. Live build is good. Run via `Restart onboarding` from Profile → Debug Tools whenever Corey wants to re-experience the cold-start journey.

---

## 2026-05-10 (afternoon) — Onboarding rebuild: prologue lands in under 90s

The 2026-05-10 repositioning ("book is the lead, walking is the cost") was in `decisions.md` but not in the code. Today's onboarding still asked for the full profile up front and the prologue only landed once the user found the Story tab and tapped through the genre + scene pickers. This session implements the new shape: gate → photo+name+breed → genre → scene → prologue → permissions ask → Home, with the prologue landing in under 90 seconds.

**Done — new onboarding flow:**

- **`OnboardingFlowView` coordinator** (`Features/Onboarding/OnboardingFlowView.swift`) — six-step state machine: `.profile` → `.genre` → `.scene` → `.generating` → `.prologue` → `.permissions`. Embeds the existing `StoryGenrePicker`, `StoryScenePicker`, `StoryGenerationProgress`, and `StoryPageReader` so the genre+scene UI is identical to what users see later on the Story tab. Atmosphere coalescing chain (genre preview behind scene picker behind generating step) mirrors `StoryView`'s pattern. Resumes at the right step on `.onAppear` so a backgrounded mid-flow is recoverable: no dog → `.profile`, dog without story → `.genre`, dog with story but `onboardingDone == false` → `.permissions`. The resume logic is extracted as `static func resumeStep(for dog: Dog?) -> Step` for unit-testability.
- **`OnboardingProfileStep`** (`Features/Onboarding/OnboardingProfileStep.swift`) — compressed to three fields: photo (optional), name (required), breed (required). Reuses `AddDogFormState` so the breed-table-driven daily target still computes (graceful degradation: DOB and weight defaults feed `ExerciseTargetService` which has size/breed fallbacks). Postcode, DOB, weight, sex, neuter, activity, health flags are deferred to in-app prompts (not yet built — follow-up UX work).
- **`OnboardingPermissionsStep`** (`Features/Onboarding/OnboardingPermissionsStep.swift`) — post-prologue ask with the headline "Fresh page?" and copy "A nudge when {dog}'s next page is ready. Nothing else, no spam." Two buttons: "Yes, nudge me" (calls `NotificationService.requestPermission()` + `reschedule(for:)`) and "Maybe later" (no-op). Both paths flip `UserPreferences.onboardingDone = true` and fire the coordinator's `onComplete` callback.
- **`UserPreferences.onboardingDone` + `onboardingMigrationDone`** (`Core/Services/UserPreferences.swift`) — new UserDefaults-backed flags. `onboardingDone` drives the `RootView` routing decision; `onboardingMigrationDone` is a one-shot flag that lets the routing differentiate between "pre-existing user (already onboarded under the old flow)" and "new user genuinely mid-flow with a story but no permissions decision yet."
- **`RootView` routing rewrite** (`App/RootView.swift`) — added `shouldShowOnboardingFlow` as a pure-function read of state. Routing branches: gate → onboarding (if `shouldShowOnboardingFlow`) → legacy `AddDogView` (defensive fallback when `onboardingDone == true && activeDogs.isEmpty`) → `HomeView`. The migration check (`!onboardingDone && !onboardingMigrationDone && dog.story != nil → treat as migrated`) runs **inline** in the routing decision, not just in `.task`, so first-paint routing is consistent for existing users — no flash through `OnboardingFlowView` while the `.task` migration races. The `.task` version of the migration still runs as a backstop to flip the persisted flags.
- **DEBUG paths reset onboarding flags too** — `OnboardingGateView`'s "Reset all data (DEBUG)" button now also resets `onboardingDone`, `onboardingMigrationDone`, and `storyIntroSeen` so the next-launch flow runs through the new onboarding cleanly. Same change applied to `trot://debug/reset` in `DebugDeepLinks.swift`. The wipe button gains an `onDebugWipe` callback so `RootView` can sync its `@State onboardingDone` synchronously and avoid a one-frame flash through the legacy `AddDogView` fallback.

**Done — tests:**

- New `OnboardingFlowResumeTests` (3 tests) — covers the three resume cases via the extracted `OnboardingFlowView.resumeStep(for:)` static helper. In-memory `ModelContainer` per test, fixture-style.
- New `AddDogFormStateTests.minimalFieldsProduceUsableTarget` — confirms that the new compressed form (only name + breed + photo) still produces a positive `dailyTargetMinutes` via `ExerciseTargetService`'s fallbacks. Sanity-bounds the result (>0, <240).
- **Test count: 194 unit + 4 UI passing, all serial.** Net additions this session: 4 new tests (3 resume + 1 minimal-fields).

**Done — gotchas hit and resolved:**

- **iOS Simulator UserDefaults persistence quirk.** `simctl uninstall` does NOT wipe UserDefaults stored at the device-level path (`~/Library/Developer/CoreSimulator/Devices/<id>/data/Library/Preferences/<bundle>.plist`). The actual UserDefaults the app reads/writes lives in the *app container* (`/data/Containers/Data/Application/<id>/Library/Preferences/<bundle>.plist`), which IS wiped on uninstall. Spent some time confused by `defaults read` showing stale top-level state while the app was reading fresh container state. Resolution: `plutil -p` against the container path tells the truth.
- **Race between `.task` migration and first-paint routing.** Initial implementation only flipped `onboardingDone` in `.task(id: isPastGate)`, which fires asynchronously. Result: the user who already had a dog with a story flashed through `OnboardingFlowView`'s permissions step for one frame before the routing re-evaluated. Fixed by inlining the migration condition into a synchronous `shouldShowOnboardingFlow` computed property that the routing reads directly. The `.task` migration stays as a backstop to persist the flags.
- **DebugSeed seeds Bonnie WITH a story by default** — so testing the "no dog" new-user path requires either resetting state in the same process (without relaunching) or launching with `-DebugSkipStorySeed YES`. Documented for future testing.

**Out of scope for this session (deliberately deferred — listed in `decisions.md` 2026-05-10):**

- Day-0 HealthKit history backfill (depends on HealthKitService, held to end-of-build)
- Cliffhanger prompt tightening (separate prompt-tightening pass on the Vercel proxy)
- Deferred-field in-app prompts (postcode/DOB/weight/etc. surfaced on Home/Profile)
- App Store + landing positioning copy update
- Share cards on book completion
- Trot Pro paid tier
- Rebuilding the "add another dog" path — still uses the existing `AddDogView` from Profile

**Files changed this session:**

- New: `Features/Onboarding/OnboardingFlowView.swift`, `OnboardingProfileStep.swift`, `OnboardingPermissionsStep.swift`, `TrotTests/OnboardingFlowResumeTests.swift`
- Modified: `App/RootView.swift`, `App/DebugDeepLinks.swift`, `Core/Services/UserPreferences.swift`, `Features/Onboarding/OnboardingGateView.swift`, `TrotTests/AddDogFormStateTests.swift`

**Verification done:**

- Full test suite green (194 unit + 4 UI, serial)
- Visual: fresh-state path lands on `OnboardingProfileStep` with "Show us your dog. Three things and the book starts." copy
- Visual: existing-user (DebugSeed Bonnie with story) bypasses onboarding cleanly to Home — migration via routing, no flash

**Verification deferred (covered by unit tests, not visually walked):**

- Genre + scene pickers inside `OnboardingFlowView` — same components as Story tab, already exercised
- Prologue display step — uses `StoryPageReader` with `.awaitingWalk` interaction, same component as Story tab
- Permissions step iOS dialog — requires real interaction
- Resume cases (dog without story → `.genre`, dog with story but flag false → `.permissions`) — covered by `OnboardingFlowResumeTests`

**Not committed yet** — pending Corey's review of the working tree (9 files, 4 new + 5 modified).

**Next session pickup:**

- **Walk through the new onboarding end-to-end on the simulator.** Time-to-prologue measurement, copy sanity-check, scene-picker UX, generation-progress feel, prologue length on iPhone 17 Pro screen, permissions step dialog timing.
- **The deferred-field in-app prompts.** Postcode/DOB/weight need surfaces on Home/Profile that contextualise their value ("Add Bonnie's date of birth so the story can know her age"). Probably four small tiles wrapped in a discoverable section. Could be a single ~half-day chunk.
- **Cliffhanger prompt tightening** on the Vercel proxy. The new onboarding makes the prologue's quality more load-bearing — it's the headline payoff. The proxy's `story_page` system prompt was tightened in a previous session but a re-audit against the "hard cliffhanger every page" rule from `spec.md` is worth doing before the next round of pre-launch validation.
- **Day-0 HealthKit history backfill** is the next big move — but it's blocked on HealthKitService which is held to end-of-build per `decisions.md`. The "Bonnie has walked with you 84 hours over the past year" copy can be drafted ahead, but the data hookup waits.

**Blockers / open:** none. Build clean, all tests passing, both routing paths verified visually.

---

## 2026-05-09 / 2026-05-10 — Refactor + retention bundle: scene-setter, course-corrected onboarding, book length, finale, archive

Two-day session. The Story tab journey went from "loosely shaped" to "structurally complete with a beginning, middle, and end". Plus a handful of refactor items closed: deprecated journey fields dropped, chapter-seen state moved off install-scoped UserDefaults onto SwiftData, notification permission re-wired to a contextual moment, and a clean onboarding-vs-discovery course correction.

**Done — Story journey overhaul:**

- **Scene-setter step before page 1.** New `StoryGenrePicker` → `StoryScenePicker` flow. Each genre exposes 4 hand-picked scenes (e.g. murder mystery: village fête / seaside hotel / old library / WI meeting). The pick persists on `Story.sceneRaw` and ships into the proxy's `scenePrompt` context key so page 1 visibly opens in the chosen world. Solves the "prologue feels random — the user contributed nothing but a genre" problem. Real artwork is a v1.x swap; SF Symbols today.
- **Story-tab intro replaces forced onboarding screen.** First-pass attempt was a forced `OnboardingPermissionsView` between AddDog and Home. User pushed back hard ("came up while I was logging in", "didn't see why this would make me press allow notifications"). Reverted that screen entirely and added `StoryIntroView` as the noStory branch on the Story tab — fires the first time the user visits Story, three plain bullets explain Story mode, "Begin" flips `UserPreferences.storyIntroSeen` and the genre picker takes over. Notification permission removed from the bundle.
- **Book length: 5 chapters / 25 pages per book.** `StoryGenre.chaptersPerBook` is per-genre (locked at 5 across the board for v1, future-proof for varying pacing). When chapter 5 closes, the proxy switches to a finale variant of `story_chapter_close` and returns a book title + book-closing line on top of the chapter wrap. The Story is moved from `dog.story` (active) to `dog.completedStories` (archive); `dog.story` is now nil and the genre picker re-appears.
- **`StoryFinaleOverlay`.** Full-screen genre-saturated takeover. Book title in display type, stats line ("5 chapters · 25 pages · N walks"), closing line in italic, two CTAs: "Read it all" (opens StoryFullPageReader scoped to that book's first page) and "Start a new story" (dismiss → router lands on noStory → genre picker).
- **`CompletedBooksShelf`.** Horizontal scroll under the genre picker once any book is finished. One card per book, themed in that genre's `bookSurface` / `bookBorder` / `bookProseColor`. Tap → opens the book in the existing reader.
- **Debug Tools card extension.** Profile → Settings → Debug Tools gains a "Debug · story" section: active-story row (genre · scene · chapter index · page count), Swap genre / Swap scene buttons, Force-finish (templated copy, no LLM), Seed completed book (synthesises a 5×5 placeholder book directly into the archive). Symmetric `trot://debug/story/finish` and `trot://debug/story/seed-completed-book?genre=fantasy` deep links — UI and deep-links call into the same `StoryService.debug...` helpers in `StoryService+Debug.swift`.

**Done — refactor.md items closed:**

- **Item 1 — drop deprecated `Dog.activeRouteID` / `routeProgressMinutes` / `completedRouteIDs`.** Schema bumped 1.0.0 → 1.1.0; SwiftData lightweight migration on the existing simulator store dropped the columns, preserved every other field (verified via sqlite). Locked in `decisions.md` as "Pre-launch schema cleanup: destructive in-place V1 edit" — applied two more times this session (sceneRaw add, chapter-seen field, book-length fields).
- **Item 3 — chapter seen-state moves to SwiftData.** `StoryChapter.seenAt: Date?` replaces the install-scoped UserDefaults key (`trot.story.chapterSeen.<persistentModelID.hashValue>` was breaking on every reinstall because the hash changed). Schema 1.1.0 → 1.2.0 → 1.3.0 (scene field then chapter-seen field). One-shot legacy migrator promotes any pre-existing UserDefaults flags onto the new field on first launch.
- **Item 5 — notification permission alert on every reinstall.** Removed the launch-time `requestPermission()` call from `RootView.task`. After the failed forced-onboarding-screen detour, ended up wiring the ask **contextually** to the walk-window reminder toggle (`WalkWindowTile.toggleReminder`). Tap "Remind me" while undetermined → iOS prompt → if granted, schedule and capsule flips to "Reminder set"; if denied, capsule stays at "Remind me" and an inline "Notifications are off · Open Settings" hint appears (deep-links to iOS Settings via `UIApplication.openSettingsURLString`). Once granted, `NotificationService.reschedule` picks up the other three scheduled types (nudge, milestone, recap, morning-window) automatically — permission is app-wide, not per-type.
- **Item 10 — onboarding doesn't mention Story mode.** Closed via `StoryIntroView` on the Story tab (not via onboarding — see course correct above).

**Done — bug fixes:**

- **Weather background didn't refresh on postcode add.** `WeatherMoodLayer.load()` reads `UserPreferences.postcode` only when its `refreshTrigger` bumps; that only happens on `.onAppear`. The postcode-edit sheet is owned by `WalkWindowTile` / `DogSettingsSheet`, so dismissing it never fires `onAppear` on the mood layer. Fixed by posting `Notification.Name.trotPostcodeChanged` from `UserPreferences.postcode.set` and observing it in the layer with `.onReceive`. Pattern mirrors the existing `trotRecapTapped` notification.
- **Seeded debug dog renamed Luna → Bonnie.** Per user request. Brand docs / test fixtures / SwiftUI Preview placeholders kept Luna deliberately — Luna is still the canonical brand example dog; Bonnie is the dog you meet on a fresh debug install. The full Christie-pastiche book chapters in DebugSeed got renamed end-to-end.

**Done — gotchas hit and resolved:**

- **Bundling notification ask with Story-mode discovery flopped.** First attempt at refactor item 5 + 10 combined them onto one forced screen between AddDog and Home. User flagged: looked like sign-in, didn't motivate the notification ask, didn't explain Story mode clearly. Lesson: don't bundle disparate concerns. Notifications need a contextual trigger (an explicit user-initiated request); discovery belongs on the surface being discovered. Saved as a memory rule.
- **SwiftData Mirror tripwire pattern: presence vs absence.** The DogModelTests pattern checks for ABSENCE of removed property names (`!names.contains("activeRouteID")`) — works regardless of SwiftData's `_` prefix. New StoryModelTests adapted to check PRESENCE — needed `_sceneRaw` / `_genreRaw` not `sceneRaw` / `genreRaw`. Tripped the test on first run; fixed.
- **Course correct as a discipline.** `cedbae2` shipped the wrong forced screen; `5da822c` reverted and replaced with the right design. Kept both commits in history rather than rebasing — useful trail of the course correct, and the user could see the journey not just the destination.

**Schema migrations this session (all lightweight, all in-place V1):**

- 1.0.0 → 1.1.0 — drop deprecated `Dog.activeRoute*` fields
- 1.1.0 → 1.2.0 — `Story.sceneRaw`
- 1.2.0 → 1.3.0 — `StoryChapter.seenAt`
- 1.3.0 → 1.4.0 — `Story.finishedAt` / `title` / `closingLine` + `Dog.completedStories`

Each verified by sqlite inspection of `default.store` post-migration: new columns present, existing rows preserved, no fatalError on launch.

**Committed this session (15 commits, all on `main`, all pushed to `origin`):**

- `a8b38e3` — Drop deprecated Dog journey fields (route/progress/completed)
- `e845c36` — DebugSeed: rename seeded dog Luna → Bonnie
- `e7afe7b` — Story proxy: scene-aware prologue prompt
- `a3a8bd8` — Story scene-setter: one-tap world pick before page 1
- `9b146c5` — Weather: refresh mood layer when postcode changes mid-session
- `67bcd0e` — Story: chapter seen-state moves to SwiftData
- `cedbae2` — Onboarding: permissions step + Story-mode discovery (wrong design)
- `5da822c` — Story intro replaces forced onboarding permissions step (course correct)
- `242b072` — Story intro: drop em dashes from bullet copy
- `20decf3` — Story proxy: finale-aware chapter close
- `bd9b317` — Story: book length, finale, and archived books
- `13ed9af` — Debug Tools: story controls + deep links for finale + archive
- `021bdcc` — Notifications: contextual permission ask on walk-window reminder
- (+ 2 doc/admin commits via this handoff pass)

**Test count: 190 unit + 4 UI passing, all serial.** Net additions across the session: scene tests (6), chapter tests (3), finale tests (8). No flakes; full suite under 90 seconds.

**Refactor.md state:**

- Items 1, 3, 5, 10: ✅ shipped
- Item 4 (StoryService test coverage): partially closed by `StoryServiceFinaleTests`; full `currentState` matrix still open
- Items 2, 6, 7, 8, 9, 11–14: open. None block anything user-visible. Best done as a single "spring clean" pass once features are locked.

**Next session — pickup options:**

- **Use the app for a few days.** Honest recommendation. The journey loop is now coherent end-to-end. Living with it will surface real priorities better than an imagined list. Bonnie has a story → walk her → page lands → hit milestones → close chapter → finish book → start a new genre. That whole cycle hasn't been actually walked through yet by a real human (only deep-link-driven simulations).
- **Brand voice audit on the new Story-mode surfaces** (refactor item 9). Lots of new copy this session — finale overlay, intro view, completed-books shelf, debug card, scene prompts. ~30 minute pass against `brand.md`'s Never list. Already caught and fixed em dashes once on the intro; might be more lurking.
- **Visual polish for TestFlight readiness.** App icon is still placeholder, Bonnie's photo placeholder is the paw-print. Bookshelf cards look noticeably barer without a dog photo. A couple of hours of mostly visual work.
- **Manual recap entry on Home** (small discoverability — Sunday auto-trigger works, manual entry from Insights tab works, but Home has no surface).
- **A general notifications settings toggle in the Profile sheet.** Spec says "all notifications individually toggleable" but those toggles aren't built; the contextual ask is the only on-ramp today.

**End-of-build chunks (deliberately held until last):**

Sign in with Apple, CloudKit production turn-on, HealthKitService + walk detection algorithm, Apple Developer Program $99 spend. Trigger per `decisions.md` is "I want to walk around the block and confirm iOS wakes my app in the background." Not yet.

**Blockers / open:** none. Build clean, all tests passing, Vercel proxy live (verified post-deploy via curl), schema migrations all verified end-to-end.

---

## 2026-05-08 — Story tab rebuild end-to-end + journey rip-out + handoff prep

A long single session. The Story tab went from "loosely scaffolded" to "fully functional with milestone gating, atmosphere, swipe reader, error/loading banners, page-cap anti-grind, author-channelling LLM prompts, and live deploy of the proxy." Mid-session the Journey/route system (which was the previous progression spine) got fully ripped out and replaced by story-mode milestones. End of session is a deliberate handoff to a fresh chat for refactor work — see `docs/refactor.md` (new this session).

**Done this session — Story tab core:**

- **Per-genre book theming** (`GenreOverlay`, `GenrePageHeader`, `GenreProseView`, `GenreBookCard`). Six visual languages: noir film grain + EXHIBIT stamp + monospaced typewriter prose + magnifying-glass corner ornament; horror vignette + handwritten header + scratched underline; fantasy parchment foxing + ornate diamond divider + drop cap; sci-fi scan-lines + bracketed file slug + terminal `> ` prefix + blinking cursor; cosy warm afternoon-glow + italic serif + leaf ornament + drop cap; adventure kraft fibre cross-hatch + DAY/LEG stamp + compass ornament. Each card carries the genre's surface, border, corner ornament, and genre-tinted shadow.
- **`StoryFullPageReader` with cross-chapter swipe** — TabView `.page` style, every page in the story is one swipe stop, opens at any page (from the Read-the-File pill OR from a tap on a chapter-spine row). Cross-chapter navigation enabled.
- **`ChapterSpine` row tappability** — `.past` and `.current` rows wrap in a Button that opens `StoryFullPageReader` at that page; future rows stay non-interactive.
- **Calm picker with live atmosphere preview.** Picker cards are uniform cream — same surface, same hairline border, one accent-tinted icon per card. The atmosphere layer behind the picker swaps to the highlighted genre on each card tap (selected state lifted from `StoryGenrePicker` to `StoryView` via `@Binding`). "Begin <Genre>" CTA at the bottom commits.
- **`StoryGenerationProgress` writing-state view** — appears immediately on Begin tap so the picker doesn't sit visually frozen during the LLM round-trip; genre-flavoured headline + atmosphere already painting.
- **Author-channelling per genre.** Each `StoryGenre.toneInstruction` gained a *"Channel <Author>'s voice: <one-line style note>. Don't mimic, don't pastiche — channel."* cue. Christie / King / Martin / Herbert (Dune) / Osman / Macfarlane.
- **Milestone-gated decisions + 2-page-per-day cap.** `StoryService.currentState` extended with `PageLock` enum (`.needMoreMinutes`, `.dailyCapHit`) and `Milestone` (.halfTarget, .fullTarget). Page 1 unlocks at 50% of dog's daily target; page 2 at 100%; max 2 pages per local day regardless of additional walks. Locked decisions render as dimmed buttons with a one-line "Walk Luna 18 more minutes…" explainer + padlock glyph; daily cap shows a calm "Two pages today" footer.
- **Generation feedback owned by `StoryView`.** `isGeneratingPage` lifted from the reader so it survives view re-renders during the LLM call and reliably resets on success OR failure. `pageGenerationError: String?` surfaces a `GenerationErrorBanner` with **Try again** that re-fires the same `(choice, text, photo)` payload via `lastPickArgs`. Inline `GenerationStatusBanner` shows genre-flavoured *"Inking the next page…"* / *"Pouring the next page…"* etc. while waiting.
- **Page length recalibrated TWICE.** Initial bump 40-70 → 220-280 words (too long, spilled past iPhone screen). Final 140-180 words / 2-3 paragraphs / max_tokens 800. Card preview clamps at `lineLimit(4)` with tail truncation; full prose only in the swipe reader. Six fallback prologues retightened from ~250 → ~160 words each in author voice. Same recalibration applied to `story_chapter_close.prologueProse` (max_tokens 1600 → 1000).
- **`DebugSeed` chapter 1 + 2 pages rewritten** to ~160 words / 2-3 paragraphs in Christie voice. Chapter 1 pages backdated 8-12 days so milestone-gating doesn't see them as "today" pages and trigger the daily cap. Same plot beats so the existing `userChoice` trail is preserved.

**Done this session — Journey infrastructure rip-out:**

The old Journey/Route system (routes, landmarks, route progress, chapter memory) was the v1 progression spine. Story-mode replaces it. After a meticulous audit, the following were deleted as 100% dead:

- `JourneyView.swift` — orphan, no callers since the tab was renamed to Story
- `ChapterMemoryService.swift` — only consumer was JourneyView
- `DistanceTranslator.swift` — only consumer was JourneyView
- `LandmarkRevealView.swift` — only consumer was ExpeditionView's mid-walk landmark toast (replaced by `StoryMilestoneToastView`)
- `JourneyService.swift` + `JourneyService+Routes.swift` — last consumers (AppState, LogWalkSheet, ExpeditionView, WalkCompleteOverlay, DebugSeed) all rewired for story
- `Routes.json` + `UKLandmarks.json` — data files for the deleted services
- `JourneyServiceTests.swift` — tests die with the service
- `LLMService.chapterMemory(...)` static func + `Kind.chapterMemory` case + matching `chapter_memory` proxy case

**Left for refactor (SwiftData migration):** `Dog.activeRouteID` / `routeProgressMinutes` / `completedRouteIDs` are persisted fields on the SwiftData model. Removing persisted fields is a schema migration with CloudKit-sync risk; they remain in the model with a DEPRECATED comment block and are listed as item 1 in `docs/refactor.md`.

**Done this session — Walk-complete overlay rebuilt for story mode:**

- `PendingWalkComplete` struct rewritten. Old shape: `routeName`, `routeTotalMinutes`, `landmarksCrossed`, `routeCompleted`, `nextLandmarkName`, `oldProgressMinutes`, `newProgressMinutes`. New shape: `oldMinutesToday`, `newMinutesToday`, `targetMinutes`, `pagesAlreadyToday`. Computed: `halfTargetMinutes`, `oldFraction`, `newFraction`, `crossedHalfTarget`, `crossedFullTarget`, `progressCaption`.
- `WalkCompleteOverlay` renders `storyProgressBar` (today's minutes vs target with notches at 50% and 100%) and `pageUnlockStamp` (PAGE 1 / PAGE 2 UNLOCKED, fired only when this walk crossed a milestone). `progressCaption` strips the bar with one-liner: *"X min to today's first page"*, *"X min to today's second page"*, or *"Two pages today. The book waits for tomorrow."*
- `LLMService.walkCompleteLine` simplified: `pageUnlocked: String?` parameter replaces the old `landmarksHit` / `routeName` / `nextLandmarkName` trio. Proxy's `walk_complete` case takes the new hint.

**Done this session — ExpeditionView rewired for story:**

- "X min to ???" line gone. Replaced with `storyProgress` block that shows the current minutes-walked-today vs daily target, captioned *"X min to today's first/second page"* or *"Two pages today. Walk for the love of it."* and a bar that anchors against the next milestone.
- Mid-walk landmark toasts (`visibleLandmark` + `LandmarkRevealView`) replaced with `visibleMilestone` (`StoryMilestoneToast` enum: `.halfTarget` → "PAGE 1 UNLOCKED", `.fullTarget` → "PAGE 2 UNLOCKED") + `StoryMilestoneToastView`. Toast fires once per session per milestone via `firedMilestones: Set<StoryMilestoneToast>`.
- `ExpeditionView.finishWalk()` story-mode payload + enqueue-before-dismiss (mirror of last turn's `LogWalkSheet` fix). The dismiss + 350ms sleep + enqueue dead-air is gone — overlay is queued the moment Save fires, sheet animation reveals it from underneath.
- `ExpeditionState.firedLandmarkIDs` / `markLandmarkFired` deleted (logic moved into the view's `firedMilestones`).

**Done this session — gotchas hit and resolved:**

- **macOS Tahoe codesign provenance issue.** Sticky `com.apple.provenance` xattr re-applies after `xattr -cr`, blocking simulator codesign. Workaround: `CODE_SIGNING_ALLOWED=NO` for sim builds. Saved as memory: `feedback_codesign_provenance_workaround.md`.
- **Vercel deploy gap.** Story-related kinds (`story_page`, `story_chapter_close`) added to `ALLOWED_KINDS` in commit `456bcfb` but Vercel never redeployed since. Every path-pick was bouncing with HTTP 400 `invalid_kind`. Diagnosed by hitting the proxy with curl. Fixed by pushing `09e5697` (which also carries the page-length recalibration), Vercel auto-deployed, verified live with a real `story_page` curl returning Sonnet 4.6 prose.
- **Notification permission alert was looping on fresh installs.** Pre-firing the `firstWalk` milestone in `DebugSeed` triggered `UNUserNotificationCenter.requestAuthorization` on every reinstall. Visible in screenshots as a black alert covering the centre of the screen. Eventually auto-grants and stops; not blocking, just noisy. Added `-DebugSkipNotifications YES` launch arg.
- **Chapter-close overlay re-firing on fresh installs.** UserDefaults seen-key keyed by `chapter.persistentModelID.hashValue` — the hash changes each install, so the overlay sees the chapter as unseen and re-fires. Listed in refactor.md.
- **GitHub OAuth token leaked in transcript.** While diagnosing a hung `git push`, ran `git credential fill` to "verify creds were stored." That command's purpose is to print the secret to stdout, which it did. The token was rotated by the user via `gh auth logout` + `gh auth login`. Added a `Never surface stored secrets to stdout` rule to `CLAUDE.md` Security section + memory entry. Concrete bans: `git credential fill`, `cat .env`, `security find-generic-password -w`, etc. + the metadata-only debug pattern for hung auth-requiring commands.

**Committed this session:**

- `f342f39` — Story tab: per-genre book theming, swipe reader, milestone gating
- `09e5697` — Story proxy: real-page length + author-channelling tone (deployed)
- (about to commit) — Story-mode walk-complete overlay + ExpeditionView rewire + journey rip-out

Plus 7 commits from earlier in the same conversation (pre-Story-mode era, but same chat session) — Today/Walk-window/Today-reorg/Journey-rebuild/etc.

**Next session — refactor focus:**

Read `docs/refactor.md` (created this session, prioritised backlog) and `docs/decisions.md` (10 architectural decisions appended this session). Item 1 is the SwiftData migration to drop the now-orphaned `Dog.activeRouteID` / `routeProgressMinutes` / `completedRouteIDs` fields cleanly.

**Blockers / open:** none. Build clean (zero errors, zero warnings excluding the harmless AppIntents-not-needed system note). Vercel proxy live. Story tab fully functional end-to-end.

---

## 2026-05-06 (late evening) — Recap loop, streak tiers, breed table to 60, picker UX

**Done this session:**
- **Weekly recap surface, manual + auto.** `RecapService` is a pure-function namespace returning a `WeeklyRecap` from a dog's walks: trailing 7 days inclusive of today (this week), the 7 days before that (last week), per-day percent-of-needs-met capped at 100% (consistency-weighted, not volume), comparison delta, current streak from `StreakService`, and a featured insight (preferring the part-of-day pattern over the lifetime summary). `RecapView` is a brand-celebration sheet with the dog photo as the hero, stats row, comparison phrasing (up/down/equal), streak status, and the featured insight. Manual entry from the Insights tab via a "This week's recap" button. Auto-show on Sunday evenings: per-dog `Dog.lastRecapSeenWeekStart` (Sunday-startOfDay key) gates the auto-trigger; `RootView` checks on .task and scenePhase = active and presents the sheet via `AppState.pendingRecapDogID`. Milestone celebrations take precedence — auto-show waits if a celebration is queued.
- **Streak-tier celebrations (7/14/30).** Three new `MilestoneCode` cases (`streak7Days`, `streak14Days`, `streak30Days`) extend the first-week ladder with the long-term streak milestones. Once-per-dog. The 7/14/30 push notifications in `NotificationDecisions` keep firing every time the streak hits those tiers; the in-app celebrations here are the first-time emotional moment.
- **Insights catalog growth.** Three additive observations in `InsightsService`: weekly trend (≥7 days of data, last week non-empty), weekday/weekend split (≥14 days, ≥30% per-day lift), favorite hour (≥7 walks, ≥40% concentration). Thresholds deliberately conservative — a thin lead from sparse data is noise, not insight.
- **Breed table expanded from 30 to 60 entries.** Subagent-researched additions covering UK pet population gaps: designer crosses (Goldendoodle, Labradoodle, Maltipoo, Cavachon, Sprocker), companions (Maltese, Pomeranian, Papillon), poodles (all three sizes), terriers (Bull, Cairn, Patterdale, Lakeland, Airedale), sighthounds (Saluki, Italian Greyhound) with sprint-not-marathon cautions, working dogs (Australian Shepherd, Belgian Malinois, GSP, Husky), giants (Newfoundland, Bernese Mountain Dog, Great Dane) with slow-growth and bloat cautions, plus Dalmatian, Flat-Coated Retriever, Welsh Springer Spaniel, Old English Sheepdog, Miniature Schnauzer. Same `last_reviewed: needs verification` flag — pre-launch verification pass covers all 60. Both JSON copies (iOS + web) regenerated and verified byte-identical.
- **Breed picker on AddDogView + honest unknown-breed messaging.** `BreedPickerView` is a searchable sheet listing all 60 canonical names with a "Type a custom name" path at the top for unlisted breeds and mixes. Selecting a breed sets the form value; preserves the existing value when re-entered. `ExerciseTargetService.templatedRationale` now branches on whether the breed matched: known breed gets the confident "Beagle adult. Around 75 minutes a day reflects standard breed needs." line; unknown breed gets the honest "Around 70 minutes a day for a medium adult dog. We don't have this breed listed yet, so these numbers come from general size-based guidance." Per-stage codas (puppy growth-plates, senior joints) still apply on both branches.

**Test methodology change mid-session.** User pushed back on running the full 100+ test suite after every change. Switched to: targeted `-only-testing:TrotTests/XServiceTests` while iterating, single full-suite run pre-commit. Saved as memory rule (`feedback_targeted_tests_during_iteration.md`). Discipline applied to remaining chunks — material drop in compute and token use without losing safety.

**LLM scope decision.** Decided to skip wiring iOS `LLMService` for v1. Richer hardcoded data (breed table + medical conditions) is a stronger personalisation lever than LLM prose for v1. LLM-personalised milestone copy / walk feedback / weekly-recap narrative is reserved for v1.1+. The Vercel Edge Function stays code-only. Saved as project memory (`project_llm_deferred_to_v1_1.md`).

**Test count: 118 passing**, all serial: 8 AddDogFormState, 7 LogWalkFormState, 13 StreakService, 12 NotificationDecisions, 4 AppState, 21 ExerciseTargetService (including 3 new for the rationale branch + knownBreedNames), 16 MilestoneService (with parameterised streak-tier matrix), 19 InsightsService (with 10 new for trend / split / favorite hour), 20 RecapService (with parameterised auto-show window matrix).

**Committed this session:**
- `470ffc6` — Add weekly recap surface (manual entry from Insights tab)
- `87fafce` — Auto-show weekly recap on Sunday evenings
- `59f6b06` — Extend MilestoneService with streak-tier celebrations (7/14/30)
- `9ae3c4e` — Grow Insights catalog: weekly trend, weekday/weekend, favorite hour
- `8102fc5` — Expand breed table from 30 to 60 entries
- `17ec6d0` — Breed picker + honest unknown-breed rationale
- All on `main`, pushed to `ElimDroflem/trot`.

**Next session pickup:**
- **Manual recap entry on Home.** Currently the recap is only reachable from the Insights tab or via the Sunday-evening auto-trigger. A small recap tile or "view this week" button on Home raises discoverability without crowding the Today surface.
- **App icon production version + Luna placeholder photo.** Both flagged earlier in the log as deferred. The current `app-icon-1024.png` is a Claude Design placeholder; the seeded Luna has no photo so Home renders the empty paw-print placeholder. Neither blocks shipping.
- **BreedData drift check script.** Small build-time / CI script that diffs `ios/Trot/Trot/Resources/BreedData.json` against `web/api/breed-data.json` to catch divergence. Currently maintained manually (subagent regenerated both this session). Low urgency; small chunk.
- **Notification deep-link to recap.** The Sunday 19:00 `trot.recap` notification fires but tapping it just opens the app to wherever the user last was. Wiring the notification's userInfo to set `AppState.pendingRecapDogID` on tap completes the loop. Small chunk; iOS notification-handler plumbing.
- **Mixed-breed UX (v1.1 candidate).** Two-breed weighted average for `breedPrimary` + secondary. Currently single-breed only.
- **End-of-build chunks (held intentionally):** Sign in with Apple, CloudKit turn-on, HealthKitService + walk detection algorithm, Apple Developer Program $99 spend.

**Open from this session that may surface later:**
- Auto-show recap requires the user to be on the selected dog at the moment of trigger. Multi-dog households with active dog set to Dog A, but Dog B's last-seen-week not updated, will see Dog A's recap on first open and Dog B's on subsequent open (after switching). Acceptable but worth noting.
- The current breed-rationale branch unconditionally treats free-text input as a potential breed lookup. After the picker change, free-text only happens on "custom name" path — but rationale logic doesn't distinguish "user explicitly chose custom" from "user typed something we don't recognise." Both end up with the disclosure copy, which is correct anyway.
- No notification handler is wired yet for the recap deep-link case. iOS notification taps currently just open the app.
- All 60 breed entries still flagged `needs verification`. Pre-launch task per `decisions.md`.

---

## 2026-05-06 (evening) — Front-load delight: first-week loop shipped

**Done this session:**
- **Vercel Edge Function for the LLM proxy** at `web/api/exercise-plan.ts`. TypeScript, Anthropic Haiku 4.5, 8s timeout, defensive clamp if the model picks outside the safe range, anonymous-install-token validation. The handler computes the safe range LOCALLY (mirrors `ExerciseTargetService.swift`) before asking the LLM to pick within it — the LLM never invents numbers. `web/api/breed-data.json` is a copy of the iOS bundle's `BreedData.json`; both derive from `docs/breed-table.md`. TODO recorded for a build-time drift check. Code-only, no deploy, no API key set, no iOS LLMService yet. Typechecks cleanly.
- **Front-load-delight scope locked into docs.** Pressure-tested whether the v1 daily loops give a new user enough reason to come back in week 1 (answer: no — every loop pays off in week 4+). Locked the design principle into `spec.md` ("front-load delight, back-load discipline") and `decisions.md`. Added a numbered "0. First-week loop" section to spec.md with a six-beat named-milestone ladder, an Insights-tab "learning Luna's patterns" anticipation hook, and an evergreen breed-rationale Home tile. Recorded the rejected Finch-style virtual-pet alternative in decisions.md so the question doesn't get re-litigated.
- **MilestoneService + first-week celebration overlay.** Six beats — firstWalk, firstHalfTargetDay, firstFullTargetDay, first100LifetimeMinutes, first3DayStreak, firstWeek — fired once per dog, stored as raw values on `Dog.firedMilestones: [String]`. Service is pure-function in the same shape as `StreakService`. `LogWalkSheet.save()` and `RootView.task`/`scenePhase = active` are the producer points; `AppState.pendingCelebrations` is the FIFO queue; `CelebrationOverlay` renders Bricolage Grotesque on the secondary brand surface with the brand celebration spring and a Reduce Motion fallback. Tap to dismiss.
- **Evergreen breed-rationale Home tile.** `ExerciseTargetService.templatedRationale(...)` produces a one-line rationale from the same breed/lifestage/condition logic as the target. AddDogFormState writes it to `dog.llmRationale` on save and edit. Home gains a small `RationaleCard` between the progress card and the walks section, on `brandSecondaryTint` with a sparkle icon. The previous inline concatenation ("X of Y minutes done. Beagles do best with...") is removed — the rationale now has its own surface, daily.
- **InsightsService + InsightsView.** Replaces the placeholder Insights tab. Pure-function service returning an `InsightsState` with a `LearningProgress` (days-of-data over 7) plus a list of computable observations. Day 1 ships with two observation shapes: lifetime walks summary (≥1 walk, singular/plural copy) and part-of-day pattern (≥3 walks AND one bucket ≥50%, "Most walks happen in the morning"). View shows the learning card on top while it applies, then either the observation cards or an anticipating empty state ("Your first walk unlocks the first observation."). Catalog is structured to grow additively — weekly trend, weekday/weekend, favorite hour are obvious next observations.
- **Schema bump aside.** Tried bumping V1 → V2 with a lightweight migration stage to add `firedMilestones`. SwiftData rejected with "Duplicate version checksums detected" because both versions reference the same live model classes. Properly handling that requires snapshotting V1's Dog as a separate historical class — too much ceremony pre-launch with no users. Added the property to V1 directly; we'll exercise real V2 the first time we have a schema change worth preserving old data through.

**Test count: 85 passing, all serial:** 8 AddDogFormState, 7 LogWalkFormState, 13 StreakService, 12 NotificationDecisions, 4 AppState, 18 ExerciseTargetService (12 target + 6 rationale), 15 MilestoneService, 9 InsightsService.

**Committed this session:**
- `ed26f24` — Add Vercel Edge Function for LLM exercise-plan proxy (no deploy yet)
- `73eaff5` — Bake "front-load delight" first-week loop into v1 scope
- `ea569f0` — Add MilestoneService + first-week celebration overlay
- `f455986` — Add evergreen breed-rationale Home tile (templated until LLM ships)
- `c9459a1` — Add InsightsService + InsightsView with day-1 learning state
- All on `main`, pushed to `ElimDroflem/trot`.

**Next session pickup:**
- **Weekly recap UI.** The `trot.recap` notification already fires Sunday 19:00. Tapping it should land the user on a recap surface that doesn't yet exist. Per spec.md → "6. Weekly recap as a fixed ritual": total minutes, percentage of needs met, comparison to last week, streak status, one personalised insight, a featured dog photo. Pure local computation over walk history; no LLM needed for v1.
- **Streak milestone in-app celebration.** Currently 7/14/30-day streak milestones fire as push notifications but there's no in-app moment when the user opens the app at that streak. Could extend MilestoneService to also produce streak-milestone celebrations (firstWeek already covers day 7). Or surface them in the Today tab as a small pulse. Smaller chunk than weekly recap.
- **iOS LLMService.** Wires the Vercel proxy into AddDogView's save flow to overlay LLM personalisation on top of `ExerciseTargetService`. Has a spending decision attached — depends on whether we deploy the proxy and pay for Anthropic API access during pre-launch development.
- **BreedData drift check.** Small CI/build-time script that diffs the iOS and web copies of BreedData.json. Nice cleanliness move, no urgency.

**Open from this session that may surface later:**
- DEBUG-seeded Luna's `llmRationale` was the old hardcoded "Beagles do best with a second walk before sundown." After this session, anyone editing Luna will have it overwritten by the templated form. Existing seeded Luna without an edit still shows the old rationale until an edit happens. Acceptable in DEBUG.
- The Insights view doesn't yet reflect AppState's selected dog if it changes while the view is on screen. The `@Query` re-evaluates and `selectedDog` is a computed property over it, so SwiftUI should update on dog switch. Worth eyeballing once on a real device.
- `firedMilestones` is `[String]` for CloudKit primitive-storage discipline. The service maps to/from `MilestoneCode`. Migrating to `[MilestoneCode]` directly is a v1.1 cleanup if Apple's CloudKit support for raw-representable arrays is solid by then.
- Vercel Edge Function bundles a copy of `BreedData.json`. If the iOS file changes and the web copy doesn't (or vice versa), they drift. TODO recorded in the file header. Pre-launch checkbox.

---

## 2026-05-06 — Multi-dog UX + breed-table-driven targets

**Done this session:**
- **Multi-dog UX.** New `AppState` (`@Observable` class) holds the selected `PersistentIdentifier` and is injected via `.environment(appState)`. Home, Activity, and Profile all read the selected dog from AppState, so switching propagates everywhere. Header gained a dropdown switcher menu (with checkmarks + "Add another dog" entry). DogProfileView gained an "Add another dog" button presenting AddDogView as a sheet. AddDogView gained `showsCancelButton: Bool = false` for the sheet case and now writes the saved dog into AppState on new-dog flows. Archive clears `selectedDogID` so AppState falls back to the next active dog (or routes to AddDogView if none). 4 new `AppStateTests`.
- **ExerciseTargetService + BreedData.json.** Subagent extracted 30 breed YAML blocks from `docs/breed-table.md` into `ios/Trot/Trot/Resources/BreedData.json` (canonical schema: breed, aliases, size, defaultIntensity, lifeStages, plus size-fallback table, senior-age-by-size thresholds, and three condition adjustments). New `ExerciseTargetService` is a pure-function namespace that picks a daily target from breed + DOB + weight + health flags. Strategy: breed lookup by name or alias (case- and punctuation-insensitive), size fallback for unknown breeds (weight bins), life-stage selection (puppy <1yr, senior at size-specific threshold), conservative-low for puppy/senior + midpoint for adult per breed-table rules, then largest-single-reduction for combined health conditions (no multiplicative stacking — too aggressive), rounded to nearest 5 min. AddDogFormState now writes this on both new-dog save and edit, replacing the hardcoded `60`. 12 new `ExerciseTargetServiceTests`. Existing AddDogFormState tests updated to assert wire-up via `state.computedDailyTargetMinutes` rather than hardcoded numbers — JSON values can evolve without churning these tests.
- **Test count: 55 passing, all serial** (`-parallel-testing-enabled NO`): 8 AddDogFormState, 7 LogWalkFormState, 13 StreakService, 12 NotificationDecisions, 4 AppState, 12 ExerciseTargetService.

**Committed this session:**
- `0c1d9e1` — Add multi-dog selection with switcher menu and add-another-dog flow
- `dca2805` — Add ExerciseTargetService backed by 30-breed BreedData.json
- Both pushed to `ElimDroflem/trot`.

**Next session pickup:**
- **Vercel Edge Function for the LLM proxy.** Write `web/api/exercise-plan.ts` (TypeScript, Anthropic Haiku 4.5, 8s timeout, anonymous-install-token rate limiting). No deploy until Corey decides — code-only, validated locally. iOS LLMService wires later to overlay personalisation on top of ExerciseTargetService.
- After that: missing-screens polish (Insights, weekly recap UI, streak milestone celebration), then end-of-build (paid program, real auth, CloudKit turn-on, HealthKitService + walk detection).

**Open from this session that may surface later:**
- DEBUG-seeded Luna's `dailyTargetMinutes` is still the hardcoded 60 from when she was first inserted. Existing dogs aren't recomputed on relaunch (deliberate — edits trigger recomputation, seed data is DEBUG-only). If the seeded value bothers anyone in dev, edit Luna once via DogProfileView to recompute. Not a real-user concern.
- Recompute-on-edit is unconditional. If a future "manual override target" UI lands, the apply() flow will need to skip recomputation when the user has explicitly overridden. Not a v1 concern.
- Mixed-breed UI still single-breed only — `BreedData.json` has aliases but no two-breed weighted average. v1.1 candidate per `decisions.md`.

---

## 2026-05-05 (late evening) — Daily loop functional end-to-end

**Done this session:**
- **SwiftData schema** built CloudKit-ready under `ios/Trot/Trot/Core/Models/`. Three @Model classes (`Dog`, `Walk`, `WalkWindow`), four raw-value enums in `Enums/ModelEnums.swift`, `TrotSchemaV1` + empty `TrotMigrationPlan` in `Schema/`. Every property has a default or is optional; relationships are optional collections; `.nullify` on the many-to-many `Walk.dogs` relationship; no `@Attribute(.unique)`. The single line that flips local→CloudKit at end of build is marked in `TrotApp.swift`. `DebugSeed` populates Luna + sample 42-min walk on first DEBUG launch when the store is empty. `HomeView` now reads from `@Query` instead of hardcoded constants. Plan-mode session backed this; full plan at `~/.claude/plans/melodic-tickling-blum.md`.
- **Add-a-dog onboarding form** at `Features/Onboarding/AddDogView.swift`. Brand-styled custom form (not native Form) with photo picker, name, breed, DOB, weight, sex, neutered, activity level, three health tickboxes + free-text notes. `AddDogFormState` is a plain struct → unit-testable. `UIImage+Downscale` extension enforces the 1024px / 80% JPEG hard rule from `decisions.md` before bytes hit `dog.photo`. `RootView` extracts the routing: gate → if active dogs empty, AddDogView → Home; else Home directly. After save, the @Query on `RootView` re-evaluates and falls through to Home automatically — no callback plumbing needed.
- **DEBUG reset button on the gate.** Wipes Dog/Walk/WalkWindow with a confirmation dialog so the add-a-dog flow can be tested without rebuilding or app-deleting. `#if DEBUG` only.
- **Manual walk logging sheet** at `Features/WalkLog/LogWalkSheet.swift`. Tap "+" on Home (replaced the old ellipsis) → branded sheet: When (date/time picker), Duration (TextField + 5-min Stepper, range 1–300), Notes (optional). Cancel in toolbar, Save at bottom. `LogWalkFormState` is testable. Headline adapts to the active dog or to multi-dog ("Log a walk with Luna and Bruno."). Source = `.manual`, distance = nil.
- **Walk edit and delete.** Walk rows on Home are tappable → opens `LogWalkSheet` in edit mode (same form, pre-populated, navigation title flips to "Edit walk"). Save mutates in place; destructive Delete button at the bottom with confirmation dialog. `LogWalkFormState` gained `apply(to:)` and `from(walk:)` for the round-trip.
- **`StreakService`** at `Core/Services/StreakService.swift`. Pure function, no side effects. Replaced the hardcoded `14` on Home. Math per `decisions.md`: HIT day = ≥50% target; PARTIAL/MISS burn rest day; rolling 7-day window of the streak run allows ≤1 non-hit; days before `dog.createdAt` aren't penalised. Streak count = HIT days in the run. Initial test run flagged a real bug — my first interpretation checked the trailing 7 *calendar* days at any cursor, which penalised days before the user's actual streak started. Correct rule walks through *streak-run days only*. Rewrote the algorithm to track `nonHitDaysInRun: [Date]` and check window membership against that list. All tests now pass.
- **Code review pass.** Used `/swiftdata-pro` and `/swiftui-pro` skills against the schema and HomeView. Findings actioned: cached `DateFormatter` instances (avoid per-render allocation), 44pt tap targets on header buttons (HIG minimum), accessibility labels on icon-only buttons.
- **Doc updates.** `decisions.md` revised entries for "Apple Developer Program timing" (now: pay only at end-of-build, when ready to verify background wake) and added "Build sequence: passive walk detection ships last" decision. `architecture.md` folder-layout block matches Xcode's actual output (`ios/Trot/Trot.xcodeproj`); walk detection section flags end-of-build sequencing. Captured the Strava framing for manual-first development.
- **26 unit tests** total, all passing: 6 AddDogFormState, 7 LogWalkFormState (including `roundTripFromApply`), 13 StreakService.

**Committed this session:**
- `eba1f0b` — Add iOS skeleton: design system, gate, basic Home (45 files)
- `e8edc4d` — Defer passive walk detection to end of v1 build (decisions.md/architecture.md/log.md)
- `fda4ab8` — Add SwiftData schema (CloudKit-ready, local-only) and wire HomeView to live data
- `69d25fa` — Add the add-a-dog onboarding form
- `8f294e3` — Add DEBUG-only reset button on the gate
- `7c6e80c` — Add manual walk logging sheet
- `69abe4b` — Add StreakService and replace hardcoded 14 with real streak math
- `f7acad9` — Add walk row edit and delete
- All on `main`, pushed to `ElimDroflem/trot`.

**The app now functions end-to-end as a manual daily-walk tracker:**
1. Gate → reset (DEBUG) or continue → AddDog form (or Home if dog exists).
2. AddDog → fill in profile → Save → Home with real data.
3. Home shows dog name, today's progress (live from walks), streak count (live from `StreakService`), today's walk rows.
4. Tap "+" → log a walk → Home updates.
5. Tap a walk row → edit or delete → Home updates.

**Notable workflow note:** The first push of this session timed out with macOS `mmap` / "Stale NFS file handle" errors (likely iCloud Drive syncing the `Documents/` folder mid-push). `git repack -a -d` to consolidate loose objects fixed it. Pattern: if a future push hits the same error, run `git repack -a -d` and retry.

**Next session pickup:**
- **Activity tab calendar** (the next likely chunk): month view with day cells colour-coded by hit/partial/miss, prev/next month nav, monthly summary aggregates, tap a day → walks for that day. Replaces the current placeholder.
- After that, **Profile/Account tab** (edit dog, add another dog, archive, walk windows picker), then **LLM service** for personalised exercise targets, then notifications, then the missing-screens polish, then end-of-build (paid program, real auth, CloudKit turn-on, HealthKitService + walk detection algorithm).

**Open from this session that may surface later:**
- Real Luna photo source — still using a tinted placeholder. Corey to generate at some point.
- Production app icon — placeholder is in place.
- Sign in with Apple wiring — held to end of build.
- CloudKit sync — held to end of build.
- HealthKitService + walk detection — held to end of build.
- BreedData.json + breed-table-driven default target — currently every new dog gets `dailyTargetMinutes = 60`. Will be replaced when LLM service / breed-table lookup lands.
- Mixed-breed UI — current AddDog only collects `breedPrimary`. Secondary-breed collection is a polish pass when breed picker arrives.

---

## 2026-05-05 (evening) — iOS skeleton built and compiling

**Done this session:**
- Verified Xcode 26.4.1 installed (newer than the 26.3 minimum), `xcode-select` pointing at it.
- Created the Xcode project via the wizard: bundle id `dog.trot.Trot`, Personal Team for now, SwiftUI + SwiftData with "Host in CloudKit" ticked (auto-adds iCloud entitlement), Swift Testing system, save location `ios/Trot/Trot.xcodeproj`. Unticked Xcode's "Create Git repository" since the repo already exists at the root.
- **Option B taken on Sign in with Apple**: skeleton ships without the auth capability so we don't pay $99 yet. Placeholder gate (logo, headline, dimmed Sign in with Apple button, "Continue without sign-in" stub) is what users see at launch. Real auth lands when the Apple Developer Program is paid for.
- Set up the source folder structure under `ios/Trot/Trot/`: `App/`, `Features/{Onboarding,Home,Activity,Insights,Profile}/`, `Core/{DesignSystem,Models,Services,Extensions}/`, `Resources/Fonts/`. Project uses Xcode 16's `PBXFileSystemSynchronizedRootGroup` so files are auto-discovered — no `.pbxproj` editing needed when adding Swift files.
- Built the design system in `Core/DesignSystem/`: `BrandColor.swift` (semantic aliases only — Xcode 26 auto-generates `Color.brandPrimary` etc from asset-catalog colorsets, manual declarations would collide), `BrandFont.swift` (Bricolage display + SF Pro UI), `BrandTokens.swift` (`Space`, `Radius` enums), `BrandMotion.swift` (`brandDefault`/`brandCelebration` springs), `TrotLogo.swift` (wordmark with coral spot inside the `o`).
- 22 brand colorsets added to the asset catalog (light only). Bricolage `.ttf` files copied into `Resources/Fonts/`. `Info.plist` updated with `UIUserInterfaceStyle = Light` and `UIAppFonts`. Placeholder app icon (`app-icon-1024.png`) wired into `AppIcon.appiconset` — single universal entry, light only (Xcode warns about missing dark/tinted variants, accepted as placeholder).
- `OnboardingGateView` and a basic Outdoorsy + Grounded `HomeView` written. Home matches `snapshots/home.png` structurally: header with chevron + ellipsis, streak chip + date chip row, hero photo placeholder (tinted card with paw symbol — see Open below), "Luna's morning." progress card with rationale text, progress track in evergreen, "This morning" walks section with a confirmed walk row, branded TabView (Today/Activity/Insights/Luna).
- Stripped the wizard's SwiftData boilerplate: deleted `Item.swift` and `ContentView.swift`, simplified `TrotApp.swift` to a `@State` flag swapping between `OnboardingGateView` and `HomeView`. The real Dog/Walk/WalkWindow schema + CloudKit wiring stays deferred to its own plan-mode session per architecture.md ("Initial models. Refine in plan mode before implementing.") — half-doing it now would create migration debt.
- `architecture.md` folder-layout block updated to match Xcode's actual output (`ios/Trot/Trot.xcodeproj` rather than `ios/Trot.xcodeproj`). Decided that's cleaner than trying to fight Xcode's wrapper-folder convention.
- `xcodebuild build -scheme Trot -destination "platform=iOS Simulator,name=iPhone 17 Pro"` returns BUILD SUCCEEDED. Both Bricolage TTFs bundled in the .app, asset catalog compiled, app installable in simulator.

**Committed this session:**
- `eba1f0b` — Add iOS skeleton: design system, gate, basic Home (45 files, +1683/-19). Pushed to `origin/main`. First push timed out with macOS `mmap`/"Stale NFS file handle" errors (likely iCloud Drive syncing the `Documents/` folder mid-push); resolved with `git repack -a -d` to consolidate 158 loose objects into one 890 KiB pack, then push went through. If this recurs on future pushes, same fix.
- Mid-session decision shift, captured in `decisions.md`:
    - **Build sequence revised:** passive walk detection (HealthKitService, the algorithm, real-device testing) moves to the **end** of the v1 build, not the start. Manual walk logging is the primary v1-development path. Strava analogy — most fitness apps default to manual start anyway.
    - **Apple Developer Program timing revised:** $99 paid only at the very end, when ready to verify background walk-detection wake on a real device. Not at "first HealthKit work." Corey's framing: $99 acts as a risk gate, validate everything that can be validated on a free Personal Team first.
    - Caveat captured: pre-launch validation under manual-only logging is provisional — the friction of manual logging is part of what passive detection eliminates, so "I love it manually" is not a guarantee of "I love it automatically."

**Next session pickup:**
- **My recommendation:** SwiftData plan-mode session, local-only persistence (no CloudKit yet — that turns on with the paid program at the end). Refine the Dog / Walk / WalkWindow models per architecture.md, wire `ModelContainer` back into `TrotApp.swift`, replace HomeView's hardcoded constants with real `@Query` reads. Once data has somewhere to live, every feature after has a place to put it.
- **Then probably:** Add-a-dog onboarding form (the first feature that actually does something — collect profile fields, persist a `Dog`, navigate to Home with real data). After that, manual walk logging sheet, then build out the engagement loops (streak service, daily target scoring, weekly recap, insights).
- **Held to the end:** Sign in with Apple wiring, CloudKit sync turn-on, HealthKitService + walk detection algorithm, paid Apple Developer Program. All clean, well-defined swaps when we get there — no architectural rework needed.

**Open from this session that may surface later:**
- **Hero photo source.** Home currently shows a tinted placeholder card where the dog photo should go. The AI-generated `dog-luna.jpg` in `design-reference/Trot Design System/assets/` does not ship with the iOS app per `decisions.md`. Need to generate or commission a non-AI placeholder photo (or the proper user-upload flow) before this looks right. Action: Corey to generate this at some point — flagged here so it's not forgotten.
- **App icon production version.** Current icon in the asset catalog is `app-icon-1024.png` from design-reference, used as a placeholder. Needs replacement before TestFlight: generate via Claude Design (prompt drafted previously) and add proper light/dark/tinted variants per Apple's iOS 18+ icon system.
- **Sign in with Apple capability — held to end of build.** Disabled in the gate via Option B. When the Apple Developer Program is paid for at the end, add the capability via Xcode UI, swap the dimmed placeholder button for the real `SignInWithAppleButton`, wire `CKContainer.accountStatus()` for the iCloud-required gate.
- **CloudKit sync — held to end of build.** SwiftData will be wired local-only. The iCloud entitlement and CloudKit container array sit idle on the entitlements file until the end-of-build session that turns sync on (one `ModelConfiguration.cloudKitDatabase` flip plus CloudKit Console schema deploy).
- **Walk detection algorithm + HealthKitService — held to end of build** per the new sequencing. Constraints already locked in `decisions.md` survive intact.
- Breed-table verification pass — pre-launch task, all 30 entries flagged `needs verification`.

---

## 2026-05-05 — Foundation locked, skeleton blocked on Xcode install

**Done this session:**
- Pressure-tested the entire project plan via a structured grill (25+ findings: contradictions between docs, gaps, technical risks, design system integration). Worked through all of them.
- Locked decisions on auth (Sign in with Apple + iCloud required), LLM model (Haiku 4.5), failure UX (8s timeout, fall back to safe-range), streak mechanics (rolling-7-day, ≥50%, partial burns), notification times, distance source (HealthKit pedometer not breed-pace), iOS deployment target (18.0), photo storage (`.externalStorage` + downscale), force light mode, missing-screens strategy (build in code, don't pre-design), email service (Resend, swapped from MailerLite), repo (GitHub public), iOS CI (Xcode Cloud free).
- Path A confirmed for design system: `design-reference/Trot Design System/` is canonical. CSS leads, Swift mirrors. Trot Design skill installed project-scoped at `.claude/skills/trot-design/` (relative symlink).
- Home variant locked: Outdoorsy + Grounded. Other two variants deleted from `home-variants.jsx` and the kit's runtime toggle removed.
- Pre-code checklist mostly done: Bricolage Grotesque `.woff2` → `.ttf` conversion, app-icon-1024 placeholder rendered (Bricolage installed system-wide so Chrome could see it; production icon prompt still on Corey's list for Claude Design), Home variant snapshotted to `snapshots/home.png`.
- `docs/breed-table.md` populated with 30 UK breed YAML blocks (numbers grounded in PDSA puppy rule + KC tier categories + size/life-stage fallback). Every entry flagged `needs verification` — a single pre-launch verification pass replaces the TODO source URLs with real ones.
- All eight project docs updated to reflect the locked decisions. New `docs/breed-table.md` created.
- Two defaults taken without explicit ask, both flagged in decisions.md: deceased-dog v1 = 14-day no-walks safeguard, full memorialise UX deferred to v1.1; pre-Trot lifetime backfill = accept zero, "Trot starts counting today."
- Git initialised, `.gitignore` written, repo pushed to https://github.com/ElimDroflem/trot (commit `92d7b8e`).
- This session-log mechanism set up: `docs/log.md` (you're reading it) plus a pointer in `CLAUDE.md`. Not auto-loaded — read on demand when resuming work.

**Committed this session:**
- `92d7b8e` — Initial project setup: docs, brand, design system, decisions
- `7134ba7` — Add session log to docs/log.md, pointer in CLAUDE.md

**Blocked on:**
- **Xcode 26.3 not installed.** The Mac has Command Line Tools only (Swift 5.9, no `xcodebuild`, no simulator). Setup-guide Step 1 lists Xcode as a prerequisite but it was never verified. Corey is doing a system update + Xcode install during the next gap.

**Next session pickup:**
- Confirm `xcodebuild -version` reports Xcode 26.3+ and `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer` has been run.
- Resume the iOS skeleton plan-mode session. Scope (per Corey's confirmed plan): Xcode project at `ios/Trot.xcodeproj`, folder structure per architecture.md, design system tokens mirroring `colors_and_type.css` 1:1 in `ios/Trot/Core/DesignSystem/`, asset catalog with brand colors (light only), Bricolage `.ttf` bundled in `ios/Trot/Resources/Fonts/`, Info.plist with `UIUserInterfaceStyle = Light` and `UIAppFonts` registered, Sign in with Apple gateway + iCloud-availability check (real native button, real `CKContainer.accountStatus()`), and the Outdoorsy Home matching `snapshots/home.png` at a basic level showing "Hello, Luna" via placeholder data.
- Decision needed at the top of next session: whether to autonomously generate the project via `xcodegen` (cleaner for LLM editing, brittle .pbxproj avoided) or have Corey create the Xcode project shell via Xcode UI (matches architecture.md's "use Xcode UI for capability changes" rule). My recommendation: Corey creates the shell via Xcode UI for the capabilities (Sign in with Apple + iCloud → CloudKit container creation), then I fill in everything inside. ~5 mins of UI clicks for him, the rest autonomous.

**Open from this session that may surface later:**
- App icon: production-quality version via Claude Design (prompt drafted, Corey to run when convenient). Current cream `app-icon-1024.png` is a placeholder — usable for skeleton dev, replace before TestFlight.
- Walk detection algorithm: still flagged Open in `decisions.md`. Dedicated plan-mode session before HealthKitService is built (constraints already captured: Core Motion primary, ≤3-min stationary tolerance, Apple Watch source filtering).
- Breed-table verification pass: pre-launch task. The numbers are conservative and structurally sound; verification replaces TODO sources with real URLs.
