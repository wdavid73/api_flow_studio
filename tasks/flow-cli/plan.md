# Plan: flow-cli

Spec: [SPEC-flow-cli.md](../../SPEC-flow-cli.md). Plan separado de `tasks/plan.md` (v1),
`tasks/workspaces/`, `tasks/integration-tests/`, `tasks/generated-variables/` y
`tasks/flow-assertions/`.

## Overview

Ocho tareas, cada una un corte vertical con su test y su commit. Mientras no llega C6
nada es alcanzable desde la línea de comandos, pero cada pieza (argumentos, selección,
redactor, reportes) queda probada por separado y la suite existente sigue verde en
cada tarea. Se aplican las respuestas por defecto de la spec: se declara `args`, no hay
modo "datos locales de la app", los ejecutables en el release quedan para después y la
heurística de nombres sensibles se mantiene.

## Hallazgos del código que condicionan el plan

- **`engine/` no importa Flutter** (comprobado con grep) y un script en `bin/` que lo
  importa corre con `fvm dart run` y compila con `dart compile exe` (comprobado). Nada
  de eso hay que arreglar.
- **`isProductionEnvironment` está en `lib/ui/shell/environment_kind.dart`**, que importa
  `package:flutter/painting.dart`; el CLI no puede importarlo. Hay 8 usos fuera de ese
  archivo → se mueve la función al engine y el archivo de UI la reexporta (C1), sin tocar
  a los llamadores.
- **`args` es transitiva** en `pubspec.lock` (2.7.0); declararla en `pubspec.yaml` no
  cambia ninguna versión instalada.
- **`FlowRunner.run` ya da lo necesario:** `onStepResult(index, result)` para el progreso,
  `FlowStepResult.extractedVariables`, `assertionResults` y `response.error`/`requestUrl`.
  El tipo de fallo se deriva de esa estructura, no del texto (a diferencia de
  `classifyFailure` en la UI, que depende del prefijo del mensaje).
- **`RequestExecutor` acepta un `Dio`**, así que el timeout del CLI se aplica creando un
  `Dio(BaseOptions(...))` en `run_cli`; no hay cambios en el engine.
- **Redacción en streaming:** la consola imprime cada paso al terminar, pero los valores
  extraídos (un token) solo se conocen al terminar ese paso. El redactor debe poder
  "aprender" los valores extraídos de un paso **antes** de imprimir ese paso; los
  reportes JUnit/JSON, que se generan al final, usan todo lo aprendido.
- **El lint `avoid_print` está activo:** la salida va a `StringSink`s inyectados; `print` y
  `exit` solo en `bin/`.
- **No usar `dart format`** en archivos existentes (el repo no usa el estilo nuevo).

## Dependency graph

```
C1 isProductionEnvironment al engine + declarar args ─┐
C2 argumentos ────────────────────────────────────────┼─ C3 selección y variables ─┐
C4 redactor + datos del reporte ── C5 reporters ──────┘                            ├─ C6 run_cli + bin ── C7 punta a punta ── C8 README
                                                                                   ┘
```

## Tareas

Cada tarea sigue TDD (test rojo primero) y termina con `fvm flutter analyze` y la suite
relevante en verde.

### C1 — `isProductionEnvironment` al engine y `args` declarada
Mover la función a `lib/engine/models/environment_kind.dart`; `lib/ui/shell/environment_kind.dart`
la reexporta (conserva `environmentDotColorFor`). Añadir `args: ^2.7.0` a `pubspec.yaml`.
**Aceptación:** test de engine para `prod`/`production`/`prd`, espacios y mayúsculas; los
tests y llamadores existentes de la UI no cambian; `pubspec.lock` solo cambia la
clasificación de `args` a "direct".
**Verify:** `fvm flutter pub get && fvm flutter test test/engine test/ui/shell test/ui/environments`

### C2 — Parseo de argumentos
`lib/cli/cli_options.dart`: `parseCliArgs(List<String>) → CliOptions | CliUsageError`, con
`usageText`. **Aceptación:** todas las opciones del spec; `--flow` y `--var` repetibles;
`--timeout` numérico > 0 (por defecto 30); `--var` sin `=` o con nombre vacío → error;
`--workspace` obligatorio salvo con `--help`; opción desconocida y valor faltante → error
con mensaje claro; `--help` y `--list` reconocidos.
**Verify:** `fvm flutter test test/cli/cli_options_test.dart`

### C3 — Selección de ambiente y flujos, variables
`lib/cli/selection.dart`: sobre un `WorkspaceFile` y `CliOptions`, elige ambiente (único,
por nombre, errores listando nombres), elige flujos (nombre/id, ambiguo, vacío), aplica el
guard de producción y mezcla variables (ambiente < `AFS_VAR_*` < `--var`), devolviendo
también la lista de secretas sin valor para el aviso. **Aceptación:** todos los casos de
la sección "Selección" y "Variables" de la spec; los errores son valores (no excepciones)
con el mensaje que verá el usuario.
**Verify:** `fvm flutter test test/cli/selection_test.dart`

