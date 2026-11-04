# Flow Canvas Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sustituir el editor vertical de Flows por un canvas ordenado donde cada paso muestra sus entradas (con origen) y los campos de su última respuesta, y los datos se conectan arrastrando un campo hasta una entrada.

**Architecture:** Todo lo nuevo se calcula a partir del modelo actual, que no cambia: funciones puras en `lib/engine/flows/` (entradas, campos, orígenes, nombres, cableado) y una capa de UI en `lib/ui/flows/canvas/` cuya geometría sale de métricas fijas, de modo que nodos y cables comparten coordenadas sin medir widgets. Los resultados de ejecución viven en un provider en memoria por flujo; la pantalla de ejecución aparte desaparece y sus piezas pasan al panel lateral.

**Tech Stack:** Flutter `3.44.6` (FVM), Dart `^3.12`, `flutter_riverpod ^2.6.1`, `freezed`, `flutter_test` + `mocktail`, l10n con ARB (`app_en.arb`, `app_es.arb`).

**Spec:** [docs/SPEC-flow-canvas.md](../../docs/SPEC-flow-canvas.md). Leer la spec completa antes de cada tarea; este plan dice *qué* se decide y *dónde*, la spec dice *por qué*.

## Global Constraints

- **El modelo no cambia:** ni `Flow`, `FlowStep`, `Assertion`, `flows.json`, `flowsFileVersion = 1`, el archivo de workspace ni `bin/api_flow_runner.dart`. Un cable = `steps[j].extract[nombre]` + `{{nombre}}` en el request de un paso `i > j`.
- **Ejecutar desde el canvas nunca escribe en el historial** (`appendHistoryEntry` solo lo llama `send_provider.dart`).
- `lib/engine/` no importa `package:flutter`. Nada nuevo usa `dart:io` (la app también se publica en web).
- Precedencia de orígenes = la del runner: paso anterior más cercano que extrae el nombre > environment activo > `session_access_token`/`session_refresh_token` > sin origen. Los extracts de un paso no alimentan sus propias entradas.
- Nombre de variable válido = `^\w+$` (mismo patrón que `interpolator.dart`).
- Toda cadena visible va por `context.l10n`, en `app_en.arb` **y** `app_es.arb` (claves en *Textos*). Las llaves de `{{nombre}}` se arman en código y se pasan como argumento; nunca se escriben `{`/`}` literales en un ARB.
- TDD: test rojo primero. Antes de cada commit: `fvm flutter analyze` sin avisos y `fvm flutter test` en verde.
- **No ejecutar `dart format`** sobre archivos existentes. Commits por tarea, solo con los archivos de la tarea, estilo `feat(flows): …`, terminados en `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.
- Un test que se elimina porque su widget desaparece se **sustituye** en la misma tarea por uno que cubre el mismo comportamiento sobre el canvas.

## Review Focus

1. **Body del historial recortado o que no es JSON** (página HTML de error, `truncated: true`): el nodo no debe romperse; muestra `canvasTruncated` / `canvasNotJson` y cero campos. → test en Task 4.
2. **Nombre de variable inválido en "Usar como variable"** (`user id`, `user-id`, vacío): no puede guardarse un extract que el interpolador nunca resolverá; el botón confirmar queda deshabilitado con `variableNameInvalid`. → test en Task 9.
3. **Extract cuya ruta no está entre los campos visibles del nodo** (`response.status`, `response.headers.x`, el campo nº 12, o una ruta que ya no está en la respuesta): el cable sale del ancla de la cabecera, no se pierde ni lanza. → test en Task 8.
4. **Cambio de proyecto con una ejecución en curso o terminada:** los resultados no deben aparecer en el flujo de otro proyecto ni sobrevivir al cambio. → test en Task 4.
5. **Respuestas enormes** (lista de 1000 objetos, anidación profunda): `responseFields` corta en 200 hojas, informa `omitted` y no recorre más de lo necesario. → test en Task 2.

---

## Textos (l10n)

Claves nuevas, añadidas por la tarea indicada. `es` / `en`:

| Clave | es | en | Tarea |
|---|---|---|---|
| `canvasInputs` | ENTRADAS | INPUTS | 6 |
| `canvasNoInputs` | Sin variables | No variables | 6 |
| `canvasResponse` | RESPUESTA | RESPONSE | 6 |
| `canvasSourceRun(age)` | última ejecución · {age} | last run · {age} | 6 |
| `canvasSourceHistory(age)` | historial · {age} | history · {age} | 6 |
| `canvasNotSent` | Aún no se ha enviado | Not sent yet | 6 |
| `canvasTruncated` | Respuesta recortada: ejecuta el paso para verla completa | Response was cut: run the step to see all of it | 6 |
| `canvasNotJson` | La respuesta no es JSON | The response is not JSON | 6 |
| `canvasMoreFields(count)` | +{count} más | +{count} more | 6 |
| `canvasOriginEnv` | env | env | 6 |
| `canvasOriginGenerated` | generado | generated | 6 |
| `canvasOriginSession` | 🔑 sesión | 🔑 session | 6 |
| `canvasOriginStep(step)` | ← {step} | ← {step} | 6 |
| `canvasOriginMissing` | ⚠ sin origen | ⚠ no source | 6 |
| `canvasTokenToSession` | 🔑 → sesión | 🔑 → session | 6 |
| `canvasMissingRequest` | Petición no encontrada | Request not found | 6 |
| `canvasAddStep` / `canvasAddFirstStep` | Agregar paso / Agregar primer paso | Add step / Add first step | 6 |
| `canvasMoveLeft` / `canvasMoveRight` / `canvasDeleteStep` | Mover a la izquierda / Mover a la derecha / Eliminar paso | Move left / Move right / Delete step | 6 |
| `canvasNotRun` | sin enviar | not sent | 6 |
| `canvasZoomIn` / `canvasZoomOut` / `canvasZoomFit` | Acercar / Alejar / Ajustar | Zoom in / Zoom out / Fit | 6 |
| `ageJustNow` | justo ahora | just now | 6 |
| `ageMinutes(count)` | hace {count} min | {count} min ago | 6 |
| `ageHours(count)` | hace {count} h | {count} h ago | 6 |
| `ageDays(count)` (plural) | hace 1 día / hace {count} días | 1 day ago / {count} days ago | 6 |
| `panelStep` / `panelResponse` / `panelRun` / `panelClose` | Paso / Respuesta / Ejecución / Cerrar | Step / Response / Run / Close | 5 |
| `panelInputs` | Entradas | Inputs | 5 |
| `panelExtractNotInResponse` | no aparece en la última respuesta | not in the last response | 5 |
| `canvasRunUntilHere` | Ejecutar hasta aquí | Run up to here | 7 |
| `canvasRerunFromHere` | Volver a ejecutar desde aquí | Run again from here | 7 |
| `wireDisconnect` | Desconectar | Disconnect | 8 |
| `wireUsedBy(count)` (plural) | la usa 1 paso / la usan {count} pasos | used by 1 step / used by {count} steps | 8 |
| `wireShadowed(step, variable)` | El paso {step} ya define {variable} y lo sobrescribe | Step {step} already sets {variable} and overrides it | 8 |
| `fieldUseAsVariable` | Usar como variable… | Use as variable… | 9 |
| `fieldCopyPath` / `fieldPathCopied` | Copiar ruta / Ruta copiada | Copy path / Path copied | 9 |
| `variableNameTitle` | Nombre de la variable | Variable name | 9 |
| `variableNameInvalid` | Usa solo letras, números y _ | Use only letters, numbers and _ | 9 |
| `suggestionConnect(variable)` | ¿Conectar {variable}? | Connect {variable}? | 9 |
| `flowListToggle` | Mostrar u ocultar flujos | Show or hide flows | 10 |

"Añadir assertion" reutiliza `assertionsAdd`. Las claves que quedan sin uso al borrar widgets (`flowsSave`, `stepPayloadTemplate`, `stepTerminal`, `runReRunFlow`, `runSelectStep`…) se quitan en la tarea que borra su último uso, tras comprobarlo con `grep`.

Regenerar tras tocar los ARB: `fvm flutter gen-l10n`.

## Keys de widgets (contrato para tests)

Se conservan: `flow-name-field`, `run-flow-button`, `run-summary-total`, `run-in-progress-indicator`, `add-step-button`, `empty-flow-state`, `no-flow-selected`, `stop-on-failure-$i`, las del `AssertionsEditor` y las del editor de extracts (`extract-name-$i-$k`, `extract-path-$i-$k`, `remove-extract-$i-$k`, `add-extract-$i`).

Nuevas: `flow-canvas`, `step-node-$i`, `step-node-status-$i`, `step-node-menu-$i`, `step-node-change-request-$i`, `step-node-move-left-$i`, `step-node-move-right-$i`, `step-node-delete-$i`, `step-node-missing-$i`, `step-input-$i-$name`, `step-input-origin-$i-$name`, `step-field-$i-$k`, `step-field-pin-$i-$k`, `run-until-$i`, `step-node-rerun-from-$i`, `wire-$j-$i-$name`, `suggestion-$i-$name`, `disconnect-$i-$name`, `step-panel`, `step-panel-close`, `step-panel-tab-step`, `step-panel-tab-response`, `step-panel-tab-run`, `step-panel-change-request`, `step-panel-delete`, `response-tree-value-$path`, `field-menu-use-as-variable`, `field-menu-add-assertion`, `field-menu-copy-path`, `variable-name-field`, `variable-name-confirm`, `zoom-in`, `zoom-out`, `zoom-fit`, `zoom-level`, `toggle-flow-list`.

---

### Task 1: Entradas de un paso (engine)

**Files:**
- Create: `lib/engine/flows/step_inputs.dart`
- Modify: `lib/engine/session/session_apply.dart` (extraer la regla de `applySession`)
- Test: `test/engine/flows/step_inputs_test.dart`, `test/engine/session/session_apply_test.dart`

**Interfaces:**
- Produces:
  - `class StepInputs { const StepInputs({required this.variables, required this.generated}); final List<String> variables; final List<String> generated; }` — `generated` sin el `$` (`uuid`, `randomEmail`).
  - `StepInputs stepInputs(Endpoint endpoint)`
  - `bool acceptsSessionToken(Endpoint endpoint)` — `authConfig is AuthConfigNone` y sin header `Authorization` habilitado. `applySession` pasa a usarla (mismo comportamiento).

- [ ] **Step 1: Write the failing tests** (`step_inputs_test.dart`)

```dart
test('finds variables in url, enabled query params and headers, in order, without duplicates', () {
  const e = Endpoint(id: 'e', groupId: 'g', name: 'n', method: 'GET',
    url: '{{base_url}}/users/{{user_id}}',
    queryParams: [KeyValueEntry(key: 'region', value: '{{region}}'), KeyValueEntry(key: 'x', value: '{{off}}', enabled: false)],
    headers: [KeyValueEntry(key: 'X-Id', value: '{{user_id}}')]);
  expect(stepInputs(e).variables, ['base_url', 'user_id', 'region']);
});
test('reads json raw, form-urlencoded and multipart enabled fields', ...);   // un endpoint por tipo de body
test('reads basic and bearer auth', ...);                                     // ['user','pass'] y ['token']
test('separates generated tokens', () {
  // url '{{$uuid}}/{{id}}', body json '{"e":"{{$randomEmail}}"}'
  expect(stepInputs(e).variables, ['id']);
  expect(stepInputs(e).generated, ['uuid', 'randomEmail']);
});
test('ignores malformed tokens', () { /* '{{ id }}', '{{user-id}}', '{id}' */ expect(stepInputs(e).variables, isEmpty); });
```

En `session_apply_test.dart`: `acceptsSessionToken` es `true` sin auth ni header; `false` con `AuthConfig.bearer`, con header `authorization` habilitado (minúsculas); `true` si ese header está deshabilitado.

- [ ] **Step 2: Run tests to verify they fail**

Run: `fvm flutter test test/engine/flows/step_inputs_test.dart test/engine/session/session_apply_test.dart`
Expected: FAIL — `stepInputs` / `acceptsSessionToken` no definidos.

- [ ] **Step 3: Implement `stepInputs` and `acceptsSessionToken`**

Reutilizar los patrones `\{\{(\w+)\}\}` y `\{\{\$(\w+)\}\}` (hacerlos visibles desde `interpolator.dart` en vez de duplicarlos). Recorrer los textos en el orden: url, query (key, value), headers (key, value), body, auth.

- [ ] **Step 4: Run tests to verify they pass**

Run: `fvm flutter test test/engine/flows/step_inputs_test.dart test/engine/session`
Expected: PASS (incluida la suite existente de sesión).

- [ ] **Step 5: Commit** — `feat(flows): detect the variables a step's request uses`

