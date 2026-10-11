# Spec: flow-assertions

Módulo 2 del mapa "Flows de testing" (`generated-variables` → `flow-assertions`).
[`generated-variables`](SPEC-generated-variables.md) ya está implementado; este
módulo no depende de él para funcionar, solo se combina bien con él.

## Objective

Hoy cada paso de un flujo admite **una** comprobación de igualdad
(`assertField == assertExpected`) y nada más. Eso obliga a escribir "status es
200" y no se puede comprobar a la vez que un campo existe, que un texto contiene
algo o que la respuesta fue rápida. Este módulo convierte esa comprobación en
una **lista de assertions con operadores** para que un flujo sirva como test de
API real.

**Usuario:** el desarrollador dueño de la app.

**Éxito:** en un paso se pueden añadir varias assertions
(`response.status == 201`, `response.body.data.id existe`,
`response.body.email contiene @`, `response.elapsedMs < 800`); al correr el
flujo se ve cuál pasó y cuál falló y por qué; los flujos y workspaces ya
guardados siguen funcionando sin que el usuario haga nada.

## ASSUMPTIONS (corregir ahora o procedo con estas)

1. Una assertion es `campo + operador + valor esperado`. El campo es una ruta
   con punto que empieza por `response` (igual que `extract`).
2. Operadores v1: `==`, `!=`, `contains`, `not contains`, `exists`,
   `not exists`, `matches` (regex) , `>`, `<`. Sin `>=`/`<=` ni operadores
   sobre arreglos más allá de `contains`.
3. **Se evalúan todas las assertions del paso** (no se corta en la primera
   falla) para poder mostrar todo lo que falló. El paso falla si falla
   cualquiera.
4. `stopOnFailure` no cambia: sigue siendo por paso. No hay assertions "no
   bloqueantes" en v1 (ver Open Questions).
5. El valor esperado admite `{{variables}}` del pool del flujo (incluidas las
   extraídas por ese mismo paso). **No** admite tokens `{{$uuid}}`: generar un
   valor aleatorio para compararlo no tiene sentido.
6. Sin dependencias nuevas (`RegExp` es de `dart:core`).
7. El modelo guarda las assertions en una lista nueva, `FlowStep.assertions`. Los
   campos viejos `assertField` / `assertExpected` **desaparecen** del modelo y
   se migran al leer (ver Migración).

## Modelo

```dart
enum AssertionOperator { equals, notEquals, contains, notContains, exists, notExists, matches, greaterThan, lessThan }

@freezed
class Assertion with _$Assertion {
  const factory Assertion({
    required String field,            // 'response.status', 'response.body.data.id'
    @Default(AssertionOperator.equals) AssertionOperator operator,
    @Default('') String expected,     // ignorado por exists / notExists
  }) = _Assertion;
}

// FlowStep: + @Default([]) List<Assertion> assertions
// - assertField, - assertExpected
```

Campos disponibles bajo `response` (el runner arma el mapa): `status`, `headers`,
`body`, y **nuevos** `elapsedMs` y `sizeBytes`, para poder afirmar tiempo y
tamaño (`response.elapsedMs < 800`). Añadir esas dos claves no cambia nada de lo
que ya existe; también pasan a estar disponibles para `extract`.

### Resultado

`FlowStepResult` gana `assertionResults` (en memoria, no se persiste):

```dart
class AssertionResult { Assertion assertion; bool passed; String? actual; String? message; }
```

`failureReason` se conserva (lo usa `classifyFailure`) y su primera línea sigue
empezando por `Assertion failed`; si fallan varias, una línea por assertion.

## Semántica de los operadores

El valor "actual" es `extractValueAsString` de la ruta (cadena para strings;
`toString()` para número/bool; JSON para objetos y listas; `null` si falta).
Cada comparación de texto es **exacta y sensible a mayúsculas**.

