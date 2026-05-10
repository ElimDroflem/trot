# Trot — v1 Specification

## Aim

Build an iOS app that gets dogs walked daily by hooking the user with a personalised AI-written book about their dog — one page per walk. Every design decision is judged against two questions:

1. Does this get someone out the door on a wet Tuesday in February?
2. Does the book make them care enough to leave the house in the first place?

The book is the lead. Walking is the cost. Trot is positioned, marketed, and onboarded as "an AI book about your dog that grows when you walk them" — not as another walking tracker.

## Platform

iOS only for v1. iPhone first. iPad and Apple Watch out of scope. Android is a future consideration.

Built with Xcode 26.3+ and the iOS 26 SDK (mandatory for App Store as of April 2026). Deployment target: iOS 18.0. The first generation of SwiftData (iOS 17.0–17.3) had material CloudKit sync bugs; iOS 18 skips that bug surface entirely and the reach cost in 2026 is small.

Force light mode (`UIUserInterfaceStyle = Light` in Info.plist). The warm-cream brand surface is the visual identity; auto-switching to dark would defeat it. Dark mode is a v1.x or later exploration.

## Core principles

**The book is the lead, walking is the cost.** Trot's job-to-be-done is "tell me a story about my dog." Walking is the mechanic that pays for the next page. The retention loop is curiosity, not obligation. Every other feature is in service of that loop.

**The dog is the protagonist.** Both of the story and of the app. Stats, streaks, and progress belong to the dog. Opening Trot feels like checking on the pet, not yourself.

**Zero-effort baseline.** Walks should log without the user opening the app. Trot earns its place through the book and its insights, not through demanding interaction.

**Personalised but safe.** Exercise targets are tailored per dog, but generated from a vetted base table of breed and age guidance. Any LLM personalisation works within safe ranges, it does not invent the numbers.

**Day-zero meaning, not zero-zero stats.** New users see their dog as a character before they see a streak, and they see their HealthKit walking history backfilled into Trot from the moment they grant the permission — never an empty home screen.

## User and account model

One human account holds multiple dogs. Each dog has its own profile, stats, streaks, and book.