---

### Task 2: Campos de la respuesta (engine)

**Files:**
- Create: `lib/engine/flows/response_fields.dart`
- Modify: `lib/engine/session/token_finder.dart` (exponer las claves)
- Test: `test/engine/flows/response_fields_test.dart`, `test/engine/session/token_finder_test.dart`

**Interfaces:**
- Produces:
  - `class ResponseField { const ResponseField({required this.path, required this.preview, this.listLength}); final String path; final String preview; final int? listLength; }` — `path` completa (`response.body.user.id`); `listLength` solo para la hoja que representa una lista.
  - `class ResponseFields { const ResponseFields(this.fields, {this.omitted = 0}); final List<ResponseField> fields; final int omitted; }`
  - `ResponseFields responseFields(Object? body, {int limit = 200})`
  - `String displayPath(String path)` — quita `response.body.`; `response.body` → `body`.
  - `bool isSessionTokenKey(String key)` en `token_finder.dart` (`accessToken`, `access_token`, `refreshToken`, `refresh_token`); `findTokens` la usa.

- [ ] **Step 1: Write the failing tests**

```dart
test('flattens nested objects into leaf paths with previews', () {
  final r = responseFields({'access_token': 'eyJhbGciOiJIUzI1NiJ9.abcdefghijk', 'user': {'id': 'u_81f', 'age': 3, 'ok': true, 'n': null}});
  expect(r.fields.map((f) => f.path), ['response.body.access_token', 'response.body.user.id', 'response.body.user.age', 'response.body.user.ok', 'response.body.user.n']);
  expect(r.fields[1].preview, '"u_81f"');
  expect(r.fields[0].preview, '"eyJhbGciOiJIUzI1NiJ9.abc…"'); // 24 caracteres de contenido + …
  expect(r.fields[2].preview, '3');
  expect(r.fields[4].preview, 'null');
});
test('a list becomes a leaf with its length and only index 0 is expanded', () {
  final r = responseFields({'items': [{'id': 1}, {'id': 2}, {'id': 3}]});
  expect(r.fields.map((f) => f.path), ['response.body.items', 'response.body.items.0.id']);
  expect(r.fields.first.listLength, 3);
  expect(r.fields.first.preview, '[3]');
});
test('a list at the root uses response.body.0', ...);
test('a scalar or string body has no fields', () { expect(responseFields('<html>').fields, isEmpty); expect(responseFields(null).fields, isEmpty); });
test('an empty object leaf previews as {}', ...);
test('stops at the limit and counts what was left out', () {
  final body = {'items': [for (var i = 0; i < 1000; i++) {'id': i}], 'meta': {for (var i = 0; i < 300; i++) 'k$i': i}};
  final r = responseFields(body, limit: 200);
  expect(r.fields, hasLength(200));
  expect(r.omitted, greaterThan(0));
});
test('displayPath strips response.body', () { expect(displayPath('response.body.user.id'), 'user.id'); expect(displayPath('response.status'), 'response.status'); });
```