### C4 — Redactor y datos del reporte
`lib/cli/redactor.dart` (valores secretos del ambiente, overrides, extraídos por nombre
sensible; mínimo 4 caracteres; `learn(extracted)` incremental) y `lib/cli/run_report.dart`
(`FlowReport`/`StepReport` y su construcción desde `FlowStepResult`, con el tipo de fallo:
assertion / network / configuration / skipped). **Aceptación:** valores cortos no se
enmascaran; el mismo valor dentro de una URL o de un mensaje se redacta; los valores
aprendidos solo afectan a lo que se escriba después; clasificación derivada de la
estructura (un fallo con mensaje "Assertion failed" pero sin `assertionResults` fallidas
**no** cuenta como assertion).
**Verify:** `fvm flutter test test/cli/redactor_test.dart test/cli/run_report_test.dart`

### C5 — Reporters (consola, JUnit, JSON)
Tres archivos en `lib/cli/reporters/`, funciones puras de datos del reporte a texto.
**Aceptación:** consola con el formato de la spec (`[PASS]/[FAIL]/[SKIP]`, líneas de
mensaje bajo el paso, resumen); JUnit con escape de `& < > " '`, tipos
`failure`/`error`/`skipped`, `testsuite` por flujo y totales; JSON con el esquema de la
spec y `failures`/`actual`/`message` solo en pasos fallidos; el redactor se aplica a todo el
texto antes de escribirlo.
**Verify:** `fvm flutter test test/cli/reporters`

### C6 — `runCli` y `bin/`
`lib/cli/run_cli.dart` + `bin/api_flow_runner.dart`: lee el archivo, `WorkspaceFile.parse`
(errores → 2), `--help`, `--list`, selección, `FlowRunner` con `RequestExecutor` (o el
inyectado), progreso por paso, `--fail-fast`, `--verbose`, escritura de reportes (error al
escribir → 2 tras correr), avisos a `err`, código de salida. **Aceptación:** con un
`RequestExecutor` falso (mocktail): todo pasa → 0; una assertion falla → 1 y los siguientes
`[SKIP]`; error de red → 1; `--fail-fast` no corre el segundo flujo; producción sin
`--allow-production` → 2 sin ningún request; reporte no escribible → 2; ningún secreto en
`out`, `err` ni en los archivos.
**Verify:** `fvm flutter test test/cli && fvm dart run bin/api_flow_runner.dart --help`
**Checkpoint tras C6:** `fvm flutter analyze` y `fvm flutter test` completos en verde.

### C7 — De punta a punta contra un servidor local
`test/cli/end_to_end_test.dart`: `HttpServer` en `localhost` con rutas guiadas y dio real.
**Aceptación:** un flujo de dos pasos con extracción entre ellos y assertions → `0` y JUnit
correcto; un flujo con assertion fallida → `1`; una ruta lenta con `--timeout 1` se marca
como fallo de red en menos de ~3 s sin colgar; `{{$token}}` se genera en el request real.
**Verify:** `fvm flutter test test/cli/end_to_end_test.dart`

### C8 — README y ejemplo de CI
Sección "Running flows from the terminal": instalación vía `dart run`, opciones, códigos de
salida, secretos con `AFS_VAR_*`, límites (sin sesión, redacción por coincidencia de texto,
archivo de confianza) y un workflow de GitHub Actions de ejemplo. Marcar los criterios de
éxito de la spec. **Aceptación:** el ejemplo usa solo opciones que existen (revisado contra
`--help`). **Verify:** `fvm flutter analyze && fvm flutter test`

## Riesgos

| Riesgo | Mitigación |
|---|---|
| `flutter test` bloquea HTTP real si hay un binding inicializado | C7 usa `test()` (sin binding), no `testWidgets`; si falla, se abre el socket con `HttpOverrides.runZoned(createHttpClient: null)` |
| El `HttpServer` de pruebas deja el puerto abierto y cuelga la suite | `tearDown` cierra con `force: true`; puerto 0 (efímero) |
| Un secreto aparece en un mensaje de `DioException` | El redactor se aplica a todo texto de salida, incluido `response.error`; prueba con el valor secreto dentro de una URL de error |
| `exit()` antes de vaciar stdout trunca la salida en CI | `bin/` hace `await stdout.flush()` y `await stderr.flush()` antes de `exit` |
| Mover `isProductionEnvironment` rompe imports de la UI | La UI reexporta desde el mismo archivo; los tests existentes de `shell` y `environments` son el seguro |
| Rutas de reporte relativas en Windows | Se resuelven con `File(path)` tal cual; sin manipular separadores a mano |

## Fuera del plan (seguimiento)

- Ejecutables compilados en el release de GitHub (Windows/macOS/Linux) para usar el runner
  sin instalar Flutter — toca `release.yml`; requiere tu visto bueno.
- Correr contra los datos locales de la app (`--project`).
- `--insecure`, reintentos, paralelismo, `--redact <nombre>`.
