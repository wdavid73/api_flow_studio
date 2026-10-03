# Implementation Plan: integration tests

Spec: [SPEC-integration-tests.md](../../SPEC-integration-tests.md). Checklist
in [todo.md](todo.md).

> Saved under `tasks/integration-tests/` because `tasks/plan.md` and
> `tasks/todo.md` still belong to the v1 plan, which has open items.

## Overview

Add user-journey tests that run the whole `ApiFlowStudioApp` with its real
engine (variables, session, flows, history, storage) and only replace the HTTP
layer with a scripted `FakeBackend`. Each journey is written once and runs two
ways: with `flutter_test` (no window, in-memory storage) and with the
`integration_test` package on the real Windows app (temp folder on disk).

## Architecture Decisions

- **Risk first.** The riskiest part is the shared-journey architecture and
  running it under both runners, so the first task builds the whole stack with
  one small journey and runs it both ways before anything else is written.
- **Journeys are plain functions** (`void defineXJourney(JourneyHarness
  Function() harness)`) living in `integration_test/journeys/`; the
  `flutter_test` runner imports them from `test/integration/`. One copy of
  every journey.
- **`JourneyHarness` hides the differences** between runners: how the store is
  created (in memory vs. a temp folder), how the app is launched and
  restarted, and the logical window size.
- **`FakeBackend implements RequestExecutor`** with scripted routes and a call
  log, injected through `requestExecutorProvider`. The real
  `SessionRequestExecutor`, interpolation, flow runner and history sit in
  front of it unchanged.
- **Test through `Key`s and visible text that already exist.** No `lib/`
  changes are planned; a missing `Key` is the only allowed exception, and
  anything bigger stops for a decision.
- **A bug a journey uncovers** is fixed on the spot, in its own commit with its
  own test, when it is small and clear; otherwise work pauses to ask.
- **Failure screenshots** need a proof of concept first (two candidate
  mechanisms), so they get their own early task.
- **Everything is deterministic:** injected session clock, fixed tokens and
  responses, no network.

## Dependency graph

```
I1 stack + navigation journey, run both ways
 ├── I2 failure screenshots (spike, then implement)
 ├── I3 send request + history journeys
 │    ├── I5 session journey
 │    └── I6 flow journey
 ├── I4 environments + production journeys
 │    └── I7 hosts & notes journey
 └── I8 persistence + keyboard journeys   (needs I3, I4, I6, I7 data to persist)
          └── I9 break-on-purpose check, docs, final runs
```
I2–I4 only need I1. I5 and I6 need the send/history helpers from I3; I7 needs
the environment helpers from I4; I8 reuses everything.

## Task List

### Phase 1: The stack
- [x] I1: Shared stack and the navigation journey, run both ways
- [x] I2: Failure screenshots

### Checkpoint: The stack
- [x] `fvm flutter test test/integration` and `fvm flutter test integration_test -d windows` both pass the navigation journey
- [x] `fvm flutter test` (no args) still passes and does not run `integration_test/`
- [x] A forced failure leaves a PNG in `build/integration_failures/`

### Phase 2: Core journeys
- [x] I3: Send a request and history journeys
- [x] I4: Environments, variables and production journeys

### Checkpoint: Core journeys
- [x] analyze clean, both runners green, 614 existing tests untouched

### Phase 3: Feature journeys
- [x] I5: Session journey
- [x] I6: Multi-step flow journey
- [ ] I7: Hosts & notes journey

### Checkpoint: Feature journeys
- [ ] analyze clean, both runners green

### Phase 4: Whole-app journeys and wrap-up
- [ ] I8: Persistence and keyboard journeys
- [ ] I9: Break-on-purpose check, docs and final runs

### Checkpoint: Done
- [ ] All SPEC-integration-tests.md success criteria checked

---

## I1: Shared stack and the navigation journey, run both ways

**Description:** Add `integration_test` to `dev_dependencies`. Create
`integration_test/support/` with a minimal `FakeBackend` (records calls,
answers 200 `{}` to anything), `seed_data.dart` (three environments `Dev`
active / `QA` / `Prod` with `base_url`, a small collection, one flow) and
`journey_harness.dart` (the `JourneyHarness` interface with `launchApp`,
`restartApp`, `newStore`, window size, plus an `AppDriver` with tap/type/read
helpers by `Key`). Write `journeys/navigation_journey.dart` and the two
runners: `test/integration/journeys_test.dart` (in-memory harness) and
`integration_test/app_test.dart` (disk harness, real binding).

