# Todo: flow-canvas

Plan: [plan.md](plan.md) · Spec: [SPEC-flow-canvas.md](../../docs/SPEC-flow-canvas.md)

- [x] **Task 1: entradas de un paso** — `stepInputs`, `acceptsSessionToken`
  - Verify: `fvm flutter test test/engine/flows/step_inputs_test.dart test/engine/session`
- [x] **Task 2: campos de la respuesta** — `responseFields`, `displayPath`, `isSessionTokenKey`
  - Verify: `fvm flutter test test/engine/flows/response_fields_test.dart test/engine/session/token_finder_test.dart`
- [x] **Task 3: orígenes, nombres y sugerencias** — `resolveInputOrigin`, `suggestVariableName`, `suggestConnection`, `isValidVariableName`
  - Verify: `fvm flutter test test/engine/flows/input_origin_test.dart test/engine/flows/variable_naming_test.dart`
- [x] **Task 4: estado de ejecución y respuesta por paso** — `runFrom(endIndex)`, `flowRunProvider`, `stepResponseProvider`
  - Verify: `fvm flutter test test/engine/flows test/ui/flows/flow_run_provider_test.dart test/ui/flows/step_response_test.dart`
- [x] **Checkpoint 1:** `fvm flutter analyze` sin avisos y `fvm flutter test` completo en verde
- [x] **Task 5: panel lateral** — `ExtractsEditor`, `ResponseTree`, `StepPanel`
  - Verify: `fvm flutter test test/ui/flows`
- [x] **Task 6: canvas y nodos** — sustituye `_FlowBuilder` y `StepCard`
  - Verify: `fvm flutter test && fvm flutter test test/integration`
- [x] **Task 7: ejecutar en el canvas** — se elimina `FlowRunViewScreen`
  - Verify: `fvm flutter test && fvm flutter test test/integration`
- [x] **Checkpoint 2:** la app funciona de punta a punta sin la pantalla de ejecución; analyze + suite completa en verde
- [x] **Task 8: cables y arrastrar para conectar** — `connectField`, `computeWires`, `WirePainter`
  - Verify: `fvm flutter test`
- [x] **Task 9: menú de campo y sugerencias** — `showFieldMenu`, sugerencias punteadas
  - Verify: `fvm flutter test`
- [x] **Task 10: cierre** — lista plegable, journey de conexión, README, build web
  - Verify: `fvm flutter analyze && fvm flutter test && fvm flutter test test/integration && fvm flutter build web --release --base-href /api_flow_studio/`
