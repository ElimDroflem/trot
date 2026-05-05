# Trot — Session log

A lightweight "where are we" file. Read this when resuming work after a break. Update at the end of each substantive session.

**Format:** newest entry at the top. Each entry covers what was done, what was committed, what's next, and any blockers. Older entries (10+ sessions back) get compressed to a single line.

**This file is not auto-loaded into CLAUDE.md context** — it's read on demand to keep daily context costs low.

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

**Committed this session:**
- `92d7b8e` — Initial project setup: docs, brand, design system, decisions

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
