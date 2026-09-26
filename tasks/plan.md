# Implementation Plan: API Flow Studio — Task Breakdown

Repo confirmed at `E:\Devs\api_flow_studio`: `flutter create` skeleton only, zero commits, `pubspec.yaml`/`pubspec.lock` already resolved with the full target stack, `lib/main.dart` and `test/widget_test.dart` are unmodified counter-app boilerplate, no `lib/engine`/`lib/ui`/`lib/app.dart`, no `tasks/`. Design bundle at `design/` has 5 subfolders (`api_flow_studio` = DESIGN.md, `api_flow_studio_logo`, `environment_manager`, `flow_builder`, `flow_run_view`, `main_workspace`), each screen with `screen.png` + `code.html`. `windows/runner/resources/app_icon.ico` exists (default Flutter icon, unreplaced).

I read all of `DESIGN.md`, `PROJECT_CONTEXT.md`, `SPEC.md`, `STITCH_PROMPT.md`, the current boilerplate, and the actual generated `code.html` for `main_workspace` and `flow_builder` (structure below is informed by real markup, not guesswork). This surfaced one important discrepancy and a few data-model gaps that the task breakdown below resolves explicitly — see **Architecture Decisions**.

---

## Architecture Decisions (resolve before/at Task 2.2 and 1.1 — flagged for human sign-off)

