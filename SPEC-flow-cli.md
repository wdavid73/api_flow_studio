# Spec: flow-cli

Ejecutar los flujos de un workspace desde la terminal, sin abrir la app, para
usarlos como pruebas de humo de una API en CI. Es una sola capacidad (leer un
workspace → correr flujos → informar y devolver un código de salida), así que no
necesita mapa de módulos; los reportes (JUnit/JSON) son parte de ella.

## Objective

Hoy un flujo solo se puede correr desde la ventana de la app. Con
[`flow-assertions`](SPEC-flow-assertions.md) los flujos ya funcionan como tests de
API; falta poder lanzarlos en un pipeline y que **el pipeline falle cuando un flujo
falla**.

**Usuario:** el desarrollador dueño de la app, en su terminal y en GitHub Actions.

**Éxito:** con un archivo `*.workspace.json` exportado desde la app y un comando

```bash
dart run bin/api_flow_runner.dart --workspace commodo.workspace.json --env qa \
  --var api_key="$API_KEY" --junit report.xml
```

se corren los flujos contra el ambiente `qa`, se ve en consola qué paso pasó y cuál
falló (con el porqué), se escribe `report.xml` para que el CI lo muestre, y el
proceso termina con `0` si todo pasó y `1` si algo falló. Ningún valor secreto
aparece en la salida.

## ASSUMPTIONS (corregir ahora o procedo con estas)

1. **La entrada es un archivo workspace** (el mismo que exporta/importa la app),
   no la carpeta de datos local. Es portable, se versiona en el repo y no arrastra
   historial ni tokens. Correr contra los datos locales de la app queda fuera de v1
   (ver Open Questions).
2. **Mismo motor que la app:** `FlowRunner` + `RequestExecutor`, así que
   `{{variables}}`, `{{$tokens}}`, extracciones y assertions se comportan igual. Sin
   cambios de comportamiento en `engine/`.
3. **Sin sesión:** no hay login guardado como en la app (`SessionRequestExecutor`).
   Un flujo que dependa de `session_*` debe hacer su propio login como primer paso.
4. **Los flujos se corren en orden y de uno en uno**, cada uno con su propio pool de
   variables partiendo del ambiente, igual que "Run Flow" en la app. Sin paralelismo.
5. **Los secretos llegan por fuera del archivo** (el export los deja vacíos): con
   `--var nombre=valor` o con variables de entorno `AFS_VAR_<nombre>`.
6. **Cero dependencias nuevas de código:** se propone declarar `args` en el
   `pubspec.yaml`; ya está resuelta en `pubspec.lock` como transitiva (`2.7.0`), así que
   no cambia ningún paquete instalado.
7. Funciona con `dart run` (probado: un script en `bin/` que importa `engine/` corre
   con `fvm dart run`) y con `dart compile exe` (probado: ~5.7 MB). Publicar
   ejecutables en el release queda fuera de v1.

## Interfaz

```
api_flow_runner --workspace <archivo> [opciones]

  -w, --workspace <archivo>   (obligatorio) workspace exportado por la app
  -e, --env <nombre>          ambiente a usar; obligatorio si el archivo tiene más de uno
  -f, --flow <nombre|id>      flujo a correr; repetible; por defecto, todos
      --var <nombre=valor>    sobrescribe una variable; repetible
      --timeout <segundos>    tiempo máximo por request (por defecto 30)
      --fail-fast             detener después del primer flujo que falle
      --allow-production      necesario si el ambiente se llama prod, production o prd
      --junit <archivo>       escribe un reporte JUnit XML
      --json <archivo>        escribe un reporte JSON
  -v, --verbose               imprime cada request (método y URL)
      --list                  lista ambientes y flujos y termina sin correr nada
  -h, --help
```

### Códigos de salida

| Código | Significa |
|---|---|
| `0` | todos los flujos elegidos pasaron |
| `1` | al menos un flujo falló (assertion, error de red/timeout o endpoint ausente) |
| `2` | no se pudo correr: argumentos inválidos, archivo ilegible o de versión nueva, ambiente o flujo inexistente/ambiguo, falta `--allow-production`, o no se pudo escribir un reporte |

Un error de uso imprime el motivo y `--help` abreviado en `stderr`; nunca un stack trace.

## Comportamiento

### Selección
- **Ambiente:** coincidencia exacta por nombre sin distinguir mayúsculas. Si el
  archivo tiene exactamente uno, se usa sin `--env`; con ninguno se corre solo con
  las variables dadas; con varios y sin `--env` → código 2 listando los nombres.
