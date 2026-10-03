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
- [x] W6: Body Format JSON and Invalid JSON

### Checkpoint: Request side
- [x] analyze clean, full suite green

## Phase 4 — Sidebar and keys
- [x] W7: Method chips and combined filter
- [x] W8: Sidebar rows, group headers and empty result
- [x] W9: Keyboard shortcuts

## Phase 5 — Verify
- [x] W10: Sweep and visual check (>=1100px and <1100px)

### Checkpoint: Module done
- [x] All SPEC-workspace.md success criteria checked (visual check: 1440px fully; 900px stacking verified by widget tests, the browser capture was cropped by the pane; toasts, History tab, Format JSON and shortcuts verified by tests only)
- [x] Human review, then write `SPEC-secondary-screens.md`

---

# Module `secondary-screens`

Detail in [plan-secondary-screens.md](plan-secondary-screens.md).

## Phase 1 — History
- [x] S1: `JsonStore.readAllHistory()`
- [x] S2: History screen with day groups and empty state
- [x] S3: History search, open request and deleted rows

### Checkpoint: History
- [x] analyze clean, full suite green
- [x] Sending a saved request makes it appear in History; clicking it opens it in the Workspace

## Phase 2 — Environments
- [x] S4: ACTIVE fix, PROD tag and dot colors
- [x] S5: Shared list/detail layout and Environments restyle

### Checkpoint: Environments
- [x] analyze clean, full suite green

## Phase 3 — Flows
- [x] S6: Flows list and builder restyle
- [x] S7: Flow run view restyle
- [x] S8: Step picker chips aligned with the sidebar

### Checkpoint: Flows
- [x] analyze clean, full suite green

## Phase 4 — Verify
- [x] S9: Sweep and visual check

### Checkpoint: Module done
- [x] All SPEC-secondary-screens.md success criteria checked (visual check at 1440px: History, Environments and the Flows builder in the browser; the flow run view needs a real HTTP run and is verified by widget tests only)
- [x] Human review, then write `SPEC-session-tokens.md`

---

# Module `session-tokens`

Detail in [plan-session-tokens.md](plan-session-tokens.md).

## Phase 1 — Engine rules
- [ ] K1: `Session`, `applySession` and `sessionVariables`
- [ ] K2: JWT claims and expiry
- [ ] K3: Token finder

### Checkpoint: Engine rules
- [ ] analyze clean, full suite green
- [ ] `grep -r "package:flutter" lib/engine` is empty

## Phase 2 — Behavior
- [ ] K4: `SessionRequestExecutor`
- [ ] K5: Per-environment sessions wired into send and flows

### Checkpoint: Behavior
- [ ] Sending a login stores tokens for the active environment; the next send carries them; another environment does not
- [ ] analyze clean, full suite green

## Phase 3 — UI
- [ ] K6: Header session button and popover shell
- [ ] K7: Popover contents
- [ ] K8: Capture toast
- [ ] K9: Effective variables for curl and URL highlighting

### Checkpoint: UI
- [ ] analyze clean, full suite green

## Phase 4 — Verify
- [ ] K10: Sweep and visual check

### Checkpoint: Module done
- [ ] All SPEC-session-tokens.md success criteria checked
- [ ] Human review, then write `SPEC-hosts-notes.md`
