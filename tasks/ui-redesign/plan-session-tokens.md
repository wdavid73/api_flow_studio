# Implementation Plan: UI redesign — module `session-tokens`

Spec: [SPEC-session-tokens.md](../../SPEC-session-tokens.md). Depends on
`app-shell` and `workspace` (done). Checklist in [todo.md](todo.md). Earlier
plans: [plan.md](plan.md), [plan-app-shell.md](plan-app-shell.md),
[plan-workspace.md](plan-workspace.md),
[plan-secondary-screens.md](plan-secondary-screens.md).

## Overview

Add a per-environment, in-memory session (access + refresh token) that is
attached as `Authorization: Bearer` to requests, captured from 2xx login
responses, exposed as `{{session_*}}` variables, and shown in the header
with its expiry. The rules live in pure Dart under `lib/engine/session/`; a
decorator around the executor applies them, so Workspace sends and Flows get
the behavior without touching either's logic.

## Architecture Decisions

- **Defaults for the two open questions** (approved with "apruebo"): the
  history keeps storing response bodies as it does today (the plaintext-login
  risk is noted in the spec, not changed here), and `curl` includes the real
  `Authorization` value.
- **Engine first, one rule per task.** `Session`, JWT parsing and token
  search each get their own small, fully unit-tested task before anything
  uses them.
- **The raw executor stays overridable.** `requestExecutorProvider` keeps
  meaning "the real HTTP executor" (tests override it with mocks). A new
  `sessionExecutorProvider` wraps it; `SendNotifier` and the flow run view
  read the wrapper. Existing tests that mock the raw executor keep passing
  because, with an empty session, the wrapper passes endpoint and variables
  through unchanged.
- **Environment variables win over session variables** with the same name.
- **No persistence at all**: sessions live in a Riverpod notifier keyed by
  environment id (`''` for "no environment").
- **The decorator `implements RequestExecutor`** and takes closures
  (read/write session) so the engine stays free of Riverpod and Flutter.

## Dependency graph

```
K1 Session + applySession + sessionVariables
K2 JWT claims
K3 token finder
 └── K4 SessionRequestExecutor            (needs K1, K3)
      └── K5 per-environment sessions wired into send and flows  (also K2 for later UI)
           ├── K6 header session button + popover shell
           │    └── K7 popover contents
           ├── K8 capture toast
           └── K9 effective variables for curl and URL highlighting
                └── K10 sweep + visual check
```
K1, K2 and K3 are independent. K6–K9 only need K5; K7 also uses K2.

## Task List

### Phase 1: Engine rules
- [ ] K1: `Session`, `applySession` and `sessionVariables`
- [ ] K2: JWT claims and expiry
- [ ] K3: Token finder

### Checkpoint: Engine rules
- [ ] analyze clean, full suite green
- [ ] `grep -r "package:flutter" lib/engine` is empty

### Phase 2: Behavior
- [ ] K4: `SessionRequestExecutor`
- [ ] K5: Per-environment sessions wired into send and flows

### Checkpoint: Behavior
- [ ] Sending a login stores tokens for the active environment; the next send carries them; another environment does not
- [ ] analyze clean, full suite green

### Phase 3: UI
- [ ] K6: Header session button and popover shell
- [ ] K7: Popover contents
- [ ] K8: Capture toast
- [ ] K9: Effective variables for curl and URL highlighting

### Checkpoint: UI
- [ ] analyze clean, full suite green

### Phase 4: Verify
- [ ] K10: Sweep and visual check

### Checkpoint: Module done
- [ ] All SPEC-session-tokens.md success criteria checked
- [ ] Human review, then write `SPEC-hosts-notes.md`

---

## K1: `Session`, `applySession` and `sessionVariables`

**Description:** `lib/engine/session/session.dart` with the immutable
`Session` (`accessToken`, `refreshToken`, `attachAuth = true`,
`captureTokens = true`, `copyWith`, `hasToken`), `sessionVariables(Session)`
(`session_access_token` / `session_refresh_token`, non-empty only) and
`session_apply.dart` with `applySession(Endpoint, Session)`.

**Acceptance criteria:**
- [ ] Attaches `Authorization: Bearer <token>` when `attachAuth` and a token exist.
- [ ] Does not attach with `attachAuth` off, an empty token, a non-`none` `AuthConfig`, or an `Authorization` header in any capitalization.
- [ ] Returns the same instance when nothing changes.
- [ ] `sessionVariables` omits empty tokens.

**Verification:**
- [ ] `fvm flutter test test/engine/session`
- [ ] `fvm flutter analyze`

**Dependencies:** none

**Files likely touched:** `lib/engine/session/session.dart`,
`lib/engine/session/session_apply.dart`,
`test/engine/session/session_test.dart`,
`test/engine/session/session_apply_test.dart`

**Estimated scope:** Small (4 files)

## K2: JWT claims and expiry

**Description:** `lib/engine/session/jwt_claims.dart`:
`JwtClaims.tryParse(String token)` decodes the base64url payload (padding
optional) and exposes `subject`, `expiresAt`; `expiresIn(DateTime now)`
returns the remaining `Duration` (negative when expired, null without `exp`).
Non-JWT input returns null instead of throwing.

