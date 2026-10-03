# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Stack

Flutter (Dart), one codebase shipping to Android (primary), desktop (Windows / macOS / Linux) and web. Material 3 is the design language on every target. Backend: Supabase (Realtime Broadcast + Presence, Postgres with RLS, Auth, Edge Functions, pg_cron). State management: delegated — Riverpod, feature-first folders (chosen for testability and compile-safe providers; see PLAN.md ADR-004).

## Users

People who move text between their own devices many times a day — students and developers copying links, commands, notes and snippets between a phone and a laptop — plus small ad-hoc groups (classmates, a teammate at the next desk) who need to pass text between devices that are not theirs for a short time.

## Product Purpose

Synclip gives non-Apple device mixes (Android + Windows/Linux/Mac + any browser) something close to Apple's Universal Clipboard: copy on one device, paste on another. Success means a clip reaches every other device in the room in under a second while they are open, and a device that was closed catches up the moment it opens.

## Positioning

Two ways in, one mechanism: a **Quick Room** joined with a 6-character code, QR or link (no account), and **My Devices**, a permanent room bound to an email/Google account. Every clip is end-to-end encrypted: the server relays and stores only ciphertext, and a new device receives the room key only after an existing device approves it.

## Operating Context

- Phone in hand mid-task; laptop or desktop on a desk; sometimes a borrowed or lab computer through the web client.
- Android cannot read the clipboard in the background, so sending from Android is an explicit gesture: Quick Settings tile, share sheet, or auto-send when the app opens. Android receives only while the app is open; history covers the gaps.
- Desktop runs in the system tray, watches the clipboard automatically (pausable), writes incoming clips straight to the clipboard, and launches at startup.
- The web client can't read the clipboard freely: it sends through paste and copies through a button.

## Capabilities and Constraints

- Content in v1: plain text and URLs (link previews fetched by the receiving device; none on web because of CORS). No images or files.
- Quick Room: up to 5 devices, expires 10 h after last activity, keeps the last 20 clips, 50 KB per clip.
- My Devices: up to 10 devices, permanent, keeps the last 50 clips for 7 days each, 100 KB per clip.
- Sensitive clips (password-manager flags, detected card numbers / OTPs / secrets after a prompt) are relayed live but never stored in history.
- Supabase free tier: 200 concurrent connections, 256 KB broadcast payload, project pauses after 7 idle days.

## Brand Commitments

- Name: **Synclip**.
- Material 3 with a custom brand layer (own type, card shapes, a "device ring" signature visual, custom motion on key moments).
- Theming: brand accent by default, optional wallpaper Dynamic Color on Android 12+, 6–8 preset accents, light/dark following the system with manual override.
- Motion: rich, but spent on three signature moments (clip arrival/send, device joining the ring, approval sheet); everything else quick M3 transitions with haptics on send/receive.

## Evidence on Hand

None yet: no users, testimonials, benchmarks or assets. Nothing like that may be fabricated in store listings, README or onboarding.

## Product Principles

1. **The clip is the product.** Every screen gets the newest clip in front of the user in one glance and one tap.
2. **Trust is earned in the UI.** Approvals, emoji verification and "end-to-end encrypted" statements are honest and visible; never claim more privacy than the protocol gives.
3. **Respect the platform's limits.** Do what Android, desktop and web each actually allow; don't fake background magic that breaks.
4. **Ephemeral by default.** Quick Rooms and history expire; sensitive clips never persist.
5. **Learning project, production habits.** Clean architecture, tests on the security-critical parts, no shortcuts that would have to be unlearned.

## Accessibility & Inclusion

48 dp touch targets; text scales to 200% without clipping; every state (online, sending, failed, expiring) is readable without colour; emoji verification also announced as words for screen readers; the system "remove animations" setting replaces signature motion with crossfades.