- **Flujos:** `--flow` por nombre (exacto, sin distinguir mayúsculas) o por id. Un
  nombre que coincide con dos flujos → código 2 pidiendo el id. Sin `--flow` se corren
  todos, en el orden del archivo. Un workspace sin flujos → código 2 ("nothing to run").
- **Producción:** si `isProductionEnvironment(nombre)` y no hay `--allow-production`
  → código 2 antes de enviar ningún request.

### Variables
Orden de prioridad (la última gana): variables del ambiente → `AFS_VAR_<nombre>` →
`--var`. El nombre en `AFS_VAR_<nombre>` es exactamente el de la variable (distingue
mayúsculas). Una variable secreta que queda vacía y no fue dada produce un aviso en
`stderr` con su nombre (`warning: secret variable "api_key" has no value`); no cambia
el código de salida.

### Requests
- Mismo `RequestExecutor` que la app, con un `Dio` configurado con el `--timeout`
  (conexión, envío y recepción). Un timeout es un fallo de paso ("network error"); no
  se reintenta.
- Verificación TLS siempre activa; sin `--insecure` en v1.

### Salida de consola
Progreso a medida que termina cada paso, ASCII, sin colores:

```
Flow: Signup (3 steps)
  [PASS] 1. Log in            200    120 ms
  [FAIL] 2. Create item       404     45 ms
         Assertion failed: expected response.status == "201", got "404"
  [SKIP] 3. List items
Flow: Smoke (1 step)
  [PASS] 1. Health            200     30 ms

2 flows: 1 passed, 1 failed - 4 steps: 2 passed, 1 failed, 1 skipped - 1.4 s
```

`--verbose` añade bajo cada paso `GET https://…` (la URL realmente enviada,
`ExecutedResponse.requestUrl`). Los avisos van a `stderr`, el resto a `stdout`.

### Reporte JUnit (`--junit`)
Un `<testsuite>` por flujo y un `<testcase>` por paso (`classname` = nombre del
flujo, `name` = `"<n>. <endpoint>"`, `time` en segundos):
- assertion fallida → `<failure message="primer mensaje" type="AssertionFailure">todos los mensajes</failure>`
- error de red, timeout o endpoint ausente → `<error message="…" type="NetworkError|ConfigurationError">`
- paso saltado → `<skipped/>`

Con texto XML escapado y los totales (`tests`, `failures`, `errors`, `skipped`, `time`)
en `testsuite` y en el `testsuites` raíz.

### Reporte JSON (`--json`)
```json
{
  "workspace": "commodo", "environment": "qa",
  "startedAt": "2026-10-11T14:03:22.000Z", "durationMs": 1400,
  "summary": {"flows": 2, "flowsFailed": 1, "steps": 4, "stepsFailed": 1, "stepsSkipped": 1},
  "flows": [{
    "id": "f-signup", "name": "Signup", "status": "failed", "durationMs": 900,
    "steps": [{
      "index": 1, "endpoint": "Log in", "method": "POST", "status": "passed",
      "httpStatus": 200, "elapsedMs": 120,
      "assertions": [{"check": "response.status == \"200\"", "passed": true}]
    }]
  }]
}
```
Un paso fallido añade `"failures": ["…"]` y, por assertion fallida, `"actual"` y `"message"`.

### Qué es un fallo (y de qué tipo)
Se deriva de la estructura de `FlowStepResult`, no del texto del mensaje: alguna
`assertionResults` con `passed == false` → **assertion**; `response.error != null` →
**network**; cualquier otro fallo (endpoint ausente) → **configuration**.

### Datos sensibles
- **Se redactan como `***`** en consola, `--verbose`, JUnit y JSON: el valor de toda
  variable secreta del ambiente, todo valor dado por `--var`/`AFS_VAR_*`, y los valores
  extraídos en variables cuyo nombre contenga `token`, `secret`, `password`, `key` o `auth`
  (sin distinguir mayúsculas). Solo valores de 4 caracteres o más, para no enmascarar `1`.
- La redacción es por coincidencia de texto, no es un vault: un secreto que el servidor
  devuelva con otro formato podría verse. Límite conocido y documentado.
- Los valores de `--var` quedan visibles en la lista de procesos; se documenta preferir
  `AFS_VAR_*` en CI.
- El archivo workspace es entrada **de confianza** (corre los requests que describe, a las
  URLs que describe): no se ejecutan archivos de origen desconocido. Se documenta.

## Tech Stack
Dart 3.12 (el del proyecto, vía FVM), `dio` y los modelos existentes. `args` ^2.7.0
declarada en `pubspec.yaml` (ver Assumptions 6).

