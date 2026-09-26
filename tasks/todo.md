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
- [ ] Task 4.3: History UI

### Checkpoint: After Phase 4
- [ ] `fvm flutter analyze`/`fvm flutter test` clean
- [ ] Manual: SPEC criterion #5 (history caps at N, old entries viewable)
- [ ] Quick review before Phase 5 (highest complexity)

## Phase 5 — Flows

- [ ] Task 5.1: `value_extractor` (dot-notation)
- [ ] Task 5.2: `flow_runner`
- [ ] Task 5.3: Flows provider
- [ ] Task 5.4a: Flow builder UI scaffold
- [ ] Task 5.4b: Flow builder — extract mapping & stop-on-failure editor
- [ ] Task 5.5a: Flow run view — wiring & status icons
- [ ] Task 5.5b: Flow run view — detail panel, error diagnostics, re-run-from-step

### Checkpoint: After Phase 5
- [ ] `fvm flutter analyze`/`fvm flutter test` clean
- [ ] Manual: SPEC criterion #6 full walkthrough (registration-flow example, stop-on-failure→skip, re-run-from-step)
- [ ] Review with human: reassess remaining scope/timeline before Phase 6/7

## Phase 6 — curl Paste-Import

- [ ] Task 6.1: `curl_parser`
- [ ] Task 6.2: Paste-curl UI hook

### Checkpoint: After Phase 6
- [ ] `fvm flutter analyze`/`fvm flutter test` clean
- [ ] Manual: SPEC criterion #7 walkthrough

## Phase 7 — Polish & Sign-off

- [ ] Task 7.1: Visual QA pass vs `screen.png` for all 4 screens
- [ ] Task 7.2: Success-criteria walkthrough & edge-case hardening
- [ ] Task 7.3 [optional, ask-first]: Windows app icon from logo asset

### Checkpoint: Final
- [ ] All SPEC.md Success Criteria checked
- [ ] `fvm flutter analyze` clean, `fvm flutter test` all green
- [ ] Human sign-off