`token_finder_test.dart`: `isSessionTokenKey` acepta las 4 claves y rechaza `token`, `Access_Token`.

- [ ] **Step 2: Run tests to verify they fail** — `fvm flutter test test/engine/flows/response_fields_test.dart test/engine/session/token_finder_test.dart` → FAIL.

- [ ] **Step 3: Implement** — recorrido en profundidad en orden de inserción del `Map`; contar las hojas que no entran sin seguir construyendo `ResponseField`s (el conteo puede ser aproximado por exceso solo si se corta la recursión: documentarlo en `///`).

- [ ] **Step 4: Run tests to verify they pass** — mismo comando → PASS.

- [ ] **Step 5: Commit** — `feat(flows): flatten a response into fields a step can extract`

---

### Task 3: Orígenes, nombres y sugerencias (engine)

**Files:**
- Create: `lib/engine/flows/input_origin.dart`, `lib/engine/flows/variable_naming.dart`
- Test: `test/engine/flows/input_origin_test.dart`, `test/engine/flows/variable_naming_test.dart`

**Interfaces:**
- Consumes: `ResponseField` (Task 2).
- Produces:
  - `sealed class InputOrigin` con `final class FromStep extends InputOrigin { const FromStep(this.stepIndex, this.path); final int stepIndex; final String path; }`, `FromEnvironment`, `FromSession`, `Missing` (las tres `const` sin campos).
  - `InputOrigin resolveInputOrigin(Flow flow, int stepIndex, String name, Map<String, String> environmentVariables)`
  - `String suggestVariableName(String path)`
  - `({int stepIndex, String path})? suggestConnection({required String name, required int stepIndex, required Map<int, List<ResponseField>> fieldsByStep})`
  - `bool isValidVariableName(String name)` — `^\w+$`.

- [ ] **Step 1: Write the failing tests**

