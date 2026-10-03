# UI redesign — Task List (module `ui-theme`)

Detail, acceptance criteria and verification for each item are in
[plan.md](plan.md). Check items off as they land. The v1 list lives in
`tasks/todo.md` and is separate.

## Phase 1 — Foundation
- [x] T1: Color tokens and ColorScheme
- [x] T2: Method and status badges

### Checkpoint: Foundation
- [ ] `fvm flutter analyze` clean, `fvm flutter test` green
- [ ] App launches with lime primary, no layout change

## Phase 2 — Remaining theme surface
- [x] T3: Variable chip and JSON syntax colors
- [x] T4: Component themes, radii, kicker style
- [ ] T5: Logo mark

### Checkpoint: Theme complete
- [ ] analyze clean, full suite green
- [ ] All screens opened, no indigo/cyan remnants

## Phase 3 — Verify
- [ ] T6: Sweep, contrast test, side-by-side visual check

### Checkpoint: Module done
- [ ] All SPEC-ui-theme.md success criteria checked
- [ ] Human review, then write `SPEC-app-shell.md`
