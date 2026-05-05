# Trot — Claude Code Instructions

## Project

Trot is an iOS app that promotes daily dog walking through habit loops, dog-centric stats, and zero-friction passive walk detection via HealthKit. UK market. v1 only.

The repo also contains a marketing landing page and a small backend (LLM proxy) — both deployed to Vercel.

Spec: @docs/spec.md
Architecture: @docs/architecture.md
Brand and design system: @docs/brand.md
Landing page brief: @docs/landing.md
Decisions log: @docs/decisions.md

Session log lives at `docs/log.md` (not auto-loaded). Read it on demand when resuming work after a break, or when the user references "where we left off." Update it at the end of substantive sessions.

## Working with me

- I'm not a developer. Explain non-obvious choices briefly — one or two sentences, not lectures.
- If I want more detail, I'll ask. Don't pre-emptively expand.
- Flag problems and uncertainties as they arise, not at the end. If you're unsure something will work, say so before building it.
- Errors: show the error, one line on what it means, the fix, then apply.
- I prefer plain language. No filler, no hedging, no em dashes in copy or comments.

## Workflow

- Use plan mode before writing code for any new feature. The plan is the explanation — I read it, ask questions if needed, approve, then you implement.
- One feature at a time. Don't scope-creep into adjacent work.
- When you make an architectural decision, update @docs/decisions.md.
- Don't bypass plan mode because the change "seems small."
- When implementing a screen, check `design-reference/Trot Design System/snapshots/` for a canonical capture and `ui_kits/` for component examples. If neither exists, build it from tokens, voice rules, and layout principles, then iterate from running builds.

## Stack

**iOS app:**
- Swift 6 with strict concurrency from day one
- SwiftUI only (no UIKit, no Storyboards)
- Built with Xcode 26.3+ and iOS 26 SDK; deployment target iOS 18.0
- Sign in with Apple for auth. iCloud required (Trot's sync story depends on it)
- SwiftData for persistence with CloudKit sync. No `User` model — iCloud account is the user identity
- HealthKit + Core Motion for passive walk detection (algorithm pending plan-mode session — see decisions.md)
- Force light mode for v1 (`UIUserInterfaceStyle = Light` in Info.plist)
- Swift Testing framework
- Swift Package Manager only (no CocoaPods)
- MetricKit + Sentry for observability. No product analytics in v1.

**Web (landing page + backend):**
- Static HTML/CSS/JS for the landing page (no framework needed for v1)
- Vercel Edge Functions in TypeScript for the LLM proxy
- Single Vercel deployment serves both

## Architecture

- MVVM. Views observe view models. Models are dumb data.
- Service layer for everything external: HealthKit, persistence, LLM, notifications. Views never touch these directly.
- Async/await throughout. No completion handlers, no Combine, no DispatchQueue in new code.
- View models marked @MainActor. Data types Sendable. Services as actors where state is shared.
- Split files early. SwiftUI view past 200 lines → break it up.

## Design

- The canonical design system is `design-reference/Trot Design System/`. `colors_and_type.css` is the single source of truth for tokens.
- Token flow: add to `colors_and_type.css` first, then mirror to Swift extensions in `ios/Trot/Core/DesignSystem/`. Never the other way round. CSS leads, Swift follows.
- Visual references live at `design-reference/Trot Design System/snapshots/` (canonical screen captures) and `design-reference/Trot Design System/ui_kits/` (component examples). When implementing a screen, check these first.
- Voice and component principles still live in @docs/brand.md (everything that isn't a token).
- Colors: `Color.brandPrimary` etc, defined in the asset catalog. Light only — no dark variants in v1. No raw hex in views.
- Typography: SF Pro for UI, Bricolage Grotesque only for moments of brand expression (onboarding hero, weekly recap, streak milestones, landing hero).
- Spacing: `Space.md` etc, never raw numbers like `16`.
- Corner radius: `Radius.lg` etc, never raw numbers.
- Icons: SF Symbols on iOS, Lucide on web. Custom illustration only where brand.md calls for it.
- Copy follows the voice rules in brand.md. Never write copy that violates the "Never" list.
- For landing page work, follow @docs/landing.md.

## Security

- No API keys in the iOS app, ever. LLM calls route through the Vercel Edge Function proxy at `web/api/exercise-plan`.
- Secrets in .env files, never committed. .env in .gitignore from day one.
- Validate user input before persisting it.

## Persistence

- SwiftData with CloudKit sync. CloudKit schema must be deployed to the Production environment in the CloudKit Console before each App Store release — silent sync failure otherwise.
- Use `initializeCloudKitSchema` in DEBUG only, after model changes, to ensure relationships sync.
- All timestamps stored in UTC. Convert to local on display only.
- Schema changes go through SwiftData migrations, never manual edits.
- Photos use `@Attribute(.externalStorage)` — never inline. Downscale on save: 1024px long edge, 80% JPEG, ~150-300KB target. This is a hard rule from day one because adding `.externalStorage` later is a migration.

## Observability

- MetricKit from day one for crash, hang, and jetsam reports.
- Sentry layered on top for real-time alerts and richer context.
- Persistent logger for meaningful events. No raw print() in production code paths.
- Errors surface to the user with a useful message. No silent failures.

## Testing

- Swift Testing (@Test, #expect — not XCTest).
- Unit-test the unhappy paths: HealthKit denied, LLM fails, malformed data, notifications blocked.
- New features ship with tests.

## Discipline

- If something feels hacky, fix it now or add `// TODO(corey, YYYY-MM-DD):` with a clear deadline. "Later" never comes.
- No commented-out code in commits. Use feature flags or branches.
- Repeated logic across files → factor it out before continuing.

## Installed agent skills

Invoke when relevant to the work in hand:
- `/swiftui-pro` for SwiftUI views and components (global)
- `/swiftdata-pro` for SwiftData models and CloudKit sync (global)
- `/swift-concurrency-pro` for concurrency-related work (global)
- `/swift-testing-pro` when writing tests (global)
- `/trot-design` for visual work, components, and brand decisions (project-scoped at `.claude/skills/trot-design/`)