**Acceptance criteria:**
- [ ] The navigation journey passes with `fvm flutter test test/integration`.
- [ ] The same journey passes with `fvm flutter test integration_test -d windows`.
- [ ] `fvm flutter test` with no arguments passes and does not try to run `integration_test/`.
- [ ] Each test builds its own store and `FakeBackend`; deleting the temp folder after the test leaves nothing behind.
- [ ] The journey checks: opens on Workspace, both header buttons present, the four destinations reachable and back, the environment pill shows the seeded environments with `Dev` active.

**Verification:**
- [ ] `fvm flutter pub get`
- [ ] `fvm flutter test test/integration`
- [ ] `fvm flutter test integration_test -d windows`
- [ ] `fvm flutter analyze`

**Dependencies:** none

**Files likely touched:** `pubspec.yaml`, `integration_test/support/*` (3),
`integration_test/journeys/navigation_journey.dart`,
`integration_test/app_test.dart`, `test/integration/journeys_test.dart`

**Estimated scope:** Large (≈8 files, mostly small); it is the foundation, so
it is allowed to be the biggest task.

## I2: Failure screenshots

**Description:** Spike which mechanism works on Windows —
`IntegrationTestWidgetsFlutterBinding.takeScreenshot`, or rendering the root
layer with `OffsetLayer.toImage` — then implement a helper that, when a journey
test fails, writes `build/integration_failures/<test name>.png`. Wire it into
the harness so every journey gets it without repeating code; do the same for
`flutter_test` if feasible and document it if not.

**Acceptance criteria:**
- [ ] A throwaway failing assertion in a journey leaves a non-empty, valid PNG in `build/integration_failures/` under `integration_test -d windows`.
- [ ] The file name is derived from the test name and is safe on Windows (no illegal characters).
- [ ] A passing run leaves no screenshot behind.
- [ ] If the `flutter_test` runner cannot capture, the limitation is written in the spec and the helper does nothing there (no error).
- [ ] The throwaway failure is removed before committing.

**Verification:**
- [ ] Force a failure, run `fvm flutter test integration_test -d windows`, open the PNG
- [ ] `fvm flutter test test/integration` and `fvm flutter analyze`

**Dependencies:** I1

**Files likely touched:** `integration_test/support/failure_screenshot.dart`,
`integration_test/support/journey_harness.dart`,
`integration_test/app_test.dart`, `SPEC-integration-tests.md`

**Estimated scope:** Small–Medium (3–4 files)

## I3: Send a request and history journeys

**Description:** Extend `FakeBackend` with scripted routes (`GET /items` 200
with a JSON list, `GET /boom` transport error, `GET /flaky` 500) and extend
`AppDriver` with `createFolder`, `addRequest`, `setUrl`, `save`, `send`,
`openHistoryTab`, `openHistoryScreen`. Journeys 2 and 3: create folder and
request, save, send, check status/time/body and `Copy` + toast; the sent
request shows in the History tab and the History screen, tapping the row
reopens it in the Workspace, a failed send appears as `Error`.

**Acceptance criteria:**
- [ ] A saved request sent to `/items` shows `200` and its body; `Copy` puts the body on the clipboard and shows `Response copied`.
- [ ] The same send appears under History in the panel and in the History screen with method, name and URL.
- [ ] Tapping the History-screen row returns to the Workspace with that request loaded.
- [ ] `/boom` and `/flaky` produce the transport-error view and a `500` badge; the first appears as `Error` in History.
- [ ] An unsaved draft sends fine but records no history.

**Verification:**
- [ ] `fvm flutter test test/integration` and `fvm flutter test integration_test -d windows`
- [ ] `fvm flutter analyze`

**Dependencies:** I1

**Files likely touched:** `integration_test/support/fake_backend.dart`,
`integration_test/support/journey_harness.dart`,
`integration_test/journeys/send_request_journey.dart`,
`integration_test/journeys/history_journey.dart`, both runners