```dart
// input_origin_test.dart — flow de 4 pasos; paso 0 extrae {'email': 'response.body.data.email'}, paso 1 extrae {'user_id': 'response.body.user.id', 'email': 'response.body.email'}
test('the nearest earlier step that extracts the name wins', () {
  expect(resolveInputOrigin(flow, 3, 'email', const {}), isA<FromStep>().having((o) => o.stepIndex, 'step', 1));
});
test("a step's own extract does not feed its own inputs", () { expect(resolveInputOrigin(flow, 1, 'user_id', const {}), isA<Missing>()); });
test('an extracted value wins over the environment', () { expect(resolveInputOrigin(flow, 2, 'user_id', {'user_id': 'x'}), isA<FromStep>()); });
test('falls back to the environment, then the session, then missing', () {
  expect(resolveInputOrigin(flow, 2, 'base_url', {'base_url': 'h'}), isA<FromEnvironment>());
  expect(resolveInputOrigin(flow, 2, 'session_access_token', const {}), isA<FromSession>());
  expect(resolveInputOrigin(flow, 2, 'region', const {}), isA<Missing>());
});

// variable_naming_test.dart
test('suggestVariableName', () {
  expect(suggestVariableName('response.body.user.id'), 'user_id');
  expect(suggestVariableName('response.body.data.token'), 'token');
  expect(suggestVariableName('response.body.access_token'), 'access_token');
  expect(suggestVariableName('response.body.userId'), 'user_id');
  expect(suggestVariableName('response.body.items.0.id'), 'items_id');
  expect(suggestVariableName('response.status'), 'status');
});
test('suggestConnection matches normalized names and prefers the nearest step', () {
  // fieldsByStep: 0 → [user.id], 2 → [data.userId]; entrada 'user_id' en el paso 3
  expect(suggestConnection(name: 'user_id', stepIndex: 3, fieldsByStep: f), (stepIndex: 2, path: 'response.body.data.userId'));
});
test('suggestConnection joins the last two segments', ...);   // 'userid' ↔ user.id
test('suggestConnection ignores later steps and returns null without a match', ...);
test('isValidVariableName', () { expect(isValidVariableName('user_id'), isTrue); for (final n in ['', 'user id', 'user-id', '{{x}}']) expect(isValidVariableName(n), isFalse); });
```

Genéricos para `suggestVariableName`: `id`, `name`, `token`, `code`, `value`, `key`, `uuid`; contenedores que no se anteponen: `data`, `result`, `response`, `body`; índices numéricos se saltan.

- [ ] **Step 2: Run tests to verify they fail** — `fvm flutter test test/engine/flows/input_origin_test.dart test/engine/flows/variable_naming_test.dart` → FAIL.
- [ ] **Step 3: Implement** — normalizar = minúsculas sin `_`/`-`; comparar contra el último segmento no numérico y contra los dos últimos unidos.
- [ ] **Step 4: Run tests to verify they pass** → PASS.
- [ ] **Step 5: Commit** — `feat(flows): resolve where each step input comes from and suggest names`

---

### Task 4: Estado de ejecución por flujo y respuesta de cada paso

**Files:**
- Modify: `lib/engine/flows/flow_runner.dart` (`runFrom(..., int? endIndex)`)
- Create: `lib/ui/flows/flow_run_provider.dart`, `lib/ui/flows/step_response.dart`
- Test: `test/engine/flows/flow_runner_test.dart`, `test/ui/flows/flow_run_provider_test.dart`, `test/ui/flows/step_response_test.dart`

**Interfaces:**
- Produces:
  - `FlowRunner.runFrom(Flow flow, {required int startIndex, int? endIndex, required Map<String, Endpoint> endpoints, required Map<String, String> seedVariables, …})` — `endIndex` inclusivo; los pasos posteriores no se ejecutan ni se reportan.
  - `int firstPendingStep(List<FlowStepResult?> results, int upTo)` — primer índice `<= upTo` sin resultado `success`; `upTo` si todos lo tienen.
  - ```dart
    class FlowRunState {
      const FlowRunState({this.results = const [], this.resultAt = const [], this.initialVariables = const {}, this.running = false, this.focusIndex});
      final List<FlowStepResult?> results;   // índice = paso
      final List<DateTime?> resultAt;
      final Map<String, String> initialVariables;
      final bool running;
      final int? focusIndex;                  // primer fallo, si no el último que corrió
    }
    class FlowRunNotifier extends FamilyNotifier<FlowRunState, String /* flowId */> {
      Future<void> runAll(Flow flow, Map<String, Endpoint> endpoints);
      Future<void> runUntil(Flow flow, Map<String, Endpoint> endpoints, int index);
      Future<void> rerunFrom(Flow flow, Map<String, Endpoint> endpoints, int index);
      void clearFrom(int index);
      Map<String, String> variablesEnteringStep(int index);
      String? requestUrlFor(int index, Endpoint? endpoint);
    }
    final flowRunProvider = NotifierProvider.family<FlowRunNotifier, FlowRunState, String>(FlowRunNotifier.new);
    ```
  - ```dart
    enum StepResponseSource { run, history }
    class StepResponse {
      const StepResponse({required this.source, this.at, this.status, this.headers = const {}, this.body, this.isJson = false, this.truncated = false});
      // body: Map/List decodificado si isJson; String crudo si no.
    }
    typedef StepResponseKey = ({String flowId, int index, String endpointId});
    final stepResponseProvider = Provider.family<AsyncValue<StepResponse?>, StepResponseKey>(...);
    ```

- [ ] **Step 1: Write the failing tests**

```dart
// flow_runner_test.dart (añadir; la suite existente no se toca)
test('runFrom with endIndex stops after that step and reports nothing later', () async {
  // 3 pasos, startIndex 0, endIndex 1 → executor llamado 2 veces; onStepResult con índices [0, 1]
});

// flow_run_provider_test.dart — ProviderContainer con jsonStoreProvider (JsonStore.inMemory) y requestExecutorProvider (mock)
test('firstPendingStep', () {
  expect(firstPendingStep([ok, ok, null], 2), 2);
  expect(firstPendingStep([ok, failed, ok], 2), 1);
  expect(firstPendingStep([ok, skipped], 1), 1);
  expect(firstPendingStep([ok, ok, ok], 1), 1);
});
test('runAll fills every result and focuses the first failure', ...);
test('runUntil only sends the pending steps up to the index and clears later results', () async {
  // tras runAll de 3 pasos OK, runUntil(…, 1) con los anteriores en éxito → solo 1 llamada (paso 1); results[2] == null
});
test('runUntil seeds the pool with what earlier steps extracted', ...);   // la URL del paso 1 lleva el valor extraído en 0
test('a canvas run never writes history', () async {
  await notifier.runAll(flow, endpoints);
  expect(await store.readHistory('e-1'), isEmpty);
});
test('switching project drops the results, and a run in flight does not write into the new project', ...);
test('clearFrom drops results from that index on', ...);

// step_response_test.dart
test('prefers the run result over history', ...);
test('falls back to the newest history entry with a body, decoding JSON', ...);
test('a truncated history body is not decoded', () { /* truncated: true → isJson false, truncated true */ });
test('a non-JSON history body is kept as text', () { /* '<html>…' → isJson false, body String */ });
test('no run and no history gives null', ...);
```

