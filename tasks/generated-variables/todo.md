# Todo: generated-variables

Plan: [plan.md](plan.md) · Spec: [SPEC-generated-variables.md](../../SPEC-generated-variables.md)

- [x] **G1: `DynamicValues`**
  - Acceptance: los 6 tokens con formato correcto (semilla/reloj fijos); `isKnown`/`names` expuestos; desconocido → `null`
  - Verify: `fvm flutter test test/engine/variables/dynamic_values_test.dart`
  - Files: `lib/engine/variables/dynamic_values.dart`, `test/engine/variables/dynamic_values_test.dart`

- [x] **G2: `interpolate*` con generador opcional**
  - Acceptance: un token → valor; dos apariciones → distintos; desconocido o sin generador → literal; `{{$uuid}}` dentro de un valor de variable se resuelve sin re-escanear lo generado; tests existentes sin cambios
  - Verify: `fvm flutter test test/engine/variables`
  - Files: `lib/engine/variables/interpolator.dart`, `test/engine/variables/interpolator_test.dart`

- [x] **G3: `RequestExecutor` + `ExecutedResponse.requestUrl`**
  - Acceptance: valores reales en URL, query, headers, body json/form y auth; dos envíos difieren; `requestUrl` = URL enviada (éxito y error); `curl_builder` deja el token literal
  - Verify: `fvm dart run build_runner build --delete-conflicting-outputs && fvm flutter test test/engine`
  - Files: `lib/engine/http/request_executor.dart`, `lib/engine/http/executed_response.dart` (+ `.freezed.dart`), `test/engine/http/request_executor_test.dart`, `test/engine/curl/`

- [x] **Checkpoint 1:** `fvm flutter analyze` sin avisos y `fvm flutter test` completo en verde

- [x] **G4: UI — resaltado y validación JSON**
  - Acceptance: `{{$uuid}}` cian, `{{$nope}}` ámbar, `{{var}}` igual que antes; `{"n": {{$randomInt}}}` es JSON válido y no se reformatea
  - Verify: `fvm flutter test test/ui/request_builder test/ui/theme`
  - Files: `lib/ui/theme/widgets/json_syntax.dart`, `lib/ui/request_builder/variable_highlighting_controller.dart`, `lib/ui/request_builder/json_body.dart`, tests correspondientes

- [x] **G5: inspector "Request Sent" con la URL enviada**
  - Acceptance: un paso con `{{$uuid}}` en la URL muestra la misma URL que recibió el servidor falso (no el token ni otra re-interpolación); sin respuesta, comportamiento actual
  - Verify: `fvm flutter test test/ui/flows`
  - Files: `lib/ui/flows/flow_run_view_screen.dart`, `lib/ui/flows/run_step_inspector.dart` (si hace falta), `test/ui/flows/`

- [x] **G6: ayuda, journey y docs**
  - Acceptance: la nota de sintaxis del gestor de ambientes lista los tokens; journey "dos envíos, dos correos distintos" verde; README documenta los tokens
  - Verify: `fvm flutter test test/integration`
  - Files: `lib/ui/environments/environment_manager_screen.dart`, `test/integration/`, `integration_test/`, `README.md`

- [x] **Checkpoint final:** `analyze` + suite completa + `test/integration` en verde; revisión humana
