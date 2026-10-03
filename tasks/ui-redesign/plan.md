# Implementation Plan: UI redesign — module `ui-theme`

Specs: [SPEC-ui-redesign.md](../../SPEC-ui-redesign.md) (capability map) ·
[SPEC-ui-theme.md](../../SPEC-ui-theme.md) (this module).
Separate from the v1 plan in `tasks/plan.md` / `tasks/todo.md`, which still
has open items and is not touched.

## Overview

Swap the app's palette from indigo/cyan to the Commodo lime-on-dark system
from `commodo-api-playground.html`, keeping Geist / JetBrains Mono and the
public names of `AppColors` / `AppTypography` so the 27 consumer files keep
compiling. No layout or engine changes. This plan covers only `ui-theme`;
`app-shell`, `workspace`, `secondary-screens`, `session-tokens`,
`hosts-notes` get their own spec, then plan, in dependency order.

## Architecture Decisions

- **Keep member names, change values.** `AppColors.primary` stays `primary`
  but becomes `#D6FF4A`. Avoids touching every screen; reviewers see one
  diff of tokens.
- **Existing `AppRadius` values are not changed** (changing them would shift
  every screen's look in this module). New radii from the HTML are added as
  new names: `field` 10, `dialog` 16, `block` 12.
- **`MethodBadge` becomes colored mono text without a filled pill**, as in
  the HTML sidebar. Existing tests asserting the 12% fill are updated.
- **Slices are vertical per widget family**, each leaving the app
  compiling, analyzed, and with a green suite.
- **Semantic extras** (`warning`, `kicker`, response bg, banner bg) are
  added to `AppColors`/`AppTypography`, not hardcoded in widgets.

## Dependency graph

```
T1 tokens + ColorScheme
 ├── T2 method/status badges
 ├── T3 variable chip + JSON syntax
 ├── T4 ThemeData components + radii + kicker
 └── T5 logo mark
        └── T6 sweep: no stale hex, contrast test, visual check
```
T2–T5 are independent of each other and only need T1. T6 needs all of them.

## Task List

### Phase 1: Foundation
- [x] T1: Color tokens and ColorScheme
- [x] T2: Method and status badges

### Checkpoint: Foundation
- [ ] `fvm flutter analyze` clean, `fvm flutter test` green
- [ ] App launches; shell shows lime primary, no layout change

### Phase 2: Remaining theme surface
- [ ] T3: Variable chip and JSON syntax colors
- [ ] T4: Component themes, radii, kicker style
- [ ] T5: Logo mark

### Checkpoint: Theme complete
- [ ] analyze clean, full suite green
- [ ] Every existing screen opened once, no indigo/cyan remnants

### Phase 3: Verify
- [ ] T6: Sweep, contrast test, side-by-side visual check

### Checkpoint: Module done
- [ ] All SPEC-ui-theme.md success criteria checked
- [ ] Human review, then write `SPEC-app-shell.md`

---

## T1: Color tokens and ColorScheme

**Description:** Replace values in `AppColors` with the mapping table of
SPEC-ui-theme.md (surfaces, text, accent, error, ok, derived
secondary/containers) and add `warning`. Keep all existing member names.
Update `AppTheme.dark()` to use them.

**Acceptance criteria:**
- [ ] Every row of the spec's token table matches its hex in `AppColors`.
- [ ] `AppColors.warning == #FFD27A` exists; `outlineVariant` is `#2B2D26`.
- [ ] `ThemeData.colorScheme` maps surface/primary/secondary/tertiary/error to the tokens.

**Verification:**
- [ ] `fvm flutter test test/ui/theme` (test updated: tokens asserted by hex)
- [ ] `fvm flutter analyze`
- [ ] `fvm flutter test` — update any other test that hardcodes old colors, don't delete

**Dependencies:** none

**Files likely touched:** `lib/ui/theme/app_colors.dart`,
`lib/ui/theme/app_theme.dart`, `test/ui/theme/app_theme_test.dart`

**Estimated scope:** Small (3 files)

## T2: Method and status badges

**Description:** Update method colors (GET `#9DFFB0`, POST `#9EC1FF`, PUT
`#FFD27A`, PATCH `#FFB86B`, DELETE `#FF8D8D`) and status colors (2xx
`#B6F25C`, 3xx `#9EC1FF`, 4xx `#FFD27A`, 5xx `#FF6B4A`). `MethodBadge`
renders colored mono text with no filled pill; `StatusBadge` keeps a tinted
chip. `MethodBadge.colorForMethod` API unchanged.

**Acceptance criteria:**
- [ ] 5 method colors + `methodOther` verified by tests.
- [ ] 4 status bands verified by tests.
- [ ] Method badge has no background fill.
- [ ] Add-step picker filter chips (use `colorForMethod`) still compile and render.

**Verification:**
- [ ] `fvm flutter test test/ui/theme test/ui/flows test/ui/collections`
- [ ] `fvm flutter analyze`

**Dependencies:** T1

**Files likely touched:** `lib/ui/theme/app_colors.dart`,
`lib/ui/theme/widgets/method_badge.dart`,
`lib/ui/theme/widgets/status_badge.dart`, `test/ui/theme/app_theme_test.dart`

**Estimated scope:** Small (4 files)

## T3: Variable chip and JSON syntax colors

**Description:** Resolved `{{var}}` = accent tint, unresolved = `warning`
tint. JSON syntax: key `#D6FF4A`, string `#FFD7A8`, number `#9EC1FF`,
bool/null `#FF8D8D`; response bg `#14160F`, code block bg `#0C0D0A`.

**Acceptance criteria:**
- [ ] `variableResolved*` / `variableUnresolved*` tokens updated; chip tests green.
- [ ] `json_syntax` token colors follow the spec table; `json_syntax_test` updated.
- [ ] No raw hex in the widgets; all via `AppColors`.

**Verification:**
- [ ] `fvm flutter test test/ui/theme test/ui/request_builder test/ui/response_viewer`
- [ ] `fvm flutter analyze`

**Dependencies:** T1

**Files likely touched:** `app_colors.dart`, `widgets/variable_chip.dart`,
`widgets/json_syntax.dart`, `test/ui/theme/json_syntax_test.dart`,
`test/ui/theme/app_theme_test.dart`

**Estimated scope:** Medium (5 files)

## T4: Component themes, radii, kicker style

**Description:** In `AppTheme.dark()` add themes for inputs (10px radius,
`surface` fill, `outlineVariant` border, primary focus ring), filled/ghost
buttons (primary = lime on `onPrimary`), dialogs (16px), tab bar, tooltip,
divider. Add `AppRadius.field/dialog/block` and `AppTypography.kicker`
(11px, 0.08em tracking) plus the 18px / -0.03em title tweak. Existing radius
values unchanged.

**Acceptance criteria:**
- [ ] `ThemeData` exposes the component themes; test asserts input radius 10, dialog radius 16, primary button colors.
- [ ] Existing `AppRadius` values unchanged; new names added.
- [ ] Font families still `Geist` / `JetBrains Mono`.

**Verification:**
- [ ] `fvm flutter test test/ui`
- [ ] `fvm flutter analyze`
- [ ] Manual: request bar and environment manager show lime focus/primary

**Dependencies:** T1

**Files likely touched:** `app_theme.dart`, `app_spacing.dart`,
`app_typography.dart`, `test/ui/theme/app_theme_test.dart`

**Estimated scope:** Small–Medium (4 files)

## T5: Logo mark

**Description:** `AppLogoMark` becomes the HTML mark: lime rounded square
(radius ≈ 29% of size) with two dark `#141A08` dots. Remove the hardcoded
indigo/cyan constants.

**Acceptance criteria:**
- [ ] No `_indigo` / `_cyan` / old background constants left in `app_logo.dart`.
- [ ] Mark scales with `size`; widget test renders it at 28 and 56.

**Verification:**
- [ ] `fvm flutter test test/ui`
- [ ] Manual: header shows the new mark

**Dependencies:** T1

**Files likely touched:** `lib/ui/theme/widgets/app_logo.dart`, new
`test/ui/theme/app_logo_test.dart`

**Estimated scope:** Small (2 files)

## T6: Sweep, contrast test, visual check

**Description:** Remove any leftover old palette values, add a contrast test,
run the app and compare every screen with the HTML.

**Acceptance criteria:**
- [ ] A search for `6366F1|06B6D4|C0C1FF|8083FF|4CD7F6` (any casing) in `lib/` is empty.
- [ ] Contrast test: `onPrimary` on `primary` ≥ 4.5:1 and `onSurface` on `surface` ≥ 4.5:1.
- [ ] Workspace, Environments, Flows, run view, History each opened and compared side by side with the HTML.

**Verification:**
- [ ] `fvm flutter analyze` and `fvm flutter test` (whole suite)
- [ ] `fvm flutter run -d windows` manual pass

**Dependencies:** T2, T3, T4, T5

**Files likely touched:** `test/ui/theme/contrast_test.dart`, any stragglers
found by the search (expected 0–3 files)

**Estimated scope:** Small

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Other tests assert old colors or the badge fill | Med | Update them in the task that changes the color; never delete |
| Lime on dark text contrast at small sizes | Med | Contrast test in T6; body text stays `onSurface`, lime only for accent |
| Method badge without pill hurts the Flows picker | Low | `colorForMethod` is unchanged; check picker visually in T2 |
| Hidden hardcoded `Colors.*` in screens | Low | T6 search; fix in place and report |
| Derived colors (secondary etc.) look off | Low | Spec-approved values; adjust in T1 if the visual check disagrees |

## Open Questions

None for this module. Next: review this plan, then write `SPEC-app-shell.md`.
