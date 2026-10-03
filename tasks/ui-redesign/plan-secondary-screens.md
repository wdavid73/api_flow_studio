# Implementation Plan: UI redesign — module `secondary-screens`

Spec: [SPEC-secondary-screens.md](../../SPEC-secondary-screens.md). Depends
on `ui-theme` and `app-shell` (done). Checklist in [todo.md](todo.md).
Earlier plans: [plan.md](plan.md), [plan-app-shell.md](plan-app-shell.md),
[plan-workspace.md](plan-workspace.md).

## Overview

Make Environments, Flows (builder and run view) and History look like the
Workspace, turn the History destination into a global history screen, and
fix the misleading `ACTIVE` tag in Environments. Logic stays as it is; the
only engine change is the additive `JsonStore.readAllHistory()`.

## Architecture Decisions

- **Defaults for the two open questions** (approved with "apruebo" without
  changing them): history rows take method/name/URL from the saved request
  (deleted requests show `Deleted request`), and there is **no** clear-history
  button.
- **Behavior before looks.** The `ACTIVE` fix and prod marking (S4) land
  before any restyle, so a visual refactor can't hide a logic regression.
- **One shared layout, introduced where it is first used.**
  `ListDetailLayout` is created in S5 with Environments and reused by Flows
  in S6, instead of being built speculatively.
- **History is built read-only first** (list, grouping, empty state), then
  search and navigation, so each slice is demonstrable on its own.
- **No new fields on any model**; existing keys are kept.

## Dependency graph

```
S1 readAllHistory (engine)
 └── S2 History screen: list, day groups, empty state
      └── S3 History: search, open request, deleted rows
S4 Environments: ACTIVE fix, PROD tag, dot colors
 └── S5 ListDetailLayout + Environments restyle
      └── S6 Flows list + builder restyle
           ├── S7 Flow run view restyle
           └── S8 Step picker chips aligned
                └── S9 sweep + visual check
```
S1–S3 (History) and S4–S8 (Environments/Flows) are independent chains; S9
needs both.

## Task List

### Phase 1: History
- [x] S1: `JsonStore.readAllHistory()`
- [x] S2: History screen with day groups and empty state
- [x] S3: History search, open request and deleted rows

### Checkpoint: History
- [x] analyze clean, full suite green
- [x] Sending a saved request makes it appear in History; clicking it opens it in the Workspace

### Phase 2: Environments
- [ ] S4: ACTIVE fix, PROD tag and dot colors
- [ ] S5: Shared list/detail layout and Environments restyle

### Checkpoint: Environments
- [ ] analyze clean, full suite green

### Phase 3: Flows
- [ ] S6: Flows list and builder restyle
- [ ] S7: Flow run view restyle
- [ ] S8: Step picker chips aligned with the sidebar

### Checkpoint: Flows
- [ ] analyze clean, full suite green

### Phase 4: Verify
- [ ] S9: Sweep and visual check

### Checkpoint: Module done
- [ ] All SPEC-secondary-screens.md success criteria checked
- [ ] Human review, then write `SPEC-session-tokens.md`

---

## S1: `JsonStore.readAllHistory()`

**Description:** Public method returning every stored history entry across
all endpoints as a flat list, newest first. Works for the disk store and
`JsonStore.inMemory()`.

**Acceptance criteria:**
- [ ] Empty store → empty list.
- [ ] Entries of several endpoints come back mixed, sorted by `timestamp` descending.
- [ ] Existing per-endpoint behavior (`readHistory`, trimming to 20) unchanged.
- [ ] No `package:flutter` import under `lib/engine`.

**Verification:**
- [ ] `fvm flutter test test/engine/storage`
- [ ] `fvm flutter analyze`

**Dependencies:** none

**Files likely touched:** `lib/engine/storage/json_store.dart`,
`test/engine/storage/history_store_test.dart`

**Estimated scope:** Small (2 files)

## S2: History screen with day groups and empty state

**Description:** `HistoryScreen` replaces the placeholder: kicker `HISTORY`,
title `Request history`, rows grouped by day (`TODAY`, `YESTERDAY`, or
`YYYY-MM-DD`). Each row: `MethodBadge`, request name, URL in muted mono,
then `StatusBadge` (or `Error` in `error` color), `N ms` and `HH:mm`. Data
comes from `allHistoryProvider` (reads `readAllHistory`, joins each entry to
its request in the collections). Empty state `No history yet — send a saved
request.`

