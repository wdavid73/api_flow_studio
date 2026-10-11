# API Flow Studio

A Postman/Insomnia-style desktop app for testing HTTP endpoints, built as a
single Flutter Desktop app — no separate backend, no Electron, no database.

Beyond a basic request/response cycle, it supports:

- **Multiple environments** (dev/qa/prod) with `{{variable}}` interpolation
  in the URL, headers, and body.
- **Generated values**: `{{$uuid}}`, `{{$timestamp}}` (epoch seconds),
  `{{$isoTimestamp}}`, `{{$randomInt}}`, `{{$randomString}}` and
  `{{$randomEmail}}` in the URL, query, headers, body and authentication. Each
  occurrence gets a fresh value every time the request is sent, so a flow can
  run again without clashing with data it created before. The "Request Sent"
  tab of a flow step shows the URL that was really sent; copied curl commands
  keep the token as written.
- **Collections** of saved requests, grouped into nested folders.
- **Flows** — ordered sequences of saved requests where each step can
  extract a value from its response (dot-notation, e.g.
  `response.body.data.otp`) into a variable the next step consumes, with
  per-step assertions and "stop on failure" — e.g. a registration flow:
  check if a user exists → send OTP → validate OTP → create user.
- **Assertions** on every flow step: any number of checks on the response, each a
  field, an operator and an expected value — `==`, `!=`, `contains`,
  `not contains`, `exists`, `not exists`, `matches` (regex), `>` and `<`. Fields
  are dot paths starting with `response`: `response.status`,
  `response.body.data.id`, `response.headers.content-type`, plus
  `response.elapsedMs` and `response.sizeBytes` (so `response.elapsedMs < 800`
  works). The expected value can use `{{variables}}`. All assertions of a step
  run, and the run view shows which held and which did not. A flow saved with the
  old single "assert field / expected value" pair opens as one `==` assertion.
  Workspace files are now version 2; version 1 files still import, but an older
  copy of the app will refuse (or, for `flows.json`, silently ignore) assertions
  written by this one.
- **Form Data bodies** (`multipart/form-data`): text fields and files, each row
  with its own on/off switch. Choose a file with the system dialog or type its
  path (`{{fixtures}}/avatar.png` works); its type is worked out from the
  extension unless you set one. The file is read when the request is sent, never
  stored. A missing or unchosen file fails the request with a clear message
  instead of sending anything.
- **Paste-a-curl-command** to prefill a new request's method, URL, headers,
  and body (`-d`, and `-F`/`--form`/`--form-string` for Form Data); the copied
  curl writes Form Data back as `-F`.
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
kept), **the path of every file in a Form Data body** (the field stays, as "no file
chosen"), the history, session tokens and which environment is active. Headers are
not inspected, so keep secrets in secret variables.

**Import** always creates a **new** project (`commodo`, then `commodo (2)`…); it
never overwrites or merges into an existing one. Every id is regenerated, no
environment is made active, and the app says how many values are left to fill in
(secrets, and files to choose again). File paths are **never imported**, even if
the file carries them: a Form Data body sends a local file to its URL, and a path
inside a file somebody gave you is not a file you chose to send. The same goes
for the sidebar's collections JSON import. A file that is not a workspace, is
damaged or comes from a newer version is refused with a reason and creates
nothing.

Workspace files are version 3 (Form Data bodies). Versions 1 and 2 still import.
**Older copies of the app cannot read a request with a Form Data body:** they set
the damaged `collections.json` aside as `collections.json.corrupt-<date>` and show
empty collections until you go back to this version, so don't share one data
folder between versions.

Design and acceptance criteria: [SPEC-workspaces.md](SPEC-workspaces.md).

## Running flows from the terminal

The flows of a workspace file (see [Projects and workspaces](#projects-and-workspaces))
can run without the app, which makes them usable as API smoke tests in CI. The
runner uses the same engine as the app, so `{{variables}}`, `{{$tokens}}`,
extractions and assertions behave the same.

```bash
fvm dart run bin/api_flow_runner.dart --workspace commodo.workspace.json --env qa \
  --junit report.xml
```

| Option | Meaning |
|---|---|
| `-w, --workspace <file>` | the workspace file exported by the app (required) |
| `-e, --env <name>` | environment to use; required if the file has more than one |
| `-f, --flow <name\|id>` | flow to run; repeatable; default: all, in file order |
| `--var <name=value>` | override a variable; repeatable |
| `--timeout <seconds>` | time limit per request (default 30) |
| `--fail-fast` | stop after the first flow that fails |
| `--allow-production` | required when the environment is called `prod`, `production` or `prd` |
| `--junit <file>`, `--json <file>` | write a JUnit XML or a JSON report |
| `-v, --verbose` | print each request (method and URL actually sent) |
| `--list` | list environments and flows and exit |

**Exit code:** `0` every chosen flow passed, `1` a flow failed (assertion, network
error, timeout or a missing endpoint), `2` the run could not be made (bad
arguments, unreadable or newer-version file, unknown environment or flow, missing
`--allow-production`, or a report that could not be written).

**Secrets.** An exported workspace has its secret values blanked, so give them from
outside: `--var api_key=...`, or an environment variable `AFS_VAR_api_key=...`
(the name after the prefix is the variable's exact name; `--var` wins). Prefer the
environment variable in CI, since command-line arguments show up in process lists.
A secret variable left empty produces a warning on stderr. Secret values, the values
given with `--var`/`AFS_VAR_*` and values extracted into variables whose name contains
`token`, `secret`, `password`, `key` or `auth` are replaced by `***` in the console,
the verbose lines and both reports. The one exception: a value given for a variable
the environment declares as *not* secret (say `base_url`) stays readable, unless its
name looks like a credential. That is a plain text match, not a vault:
a secret the server returns in another format may still show.

**Files in Form Data bodies.** A file path is resolved from the directory the runner
is started in, so use absolute paths or a `{{variable}}` given with `--var`
(`{{fixtures}}/avatar.png` with `--var fixtures=$PWD/fixtures`). A workspace exported
from the app has no paths: a file field with no file chosen, or a file that does not
exist, fails its step (exit code 1) without sending the request.

**Limits.** There is no saved login session as in the app: a flow that needs a token
logs in itself in its first step. Flows run one at a time. TLS certificates are always
verified. The workspace file is trusted input — it sends the requests it describes —
so only run files you trust.

Example GitHub Actions job (runs the flows of a workspace committed next to the
source):

```yaml
smoke-tests:
  runs-on: ubuntu-latest
  steps:
    - uses: actions/checkout@v4
    - uses: subosito/flutter-action@v2
      with:
        channel: stable
        cache: true
    - run: flutter pub get
    - run: dart run build_runner build --delete-conflicting-outputs
    - run: dart run bin/api_flow_runner.dart -w commodo.workspace.json -e qa --junit report.xml
      env:
        AFS_VAR_api_key: ${{ secrets.API_KEY }}
    - uses: actions/upload-artifact@v4
      if: always()
      with:
        name: smoke-report
        path: report.xml
```

## Documentation

- [SPEC.md](SPEC.md) — objective, tech stack, commands, project structure,
  code style, testing strategy, and the v1 success criteria.
- [PROJECT_CONTEXT.md](PROJECT_CONTEXT.md) — architecture rationale, data
  model, and what's explicitly out of scope for v1.
- [tasks/plan.md](tasks/plan.md) / [tasks/todo.md](tasks/todo.md) —
  phase-by-phase implementation plan and checklist.