## Commands

```bash
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs   # solo si cambia un modelo freezed
fvm dart run bin/api_flow_runner.dart --help
fvm dart run bin/api_flow_runner.dart --workspace sample.workspace.json --env dev --list
fvm dart compile exe bin/api_flow_runner.dart -o build/api_flow_runner     # opcional
fvm flutter test test/cli
fvm flutter test                       # suite completa
fvm flutter analyze
# NO ejecutar `dart format` sobre archivos existentes: el repo no usa el estilo nuevo.
```

## Project Structure

```
bin/api_flow_runner.dart            # main mínimo: exit(await runCli(args))
lib/cli/                            # Dart puro (sin package:flutter), igual que engine/
  cli_options.dart                  # parseo de argumentos → CliOptions o error de uso
  run_cli.dart                      # orquestación; devuelve el código de salida; no llama a exit()
  selection.dart                    # elegir ambiente y flujos, mezclar variables
  redactor.dart                     # sustituye valores sensibles por ***
  run_report.dart                   # datos neutros (FlowReport/StepReport) a partir de FlowRunResult
  reporters/console_reporter.dart
  reporters/junit_reporter.dart
  reporters/json_reporter.dart
lib/engine/models/environment_kind.dart   # isProductionEnvironment, movida desde la UI
lib/ui/shell/environment_kind.dart        # reexporta la función; los 8 usos actuales no cambian
test/cli/                           # unit + una prueba de punta a punta con HttpServer local
SPEC-flow-cli.md, tasks/flow-cli/, README.md (sección "Running flows from the terminal")
```

`isProductionEnvironment` hoy vive en `lib/ui/shell` e importa `painting`: el CLI no
puede depender de eso. Se mueve la función pura al engine y el archivo de UI la
reexporta, sin tocar a quienes la usan.

## Code Style

`runCli` recibe todo lo del mundo exterior por parámetro (sinks, entorno, ejecutor,
reloj) para probarlo sin procesos ni red; el `main` solo conecta lo real:

```dart
Future<int> runCli(
  List<String> args, {
  required StringSink out,
  required StringSink err,
  Map<String, String> environment = const {},
  RequestExecutor? executor,        // null → uno real con el --timeout
  DateTime Function()? now,
}) async {
  final parsed = parseCliArgs(args);
  if (parsed case CliUsageError(:final message)) {
    err.writeln('error: $message');
    return 2;
  }
  // ...
}
```

Convenciones: sin `print` (lint `avoid_print`): se escribe en los sinks; `exit()` solo en
`bin/`; mensajes en inglés; comentarios `///` con el porqué; estilo de línea largo del repo.

## Testing Strategy

- **Argumentos:** cada opción, repetibles (`--flow`, `--var`), valores faltantes,
  opciones desconocidas, `--var` sin `=`, `--timeout` no numérico o ≤ 0.
- **Selección:** un solo ambiente sin `--env`; varios sin `--env` → 2; ambiente
  inexistente; flujo por nombre/id; nombre ambiguo; sin flujos; producción sin y con
  `--allow-production`.
- **Variables:** precedencia ambiente < `AFS_VAR_*` < `--var`; aviso por secreta vacía.
- **Redactor:** secretas, overrides, extraídos por nombre; valores cortos no se
  enmascaran; aparece redactado también dentro de URLs y mensajes de assertion.
- **Reporters** (con resultados construidos a mano, sin red): consola, JUnit
  (escape de `& < > "`, tipos `failure`/`error`/`skipped`, totales) y JSON con su
  esquema; se comparan contra texto esperado.
- **Orquestación con `RequestExecutor` falso (mocktail):** todo pasa → 0; una
  assertion falla → 1 y los pasos siguientes salen `SKIP`; error de red → 1;
  `--fail-fast` no corre el segundo flujo; reporte no escribible → 2 después de
  correr; los reportes no contienen ningún secreto.
- **De punta a punta, en proceso:** `runCli` contra un `HttpServer` de `dart:io` en
  `localhost` con rutas guiadas (dio real): un flujo de dos pasos con extracción entre
  ellos y assertions; verifica código de salida, JUnit y que el timeout corta un paso lento.
- Cobertura: toda rama de `lib/cli/`. La suite existente, sin cambios, en verde.

## Boundaries

- **Always:** TDD; `fvm flutter analyze` y la suite completa antes de cada commit;
  `lib/cli/` y `engine/` sin imports de Flutter; nada de `exit()` ni `print` fuera de
  `bin/`; redactar antes de escribir cualquier salida; commits por tarea con solo sus archivos.