**Estimated scope:** Medium (6 files)

## I4: Environments, variables and production journeys

**Description:** Journeys 4 and 10. A request with `{{base_url}}` goes out with
the active environment's value; switching the pill changes the URL sent; an
undefined variable is sent literally; creating an environment from the
Environments screen and typing a variable makes `{{x}}` resolve. With the
seeded `Prod` active, the red strip shows and the pill's active button is red.

**Acceptance criteria:**
- [ ] The URL the `FakeBackend` receives is the interpolated one for `Dev`, then for `QA` after switching.
- [ ] `{{missing_var}}` reaches the backend unchanged.
- [ ] A variable added in the Environments screen is used by the next send.
- [ ] Activating `Prod` shows the strip (`active-environment-strip` has height 3) and the red active pill button; activating `Dev` removes the strip.
- [ ] Switching environment never changes the saved request itself.

**Verification:**
- [ ] `fvm flutter test test/integration` and `fvm flutter test integration_test -d windows`
- [ ] `fvm flutter analyze`

**Dependencies:** I1 (uses the send helper from I3 if already available; otherwise adds the minimum itself)

**Files likely touched:** `integration_test/journeys/environments_journey.dart`,
`integration_test/journeys/production_journey.dart`,
`integration_test/support/journey_harness.dart`, both runners

**Estimated scope:** Medium (5 files)

## I5: Session journey

**Description:** Journey 5. `POST /login` returns tokens; `GET /me` answers 200
only with `Authorization: Bearer …`, otherwise 401. A login captures tokens
(session button `Expires in …`, toast `Tokens captured for Dev`), the next
request carries the header, `QA` does not, `Clear tokens` removes it, the copied
`curl` includes the header, an explicit `Authorization` header on a request is
not overridden. Uses an injected clock and a fake JWT.

**Acceptance criteria:**
- [ ] After `/login` the session button reads `Expires in 12 min` with the injected clock.
- [ ] `/me` is 200 afterwards and 401 after switching to `QA`; back on `Dev` it is 200 again.
- [ ] `Clear tokens` makes `/me` 401 again; the checkbox values are kept.
- [ ] The `curl` copied after login contains `Authorization: Bearer`.
- [ ] A request with its own `Authorization` header reaches the backend with its own value.
- [ ] No token string appears in any toast.

**Verification:**
- [ ] `fvm flutter test test/integration` and `fvm flutter test integration_test -d windows`
- [ ] `fvm flutter analyze`

**Dependencies:** I3

**Files likely touched:** `integration_test/support/fake_backend.dart`,
`integration_test/journeys/session_journey.dart`, both runners

**Estimated scope:** Small–Medium (4 files)

## I6: Multi-step flow journey

**Description:** Journey 6. Create a flow with three saved requests, run it:
all OK → `3 passed` and the total time; a step answering 500 (with an assertion
or transport error) → `1 passed`, `1 failed`, `1 skipped`; `Re-run` executes
again; a login step inside a flow leaves the session ready for the next step.

