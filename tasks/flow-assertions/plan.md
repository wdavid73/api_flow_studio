# Plan: flow-assertions

Spec: [SPEC-flow-assertions.md](../../SPEC-flow-assertions.md). Plan separado de
`tasks/plan.md` (v1), `tasks/workspaces/`, `tasks/integration-tests/` y
`tasks/generated-variables/`.

## Overview

Seis tareas, cada una un corte vertical que deja la app funcionando, con su test
y su commit. Se aplican las decisiones por defecto de la spec: `workspaceFormatVersion`
sube a 2, se quitan `assertField`/`assertExpected` del modelo, las assertions no
son bloqueantes **no** entran, y `extract` con ruta inválida queda fuera.

## Hallazgos del código que condicionan el plan

- **Los campos viejos se usan en 6 archivos de `lib` + 7 de test/integración**
  (`flow_runner`, `step_card`, `flow_step`, `value_extractor` (solo un comentario) y los
  tests `flow_runner_test`, `flow_step_test`, `flow_run_view_*`, `step_card_editor_test`,
  `flow_journey`). Quitarlos es un cambio atómico: no se puede dejar la app verde con
  el modelo a medias. Por eso la **tarea A2 es el "swap"** y mantiene el editor
  actual funcionando con un adaptador, y el editor nuevo llega en A4.
- **El adaptador evita reescribir los tests del editor.** En A2 los dos campos
  existentes (`assert-field-$i`, `assert-expected-$i`) pasan a leer y escribir la
  primera assertion `equals` de la lista, así los tests de `step_card_editor_test.dart`
  solo cambian al construir el `FlowStep`, no sus `Key`s ni sus pasos.
- **Los flujos se leen con `Flow.fromJson` → `FlowStep.fromJson`** (`JsonStore.readFlows`)
  y el import de workspace copia pasos con `copyWith`. Con una `fromJson` que migra
  el JSON legado, tanto `flows.json` como un workspace v1 se migran sin tocar
  `json_store.dart` ni `import_workspace.dart`.
- **`classifyFailure` se apoya en el prefijo `Assertion failed`** de `failureReason`;
  el evaluador y el runner lo conservan.
- **`extractValue` lanza `ArgumentError`** si la ruta no empieza por `response`
  (hoy rompería la corrida). El evaluador valida la ruta antes de llamarlo.
- **El runner arma el mapa de respuesta** `{status, headers, body}`; añadir
  `elapsedMs` y `sizeBytes` ahí habilita `response.elapsedMs < 800` sin tocar nada más.
- **Tres tests dependen de `version: 1/2` del workspace**
  (`workspace_file_test.dart` líneas ~80, ~164 y ~195); el de "versión futura" pasa de 2 a 3.
- **No usar `dart format`** sobre archivos existentes (lección de generated-variables).

## Dependency graph

```
A1 Assertion + evaluador ── A2 swap del modelo + runner ──┬─ A3 workspace v2
                                                          └─ A4 editor de assertions ── A5 vista de ejecución ──┐
                                                                                                                 A6 journey + docs
                                                          A3 ───────────────────────────────────────────────────┘
```

## Tareas

Cada tarea sigue TDD (test rojo primero) y termina con `fvm flutter analyze` y la
suite relevante en verde.

### A1 — `Assertion`, `AssertionResult` y el evaluador (engine, aislado)
Archivos nuevos: `lib/engine/models/assertion.dart` (freezed, `Assertion` +
`AssertionOperator`), `lib/engine/flows/assertion_evaluator.dart`
(`evaluateAssertion`) y `AssertionResult`. Sin tocar nada existente.
**Aceptación:** los 9 operadores según la tabla de la spec (pasa / falla / valor
ausente); ruta inválida y regex inválida → fallo con mensaje, sin excepción;
`>`/`<` con texto → fallo `"x" is not a number`; `expected` con `{{variable}}`;
`exists` ignora `expected`; campo vacío → "sin configurar"; mensajes empiezan por
`Assertion failed`.
**Verify:** `fvm dart run build_runner build --delete-conflicting-outputs && fvm flutter test test/engine/flows/assertion_evaluator_test.dart test/engine/models`

