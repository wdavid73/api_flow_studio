# Implementation Plan: UI redesign — module `app-shell`

Spec: [SPEC-app-shell.md](../../SPEC-app-shell.md). Depends on `ui-theme`
(done). Checklist lives in [todo.md](todo.md). The `ui-theme` plan is in
[plan.md](plan.md).

## Overview

Replace the nav bar, environment dropdown and per-environment color strip
with the playground-style header, a segmented environment pill, a
production-only red strip, and add a banner and a toast that any screen can
trigger. No engine changes; destination screens are untouched.

## Architecture Decisions

- **Defaults for the two open questions** (the user said "siga" without
  choosing): subtitle is **"API playground"** (matches the HTML); more than
  4 environments overflow into a `…` menu. Both are one-line changes later.
- **Slices swap one existing piece at a time** (strip → pill → header), each
  wired into the live `AppShell`, so the app works after every task.
- **New code lives in `lib/ui/shell/`**; the old widgets in
  `lib/ui/environments/` are deleted in the task that replaces them, never
  left alongside.
- **Toast and banner are Riverpod state + a host widget in `AppShell`**, so
  any screen uses them via `ref` with no `BuildContext` plumbing.
- **Existing `Key`s are kept** (`environment-switcher`,
  `active-environment-strip`) so tests keep finding the same things.

## Dependency graph

```
S1 production rule + strip
 └── S2 environment pill
      └── S3 header (nav, brand, actions zone, gradient)
           ├── S4 toast
           └── S5 banner
                └── S6 sweep + visual check
```
S4 and S5 are independent of each other; both need the header/shell host
from S3.

## Task List

### Phase 1: Environment signals
- [x] S1: Production rule and red strip
- [x] S2: Segmented environment pill

### Checkpoint: Environment signals
- [x] analyze clean, full suite green
- [x] Switching environments in the pill changes variable resolution as before (setActive covered by pill tests; resolution by variable_interpolation_test)

### Phase 2: Header and feedback
- [x] S3: Header with brand, nav, actions zone and background
- [x] S4: Toast
- [x] S5: Banner

### Checkpoint: Shell complete
- [x] analyze clean, full suite green
- [x] No references to `EnvironmentSwitcher` / `ActiveEnvironmentStrip`

### Phase 3: Verify
- [ ] S6: Sweep and visual check (≥1100px and <1100px)

### Checkpoint: Module done
- [ ] All SPEC-app-shell.md success criteria checked
- [ ] Human review, then write `SPEC-workspace.md`

---

## S1: Production rule and red strip

**Description:** Add `isProductionEnvironment(name)` and a `ProductionStrip`
that replaces `ActiveEnvironmentStrip`: 3px `error` bar only when the
active environment is prod, height 0 otherwise. Wire it in `AppShell`.

**Acceptance criteria:**
- [ ] `isProductionEnvironment` true for `prod`, `PROD`, ` Production `, `prd`; false for `staging`, `preprod`, `product`, empty.
- [ ] Strip is `error`-colored with prod active; height 0 with another or no environment.
- [ ] `Key('active-environment-strip')` kept; `ActiveEnvironmentStrip` file deleted.

**Verification:**
- [ ] `fvm flutter test test/ui/shell test/ui/request_builder/variable_interpolation_test.dart` (the strip-color test there is rewritten for the new rule)
- [ ] `fvm flutter analyze`

**Dependencies:** none

**Files likely touched:** `lib/ui/shell/environment_kind.dart`,
`lib/ui/shell/production_strip.dart`, `lib/app.dart`, delete
`lib/ui/environments/active_environment_strip.dart`,
`test/ui/shell/environment_kind_test.dart`,
`test/ui/shell/production_strip_test.dart`,
`test/ui/request_builder/variable_interpolation_test.dart`

**Estimated scope:** Medium (7 files, mostly small)

## S2: Segmented environment pill

**Description:** `EnvironmentPill` replaces `EnvironmentSwitcher`: a rounded
pill with one button per environment (active = `primary`/`onPrimary`, active
prod = `error`/`onError`). With more than 4 environments the first 3 show
and the rest go in a `…` menu. Tapping calls
`environmentsProvider.notifier.setActive`. Hidden with no environments.

**Acceptance criteria:**
- [ ] One button per environment up to 4; 5+ → 3 buttons + `…` menu listing the rest.
- [ ] Active button colors as specified; tapping another changes the active environment.
- [ ] Hidden when the list is empty; `Key('environment-switcher')` kept.
- [ ] `EnvironmentSwitcher` file deleted.

**Verification:**
- [ ] `fvm flutter test test/ui/shell test/ui/app_shell_test.dart`
- [ ] `fvm flutter analyze`
- [ ] Manual: create 3 environments, switch, check variable resolution on Send

