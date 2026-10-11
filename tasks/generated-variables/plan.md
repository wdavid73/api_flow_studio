# Plan: generated-variables

Spec: [SPEC-generated-variables.md](../../SPEC-generated-variables.md). Plan separado
de `tasks/plan.md` (v1), `tasks/workspaces/` y `tasks/integration-tests/`.

## Overview

Seis tareas, cada una un corte vertical que deja la app funcionando, con su test
y su commit. La suite existente (tests unitarios y los recorridos de
`test/integration`) debe seguir verde sin modificarse en cada tarea.

## Hallazgos del código que condicionan el plan

- **Hay un solo punto de envío**: `RequestExecutor.execute`. `SessionRequestExecutor`
  lo envuelve con `implements` y le pasa `variables`; no hay que tocar su firma
  ni la de `FlowRunner`. El generador entra por el **constructor** del executor.
- **`interpolate` se usa también en `curl_builder` y en la vista previa del
  flujo.** Sin generador esos sitios dejan el token literal (comportamiento
  deseado) sin tocarlos.
- **El request enviado no se guarda en ningún lado.** `ExecutedResponse` no lo
  lleva, `HistoryEntry` tampoco, y "Request Sent" del inspector re-interpola
  `endpoint.url` (`flow_run_view_screen.dart:60`). Con valores aleatorios eso
  mostraría una URL distinta de la enviada → se añade `ExecutedResponse.requestUrl`
  (solo memoria). Requiere regenerar freezed.
- **Tres regex de `{{var}}` usan `\w+`** y no aceptan `$`: `interpolator.dart`,
  `json_syntax.dart` (`_variablePattern`, y revisar `_outerPattern`) y
  `json_body.dart`. Sin cambiar este último, un body `{"n": {{$randomInt}}}`
  se marcaría como JSON inválido.
- **Orden de pasadas**: primero variables normales (`\w+`), luego dinámicas
  (`\$\w+`). Un valor de ambiente que contenga `{{$uuid}}` se resuelve; un valor
  generado nunca contiene `{{`, así que no se re-escanea.

## Dependency graph

```
G1 DynamicValues ── G2 interpolate(+dynamic) ── G3 executor + requestUrl ──┬─ G5 inspector "Request Sent"
                                                                           │
                                                   G4 UI: highlight + JSON ─┴─ G6 ayuda, journey, docs
```

G4 solo necesita el *conjunto de nombres conocidos* (G1), así que puede ir en
paralelo a G2–G3; se ordena después por simplicidad (un solo hilo).

## Tareas

Cada tarea sigue TDD (test rojo primero) y termina con `fvm flutter analyze` y la
suite relevante en verde.

### G1 — `DynamicValues` (engine, aislado)
Archivo nuevo `lib/engine/variables/dynamic_values.dart` + test. Expone
`generate(name) → String?` y `static const names` / `isKnown(name)` para que la
UI no duplique la lista. Seis tokens de la spec; `Random` y reloj inyectables.
**Aceptación:** formatos correctos con semilla fija; `uuid` v4 válido;
`randomString` de 12 `[a-z0-9]`; `randomEmail` `test.<8>@example.com`; nombre
desconocido → `null`.

### G2 — `interpolate*` con generador opcional
Parámetro nombrado opcional `dynamicValues` en `interpolate`,
`interpolateEntries`, `interpolateBody`. Sin él, comportamiento idéntico al
actual. **Aceptación:** un token → valor; dos apariciones → distintos; desconocido
→ literal; variable normal con `{{$uuid}}` en su valor se resuelve; sin
generador → literal; los 693+ tests existentes intactos.

### G3 — `RequestExecutor` + `ExecutedResponse.requestUrl`
Constructor `RequestExecutor({Dio?, DynamicValues?})` (por defecto uno real),
pasarlo en URL, query, headers, body y auth (basic/bearer). Añadir
`String? requestUrl` a `ExecutedResponse` (rama de éxito y de error) y regenerar
freezed. **Aceptación:** test con dio mockeado: lo que sale por la red lleva
valores reales; dos `execute` seguidos difieren; `requestUrl` coincide con la URL
enviada; `curl_builder` deja el token literal (test de regresión).
**Checkpoint tras G3:** `fvm flutter test` completo + `analyze` verdes.

### G4 — UI: resaltado y validación JSON
`tokenizeVariablesOnly` y `VariableHighlightingController`: token `{{$x}}`
conocido → color resuelto, desconocido → no resuelto. `json_body.dart` acepta
`{{$token}}` en `isValidJsonBody` y mantiene `formatJsonBody` negándose a
reformatear un token desnudo. Revisar `_outerPattern` de `json_syntax.dart`.
**Aceptación:** tests de widget/unidad: `$uuid` cian, `$nope` ámbar, `{{var}}`
sin cambios; body `{"n": {{$randomInt}}}` válido.

### G5 — Inspector "Request Sent" usa la URL enviada
`flow_run_view_screen.dart` pasa `result.response?.requestUrl ?? interpolación`
a `RunStepInspector` (el fallback cubre pasos sin respuesta). **Aceptación:**
test de widget: un paso con `{{$uuid}}` en la URL muestra en "Request Sent" la
misma URL que recibió el servidor falso, no una re-interpolada ni el token.

### G6 — Ayuda, journey y docs
Lista de tokens en la nota "Syntax & Resolution" del gestor de ambientes; un
journey en `test/integration` que envía el mismo request dos veces y comprueba
que `{{$randomEmail}}` difiere (con sus equivalentes en `integration_test/`
según la convención del repo); sección corta en README. **Aceptación:** journey
verde en `fvm flutter test test/integration`; README documenta los tokens.

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Regenerar freezed toca `executed_response.freezed.dart` y puede arrastrar diffs de otros generados | Ejecutar `build_runner` y revisar que el diff sea solo de ese archivo |
| El tercer regex (`json_syntax._outerPattern`) puede tokenizar variables dentro de JSON por otra vía | G4 empieza leyéndolo y cubriéndolo con un test antes de cambiar |
| `Random.secure()` por defecto es más lento/inesperado en tests | Siempre inyectar `Random(seed)` en tests; el default solo en producción |
| Journeys duplicados (`test/integration` e `integration_test/`) | Seguir `SPEC-integration-tests.md` para añadir el journey una sola vez en el formato compartido |

## Preguntas abiertas (heredadas de la spec)

Se mantienen los supuestos de la spec (valor nuevo por aparición, `$timestamp` en
segundos, export literal). Si cambian, solo G1/G2 se ven afectadas.
