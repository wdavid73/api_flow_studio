# Implementation Plan: UI redesign — module `workspace`

Spec: [SPEC-workspace.md](../../SPEC-workspace.md). Depends on `app-shell`
(done). Checklist in [todo.md](todo.md). Earlier plans:
[plan.md](plan.md) (`ui-theme`), [plan-app-shell.md](plan-app-shell.md).

## Overview

Turn the Workspace into the playground's three panels (sidebar | request |
response), add method filtering and search to the sidebar, restyle the
request builder, move History next to the response, add Copy / curl buttons
with toasts, and add Ctrl/Cmd+Enter and `/` shortcuts. One additive engine
file (`curl_builder.dart`); everything else is UI.

## Architecture Decisions

- **Defaults for the two open questions** (the user said "continuemos"
  without choosing): sidebar rows show the endpoint **name**, and
  **`Restore example` is omitted** (no per-endpoint example exists); only
  `Format JSON` is added.
- **`WorkspaceScreen` owns the layout**; `RequestBar` becomes only the
  request builder. Tests that mounted `RequestBar` to reach the response or
  history now mount `WorkspaceScreen` (or `RequestBar` + `ResponsePanel`).
- **Layout first, then content.** Moving the response out of `RequestBar`
  (W2) is the riskiest change for existing tests, so it goes before any
  restyling.
- **curl comes from the engine** (`buildCurl`), pure and tested on its own
  before any widget uses it.
- **English labels stay English**; copy for new toasts/messages is in the
  spec.

## Dependency graph

```
W1 buildCurl (engine)
W2 three-panel layout  ── W3 response status + Copy/curl (needs W1)
                      ├─ W4 History moves into the response panel
                      ├─ W5 request header, URL bar, pill tabs
                      │    └─ W6 Body: Format JSON + Invalid JSON
                      ├─ W7 sidebar method chips + combined filter
                      │    └─ W8 sidebar rows, group headers, empty result
                      └─ W9 shortcuts (Ctrl/Cmd+Enter, /)
                           └─ W10 sweep + visual check
```
W1 and W2 are independent; W3–W9 need W2 (W3 also W1). W10 needs all.

## Task List

### Phase 1: Foundations
- [x] W1: `buildCurl` in the engine
- [ ] W2: Three-panel layout

### Checkpoint: Layout
- [ ] analyze clean, full suite green (tests moved off `RequestBar` where needed)
- [ ] 1440px shows three panels, 900px stacks the response

### Phase 2: Response side
- [ ] W3: Response status line, Copy and curl
- [ ] W4: History inside the response panel

### Checkpoint: Response side
- [ ] analyze clean, full suite green

### Phase 3: Request side
- [ ] W5: Request header, URL bar and pill tabs
- [ ] W6: Body Format JSON and Invalid JSON

### Checkpoint: Request side
- [ ] analyze clean, full suite green

### Phase 4: Sidebar and keys
- [ ] W7: Method chips and combined filter
- [ ] W8: Sidebar rows, group headers and empty result
- [ ] W9: Keyboard shortcuts

### Phase 5: Verify
- [ ] W10: Sweep and visual check (>=1100px and <1100px)

### Checkpoint: Module done
- [ ] All SPEC-workspace.md success criteria checked
- [ ] Human review, then write `SPEC-secondary-screens.md`

---

## W1: `buildCurl` in the engine

