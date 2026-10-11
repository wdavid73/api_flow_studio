# Todo: postman-import

Plan: [plan.md](plan.md) · Spec: [SPEC-postman-import.md](../../SPEC-postman-import.md)

- [ ] **P1: `valuesToFill` cuenta también los archivos sin elegir (core)**
  - Acceptance: campo de archivo habilitado suma 1, deshabilitado 0; secretos + archivos suman; el texto no cambia
  - Verify: `fvm flutter test test/ui/import test/engine/import`
  - Files: `lib/ui/import/import_actions.dart`, `test/ui/import/apply_import_test.dart`

- [ ] **P2: variables de Postman y el importador de ambientes**
  - Acceptance: `matches` correcto; `secret`, `enabled: false` avisado, nombre (globales incluidas), nombres saneados con un aviso, `{{ x }}` normalizado, dinámicas traducidas o avisadas; el registro real importa un ambiente sin activarlo
  - Verify: `fvm flutter test test/engine/import`
  - Files: `lib/engine/import/postman/postman_variables.dart`, `postman_environment_importer.dart`, `lib/engine/import/import_registry.dart`, `test/engine/import/postman/`

- [ ] **P3: un request — URL, parámetros, headers y descripción**
  - Acceptance: URL texto/objeto/sin raw, query con disabled, variables de ruta, `localhost:3000` intacto, headers, descripción, nombre por defecto, ningún tipo inesperado lanza
  - Verify: `fvm flutter test test/engine/import/postman`
  - Files: `lib/engine/import/postman/postman_request.dart`, `test/engine/import/postman/postman_request_test.dart`

- [ ] **P4: los cuerpos**
  - Acceptance: raw (JSON y otros con Content-Type solo si falta), urlencoded, formdata (archivo sin ruta con aviso), graphql, binario y deshabilitado con aviso; un `src` nunca llega al resultado
  - Verify: `fvm flutter test test/engine/import/postman`
  - Files: `lib/engine/import/postman/postman_request.dart`, `test/engine/import/postman/postman_body_test.dart`

- [ ] **P5: autenticación heredada**
  - Acceptance: bearer, basic, apikey header/query, noauth que corta la herencia, tipos no soportados con un aviso donde se define, forma de lista y de objeto
  - Verify: `fvm flutter test test/engine/import/postman`
  - Files: `lib/engine/import/postman/postman_auth.dart`, `test/engine/import/postman/postman_auth_test.dart`

- [ ] **Checkpoint 1:** `fvm flutter analyze` sin avisos y `fvm flutter test` completo en verde

- [ ] **P6: el importador de colecciones y el registro**
  - Acceptance: fixture realista con las cifras esperadas; v1 con su mensaje; scripts y ejemplos avisados; ambiente `<nombre> (imported)`; el registro real elige bien; `applyImport` no deja rutas ni activa nada
  - Verify: `fvm flutter test test/engine/import test/ui/import`
  - Files: `lib/engine/import/postman/postman_collection_importer.dart`, `lib/engine/import/import_registry.dart`, `test/engine/import/postman/`

- [ ] **P7: UI, journey y README**
  - Acceptance: un widget test con avisos Postman en el resumen; journey con carpeta, ambiente sin activar y resumen; README con formatos y límites; criterios marcados
  - Verify: `fvm flutter test && fvm flutter analyze`
  - Files: `test/ui/import/`, `integration_test/journeys/import_journey.dart`, `README.md`, `SPEC-postman-import.md`

- [ ] **Checkpoint final:** `analyze` + suite completa + `test/integration` en verde; revisión humana
