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
- **Terminal runner**: the flows of a workspace file run without the app
  (`bin/api_flow_runner.dart`), with JUnit and JSON reports and exit codes for CI;
  see [Running flows from the terminal](#running-flows-from-the-terminal).
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
  A workspace file written before assertions existed still imports; an older copy of
  the app will refuse (or, for `flows.json`, silently ignore) assertions written by
  this one.
- **Form Data bodies** (`multipart/form-data`): text fields and files, each row
  with its own on/off switch. Choose a file with the system dialog or type its
  path (`{{fixtures}}/avatar.png` works); its type is worked out from the
  extension unless you set one. The file is read when the request is sent, never
  stored. A missing or unchosen file fails the request with a clear message
  instead of sending anything.
- **Import** (sidebar): bring a file of requests into the active project as a **new
  folder**, with a summary of what came in and what had to be left out. Today it
  reads the collections JSON that the sidebar's own Export writes (and the bundled
  `sample-endpoints.json`), **Postman** collections (v2.0 and v2.1), Postman
  environment files and **OpenAPI** 3.0/3.1 specs in JSON or YAML; see
  [Importing](#importing).
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
- [`file_picker`](https://pub.dev/packages/file_picker) — the open dialogs of Import
  and Form Data files.
- [`yaml`](https://pub.dev/packages/yaml) — reads OpenAPI specs written in YAML.
- [`args`](https://pub.dev/packages/args) — options of the terminal runner.
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
    import/                      # Importer contract + registry; app_collections, postman/, openapi/
    workspace/                   # export/import of a whole project as one file
  cli/                    # the terminal runner (options, selection, reporters, redaction)
  ui/                     # feature-first, consumes engine/ via Riverpod providers
    environments/
    collections/
    request_builder/
    response_viewer/
    flows/
    theme/                 # ThemeData built from design/*/DESIGN.md tokens
  app.dart
  main.dart
bin/api_flow_runner.dart  # entry point of the terminal runner
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

## Importing

The **Import** button of the sidebar works out what a file is from its contents (not
its extension) and brings it in:

- **It never overwrites or merges.** Everything arrives as new folders, requests and
  environments with new ids; a top-level folder whose name is already taken becomes
  `Name (2)`, `Name (3)`…, so importing the same file twice leaves two folders. Imported
  environments get their own names and **none is made active**.
- **All or nothing.** If something fails while saving, the project is left as it was.
- **It tells you what it left out.** A clean import shows a one-line toast
  (`Imported …: 12 requests in 4 folders`); one that had to drop or change something
  opens a summary that lists each item. A request whose folder is not in the file, for
  example, is skipped and named there.
- **File paths are never imported** from a Form Data body (see below): the field arrives
  as "no file chosen", and counts in the "values to fill in".
- A file that is not a format it knows says so and lists the formats it does know; a
  **workspace** file is explained, not imported (open it with Project ▸ Import
  workspace…, which makes a whole new project); files over 32 MB are refused without
  being read. Files over 256 KB are translated on a separate isolate, so the window does
not freeze on a big spec.

### Formats

| File | What you get |
|---|---|
| Collections JSON (the sidebar's Export, `sample-endpoints.json`) | its folders and requests |
| **Postman collection** v2.0 / v2.1 | a root folder named after the collection with the same tree, in the same order; method, URL, params, headers, description, bodies (raw, urlencoded, Form Data, GraphQL) and authentication (bearer, basic, API key) inherited from folders and the collection; the collection's variables as an environment `<name> (imported)` |
| **Postman environment** or globals | one environment (secret variables stay secret) |
| **OpenAPI** 3.0 / 3.1 spec (`.json`, `.yaml`, `.yml`) | a root folder named after the API with a subfolder per tag and a request per operation, in the order of the file; the URL is `{{base_url}}/pets/{{petId}}`; query and header parameters (required ones on, optional ones off), a body example (JSON, form, Form Data, XML/text), and authentication (bearer, basic, API key) as variables; an environment `<title> (imported)` with `base_url` filled in from the first server |

Not imported, and listed in the summary when a file has them: **scripts** (pre-request
and test — nothing is ever executed), saved example responses, OAuth and the other
authentication types, binary bodies, disabled bodies, and the files of a Form Data
body. Raw bodies that are not JSON (XML, HTML, text) arrive in the JSON body editor with a
matching `Content-Type`. Postman's dynamic variables are mapped onto this app's
(`{{$guid}}` becomes `{{$uuid}}`); variable names with characters other than letters,
digits and `_` are renamed (`base-url` becomes `base_url`) everywhere in the file so they
still resolve, and the summary lists the renames. A Postman **v1** collection is refused
with a note to export it again as v2.1.

For **OpenAPI**, the examples come from the file (`example`, `examples`, `default`,
`enum`) or, failing that, from a plain sample built from the schema (read-only
properties left out, a limit on depth and size, and the recursive part of a schema that
refers to itself omitted). Credentials become **secret, empty** variables named after the
security scheme (`{{BearerAuth_token}}`), so there is something to fill in and nothing is
made up. OAuth2, OpenID Connect and mutual TLS have no equivalent here and are listed in
the summary; so are cookie parameters, webhooks and callbacks, servers beyond the first
(only `servers[0]` becomes `base_url`), and binary request bodies. Only `$ref`s inside the
file are followed: a reference to another file or a URL is never read or fetched, only
reported. A **Swagger 2.0** file is refused with a note to convert it first. A server URL
with a variable that has no default (`https://{tenant}.api.test`) becomes
`https://{{tenant}}.api.test`, with `tenant` an empty variable of the environment to fill in.

**Variables the file uses but does not define.** A value in a file can read `{{token}}`,
and when the request is sent that takes whatever variable of yours has that name. That is
often what a collection expects (Postman collections lean on a separate environment file),
but a file could also use it to send one of your secrets somewhere it chose. So the summary
names each `{{variable}}` that an import uses and does not define, once, with the request
where it first appears. Generated values (`{{$uuid}}`) are built in and are not listed. The
summary shows at most 200 items and says how many more there are.

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
- `SPEC-<module>.md` — one spec per feature, with its plan and checklist in
  `tasks/<module>/`: [generated-variables](SPEC-generated-variables.md),
  [flow-assertions](SPEC-flow-assertions.md), [flow-cli](SPEC-flow-cli.md), and the
  import family indexed by [SPEC-import-map.md](SPEC-import-map.md)
  ([multipart-body](SPEC-multipart-body.md), [import-core](SPEC-import-core.md),
  [postman-import](SPEC-postman-import.md), [openapi-import](SPEC-openapi-import.md)).
- [tasks/plan.md](tasks/plan.md) / [tasks/todo.md](tasks/todo.md) —
  phase-by-phase implementation plan and checklist.
