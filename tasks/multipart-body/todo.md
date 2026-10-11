# Todo: multipart-body

Plan: [plan.md](plan.md) · Spec: [SPEC-multipart-body.md](../../SPEC-multipart-body.md)

- [ ] **M1: enviar un cuerpo multipart (engine)**
  - Acceptance: modelo + JSON; `FormData` con texto/archivo en orden; MIME inferido o explícito; deshabilitados/sin nombre ignorados; `Content-Type` manual descartado; errores previos al envío sin llamar a dio; interpolación en nombre, texto, ruta y tipo; `buildCurl` con `--form-string`/`-F`; ramas mínimas en UI y FakeBackend
  - Verify: `fvm dart run build_runner build --delete-conflicting-outputs && fvm flutter test test/engine test/ui/request_builder test/ui/flows`
  - Files: `lib/engine/models/multipart_field.dart`, `request_body.dart`, `models.dart`, `lib/engine/http/mime_types.dart`, `request_executor.dart`, `lib/engine/variables/interpolator.dart`, `lib/engine/curl/curl_builder.dart`, `lib/ui/request_builder/tabs/body_tab.dart`, `lib/ui/flows/step_card.dart`, `integration_test/support/fake_backend.dart`, tests

- [ ] **Checkpoint 1:** `fvm flutter analyze` sin avisos y `fvm flutter test` completo en verde

- [ ] **M2: pegar un curl con `-F`**
  - Acceptance: `-F`/`--form`/`--form-string` repetibles; `@ruta;type=`; `<ruta` como texto; implica POST; mezcla con `--data` → error; round-trip con `buildCurl`
  - Verify: `fvm flutter test test/engine/curl test/ui/collections/paste_curl_dialog_test.dart`
  - Files: `lib/engine/curl/curl_parser.dart`, `test/engine/curl/curl_parser_test.dart`, `curl_builder_test.dart`

- [ ] **M3: rutas fuera de exportaciones e importaciones; versión 3**
  - Acceptance: export y ambos imports vacían rutas; `secretsToFill` suma los archivos habilitados; mensaje `N value(s) to fill in`; versión 3 (se leen 1–3, ≥4 rechazada); `collections.json` con multipart sin pérdida
  - Verify: `fvm flutter test test/engine/workspace test/engine/storage test/ui/projects test/ui/collections`
  - Files: `lib/engine/models/file_paths.dart`, `lib/engine/workspace/export_workspace.dart`, `import_workspace.dart`, `workspace_file.dart`, `lib/ui/collections/collections_provider.dart`, `lib/ui/workspace_transfer/workspace_transfer_actions.dart`, tests

- [ ] **M4: editor Form Data y selector de archivos**
  - Acceptance: filas con id propio; Text↔File; `Choose…` con selector falso; `No file chosen`; sin texto viejo al quitar ni al cambiar de cuerpo; escribir no reconstruye; segmento Form Data en BodyTab
  - Verify: `fvm flutter test test/ui/request_builder`
  - Files: `lib/ui/request_builder/file_picker_service.dart`, `multipart_table.dart`, `tabs/body_tab.dart`, tests

- [ ] **M5: journeys, CLI de punta a punta y README**
  - Acceptance: journey (texto + archivo, importar con rutas); CLI contra `HttpServer` que lee el multipart y con archivo inexistente (código 1); README completo; criterios de la spec marcados
  - Verify: `fvm flutter test && fvm flutter analyze`
  - Files: `integration_test/journeys/`, `test/integration/`, `test/cli/end_to_end_test.dart`, `README.md`, `SPEC-multipart-body.md`

- [ ] **Checkpoint final:** `analyze` + suite completa + `test/integration` en verde; revisión humana
