# Implementation Plan: UI redesign — module `hosts-notes`

Spec: [SPEC-hosts-notes.md](../../SPEC-hosts-notes.md). Depends on
`app-shell` (done). Checklist in [todo.md](todo.md). Earlier plans:
[plan.md](plan.md), [plan-app-shell.md](plan-app-shell.md),
[plan-workspace.md](plan-workspace.md),
[plan-secondary-screens.md](plan-secondary-screens.md),
[plan-session-tokens.md](plan-session-tokens.md).

> Saved under `tasks/ui-redesign/` (the location agreed for this whole
> initiative) because `tasks/plan.md` and `tasks/todo.md` still belong to the
> v1 plan, which has open items.

## Overview

Add a `Hosts & notes` dialog: a matrix of "bases" (environment variables whose
value is an `http(s)` URL) by environment, editable in place, with a warning
for every base missing in some environment, a note per base, and how many
saved requests use each one. The logic lives in pure Dart under
`lib/engine/hosts/`; notes get their own tiny file, `host_notes.json`;
everything else reuses the existing environments store.

## Architecture Decisions

- **Defaults for the two open questions** (the spec was left as proposed):
  notes are per base only (no general workspace note), and a base written with
  variables (`{{scheme}}://{{host}}`) is not auto-detected; `Add host` covers it.
- **Pure engine first.** `isHostUrl`, `buildHostMatrix` (rows, values, usage
  counts, notes, missing-in-environment warnings) and `setHostValue` are
  small, fully unit-tested functions before any widget uses them.
- **No new model for hosts.** A base is a view over `EnvironmentVariable`s;
  edits go through the existing `environmentsProvider.updateEnvironment`.
- **Notes are the only new data**: `host_notes.json`, a `name → note` map,
  read/written by two new `JsonStore` methods (works on disk and in memory).
- **Secret variables are excluded in the engine**, so no widget can leak them.
- **Read-only first, then editable**: the matrix (H4) is shown before cells
  become editable (H5), so each slice can be seen on its own.
