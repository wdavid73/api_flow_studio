# Todo: openapi-import

Plan: [plan.md](plan.md) · Spec: [SPEC-openapi-import.md](../../SPEC-openapi-import.md)

- [x] **O1: preparación — lectores y saneado compartidos, `yaml` declarada**
  - Acceptance: `import_json.dart` movido (Postman sin cambios); `asMap` no lanza con claves enteras; `VariableNames` extraído con tests; `yaml` en `pubspec.yaml`
  - Verify: `fvm flutter pub get && fvm flutter test test/engine/import`
  - Files: `lib/engine/import/import_json.dart`, `lib/engine/import/variable_names.dart`, `lib/engine/import/postman/*`, `pubspec.yaml`, `pubspec.lock`, tests

- [x] **O2: reconocer y leer JSON y YAML**
  - Acceptance: `matches` (JSON, sniff de YAML, Swagger); YAML válido/ inválido; Swagger → mensaje; alias anidados acotados; sin registrar
  - Verify: `fvm flutter test test/engine/import/openapi`
  - Files: `lib/engine/import/openapi/openapi_importer.dart`, `test/engine/import/openapi/openapi_recognition_test.dart`

- [ ] **O3: referencias `$ref`**
  - Acceptance: locales, anidadas, `~0/~1/%`, ciclos, inexistentes y externas avisadas sin leer nada
  - Verify: `fvm flutter test test/engine/import/openapi`
  - Files: `lib/engine/import/openapi/openapi_refs.dart`, `test/engine/import/openapi/openapi_refs_test.dart`

- [ ] **O4: muestras de esquemas**
  - Acceptance: todas las ramas; `readOnly` omitido; 3.1 con `null`; ciclo y tamaño acotados con aviso
  - Verify: `fvm flutter test test/engine/import/openapi`
  - Files: `lib/engine/import/openapi/openapi_schema.dart`, `test/engine/import/openapi/openapi_schema_test.dart`

- [ ] **O5: operaciones — estructura, URL, servidor y parámetros**
  - Acceptance: carpeta raíz y tags en orden; primer tag; `{{base_url}}`/`{{param}}`; servidor con variables, relativo, ausente, otros; parámetros path/query/header, cookie y objeto avisados; herencia ruta→operación
  - Verify: `fvm flutter test test/engine/import/openapi`
  - Files: `lib/engine/import/openapi/openapi_operation.dart`, `openapi_importer.dart`, `test/engine/import/openapi/openapi_operation_test.dart`

- [ ] **O6: cuerpos**
  - Acceptance: preferencia de tipo; JSON (`example`/`examples`/muestra, `+json`); urlencoded; multipart con archivo por elegir; texto/XML con Content-Type; binario avisado
  - Verify: `fvm flutter test test/engine/import/openapi`
  - Files: `lib/engine/import/openapi/openapi_body.dart`, `test/engine/import/openapi/openapi_body_test.dart`

- [ ] **Checkpoint 1:** `fvm flutter analyze` sin avisos y `fvm flutter test` completo en verde

- [ ] **O7: seguridad**
  - Acceptance: efectiva por operación; bearer/basic/apiKey; no soportados una vez por esquema; conflicto; variables secretas vacías
  - Verify: `fvm flutter test test/engine/import/openapi`
  - Files: `lib/engine/import/openapi/openapi_security.dart`, `test/engine/import/openapi/openapi_security_test.dart`

- [ ] **O8: el importador completo y el registro**
  - Acceptance: fixtures JSON 3.0 y YAML 3.1 con las cifras esperadas; registro real elige entre los cuatro formatos; `applyImport` sin activar y `valuesToFill` suma; externas sin leer; hostil acotado
  - Verify: `fvm flutter test test/engine/import test/ui/import`
  - Files: `lib/engine/import/openapi/openapi_importer.dart`, `lib/engine/import/import_registry.dart`, `test/engine/import/openapi/`, `test/ui/import/`

- [ ] **O9: UI, journey y README**
  - Acceptance: widget test con avisos; journey con YAML embebido; README con formatos y límites; criterios marcados
  - Verify: `fvm flutter test && fvm flutter analyze`
  - Files: `test/ui/import/import_file_test.dart`, `integration_test/journeys/import_journey.dart`, `README.md`, `SPEC-openapi-import.md`

- [ ] **Checkpoint final:** `analyze` + suite completa + `test/integration` en verde; revisión humana