### A2 — Swap: `FlowStep.assertions`, migración y runner
`FlowStep` gana `assertions` y pierde `assertField`/`assertExpected`;
`FlowStep.fromJson` migra el JSON legado. `FlowRunner` evalúa todas las
assertions con el evaluador, añade `elapsedMs`/`sizeBytes` al mapa y guarda
`assertionResults` en `FlowStepResult`. `step_card` usa un **adaptador** (los dos
campos actuales editan la primera assertion `equals`). Se actualizan de forma
mecánica los tests que construían `FlowStep(assertField:…)`.
**Aceptación:** migración (ambos viejos → una `equals`; solo uno → ninguna;
`assertions` presente → viejos ignorados; nada → vacío; `toJson` no escribe los
viejos); varias assertions → se evalúan todas y `failureReason` las lista una por
línea; `stopOnFailure` igual que antes; `response.elapsedMs` afirmable; ruta
inválida no lanza; un `flows.json` con campos viejos se lee con la assertion
migrada (test en `json_store`); los tests del editor y de la vista de ejecución
pasan sin cambiar sus `Key`s ni sus acciones.
**Verify:** `fvm dart run build_runner build --delete-conflicting-outputs && fvm flutter test test/engine test/ui/flows`
**Checkpoint tras A2:** `fvm flutter test` completo + `analyze` verdes.

### A3 — Workspace format v2
`workspaceFormatVersion = 2`; la lectura acepta 1 y 2 (la migración de assertions
ya ocurre en `FlowStep.fromJson`); ≥3 → `newerVersion`.
**Aceptación:** export escribe `version: 2`; import de un v1 con
`assertField/assertExpected` produce la assertion migrada; v3 se rechaza con el
mensaje existente; los tests de `workspace_file_test.dart` que usaban 2 como
"futuro" pasan a 3; resto intacto.
**Verify:** `fvm flutter test test/engine/workspace`

### A4 — Editor de assertions en el paso
Se reemplaza el adaptador por filas: campo · operador (dropdown) · esperado
(oculto con `exists`/`not exists`) · quitar, más `Add assertion` (la primera
propone `response.status == 200`). Claves: `assertion-field-$step-$i`,
`assertion-operator-$step-$i`, `assertion-expected-$step-$i`,
`remove-assertion-$step-$i`, `add-assertion-$step`.
**Aceptación:** añadir, editar, cambiar operador, quitar; `exists` oculta el
esperado y conserva su valor al volver a `==`; persiste vía `onUpdateStep`;
assertion con campo vacío no se guarda como configurada (se conserva en pantalla
mientras se edita). Los tests del adaptador de A2 se reemplazan por los del editor
nuevo (único caso en que se cambian `Key`s, ya anunciado en la spec).
**Verify:** `fvm flutter test test/ui/flows/step_card_editor_test.dart test/ui/flows/flow_builder_screen_test.dart`

### A5 — Vista de ejecución
`ErrorDetailPanel` muestra una línea por assertion fallida; el inspector añade la
pestaña **Assertions** (✓/✗, operador, esperado, actual) cuando el paso tiene
assertions, también si pasó; `RunStepCard` muestra `n/m assertions`.
**Aceptación:** paso con ✓✓✗ → pestaña con los tres, resumen `2/3`, panel de error con
una línea; paso sin assertions → sin pestaña ni resumen y el resto de la vista
exactamente como hoy; ruta inválida se ve como fila ✗ con su mensaje.
**Verify:** `fvm flutter test test/ui/flows`

### A6 — Journey, README y cierre
Journey en `integration_test/journeys/flow_journey.dart` (se actualiza el que usa
`assertField`): flujo con tres assertions, una falla → "Assertion Failure", pestaña
✓✓✗, paso en failure. README: sección de assertions y la limitación de que una
versión anterior de la app ignora `assertions`. Marcar los criterios de la spec.
**Aceptación:** `fvm flutter test test/integration` verde; README documenta
operadores, `elapsedMs`/`sizeBytes` y la migración.
**Verify:** `fvm flutter test && fvm flutter analyze`

## Riesgos

| Riesgo | Mitigación |
|---|---|
| A2 toca muchos archivos a la vez (modelo, runner, editor, ~7 tests) | Es un swap atómico por diseño; el adaptador del editor limita el cambio de UI y los tests se tocan solo en su constructor |
| `FlowStep.fromJson` personalizado con freezed puede chocar con el generador | Delegar en `_$FlowStepFromJson(migrar(json))`, que es el patrón que ya usan los demás modelos con `fromJson` manual; probarlo en A2 antes del resto |
| Migrar de forma silenciosa un `flows.json` | La migración solo ocurre en memoria al leer; el archivo se reescribe cuando el usuario guarda el flujo (spec: "nunca reescribir fuera del guardado normal") |
| Dropdown de operador en tests de widget | Usar `DropdownButton` con `Key` y `tester.tap` + `pumpAndSettle`, igual que otros selectores del repo (`method_selector`) |
| Subir la versión del formato rompe archivos exportados antes | El lector acepta 1 y 2; solo se rechaza ≥3 |

## Fuera del plan (seguimiento)

- Assertions no bloqueantes (un tercer estado de paso).
- `extract` con ruta inválida lanza `ArgumentError` (mismo defecto; tarea aparte).
- `>=`/`<=` y comparación sin distinguir mayúsculas.