- [ ] **Step 2: Run tests to verify they fail** — `fvm flutter test test/engine/flows/flow_runner_test.dart test/ui/flows/flow_run_provider_test.dart test/ui/flows/step_response_test.dart` → FAIL.
- [ ] **Step 3: Implement** — `runAll`/`runUntil`/`rerunFrom` reproducen `FlowRunViewScreen._run`/`_rerunFromStep` (variables con `await ref.read(environmentsProvider.future)`, executor `sessionExecutorProvider`, auto-selección como `_autoSelect`). `build(flowId)` hace `ref.watch(activeProjectIdProvider)` e incrementa un contador de generación; los callbacks de una ejecución iniciada en otra generación se descartan. La entrada de historial "más reciente" es la **última** de la lista (`appendHistoryEntry` añade al final).
- [ ] **Step 4: Run tests to verify they pass** → PASS; `fvm flutter test test/engine` sigue verde.
- [ ] **Step 5: Commit** — `feat(flows): keep run results per flow in memory and resolve each step's last response`

---

### Task 5: Panel lateral del paso

**Files:**
- Create: `lib/ui/flows/extracts_editor.dart` (las filas de extract de `step_card.dart`, movidas), `lib/ui/flows/response_tree.dart`, `lib/ui/flows/canvas/step_panel.dart`
- Modify: `lib/ui/flows/step_card.dart` (usa `ExtractsEditor`; se borra en Task 6), `lib/l10n/app_en.arb`, `lib/l10n/app_es.arb`
- Test: `test/ui/flows/extracts_editor_test.dart`, `test/ui/flows/response_tree_test.dart`, `test/ui/flows/step_panel_test.dart`

**Interfaces:**
- Consumes: `stepInputs`, `resolveInputOrigin`, `responseFields` (Tasks 1–3); `flowRunProvider`, `stepResponseProvider` (Task 4); `AssertionsEditor`, `RunStepInspector`, `showAddStepPicker` (existentes).
- Produces:
  - `ExtractsEditor({required int stepIndex, required Map<String, String> extract, required ValueChanged<Map<String, String>> onChanged, Set<String>? knownPaths})` — mismas keys que hoy; con `knownPaths != null`, cada ruta ausente muestra `panelExtractNotInResponse`.
  - `ResponseTree({required int? status, required Map<String, String> headers, required Object? body, ValueChanged<String>? onValueTap})` — cada hoja tocable con key `response-tree-value-$path`, rutas `response.status`, `response.headers.<nombre>`, `response.body.…`; body no JSON se muestra como texto.
  - `enum StepPanelTab { step, response, run }`
  - `StepPanel({required Flow flow, required int index, required Map<String, Endpoint> endpoints, required VoidCallback onClose, StepPanelTab initialTab = StepPanelTab.step, ValueChanged<String>? onFieldTap})`

- [ ] **Step 1: Write the failing tests**

```dart
// extracts_editor_test.dart: se portan los casos de extract de step_card_editor_test.dart (añadir, renombrar, cambiar ruta, quitar) y:
testWidgets('marks an extract whose path is not in the last response', (t) async {
  // extract {'otp': 'response.body.otp'}, knownPaths {'response.body.id'} → find.text('not in the last response') findsOneWidget
});
// response_tree_test.dart
testWidgets('every leaf is tappable with its full path', (t) async {
  // body {'user': {'id': 'u1'}}, headers {'content-type': 'json'}, status 200
  // tap 'response-tree-value-response.body.user.id' → onValueTap recibe 'response.body.user.id'
  // también existen 'response-tree-value-response.status' y '...response.headers.content-type'
});
// step_panel_test.dart (ProviderScope con store en memoria)
testWidgets('the Step tab lists inputs with their origin, extracts, assertions and stop on failure', ...);
testWidgets('editing an extract, an assertion or stop on failure persists the step', ...);   // store.readFlows()
testWidgets('the Run tab only appears when the step has a run result', ...);
testWidgets('change request and delete update the flow and clear run results from that step', ...);
```

- [ ] **Step 2: Run tests to verify they fail** — `fvm flutter test test/ui/flows/extracts_editor_test.dart test/ui/flows/response_tree_test.dart test/ui/flows/step_panel_test.dart` → FAIL.
- [ ] **Step 3: Implement** — `step_card.dart` pasa a usar `ExtractsEditor` (sus tests siguen verdes). La pestaña Run envuelve `RunStepInspector` con `requestUrl: notifier.requestUrlFor(i, endpoint)` y `onRerunFromHere: () => notifier.rerunFrom(...)`. Ancho fijo del panel: 400.
- [ ] **Step 4: Run tests to verify they pass** — `fvm flutter test test/ui/flows` → PASS.
- [ ] **Step 5: Commit** — `feat(flows): side panel for a step with its inputs, response and run result`

---

### Task 6: Canvas y nodos (sustituye al editor vertical)

**Files:**
- Create: `lib/ui/flows/canvas/canvas_metrics.dart`, `lib/ui/flows/canvas/node_model.dart`, `lib/ui/flows/canvas/step_node.dart`, `lib/ui/flows/canvas/flow_canvas.dart`, `lib/ui/flows/canvas/flow_toolbar.dart`, `lib/ui/flows/canvas/relative_age.dart`
- Modify: `lib/ui/flows/flows_screen.dart` (se va `_FlowBuilder`; detalle = toolbar + canvas + panel), ARBs
- Delete: `lib/ui/flows/step_card.dart`, `test/ui/flows/step_card_editor_test.dart` (cubierto por Task 5), `test/ui/flows/flow_builder_screen_test.dart` → sustituido por `test/ui/flows/flow_canvas_test.dart`
- Modify: `integration_test/journeys/flow_journey.dart` (`step-card-$i` → `step-node-$i`)
- Test: `test/ui/flows/canvas/node_model_test.dart`, `test/ui/flows/canvas/relative_age_test.dart`, `test/ui/flows/flow_canvas_test.dart`

