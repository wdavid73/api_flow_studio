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
- [x] S1: Production rule and red strip
- [x] S2: Segmented environment pill

### Checkpoint: Environment signals
- [x] analyze clean, full suite green
- [x] Switching environments in the pill changes variable resolution as before (setActive covered by pill tests; resolution by variable_interpolation_test)

## Phase 2 — Header and feedback
- [x] S3: Header with brand, nav, actions zone and background
- [x] S4: Toast
- [x] S5: Banner

### Checkpoint: Shell complete
- [x] analyze clean, full suite green
- [x] No references to `EnvironmentSwitcher` / `ActiveEnvironmentStrip`

## Phase 3 — Verify
- [x] S6: Sweep and visual check (>=1100px and <1100px)

### Checkpoint: Module done
- [x] All SPEC-app-shell.md success criteria checked (red prod state verified by widget tests only: the app has no environment rename, so it could not be shown in the browser)
- [x] Human review, then write `SPEC-workspace.md`

---

# Module `workspace`

Detail in [plan-workspace.md](plan-workspace.md).

## Phase 1 — Foundations
- [x] W1: `buildCurl` in the engine
- [x] W2: Three-panel layout

### Checkpoint: Layout
- [x] analyze clean, full suite green
- [x] 1440px shows three panels, 900px stacks the response

## Phase 2 — Response side
- [x] W3: Response status line, Copy and curl
- [x] W4: History inside the response panel

### Checkpoint: Response side
- [x] analyze clean, full suite green

## Phase 3 — Request side
- [x] W5: Request header, URL bar and pill tabs
- [ ] W6: Body Format JSON and Invalid JSON

### Checkpoint: Request side
- [ ] analyze clean, full suite green

## Phase 4 — Sidebar and keys
- [ ] W7: Method chips and combined filter
- [ ] W8: Sidebar rows, group headers and empty result
- [ ] W9: Keyboard shortcuts

## Phase 5 — Verify
- [ ] W10: Sweep and visual check (>=1100px and <1100px)

### Checkpoint: Module done
- [ ] All SPEC-workspace.md success criteria checked
- [ ] Human review, then write `SPEC-secondary-screens.md`