**Dependencies:** S1

**Files likely touched:** `lib/ui/shell/environment_pill.dart`, `lib/app.dart`,
delete `lib/ui/environments/environment_switcher.dart`,
`test/ui/shell/environment_pill_test.dart`, `test/ui/app_shell_test.dart`

**Estimated scope:** Medium (5 files)

## S3: Header, actions zone and background

**Description:** Move the nav bar out of `app.dart` into `AppHeader`: logo
mark, "API Flow Studio" with subtitle "API playground", the four
destination pills, the environment pill, and an empty actions zone on the
right. Add `HeaderGhostButton` for later modules. Draw the radial lime
gradient behind the shell. Below 1100px the header wraps.

**Acceptance criteria:**
- [ ] Header shows brand, subtitle, 4 destinations (active highlighted), pill, actions zone.
- [ ] `HeaderGhostButton` renders with `outlineVariant` border and radius 10; a test puts one in the actions zone.
- [ ] At width 900 the header wraps without overflow errors; at 1440 it is a single row.
- [ ] Navigation still switches destinations (existing test green).

**Verification:**
- [ ] `fvm flutter test test/ui/shell test/ui/app_shell_test.dart`
- [ ] `fvm flutter analyze`
- [ ] Manual: header at 1440px and 900px

**Dependencies:** S2

**Files likely touched:** `lib/ui/shell/app_header.dart`,
`lib/ui/shell/header_ghost_button.dart`, `lib/app.dart`,
`test/ui/shell/app_header_test.dart`, `test/ui/app_shell_test.dart`

**Estimated scope:** Medium (5 files)

## S4: Toast

**Description:** `toastProvider`, `showToast(ref, message)` and a
`ToastHost` in `AppShell`: lime pill at the bottom center, fade + 12px
slide over 160ms, hidden after 2200ms, a new toast replaces the previous
one and restarts the timer, never intercepts pointer events.

**Acceptance criteria:**
- [ ] `showToast` makes the message visible; it is gone after 2200ms (`tester.pump`).
- [ ] A second toast replaces the first and the timer restarts.
- [ ] Toast ignores pointer events (tap through works).

**Verification:**
- [ ] `fvm flutter test test/ui/shell/app_toast_test.dart`
- [ ] `fvm flutter analyze`

**Dependencies:** S3

**Files likely touched:** `lib/ui/shell/app_toast.dart`, `lib/app.dart`,
`test/ui/shell/app_toast_test.dart`

**Estimated scope:** Small (3 files)

## S5: Banner

**Description:** `bannerProvider` (`AppBanner(message, kind)`, `warning` or
`info`) and a `BannerHost` below the header: full width, 13px, bottom
border, code fragments in JetBrains Mono; null takes no space.

**Acceptance criteria:**
- [ ] null → zero height; `warning` uses `bannerBackground`/`warning`; `info` uses `infoBackground`/`onSurfaceVariant`.
- [ ] Setting then clearing the provider shows then hides it.

**Verification:**
- [ ] `fvm flutter test test/ui/shell/app_banner_test.dart`
- [ ] `fvm flutter analyze`

**Dependencies:** S3

**Files likely touched:** `lib/ui/shell/app_banner.dart`, `lib/app.dart`,
`test/ui/shell/app_banner_test.dart`

**Estimated scope:** Small (3 files)

## S6: Sweep and visual check

**Description:** Confirm nothing references the removed widgets, the whole
suite is green, and compare the running app with the HTML header.

**Acceptance criteria:**
- [ ] No hits for `EnvironmentSwitcher` / `ActiveEnvironmentStrip` in `lib/` or `test/`.
- [ ] Header checked at ≥1100px and <1100px with a prod environment and a non-prod one.
- [ ] A throwaway call to `showToast` and `bannerProvider` shown once on screen, then removed.

**Verification:**
- [ ] `fvm flutter analyze` and `fvm flutter test`
- [ ] `fvm flutter run -d windows` or the web preview at 1440px

**Dependencies:** S4, S5

**Files likely touched:** none expected beyond fixes found

**Estimated scope:** Small

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Tests that look up the old switcher or strip break | Med | Keys are kept; tests are updated in the same task, not deleted |
| `DropdownButton` → pill changes how a test selects an environment | Med | S2 updates `app_shell_test`; verified before commit |
| Header wrap hides content below 1100px | Low | Explicit width-900 test in S3 |
| Prod detection by name misses an unusual name | Low | Open to the "is production" checkbox later; spec lists it under Ask first |
| Toast timers leak between tests | Low | Use a cancellable `Timer` and cancel in `ref.onDispose` |

## Open Questions

None blocking. Subtitle ("API playground") and the `…` overflow menu are
defaults chosen without an answer; say so if you want either changed.
