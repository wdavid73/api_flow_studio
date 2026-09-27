# API Flow Studio — Task List

Full detail (acceptance criteria, verification commands, files touched,
sizing) for every task below lives in [tasks/plan.md](plan.md). This file
is the checklist `/build` and other tooling read — check items off as they
land, don't duplicate the detail here.

## Phase 1 — Engine Foundation

- [x] Task 1.1: Core freezed models (`lib/engine/models/`)
- [x] Task 1.2: Variable interpolator (`lib/engine/variables/interpolator.dart`)
- [x] Task 1.3: JSON on-disk store (`lib/engine/storage/json_store.dart`)
- [x] Task 1.4: Request executor (`lib/engine/http/request_executor.dart`)

### Checkpoint: After Phase 1
- [x] `fvm dart run build_runner build --delete-conflicting-outputs` clean
- [x] `fvm flutter analyze` clean
- [x] `fvm flutter test test/engine` all green (53/53)
- [x] `grep -r "package:flutter" lib/engine` empty
- [x] Architecture Decisions #1 (palette) and #2 (fonts) confirmed with human — resolved 2026-09-26

## Phase 2 — UI Shell, Theme, First Vertical Slice

- [x] Task 2.1: App shell & navigation skeleton
- [x] Task 2.2: Theme tokens from DESIGN.md (fonts downloaded + confirmed with user: Geist Regular/Medium/SemiBold, JetBrains Mono Regular/Medium)
- [x] Task 2.3: Minimal request bar + real Send + response viewer (first vertical slice)
- [x] Task 2.4: Full request builder tabs (Params/Headers/Body/Auth)
- [x] Task 2.5: Full response viewer polish

### Checkpoint: After Phase 2
- [x] `fvm flutter analyze` and `fvm flutter test` clean (99/99)
- [x] Manual: build + send a full request, inspect full response viewer (mocked-executor widget tests + web build spot-check)
- [x] Visual spot-check vs `design/main_workspace/screen.png` (informal, via browser pane screenshot)
- [x] Review with human before starting persistence (Phase 3) — proceeding autonomously per approved /build auto run

## Phase 3 — Environments + Collections (Persisted)

- [x] Task 3.1: Environments provider
- [x] Task 3.2: Environment manager screen
- [x] Task 3.3: Wire active-environment interpolation into request builder
- [x] Task 3.4: Collections provider
- [x] Task 3.5: Sidebar collection tree UI + save endpoint

### Checkpoint: After Phase 3
- [x] `fvm flutter analyze`/`fvm flutter test` clean (133/133)
- [x] Manual: SPEC criteria #2 + #3 — verified via widget tests with a real temp-dir JsonStore, including a "simulated restart" (fresh ProviderContainer re-reading the same on-disk files). The web dev-aid can no longer stand in for this: `path_provider` has no web implementation, so the real app (not the tests, which inject a temp dir directly) throws `MissingPluginException` on web from this phase onward. Native Windows run is still blocked on the missing Visual Studio toolchain.
- [x] Review with human: delete semantics (3.4, blocking not cascading) + on-disk JSON shape — proceeding autonomously per approved /build auto run

## Phase 4 — History

- [x] Task 4.1: History store functions
- [x] Task 4.2: Wire Send → save HistoryEntry
- [x] Task 4.3: History UI

### Checkpoint: After Phase 4
- [x] `fvm flutter analyze`/`fvm flutter test` clean (143/143)
- [x] Manual: SPEC criterion #5 — verified via HistoryTab widget tests against a real temp-dir JsonStore (empty state, most-recent-first ordering, cap-at-20 already proven in Task 4.1's store tests, expand-to-view historical body)
- [x] Quick review before Phase 5 (highest complexity) — proceeding autonomously per approved /build auto run

## Phase 5 — Flows

- [x] Task 5.1: `value_extractor` (dot-notation)
- [x] Task 5.2: `flow_runner`
- [x] Task 5.3: Flows provider
- [x] Task 5.4a: Flow builder UI scaffold
- [x] Task 5.4b: Flow builder — extract mapping & stop-on-failure editor
- [x] Task 5.5a: Flow run view — wiring & status icons
- [x] Task 5.5b: Flow run view — detail panel, error diagnostics, re-run-from-step

### Checkpoint: After Phase 5
- [x] `fvm flutter analyze`/`fvm flutter test` clean (191/191)
- [x] Manual: SPEC criterion #6 full walkthrough — the Windows Visual Studio toolchain blocker (Phase 2) still rules out a true manual run; verified instead via widget tests driving the real `FlowRunner`/`JsonStore` against a mocked network boundary (same substitution used at the Phase 3/4 checkpoints): 3-step success run, stop-on-failure→skip, step-detail expand/collapse with request+response+error classification, and re-run-from-step reusing the accumulated variable pool without re-calling earlier steps.
- [x] Review with human: reassess remaining scope/timeline before Phase 6/7 — proceeding autonomously per approved /build auto run

## Phase 6 — curl Paste-Import

- [x] Task 6.1: `curl_parser`
- [x] Task 6.2: Paste-curl UI hook

### Checkpoint: After Phase 6
- [x] `fvm flutter analyze`/`fvm flutter test` clean (206/206)
- [x] Manual: SPEC criterion #7 walkthrough — same Windows-toolchain substitution as prior checkpoints: `curl_parser_test.dart` parses a real Chrome devtools "Copy as cURL (bash)" multi-line sample, and `paste_curl_dialog_test.dart` drives the actual dialog end-to-end (paste -> request draft prefilled with method/URL/headers/body, inline error + retry on a bad paste, cancel leaves the draft untouched).

## Phase 7 — Polish & Sign-off

