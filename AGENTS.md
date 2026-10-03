# AGENTS.md — Synclip

Synclip is a Flutter app (Android, desktop, web) that syncs clipboard text between devices through end-to-end encrypted rooms on Supabase.

## Sources of truth

- **Product truth** (users, limits, platform rules, brand commitments): read [PRODUCT.md](PRODUCT.md) before scoping a feature.
- **Build contract** (architecture, data model, crypto protocol, design system, milestones, engineering practices): read [PLAN.md](PLAN.md). Read the section you are implementing before writing code. Its section numbers are cited below.
- **Visual truth**: the design canvas linked in PLAN.md §7, source in `design/canvas/project/`. UI matches it. A visual change updates the canvas in the same PR.
- **Decisions:** PLAN.md §8 and `docs/adr/`. A new architectural decision gets a new ADR in the same PR.

## The feature loop

Every change, however small, runs this loop. Each step's criterion must hold before you move on.

1. **Branch** from fresh `main`: `feature/<name>` for features (`feature/profile`), otherwise `fix|test|refactor|chore|docs|ci/<slug>`. *Done when* you're on a new branch with nothing uncommitted from elsewhere.
2. **Scope with ponytail.** Load the `ponytail` skill and write down the smallest change that meets the PLAN.md section. Prefer the SDK or a platform feature over a new package, and justify any new dependency in the PR body. *Done when* the scope fits one PR of about 400 changed lines or fewer.
3. **Red first.** For logic, load the `tdd` skill and write the failing test before the code: crypto, sync engine, join flow, detectors, guards, SQL policies and RPCs (pgTAP). A bug fix starts with a test that goes red on the bug. *Done when* the new test is red for the right reason.
4. **Green, then refactor.** Implement until green. Then remove duplication at its third occurrence and not before. *Done when* `dart format`, `flutter analyze` (zero issues) and every test pass locally.
5. **Self-review.** Run `ponytail-review` on the diff and apply its cuts. These never remove tests, security checks, RLS or accessibility semantics. If the diff touches `lib/core/crypto`, `lib/core/security`, auth, `supabase/migrations` or `supabase/functions`, also run `/security-review`, add the `security` label, and update PLAN.md §4.2 if the threat model moved. *Done when* both reviews leave no open finding.
6. **Open the PR.** Use a Conventional Commit title and fill in the PR template: what/why, milestone, test evidence, light + dark screenshots for UI, and the security checklist. *Done when* the PR is open and CI has started.
7. **Converge.** Fix every failing check. Answer every CodeRabbit comment, either with a fix commit or a reasoned reply. *Done when* CI is green and no CodeRabbit thread is unresolved.
8. **Hand off.** Report the PR link and anything left for the owner to decide. **The owner merges**; your work on this PR ends here.

At the end of a milestone, run `ponytail-debt` and record deferred shortcuts in `docs/debt.md`.

## Hard guardrails

- **PR-only:** every change reaches `main` through a reviewed PR. Commit only on feature branches. Leave merging, force-pushing `main` and branch-protection changes to the owner.
- **Owner authorship:** commits and PR bodies carry the owner's git identity only. Write messages without `Co-Authored-By` trailers or "Generated with" lines.
- **Secrets:** keep them in `.env` (gitignored), GitHub Environments, or Edge Function secrets. The app ships only the Supabase anon key; the service-role key lives server-side only.
- **Clip content and keys never leave the crypto boundary in plaintext:** no logging, analytics or error reports containing them, and no plaintext columns.
- **Schema changes** go only through `supabase/migrations/`. Each new table has RLS enabled and ships with allow + deny pgTAP tests.

## Code rules (reference)

- **Layers** (PLAN.md §6.2): `presentation → application → domain ← data`. `domain/` and `core/crypto/` import neither Flutter nor Supabase.
- **Platform access** goes through ports: clipboard via `ClipboardPort` in `core/clipboard/`, Android/desktop specifics via `core/platform/`.
- **Theme:** components read `ColorScheme` roles and `app/theme/tokens.dart`; raw hex values exist only in `tokens.dart`.
- **Limits** come from the room row (PLAN.md §1.3, §5). Clients read them; they never hard-code them.
- **Randomness** in crypto code comes from `Random.secure()` or the `cryptography` package.
- **Accessibility:** 48 dp targets, semantics labels on icon-only controls, layouts that survive 200% text, and every animation honouring `MediaQuery.disableAnimations` (PLAN.md §7.7–7.9).
- **Copy** follows PLAN.md §7.8: plain, short, never over-claiming security.

## Commands

CI workflows in `.github/workflows/` are authoritative. Mirror them locally: `dart format .`, `flutter analyze`, `flutter test`, `supabase start && supabase test db`, `deno test` (in `supabase/functions/`).
