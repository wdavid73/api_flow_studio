# Todo: import-core

Plan: [plan.md](plan.md) · Spec: [SPEC-import-core.md](../../SPEC-import-core.md)

- [x] **I1: el contrato y `runImport` (engine puro)**
  - Acceptance: `ImportSource` decodifica una vez; `runImport` elige por orden, mensajes de formato desconocido / vacío / workspace, `matches` que lanza = no; `uniqueName`; `ImportSummary.describe()` con plurales
  - Verify: `fvm flutter test test/engine/import`
  - Files: `lib/engine/import/import_result.dart`, `import_source.dart`, `importer.dart`, `import_naming.dart`, `test/engine/import/`

- [x] **I2: `AppCollectionsImporter` y el registro**
  - Acceptance: parsea `sample-endpoints.json`; formas válidas e inválidas; huérfanos omitidos con aviso; JSON a medias → `ImportException`; `runImport` real importa el sample y rechaza un workspace
  - Verify: `fvm flutter test test/engine/import test/sample_endpoints_test.dart`
  - Files: `lib/engine/import/app_collections_importer.dart`, `importer.dart`, `test/engine/import/app_collections_importer_test.dart`

- [x] **I3: aplicar un resultado**
  - Acceptance: raíces únicas; `addImported` sin activar; `restore` y rollback si falla la escritura de ambientes; `ImportSummary` con cifras reales y `valuesToFill`
  - Verify: `fvm flutter test test/ui/collections test/ui/environments test/ui/import`
  - Files: `lib/ui/collections/collections_provider.dart`, `lib/ui/environments/environments_provider.dart`, `lib/ui/import/import_actions.dart`, tests

- [x] **Checkpoint 1:** `fvm flutter analyze` sin avisos y `fvm flutter test` completo en verde

- [x] **I4: la UI del botón Import**
  - Acceptance: diálogo inyectable con tamaño antes del texto; toast con cifras; `import-summary-dialog` con avisos; cancelar no hace nada; workspace → pista; formato desconocido → mensaje; >32 MB sin leer; error no cambia nada
  - Verify: `fvm flutter test test/ui/import test/ui/collections`
  - Files: `lib/ui/import/import_file_dialogs.dart`, `import_actions.dart`, `import_summary_dialog.dart`, `lib/ui/collections/sidebar_tree.dart`, tests

- [x] **I5: journey y README**
  - Acceptance: importar desde el sidebar y ver carpeta y toast; dos veces → `Nombre (2)`; README con la sección "Importing"; criterios marcados
  - Verify: `fvm flutter test && fvm flutter analyze`
  - Files: `integration_test/journeys/import_journey.dart`, `integration_test/support/`, `integration_test/app_test.dart`, `test/integration/journeys_test.dart`, `README.md`, `SPEC-import-core.md`

- [x] **Checkpoint final:** `analyze` + suite completa + `test/integration` en verde; revisión humana
