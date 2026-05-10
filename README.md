# Trot

iOS app that helps people walk their dogs every day through habit loops, dog-centric stats, and zero-friction passive walk detection via HealthKit.

UK launch. iOS only for v1.

## Repository

This monorepo contains:
- **`ios/`** — the SwiftUI iOS app
- **`web/`** — the landing page and Vercel Edge Function (LLM proxy)
- **`docs/`** — product spec, architecture, brand, decisions
- **`design-reference/`** — mockups and assets from Claude Design

## Documents

- `CLAUDE.md` — instructions for Claude Code
- `docs/spec.md` — product spec
- `docs/architecture.md` — technical architecture
- `docs/brand.md` — brand and design system
- `docs/landing.md` — landing page brief
- `docs/decisions.md` — decision log
- `docs/refactor.md` — prioritised refactor backlog
- `docs/log.md` — session log (read on demand to pick up where you left off)
- `setup-guide.md` — first-time setup walkthrough

## Stack

**iOS:** Swift 6 / SwiftUI / SwiftData + CloudKit / HealthKit. Built with Xcode 26.3+ and the iOS 26 SDK. Deployment target iOS 18.0.

**Web:** Static HTML/CSS for the landing page. Vercel Edge Function in TypeScript for the LLM proxy. Single Vercel deployment.

## Working with Claude Code

`cd` into the project folder and run `claude`. State what you want to work on. Insist on plan mode for any new feature.