**Acceptance criteria:**
- [ ] A valid JWT yields `sub` and `exp`; padding-less base64url decodes.
- [ ] `abc`, an empty string, a 2-part token and bad base64/JSON return null.
- [ ] `expiresIn` is negative for a past `exp`, positive for a future one, null without `exp`.

**Verification:**
- [ ] `fvm flutter test test/engine/session/jwt_claims_test.dart`
- [ ] `fvm flutter analyze`

**Dependencies:** none

**Files likely touched:** `lib/engine/session/jwt_claims.dart`,
`test/engine/session/jwt_claims_test.dart`

**Estimated scope:** Small (2 files)

## K3: Token finder

**Description:** `lib/engine/session/token_finder.dart`:
`findTokens(Object? json)` searches breadth-first, at most 300 nodes, for the
first string under `accessToken`/`access_token` and `refreshToken`/
`refresh_token`; returns `({String? accessToken, String? refreshToken})`.

**Acceptance criteria:**
- [ ] Finds tokens at the root and nested (`{"data":{"accessToken":"…"}}`), camelCase and snake_case.
- [ ] Returns only the one present; `null`s when none; ignores non-string values.
- [ ] Stops after 300 nodes (a deep/wide tree does not hang).
- [ ] Prefers the shallowest match.

**Verification:**
- [ ] `fvm flutter test test/engine/session/token_finder_test.dart`
- [ ] `fvm flutter analyze`

**Dependencies:** none

**Files likely touched:** `lib/engine/session/token_finder.dart`,
`test/engine/session/token_finder_test.dart`

**Estimated scope:** Small (2 files)

## K4: `SessionRequestExecutor`

**Description:** `lib/engine/session/session_request_executor.dart`:
`SessionRequestExecutor implements RequestExecutor`, built from an inner
executor plus `Session Function() readSession` and
`void Function(Session) writeSession`. `execute` applies the session
(`applySession`, session variables with environment variables winning),
calls the inner executor, then — for a 2xx response with a JSON body and
`captureTokens` on — writes the found tokens back.

**Acceptance criteria:**
- [ ] The inner executor receives the endpoint with the Bearer header and the merged variables.
- [ ] A 2xx JSON response with tokens updates the session via `writeSession`; only found tokens change.
- [ ] No capture on 4xx/5xx, transport errors, non-JSON bodies, or with `captureTokens` off.
- [ ] With an empty session the inner executor gets the original endpoint and variables untouched.
- [ ] A JSON body given as a `Map` (already decoded) or as a `String` are both handled.

**Verification:**
- [ ] `fvm flutter test test/engine/session`
- [ ] `fvm flutter analyze`

**Dependencies:** K1, K3

**Files likely touched:** `lib/engine/session/session_request_executor.dart`,
`test/engine/session/session_request_executor_test.dart`

**Estimated scope:** Small (2 files)

## K5: Per-environment sessions wired into send and flows

**Description:** `lib/ui/session/session_provider.dart`: a notifier holding
`Map<String, Session>` keyed by active environment id (`''` for none),
`activeSessionProvider`, and `sessionExecutorProvider` (the decorator over
`requestExecutorProvider`, bound to the active environment). `SendNotifier`
and `FlowRunViewScreen` use `sessionExecutorProvider`.

**Acceptance criteria:**
- [ ] After sending a mocked login (200 with tokens) in environment A, A's session has the tokens and B's is empty.
- [ ] The next send in A carries `Authorization`; in B it does not.
- [ ] A flow step sent through the run view also gets the Bearer token, and a login step captures tokens.
- [ ] Existing tests that override `requestExecutorProvider` still pass unchanged.
- [ ] Nothing is written to the store: `JsonStore` files are identical before and after.

**Verification:**
- [ ] `fvm flutter test test/ui/session test/ui/request_builder test/ui/flows`
- [ ] `fvm flutter analyze`

**Dependencies:** K4

**Files likely touched:** `lib/ui/session/session_provider.dart`,
`lib/ui/request_builder/send_provider.dart`,
`lib/ui/flows/flow_run_view_screen.dart`,
`test/ui/session/session_provider_test.dart`,
`test/ui/session/session_integration_test.dart`

**Estimated scope:** Medium (5 files)

## K6: Header session button and popover shell

**Description:** `SessionButton` in the header actions (AppShell passes it):
two-line button — top `Expires in N min` / `Token expired` / `Token saved` /
`No token`, bottom `Authorization: Bearer` or `kept in memory only`;
`tertiary` when valid, `warning` when expired, `onSurface` without a token.
Tapping toggles a popover (420px, `surfaceContainerLow`, 16 radius, titled
`Session · <env>`), closed with `Esc` or an outside click.

**Acceptance criteria:**
- [ ] The four label/color states render from a given session and clock.
- [ ] The button sits in the `AppHeader` actions zone.
- [ ] Tapping opens and closes the popover; `Esc` and outside click close it.
- [ ] The popover title shows the active environment name or `No environment`.