**Interfaces:**
- Consumes: Tasks 1–5.
- Produces:
  - `canvas_metrics.dart`: `nodeWidth = 240`, `nodeGap = 56`, `canvasPadding = 24`, `headerHeight = 44`, `pathHeight = 24`, `sectionLabelHeight = 24`, `rowHeight = 24`, `sectionGap = 8`, `emptyResponseHeight = 56`, `maxVisibleFields = 8`, `minZoom = 0.5`, `maxZoom = 1.5`, `zoomStep = 0.1`; `double nodeLeft(int index)`; `double nodeHeight(int inputRows, int fieldRows, {required bool hasResponse, required bool hasMore})`; `double inputRowCenterY(int row)`; `double fieldRowCenterY(int inputRows, int row)` (relativos al tope del nodo).
  - `node_model.dart`:
    ```dart
    enum InputRowKind { variable, generated, session, none }
    class InputRow { const InputRow({required this.kind, required this.label, this.origin}); final InputRowKind kind; final String label; final InputOrigin? origin; }
    class NodeModel { final int index; final Endpoint? endpoint; final List<InputRow> inputs; final StepResponse? response; final ResponseFields? fields; final Map<String, String> extract; List<ResponseField> get visibleFields; int get hiddenFieldCount; }
    NodeModel buildNodeModel({required Flow flow, required int index, required Endpoint? endpoint, required StepResponse? response, required Map<String, String> environmentVariables, required bool sessionAttachAuth});
    ```
    Orden de filas: variables (con pin), generados, fila de sesión; sin ninguna → una fila `none` (`canvasNoInputs`).
  - `String relativeAge(BuildContext context, DateTime at, {DateTime? now})` — `< 1 min` → `ageJustNow`; `< 60 min` → `ageMinutes`; `< 24 h` → `ageHours`; resto `ageDays`.
  - En `flows_screen.dart`, junto a `selectedFlowIdProvider`: `final selectedStepIndexProvider = StateProvider<int?>((ref) { ref.watch(selectedFlowIdProvider); return null; });`
  - `FlowCanvas({required Flow flow, required Map<String, Endpoint> endpoints})` y `FlowToolbar({required Flow flow, required Map<String, Endpoint> endpoints})`.

- [ ] **Step 1: Write the failing tests**

```dart
// node_model_test.dart
test('orders variable rows, then generated, then the session row', ...);
test('adds the session row only when attachAuth is on and the request accepts the token', ...);
test('a step with no inputs gets one none row', ...);
test('shows at most 8 fields and counts the hidden ones', ...);
test('a missing endpoint gives no inputs and no fields', ...);
// relative_age_test.dart: 30 s → 'just now', 5 min → '5 min ago', 3 h → '3 h ago', 1 día y 3 días (en)
// flow_canvas_test.dart (store en memoria, superficie 1600x1000)
testWidgets('a 4-step flow shows 4 nodes left to right in step order', (t) async {
  // dx(step-node-0) < dx(step-node-1) < dx(step-node-2) < dx(step-node-3)
});
testWidgets('a node shows its inputs with origin labels and its response fields', ...);   // historial sembrado con body JSON
testWidgets('the response section names its source and age', ...);   // historial de hace 3 días → 'history · 3 days ago'
testWidgets('a token field is tagged 🔑 → session when captureTokens is on', ...);   // campo access_token
testWidgets('a truncated or non-JSON history response shows its message and no fields', ...);
testWidgets('a node without a response shows Not sent yet', ...);
testWidgets('pins sit where canvas_metrics says', (t) async {
  // centro de step-field-pin-1-0 == Offset(nodeLeft(1) + nodeWidth, top + fieldRowCenterY(inputs, 0)) ± 1 px (en coordenadas del canvas, zoom 1)
});
testWidgets('adding, moving left/right and deleting steps from the node menu persists the flow', ...);  // porta flow_builder_screen_test
testWidgets('a step whose request was deleted shows Request not found and can change request', ...);
testWidgets('an empty flow shows the add-first-step node', ...);
testWidgets('selecting a node opens the side panel and closing it clears the selection', ...);
testWidgets('zoom buttons change the level between 50% and 150%, and Fit fits the row', ...);
testWidgets('the disabled Save button is gone', (t) async { expect(find.text('Save Flow'), findsNothing); });
```

- [ ] **Step 2: Run tests to verify they fail** — `fvm flutter test test/ui/flows/canvas test/ui/flows/flow_canvas_test.dart` → FAIL.
- [ ] **Step 3: Implement**
  - El nodo pinta cada sección con las alturas exactas de `canvas_metrics` (filas de altura fija, una línea con elipsis) para que la geometría sea calculable sin medir.
  - Zoom sin paneo libre (evita conflictos con el arrastre de Task 8): `Scrollbar` + scroll en ambos ejes sobre un `SizedBox(size × zoom)` que contiene `FittedBox(fit: BoxFit.fill)` del contenido a tamaño 1:1; Ctrl+rueda (`Listener.onPointerSignal` con `HardwareKeyboard.instance.isControlPressed`) cambia el zoom en `zoomStep`. "Ajustar" = `clamp(anchoVisible / anchoContenido, minZoom, maxZoom)`.
  - Mover/eliminar/cambiar petición llaman a `FlowsNotifier` y luego a `flowRunProvider(flow.id).notifier.clearFrom(primerÍndiceAfectado)`.
  - El botón Run de la toolbar sigue abriendo `FlowRunViewScreen` en esta tarea (se cambia en Task 7).
  - Quitar claves ARB sin uso (`flowsSave`, `stepPayloadTemplate`, `stepTerminal`, `stepMissingEndpoint` si ya nadie las usa).
- [ ] **Step 4: Run tests to verify they pass** — `fvm flutter test` completo y `fvm flutter test test/integration` → PASS.
- [ ] **Step 5: Commit** — `feat(flows): ordered canvas of step nodes replaces the vertical builder`

---

### Task 7: Ejecutar en el canvas

