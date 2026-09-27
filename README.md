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
- Per-request **history** of past responses.

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
  drive) carries the data with it. Not versioned by git automatically; see
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

### Pre-built binaries

Every push to `master` runs the test suite and, if it's green, builds
portable Windows and macOS binaries and publishes them to a rolling
`latest` GitHub release (`.github/workflows/release.yml`). No installer —
unzip and run. macOS builds are unsigned, so macOS will warn about an
unidentified developer; right-click the app and choose Open, or run
`xattr -cr api_flow_studio.app` first.

## Documentation

- [SPEC.md](SPEC.md) — objective, tech stack, commands, project structure,
  code style, testing strategy, and the v1 success criteria.
- [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) — architecture rationale, data
  model, and what's explicitly out of scope for v1.
- [tasks/plan.md](tasks/plan.md) / [tasks/todo.md](tasks/todo.md) —
  phase-by-phase implementation plan and checklist.