| Operador | Pasa cuando | Con valor ausente (`null`) |
|---|---|---|
| `==` | actual == esperado | falla ("got null") |
| `!=` | actual != esperado | **pasa** |
| `contains` | actual contiene esperado | falla |
| `not contains` | actual no contiene esperado | **pasa** |
| `exists` | el valor existe (no `null`) | falla |
| `not exists` | el valor no existe | **pasa** |
| `matches` | `RegExp(esperado).hasMatch(actual)` | falla |
| `>` / `<` | ambos numéricos (`num.tryParse`) y el orden se cumple | falla |

Casos límite definidos (ninguno lanza excepción):
- Ruta que no empieza por `response` → falla con `Invalid field path "<ruta>"`
  (hoy `extractValue` lanza `ArgumentError` y rompería la corrida).
- Regex inválida → falla con `Invalid regex "<patrón>"`.
- `>`/`<` con un lado no numérico → falla con
  `"<valor>" is not a number`.
- `field` vacío o solo espacios → la assertion se ignora al correr (se
  considera sin configurar, igual que hoy un par vacío). La UI conserva la fila
  mientras se edita, y por eso también se guarda en el flujo, pero nunca se evalúa.
- `expected` vacío con `==` es válido (compara con cadena vacía); un valor
  ausente sigue fallando porque `null != ''`.

Mensajes (primera línea, compatibles con el formato actual):
`Assertion failed: expected response.status == "200", got "404"`.

## Migración y compatibilidad

- **Al leer** (`FlowStep.fromJson`): si el JSON trae `assertField` y
  `assertExpected` no vacíos y no trae `assertions`, se crea
  `[Assertion(field, equals, expected)]`. Si trae solo uno de los dos, no se crea
  nada (hoy esa assertion no se evaluaba). Si trae `assertions`, los campos viejos
  se ignoran. `toJson` ya no escribe los viejos.
- **`flows.json` existente** se lee sin pasos manuales y se reescribe en el
  formato nuevo la próxima vez que se guarde el flujo.
- **Workspace export/import:** `workspaceFormatVersion` pasa de 1 a **2** (un
  archivo con assertions nuevas no debe abrirse "en silencio" en una versión
  anterior que las perdería). La versión actual lee 1 y 2 (migración al
  importar) y rechaza ≥3 como "newer version". Un archivo v1 con
  `assertField/assertExpected` se importa con sus assertions migradas.
- Una versión **anterior** de la app que lea un `flows.json` nuevo ignorará
  `assertions` sin avisar: es una limitación aceptada para el uso de una sola
  máquina; se documenta en el README.

## UI

### Editor del paso (`step_card.dart`)
- Se sustituyen los dos campos "Assert field / Expected value" por una lista de
  filas, cada una: campo (mono, hint `response.status`) · selector de operador ·
  valor esperado (oculto para `exists` / `not exists`) · botón quitar.
- Botón `Add assertion`. Un paso nuevo no trae ninguna.
- Atajo: al crear la primera assertion se propone `response.status == 200`
  (campo y valor rellenados, editables).
- Teclas (para tests): `assertion-field-$step-$i`, `assertion-operator-$step-$i`,
  `assertion-expected-$step-$i`, `remove-assertion-$step-$i`,
  `add-assertion-$step`.
- Estilo: mismos widgets, espaciados y tokens que las filas de `extract`.

### Vista de ejecución
- `ErrorDetailPanel` sigue mostrando la clasificación "Assertion Failure" y, en
  vez de un único texto, una línea por assertion fallida.
- El inspector añade una pestaña **Assertions** (solo si el paso las tiene),
  con ✓/✗ por assertion, el operador, el valor esperado y el actual. Se muestra
  también en pasos exitosos, para ver qué se comprobó.
- `RunStepCard` muestra un resumen `2/3 assertions` cuando el paso tiene alguna.
- Los textos de UI van en inglés, como el resto de la app.

## Commands

```bash
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs   # cambia FlowStep, nuevo Assertion
fvm flutter test test/engine/models test/engine/flows test/engine/workspace
fvm flutter test test/ui/flows
fvm flutter test                       # suite completa
fvm flutter test test/integration      # journeys sin ventana
fvm flutter analyze
# NO ejecutar `dart format` sobre archivos existentes: el repo no usa el estilo nuevo.
```

