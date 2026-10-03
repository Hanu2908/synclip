## What and why

<!-- One focused change. Link the PLAN.md section or milestone it implements. -->

Milestone: M_

## How it was tested

<!-- New or changed tests, and what you ran. For UI: light + dark screenshots. -->

## Checklist

- [ ] Title is a Conventional Commit (`feat(scope): …`, `fix: …`, `ci: …`)
- [ ] Built with `ponytail`; `ponytail-review` run on the diff
- [ ] Tests written first for logic; CI green
- [ ] UI matches the design canvas; 200% text and dark theme checked
- [ ] Docs / ADR updated if behaviour or a decision changed

## Security (fill in if crypto, auth, `supabase/migrations` or `supabase/functions` changed)

- [ ] `security` label added and `/security-review` run
- [ ] New tables have RLS + allow/deny pgTAP tests
- [ ] No secrets, keys or clip plaintext logged or stored
- [ ] Threat model (PLAN.md §4.2) updated if it changed
