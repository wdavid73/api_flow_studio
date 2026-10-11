# Todo: flow-cli

Plan: [plan.md](plan.md) · Spec: [SPEC-flow-cli.md](../../SPEC-flow-cli.md)

- [x] **C1: `isProductionEnvironment` al engine y `args` declarada**
  - Acceptance: la función vive en `lib/engine/models/environment_kind.dart` con tests; la UI la reexporta sin cambiar llamadores; `args: ^2.7.0` en `pubspec.yaml`
  - Verify: `fvm flutter pub get && fvm flutter test test/engine test/ui/shell test/ui/environments`
  - Files: `lib/engine/models/environment_kind.dart`, `lib/ui/shell/environment_kind.dart`, `pubspec.yaml`, `pubspec.lock`, `test/engine/models/environment_kind_test.dart`

- [x] **C2: parseo de argumentos**
  - Acceptance: todas las opciones; `--flow`/`--var` repetibles; `--timeout` > 0 (30 por defecto); errores de uso claros; `--help`/`--list`
  - Verify: `fvm flutter test test/cli/cli_options_test.dart`
  - Files: `lib/cli/cli_options.dart`, `test/cli/cli_options_test.dart`

- [x] **C3: selección de ambiente y flujos, variables**
  - Acceptance: ambiente único/por nombre/errores; flujos por nombre o id, ambiguo y vacío; guard de producción; precedencia ambiente < `AFS_VAR_*` < `--var`; lista de secretas vacías
  - Verify: `fvm flutter test test/cli/selection_test.dart`
  - Files: `lib/cli/selection.dart`, `test/cli/selection_test.dart`

- [x] **C4: redactor y datos del reporte**
  - Acceptance: redacta secretas, overrides y extraídos por nombre (≥ 4 caracteres, incremental); tipo de fallo derivado de la estructura
  - Verify: `fvm flutter test test/cli/redactor_test.dart test/cli/run_report_test.dart`
  - Files: `lib/cli/redactor.dart`, `lib/cli/run_report.dart`, tests correspondientes

- [x] **C5: reporters (consola, JUnit, JSON)**
  - Acceptance: formatos de la spec; escape XML; `failure`/`error`/`skipped`; JSON con su esquema; redacción aplicada
  - Verify: `fvm flutter test test/cli/reporters`
  - Files: `lib/cli/reporters/console_reporter.dart`, `junit_reporter.dart`, `json_reporter.dart`, `test/cli/reporters/`

- [x] **C6: `runCli` y `bin/`**
  - Acceptance: 0/1/2 según la spec con un ejecutor falso; `--list`, `--help`, `--fail-fast`, `--verbose`; reporte no escribible → 2; sin secretos en ninguna salida
  - Verify: `fvm flutter test test/cli && fvm dart run bin/api_flow_runner.dart --help`
  - Files: `lib/cli/run_cli.dart`, `bin/api_flow_runner.dart`, `test/cli/run_cli_test.dart`

- [x] **Checkpoint 1:** `fvm flutter analyze` sin avisos y `fvm flutter test` completo en verde

- [ ] **C7: de punta a punta contra un servidor local**
  - Acceptance: dos pasos con extracción y assertions → 0 y JUnit correcto; assertion fallida → 1; timeout corta un paso lento; `{{$token}}` se genera en el request real
  - Verify: `fvm flutter test test/cli/end_to_end_test.dart`
  - Files: `test/cli/end_to_end_test.dart`

- [ ] **C8: README y ejemplo de CI**
  - Acceptance: sección con opciones, códigos de salida, secretos, límites y un workflow de ejemplo que solo usa opciones existentes
  - Verify: `fvm flutter analyze && fvm flutter test`
  - Files: `README.md`, `SPEC-flow-cli.md` (criterios)

- [ ] **Checkpoint final:** `analyze` + suite completa en verde; revisión humana