**Acceptance criteria:**
- [ ] A flow of three steps against OK routes shows `3 passed`.
- [ ] With the second step failing the strip reads `1 passed`, `1 failed`, `1 skipped` and the failed step is selected with its error detail.
- [ ] `Re-run` runs the three steps again (the backend's call log grows accordingly).
- [ ] A flow whose first step is `/login` sends the Bearer token on the second step.
- [ ] A value extracted from step 1 is used by step 2's URL (variable propagation).

**Verification:**
- [ ] `fvm flutter test test/integration` and `fvm flutter test integration_test -d windows`
- [ ] `fvm flutter analyze`

**Dependencies:** I3

**Files likely touched:** `integration_test/journeys/flow_journey.dart`,
`integration_test/support/journey_harness.dart` (flow helpers), both runners

**Estimated scope:** Medium (4 files)

## I7: Hosts & notes journey

**Description:** Journey 7. With the seeded environments (one base missing in
`QA`), open `Hosts & notes`, see the warning, type a value in the `QA` cell until
the warning disappears, write a note, add a new host, and confirm in the
Environments screen that the variable exists with the typed value.

**Acceptance criteria:**
- [ ] The warning for the base missing in `QA` is shown; after typing the `QA` URL it is gone and the all-defined line shows.
- [ ] The note typed for a base is still there after closing and reopening the dialog.
- [ ] `Add host` + a typed URL creates the variable in that environment, visible in the Environments editor.
- [ ] Clearing a cell removes the variable from that environment only.
- [ ] A secret variable with a URL value never appears in the dialog.

**Verification:**
- [ ] `fvm flutter test test/integration` and `fvm flutter test integration_test -d windows`
- [ ] `fvm flutter analyze`

**Dependencies:** I4

**Files likely touched:** `integration_test/journeys/hosts_journey.dart`,
`integration_test/support/seed_data.dart`, both runners

**Estimated scope:** Small–Medium (4 files)

## I8: Persistence and keyboard journeys

**Description:** Journeys 8 and 9. Persistence: create a folder, a request, an
environment with a variable, a flow and a host note, call `restartApp()` on the
same store, and check it all is still there; tokens are not. Keyboard:
`Ctrl+Enter` sends once, `/` focuses the search, `Esc` closes the session popover
and the hosts dialog.

**Acceptance criteria:**
- [ ] After a restart the folder, request, environment variable, flow and host note are present.
- [ ] After a restart the session button reads `No token` even though tokens were captured before.
- [ ] On the disk harness the data folder contains the expected files and no file contains a token value.
- [ ] `Ctrl+Enter` makes exactly one backend call; pressing it twice quickly while sending still yields one.
- [ ] `/` focuses the sidebar search only when no text field has focus; `Esc` closes the popover and the dialog.

**Verification:**
- [ ] `fvm flutter test test/integration` and `fvm flutter test integration_test -d windows`
- [ ] `fvm flutter analyze`

**Dependencies:** I3, I4, I6, I7

**Files likely touched:** `integration_test/journeys/persistence_journey.dart`,
`integration_test/journeys/keyboard_journey.dart`,
`integration_test/support/journey_harness.dart`, both runners

**Estimated scope:** Medium (5 files)

## I9: Break-on-purpose check, docs and final runs

**Description:** Prove the journeys fail when they should: temporarily break one
real connection per area (history not recorded, session header not attached,
host warning not shown) and confirm the matching journey goes red, then restore.
Document both commands in `README.md`, update the Testing Strategy line in
`SPEC.md` (already done in the spec phase; re-check), and run everything once.

**Acceptance criteria:**
- [ ] Each of the three deliberate breaks makes its journey fail with a clear message; all are reverted and the tree is clean.
- [ ] `README.md` has a section with both commands and what they need (a Windows device for the second).
- [ ] Final run: analyze clean, the 614 existing tests plus the new `test/integration` green, and `integration_test -d windows` green.
- [ ] Every success criterion in the spec is ticked or listed with the reason it could not be verified.

**Verification:**
- [ ] `fvm flutter analyze`
- [ ] `fvm flutter test`
- [ ] `fvm flutter test integration_test -d windows`

**Dependencies:** I2–I8

**Files likely touched:** `README.md`, `SPEC.md` (re-check),
`tasks/integration-tests/todo.md`

**Estimated scope:** Small

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| `integration_test` on Windows is slow or flaky (real window, timing) | High | Journeys use `pumpAndSettle` on real conditions, no fixed sleeps; run I1 on Windows first; keep each test short and independent |
| The shared journeys behave differently in the two runners (real vs. fake async, real disk I/O) | High | I1 proves both ways with a real journey; the harness hides storage/launch differences; real disk I/O only in the Windows harness |
| Failure screenshots may not work the same on both runners | Med | Spike first (I2); if `flutter_test` cannot do it, document it |
| A journey uncovers a real app bug | Med | Fix small, clear bugs on the spot with their own test and commit (per decision); otherwise stop and ask |
| Tests become brittle by matching text | Med | Find widgets by existing `Key`s; read text only to assert what the user sees |
| `fvm flutter test` accidentally starts `integration_test/` | Med | Keep the in-process journeys under `test/integration/`; `integration_test/` is only run when named explicitly; I1 verifies it |
| Windows toolchain is missing on another machine | Low | Documented in the README; the `flutter_test` variant needs nothing |

## Open Questions

None blocking. The screenshot mechanism is decided by the I2 spike.
