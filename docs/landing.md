# Trot — Landing page brief

## Purpose

The landing page exists to do two things and nothing else:
1. Convert visitors to App Store downloads (or email signups before launch).
2. Function as a portfolio piece — a real, polished URL to share on X and put on the CV.

It is not a marketing website. It is not a place for blog posts. It is not the start of a content strategy. If a section is not directly serving conversion or onboarding, it doesn't ship.

## What ships

A single-page site with three sections plus footer.

### 1. Hero

- Logo (top-left, small)
- Headline that captures the value prop in one line
- One-line subhead with the proof point or detail
- Primary CTA: App Store badge if launched, email signup if pre-launch
- Visual: a single screenshot of the Trot Home screen, on a phone, well-shot

The headline does the heavy lifting. Some directions to test:

- "The dog walking app that keeps you on track."
- "Built around your dog, not your steps."
- "Your dog deserves a daily walk. Trot makes sure they get one."
- "Walk your dog, every day."

Subhead supports it with the differentiator:

- "Trot detects walks automatically and tailors targets to your dog's breed, age, and health. iOS only."
- "Passive walk detection, breed-tailored targets, and a streak that belongs to your dog."

### 2. Three feature blocks

Three short blocks. Each one: an icon or small illustration, a one-line title, two sentences. That's it. No pricing tables, no comparison charts.

The three features:

- **Walks log themselves.** Trot detects walks via HealthKit. Tap once to confirm; the rest is automatic.
- **Targets that fit your dog.** Beagles, Frenchies, and Labradors don't need the same exercise. Trot's targets adjust to breed, age, and health.
- **A streak worth keeping.** Track your dog's daily walking habit. One rest day a week is allowed. Skipping more breaks the streak.

### 3. CTA repeat

A second download/signup CTA at the bottom for users who scrolled past the first.

Headline: short. "Start walking your dog daily." or similar.
Same CTA button as the hero.

### Footer

- Trot logo, small, monochrome
- Links: Privacy Policy, Terms of Service, X account (build-in-the-open)
- Copyright line: "© [Year] Trot"

## What does NOT ship

- About page or about section
- Team / founder bio
- Blog
- Newsletter (separate from launch email signup)
- Long-form feature lists
- "How it works" walkthrough
- Testimonials placeholder ("Coming soon!" looks unfinished)
- Pricing (Trot is free for v1)
- FAQ
- Press / media kit
- Multiple language toggles
- Comparisons against other apps
- Any animation that is decorative rather than functional

## Tone

Same voice as the app. Plain English, no filler, no hype, no exclamation marks except in genuine moments.

The headline should sound like something a dog owner would actually say to a friend, not like marketing copy.

## Pre-launch vs post-launch

**Pre-launch (no App Store yet):**
- Primary CTA: email signup ("Get notified when Trot launches")
- Service: **Resend** (Audiences for the contact list, Send for the launch-day blast). One vendor for both signup-capture and the eventual launch email — same domain, same dashboard. Form posts to `web/api/subscribe.ts` (Vercel Edge Function), which calls Resend's contacts API.
- Small "Building in the open · X" link near the CTA, pointing at the personal handle (`@coreyrichardsn`) for v1. Worth noting that the X handle is personal, not a project handle — that's fine for build-in-the-open.

**Post-launch:**
- Primary CTA: App Store download badge (Apple's official badge from developer.apple.com/app-store/marketing/guidelines)
- Email signup retired or moved to footer
- Optional: small "★★★★★ on the App Store" if ratings hit that bar

The page should be designed once with a clear structure, with a single component swap (CTA) between pre-launch and post-launch. Don't redesign for launch.

## Tech

Simple is better.

- Plain HTML, CSS, and minimal JS
- No React, no Next, no build step
- Hosted on Vercel alongside the LLM proxy backend (same Vercel project, same domain)
- Deployment: push to main → Vercel deploys automatically
- Domain: free vercel.app subdomain for v1 build-in-the-open phase. **Real domain (`trot.dog` target, `trotapp.com` fallback) registered closer to App Store submission**, when there's something for users to actually do at the URL.
- The CSS links `design-reference/Trot Design System/colors_and_type.css` directly — that file is the single source of truth for tokens. No duplicate variable definitions in the landing page.
- **Self-host icons.** The exported landing kit currently uses Lucide via the `unpkg.com` CDN. For Lighthouse 95+ and offline-friendly rendering, extract the three icons used (`footprints`, `sliders-horizontal`, `flame`) from the Lucide npm package and inline them as SVG. Drop the CDN script tag.

## Required pages alongside the landing

Apple requires a privacy policy URL before App Store submission. Two additional small pages live in `web/`:

- `web/privacy.html` — Privacy Policy. Must cover HealthKit data handling specifically. Generate a draft from a service (termly.io, freeprivacypolicy.com) and adjust. Get a lawyer to review before App Store submission.
- `web/terms.html` — Terms of Service. Standard template adjusted for Trot.

These pages don't need fancy design — same tokens, simpler layout, prose. Linked from the footer of index.html.

## Performance and accessibility

- Page weight: under 500KB total (excluding fonts)
- Lighthouse score: 95+ on Performance, Accessibility, Best Practices, SEO
- Single hero image, optimized as WebP with PNG fallback
- Fonts: brand display face for hero only, system fonts for body. Avoid loading the full font file just for one heading.
- Accessibility: real semantic HTML (h1, h2, button, a). Alt text on every image. Color contrast hits WCAG AA.
- Mobile-first. The page is used by people on phones who want to download an iOS app — it has to be flawless on iPhone.

## The design and build flow

The Claude Design session has happened. The exported landing source lives at `design-reference/Trot Design System/ui_kits/landing/index.html`.

To deploy:

1. Copy `ui_kits/landing/index.html` → `web/index.html`
2. Update the `<link rel="stylesheet">` to reference the project copy of `colors_and_type.css` (not `../../colors_and_type.css`)
3. Copy needed assets (`dog-luna.jpg` is currently used for the phone screenshot — replace with a real Home-screen PNG once iOS skeleton renders one) to `web/assets/`
4. Inline the three Lucide icons as SVG, drop the CDN script
5. Wire the form to Resend via a small `web/api/subscribe.ts` Edge Function that calls Resend's contacts API to add the email to a "trot-launch" audience. Same Resend account holds the launch-day broadcast.
6. Add `vercel.json` for routing
7. Push to main, Vercel auto-deploys

The landing page goes live before the iOS app ships. That's the build-in-the-open value: a real URL to share on X within the first week of the project.