**Dog profile fields (collected progressively, see Onboarding):**
- Name (required at onboarding)
- Photo (required at onboarding — the visual identity of the app is your dog's face)
- Breed (single or mixed, with primary breed selected — required, used in story prompts)
- Age (date of birth, with life-stage flag: puppy, adult, senior — optional at onboarding, requested before first exercise target lands)
- Weight (optional, requested when refining target)
- Sex and neuter status (optional)
- Known health conditions (optional, free text plus common tickboxes — arthritis, hip dysplasia, brachycephalic breathing, etc.)
- Activity level baseline (low / moderate / high — user self-assessed, optional)

The minimum viable profile to generate a prologue is: name + photo + breed. Everything else is requested as it becomes useful, with the reward being clearer: "Tell me Bonnie's date of birth so the story can know her age" / "Add Bonnie's weight so we can pitch her exercise plan."

## Onboarding flow

The shape: **two screens of input, then the prologue lands.** Total time-to-prologue: under 90 seconds.

1. **Sign in with Apple.** iCloud required for sync; if missing, copy directs to Settings ("Trot syncs Bonnie's book to your iCloud so you don't lose it."). A Continue-without-sign-in path exists for development.
2. **Photo + name + breed.** Three fields, one screen. Photo is required; if the user skips, the story uses a stylised illustration based on breed but the home screen carries the placeholder cost. Breed feeds the LLM so it can write a beagle vs a great dane differently.
3. **Pick a story.** Genre picker — six worlds (murder mystery, cosy, fantasy, sci-fi, horror, adventure). One tap to highlight, one Begin to commit.
4. **Pick a scene.** One question per genre, four cards (e.g. "Where does the trouble start?" → village fête / seaside hotel / old library / WI meeting). One tap.
5. **Trot writes the prologue.** LLM call, ~5–10 seconds, full-screen genre-themed loading state with copy in voice ("Inking the first page…" / "Pouring the first page…" etc). On failure, falls through to a templated prologue per genre. Result: page 1 of chapter 1 of Bonnie's first book lands. The user reads ~140-180 words ending on a hard cliffhanger.
6. **Permissions, contextually.** AFTER the user has read page 1: "Want me to nudge you when there's a fresh page to read?" → notifications. "Want me to backfill Bonnie's last year of walks?" → HealthKit. The user has just received value; the asks are earned.
7. **Land on the Story tab.** Page 1 visible. The two path-choice buttons are dimmed with a padlock and the explainer "Walk Bonnie 30 minutes to unlock the next page." Done. The book is the home view.

Postcode, DOB, weight, conditions, activity level, walk windows are deferred to optional follow-up moments — surfaced on Home and on Profile with the value made clear ("Add a postcode for the daily walk-window forecast" / "Tell us Bonnie's age so the story can know how old she is").

**The under-the-hood exercise target** still gets generated (using the breed table at the very minimum), but it's not the centrepiece of onboarding. The user sees it later, framed as part of the dog's care, not as the headline.

## Story mode

Story mode is the heart of v1. Per-dog narrative book, AI-generated, one page per walk. Readers steer with path picks. Books finish at five chapters and archive to the dog's bookshelf.

### Mechanics, locked

- **Genre is per-dog and locked for the run of a book.** Switching at the next book is allowed; mid-book is not.
- **Scene is per-book.** Picked once at book start, used to anchor the prologue and inherited into the rolling bible so every subsequent page stays in that world.
- **One book = five chapters × five pages = 25 pages.** Per-genre `chaptersPerBook` field exists for future-proofing varying pacing; v1 ships every genre at 5.
- **Page generation is gated by walking, milestone-style.** Day's first walk hits 50% of target → page 1 of the day unlocks. Day's walks reach 100% of target → page 2 of the day unlocks. Hard cap of 2 pages per local day. Anti-grind: no amount of extra walking on one day generates more than 2 pages.
- **Every page ends on a hard cliffhanger.** Not a tied-off scene, not "they walked home." A discovery, a name, a door opening, a sound. The system prompt enforces this; fallback prologues are written to the same standard. The cliffhanger is the engine that pulls the user back out for the next walk.
- **Path choices.** Each page ends with two LLM-generated path teasers (4-8 word strings). The user picks one, walks, and the next page follows that thread. Optional: write your own direction or attach a photo for the LLM to weave in.
- **Chapter close = celebration.** Page 5 of any chapter triggers an LLM finale call that returns chapter title + closing line + bible refresh + (most chapters) prologue of chapter N+1. UI: full-screen genre-themed takeover with the chapter title in display type.
- **Book finish = bigger celebration.** Chapter 5 close runs a finale variant of the prompt; returns book title + book closing line. UI: bigger takeover than chapter close. Two CTAs: "Read it all" → swipe reader scoped to the book; "Start a new story" → genre picker reappears for the next book.
- **Bookshelf.** Finished books archive on `dog.completedStories` and surface as a horizontal shelf below the genre picker once at least one book is finished. Tap any book to re-read it in the swipe reader.

### Author voice per genre

Each genre's LLM tone instruction ends with *"Channel <Author>'s voice: <one-line style note>. Don't mimic, don't pastiche — channel."* — Christie / King / Martin / Herbert (Dune) / Osman / Macfarlane. This produces recognisable register without crossing into parody.

### Decision panel locked-but-visible

When a milestone hasn't been crossed yet, the path-choice buttons render dimmed (45% opacity, padlock glyph replaces the per-genre path icon, tap suppressed) plus an explainer underneath: *"Walk Bonnie 18 more minutes to unlock the next page."* This gives the user the *tease* of what's coming + the *exact rule* for unlocking it.

### LLM cost ceiling

Anthropic Haiku 4.5 for short-input kinds; Sonnet 4.5 for story page + chapter close (where prose quality matters). Per-call hash-caching where appropriate. Cost target: ~£0.05 per active dog per month at typical use. £15 prepaid spend cap on Anthropic for v1 pre-launch; recurring budget is part of the unit economics for the paid tier (see below).

## Walking habit (the cost mechanic)

### Daily target with consistency-weighted scoring

Each dog has a daily exercise target in minutes. Trot tracks percentage-of-needs-met. 100% is the ceiling. The scoring treats "70 minutes daily for 7 days" as healthier than "490 minutes once a week" — consistency beats volume, and exceeding target doesn't earn extra story pages.

### Streaks tied to the dog

Streaks are per-dog, in local time, ≥50% of target counts as walked, partial days burn the rest day, one rest day per rolling 7-day window allowed, two missed days break it. Mechanics are unchanged from v1's earlier design.

### Walk detection and logging

**Passive detection** is the headline reliability feature. Core Motion + HealthKit observer query + walk-window gating. Algorithm details deferred to a dedicated plan-mode session at the **end** of the v1 build (per `decisions.md`); manual logging is the v1-development primary path.

**Manual logging** always available — for left-the-phone-at-home, outside-window, multi-dog cases, or user preference.

**Multi-dog walks** default-on per dog; every walk credits all active dogs unless the user unticks one.

### HealthKit history backfill on day 0

After the prologue lands and the user grants HealthKit, Trot pulls the last year of walking history and surfaces "Bonnie has walked with you 84 hours over the past year" as part of her stats. The dog's life as the user has already lived it, suddenly visible in the app. This reverses the previous "lifetime stats start at zero" decision (see `decisions.md`).

### Deceased-dog safeguard (v1 hard rule)

No notifications fire for any dog with zero walks in the last 14 days. The streak silently freezes; no nudges, no "streak at risk", no recap pushes. The user can manually archive the dog from profile settings. Full memorialise UX deferred to v1.1.

## Engagement loops

Story mode is the spine. The other loops support it.

1. **Story mode** (above) — the curiosity engine.
2. **Streak** — per-dog, breaking it feels like letting the dog down. Reinforces the daily-walk habit between book milestones.
3. **Insights** — populated from day 1 with HealthKit backfill data, refreshed weekly. "Bonnie walks 22% more on weekends." "Bonnie has been most active when you walk her before 8am." Real observations become more interesting once the user has data to be observed against.
4. **Dog-centric milestones** — lifetime minutes, lifetime distance (HealthKit pedometer-derived, displayed as estimated), walks completed, "Bonnie has walked approximately the equivalent of London to Brighton."
5. **Identity reinforcement** — "Bonnie is getting the exercise she needs" not "you're crushing it."
6. **Weekly recap** — Sunday evening ritual. Total minutes, percentage of needs met, comparison to last week, streak status, one personalised insight, a featured photo. Deliberate redundancy to story mode: this loop pays off for users who don't engage with the book, and for those who do, it's a different angle on the same week.

### First-week journey, woven into Story mode

The prologue lands on day 0 from the dog profile alone. Day 1's walk unlocks page 2. The first chapter (5 pages) is roughly the user's first 3 days of walking. Chapter 1 close = first major celebration.

The prior "first-week milestone ladder" (first walk / first 50% / first 100% / first 100 minutes / first 3-day streak / first week) is deprecated as a separate UI surface — its beats are now woven into Story mode (page unlocks, chapter close) and the streak/recap loops. In-app celebration moments still fire for streak tiers (3, 7, 14, 30) and book completion; they don't compete with story-tab beats.

## Notifications

Permission asked at the **first earned moment** — after the user reads page 1 of the prologue ("Want me to nudge you when there's a fresh page?"). On grant, all notification types are enabled. On denial, an inline "enable in Settings" hint appears in-context wherever a reminder would otherwise help.

All times local. No user configuration in v1 — defaults locked.

1. **Walk confirmation** — fires after passive detection identifies a likely walk. Most important once detection ships. "Looks like you just walked for 28 minutes. Was that with Bonnie?"
2. **Story page-ready nudge** — when a walk crosses a page-unlock threshold (50% or 100% of target), a notification fires: "Bonnie's next page is ready." Direct deep-link into Story tab. New in this revision; replaces the under-target nudge as the primary daily push.
3. **Under-target nudge** — fires at **19:00 local** if the dog has had <50% of target progress AND no walk is in progress AND the day isn't covered by the rest-day allowance. Suppressed Sundays. Demoted from the headline notification slot — story page-ready earns more taps and is more aligned with the book-as-lead positioning.
4. **Streak milestone** — at 7, 14, 30 days. Fires at **09:00 local the morning after** the qualifying day completes.
5. **Weekly recap ready** — fires **Sunday 19:00 local**.
6. **Streak at risk** — deferred to v1.1.

The 14-day no-walks deceased-dog safeguard suppresses all per-dog notifications regardless of toggles.

## Sharing (new in v1 scope)

A finished book is a shareable artefact. On book completion, the user can generate a beautifully designed share card carrying:
- The dog's photo (hero)
- Book title (LLM-generated)
- Genre badge
- Stat line ("5 chapters · 25 pages · 27 walks · 14 hours with Bonnie")
- A short closing line excerpt
- A small "Made with Trot" mark

Card exports to Photos / shares natively via `UIActivityViewController`. No public web URL in v1 (deferred to v1.1).

This is the minimum viable social hook. Without it, every install must come from paid acquisition or personal network. With it, finished books seed organic discovery.

## Monetisation (new in v1 scope)

Free tier covers the core loop: one dog, one book at a time, all walking + streak + insights features. Trot Pro at £3/month or £20/year unlocks:

- **HealthKit history backfill beyond the last 30 days** (free tier sees the last 30; Pro sees the full year)
- **Multiple active dogs** (free is one dog; Pro is unlimited)
- **Share cards** (free generates a watermarked card; Pro generates the clean card)
- **Priority story generation** (Pro queues bypass any rate-limit windows; free queues fall back to templated copy more readily)
- **Future**: print-on-demand for finished books (v1.x via partner)

Pricing target unit economics: at £3/month with average 5 LLM calls per active dog per month at ~£0.01 each, gross margin > 80%. The free tier's LLM cost is the marketing cost.

In-app purchase via StoreKit 2. No subscription manipulation, no dark patterns. Cancel button is one tap deep, in the same place every other iOS subscription cancel lives.

Free-with-IAP is the sustainable model in this category in 2026; pet owners pay for things they care about (BarkBox, FitBark, Whistle, Tractive). A small, well-positioned paid tier signals quality and funds the AI loop.

## Key screens

**Story (the home of the app — was Today / Home in earlier v1 drafts).** Active book's current page with milestone-gated decisions. Chapter spine above. Bookshelf below the genre picker when no book is active. The first thing the user sees when they open the app on day 0 is page 1 of the prologue.

**Today.** Dog photo, current streak, today's progress against target, walk-window forecast, walk-rationale tile. The daily-loop surface. Less prominent than Story.

**Activity.** History of walks. Calendar view showing daily target hit / partially hit / missed. Weekly and monthly aggregates.

**Insights.** Personalised observations. Populated from day 1 via HealthKit backfill (was day-7 in earlier draft).

**Dog profile.** Editable profile, exercise target, walk windows, archive button.

**Account.** Multiple dogs, settings, notifications, permissions, subscription state.

## Tech summary

- **App:** Swift 6 with strict concurrency, SwiftUI, SwiftData + CloudKit, HealthKit + Core Motion, iOS 18.0+, light mode only
- **Auth:** Sign in with Apple. iCloud required.
- **Backend:** Single Vercel Edge Function as LLM proxy. Anthropic Haiku 4.5 for short kinds; Sonnet 4.5 for story page + chapter close. 30s timeout for story; 8s for everything else. Hash-cached responses where appropriate. Anonymous install tokens for rate limiting.
- **Observability:** MetricKit + Sentry. No product analytics in v1.
- **Tests:** Swift Testing framework
- **Landing page:** static HTML/CSS, deployed to Vercel alongside the backend. Headline leads with the book.
- **iOS CI:** Xcode Cloud (free tier, 25hr/month) on push to main
- **Monetisation:** StoreKit 2, single subscription product (Trot Pro)

Distance estimates use HealthKit's pedometer-derived `distanceWalkingRunning` (no GPS, no location tracking), displayed as estimated.

## App Store metadata

Test variations during pre-launch. Lead candidate:

- **App Name:** `Trot: A Book About Your Dog` (28 chars)
- **Subtitle:** `AI writes a page every walk` (28 chars)
- **Keyword field:** dog story, AI book, dog walking, pet exercise, dog journal, walking tracker, breed exercise, dog routine, dog wellness, daily walk

Lead-with-the-book positioning is non-negotiable. Walking tracker is what the App Store is full of; AI book about your dog is what makes Trot worth a tap.

Backup variant if review rejects "Book About Your Dog" framing for any reason:

- **App Name:** `Trot: Walk to Write the Book`
- **Subtitle:** `AI writes a story when you walk`

## Launch market

UK only. High dog ownership, strong walking culture, single language, manageable size for refining the product before geographic expansion.

## Out of scope for v1

- Photo features beyond the dog's profile photo and per-page-photo attachments
- Couples and shared accounts (deferred to v1.1; flagged as the highest-priority post-launch feature based on UK pet-household demographics)
- Leaderboards (any flavour)
- Public profile pages / web URLs for shared books
- Location tracking and route mapping
- Vet, trainer, and welfare partnerships
- Health and behaviour tracking beyond exercise
- iPad, Apple Watch, Android
- Streak-at-risk notifications
- Book-completion print-on-demand

## Success criteria for v1

There is no product analytics in v1, so success is measured qualitatively:

- Corey uses Trot daily for 3 months and the app feels good
- 5+ friends and family use it daily for 3 months without prompting
- App Store reviews mention the **book** as the thing that hooked them — not the streak, not the tracker (those work for retention; the book is what makes the app stand out)
- At least one finished book gets shared organically (Instagram / X / WhatsApp) without prompting
- Nobody asks "why doesn't it just …" about the core loop — story page reveal, walk gating, chapter close, book finish

If those signals are positive, build v1.1 with proper analytics (PostHog or similar) and chase the real numbers. If the qualitative signals are negative, no amount of analytics will save it.

---

## Future feature concepts

Exploratory; not committed.

**Couples / shared accounts.** Highest-priority post-launch feature. Two humans walking the same dog should both get credit, both get nudged, both see the same story. UK pet-household demographics make this near-mandatory for retention at scale.

**Photo game.** Couples or individuals submit walk photos, an AI judge scores them with personality, weekly winners get featured.

**Local leaderboards.** Hyper-local, breed-specific cohorts. Scored on percentage-of-needs-met, capped at 100%.

**Vet and welfare partnerships.** The "needs-met, capped at 100%" scoring is well-suited to clinical endorsement.

**Year-end recap.** Spotify Wrapped equivalent for the dog's year, including a montage of the year's books.

**Print-on-demand for finished books.** Real, physical, beautifully designed printed book of the dog's first AI-written story. Premium add-on.

**Adoption-anniversary milestones, training records, vet reminders.** Expanding from walks to a fuller dog-life companion.

**Apple Watch and wearable integration.** Detect walks via watch directly, log without phone present.

**Location features.** Optional, opt-in route mapping. Discovery of new walking spots. Sniff-time tracking.

**Android.** Once iOS validates the core habit and unit economics work.

These features assume v1 succeeds in its core aim. If users do not engage with the book + walking loop in v1, none of these additions will save the product.