**Verification:**
- [ ] `fvm flutter test test/ui/session test/ui/app_shell_test.dart`
- [ ] `fvm flutter analyze`

**Dependencies:** K2, K5

**Files likely touched:** `lib/ui/session/session_button.dart`,
`lib/ui/session/session_popover.dart`, `lib/app.dart`,
`test/ui/session/session_button_test.dart`

**Estimated scope:** Medium (4 files)

## K7: Popover contents

**Description:** Inside the popover: `Access token` and `Refresh token`
fields (obscured by default), `Show`, `Send Authorization` and
`Capture tokens from 2xx` checkboxes, the metadata line (`sub … · Expires in
12 min`, or `Doesn't look like a JWT. It is still sent as a Bearer.`), and
`Clear tokens` (empties both tokens, keeps the checkboxes).

**Acceptance criteria:**
- [ ] Typing in a field updates the active environment's session.
- [ ] `Show` toggles obscuring of both fields.
- [ ] The two checkboxes drive `attachAuth` / `captureTokens` (default checked).
- [ ] Metadata line shows sub + expiry for a JWT, the hint for a non-JWT, nothing without a token.
- [ ] `Clear tokens` empties the tokens and keeps the checkbox values.
- [ ] Switching the active environment shows that environment's tokens.

**Verification:**
- [ ] `fvm flutter test test/ui/session`
- [ ] `fvm flutter analyze`

**Dependencies:** K6

**Files likely touched:** `lib/ui/session/session_popover.dart`,
`test/ui/session/session_popover_test.dart`

**Estimated scope:** Small (2 files)

## K8: Capture toast

**Description:** When a response updates the session, show the toast
`Tokens captured for <environment>` (`No environment` when none).

**Acceptance criteria:**
- [ ] A capturing send raises the toast with the environment name; a non-capturing send does not.
- [ ] The toast text never contains a token value.

**Verification:**
- [ ] `fvm flutter test test/ui/session`
- [ ] `fvm flutter analyze`

**Dependencies:** K5

**Files likely touched:** `lib/ui/session/session_provider.dart`,
`test/ui/session/session_toast_test.dart`

**Estimated scope:** Small (2 files)

## K9: Effective variables for curl and URL highlighting

**Description:** `effectiveVariablesProvider` merges the active environment's
variables with `sessionVariables` (environment wins). The `curl` button uses
it and `applySession`, so the copied command matches what is sent; the URL
field highlights `{{session_access_token}}` as resolved when a token exists.

**Acceptance criteria:**
- [ ] `curl` output contains the Bearer header when a token is set, and not otherwise.
- [ ] `{{session_access_token}}` in a URL is resolved in `curl` and highlighted as resolved with a token, unresolved without.
- [ ] An environment variable with the same name wins.

**Verification:**
- [ ] `fvm flutter test test/ui/session test/ui/response_viewer test/ui/request_builder`
- [ ] `fvm flutter analyze`

**Dependencies:** K5

**Files likely touched:** `lib/ui/session/session_provider.dart`,
`lib/ui/response_viewer/response_panel.dart`,
`lib/ui/request_builder/url_field.dart`,
`test/ui/session/effective_variables_test.dart`

**Estimated scope:** Medium (4 files)

## K10: Sweep and visual check

**Description:** Confirm no token is ever logged or put in an error/toast,
nothing is persisted, run the full suite, and check the button and popover in
the web preview with a sample JWT.

**Acceptance criteria:**
- [ ] A search shows no `print`/`debugPrint`/`log` of session values and no session code in `lib/engine/storage`.
- [ ] `api_flow_studio_data` unchanged after a login-and-send run (web uses the in-memory store; verified by the K5 storage test).
- [ ] Button and popover checked at ≥1100px with a sample JWT (valid, expired) and with no token.
- [ ] Every spec success criterion ticked or listed with the reason it could not be verified.

**Verification:**
- [ ] `fvm flutter analyze` and `fvm flutter test`
- [ ] Web preview

**Dependencies:** K6–K9

**Files likely touched:** none expected beyond fixes found

**Estimated scope:** Small

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| Tests assert the exact `variables` map passed to the executor | Med | With an empty session the wrapper passes the original map; K5 re-runs the existing suites |
| Decorator and raw executor confusion (tests override the wrong provider) | Med | Keep `requestExecutorProvider` = raw; document in the provider comment; K5 test covers both |
| Popover anchoring/outside-click is fiddly in Flutter desktop | Med | Use an `OverlayPortal`/`Overlay` with a full-screen barrier; test open/close/Esc in K6 before adding content |
| Token ends up in logs, toasts or error text | High | Boundaries + K8 assertion + K10 search; tokens only rendered in the popover field and in a user-copied `curl` |
| Session attached to a flow step that already sets its own auth | Low | `applySession` never overrides explicit auth (K1 test) |
| History keeps login response bodies on disk | Med (existing) | Out of scope by decision; noted in the spec |

## Open Questions

None blocking. Both defaults (history unchanged, real token in `curl`) are
chosen; say so if you want either changed.