**Acceptance criteria:**
- [ ] Rows show method, name, URL, status, elapsed and time for stored entries, newest first.
- [ ] Day headers group entries, with `TODAY` / `YESTERDAY` / ISO date.
- [ ] A failed send shows `Error`.
- [ ] Empty store shows the empty message.
- [ ] The History nav destination renders `HistoryScreen` (placeholder gone).
- [ ] Sending a saved request refreshes the list.

**Verification:**
- [ ] `fvm flutter test test/ui/history test/ui/app_shell_test.dart`
- [ ] `fvm flutter analyze`

**Dependencies:** S1

**Files likely touched:** `lib/ui/history/history_screen.dart`,
`lib/ui/history/history_row.dart`, `lib/ui/history/all_history_provider.dart`,
`lib/app.dart`, `test/ui/history/history_screen_test.dart`

**Estimated scope:** Medium (5 files)

## S3: History search, open request and deleted rows

**Description:** Search field `Filter history…` (name, method, URL) with
`Nothing matches that search.` when empty. Tapping a row loads its endpoint
into the request draft and switches the destination to Workspace. A row whose
request no longer exists shows `Deleted request` and is not tappable.

**Acceptance criteria:**
- [ ] Search narrows rows by name, method and URL, case-insensitively.
- [ ] No matches → message; no history at all → the empty message from S2.
- [ ] Tapping a row loads that endpoint and selects `AppDestination.workspace`.
- [ ] Deleted-request rows show `Deleted request`, no method/URL, and ignore taps.

**Verification:**
- [ ] `fvm flutter test test/ui/history`
- [ ] `fvm flutter analyze`

**Dependencies:** S2

**Files likely touched:** `lib/ui/history/history_screen.dart`,
`lib/ui/history/history_row.dart`, `test/ui/history/history_screen_test.dart`

**Estimated scope:** Small (3 files)

## S4: ACTIVE fix, PROD tag and dot colors

**Description:** In the Environments list, `ACTIVE` shows only on the
environment equal to `activeEnvironmentId` (today it shows on the one
*selected in the editor*). Production environments get a `PROD` tag in
`error` color. The color dot is `error` for prod and otherwise cycles
`primary`, `tertiary`, `secondary`; `AppColors.environmentDotPalette`
changes accordingly.

**Acceptance criteria:**
- [ ] With environment A active and B selected in the editor, only A shows `ACTIVE`.
- [ ] With none active, no row shows `ACTIVE`.
- [ ] A prod-named environment shows `PROD` and a red dot; non-prod environments never have a red dot.
- [ ] Selecting a row still doesn't change the active environment.

**Verification:**
- [ ] `fvm flutter test test/ui/environments test/ui/theme`
- [ ] `fvm flutter analyze`

**Dependencies:** none

**Files likely touched:** `lib/ui/environments/environment_manager_screen.dart`,
`lib/ui/theme/app_colors.dart`,
`test/ui/environments/environment_manager_screen_test.dart`,
`test/ui/theme/app_theme_test.dart`

**Estimated scope:** Small (4 files)

## S5: Shared list/detail layout and Environments restyle

**Description:** `ListDetailLayout` (300px list panel with `outlineVariant`
right border, kicker header + ghost create button slot, flexible detail).
Environments uses it: rows with `surfaceContainerHigh` selection and
`surfaceContainer` hover (no side bar), editor with title, `kicker` table
header (`NAME`, `VALUE`, `SECRET`), themed fields, ghost `Add variable`, and
the tip card on `surfaceContainer`.

**Acceptance criteria:**
- [ ] List panel is 300px wide with the kicker header `ENVIRONMENTS`.
- [ ] Selected row `surfaceContainerHigh`; no left color bar.
- [ ] Editor header cells use the kicker style; `Add variable` is a ghost button.
- [ ] All existing keys keep resolving; create/rename/delete variables still work.

**Verification:**
- [ ] `fvm flutter test test/ui/environments test/ui/app_shell_test.dart`
- [ ] `fvm flutter analyze`

**Dependencies:** S4

**Files likely touched:** `lib/ui/shared/list_detail_layout.dart`,
`lib/ui/environments/environment_manager_screen.dart`,
`test/ui/shared/list_detail_layout_test.dart`,
`test/ui/environments/environment_manager_screen_test.dart`

**Estimated scope:** Medium (4 files)

## S6: Flows list and builder restyle

**Description:** The Flows list uses `ListDetailLayout` (`FLOWS` + ghost
`New flow`, same row style). The builder: name field, ghost `Save`, lime
`Run`, step cards with `MethodBadge`, request name and the
extractions/assertions blocks in themed rows, ghost `Add step` at the end.