**Files:**
- Modify: `lib/ui/flows/canvas/flow_toolbar.dart`, `lib/ui/flows/canvas/step_node.dart`, `lib/ui/flows/canvas/flow_canvas.dart`, `lib/ui/flows/flows_screen.dart`, ARBs
- Delete: `lib/ui/flows/flow_run_view_screen.dart`, `lib/ui/flows/run_step_card.dart` (si `grep` confirma que nada más lo usa), `test/ui/flows/flow_run_view_test.dart`, `test/ui/flows/flow_run_view_detail_test.dart`, `test/ui/flows/flow_run_view_restyle_test.dart` → sustituidos por `test/ui/flows/canvas_run_test.dart`
- Modify: `test/ui/session/session_integration_test.dart` (deja de usar `FlowRunViewScreen`), `integration_test/journeys/flow_journey.dart`, `integration_test/support/journey_harness.dart` (`runOpenFlow` espera a que termine la ejecución en el canvas)
- Test: `test/ui/flows/canvas_run_test.dart`

**Interfaces:**
- Consumes: `FlowRunNotifier` (Task 4), `StepPanel(initialTab: StepPanelTab.run)` (Task 5), `selectedStepIndexProvider` (Task 6).

- [ ] **Step 1: Write the failing tests** (`canvas_run_test.dart`, executor mock como en `flow_run_view_test.dart`)

```dart
testWidgets('Run paints each node status and the summary strip', (t) async {
  // 3 pasos OK → find.text('3 passed'), '0 failed', '0 skipped'; step-node-status-0..2 con 200; run-summary-total
});
testWidgets('a failing step with stop on failure skips the rest and opens its error in the panel', ...);
testWidgets('stop on failure off keeps running after a failure', ...);
testWidgets('node fields update from the run response', ...);   // historial con {old:1}, ejecución devuelve {fresh:1} → aparece 'fresh'
testWidgets('Run up to here sends only the pending steps up to that node', ...);   // run-until-1 tras éxito en 0 → 1 llamada
testWidgets('Run again from here re-sends from that step to the end', ...);
testWidgets('the Run tab shows the request sent with the resolved url', ...);       // porta flow_run_view_detail_test
testWidgets('editing is locked while running', ...);                                  // run-flow-button y step-node-menu-* deshabilitados
testWidgets('running never adds history entries', ...);
```

`session_integration_test.dart`: el mismo caso de hoy (el token del login llega como `Authorization` a los pasos siguientes) disparado desde `run-flow-button` en `FlowsScreen`.

- [ ] **Step 2: Run tests to verify they fail** — `fvm flutter test test/ui/flows/canvas_run_test.dart test/ui/session/session_integration_test.dart` → FAIL.
- [ ] **Step 3: Implement** — el botón Run llama a `runAll`; al terminar, `selectedStepIndexProvider` = `focusIndex` y el panel abre en `StepPanelTab.run`. Estado del nodo: spinner mientras su resultado es `null` y `running`; `StatusBadge` con el status; `runSkippedStep` para omitidos; `canvasNotRun` sin resultado ni respuesta. "Ejecutar hasta aquí" en el menú del nodo y en el recuadro "Aún no se ha enviado"; "Volver a ejecutar desde aquí" solo si hay resultados. En el journey se quitan los taps a `run-view-back-button` / `re-run-flow-button` y se conservan todas sus aserciones.
- [ ] **Step 4: Run tests to verify they pass** — `fvm flutter test` y `fvm flutter test test/integration` → PASS.
- [ ] **Step 5: Commit** — `feat(flows): run a flow on the canvas and drop the separate run screen`

---

### Task 8: Cables y arrastrar para conectar

**Files:**
- Create: `lib/engine/flows/flow_wiring.dart`, `lib/ui/flows/canvas/wire_geometry.dart`, `lib/ui/flows/canvas/wire_painter.dart`
- Modify: `lib/ui/flows/canvas/step_node.dart` (pins `Draggable`, entradas `DragTarget`, menú de origen), `lib/ui/flows/canvas/flow_canvas.dart` (capa de cables, cable fantasma), ARBs
- Test: `test/engine/flows/flow_wiring_test.dart`, `test/ui/flows/canvas/wire_geometry_test.dart`, `test/ui/flows/canvas_wiring_test.dart`

**Interfaces:**
- Consumes: `resolveInputOrigin` (Task 3), `NodeModel`, `canvas_metrics` (Task 6).
- Produces:
  - `flow_wiring.dart`:
    ```dart
    sealed class ConnectResult {}
    final class Connected extends ConnectResult { Connected(this.step); final FlowStep step; }        // paso origen actualizado
    final class Shadowed extends ConnectResult { Shadowed(this.stepIndex); final int stepIndex; }   // paso intermedio que sobrescribe
    ConnectResult connectField(Flow flow, {required int fromStep, required String path, required int toStep, required String variable});
    FlowStep disconnectVariable(Flow flow, {required int fromStep, required String variable});
    int consumersOf(Flow flow, Map<String, Endpoint> endpoints, Map<String, String> environmentVariables, {required int fromStep, required String variable});
    ```
  - `wire_geometry.dart`:
    ```dart
    class Wire { const Wire({required this.fromStep, required this.toStep, required this.variable, required this.from, required this.to, this.suggestion = false}); ... }
    Offset inputPinOffset(NodeModel node, int row);
    Offset fieldPinOffset(NodeModel node, int fieldRow);
    Offset headerAnchor(NodeModel node);            // borde derecho de la cabecera
    List<Wire> computeWires(List<NodeModel> nodes); // sugerencias: Task 9
    ```
  - `class FieldDrag { const FieldDrag(this.stepIndex, this.path); }`

- [ ] **Step 1: Write the failing tests**

```dart
// flow_wiring_test.dart
test('connectField sets the extract on the source step, replacing another path', ...);
test('connectField is Shadowed when a step in between extracts the same name', () {
  expect(connectField(flow, fromStep: 0, path: 'response.body.id', toStep: 3, variable: 'user_id'), isA<Shadowed>().having((s) => s.stepIndex, 'step', 1));
});
test('disconnectVariable removes only that extract', ...);
test('consumersOf counts later steps whose origin is that step', ...);
// wire_geometry_test.dart
test('a wire goes from the field pin to the input pin', ...);
test('an extract whose path is not a visible field starts at the header anchor', () {
  // extract {'status_code': 'response.status'} y {'n': ruta del campo nº 12} → from == headerAnchor(node0)
});
test('inputs fed by env, session or generated values have no wire', ...);
// canvas_wiring_test.dart
testWidgets('dragging a field pin onto a later input saves the extract and draws the wire', (t) async {
  // drag step-field-pin-1-<user.id> → step-input-2-user_id; store: steps[1].extract == {'user_id': 'response.body.user.id'}; wire-1-2-user_id existe
});
testWidgets('only inputs of later steps highlight as targets; dropping backwards does nothing', ...);
testWidgets('a shadowed drop is refused with a message and nothing changes', ...);
testWidgets('disconnect from the input origin label removes the extract and says how many steps use it', ...);
```