## Project Structure

```
lib/engine/models/assertion.dart          # NUEVO: Assertion + AssertionOperator (freezed)
lib/engine/models/flow_step.dart          # + assertions, - assertField/assertExpected, fromJson migra
lib/engine/models/models.dart             # export assertion.dart
lib/engine/flows/assertion_evaluator.dart # NUEVO: evaluate(assertion, responseMap, variables) → AssertionResult (puro)
lib/engine/flows/flow_runner.dart         # usa el evaluador; añade elapsedMs/sizeBytes al mapa
lib/engine/flows/flow_step_result.dart    # + assertionResults, AssertionResult
lib/engine/workspace/workspace_file.dart  # workspaceFormatVersion = 2, acepta 1 y 2
lib/ui/flows/step_card.dart               # editor de assertions
lib/ui/flows/assertions_tab.dart          # NUEVO: pestaña del inspector
lib/ui/flows/run_step_inspector.dart      # pestaña Assertions
lib/ui/flows/error_detail_panel.dart      # una línea por assertion fallida
lib/ui/flows/run_step_card.dart           # resumen n/m
test/engine/flows/assertion_evaluator_test.dart  # NUEVO
test/engine/models/flow_step_test.dart           # migración
test/engine/workspace/workspace_file_test.dart   # v1/v2/v3
test/ui/flows/                                   # editor + inspector
integration_test/journeys/flow_journey.dart      # journey
```

`assertion.dart` y el evaluador no importan `package:flutter` (regla de
`engine/`).

## Code Style

Funciones puras, un `switch` exhaustivo por operador, mensajes en inglés:

```dart
/// Evaluates [assertion] against [response] ({status, headers, body, ...}).
/// Never throws: an invalid path or regex is reported as a failed result.
AssertionResult evaluateAssertion(
  Assertion assertion,
  Map<String, dynamic> response,
  Map<String, String> variables,
) {
  final path = assertion.field.trim();
  if (path != 'response' && !path.startsWith('response.')) {
    return AssertionResult.failed(assertion, message: 'Invalid field path "$path"');
  }
  final actual = extractValueAsString(response, path);
  final expected = interpolate(assertion.expected, variables);
  return switch (assertion.operator) {
    AssertionOperator.exists => _result(assertion, actual != null, actual),
    AssertionOperator.equals => _result(assertion, actual == expected, actual, expected: expected),
    // ...
  };
}
```

Convenciones del repo: comentarios `///` con el porqué, sin `package:flutter` en
`engine/`, `Key`s con índice para tests, estilo de línea largo existente (no
reformatear archivos ajenos).

## Testing Strategy

- **Unit del evaluador (`flutter_test`, sin mocks):** cada operador con caso
  que pasa, que falla y con valor ausente; ruta inválida; regex inválida;
  `>`/`<` con texto y con números decimales/negativos; `expected` con
  `{{variable}}`; `exists` ignora `expected`; assertion con campo vacío se
  ignora; `elapsedMs`/`sizeBytes` accesibles.
- **Modelo:** round-trip JSON de `Assertion` y `FlowStep`; migración
  (ambos campos viejos → una `equals`; solo uno → ninguna; `assertions` presente
  → viejos ignorados; JSON sin nada → lista vacía); `toJson` no escribe los
  viejos.
- **FlowRunner:** varias assertions → se evalúan todas y `failureReason` las
  lista; `stopOnFailure` con y sin assertions; `assertionResults` poblados; una
  ruta inválida **no** lanza; la suite existente de `flow_runner_test.dart` se
  **actualiza mecánicamente** (`assertField/assertExpected` →
  `assertions: [Assertion(field:…, expected:…)]`), sin cambiar lo que comprueba.