**Acceptance criteria:**
- [ ] List panel and rows match Environments.
- [ ] `Save` is ghost, `Run` is the filled lime button; keys unchanged.
- [ ] Step cards keep editing extractions and assertions exactly as before.
- [ ] Empty states keep their text and keys.

**Verification:**
- [ ] `fvm flutter test test/ui/flows`
- [ ] `fvm flutter analyze`

**Dependencies:** S5

**Files likely touched:** `lib/ui/flows/flows_screen.dart`,
`lib/ui/flows/step_card.dart`, `test/ui/flows/flow_builder_screen_test.dart`,
`test/ui/flows/step_card_editor_test.dart`

**Estimated scope:** Medium (4 files)

## S7: Flow run view restyle

**Description:** Summary strip with `N passed` (`tertiary`), `N failed`
(`error`), `N skipped` (`outline`) and total time; step cards with icon and
color per state, selected one with `surfaceContainerHigh` and a `primary`
border; step inspector styled like the response panel (`responseBackground`,
`200 · 124 ms · 512 B` line, code block on `surfaceContainerLowest`); error
panel on `errorContainer`.

**Acceptance criteria:**
- [ ] Summary strip counts and colors match the run result.
- [ ] Passed/failed/skipped cards use their state colors; selection shows the primary border.
- [ ] Inspector shows the status line and code block styling.
- [ ] `run-view-back-button`, `re-run-flow-button`, `run-summary-strip` keys unchanged.

**Verification:**
- [ ] `fvm flutter test test/ui/flows`
- [ ] `fvm flutter analyze`

**Dependencies:** S6

**Files likely touched:** `lib/ui/flows/flow_run_view_screen.dart`,
`lib/ui/flows/run_step_card.dart`, `lib/ui/flows/run_step_inspector.dart`,
`lib/ui/flows/error_detail_panel.dart`,
`test/ui/flows/flow_run_view_test.dart`

**Estimated scope:** Medium (5 files)

## S8: Step picker chips aligned with the sidebar

**Description:** The add-step dialog's method filter chips use the same
shape and colors as `MethodFilterChips` (reuse the widget or its style) so
the app has one chip look.

**Acceptance criteria:**
- [ ] Method chips in the picker are visually the same widget style as the sidebar's.
- [ ] Picker filtering behavior and keys unchanged.

**Verification:**
- [ ] `fvm flutter test test/ui/flows`
- [ ] `fvm flutter analyze`

**Dependencies:** S6

**Files likely touched:** `lib/ui/flows/add_step_picker.dart`,
`lib/ui/collections/method_filter_chips.dart` (only if the chip needs to be parameterised),
`test/ui/flows/flow_builder_screen_test.dart`

**Estimated scope:** Small (3 files)

## S9: Sweep and visual check

**Description:** Search for leftovers (old environment dot palette, the
History placeholder, hardcoded colors), run the full suite, and check all
four screens in the web preview against the Workspace.

**Acceptance criteria:**
- [ ] No `History placeholder` text and no stale dot palette left in `lib/`.
- [ ] Environments, Flows (builder; run view if one can be produced), History checked at ≥1100px.
- [ ] Every spec success criterion ticked or listed with the reason it could not be verified (e.g. a run view needs a real network call in the web preview).

**Verification:**
- [ ] `fvm flutter analyze` and `fvm flutter test`
- [ ] Web preview (collections import is file-picker based; create data by hand)

**Dependencies:** S3, S8

**Files likely touched:** none expected beyond fixes found

**Estimated scope:** Small

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Changing the dot palette alters tests or the flow picker that use `environmentDotColor` | Med | Grep usages in S4; update tests in the same commit |
| `ACTIVE` fix changes what existing manager tests assert | Med | They pin current behavior (selected = active); update them to the corrected rule and say so in the commit |
| Flow run view is hard to exercise in the browser (needs real HTTP) | Med | Cover with widget tests built from `FlowStepResult` fixtures; note it in S9 |
| History list grows large | Low | Bounded: 20 entries per endpoint; use `ListView.builder` |
| History rows must not hold stale endpoints | Low | Join at render time from the collections provider; deleted → `Deleted request` |
| `ListDetailLayout` extracted too early | Low | Created inside S5 from the Environments code, not before |

## Open Questions

None blocking. Both defaults (history joined from the saved request; no
clear-history button) are chosen; say so if you want either changed.