- [ ] **Step 2: Run tests to verify they fail** — `fvm flutter test test/engine/flows/flow_wiring_test.dart test/ui/flows/canvas/wire_geometry_test.dart test/ui/flows/canvas_wiring_test.dart` → FAIL.
- [ ] **Step 3: Implement** — cables con `CustomPainter` en la misma capa transformada que los nodos (Bézier horizontal, `AppColors.primary`, 1.6 px). Cable fantasma: `Draggable.onDragUpdate` → posición global → `globalToLocal` del contenido del canvas → repintado. Rechazo por `Shadowed` con `toastProvider` y `wireShadowed`. Cada gesto persiste con `FlowsNotifier.updateStep`.
- [ ] **Step 4: Run tests to verify they pass** — `fvm flutter test` → PASS.
- [ ] **Step 5: Commit** — `feat(flows): connect a response field to a later step by dragging`

---

### Task 9: Menú de campo y sugerencias

**Files:**
- Create: `lib/ui/flows/canvas/field_menu.dart`
- Modify: `lib/ui/flows/canvas/step_node.dart`, `lib/ui/flows/canvas/step_panel.dart` (`onFieldTap` del `ResponseTree`), `lib/ui/flows/canvas/wire_geometry.dart` (`computeWires` añade sugerencias), `lib/ui/flows/canvas/flow_canvas.dart` (chips de sugerencia), ARBs
- Test: `test/ui/flows/canvas_field_menu_test.dart`, `test/ui/flows/canvas/wire_geometry_test.dart`

**Interfaces:**
- Consumes: `suggestVariableName`, `suggestConnection`, `isValidVariableName` (Task 3); `connectField` (Task 8).
- Produces: `Future<void> showFieldMenu(BuildContext context, WidgetRef ref, {required Flow flow, required int stepIndex, required String path, required Offset position})`.

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('Use as variable proposes the suggested name and saves the extract', (t) async {
  // tap step-field-1-<user.id> → field-menu-use-as-variable → variable-name-field contiene 'user_id' → variable-name-confirm
  // store: steps[1].extract['user_id'] == 'response.body.user.id'
});
testWidgets('an invalid name disables confirm and explains why', (t) async {
  for (final name in ['', 'user id', 'user-id']) { /* enterText → confirm deshabilitado; find.text('Use only letters, numbers and _') */ }
});
testWidgets('Add assertion appends an exists assertion and opens the panel on the step', ...);
testWidgets('Copy path puts the full path on the clipboard', ...);   // 'response.body.user.id'
testWidgets('tapping a value in the panel response tree opens the same menu', ...);
testWidgets('a missing input with a matching field shows a suggestion that connects on tap', (t) async {
  // Home usa {{region}}, Get user devuelve data.region → suggestion-3-region; tap → steps[2].extract['region'] == 'response.body.data.region'
});
// wire_geometry_test.dart
test('computeWires adds one dashed suggestion per missing input, from the nearest match', ...);
```

- [ ] **Step 2: Run tests to verify they fail** — `fvm flutter test test/ui/flows/canvas_field_menu_test.dart test/ui/flows/canvas/wire_geometry_test.dart` → FAIL.
- [ ] **Step 3: Implement** — sugerencias punteadas con el color de advertencia del tema y chip `suggestionConnect` en el punto medio del cable; aceptar llama a `connectField` y, si es `Shadowed`, muestra el mismo mensaje que Task 8. "Add assertion" = `Assertion(field: path, operator: AssertionOperator.exists)`.
- [ ] **Step 4: Run tests to verify they pass** — `fvm flutter test` → PASS.
- [ ] **Step 5: Commit** — `feat(flows): field menu and name-based connection suggestions`

---

### Task 10: Cierre: lista plegable, journey de conexión y documentación

**Files:**
- Modify: `lib/ui/flows/flows_screen.dart`, `lib/ui/shared/list_detail_layout.dart` (opción de plegar la lista), ARBs, `README.md` (párrafo de Flows), `integration_test/journeys/flow_journey.dart`, `tasks/flow-canvas/todo.md`
- Test: `test/ui/flows/flow_canvas_test.dart`, `integration_test/journeys/flow_journey.dart`

- [ ] **Step 1: Write the failing tests**

```dart
testWidgets('the flow list folds away and comes back', ...);   // toggle-flow-list oculta list-detail-list-panel y lo vuelve a mostrar
// flow_journey.dart
journeyTest('connecting a field by dragging sends the extracted value', (tester) async {
  // flujo login → get user ('/users/{{user_id}}'); ejecutar login; arrastrar user.id a {{user_id}}; ejecutar
  // expect(app.backend.calls.last.uri.path, '/users/<id del login>');
});
```

- [ ] **Step 2: Run tests to verify they fail** — `fvm flutter test test/ui/flows/flow_canvas_test.dart test/integration` → FAIL.
- [ ] **Step 3: Implement** — `ListDetailLayout` gana `bool listVisible = true` (por defecto igual que hoy, Environments no cambia). README: la viñeta de **Flows** describe el canvas (entradas con origen, campos de la respuesta, arrastrar para conectar, ejecutar en el mismo lugar).
- [ ] **Step 4: Verify everything**

Run: `fvm flutter analyze` → `No issues found!`
Run: `fvm flutter test` → todos en verde.
Run: `fvm flutter test test/integration` → verde.
Run: `fvm flutter build web --release --base-href /api_flow_studio/` → compila.
Run: `fvm dart run bin/api_flow_runner.dart --help` → sin cambios de comportamiento (el runner no se tocó).

- [ ] **Step 5: Commit** — `feat(flows): foldable flow list, drag-to-connect journey and docs`
