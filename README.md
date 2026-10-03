# API Flow Studio

A Postman/Insomnia-style desktop app for testing HTTP endpoints, built as a
single Flutter Desktop app — no separate backend, no Electron, no database.

Beyond a basic request/response cycle, it supports:

- **Multiple environments** (dev/qa/prod) with `{{variable}}` interpolation
  in the URL, headers, and body.
- **Collections** of saved requests, grouped into nested folders.
- **Flows** — ordered sequences of saved requests where each step can
  extract a value from its response (dot-notation, e.g.
  `response.body.data.otp`) into a variable the next step consumes, with
  per-step assertions and "stop on failure" — e.g. a registration flow:
  check if a user exists → send OTP → validate OTP → create user.
- **Paste-a-curl-command** to prefill a new request's method, URL, headers,
  and body.
- Per-request **history** of past responses (bodies kept to 100 KB, 500 entries
  per project, with a "Clear history" action).
- **Projects**: several isolated sets of environments, collections, flows,
  history and host notes (say `commodo` for work and `fin_track_pro` for
  personal), switched from the header. A project can be **exported to a file**
  and **imported** by someone else — see [Projects and workspaces](#projects-and-workspaces).

This is a personal tool built for a single developer's own use — it is not
multiuser or collaborative.

## Why a Flutter monolith instead of a web app + backend

CORS is a browser restriction (`fetch`/`XHR` from JS), not a restriction on
native HTTP clients. A Flutter Desktop binary making requests with `dio` is
native HTTP traffic — like Postman — with no CORS or header restrictions.
That means the UI, the request-execution engine, and on-disk persistence
can all live in one Dart project, with no separate frontend/backend runtime
to keep in sync.

## Tech stack

- **Flutter Desktop** `3.44.6`, pinned via [FVM](https://fvm.app/) (`.fvmrc`)
  — Windows is the primary target, macOS/Linux are enabled out of the box.
- [`dio`](https://pub.dev/packages/dio) — HTTP client (interceptors,
  timeouts, multipart, redirects).
- [`flutter_riverpod`](https://pub.dev/packages/flutter_riverpod) +
  `riverpod_annotation` — app state.
- [`freezed`](https://pub.dev/packages/freezed) + `json_serializable` —
  immutable models (`Environment`, `Group`, `Endpoint`, `Flow`, `FlowStep`,
  `HistoryEntry`) with `copyWith`/`toJson`/`fromJson`.
- **Persistence:** plain JSON on disk via `dart:io`, in an
  `api_flow_studio_data/` folder next to the executable rather than the
  OS's app-data directory — copying the build folder (e.g. to a USB
  drive) carries the data with it. Inside it, `projects.json` lists the
  projects and each one keeps its files in `projects/<id>/`. Not versioned by git automatically; see
  [SPEC.md](SPEC.md)'s Open Questions.
- `uuid` — entity ids.
- `mocktail` + `flutter_test` — engine tests, mocking the `dio` client.

## Project structure

```
lib/
  engine/                # Dart only — no package:flutter imports
    models/               # Environment, Group, Endpoint, Flow, FlowStep, HistoryEntry (freezed)
    http/request_executor.dart   # builds and runs an HTTP request resolved with dio
    variables/interpolator.dart  # replaces {{variable}} in url/headers/body
    flows/flow_runner.dart       # runs steps in order, resolves variables between steps
    flows/value_extractor.dart   # dot-notation: "response.body.data.otp" -> value
    storage/json_store.dart      # reads/writes environments/collections/flows/history to disk
    curl/curl_parser.dart        # parses a pasted curl command into an Endpoint
  ui/                     # feature-first, consumes engine/ via Riverpod providers
    environments/
    collections/
    request_builder/
    response_viewer/
    flows/
    theme/                 # ThemeData built from design/*/DESIGN.md tokens
  app.dart
  main.dart
test/
  engine/                 # unit tests, mirroring lib/engine/
design/                   # Stitch exports: screen.png + code.html + DESIGN.md tokens
SPEC.md                   # detailed spec: stack, structure, testing strategy, success criteria
PROJECT_CONTEXT.md         # design/architecture context and data model
```

Design rule: nothing under `lib/engine/` imports `package:flutter`. All
"what happens when I run this request/flow" logic is testable with plain
`flutter_test`, without rendering any UI.

## Getting started

All `flutter`/`dart` commands go through [FVM](https://fvm.app/) — never
the global `flutter` binary — so the pinned SDK version (`3.44.6`, see
`.fvmrc`) is always used.

```bash
# Install dependencies
fvm flutter pub get

# Generate freezed / json_serializable / riverpod code
fvm dart run build_runner build --delete-conflicting-outputs

# Run in development (Windows)
fvm flutter run -d windows

# Run the test suite
fvm flutter test

# Static analysis
fvm flutter analyze
```

### Integration tests

Twelve user journeys (navigation, sending, history, environments, production
safeguards, session, flows, hosts, persistence, keyboard, projects, workspace
transfer) drive the whole app
against a fake HTTP backend. The same journeys run two ways:

```bash
# Whole app inside flutter_test, data in memory, no window (fast)
fvm flutter test test/integration

# Real Windows app, data in a temporary folder (needs a Windows desktop device, ~4 min)
fvm flutter test integration_test -d windows
```

`fvm flutter test` on its own does not run `integration_test/`. A failing
journey saves a screenshot to `build/integration_failures/`. Details in
[SPEC-integration-tests.md](SPEC-integration-tests.md).

To watch a run on Windows, add `--dart-define=JOURNEY_PAUSE_MS=400` (a pause after
every step; the app then uses the real window size).

### Pre-built binaries

Every push to `master` runs the test suite and, if it's green, builds
portable Windows and macOS binaries and publishes them to a rolling
`latest` GitHub release (`.github/workflows/release.yml`); every push to master
also bumps the patch version in `pubspec.yaml` and publishes its own `vX.Y.Z`
release, which keeps the version history. No installer —
unzip and run. macOS builds are unsigned, so macOS will warn about an
unidentified developer; right-click the app and choose Open, or run
`xattr -cr api_flow_studio.app` first.

Each zip also includes `sample-endpoints.json` next to the executable —
since the app's data lives in `api_flow_studio_data/` next to whichever
executable you're running (see above), a freshly downloaded build always
starts empty. Use the **Import** button in the sidebar to load that file
(or any collections JSON exported from another machine via the **Export**
button) and get a few working example endpoints right away.

## Projects and workspaces

Each project is a fully separate set of data: nothing is shared between them.
The first time a version with projects opens an older data folder, the existing
data becomes a project called **Default**; nothing is lost.

The project button in the header (name and color) switches project and holds
**New project**, **Rename**, **Delete** (with confirmation; the last project
cannot be deleted), **Export workspace…** and **Import workspace…**.

**Export** writes one `<name>.workspace.json` with the project's environments,
collections, flows and host notes. It is meant to be handed to someone else, so
it **leaves out**: the values of secret variables (the name and the secret flag
stay, the value is empty), literal credentials typed in a request's
authentication (a bearer token or a basic password; a `{{variable}}` reference is
kept), the history, session tokens and which environment is active. Headers are
not inspected, so keep secrets in secret variables.

**Import** always creates a **new** project (`commodo`, then `commodo (2)`…); it
never overwrites or merges into an existing one. Every id is regenerated, no
environment is made active, and the app says how many secret values are left to
fill in. A file that is not a workspace, is damaged or comes from a newer version
is refused with a reason and creates nothing.

Design and acceptance criteria: [SPEC-workspaces.md](SPEC-workspaces.md).

## Documentation

- [SPEC.md](SPEC.md) — objective, tech stack, commands, project structure,
  code style, testing strategy, and the v1 success criteria.
- [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) — architecture rationale, data
  model, and what's explicitly out of scope for v1.
- [tasks/plan.md](tasks/plan.md) / [tasks/todo.md](tasks/todo.md) —
  phase-by-phase implementation plan and checklist.
