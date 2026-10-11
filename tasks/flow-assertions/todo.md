# Todo: flow-assertions

Plan: [plan.md](plan.md) · Spec: [SPEC-flow-assertions.md](../../SPEC-flow-assertions.md)

- [x] **A1: `Assertion`, `AssertionResult` y evaluador**
  - Acceptance: 9 operadores según la spec; ruta o regex inválida → fallo sin excepción; `>`/`<` con texto → fallo; `{{variable}}` en esperado; campo vacío = sin configurar
  - Verify: `fvm dart run build_runner build --delete-conflicting-outputs && fvm flutter test test/engine/flows/assertion_evaluator_test.dart`
  - Files: `lib/engine/models/assertion.dart`, `lib/engine/models/models.dart`, `lib/engine/flows/assertion_evaluator.dart`, `test/engine/flows/assertion_evaluator_test.dart`

- [ ] **A2: swap del modelo y runner**
  - Acceptance: `FlowStep.assertions` con migración desde `assertField/assertExpected`; runner evalúa todas, añade `elapsedMs`/`sizeBytes`, guarda `assertionResults`; editor actual sigue funcionando con adaptador; `flows.json` legado se lee migrado
  - Verify: `fvm dart run build_runner build --delete-conflicting-outputs && fvm flutter test test/engine test/ui/flows`
  - Files: `lib/engine/models/flow_step.dart`, `lib/engine/flows/flow_runner.dart`, `lib/engine/flows/flow_step_result.dart`, `lib/ui/flows/step_card.dart`, tests de `flow_step`, `flow_runner`, `json_store`, `step_card_editor`, `flow_run_view*`

- [ ] **Checkpoint 1:** `fvm flutter analyze` sin avisos y `fvm flutter test` completo en verde

- [ ] **A3: workspace format v2**
  - Acceptance: export `version: 2`; lee 1 y 2 (v1 con assertion legada se migra); ≥3 → `newerVersion`; el test de "versión futura" pasa de 2 a 3
  - Verify: `fvm flutter test test/engine/workspace`
  - Files: `lib/engine/workspace/workspace_file.dart`, `test/engine/workspace/workspace_file_test.dart`, `test/engine/workspace/*`

- [ ] **A4: editor de assertions**
  - Acceptance: filas campo/operador/esperado/quitar + `Add assertion` (propone `response.status == 200`); `exists`/`not exists` ocultan el esperado; persiste vía `onUpdateStep`
  - Verify: `fvm flutter test test/ui/flows/step_card_editor_test.dart test/ui/flows/flow_builder_screen_test.dart`
  - Files: `lib/ui/flows/step_card.dart`, `test/ui/flows/step_card_editor_test.dart`

- [ ] **A5: vista de ejecución**
  - Acceptance: panel de error con una línea por fallo; pestaña Assertions con ✓/✗; resumen `n/m` en la tarjeta; sin assertions todo igual que hoy
  - Verify: `fvm flutter test test/ui/flows`
  - Files: `lib/ui/flows/error_detail_panel.dart`, `lib/ui/flows/assertions_tab.dart`, `lib/ui/flows/run_step_inspector.dart`, `lib/ui/flows/run_step_card.dart`, `test/ui/flows/`

- [ ] **A6: journey, README y cierre**
  - Acceptance: journey con tres assertions (✓✓✗); README documenta operadores, `elapsedMs`/`sizeBytes` y migración/limitación de versiones anteriores
  - Verify: `fvm flutter test test/integration && fvm flutter analyze`
  - Files: `integration_test/journeys/flow_journey.dart`, `README.md`, `SPEC-flow-assertions.md` (criterios)

- [ ] **Checkpoint final:** `analyze` + suite completa + `test/integration` en verde; revisión humana