- **Ask first:** declarar `args` (propuesto); añadir `--insecure`, reintentos, paralelismo
  o ejecución de flujos desde los datos locales de la app; cambiar `release.yml` para
  publicar ejecutables; cualquier cambio de comportamiento en `engine/`.
- **Never:** imprimir un valor de variable secreta ni de `--var`; ejecutar contra un
  ambiente de producción sin `--allow-production`; escribir en la carpeta de datos de la
  app; abortar con un stack trace en errores de uso; debilitar o borrar tests existentes.

## Success Criteria

1. `--help` y `--list` funcionan sin enviar ningún request.
2. Con un workspace de ejemplo y un servidor local, un flujo correcto termina con `0` y
   uno con una assertion fallida con `1`; los pasos tras un fallo con `stopOnFailure`
   salen `[SKIP]`.
3. Argumentos inválidos, archivo ilegible o de versión nueva, ambiente/flujo inexistente
   o ambiguo y producción sin `--allow-production` terminan con `2`, con un mensaje claro
   y sin enviar requests.
4. `--var` y `AFS_VAR_*` sobrescriben variables con la precedencia indicada.
5. `--junit` escribe XML válido con un `testsuite` por flujo y un `testcase` por paso, con
   `failure`/`error`/`skipped` según el caso.
6. `--json` escribe el esquema indicado.
7. Ningún valor secreto, de `--var` ni extraído en variables sensibles aparece en consola,
   `--verbose`, JUnit ni JSON (probado con valores conocidos).
8. `--timeout` corta un request lento y lo marca como fallo de red sin colgar el proceso.
9. `engine/` no cambia de comportamiento; `isProductionEnvironment` sigue funcionando
   para la UI y ahora también para el CLI.
10. `fvm flutter analyze` sin avisos y `fvm flutter test` en verde.

## Open Questions

1. **¿Declaro `args`?** Lo recomiendo: ya está resuelta como transitiva, y escribir un
   parser a mano es más código y más errores. La alternativa es un parser mínimo propio.
2. **¿Correr también contra los datos locales de la app** (`--project <nombre>`, leyendo la
   carpeta de datos, con los secretos reales y las sesiones)? Útil en la terminal local,
   pero abre la puerta a escribir en esos datos y a sesiones; lo dejé fuera de v1.
3. **¿Publicar ejecutables** (`dart compile exe`) en el release de GitHub para Windows,
   macOS y Linux? Permite usar el runner en CI sin instalar Flutter, pero toca
   `release.yml`. Propongo hacerlo como una tarea posterior, con tu visto bueno.
4. **¿La heurística de nombres sensibles** (`token`, `secret`, `password`, `key`, `auth`)
   es suficiente, o prefieres una opción explícita `--redact <nombre>`?
5. **¿`dart run` en otro repositorio?** Para usar el runner desde otro proyecto sin copiar
   este código haría falta el ejecutable compilado (pregunta 3) o `dart pub global activate
   --source git`. ¿Cuál es tu caso de uso principal?

## Estado

Implementado de C1 a C8 (`tasks/flow-cli/`). Criterios de éxito y dónde se comprueban:

| # | Criterio | Pruebas |
|---|---|---|
| 1 | `--help` y `--list` no envían requests | `run_cli_test.dart` (`--help and --list`) |
| 2 | 0 si pasa, 1 si falla, pasos siguientes `[SKIP]` | `run_cli_test.dart`, `end_to_end_test.dart` |
| 3 | 2 ante errores de uso/archivo/selección/producción, sin requests | `run_cli_test.dart` (`runs that cannot start`) |
| 4 | precedencia de variables | `selection_test.dart`, `run_cli_test.dart` |
| 5 | JUnit | `junit_reporter_test.dart`, `end_to_end_test.dart` |
| 6 | JSON | `json_reporter_test.dart`, `run_cli_test.dart` |
| 7 | ningún secreto en la salida | `redactor_test.dart`, `run_cli_test.dart` (`secrets`), `end_to_end_test.dart` |
| 8 | `--timeout` corta un request lento | `end_to_end_test.dart` |
| 9 | `engine/` sin cambios de comportamiento | suite completa; solo se movió `isProductionEnvironment` |
| 10 | `analyze` y `test` en verde | CI |

Decisiones tomadas al implementar: `--timeout` acepta decimales (`0.5`); `--list` no aplica
la guarda de producción ni exige `--env`; si falla la escritura de un reporte, el otro se
escribe igualmente y el código de salida es 2.
