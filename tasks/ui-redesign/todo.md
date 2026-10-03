# UI redesign — Task List (module `ui-theme`)

Detail, acceptance criteria and verification for each item are in
[plan.md](plan.md). Check items off as they land. The v1 list lives in
`tasks/todo.md` and is separate.

## Phase 1 — Foundation
- [x] T1: Color tokens and ColorScheme
- [x] T2: Method and status badges

### Checkpoint: Foundation
- [x] `fvm flutter analyze` clean, `fvm flutter test` green
- [x] App launches with lime primary, no layout change

## Phase 2 — Remaining theme surface
- [x] T3: Variable chip and JSON syntax colors
- [x] T4: Component themes, radii, kicker style
- [x] T5: Logo mark

### Checkpoint: Theme complete
- [x] analyze clean, full suite green
- [x] All screens opened, no indigo/cyan remnants (empty states only)

## Phase 3 — Verify
- [x] T6: Sweep, contrast test, side-by-side visual check

### Checkpoint: Module done
- [x] All SPEC-ui-theme.md success criteria checked
- [x] Human review, then write `SPEC-app-shell.md`

---

# Module `app-shell`

Detail in [plan-app-shell.md](plan-app-shell.md).

## Phase 1 — Environment signals
- [ ] S1: Production rule and red strip
- [ ] S2: Segmented environment pill

### Checkpoint: Environment signals
- [ ] analyze clean, full suite green
- [ ] Switching environments in the pill changes variable resolution as before

## Phase 2 — Header and feedback
- [ ] S3: Header with brand, nav, actions zone and background
- [ ] S4: Toast
- [ ] S5: Banner

### Checkpoint: Shell complete
- [ ] analyze clean, full suite green
- [ ] No references to `EnvironmentSwitcher` / `ActiveEnvironmentStrip`

## Phase 3 — Verify
- [ ] S6: Sweep and visual check (>=1100px and <1100px)

### Checkpoint: Module done
- [ ] All SPEC-app-shell.md success criteria checked
- [ ] Human review, then write `SPEC-workspace.md`