1. **DESIGN.md has two conflicting palettes — use the YAML frontmatter/HTML one as canonical.** The file's YAML frontmatter (`primary: '#c0c1ff'`, `secondary: '#4cd7f6'`, `tertiary: '#4edea3'`, M3-style role names) is what's actually wired into every exported screen's Tailwind config and is what the `screen.png` files visually show. The prose "Colors" section further down the same file describes a *different, unused* palette ("Electric Violet `#6366f1`", Cyan-Teal `#06b6d4`, distinct 5-color method badges) that matches neither the HTML nor the PNGs — it appears to be the original Stitch *prompt's* intent (`STITCH_PROMPT.md` asked for GET=blue/POST=green/PUT=orange/PATCH=yellow/DELETE=red badges, "teal or violet" accent) that Stitch didn't fully realize in the actual output. The logo SVG (`design/api_flow_studio_logo/code.html`) uses yet another raw hex pair (`#6366f1`/`#06b6d4`) matching the prose, not the frontmatter. Since Success Criterion #9 requires visual comparison against `screen.png`, **the plan uses the frontmatter/HTML M3 token set as the ColorScheme/surface/typography source of truth**, and layers the prose's explicit 5-color **method-badge** and **status-code** hex values on top as a narrow semantic extension (they don't conflict with the M3 roles, and the task literally asks for "method-badge colors GET/POST/PUT/PATCH/DELETE"). This is called out again as Risk #1 — flag for the human reviewer to confirm before Task 2.2 starts.
2. **Fonts are not bundled. RESOLVED 2026-09-26: user approved bundling static `.ttf` files** (over `google_fonts` or a system-font substitute). `DESIGN.md`/`code.html` specify Geist + JetBrains Mono via a Google Fonts `<link>`, but `pubspec.yaml` has no `google_fonts` dependency and no local font assets exist. Bundle static `.ttf` files under `assets/fonts/` and declare them in `pubspec.yaml`'s `fonts:` section. This approval covers the *approach*; the actual download action at Task 2.2 time still needs the exact filenames/source URL/size stated and confirmed per this session's file-download rule before fetching anything.
3. **No JSON-syntax-highlighting package is in the approved stack.** Build a small hand-rolled tokenizer/colorizer widget instead of adding a new pub dependency. The real `code.html` markup gives an exact token→color mapping to replicate: keys → `secondary` (medium weight), string values → `tertiary`, punctuation (`{ } : ,`) → `on-surface-variant`, numbers/booleans → `primary` (semibold), `{{variable}}` tokens → pill chip (`secondary` text/border on `secondary-container` @ ~20% bg). This widget is reused for both the request body editor and the response body viewer — implemented once as a themed component (see decision 5).
4. **Data-model gaps in PROJECT_CONTEXT.md's literal field list, resolved for Task 1.1:**
   - `Endpoint.headers` / `Endpoint.queryParams` cannot be plain `Map<String,String>` — the Environment Manager and Request Builder key-value tables both show a per-row **enabled/disabled checkbox** (`code.html`: "Inline fast-toggle checkboxes"). Use `List<KeyValueEntry>` where `KeyValueEntry { String key, String value, bool enabled }`, and have `request_executor` filter to `enabled` entries only.
   - `Endpoint.body` needs a type discriminator per PROJECT_CONTEXT ("ninguno/raw JSON/form-urlencoded"): a small freezed union `RequestBody.none() | RequestBody.json(String raw) | RequestBody.formUrlEncoded(List<KeyValueEntry> fields)`.
   - `Endpoint.authConfig` needs the same treatment: `AuthConfig.none() | AuthConfig.basic({username, password}) | AuthConfig.bearer({token})`.
   - `Group` needs a `parentGroupId` (nullable `String`) to actually support "category → subcategory → endpoint" nesting — PROJECT_CONTEXT says "nestable" but never states the nesting field.
   - `Environment.variables` entries need a `secret: bool` per-key flag (Environment Manager screen's "Secret" column) — PROJECT_CONTEXT's `Map<String,String>` is too flat for that. Recommend `Map<String, EnvironmentVariable>` where `EnvironmentVariable { String value, bool secret }`, keeping the interpolator's public contract (`Map<String,String> variables`) unchanged by having a small adapter (`environment.resolvedVariables` getter) that flattens key→value for interpolation while the UI reads the richer map for the secret toggle. This is exactly the boundary in SPEC ("secret" is UI-mask-only, never real encryption) — don't over-build it.
5. **Shared design-system widgets live under `lib/ui/theme/widgets/`** (`MethodBadge`, `StatusBadge`, `VariableChip`, `JsonView`) rather than inventing a new top-level folder — this keeps the Project Structure block exactly as specified (`ui/theme/` is already the sanctioned home for anything theme/design-token-derived) while avoiding duplicating these components across `environments/`, `collections/`, `request_builder/`, `response_viewer/`, `flows/`.
6. **`request_executor` never throws on HTTP error status.** Configure `dio` with `validateStatus: (_) => true` so 4xx/5xx come back as normal results (only transport-level failures — timeout, DNS, connection refused — throw). This is what makes `flow_runner`'s "stop on failure" meaningful and matches real Postman-like semantics (a flow step that expects a 404 for "user does not exist" must not be treated as a crash).
7. **Interpolation happens as a pre-processing step, not a dio `Interceptor`.** `request_executor.execute(Endpoint endpoint, {required Map<String,String> variables})` calls the pure `interpolate()` function on url/headers/body/query internally before building `RequestOptions`. This keeps `flow_runner` trivial (merge env vars + previously-extracted vars into one map, call `execute()` per step) and keeps `interpolate()` unit-testable in total isolation from dio.

---

## Dependency Graph

```
Phase 1 — Engine Foundation (pure Dart, lib/engine/**)
  1.1 models/* (freezed+json_serializable, incl. KeyValueEntry/RequestBody/AuthConfig/EnvironmentVariable)
        │
        ├──▶ 1.2 variables/interpolator.dart
        ├──▶ 1.3 storage/json_store.dart
        └──▶ 1.4 http/request_executor.dart  (needs 1.1 + 1.2)

Phase 2 — UI shell / theme / first real vertical slice
  2.1 app shell (main.dart, app.dart, ProviderScope, nav)         ─┐
  2.2 theme tokens (lib/ui/theme/**)                               ├─▶ 2.3 minimal request bar + Send + response viewer (needs 1.4)
                                                                    ┘        │
                                                              2.4 full request builder tabs (needs 2.3, 1.1)
                                                                    │
                                                              2.5 full response viewer polish (needs 2.3)

Phase 3 — Environments + Collections (persisted)
  3.1 environments provider (needs 1.1, 1.3)
        │
        ├─▶ 3.2 environment manager screen (needs 3.1, 2.2)
        └─▶ 3.3 wire active-env interpolation into builder/send (needs 3.1, 2.4, 1.2)
  3.4 collections provider (needs 1.1, 1.3)
        │
        └─▶ 3.5 sidebar collection tree + save endpoint (needs 3.4, 2.4, 2.1)

Phase 4 — History
  4.1 history store fns (needs 1.1, 1.3)
        │
        ├─▶ 4.2 wire send → save HistoryEntry (needs 4.1, 3.5, 2.4)
        └─▶ 4.3 history UI (needs 4.1, 2.2)

Phase 5 — Flows
  5.1 flows/value_extractor.dart (needs 1.1 response shape — otherwise standalone)
  5.2 flows/flow_runner.dart (needs 5.1, 1.2, 1.4, 1.1)
  5.3 flows provider (needs 1.1, 1.3)
        │
  5.4a flow builder UI scaffold (needs 5.3, 3.5, 2.2)
        │
  5.4b flow builder extract-mapping + toggle editor (needs 5.4a)
        │
  5.5a flow run view wiring (needs 5.2, 5.4b, 3.1)
        │
  5.5b flow run view detail/error panel + re-run-from-step (needs 5.5a)

Phase 6 — curl import
  6.1 curl/curl_parser.dart (needs 1.1 only — can be built any time after Phase 1, in parallel)
        │
  6.2 paste-curl UI hook (needs 6.1, 3.5, 2.4)

Phase 7 — Polish
  7.1 visual QA vs screen.png (needs all UI phases)
  7.2 success-criteria walkthrough + analyze/test clean pass (needs everything)
  7.3 [ask-first, optional] Windows app icon from logo asset — no dependency, do any time
```

**Parallelization notes:** `2.1`/`2.2` have no engine dependency and can run alongside Phase 1. `5.1` and `6.1` are pure-Dart and self-contained — a second agent/session could build them any time after `1.1` lands, in parallel with Phase 2/3/4. Everything else is a single dependency chain because it's one implementer working through vertical slices, per the requested ordering.

---

## Phase 1 — Engine Foundation

### Task 1.1: Core freezed models
**Description:** Create all engine models under `lib/engine/models/` with `freezed` + `json_serializable`: `Environment`, `EnvironmentVariable`, `Group`, `Endpoint`, `KeyValueEntry`, `RequestBody` (union: none/json/formUrlEncoded), `AuthConfig` (union: none/basic/bearer), `HistoryEntry`, `Flow`, `FlowStep`. Wire `build_runner` codegen. Include a `lib/engine/models/models.dart` barrel export.

**Acceptance criteria:**
- [ ] All 9 types listed above exist as `@freezed` classes with `fromJson`/`toJson`/`copyWith`, matching the field shapes from PROJECT_CONTEXT.md plus the 4 refinements in Architecture Decision #4 (`KeyValueEntry.enabled`, `RequestBody` union, `AuthConfig` union, `Group.parentGroupId`, `EnvironmentVariable.secret`).
- [ ] `fvm dart run build_runner build --delete-conflicting-outputs` generates `*.freezed.dart`/`*.g.dart` for every model with zero errors.
- [ ] No file under `lib/engine/` imports `package:flutter`.

**Verification:**
- [ ] `fvm dart run build_runner build --delete-conflicting-outputs` succeeds.
- [ ] `fvm flutter analyze` clean.
- [ ] `fvm flutter test test/engine/models` passes (round-trip `toJson`→`fromJson`→equality test per model).
- [ ] Manual: `grep -r "package:flutter" lib/engine` returns nothing.

**Dependencies:** None.

**Files likely touched:**
- `lib/engine/models/environment.dart`, `environment_variable.dart`, `group.dart`, `endpoint.dart`, `key_value_entry.dart`, `request_body.dart`, `auth_config.dart`, `history_entry.dart`, `flow.dart`, `flow_step.dart`, `models.dart`
- `test/engine/models/*_test.dart`

**Estimated scope:** M (5+ small files, but each is boilerplate-shaped)

---

### Task 1.2: Variable interpolator
**Description:** Implement `lib/engine/variables/interpolator.dart` exactly per SPEC's example (`String interpolate(String template, Map<String,String> variables)` using `{{var}}` regex, leaving unresolved tokens literal), plus helper overloads to interpolate a `List<KeyValueEntry>` and a `RequestBody`.

**Acceptance criteria:**
- [ ] `interpolate()` matches SPEC's signature/behavior exactly (unresolved `{{x}}` stays literal, not blanked).
- [ ] Handles: variable at string start/end/middle, multiple variables in one string, no variables, malformed `{{` without closing `}}` (left untouched), variable names with underscores/digits.
- [ ] `interpolateEntries(List<KeyValueEntry>, Map<String,String>)` and `interpolateBody(RequestBody, Map<String,String>)` helpers exist and only interpolate `enabled: true` entries.

**Verification:**
- [ ] `fvm flutter test test/engine/variables/interpolator_test.dart` passes, covering all edge cases above.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 1.1 (for `KeyValueEntry`/`RequestBody` overloads).

**Files likely touched:**
- `lib/engine/variables/interpolator.dart`
- `test/engine/variables/interpolator_test.dart`

**Estimated scope:** S (1-2 files)

---

### Task 1.3: JSON on-disk store
**Description:** Implement `lib/engine/storage/json_store.dart`: reads/writes `environments.json`, `collections.json` (flat `groups[]` + `endpoints[]`, reconstructed into a tree by consumers via `parentGroupId`/`groupId`), `flows.json` under `getApplicationSupportDirectory()/api_flow_studio/`. Use **atomic writes** (write to `<file>.tmp`, then rename over the target) to avoid partial-write corruption, and **defensive reads** (on JSON parse failure, back up the corrupt file to `<file>.corrupt-<timestamp>` and return an empty default rather than crashing).

**Acceptance criteria:**
- [ ] `JsonStore` exposes `readEnvironments()/writeEnvironments()`, `readCollections()/writeCollections()`, `readFlows()/writeFlows()` (async, returning/accepting the Task 1.1 models).
- [ ] Directory is created if missing (`getApplicationSupportDirectory()` + `api_flow_studio` subfolder).
- [ ] Writes are atomic (temp file + rename); a simulated crash mid-write (kill after temp-file write, before rename) never corrupts the previous good file.
- [ ] A hand-corrupted JSON file is detected, backed up, and read returns an empty/default collection instead of throwing.
- [ ] Round-trip test: write a populated model set, read it back, deep-equals the original.

**Verification:**
- [ ] `fvm flutter test test/engine/storage/json_store_test.dart` passes (use a temp directory, not the real APPDATA path — inject the base directory so tests don't touch the user's real app-support folder).
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 1.1.

**Files likely touched:**
- `lib/engine/storage/json_store.dart`
- `test/engine/storage/json_store_test.dart`

**Estimated scope:** M (1 file, but atomic-write + corruption-recovery logic is nontrivial and needs several tests)

---

### Task 1.4: Request executor
**Description:** Implement `lib/engine/http/request_executor.dart`: given an `Endpoint` and a resolved `Map<String,String> variables`, interpolates URL/headers/query/body (via 1.2), builds a `dio` `RequestOptions`/`Response`, and returns a plain result type `ExecutedResponse { int status, Map<String,String> headers, dynamic body, int elapsedMs, int sizeBytes, String? error }`. Configure `dio` with `validateStatus: (_) => true` (Architecture Decision #6) so non-2xx never throws; only transport errors (`DioException` of type connectionTimeout/connectionError/etc.) populate `error` and leave `status`/`body` null.

**Acceptance criteria:**
- [ ] `Future<ExecutedResponse> execute(Endpoint endpoint, {required Map<String,String> variables})` exists, is the single entrypoint used by both the request builder UI and `flow_runner` later.
- [ ] `RequestBody.json`/`formUrlEncoded`/`none` map correctly to dio's `data`/`Content-Type`.
- [ ] `AuthConfig.basic`/`bearer` set the correct `Authorization` header; `AuthConfig.none` sets nothing.
- [ ] A 404/500 response returns normally with that status set — does not throw.
- [ ] A connection-refused/timeout returns `ExecutedResponse` with `error` set and `status == null` — does not propagate an uncaught exception.
- [ ] `elapsedMs` and `sizeBytes` are populated and non-negative.
- [ ] Uses `mocktail` to mock `Dio`/`Interceptor` behavior in tests — no real network calls in unit tests.

**Verification:**
- [ ] `fvm flutter test test/engine/http/request_executor_test.dart` passes (mocktail-mocked dio; cover 2xx, 4xx/5xx, timeout/error, each `RequestBody`/`AuthConfig` variant).
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 1.1, 1.2.

**Files likely touched:**
- `lib/engine/http/request_executor.dart`
- `test/engine/http/request_executor_test.dart`

**Estimated scope:** M (1 file, dio wiring + several branching test cases)

### Checkpoint — After Phase 1
- [ ] `fvm dart run build_runner build --delete-conflicting-outputs` clean.
- [ ] `fvm flutter analyze` clean.
- [ ] `fvm flutter test test/engine` — all green.
- [ ] `grep -r "package:flutter" lib/engine` — empty.
- [x] Review with human: confirm Architecture Decisions #1 (palette source) and #2 (font sourcing approach) — both resolved 2026-09-26 (see Decisions above). #4 (model refinements) accepted as gap-filling, not contradicting SPEC. Phase 2 may proceed.

---

## Phase 2 — UI Shell, Theme, First Vertical Slice

### Task 2.1: App shell & navigation skeleton
**Description:** Replace `lib/main.dart` boilerplate with a real entrypoint wrapped in `ProviderScope`; add `lib/app.dart` hosting `MaterialApp` + a top-level nav shell matching the `code.html` header (`Workspace | Environments | Flows | History` tabs, per `main_workspace`/`flow_builder` references) with empty placeholder bodies for each destination. Delete the counter-app widget/test.

**Acceptance criteria:**
- [ ] `fvm flutter run -d windows` launches to a blank-but-navigable shell with no errors (SPEC criterion #1, early smoke test).
- [ ] Old counter `MyApp`/`MyHomePage`/`widget_test.dart` content is fully removed, replaced with a real widget test for the new shell (e.g. "shell renders the 4 nav destinations").
- [ ] Riverpod `ProviderScope` wraps the app root.

**Verification:**
- [ ] `fvm flutter run -d windows` — manual check, app opens without red-screen.
- [ ] `fvm flutter test test/ui` (new shell test) passes.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** None (can run parallel to Phase 1).

**Files likely touched:**
- `lib/main.dart`, `lib/app.dart`
- `test/widget_test.dart` (replace) or `test/ui/app_shell_test.dart`

**Estimated scope:** S

---

### Task 2.2: Theme tokens from DESIGN.md
**Description:** Build `lib/ui/theme/` — `ColorScheme`/`ThemeData` from the DESIGN.md YAML frontmatter tokens (Architecture Decision #1), a `TextTheme` mapping the `typography` block (Geist for UI, JetBrains Mono for code — pending font-sourcing permission per Decision #2), spacing/radius constants matching the `spacing`/`rounded` YAML blocks, and the shared design-system widgets: `MethodBadge` (using the prose's 5-color method mapping), `StatusBadge` (2xx/3xx/4xx/5xx colors), `VariableChip` (pill shape, resolved/unresolved states per DESIGN.md's Variable Chips component spec).

**Acceptance criteria:**
- [ ] `AppTheme.dark()` (or equivalent) returns a `ThemeData` whose `ColorScheme` values match the DESIGN.md frontmatter hex values 1:1 (surface `#111319`, primary `#c0c1ff`, secondary `#4cd7f6`, tertiary `#4edea3`, error `#ffb4ab`, etc.).
- [ ] `AppSpacing`/`AppRadius` constants exist matching `space-xs..space-xl` (4/6/10/14/20px) and `rounded` (2/4/6/8/12px, full pill).
- [ ] `MethodBadge(method: 'GET'|'POST'|'PUT'|'PATCH'|'DELETE'|'HEAD'|'OPTIONS')` renders the correct hex per the prose Method Badge System table, JetBrains Mono 10px bold uppercase, 2px/6px padding, 3px radius.
- [ ] `StatusBadge(code: int)` maps 2xx/3xx/4xx/5xx to the correct color band.
- [ ] `VariableChip(name, {resolved: bool})` renders pill-shaped, cyan when resolved, amber when unresolved, per DESIGN.md.
- [ ] Fonts render as Geist/JetBrains Mono, not a fallback — contingent on the font-sourcing pre-step being resolved with the human first.

**Verification:**
- [ ] `fvm flutter test test/ui/theme` (widget tests asserting badge colors via `find.byWidgetPredicate` on the resolved `TextStyle`/`Color`).
- [ ] `fvm flutter analyze` clean.
- [ ] Manual: run app, screenshot the shell, eyeball against `design/main_workspace/screen.png` background/surface tones.

**Dependencies:** None (can run parallel to Phase 1). Font-sourcing approach approved (Architecture Decision #2) — before downloading the `.ttf` files, state exact filenames/source URL/size and get explicit per-download confirmation.

**Files likely touched:**
- `lib/ui/theme/app_theme.dart`, `lib/ui/theme/app_spacing.dart`, `lib/ui/theme/app_colors.dart`
- `lib/ui/theme/widgets/method_badge.dart`, `status_badge.dart`, `variable_chip.dart`
- `assets/fonts/*.ttf`, `pubspec.yaml` (fonts section)
- `test/ui/theme/*_test.dart`

**Estimated scope:** M

---

### Task 2.3: Minimal request bar + real Send + response viewer (first vertical slice)
**Description:** The first true end-to-end slice: a method dropdown + URL text field + Send button wired to `request_executor.execute()` (Task 1.4) with an **empty** variables map (no environments yet), displaying the raw status/time/size and a plain-text response body below. No Params/Headers/Body tabs yet — just prove the pipe works.

**Acceptance criteria:**
- [ ] Typing a full URL (e.g. `https://httpbin.org/get`) and clicking Send performs a real HTTP request and displays status code, elapsed ms, and response body text.
- [ ] A network error (bad host) displays an inline error state, doesn't crash the app.
- [ ] Riverpod provider (`requestDraftProvider`/`sendRequestProvider` or similar) holds in-memory draft state; no persistence yet.

**Verification:**
- [ ] `fvm flutter test test/ui/request_builder` (provider unit test with a mocked `RequestExecutor`).
- [ ] Manual: `fvm flutter run -d windows`, send a request to a real reachable URL, see the response — this is the SPEC "send a request, see a response" smoke check, minus persistence.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 1.4, 2.1, 2.2.

**Files likely touched:**
- `lib/ui/request_builder/request_bar.dart`, `lib/ui/request_builder/request_draft_provider.dart`
- `lib/ui/response_viewer/response_panel_minimal.dart` (later replaced/extended by 2.5)
- `test/ui/request_builder/*_test.dart`

**Estimated scope:** M

---

### Task 2.4: Full request builder tabs
**Description:** Extend the request bar screen with `Params | Headers | Body | Auth | Tests | Settings` tabs matching `design/main_workspace/code.html`. Params/Headers are editable `KeyValueEntry` tables with enable checkboxes. Body supports None/JSON (custom syntax-highlighted editor per Decision #3)/form-urlencoded. Auth supports None/Basic/Bearer. "Tests"/"Settings" can be stub placeholder tabs (out of MVP scope per PROJECT_CONTEXT — don't invent test-script functionality).

**Acceptance criteria:**
- [ ] Params/Headers tabs show an editable table (add row, edit key/value, toggle enabled, delete row) backed by `List<KeyValueEntry>` in the draft provider.
- [ ] Body tab: switching None/JSON/form-urlencoded changes the editor shown; JSON editor shows the custom tokenized/colorized view from Decision #3 with line numbers.
- [ ] Auth tab: None/Basic/Bearer selector updates `AuthConfig` in the draft.
- [ ] Sending now uses the full draft (params/headers/body/auth), not just the bare URL from 2.3.
- [ ] Tab bar visually matches `code.html`'s underline/active-state styling (active tab bottom-border in primary color, dirty-indicator dot).

**Verification:**
- [ ] `fvm flutter test test/ui/request_builder` — tab switching, key-value CRUD, body-type switching all covered.
- [ ] Manual: build a POST with 2 headers + JSON body against `https://httpbin.org/post`, confirm the echoed body/headers match what was entered.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 2.3, 1.1 (for `KeyValueEntry`/`RequestBody`/`AuthConfig` shapes).

**Files likely touched:**
- `lib/ui/request_builder/tabs/params_tab.dart`, `headers_tab.dart`, `body_tab.dart`, `auth_tab.dart`
- `lib/ui/theme/widgets/json_editor.dart` (shared with response viewer)
- `test/ui/request_builder/tabs/*_test.dart`

**Estimated scope:** M

---

### Task 2.5: Full response viewer polish
**Description:** Extend the minimal response panel (2.3) into the full `Body | Headers | Cookies | Timeline` tabbed viewer per `main_workspace/code.html`: status/latency/size metric chips, JSON format/Raw/Preview segmented switcher, syntax-highlighted body using the shared `JsonView` widget from Decision #3.

**Acceptance criteria:**
- [ ] Status chip uses `StatusBadge` from 2.2, colored by status band.
- [ ] Body tab shows syntax-highlighted JSON (or raw text for non-JSON) with line numbers, matching the token-color mapping from Decision #3.
- [ ] Headers tab lists response headers in a key-value table.
- [ ] Cookies tab shows parsed `Set-Cookie` values (empty state if none).
- [ ] Timeline tab can be a simple single-entry "request sent → response received, Xms" placeholder (no full network waterfall — out of MVP scope).
- [ ] Copy-body button copies the raw response text to clipboard.

**Verification:**
- [ ] `fvm flutter test test/ui/response_viewer` covers JSON pretty-printing/tokenizing edge cases (empty body, invalid JSON falls back to raw text, nested objects/arrays).
- [ ] Manual: send a JSON-returning request, confirm syntax highlighting and status/latency/size chips render correctly and match `design/main_workspace/screen.png` colors.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 2.3.

**Files likely touched:**
- `lib/ui/response_viewer/response_panel.dart`, `body_tab.dart`, `headers_tab.dart`, `cookies_tab.dart`, `timeline_tab.dart`
- `test/ui/response_viewer/*_test.dart`

**Estimated scope:** M

### Checkpoint — After Phase 2
- [ ] `fvm flutter analyze` and `fvm flutter test` clean.
- [ ] Manual: `fvm flutter run -d windows`, build a full request (any tab combination), send it, inspect the full response viewer.
- [ ] Visual spot-check against `design/main_workspace/screen.png` (informal — full pass is Task 7.1).
- [ ] Review with human before starting persistence (Phase 3) — confirm the `KeyValueEntry`/`RequestBody`/`AuthConfig` UX feels right, since collections will now start saving these shapes to disk.

---

## Phase 3 — Environments + Collections (Persisted)

### Task 3.1: Environments provider
**Description:** Riverpod layer wrapping `json_store.readEnvironments()/writeEnvironments()`: `environmentsProvider` (list) and `activeEnvironmentIdProvider`, with CRUD methods (create/edit/duplicate/delete) and "set active" persisted immediately.

**Acceptance criteria:**
- [ ] Creating/editing/duplicating/deleting an environment persists to `environments.json` (via 1.3) within the same app session.
- [ ] Setting the active environment persists and survives a provider container rebuild (simulated app restart in test).
- [ ] Duplicating an environment produces a new id, copies variables, appends " Copy" (or similar) to the name.

**Verification:**
- [ ] `fvm flutter test test/ui/environments/environments_provider_test.dart` (using an injected temp-dir `JsonStore`).
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 1.1, 1.3.

**Files likely touched:**
- `lib/ui/environments/environments_provider.dart`
- `test/ui/environments/environments_provider_test.dart`

**Estimated scope:** S

---

### Task 3.2: Environment manager screen
**Description:** Build the `Environments` nav destination per `design/environment_manager/screen.png`+`code.html`: left list of environments (colored dot, variable count, "New Environment"), right panel with the selected environment's variable table (Variable/Initial Value/Current Value/Secret/Actions columns), inline "+ Add variable" row.

**Acceptance criteria:**
- [ ] Environment list shows a colored dot per environment (color assignment can be a fixed palette cycle or user-chosen — decide and document; simplest: cycle through `tertiary`/`secondary`/`error` per the dev/qa/prod pattern in the design) and live variable count.
- [ ] Selecting an environment loads its variables into the right-hand table; edits (add/rename/change value/toggle secret/delete row) save on blur or via an explicit save action, persisting through 3.1.
- [ ] "Secret" toggle masks the Current Value column (dots/asterisks) — UI-only, no encryption (per SPEC Boundaries — must not silently build a real vault).
- [ ] Empty state (no environments yet) shows a clear "create your first environment" prompt.

**Verification:**
- [ ] `fvm flutter test test/ui/environments/environment_manager_screen_test.dart` (widget test: create env, add variable, toggle secret, delete).
- [ ] Manual: create 2 environments (e.g. Development/QA), add variables to each, close/reopen the app (`fvm flutter run -d windows` restart), confirm they persisted.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 3.1, 2.2.

**Files likely touched:**
- `lib/ui/environments/environment_manager_screen.dart`, `variable_table.dart`
- `test/ui/environments/environment_manager_screen_test.dart`

**Estimated scope:** M

---

### Task 3.3: Wire active-environment interpolation into request builder
**Description:** Connect `activeEnvironmentIdProvider`'s resolved variables into the request builder's Send action (URL/headers/body all pass through `interpolate()` before hitting `request_executor`), and render `{{variable}}` occurrences inside the URL bar and JSON body editor as `VariableChip`s (resolved = shows tooltip with current value; unresolved = amber warning state per DESIGN.md).

**Acceptance criteria:**
- [ ] With an active environment containing `base_url = https://api.example.com`, a request URL of `{{base_url}}/users` resolves and sends to the real interpolated URL.
- [ ] Switching the active environment (via the sidebar/header dropdown) and re-sending the same saved request resolves against the *new* environment's values — this is SPEC criterion #2, verbatim.
- [ ] An undefined variable (`{{nope}}`) renders as an amber "unresolved" chip and is sent literally (matches `interpolate()`'s documented fallback behavior) rather than causing a crash.
- [ ] The 3px top-of-window environment-health strip (per DESIGN.md "Top Layer") reflects the active environment's semantic color.

**Verification:**
- [ ] `fvm flutter test test/ui/request_builder/variable_interpolation_test.dart`.
- [ ] Manual: 2 environments with different `base_url`, switch active env, send same request, confirm it hits the correct host (use `httpbin.org` style echo or a local mock).
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 3.1, 2.4, 1.2.

**Files likely touched:**
- `lib/ui/request_builder/request_bar.dart` (extend), `active_environment_strip.dart`
- `lib/ui/theme/widgets/variable_chip.dart` (wire real resolution)
- `test/ui/request_builder/variable_interpolation_test.dart`

**Estimated scope:** S

---

### Task 3.4: Collections provider
**Description:** Riverpod layer wrapping `json_store.readCollections()/writeCollections()` for `Group` (nested via `parentGroupId`) and `Endpoint` lists: CRUD for groups (create/rename/reorder/delete, cascading or blocking delete-with-children decision — recommend blocking delete if non-empty, matching common IDE-tree UX) and endpoints (create/update/delete/move between groups).

**Acceptance criteria:**
- [ ] Creating a nested folder structure (category → subcategory) and an endpoint inside it persists correctly, and a tree-reconstruction helper (`buildGroupTree()`) turns the flat `groups[]`+`endpoints[]` lists back into a nested structure for the sidebar.
- [ ] Deleting a non-empty group is either blocked with a clear error or cascades — pick one, document it in the task's code comments, and cover it with a test either way.
- [ ] All operations persist immediately via `json_store`.

**Verification:**
- [ ] `fvm flutter test test/ui/collections/collections_provider_test.dart` — covers nested-group round trip, tree reconstruction, delete semantics.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 1.1, 1.3.

**Files likely touched:**
- `lib/ui/collections/collections_provider.dart`
- `test/ui/collections/collections_provider_test.dart`

**Estimated scope:** S

---

### Task 3.5: Sidebar collection tree UI + save endpoint
**Description:** Build the left sidebar per `design/main_workspace/code.html`: environment selector pill, filter/search box, collapsible collection tree (folder icons, method-badged endpoint rows, item counts), "Execution Flows" section stub (real content in Phase 5), empty-state per-folder ("No endpoints yet — + Add request"). Wire: clicking an endpoint loads it into the request builder (2.4); a "Save" action (button + `⌘S`) persists the current draft as an `Endpoint` in the selected/new group via 3.4.

**Acceptance criteria:**
- [ ] Sidebar renders the full nested tree from `collectionsProvider`, with expand/collapse state kept in local UI state (not persisted — acceptable for v1).
- [ ] Creating a new folder and a new endpoint inside it, then Save, persists via 3.4 — closing and reopening the app (`fvm flutter run -d windows` restart) shows the same tree. This is SPEC criterion #3, verbatim.
- [ ] Clicking a sidebar endpoint row loads its method/url/headers/params/body/auth into the request builder draft (2.4), replacing whatever was there (no unsaved-changes warning needed for v1 — out of scope, don't invent it).
- [ ] Search/filter box narrows the visible tree by endpoint name/path substring match.
- [ ] Empty-collection and empty-workspace states match the design's placeholder copy/iconography.

**Verification:**
- [ ] `fvm flutter test test/ui/collections/sidebar_tree_test.dart` — expand/collapse, filter, select-endpoint-loads-draft, save-persists.
- [ ] Manual (this is explicitly SPEC criterion #3): create a folder + endpoint, save, fully quit and relaunch `fvm flutter run -d windows`, confirm it's still there under `%APPDATA%/api_flow_studio/collections.json`.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 3.4, 2.4, 2.1.

**Files likely touched:**
- `lib/ui/collections/sidebar_tree.dart`, `folder_node.dart`, `endpoint_row.dart`
- `lib/ui/request_builder/request_bar.dart` (wire load/save)
- `test/ui/collections/sidebar_tree_test.dart`

**Estimated scope:** M

### Checkpoint — After Phase 3
- [ ] `fvm flutter analyze`/`fvm flutter test` clean.
- [ ] Manual full pass of SPEC criteria #2 and #3 together: 2 environments, switch active, nested folder + endpoint, save, restart app, confirm persistence and correct variable resolution.
- [ ] Review with human: confirm the "blocking vs. cascading delete" decision from 3.4 and the JSON on-disk layout (`environments.json`/`collections.json` shape) are acceptable before building History/Flows on top of them.

---

## Phase 4 — History

### Task 4.1: History store functions
**Description:** Extend `json_store.dart` (or a thin wrapper) with `appendHistoryEntry(endpointId, HistoryEntry, {maxPerEndpoint: 20})` and `readHistory(endpointId)`, persisted to `history.json` keyed by `endpointId`, auto-trimming to the last N (oldest evicted first) on every append.

**Acceptance criteria:**
- [ ] Appending N+5 entries for one endpoint leaves exactly N (default 20), oldest-first evicted.
- [ ] History for different endpoints doesn't cross-contaminate.
- [ ] Uses the same atomic-write pattern as 1.3.

**Verification:**
- [ ] `fvm flutter test test/engine/storage/history_store_test.dart`.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 1.1, 1.3.

**Files likely touched:**
- `lib/engine/storage/json_store.dart` (extend)
- `test/engine/storage/history_store_test.dart`

**Estimated scope:** S

---

### Task 4.2: Wire Send → save HistoryEntry
**Description:** After every Send from the request builder (2.4) against a *saved* endpoint (has a persisted id — unsaved drafts don't get history), append a `HistoryEntry` (status, headers, body, elapsed, timestamp) via 4.1.

**Acceptance criteria:**
- [ ] Sending a saved endpoint's request 3 times produces 3 history entries, newest last (or first — pick a consistent order and use it in both store and UI).
- [ ] Sending an unsaved draft (no endpoint id) does not error and does not write history.

**Verification:**
- [ ] `fvm flutter test test/ui/request_builder/history_wiring_test.dart`.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 4.1, 3.5, 2.4.

**Files likely touched:**
- `lib/ui/request_builder/request_bar.dart` (extend)
- `test/ui/request_builder/history_wiring_test.dart`

**Estimated scope:** S

---

### Task 4.3: History UI
**Description:** Per-endpoint history panel/tab (e.g. accessible from the sidebar endpoint row's context menu, or a tab next to Params/Headers/Body/Auth) listing the last N responses with status/time/size/timestamp; clicking an entry loads that historical response into the response viewer (read-only) without re-sending.

**Acceptance criteria:**
- [ ] History list shows all persisted entries for the currently-loaded endpoint, most-recent-first.
- [ ] Clicking an entry displays its stored response in the response viewer (2.5's `JsonView`), labeled clearly as historical (not live).
- [ ] Empty state ("No history yet — send a request") when the endpoint has never been sent.

**Verification:**
- [ ] `fvm flutter test test/ui/history/history_panel_test.dart`.
- [ ] Manual: send one endpoint's request several times, open its History, click an old entry, confirm the response viewer shows that snapshot — SPEC criterion #5.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 4.1, 2.2.

**Files likely touched:**
- `lib/ui/history/history_panel.dart`
- `test/ui/history/history_panel_test.dart`

**Estimated scope:** M

### Checkpoint — After Phase 4
- [ ] `fvm flutter analyze`/`fvm flutter test` clean.
- [ ] Manual: SPEC criterion #5 walkthrough (send an endpoint N times, confirm history caps at N and old entries are viewable).
- [ ] Quick review before Phase 5 (Flows) — this is the last checkpoint before the highest-complexity phase.

---

## Phase 5 — Flows

### Task 5.1: value_extractor (dot-notation)
**Description:** Implement `lib/engine/flows/value_extractor.dart`: `dynamic extractValue(Map<String,dynamic> response, String dotPath)` where `response = { "status": int, "headers": Map, "body": dynamic }` and `dotPath` starts with the literal `"response."` prefix (e.g. `"response.body.data.otp"`), walking `.`-separated segments through nested maps/lists (numeric segments index into `List`s). Also `String? extractValueAsString(...)` coercion helper (numbers/bools → `.toString()`, objects/lists → `jsonEncode`, missing/null → `null`) since `FlowStep.extract` values feed into a `Map<String,String>` variable pool.

**Acceptance criteria:**
- [ ] Happy path: nested object path resolves correctly (`response.body.data.otp` → the OTP string).
- [ ] Array-index path resolves correctly (`response.body.items.0.id`).
- [ ] Missing key at any depth returns `null` (no exception).
- [ ] Non-JSON response body (`response.body` is a raw `String`, e.g. plain text or HTML) with a `body.*` path returns `null` gracefully rather than throwing.
- [ ] Path not starting with `"response."` is treated as invalid input — either returns `null` or throws an `ArgumentError`; pick one and document/test it.
- [ ] `extractValueAsString` coercion rules match the spec above exactly, tested for each value type (String/int/double/bool/Map/List/null).

**Verification:**
- [ ] `fvm flutter test test/engine/flows/value_extractor_test.dart` — this is explicitly called out as a risk area, so cover it thoroughly: deep nesting, arrays, missing keys, non-JSON body, type coercion, malformed path.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 1.1 (response shape convention — otherwise pure/standalone; could be built any time after Task 1.1 in parallel with Phase 2-4).

**Files likely touched:**
- `lib/engine/flows/value_extractor.dart`
- `test/engine/flows/value_extractor_test.dart`

**Estimated scope:** S

---

### Task 5.2: flow_runner
**Description:** Implement `lib/engine/flows/flow_runner.dart`: executes a `Flow`'s `steps` in order against a starting variable pool (seeded from the active `Environment`'s resolved variables). For each step: interpolate+execute via `request_executor` (1.4), evaluate `assertField`/`assertExpected` if present (via `value_extractor`, stringified comparison — success defaults to "request completed without a transport error" when no assertion is set, per Architecture Decision #7), extract `step.extract` variables into the accumulated pool (visible to all subsequent steps, per the registration-flow example in PROJECT_CONTEXT), and on failure with `stopOnFailure == true`, mark all remaining steps `skipped` without executing them. Returns a `FlowRunResult { List<FlowStepResult> stepResults }` where `FlowStepResult { status: success|failure|skipped, ExecutedResponse? response, Map<String,String> extractedVariables, String? failureReason }`.

**Acceptance criteria:**
- [ ] 3-step flow where step 1 extracts a variable and step 2's URL/body references it via `{{var}}` — step 2's actual outgoing request contains the interpolated value (verifiable via the mocked dio call args).
- [ ] A step with an unmet assertion (`assertField`/`assertExpected` mismatch) is marked `failure`.
- [ ] A step with `stopOnFailure: true` that fails causes every subsequent step to be marked `skipped` (not executed — assert the mock `request_executor` was never called for them).
- [ ] A step with `stopOnFailure: false` that fails still lets subsequent steps run.
- [ ] Variables accumulate across the whole run (step 3 can use a variable extracted in step 1, not just step 2).
- [ ] A step whose HTTP call throws a transport error (per 1.4's `error` field) is marked `failure` with `failureReason` populated even with no assertion configured.

**Verification:**
- [ ] `fvm flutter test test/engine/flows/flow_runner_test.dart` — this is explicitly the highest-risk file per the task brief; cover step-order, variable propagation, stop-on-failure/skip, assertion pass/fail, no-assertion-success-on-transport-success. Use `mocktail` to mock `RequestExecutor`.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 5.1, 1.2, 1.4, 1.1.

**Files likely touched:**
- `lib/engine/flows/flow_runner.dart`
- `test/engine/flows/flow_runner_test.dart`

**Estimated scope:** M

---

### Task 5.3: Flows provider
**Description:** Riverpod layer wrapping `json_store.readFlows()/writeFlows()`: CRUD for `Flow`/`FlowStep` (create flow, add/remove/reorder step, edit step's `extract`/`assertField`/`assertExpected`/`stopOnFailure`).

**Acceptance criteria:**
- [ ] Creating a flow with 3 steps referencing existing `Endpoint` ids persists and round-trips via `flows.json`.
- [ ] Reordering steps persists the new order.

**Verification:**
- [ ] `fvm flutter test test/ui/flows/flows_provider_test.dart`.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 1.1, 1.3.

**Files likely touched:**
- `lib/ui/flows/flows_provider.dart`
- `test/ui/flows/flows_provider_test.dart`

**Estimated scope:** S

---

### Task 5.4a: Flow builder UI scaffold
**Description:** Per `design/flow_builder/screen.png`+`code.html`: header with flow name (inline-editable) + "Run Flow"/"Save Flow" buttons, vertical connector-line step-card list, "+ Add Next Step to Pipeline" button opening a picker over existing saved `Endpoint`s (from `collectionsProvider`, 3.4) to append a new `FlowStep`. Reordering via drag or up/down controls (drag-and-drop is a nice-to-have; up/down buttons are an acceptable, simpler MVP substitute — document the choice).

**Acceptance criteria:**
- [ ] Building a flow of 3+ steps by picking saved endpoints, matching the design's card layout (method badge + path + description per card).
- [ ] Steps can be removed and reordered; changes persist via 5.3.
- [ ] Empty-flow state matches the design's "Template Reference: Empty Flow State" placeholder.

**Verification:**
- [ ] `fvm flutter test test/ui/flows/flow_builder_screen_test.dart` — add/remove/reorder steps.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 5.3, 3.5, 2.2.

**Files likely touched:**
- `lib/ui/flows/flow_builder_screen.dart`, `step_card.dart`, `add_step_picker.dart`
- `test/ui/flows/flow_builder_screen_test.dart`

**Estimated scope:** M

---

### Task 5.4b: Flow builder — extract mapping & stop-on-failure editor
**Description:** Extend each step card with the "Extract Output Variables" editable mapping (variable name ← dot-path rows, add/remove), the "Stop on failure" toggle, and (optional read-only) payload-template preview pulled from the referenced endpoint's body, per the `code.html` reference.

**Acceptance criteria:**
- [ ] Adding an extract row (`variable_name`, `response.body.x.y`) on a step persists into that `FlowStep.extract` map via 5.3.
- [ ] Toggling "Stop on failure" persists `FlowStep.stopOnFailure`.
- [ ] Assertion editor (field + expected value) present and persists `assertField`/`assertExpected`.

**Verification:**
- [ ] `fvm flutter test test/ui/flows/step_card_editor_test.dart`.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 5.4a.

**Files likely touched:**
- `lib/ui/flows/step_card.dart` (extend), `extract_mapping_editor.dart`
- `test/ui/flows/step_card_editor_test.dart`

**Estimated scope:** S

---

### Task 5.5a: Flow run view — wiring & status icons
**Description:** Per `design/flow_run_view/screen.png`+`code.html`: reuse the step-card list from 5.4a/b but in run mode — "Run Flow" triggers `flow_runner.run()` (5.2) using the currently active environment's variables (3.1), and each card shows a live result icon (success `check_circle`/fail `cancel`/skipped, matching the actual `code.html` icon classes found) as results stream in.

**Acceptance criteria:**
- [ ] Running a 3+ step flow where step 1 extracts a variable used by step 2 completes end-to-end and each step card updates with its real result icon in order — this is SPEC criterion #6's first half.
- [ ] A step configured to fail (e.g. bad assertion) with `stopOnFailure: true` shows itself as failed and all later steps as visually skipped, matching SPEC criterion #6's second half.
- [ ] Result icons match DESIGN.md coloring (`tertiary`/success, `error`/fail, muted/skipped).

**Verification:**
- [ ] `fvm flutter test test/ui/flows/flow_run_view_test.dart` (mocked `FlowRunner`/`RequestExecutor`).
- [ ] Manual: build the PROJECT_CONTEXT registration-flow example (check-user-exists → send-OTP → validate-OTP → check-email-used → create-user) against a reachable test API (or a local mock server), run it, watch the step-by-step results.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 5.2, 5.4b, 3.1.

**Files likely touched:**
- `lib/ui/flows/flow_run_view_screen.dart`, `run_step_card.dart`
- `test/ui/flows/flow_run_view_test.dart`

**Estimated scope:** M

---

### Task 5.5b: Flow run view — detail panel, error diagnostics, re-run-from-step
**Description:** Add the expandable per-step request/response detail (reusing `JsonView` from 2.5) and the failed-step's large error-detail panel (error classification, server diagnostics text, "Re-run From Step N" button per `code.html`'s literal copy) that re-invokes `flow_runner` starting at a given step index using the variable pool accumulated up to that point in the last run.

**Acceptance criteria:**
- [ ] Expanding a completed step card shows its actual request (interpolated) and response (status/headers/body) via `JsonView`.
- [ ] A failed step shows the error-detail panel with a human-readable classification (e.g. "Assertion failed: expected X, got Y" vs "Network error: connection timed out").
- [ ] "Re-run From Step N" re-executes only steps N..end, reusing the variable pool as it stood entering step N from the previous run (not re-running steps 1..N-1).

**Verification:**
- [ ] `fvm flutter test test/ui/flows/flow_run_view_detail_test.dart` — covers expand/collapse, error panel content, re-run-from-step variable reuse.
- [ ] Manual: force step 2 to fail (bad assertion), fix the underlying issue, use "Re-run From Step 2", confirm steps 1 isn't re-executed (no duplicate side effects) and the flow completes.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 5.5a.

**Files likely touched:**
- `lib/ui/flows/run_step_card.dart` (extend), `error_detail_panel.dart`
- `lib/engine/flows/flow_runner.dart` (extend with a `runFrom(stepIndex, seedVariables)` entrypoint)
- `test/ui/flows/flow_run_view_detail_test.dart`, `test/engine/flows/flow_runner_test.dart` (extend)

**Estimated scope:** M

### Checkpoint — After Phase 5
- [ ] `fvm flutter analyze`/`fvm flutter test` clean.
- [ ] Manual: full SPEC criterion #6 walkthrough — 3+ step flow, variable propagation step1→step2, stop-on-failure→skip demonstration, re-run-from-step.
- [ ] Review with human: this closes out the hardest phase — good point to reassess remaining scope/timeline before Phase 6/7.

---

## Phase 6 — curl Paste-Import

### Task 6.1: curl_parser
**Description:** Implement `lib/engine/curl/curl_parser.dart`: `Endpoint parseCurl(String curlCommand)` handling `curl <url>`, `-X <METHOD>`/`--request`, `-H '<header>'`/`--header` (repeated), `-d '<data>'`/`--data`/`--data-raw` (implies POST + JSON or form body depending on Content-Type header presence), `-u user:pass`/`--user` (→ `AuthConfig.basic`), `-b`/`--cookie` (optional, can be mapped to a header), quoted-argument handling (both `'...'` and `"..."`), and multi-line curl commands using trailing `\` continuations (common when copy-pasted from browser devtools/Postman "Copy as cURL").

**Acceptance criteria:**
- [ ] A simple `curl https://api.example.com/users` parses to a `GET` `Endpoint` with that URL, no headers/body.
- [ ] A `curl -X POST -H 'Content-Type: application/json' -d '{"a":1}' https://api.example.com/users` parses to a `POST` endpoint with the header, `RequestBody.json('{"a":1}')`.
- [ ] `-u alice:secret` maps to `AuthConfig.basic(username: 'alice', password: 'secret')`.
- [ ] Multi-line commands with `\` line continuations (the actual copy-paste format from Chrome DevTools) parse identically to their single-line equivalent.
- [ ] Malformed/unparseable input raises a clear, catchable error (not a silent wrong result) so the UI can show "couldn't parse this curl command."

**Verification:**
- [ ] `fvm flutter test test/engine/curl/curl_parser_test.dart` — cover all bullet points above plus at least one real DevTools-style multi-line "Copy as cURL (bash)" sample.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 1.1 (can be built any time after Task 1.1, in parallel with Phase 2-5).

**Files likely touched:**
- `lib/engine/curl/curl_parser.dart`
- `test/engine/curl/curl_parser_test.dart`

**Estimated scope:** M (curl argument parsing has real edge-case surface area — quoting, escaping, flag aliases)

---

### Task 6.2: Paste-curl UI hook
**Description:** Add a "Paste curl" entry point (e.g. sidebar `+` menu item, per the `add`/`create_new_folder` icons already present in the Explorer header) opening a dialog with a multi-line text field; on submit, calls `curl_parser.parseCurl()` and opens the result in the request builder as a new unsaved draft (user still explicitly picks a group and saves via existing 3.5 flow).

**Acceptance criteria:**
- [ ] Pasting a curl command and confirming populates the request builder's method/URL/headers/body exactly as parsed — SPEC criterion #7.
- [ ] A parse failure shows an inline error message in the dialog, doesn't crash, lets the user retry/edit the pasted text.

**Verification:**
- [ ] `fvm flutter test test/ui/collections/paste_curl_dialog_test.dart`.
- [ ] Manual: copy a real "Copy as cURL" command from a browser's devtools Network tab, paste it in, confirm the request builder is correctly prefilled, then Save it into a collection.
- [ ] `fvm flutter analyze` clean.

**Dependencies:** 6.1, 3.5, 2.4.

**Files likely touched:**
- `lib/ui/collections/paste_curl_dialog.dart`
- `test/ui/collections/paste_curl_dialog_test.dart`

**Estimated scope:** S

### Checkpoint — After Phase 6
- [ ] `fvm flutter analyze`/`fvm flutter test` clean.
- [ ] Manual: SPEC criterion #7 walkthrough.

---

## Phase 7 — Polish & Sign-off

### Task 7.1: Visual QA pass vs. screen.png
**Description:** Side-by-side comparison of every implemented screen against its `design/*/screen.png`, adjusting spacing/color/typography deviations found. This is where Architecture Decision #1's palette choice gets its real validation.

**Acceptance criteria:**
- [ ] Each of the 4 screens (`main_workspace`, `environment_manager`, `flow_builder`, `flow_run_view`) has been screenshotted from the running app and compared against its reference PNG; deviations beyond minor rendering differences (font metrics, OS chrome) are fixed or explicitly logged as known gaps.

**Verification:**
- [ ] Manual only — no automated visual-regression tooling in the approved stack (adding one would be a new dependency requiring "ask first").
- [ ] `fvm flutter analyze` clean after any fixes.

**Dependencies:** All UI phases (2-6).

**Files likely touched:** Varies — whatever screens need adjustment.

**Estimated scope:** M

---

### Task 7.2: Success-criteria walkthrough & edge-case hardening
**Description:** Run every SPEC "Success Criteria" checkbox end-to-end in one sitting on Windows, and harden any rough edges found (empty states, JSON-parse-error handling in the body editor, network-error toasts, etc.) without expanding scope beyond what's already specced.

**Acceptance criteria:**
- [ ] All 9 SPEC Success Criteria checkboxes pass as literally written.
- [ ] `fvm flutter analyze` passes clean.
- [ ] `fvm flutter test` passes for all of `test/engine/**`.

**Verification:**
- [ ] `fvm flutter run -d windows` — full manual walkthrough per SPEC's Testing Strategy section.
- [ ] `fvm flutter analyze`
- [ ] `fvm flutter test`

**Dependencies:** Everything.

**Files likely touched:** Varies (bugfixes only).

**Estimated scope:** M

---

### Task 7.3 [optional, ask-first]: Windows app icon from logo asset
**Description:** Replace `windows/runner/resources/app_icon.ico` with an icon derived from `design/api_flow_studio_logo/`. SPEC explicitly lists this as an Open Question ("resolver al implementar `windows/runner` icon") and it's not required for any Success Criterion — do not start this without asking the human first, both because it's flagged as undecided scope and because generating/converting the SVG to `.ico` needs a tool decision (no icon-conversion package in the approved stack).

**Acceptance criteria:**
- [ ] Human has confirmed they want this done and where the logo should appear (window/taskbar icon vs. in-UI only, per the SPEC open question).
- [ ] If approved: `app_icon.ico` updated, `windows/runner/Runner.rc`/`resource.h` untouched (icon swap only), app relaunches showing the new icon.

**Verification:**
- [ ] Manual: check taskbar/title-bar icon after `fvm flutter run -d windows`.

**Dependencies:** None — can be done any time, but gated on explicit human approval per SPEC's own open question.

**Files likely touched:**
- `windows/runner/resources/app_icon.ico`

**Estimated scope:** S

### Checkpoint — Final
- [ ] All SPEC Success Criteria checked.
- [ ] `fvm flutter analyze` clean, `fvm flutter test` all green.
- [ ] Human sign-off.

---

## Phase 8 — Visual Parity Pass vs. Stitch Designs

**Context:** the MVP (Phases 1-7) is done and running natively on Windows.
Comparing the real app against `design/*/screen.png`, the user flagged that
it "doesn't look like the designs." That's real: every screen was
deliberately built as a functional *subset* of the much more elaborate
Stitch mockups (colors/typography/spacing tokens match per Task 7.1, but a
lot of visual richness was left out as an explicitly-logged known gap, not
a defect). This phase closes that gap with a pure visual/UI pass: it reuses
data the app already has and does not add new backend capability. Where a
mockup element implies a feature we don't have (multi-workspace switching,
a Console feature, global search, user accounts, cloud sync, run
history/run IDs, a scheduler, fabricated per-step latency), it's explicitly
skipped per-task below rather than faked — if the user wants any of those
as a real feature later, that's a separate scope decision.

**Key finding:** the header + sidebar chrome is pixel-identical across all
4 mockups. Task 8.1 fixes it once, which closes a large fraction of the gap
on every screen simultaneously, before any screen-specific work starts.

All existing widget-test `Key`/`ValueKey` identifiers must be preserved
throughout (only layout/styling changes around them) so the current
210-test suite stays green without rewrites; new elements get new keys and,
where a real behavior (not just pixels) can be verified cheaply, a new
test.

### Task 8.1: Shared app shell (header + sidebar chrome)
**Description:** Build `AppLogoMark` (a new hand-painted `CustomPainter`
widget reproducing `design/api_flow_studio_logo/code.html`'s SVG exactly —
no `flutter_svg` dependency, matches the project's existing hand-rolled
JSON-syntax-highlighter pattern for small vector graphics). Restyle
`_NavBar` in `lib/app.dart`: taller header (56px), `surfaceContainerLow`
background, a thin `tertiary`-colored accent strip along the very top of
the window, the new logo + wordmark, nav items get a rounded
`surfaceContainerHigh` background pill when active (today: bold text only,
no background), and the environment pill restyled (small pulsing dot +
uppercase name + chevron) reusing the existing `EnvironmentSwitcher` logic.
Restyle `SidebarTree`: width 280→256 (update the `SizedBox(width: 280)`
call site in `app.dart`'s `_DestinationBody` too), an "EXPLORER" label row
above the search field with the existing "New folder"/"Paste curl" icon
actions relocated into it, top-level folder icons colored by cycling a
small palette (new `AppColors.folderIconColor(index)` helper, same pattern
as the existing `environmentDotColor`), and a slim footer showing the real
app version ("API Flow Studio v1.0.0" from `pubspec.yaml`) in place of the
mock's fake "Proxy: Localhost" line.

**Out of scope (decorative-only in the mock, or implies a feature we don't
have):** macOS-style traffic-light window dots (this is a Windows app with
its own native title bar — fake traffic lights inside the content area
would look wrong, not authentic), "Personal Workspace" dropdown (implies
multi-workspace switching), Settings/Search header icons and the user
avatar (no settings screen, global search, or user accounts exist), the
"Console" nav item (no console feature).

**Acceptance criteria:**
- [ ] The header and sidebar visually match `design/*/code.html`'s shared
      chrome (logo, header height/colors, active-tab pill, sidebar width,
      EXPLORER header, colored folder icons, version footer) on all 4
      screens, modulo the explicitly out-of-scope items above.
- [ ] Every existing sidebar/header widget test still passes unmodified
      (same `Key`s, just restyled/relocated).

**Verification:**
- [ ] `fvm flutter analyze` clean; `fvm flutter test` green (full 210-test
      suite, unmodified).
- [ ] Manual: the Task-7.1-style throwaway screenshot-capture harness
      (`RepaintBoundary.toImage()` + real fonts via `FontLoader`, deleted
      after use) on all 4 screens, eyeballed against `design/*/screen.png`.

**Dependencies:** None (first task in this phase).

**Files likely touched:**
- `lib/ui/theme/widgets/app_logo.dart` (new)
- `lib/app.dart` (`_NavBar`, `AppShell`, `_DestinationBody`'s sidebar width)
- `lib/ui/collections/sidebar_tree.dart`
- `lib/ui/theme/app_colors.dart` (new `folderIconColor` helper)

**Estimated scope:** M

---

### Task 8.2: Environment Manager restyle
**Description:** Per `design/environment_manager/code.html`: convert the
environment list from plain `ListTile`s to card-style rows with a colored
left-accent bar (`environmentDotColor`) and an "ACTIVE" badge on the
selected one. Convert the variable editor into a real table with a header
row (Name / Value / Secret / Actions — 4 columns; **no** "Initial vs
Current Value" split, since `EnvironmentVariable` only ever had one
`value` field and adding a second would be a data-model change, not a
restyle). Add the static "Pro tip: reference variables with
`{{variable_name}}`" callout.

**Out of scope:** memory-footprint bar chart (fabricated metric), Import/
Export .env (real feature), row checkboxes/bulk actions (real feature), a
"Global Variables" pseudo-environment (product decision, not in SPEC),
"Sync Cloud" button, Production "read-only lock" badge (would visually
promise protection the app doesn't enforce).

**Acceptance criteria:**
- [ ] Environment list and variable table visually match the mock's
      layout/structure (card rows, table header, pro-tip callout), modulo
      the explicitly out-of-scope items above.
- [ ] Every existing `environment_manager_screen_test.dart` test still
      passes unmodified.

**Verification:**
- [ ] `fvm flutter analyze` clean; `fvm flutter test` green.
- [ ] Manual: screenshot-capture harness vs `design/environment_manager/screen.png`.

**Dependencies:** 8.1 (shares the restyled shell).

**Files likely touched:**
- `lib/ui/environments/environment_manager_screen.dart`

**Estimated scope:** M

---

### Task 8.3: Flow Builder restyle
**Description:** Per `design/flow_builder/code.html`: center the step
column in a narrower max-width (~900px) instead of full width, with a
small chevron-down connector between consecutive cards. Add a "TERMINAL"
badge on the last step (computed from `isLast`, already available). Add a
read-only "Payload Template" preview showing the referenced endpoint's
`body` (via the existing `JsonView`/`prettyResponseBody` pattern) when
it's JSON — this is exactly the "(optional read-only) payload-template
preview" named in the original Task 5.4b description and never built; low
effort since the data and rendering widget both already exist.

**Out of scope:** per-step kebab menu (mock defines no real actions behind
it), fabricated per-step Latency/Delay text (no data source before a run
exists), "Schedule Run" button (implies a scheduler), the bottom "Empty
Flow State Reference Card" (redundant with our real empty-state message).

**Acceptance criteria:**
- [ ] Step cards visually match the mock's centered pipeline layout,
      connectors, TERMINAL badge, and payload preview, modulo the
      explicitly out-of-scope items above.
- [ ] Every existing flow-builder widget test (`flow_builder_screen_test.dart`,
      `step_card_editor_test.dart`) still passes unmodified.

**Verification:**
- [ ] `fvm flutter analyze` clean; `fvm flutter test` green.
- [ ] Manual: screenshot-capture harness vs `design/flow_builder/screen.png`.

**Dependencies:** 8.1.

**Files likely touched:**
- `lib/ui/flows/step_card.dart`
- `lib/ui/flows/flows_screen.dart`

**Estimated scope:** M

---

### Task 8.4: Flow Run View restyle
**Description:** Per `design/flow_run_view/code.html`: restructure from
single-column-with-inline-expand into the mock's 2-panel layout — a left
timeline list (status icon + method + path + code, no inline expansion)
and a right detail panel for the *selected* step, reorganized into tabs
(Error Details shown only when failed / Request Sent / Response Body /
Headers) with `DefaultTabController`+`TabBar` — the same tab pattern
already used in `RequestBar`/`ResponsePanel`. All the underlying data
(request URL, response, `ErrorDetailPanel`) already exists; this only
reorganizes how it's displayed. Restyle the summary strip and "Re-run From
Step N" as small pill badges matching the mock.

**Out of scope:** latency sparkline SVG, run IDs ("RUN #1048-DX",
"run_exec_..."), "triggered by \<user\>" (no user-account concept in a
single-user local app), "Export Run Log"/"Debug in Console" buttons, the
"Failure Policy Triggered" + "Insert Step Here" suggested-fix card
(speculative, out of scope), the round-trip latency Gantt breakdown
(timing detail not measured at that granularity).

**Acceptance criteria:**
- [ ] The run view visually matches the mock's 2-panel + tabbed-inspector
      layout, modulo the explicitly out-of-scope items above.
- [ ] Every existing `flow_run_view_test.dart`/`flow_run_view_detail_test.dart`
      test still passes, adapted only where the interaction model itself
      changed (inline expand → select-to-view-detail) — re-run-from-step
      and error classification must still be reachable and tested.

**Verification:**
- [ ] `fvm flutter analyze` clean; `fvm flutter test` green.
- [ ] Manual: screenshot-capture harness vs `design/flow_run_view/screen.png`.

**Dependencies:** 8.1.

**Files likely touched:**
- `lib/ui/flows/flow_run_view_screen.dart`
- `lib/ui/flows/run_step_card.dart`

**Estimated scope:** L (interaction-model change, not just restyle)

### Checkpoint — After Phase 8
- [ ] `fvm flutter analyze`/`fvm flutter test` clean (full suite).
- [ ] `fvm flutter build windows` succeeds; user does a final visual pass
      on the real running app against all 4 `design/*/screen.png`.
- [ ] Human sign-off.

---

## Testing Note: widget tests + real JsonStore I/O (found during Task 3.2)

Any `testWidgets()` test that pumps a widget backed by a provider doing
real `dart:io` work (any `AsyncNotifier` reading/writing through
`JsonStore` -- environments, and from Phase 3 onward collections, flows,
history) **hangs forever** unless the whole body runs inside
`tester.runAsync()`. `testWidgets()` runs in a synchronous/fake-time zone
by default; real file I/O's `Future` never completes there. Plain
`test()` (used by `json_store_test.dart`, `environments_provider_test.dart`)
doesn't need this -- it runs in a normal zone. `pumpAndSettle()` also
doesn't reliably detect the loading -> data transition even inside
`runAsync` -- use a short real delay (`Future.delayed`) plus one or two
plain `pump()`s instead. Every widget test file for Collections/Flows/
History providers (Tasks 3.5, 5.3-5.5, 4.3) needs this same pattern.

Two more real bugs `environment_manager_screen_test.dart` caught while
building the pattern above, both fixed in `JsonStore`/`EnvironmentsNotifier`
and worth remembering for the same classes going forward:
- `File.rename()` overwriting an existing file can transiently fail on
  Windows with a sharing violation (antivirus/Search briefly holding a
  handle) -- `JsonStore._writeAtomicUnqueued` now retries with backoff.
- Two overlapping async mutations (e.g. two fast field edits before a
  rebuild) can both read the same pre-mutation state and race to
  overwrite each other -- both `JsonStore` (per-filename write queue) and
  `EnvironmentsNotifier` (per-notifier mutation queue) now serialize
  their operations. Any future *Notifier following this CRUD-over-JsonStore
  shape should use the same queued-mutation pattern, not `await future`
  followed by an unguarded `state = ...`.

One more, found during Task 4.3: jumping straight to a non-adjacent
`TabBar`/`TabBarView` tab in a widget test (`tester.tap` on a tab far from
the current one, or setting `TabController.index` directly) is animation-
driven and, combined with the `runAsync` + real-I/O provider underneath it,
didn't reliably settle no matter how the pump/settle calls were tuned --
`pumpAndSettle()` timed out waiting on the *provider's* real I/O, and a
fixed number of bare `pump()` calls never advanced the *animation* clock
at all (that needs `pump(duration)`, not `pump()`). Rather than hand-tune
this further, `history_panel_test.dart` tests `HistoryTab` directly
against a pre-populated store instead of driving `RequestBar`'s tab bar
end-to-end -- Send -> history persistence is already covered by
`history_wiring_test.dart`. If Phase 5's flow builder/run screens need to
test switching to a specific tab that isn't adjacent to the default one,
budget time for this same friction, or prefer testing the target widget
standalone like history_panel_test.dart does.

## Risks and Mitigations

| # | Risk | Impact | Mitigation |
|---|------|--------|------------|
| 1 | **DESIGN.md's two conflicting palettes** (YAML frontmatter vs. prose "Colors" section vs. the logo's own raw hex) could lead to an implementer picking the wrong one, failing the screen.png visual-comparison criterion. | High | Resolved explicitly in Architecture Decision #1: frontmatter/HTML tokens are canonical for `ColorScheme`; prose's method-badge/status hex values layered on top as a narrow addition. Flagged for human confirmation before Task 2.2. |
| 2 | **Fonts (Geist, JetBrains Mono) aren't bundled** and adding `google_fonts` is an unapproved new dependency; a network-fetched font is also a poor fit offline. | Medium | RESOLVED: bundle static `.ttf` assets (Decision #2), approach approved by user 2026-09-26. Per-file download still needs explicit confirmation (filename/source/size) at Task 2.2 time. |
| 3 | **`value_extractor` dot-notation edge cases** (arrays, missing keys, non-JSON body, type coercion into `Map<String,String>`). | High (silently wrong flows are hard to debug) | Concrete contract defined in Task 5.1 with an explicit coercion table (numbers/bools→`toString()`, objects/lists→`jsonEncode`, missing→`null`) and an exhaustive test list before `flow_runner` is built on top of it. |
| 4 | **`flow_runner` variable-scope propagation** (does step 3 see step 1's extracted variable, not just step 2's?) and **failure semantics** (does a bare 404 count as "failure" with no assertion configured?). | High (directly determines whether the registration-flow example from PROJECT_CONTEXT even works) | Resolved explicitly in Architecture Decisions #6/#7: single accumulating variable pool for the whole run; "success" with no assertion = transport succeeded regardless of HTTP status; `dio` configured `validateStatus: (_) => true`. Tested exhaustively in Task 5.2. |
| 5 | **Interpolation design (interceptor vs. pre-processing step)** could otherwise couple `engine/variables` to `dio` internals, hurting testability and reuse in `flow_runner`. | Medium | Resolved in Decision #7: `interpolate()` stays a pure function; `request_executor.execute(endpoint, variables)` calls it internally. `flow_runner` reuses the exact same entrypoint per step. |
| 6 | **JSON file corruption / partial writes** — a crash mid-write to `environments.json`/`collections.json`/`flows.json` could brick the app on next launch (unrecoverable parse error on startup). | High (data loss on the user's only local persistence layer) | Atomic write pattern (temp file + rename) and defensive read-with-backup-and-reset in Task 1.3, tested with a simulated crash-mid-write scenario. |
| 7 | **Mapping DESIGN.md tokens into Flutter `ThemeData` cleanly** while also supporting the hand-rolled JSON syntax highlighter (no approved highlighting package). | Medium | Task 2.2 defines exact token→`Color`/`TextStyle` mappings up front (spacing/radius constants, badge/status/chip widgets) so later UI tasks (2.4, 2.5, 5.4/5.5) consume a stable, already-verified design-system layer rather than each reinventing styling. |
| 8 | **Matching the Stitch HTML reference layout in Flutter widgets** (3-pane resizable IDE layout, sticky headers, connector-line step cards) is a lot of custom layout work with no off-the-shelf Flutter widget for several pieces (resizable split panes, the vertical flow connector line). | Medium | Called out per-task with the exact `code.html` structure already read and summarized (e.g. Task 5.4a/5.5a reference the real card/connector markup). Resizable panes can start as fixed-ratio `Row`/`Column` splits in early tasks (2.3-2.5) with drag-resize as a stretch goal noted but not blocking — avoids scope creep into a full pane-management system not in SPEC's MVP list. |
| 9 | **`Group`/`Endpoint`/`Environment` field gaps in PROJECT_CONTEXT.md's literal data model** (no `enabled` flag on key-value rows, no body/auth type discriminators, no `parentGroupId`, no per-variable `secret` flag) could cause rework if discovered mid-Phase-3/5 instead of at modeling time. | Medium | Resolved explicitly in Architecture Decision #4 at Task 1.1, before anything is built on top of the models. Flagged for human confirmation at the Phase 1 checkpoint. |
| 10 | **Deep nested-folder `Group` delete semantics** (cascade vs. block) aren't specified anywhere in SPEC/PROJECT_CONTEXT. | Low | Task 3.4 requires picking one, documenting it in code, and testing it — not blocking, but flagged so it's a deliberate choice, not an accident. |
| 11 | **curl parsing edge cases** (multi-line continuations, quoting styles, flag aliases) are a classic source of "works on my example, breaks on a real copy-paste." | Medium | Task 6.1 explicitly requires testing against a real DevTools-style multi-line "Copy as cURL" sample, not just hand-written single-line examples. |

---

## Open Questions (carried from SPEC.md + newly found)

1. **Palette source-of-truth (Risk #1)** — RESOLVED 2026-09-26: frontmatter/HTML tokens are canonical, not the prose section.
2. **Font sourcing (Risk #2)** — RESOLVED 2026-09-26: user approved downloading + bundling Geist + JetBrains Mono `.ttf` files. Exact filenames/source/size still need per-download confirmation at Task 2.2 time.
3. **Storage not git-versionable** (from SPEC's own Open Questions) — out of v1 scope per SPEC, no task needed, just documented.
4. **Logo/app-icon usage** (from SPEC's own Open Questions) — deferred to optional Task 7.3, gated on explicit approval.
5. **`Group` delete semantics** (cascade vs. block) — pick one in Task 3.4, not a blocker but worth a one-line human confirmation.
6. **Environment "colored dot" assignment rule** — fixed palette cycle vs. user-chosen color; Task 3.2 proposes a fixed cycle (simplest, matches the dev/qa/prod pattern shown in the design) unless the human prefers a color picker (that would be new, un-specced scope — flag if requested).

---

### Critical Files for Implementation
- `E:\Devs\api_flow_studio\lib\engine\models\flow_step.dart` (and sibling model files) — every other engine and UI file depends on these shapes; Architecture Decision #4's refinements must land here first.
- `E:\Devs\api_flow_studio\lib\engine\variables\interpolator.dart` — the single pure function reused by `request_executor`, the request builder's variable chips, and `flow_runner`.
- `E:\Devs\api_flow_studio\lib\engine\http\request_executor.dart` — the one HTTP entrypoint used by both the manual request builder and every flow step; its `validateStatus`/error-handling design (Decision #6) determines flow-runner correctness.
- `E:\Devs\api_flow_studio\lib\engine\flows\flow_runner.dart` — highest-risk file per the brief; variable-scope propagation and stop-on-failure/skip semantics live here (Decisions #6/#7, Risk #4).
- `E:\Devs\api_flow_studio\lib\engine\storage\json_store.dart` — sole persistence layer for environments/collections/flows/history; atomic-write and corruption-recovery design (Risk #6) protects the user's only local data store.