- **A row stays while it is being edited** even if its value stops being a URL
  (the spec's rule), so typing `h`, `ht`, `htt`… never makes the row vanish.

## Dependency graph

```
H1 isHostUrl + buildHostMatrix (incl. warnings)
H2 setHostValue
H3 host notes in JsonStore
 └── (H1) H4 button, dialog and read-only matrix
      ├── (H2) H5 editable cells
      ├── (H3) H6 notes column and Add host
      └── H7 warnings under the table
           └── H8 sweep + visual check
```
H1–H3 are independent. H5 needs H2 and H4; H6 needs H3 and H4; H7 needs H4
(its data comes from H1).

## Task List

### Phase 1: Engine
- [ ] H1: `isHostUrl` and `buildHostMatrix`
- [ ] H2: `setHostValue`
- [ ] H3: Host notes in `JsonStore`

### Checkpoint: Engine
- [ ] analyze clean, full suite green
- [ ] `grep -r "package:flutter" lib/engine` is empty

### Phase 2: Dialog
- [ ] H4: Header button, dialog and read-only matrix
- [ ] H5: Editable cells
- [ ] H6: Notes column and Add host
- [ ] H7: Warnings under the table

### Checkpoint: Dialog
- [ ] Editing a cell changes the environment and survives a reload; notes survive a reload
- [ ] analyze clean, full suite green

### Phase 3: Verify
- [ ] H8: Sweep and visual check

### Checkpoint: Module done
- [ ] All SPEC-hosts-notes.md success criteria checked
- [ ] The redesign capability map is fully implemented

---

## H1: `isHostUrl` and `buildHostMatrix`

**Description:** `lib/engine/hosts/host_matrix.dart`. `isHostUrl(String)`
(trimmed, case-insensitive `http://`/`https://`). `buildHostMatrix(
List<Environment> environments, List<Endpoint> endpoints, Map<String,String>
notes)` returns a `HostMatrix`: the environments (in order), rows sorted by
name (`name`, `valueByEnvironmentId`, `note`, `usedBy`) and, per row, the
environments where it is missing. A variable is a base if it is a URL in at
least one environment and `secret` in none; `usedBy` counts endpoints whose
URL contains `{{name}}`.

**Acceptance criteria:**
- [ ] `isHostUrl` true for `http://x`, ` HTTPS://x `, false for `{{x}}/api`, `ftp://x`, empty.
- [ ] A URL variable present in some environments is a row; the environments lacking it are listed as missing.
- [ ] A variable that is secret in any environment, or never a URL, is not a row.
- [ ] Rows sorted by name; columns follow the environment order; notes and `usedBy` filled in.
- [ ] A base present in every environment has no missing entries.

**Verification:**
- [ ] `fvm flutter test test/engine/hosts`
- [ ] `fvm flutter analyze`

**Dependencies:** none

**Files likely touched:** `lib/engine/hosts/host_matrix.dart`,
`test/engine/hosts/host_matrix_test.dart`

**Estimated scope:** Small (2 files)

## H2: `setHostValue`

**Description:** `setHostValue(Environment, String name, String value)`
returns the environment with the variable set, or removed when [value] is
empty. Only that variable changes; other variables and the secret flag of an
existing variable are preserved.

**Acceptance criteria:**
- [ ] Creates the variable when absent; replaces the value when present.
- [ ] An empty value (or whitespace only) removes the variable.
- [ ] Other variables and the environment id/name are untouched; an existing variable keeps its `secret` flag.
- [ ] Removing a variable that does not exist returns an equal environment.

**Verification:**
- [ ] `fvm flutter test test/engine/hosts`
- [ ] `fvm flutter analyze`

**Dependencies:** none

**Files likely touched:** `lib/engine/hosts/host_matrix.dart`,
`test/engine/hosts/set_host_value_test.dart`

**Estimated scope:** Small (2 files)

## H3: Host notes in `JsonStore`

**Description:** `readHostNotes()` and `writeHostNotes(Map<String,String>)`
over a new `host_notes.json`. Missing file → empty map; corrupt file follows
the store's existing backup-and-default behavior; empty notes are dropped on
write. Works for the disk store and `JsonStore.inMemory()`.

**Acceptance criteria:**
- [ ] No file → empty map; write then read round-trips.
- [ ] Blank notes are not stored.
- [ ] A corrupt `host_notes.json` is backed up and reads as empty (same as the other files).
- [ ] Existing files (`environments.json`, ...) are unchanged by writing notes.

**Verification:**
- [ ] `fvm flutter test test/engine/storage`
- [ ] `fvm flutter analyze`

**Dependencies:** none

**Files likely touched:** `lib/engine/storage/json_store.dart`,
`test/engine/storage/host_notes_store_test.dart`

**Estimated scope:** Small (2 files)

## H4: Header button, dialog and read-only matrix

**Description:** `HostsButton` (`Hosts & notes`, ghost) in the header actions
left of the session button; it opens `HostsDialog` (≤1040px, 16 radius,
`surfaceContainerLow`, title `Hosts by environment`, help text, `Close`). The
table (`HostMatrixTable`) shows one row per base and one column per
environment, read-only for now: name in mono with `Used by N request(s)`,
environment headers with a `primary` dot for the active one and `PROD` for
production, horizontal scroll with many environments, and the empty message.

**Acceptance criteria:**
- [ ] The button sits left of the session button and opens the dialog; `Close` and `Esc` close it.
- [ ] One row per base and one column per environment, with values shown.
- [ ] Active environment header has the dot; a prod-named environment has `PROD`.
- [ ] `Used by N request(s)` shown (singular for 1).
- [ ] No bases → `No hosts yet — add an environment variable whose value is a URL, or use Add host.`
- [ ] With 8 environments the table scrolls horizontally without overflow errors.

**Verification:**
- [ ] `fvm flutter test test/ui/hosts test/ui/app_shell_test.dart`
- [ ] `fvm flutter analyze`

**Dependencies:** H1

**Files likely touched:** `lib/ui/hosts/hosts_button.dart`,
`lib/ui/hosts/hosts_dialog.dart`, `lib/ui/hosts/host_matrix_table.dart`,
`lib/app.dart`, `test/ui/hosts/hosts_dialog_test.dart`

**Estimated scope:** Medium (5 files)

## H5: Editable cells

**Description:** Each cell becomes a mono text field. Typing saves that value
in that environment through `updateEnvironment` (`setHostValue`); clearing
removes the variable there and the cell shows the `warning` border and
`missing`. A row whose value stops being a URL stays while its field is being
edited and drops out once the dialog is rebuilt; no other environment field
changes.

**Acceptance criteria:**
- [ ] Typing in a cell updates exactly that variable in that environment and persists (store re-read shows it).
- [ ] Clearing a cell removes the variable from that environment only; the cell shows `missing` with a `warning` border.
- [ ] Typing a value into an empty cell creates the variable in that environment.
- [ ] Typing `h`, `ht`, … in a cell never makes its row disappear while editing.
- [ ] A secret variable is never listed or touched.

**Verification:**
- [ ] `fvm flutter test test/ui/hosts test/ui/environments`
- [ ] `fvm flutter analyze`

**Dependencies:** H2, H4

**Files likely touched:** `lib/ui/hosts/host_matrix_table.dart`,
`test/ui/hosts/host_matrix_edit_test.dart`

**Estimated scope:** Small–Medium (2–3 files)

## H6: Notes column and Add host

**Description:** A `hostNotesProvider` loads `host_notes.json` and saves each
edit; the last column is a one-line `Note…` field per base. `Add host` asks
for a name and adds an empty row that exists only while the dialog is open
(and persists once a URL is typed in any cell).

**Acceptance criteria:**
- [ ] Typing a note saves it by base name; it is still there after closing and reopening, and after a store reload.
- [ ] Clearing a note removes it from the file.
- [ ] `Add host` creates an empty row with every cell `missing`; typing a URL in a cell makes it a real base.
- [ ] An empty or duplicate name in `Add host` is rejected with a message and nothing is added.

**Verification:**
- [ ] `fvm flutter test test/ui/hosts`
- [ ] `fvm flutter analyze`

**Dependencies:** H3, H4

**Files likely touched:** `lib/ui/hosts/host_notes_provider.dart`,
`lib/ui/hosts/host_matrix_table.dart`, `lib/ui/hosts/hosts_dialog.dart`,
`test/ui/hosts/host_notes_test.dart`

**Estimated scope:** Medium (4 files)

## H7: Warnings under the table

**Description:** One `warning` callout per base missing in some environment
(`HOST_NAME isn't defined in QA, Prod. Requests that use {{HOST_NAME}} will be
sent with that text unresolved there.`). A base used by a request and missing
in the active environment goes first and carries an `ACTIVE` tag. With no
warnings: `Every host is defined in every environment.`

**Acceptance criteria:**
- [ ] A base missing in QA and Prod yields the exact message naming both environments.
- [ ] A used base missing in the active environment is listed first with `ACTIVE`.
- [ ] A base unused by any request but missing in the active environment gets no `ACTIVE` tag.
- [ ] With nothing missing the all-defined message shows; editing a cell updates the warnings.

**Verification:**
- [ ] `fvm flutter test test/ui/hosts`
- [ ] `fvm flutter analyze`

**Dependencies:** H4

**Files likely touched:** `lib/ui/hosts/hosts_dialog.dart`,
`test/ui/hosts/host_warnings_test.dart`

**Estimated scope:** Small (2 files)

## H8: Sweep and visual check

**Description:** Confirm secrets never appear, nothing but the edited variable
changes, run the full suite, and compare the dialog with the HTML using three
sample environments in the web preview.

**Acceptance criteria:**
- [ ] A secret variable with an URL value never shows in the dialog (test + manual check).
- [ ] `environments.json` differs only in the edited variable after a cell edit (store test).
- [ ] Dialog checked at ≥1100px with three environments, including a missing base and a `PROD` column.
- [ ] Every spec success criterion ticked or listed with the reason it could not be verified.

**Verification:**
- [ ] `fvm flutter analyze` and `fvm flutter test`
- [ ] Web preview (environments are created by hand; there is no rename, so a `PROD` column can only be shown by tests)

**Dependencies:** H5–H7

**Files likely touched:** none expected beyond fixes found

**Estimated scope:** Small

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Clearing a cell removes a variable (value lost) | Med | Spec'd behavior, scoped to one variable in one environment; helper text says so; H5 tests the exact scope |
| Row vanishing mid-edit as the value stops being a URL | Med | Keep edited rows alive for the dialog's lifetime; explicit H5 test |
| Every keystroke writes `environments.json` | Low | Same as the existing variable editor; writes are serialized by the store |
| A secret URL leaks into the dialog | High | Excluded in the engine (H1) and re-tested in H8 |
| Many environments overflow the dialog width | Low | Horizontal scroll; H4 test with 8 environments |
| Web preview cannot rename environments, so `PROD` is not visible there | Low | Covered by widget tests; stated in H8 |

## Open Questions

None blocking. Both defaults (per-base notes only; no auto-detection of
variable-built URLs) are chosen; say so if you want either changed.