- [x] Task 7.1: Visual QA pass vs `screen.png` for all 4 screens — the native Windows build is still blocked (missing Visual Studio toolchain) and the web build still can't run past its splash screen (`JsonStore` needs real `dart:io` file access, unavailable in a browser, confirmed again here). Used a throwaway widget-test harness instead: `RepaintBoundary.toImage()` on each of the 4 screens seeded with realistic data (registration-flow example) and real app fonts loaded via `FontLoader`, captured to PNG and eyeballed against `design/*/screen.png` side by side, then deleted (not part of the app). Result: colors, spacing, method/status badge styling, and the JSON syntax highlighting all match the DESIGN.md tokens (Architecture Decision #1 confirmed); layout structure for the request bar, response panel, environment list, and flow-step editor (extract mapping, assert fields, stop-on-failure toggle) all match their reference screens closely. Known, already-reasoned gaps vs. the richer mockups (not bugs): no workspace-switcher/Console nav/user-avatar header chrome, no per-step payload-template preview or latency/delay metadata in the flow builder, and a single-column run view instead of a 2-pane timeline+inspector layout -- all deliberately out of SPEC's MVP scope per Architecture Decisions made in tasks/plan.md during Phases 2 and 5, not oversights.
- [x] Task 7.2: Success-criteria walkthrough & edge-case hardening — see the 9-point walkthrough and the edge-case fixes below; **criterion #1 (`fvm flutter run -d windows`) cannot be verified in this environment** (missing Visual Studio C++ toolchain, unresolved since Phase 2) and is the one open item for a human to check on a machine that has it installed. Edge cases found and fixed: `deleteGroup`/`deleteEndpoint`/`deleteFlow` existed at the provider level (Tasks 3.4/5.3) but had no UI entry point at all -- added delete buttons to sidebar folders/endpoints and the flows list, with a non-empty-folder delete showing a warning (via `GroupNotEmptyException`) instead of silently no-oping or crashing. JSON-parse-error handling in the body editor and network-error display were already safe/present from earlier phases (checked, no fix needed).
- [x] Task 7.3 [optional, ask-first]: Windows app icon from logo asset — asked; user declined, keeping the default Flutter icon. Not required by any SPEC Success Criterion.

### Checkpoint: Final
- [x] All SPEC.md Success Criteria checked (8/9 verified via the test suite; #1's native Windows launch needs a human on a machine with the Visual Studio C++ toolchain)
- [x] `fvm flutter analyze` clean, `fvm flutter test` all green (210/210)
- [ ] Human sign-off

## Phase 8 — Visual Parity Pass vs. Stitch Designs

User compared the real running app against `design/*/screen.png` and flagged
it "doesn't look like the designs" — real gap, not a bug (see full context
in tasks/plan.md's Phase 8 section, added 2026-09-26). Pure visual/UI pass:
reuses existing data, adds no new backend features. Not started yet —
queued to run the next session.

- [x] Task 8.1: Shared app shell (header + sidebar chrome) — new hand-painted
      `AppLogoMark`, restyled header (56px, logo+wordmark, active-tab pill,
      pill-styled `EnvironmentSwitcher`), restyled `SidebarTree` (256px
      width, EXPLORER header with relocated New folder/Paste curl icons,
      colored folder icons via new `AppColors.folderIconColor`, real
      version footer replacing the mock's fake "Proxy: Localhost"). All 210
      existing tests pass unmodified; visually confirmed via the Task-7.1
      screenshot-capture technique.
- [x] Task 8.2: Environment Manager restyle — card-style environment list
      with colored left-accent bar + ACTIVE badge (was plain `ListTile`s),
      a real table header row (Name/Value/Secret) above the variable rows,
      and the "Pro tip: Syntax & Resolution" callout. All existing tests
      pass unmodified; visually confirmed via screenshot capture.
- [x] Task 8.3: Flow Builder restyle — centered ~900px pipeline column
      (was full-width `ListView.builder`, now a `Column` in a
      `SingleChildScrollView`), chevron-down connectors between cards, a
      "TERMINAL" badge on the last step, and a read-only "Payload
      Template" preview (via the existing `JsonView`) when the step's
      endpoint has a JSON body. All existing tests pass unmodified;
      visually confirmed via screenshot capture.
- [x] Task 8.4: Flow Run View restyle — 2-panel layout: a compact left
      timeline (`RunStepCard`, no more inline expand) and a right
      `RunStepInspector` detail panel with tabs (Error Details -- only for
      a failed step -- / Request Sent / Response Body / Headers), matching
      the design's structure. Adds auto-select of the most relevant step
      (first failure, else last success) once a run completes, matching
      the mock's "active selection" on the failing step. Two of the
      existing detail tests needed adapting (interaction model genuinely
      changed, per the plan's own allowance): one now checks the
      auto-selected state instead of "nothing selected yet", and one
      switches to the "Response Body" tab explicitly before asserting on
      it, since `TabBarView` only keeps the active tab's content in the
      tree (not all tabs at once, as assumed at first -- confirmed via a
      failing test, fixed with `pumpAndSettle()` after the tab tap for the
      page-transition animation to finish). All 210 tests pass. Visually
      confirmed via screenshot capture.

### Checkpoint: After Phase 8
- [x] `fvm flutter analyze`/`fvm flutter test` clean (full suite, 210/210;
      2 tests in flow_run_view_detail_test.dart adapted per Task 8.4's note
      above, all other Keys unmodified)
- [x] `fvm flutter build windows` succeeds (confirmed; the portable
      `api_flow_studio_data/` folder from the earlier Commodo import
      survived the rebuild untouched, as expected for a sibling folder
      Flutter's build doesn't manage)
- [ ] User does a final visual pass on the real app against all 4
      `design/*/screen.png`
- [ ] Human sign-off