**Description:** `lib/engine/curl/curl_builder.dart` with
`buildCurl(Endpoint, {Map<String,String> variables})`: `curl -X METHOD 'url'`,
one `-H` per enabled header, `--data` for a body, single quotes escaped,
`{{vars}}` resolved with the existing interpolator, lines joined with
` \` + newline.

**Acceptance criteria:**
- [ ] GET without body → one line; POST with JSON body → `--data` line.
- [ ] Single quotes in URL/header/body are escaped (`'\''`).
- [ ] Disabled headers omitted; `{{var}}` resolved from `variables`.
- [ ] Round trip: `curl_parser` on the built command returns same method, URL, headers.
- [ ] No `package:flutter` import under `lib/engine`.

**Verification:**
- [ ] `fvm flutter test test/engine/curl`
- [ ] `fvm flutter analyze`

**Dependencies:** none

**Files likely touched:** `lib/engine/curl/curl_builder.dart`,
`test/engine/curl/curl_builder_test.dart`

**Estimated scope:** Small (2 files)

## W2: Three-panel layout

**Description:** Add `WorkspaceScreen` (sidebar 300 | request | response,
dividers, response background `responseBackground`); take the embedded
`ResponsePanel` out of `RequestBar`; below 1100px keep the sidebar and stack
request over response. `app.dart` uses `WorkspaceScreen` for the Workspace
destination.

**Acceptance criteria:**
- [ ] At 1440px the three panels sit in one row (request and response widths ≈ 1 : 0.92).
- [ ] At 900px the response is below the request; no overflow exceptions.
- [ ] `RequestBar` no longer contains a `ResponsePanel`.
- [ ] Sending a request still shows its response in the right panel.

**Verification:**
- [ ] `fvm flutter test test/ui/workspace test/ui/request_builder test/ui/collections test/ui/history`
- [ ] `fvm flutter analyze`

**Dependencies:** none

**Files likely touched:** `lib/ui/workspace/workspace_screen.dart`,
`lib/ui/request_builder/request_bar.dart`, `lib/app.dart`,
`test/ui/workspace/workspace_screen_test.dart`, plus the tests that mount
`RequestBar` (updated: `request_bar_test`, `history_wiring_test`,
`sidebar_tree_test`)

**Estimated scope:** Medium–Large (≈7 files; the test updates are mechanical)

## W3: Response status line, Copy and curl

**Description:** In `ResponsePanel`: top row with the tabs area reserved,
`Copy` and `curl` ghost buttons; status line (dot + code, `ms`, `B`);
`No response yet` empty state with the hint. `Copy` copies the raw body and
toasts `Response copied` (`Nothing to copy` with no response); `curl`
copies `buildCurl(draft, variables: active env)` and toasts `curl copied`.

**Acceptance criteria:**
- [ ] Status line shows `200 · 124 ms · 512 B` style text with the status color.
- [ ] `Copy` puts the body on the clipboard and shows its toast; no response → `Nothing to copy`.
- [ ] `curl` puts a curl command with resolved variables on the clipboard and shows its toast.
- [ ] Existing keys (`response-elapsed`, `response-size`, `copy-body-button`) keep working or are updated in the same commit.

**Verification:**
- [ ] `fvm flutter test test/ui/response_viewer`
- [ ] `fvm flutter analyze`

**Dependencies:** W1, W2

**Files likely touched:** `lib/ui/response_viewer/response_panel.dart`,
`test/ui/response_viewer/response_panel_test.dart`

**Estimated scope:** Small (2 files)

## W4: History inside the response panel

**Description:** `ResponsePanel` gets `Response` / `History` tabs on top;
`History` shows the existing `HistoryTab` content (same three states). Remove
the `History` tab from the request tabs (8 → 7 tabs).

**Acceptance criteria:**
- [ ] Response panel shows `Response` and `History` tabs; History keeps its three states (unsaved, empty, entries).
- [ ] The request tab bar has no History tab.
- [ ] Sending a saved request makes the new entry appear under History without a reload.

**Verification:**
- [ ] `fvm flutter test test/ui/history test/ui/request_builder test/ui/response_viewer`
- [ ] `fvm flutter analyze`

**Dependencies:** W2

**Files likely touched:** `lib/ui/response_viewer/response_panel.dart`,
`lib/ui/request_builder/request_bar.dart`,
`test/ui/request_builder/history_wiring_test.dart`,
`test/ui/history/history_panel_test.dart`

**Estimated scope:** Small–Medium (4 files)

## W5: Request header, URL bar and pill tabs

**Description:** Add `RequestHeader` (kicker = folder name or `UNSAVED`,
`AppTypography.title` name, one description line). Style the URL bar: method
selector as colored mono text, URL field, ghost `Save`, lime `Send`. Request
tabs become pills.

**Acceptance criteria:**
- [ ] Header shows folder, name and description of the loaded endpoint; `UNSAVED` and `Untitled Request` for a draft.
- [ ] Method selector text uses `MethodBadge.colorForMethod`.
- [ ] Tab bar is pill-styled with `surfaceContainerHigh` for the active one.
- [ ] `request-url-field` and `save-request-button` keys unchanged.

**Verification:**
- [ ] `fvm flutter test test/ui/request_builder`
- [ ] `fvm flutter analyze`

**Dependencies:** W2

**Files likely touched:** `lib/ui/request_builder/request_header.dart`,
`lib/ui/request_builder/request_bar.dart`,
`test/ui/request_builder/request_header_test.dart`,
`test/ui/request_builder/request_bar_test.dart`

**Estimated scope:** Medium (4 files)

## W6: Body Format JSON and Invalid JSON

**Description:** In the Body tab, for the JSON kind add a `Format JSON`
button (pretty-prints with two spaces) and an inline `Invalid JSON` warning
(`warning` color) when the body doesn't parse. Variables `{{x}}` inside
strings must not trigger the warning.

**Acceptance criteria:**
- [ ] `Format JSON` reformats valid JSON; invalid JSON is left unchanged.
- [ ] `Invalid JSON` shows only for the JSON kind with an unparseable body, and disappears when fixed.
- [ ] A body with `{{token}}` inside a string is treated as valid.
- [ ] Other body kinds show neither control.

**Verification:**
- [ ] `fvm flutter test test/ui/request_builder`
- [ ] `fvm flutter analyze`

**Dependencies:** W5

**Files likely touched:** `lib/ui/request_builder/tabs/body_tab.dart`,
`test/ui/request_builder/body_tab_test.dart`

**Estimated scope:** Small (2 files)

## W7: Method chips and combined filter

**Description:** `MethodFilterChips` (`All`, GET, POST, PUT, PATCH, DELETE in
a 3-column grid; active = `onSurface` fill) with
`sidebarMethodFilterProvider`. The sidebar tree filters by method **and**
text; a folder shows if any descendant passes. Text search also matches
method, URL and description.

**Acceptance criteria:**
- [ ] Choosing `POST` hides non-POST endpoints; `All` restores them.
- [ ] Method + text combine; a folder with no passing descendant disappears.
- [ ] Text matches name, method, URL and description (case-insensitive).
- [ ] Only one chip active at a time; default `All`.

**Verification:**
- [ ] `fvm flutter test test/ui/collections`
- [ ] `fvm flutter analyze`

**Dependencies:** W2

**Files likely touched:** `lib/ui/collections/method_filter_chips.dart`,
`lib/ui/collections/sidebar_tree.dart`,
`test/ui/collections/sidebar_filter_test.dart`

**Estimated scope:** Medium (3 files)

## W8: Sidebar rows, group headers and empty result

**Description:** Endpoint rows: `MethodBadge` in a 54px column + name in
mono 12px with ellipsis; selected `surfaceContainerHigh`, hover
`surfaceContainer`, radius 8. Top-level folder headers in `kicker` style
with an endpoint count. When filters leave nothing, show `Nothing matches
that search.`

**Acceptance criteria:**
- [ ] Row layout and selection styling as specified; long names ellipsize.
- [ ] Top-level folder header shows its count.
- [ ] Filter with no matches shows the message (and not the `empty-workspace-state`).
- [ ] Existing keys used by `sidebar_tree_test` still resolve.

**Verification:**
- [ ] `fvm flutter test test/ui/collections`
- [ ] `fvm flutter analyze`

**Dependencies:** W7

**Files likely touched:** `lib/ui/collections/sidebar_tree.dart`,
`test/ui/collections/sidebar_tree_test.dart`,
`test/ui/collections/sidebar_filter_test.dart`

**Estimated scope:** Small–Medium (3 files)

## W9: Keyboard shortcuts

**Description:** `WorkspaceShortcuts` wraps `WorkspaceScreen`: Ctrl/Cmd+Enter
calls `sendStateProvider.notifier.send()` unless a send is already running;
`/` focuses the sidebar search only when no text field has focus.

**Acceptance criteria:**
- [ ] Ctrl+Enter and Cmd+Enter each trigger exactly one send.
- [ ] While `loading` is true, the shortcut does nothing.
- [ ] `/` focuses the search field; typing `/` inside a text field still types it.

**Verification:**
- [ ] `fvm flutter test test/ui/workspace`
- [ ] `fvm flutter analyze`

**Dependencies:** W2

**Files likely touched:** `lib/ui/workspace/workspace_shortcuts.dart`,
`lib/ui/workspace/workspace_screen.dart`,
`lib/ui/collections/sidebar_tree.dart` (focus node),
`test/ui/workspace/workspace_shortcuts_test.dart`

**Estimated scope:** Medium (4 files)

## W10: Sweep and visual check

**Description:** Import `sample-endpoints.json` in the web preview, check the
workspace at ≥1100px and <1100px against the HTML, and run the full suite.

**Acceptance criteria:**
- [ ] No leftover references to the removed History request tab.
- [ ] Both widths checked with imported endpoints; no overflow in the console.
- [ ] Every success criterion in the spec ticked or listed with the reason it could not be verified.

**Verification:**
- [ ] `fvm flutter analyze` and `fvm flutter test`
- [ ] Web preview (import is file-picker based and may not work on web; if so,
  create folders and requests by hand)

**Dependencies:** W1–W9

**Files likely touched:** none expected beyond fixes found

**Estimated scope:** Small

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Many tests mount `RequestBar` and expect the response/History inside it | High | W2 updates them in the same commit, keeps their assertions, only changes what is mounted |
| `sidebar_tree.dart` (≈400 lines) gets too big | Med | Chips go in their own file; split rows into a file if W8 adds more than ~80 lines |
| `/` shortcut swallowed while typing | Med | Only act when focus is not in an editable text field; explicit test |
| Import on web uses `dart:io` and fails in the visual check | Low | Create content by hand in W10; noted in the spec |
| Three panels cramped at 1100–1300px | Low | Min widths on request/response; stacked below 1100 |
| Response panel (flex 0.92) hides the JSON on narrow panels | Low | Body view scrolls horizontally; check in W10 |

## Open Questions

None blocking. Name-vs-path for sidebar rows and omitting `Restore example`
are defaults chosen without an answer; say so if you want either changed.