- **Workspace:** export escribe `version: 2`; import de v1 con assertion vieja la
  migra; v3 → `newerVersion`; el test existente que usa `version: 2` como
  "futuro" pasa a `3`.
- **Widget:** añadir, cambiar de operador (oculta el esperado con `exists`),
  quitar y persistir assertions; pestaña Assertions con ✓/✗; resumen `n/m`;
  `ErrorDetailPanel` con varias líneas.
- **Integración (`test/integration` + `integration_test/`):** un flujo con tres
  assertions, una de ellas falla → se ve "Assertion Failure", la pestaña
  Assertions marca ✓✓✗ y el paso queda en failure; un flujo con la assertion
  vieja guardada en `flows.json` se carga y sigue funcionando.
- Cobertura: toda rama del evaluador y de la migración. El resto de la suite debe
  seguir en verde.

## Boundaries

- **Always:** TDD (test rojo primero); `fvm flutter analyze` y la suite completa
  antes de cada commit; el evaluador nunca lanza; `engine/` sin imports de
  Flutter; commits por tarea, solo con los archivos de la tarea.
- **Ask first:** cambiar `workspaceFormatVersion` (propuesto aquí; confirmar);
  añadir operadores fuera de la lista; assertions no bloqueantes; añadir una
  dependencia; evaluar con JSONPath/filtros en vez de la ruta con punto.
- **Never:** dejar que una ruta o regex inválida rompa una corrida; borrar o
  debilitar tests existentes para que pasen (solo la actualización mecánica de
  `assertField` descrita arriba); reescribir `flows.json` del usuario fuera del
  guardado normal de un flujo; reformatear archivos que no se tocan.

## Success Criteria

1. Un paso puede tener 0..n assertions; cada una con campo, operador y esperado.
2. Los 9 operadores se comportan como la tabla, incluido el valor ausente.
3. `response.elapsedMs` y `response.sizeBytes` se pueden afirmar y extraer.
4. Se evalúan todas las assertions; el paso falla si falla cualquiera; el
   mensaje enumera todas las fallidas y empieza por `Assertion failed`.
5. Una ruta que no empieza por `response` o una regex inválida produce un fallo
   legible, no una excepción.
6. Un `flows.json` con `assertField/assertExpected` se abre y se ejecuta igual
   que antes; un par incompleto sigue sin evaluarse.
7. Un workspace v1 se importa con sus assertions migradas; se exporta como v2; un
   v3 se rechaza con el mensaje de "newer version".
8. El editor permite añadir/quitar/cambiar operador y persiste; `exists`/`not
   exists` ocultan el valor esperado.
9. La vista de ejecución muestra ✓/✗ por assertion y el resumen `n/m`.
10. `fvm flutter analyze` sin avisos y `fvm flutter test` en verde (con las
    actualizaciones mecánicas indicadas).

## Open Questions

1. **¿Subir `workspaceFormatVersion` a 2?** Lo propongo porque evita que una
   versión vieja importe un workspace y pierda assertions sin decirlo; el costo
   es tocar un test de `workspace_file_test.dart`. La alternativa es mantener
   `1` y aceptar la pérdida silenciosa.
2. **¿Assertions no bloqueantes** (marcan el paso en amarillo pero no cortan el
   flujo)? Lo dejé fuera de v1: es un tercer estado de paso
   (`success`/`failure`/`skipped` + `warning`) que toca runner, tarjetas y
   resumen del flujo. Si lo quieres, sería un módulo aparte.
3. **¿Quitar `assertField/assertExpected` del modelo** (propuesto) o dejarlos
   como getters de compatibilidad? Quitarlos fuerza actualizar ~7 archivos de
   tests una vez y evita dos fuentes de verdad.
4. **`extract` con ruta inválida** también lanza `ArgumentError` hoy. Está fuera
   de este módulo, pero es el mismo defecto; ¿lo corregimos aquí o lo anoto como
   tarea aparte?
5. **¿`>=`/`<=` y comparación sin distinguir mayúsculas** para `contains`/`==`?
   Lo dejé fuera para mantener la lista corta.
