# Trot — Setup guide

This is your one-time setup. Once done, daily workflow is just `claude` in the project folder.

## Prerequisites

- A Mac running macOS 15+ (required for Xcode 26.3)
- Xcode 26.3 or later — install from the Mac App Store
- Node.js — `brew install node` (if you don't have Homebrew, install it from brew.sh first)
- Claude Code — `npm install -g @anthropic-ai/claude-code`
- A Vercel account (free tier) — sign up at vercel.com
- An Anthropic API key — for the backend LLM proxy
- An Apple Developer account ($99/year) — required for HealthKit and TestFlight
- A Pro/Max Claude subscription — for Claude Design access

The Apple Developer account is the only paid item beyond a Claude subscription. Everything else is free at v1 scale.

---

## Step 1: Project folder

Create the folder and structure:

```bash
mkdir trot
cd trot
mkdir docs design-reference
git init
```

Save the documents in the right places:
- `CLAUDE.md` → root
- `README.md` → root
- `setup-guide.md` → root (this file)
- `spec.md` → `docs/`
- `architecture.md` → `docs/`
- `brand.md` → `docs/`
- `landing.md` → `docs/`
- `decisions.md` → `docs/`
- `breed-table.md` → `docs/` (drafted in Step 3.5 below)

Final structure at this point:

```
trot/
├── CLAUDE.md
├── README.md
├── setup-guide.md
├── docs/
│   ├── spec.md
│   ├── architecture.md
│   ├── brand.md
│   ├── landing.md
│   └── decisions.md
└── design-reference/
    └── (Trot Design System lands here, exported from Claude Design in Step 3)
```

The `ios/`, `web/`, and `.claude/skills/` folders are created in later steps.

---

## Step 2: Install Paul Hudson's agent skills (global)

These skills target the specific things Claude commonly gets wrong in Swift. Install once, they apply across all your Claude Code projects.

Run each command. When asked which agents to install to, use arrow keys to highlight Claude Code, press Space to select, Enter to confirm.

```bash
npx skills add https://github.com/twostraws/swiftui-agent-skill --skill swiftui-pro
npx skills add https://github.com/twostraws/swiftdata-agent-skill --skill swiftdata-pro
npx skills add https://github.com/twostraws/swift-concurrency-agent-skill --skill swift-concurrency-pro
npx skills add https://github.com/twostraws/swift-testing-agent-skill --skill swift-testing-pro
```

If you get `npx: command not found`, run `brew install node` first.

These install at user scope (`~/.claude/skills/`) and become available in every Claude Code session. The Trot Design skill is installed separately, project-scoped, in Step 3.5.

---

## Step 3: The design session in Claude Design (DONE)

The design session has happened. The exported design system lives at `design-reference/Trot Design System/` and is now the canonical source of truth.

Outcomes (all locked in `docs/decisions.md`):
- **Visual direction:** Outdoorsy + Grounded
- **Logo:** lowercase `o` with a coral spot inside its counter; Bricolage Grotesque 700, `letter-spacing: -0.045em`
- **Tokens:** authoritative in `colors_and_type.css` (color, type, spacing, radius, shadow, motion)
- **Canonical screens designed:** Home (Outdoorsy + Grounded), Activity, Walk Confirmation sheet, Onboarding Dog
- **Landing page:** real HTML/CSS at `ui_kits/landing/index.html`, drops into `web/` (see Step 5)

The original Step 3 instructions for running the design session are kept below for future expansion sessions (e.g. designing the screens not yet covered: Insights, Dog profile, Account, Walk windows, LLM result, Weekly recap, Streak milestone, empty states). Don't re-run the whole thing for v1 — the foundation is locked.

### Re-running the design session (only if needed)

This is where Trot becomes a brand instead of a brief. Plan for 2–3 hours total. Open Claude Design at claude.ai (palette icon in the left sidebar — Pro/Max subscribers have access).

The session has four sub-stages. Do them in order; each builds on the last.

### 3a. Visual direction (30 min)

Set up a new Claude Design project. Paste this as the brief:

> I'm building Trot, a UK iOS app that helps dog owners walk their dogs every day. The dog is the user, not the human. The app should feel warm, capable, and never preachy.
>
> Brand essence: Trot is the dog walking app that takes your dog's needs seriously. Warm, capable, never preachy. The user is a competent adult who loves their dog and we treat them that way.
>
> Principles:
> 1. The dog comes first. Every screen treats the dog as the user.
> 2. Confident, not chirpy. We trust users; we don't cheerlead.
> 3. Warm but credible. Like a knowledgeable friend, not a marketing brochure.
> 4. Daily ritual, not daily chore. Calm, not demanding.
> 5. Show, don't shout. Color and motion used sparingly so they mean something.
>
> Generate three different visual directions for the Home screen. Each should interpret the brand differently:
> 1. Warm and joyful — sunny, optimistic palette
> 2. Outdoorsy and grounded — earthy, fresh, evokes morning walks
> 3. Modern and confident — clean, slightly bold, premium feel
>
> The Home screen shows a large photo of the dog, today's walking progress, the current streak, and a button to log a manual walk. No paw prints. No cliches.

Look at the three. See which feels right. Pick one and refine through conversation, inline edits, or sliders.

### 3b. Logo (30 min)

In the same Claude Design project, with the chosen visual direction locked in:

> Now design four logo directions for Trot. The logo should:
> - Read as Trot from any context
> - Suggest motion or a dog without explicit dog imagery
> - Work as a square app icon and as a horizontal lockup
> - Be reducible to a single color for stamp/favicon use
> - Avoid paw prints, dog silhouettes, bone shapes
>
> Output as SVG so I can export and use them.

Pick a direction. Refine. Export both the wordmark (horizontal) and the icon (square) as SVG. Save to `design-reference/Trot Design System/assets/`.

For the iOS app icon specifically, you'll need a 1024×1024 PNG export. You can generate it from the SVG in any vector tool (or ask Claude Design to export). Save as `design-reference/Trot Design System/assets/app-icon-1024.png`.

### 3c. iOS screen mockups (45 min)

Still in Claude Design:

> Using the established visual direction, generate detailed mockups for these iOS screens:
> 1. Home — dog photo, today's progress, current streak, manual walk button
> 2. Activity — calendar view showing walked/missed days, list of recent walks
> 3. Onboarding step 1 — welcome screen
> 4. Onboarding step 2 — adding the first dog
> 5. Walk confirmation — the post-walk "Was that with Luna?" prompt
>
> Each should fit a modern iPhone screen (iPhone 16 Pro proportions). Use the brand palette and typography we established.

Refine each one. Export as PNG and save to `design-reference/Trot Design System/snapshots/` with clear names: `home.png`, `activity.png`, `onboarding-1.png`, `onboarding-2.png`, `walk-confirmation.png`.

These become the visual contract for Claude Code. When you ask for a screen, Claude Code will reference these files and the Xcode 26.3 integration can capture SwiftUI Previews to compare against them.

### 3d. Landing page (45 min)

Now build the actual landing page. Unlike iOS where Claude Design output is reference only, here the output IS the deliverable.

Read `docs/landing.md` first. It has the brief.

Then in Claude Design:

> Build the Trot landing page. Single page, three sections plus footer:
>
> 1. HERO: Trot logo top-left, headline ("The dog walking app that keeps you on track."), one-line subhead, primary CTA (email signup — "Get notified when Trot launches"), and a single screenshot of the Home screen on a phone.
>
> 2. THREE FEATURES: Each is an icon, a one-line title, and two short sentences.
>    - Walks log themselves. Trot detects walks via HealthKit. Tap once to confirm; the rest is automatic.
>    - Targets that fit your dog. Beagles, Frenchies, and Labradors don't need the same exercise. Trot adjusts to breed, age, and health.
>    - A streak worth keeping. Track your dog's daily walking habit. One rest day a week is allowed.
>
> 3. SECONDARY CTA: A short headline ("Start walking your dog daily.") and the same email signup.
>
> FOOTER: Trot logo monochrome, links to Privacy, Terms, X account, copyright.
>
> Use the brand palette, the display face for the headline, system fonts for body. Plain HTML and CSS, no React, no build step. Mobile-first.

Refine until it feels right. Export the HTML and CSS bundle. You'll drop these into `web/` later (in Step 5).

### Update brand.md (already done for v1)

For the v1 design session, brand.md was updated to point at `colors_and_type.css` as the source of truth and to reflect locked decisions (force light, dot-in-the-o logo, Bricolage Grotesque). Don't redo that work.

For future design sessions: update `colors_and_type.css` with new tokens, then mirror to the Swift design system. Update brand.md only if voice rules, principles, or component rules change — not for token values.

---

## Step 3.5: Pre-flight tasks before any iOS code

These are one-shot tasks that have to happen between the design session and the first Claude Code iOS session. None require code, but skipping any will cause friction later.

### 3.5a: Install the Trot Design skill (project-scoped)

```bash
mkdir -p .claude/skills
ln -s "$(pwd)/design-reference/Trot Design System" ".claude/skills/trot-design"
```

If symlinks don't work for your skill loader, copy the folder instead:

```bash
cp -R "design-reference/Trot Design System" ".claude/skills/trot-design"
```

Verify in a `claude` session: `/trot-design` should resolve.

### 3.5b: Convert Bricolage Grotesque .woff2 → .ttf for iOS

iOS bundles need TTF or OTF, not woff2. Bricolage Grotesque is SIL OFL 1.1 — format conversion is allowed.

```bash
pip install fonttools brotli
# Decompile the Latin woff2 to TTF
pyftsubset "design-reference/Trot Design System/fonts/BricolageGrotesque-Variable.woff2" \
  --output-file="design-reference/Trot Design System/fonts/BricolageGrotesque-Variable.ttf" \
  --unicodes="*" --flavor=""
```

If `pyftsubset` is awkward, use any free woff2-to-ttf online converter (the file is already public-licensed).

The .ttf gets bundled in the iOS project at `ios/Trot/Resources/Fonts/` in the iOS skeleton step.

### 3.5c: Generate the 1024×1024 app icon PNG

`design-reference/Trot Design System/assets/logo-icon.svg` is the source. Export at 1024×1024 with the tighter `o` treatment so the spot reads inside Apple's icon mask safe area (~88% inner safe zone).

Easiest path: open the SVG in any vector tool (Figma, Sketch, Affinity, even a browser tab + Inspector), export PNG at 1024×1024. Save to `design-reference/Trot Design System/assets/app-icon-1024.png`.

Test the masking: drag the PNG onto Apple's online icon preview, or use a tool like `IconKit`. Adjust the SVG if the spot gets clipped at any standard icon corner radius.

### 3.5d: Snapshot the Outdoorsy + Grounded Home variant

The visual-diff workflow needs a PNG to compare against. Run the kit locally:

```bash
cd "design-reference/Trot Design System/ui_kits/ios-app"
python3 -m http.server 8000
```

Open `http://localhost:8000` in Chrome, set the tweaks panel to "Outdoorsy + Grounded" with the standard data (42 minutes / 60 target / 14 streak), screenshot the iPhone-frame element, save to:

```
design-reference/Trot Design System/snapshots/home.png
```

### 3.5e: Lock the Home variant in the kit source

Delete the Warm + Joyful and Modern + Confident variants from `home-variants.jsx`. Remove the `homeVariant` toggle from the tweaks panel. Outdoorsy is the only Home from now on.

### 3.5f: Draft `docs/breed-table.md`

This is the data foundation for onboarding. Spend a couple of hours with PDSA, Kennel Club, RSPCA, and breed-club guidance to draft 30–40 of the most common UK breeds with daily exercise ranges, life-stage adjustments, and breed-specific cautions. Plus a fallback table by size + life stage for unlisted breeds.

The schema is fixed — see the file's header. The data is research time.

### 3.5g: Domain, email, X handle

- Check `trot.dog` availability and register if free. Fallback `trotapp.com`.
- Resend account is already set up. Confirm the API key is to hand for the Vercel env, and create a "trot-launch" audience in the Resend dashboard for the landing-page signup capture.
- Confirm the personal X handle (`@coreyrichardsn`) is set up with bio. Pinned post comes once landing is live.

### 3.5h: NOT YET — Apple Developer Program

Don't pay the $99 yet. The trigger is starting HealthKit service work. Until then, the simulator and a free Apple ID are enough for iOS skeleton work.

---

## Step 4: First Claude Code session — iOS skeleton

In the project folder, run:

```bash
claude
```

Paste this as your first prompt:

> Read CLAUDE.md, docs/spec.md, docs/architecture.md, docs/brand.md, docs/landing.md, docs/decisions.md, and docs/breed-table.md. Also read design-reference/Trot Design System/README.md and colors_and_type.css.
>
> Then in plan mode:
> 1. Confirm you understand the project, the working style, the tech stack, the brand, and the locked decisions.
> 2. Plan the iOS project skeleton: Xcode project file inside `ios/`, folder structure as defined in architecture.md, .gitignore at root, the design system tokens in `ios/Trot/Core/DesignSystem/` mirroring `colors_and_type.css` 1:1, asset catalog entries for the brand colors (light only), Bricolage Grotesque .ttf bundled in `Resources/Fonts/`, Info.plist with `UIUserInterfaceStyle = Light` and `UIAppFonts` registered, a Sign in with Apple gateway plus iCloud-availability check, and a minimal Home screen showing "Hello, Luna" using the brand tokens correctly. The Home screen should match the layout in `design-reference/Trot Design System/snapshots/home.png` at a basic level.
> 3. Don't write any code until I approve the plan.
>
> After I approve, set up the skeleton, then walk me through opening it in Xcode 26 to verify it builds and runs on the iPhone simulator.

Read the plan. Ask questions about anything unclear. Approve when ready.

---

## Step 5: Second Claude Code session — landing page

In the same project folder:

```bash
claude
```

Paste this:

> Read CLAUDE.md, docs/landing.md, docs/brand.md, and docs/decisions.md.
>
> The exported landing page lives at `design-reference/Trot Design System/ui_kits/landing/index.html`. It links `../../colors_and_type.css` and uses Lucide via CDN.
>
> In plan mode:
> 1. Plan how to organize this in `web/` — copy the landing source, adjust the colors_and_type.css path so it lives inside `web/` and isn't reaching outside the deploy root, copy the dog photo asset (replace with a real Home-screen PNG once we have one), and inline the three Lucide icons as SVG (footprints, sliders-horizontal, flame) so the landing has no CDN dependency.
> 2. Plan the email form wiring to Resend: a `web/api/subscribe.ts` Vercel Edge Function that calls Resend's contacts API to add submissions to the "trot-launch" audience. Resend API key in Vercel env, never client-side.
> 3. Plan privacy.html and terms.html using the same tokens — content covers HealthKit data handling, Anthropic as a sub-processor, log retention, anonymous install tokens, GDPR rights. Templates for lawyer review pre-submission.
> 4. Plan vercel.json and the Vercel deployment config (push to main → auto deploy).
> 5. Don't write code until I approve.

After approval, Claude Code will set up `web/`, integrate the design system output, wire the form, and walk you through deploying to Vercel.

Once deployed, you have a real URL to share on X. The landing page is live before the iOS app is even built.

---

## Step 6: Verify everything runs

**iOS app (UI only):**
1. Open `ios/Trot.xcodeproj` in Xcode 26
2. Select an iPhone simulator (e.g. iPhone 16)
3. Press Play (Cmd+R)
4. The simulator should show your Home screen using the brand tokens, in light mode

**The simulator validates UI and builds, not the core feature.** HealthKit and Core Motion don't work in the iOS Simulator. Walk detection cannot be tested there. That part requires a physical iPhone, which requires the Apple Developer Program ($99) — pay this only when starting HealthKitService work, not before.

**Landing page:**
1. Visit your Vercel deployment URL
2. The page should match the design system landing kit and respond on mobile
3. Lighthouse score: 95+ on Performance, Accessibility, Best Practices, SEO. If lower, the most likely cause is the (now self-hosted) Lucide icons — confirm they're inlined SVG, not CDN-loaded.

If anything fails, paste the error back to Claude with one line of context.

---

## Step 7: Future sessions

Every future session:
1. `cd trot`
2. `claude`
3. State what you want to work on
4. Insist on plan mode for any new feature
5. Reference design system files when building screens — "Match `design-reference/Trot Design System/snapshots/home.png`" or "Use the TrotCard pattern from `ui_kits/ios-app/components.jsx`"
6. Apple Developer Program ($99) is paid when starting HealthKitService work — that's the trigger, not day one

That's it.

---

## Working tips

**Plan mode is your biggest lever.** For every feature, ask Claude to plan first. Read the plan. Push back if something feels wrong. Approve. Then implement. Skipping plan mode is how projects turn into spaghetti.

**Reference your design system.** When asking Claude Code to build a screen, point to the canonical capture: "Build the Insights screen. Match `design-reference/Trot Design System/snapshots/insights.png` if it exists; otherwise build from tokens, voice, and component principles. Use tokens from `colors_and_type.css`."

**Compact when it gets long.** Run `/compact` when the conversation gets long. Tell Claude what to preserve: "compact the conversation, keep the current implementation plan and any open issues."

**Check your usage.** `/usage` shows how much of your plan you've used in the current window.

**Trust your instincts.** If Claude does something you didn't ask for, push back. If a recommendation feels wrong, question it. You're the senior engineer here.

**Use Claude Design later for marketing.** Once Trot ships, use Claude Design again for App Store screenshots, social posts, pitch materials. Same brand system.

---

## When things go wrong

**Build errors in Xcode:** copy the error message, paste to Claude with "this is what I'm seeing when I build."

**Behaviour wrong at runtime:** describe what you did, what you expected, what happened. One sentence each.

**Confused about something Claude did:** ask "explain what you just did in one sentence." Then ask follow-ups if needed.

**Stuck on a decision:** ask Claude to give you the trade-offs in three bullets and a recommendation. Decide, then add it to docs/decisions.md.

---

## What lives where

- **iOS code** — `ios/` (Xcode project)
- **Landing page + backend** — `web/` (deployed as one Vercel project)
- **Design system (canonical)** — `design-reference/Trot Design System/` (tokens in `colors_and_type.css`, snapshots, ui_kits, fonts, assets)
- **Trot Design skill** — `.claude/skills/trot-design/` (symlinked or copied from the design system folder)
- **Brand voice and component principles** — `docs/brand.md`
- **Architectural and product decisions** — `docs/decisions.md`
- **Spec changes** — `docs/spec.md`
- **Breed-and-age safe-range data** — `docs/breed-table.md`
- **Conversation history** — Claude Code (use `/resume` to pick up previous sessions)

CLAUDE.md is loaded every session automatically. The other docs are referenced from CLAUDE.md, so Claude pulls them in when relevant.
