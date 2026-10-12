# Todo: web-deploy

Plan: [plan.md](plan.md) · Spec: [SPEC-web-deploy.md](../../docs/SPEC-web-deploy.md)

## Corte 1 — Persistencia web

- [x] **W1: `KeyValueBackend`, `MemoryBackend`, `LocalStorageBackend`**
  - Acceptance: interfaz `read/write/remove/keysWithPrefix`; `StorageFullException`; backend de `localStorage` con prefijo `afs:` y cuota llena traducida; stub para VM; dependencia `web` en `pubspec.yaml`
  - Verify: `fvm flutter test test/engine/storage` y `fvm flutter test --platform chrome test/web`
  - Nota: `test/web/local_storage_backend_test.dart` está escrito pero no se pudo ejecutar en esta máquina (`Connection closed before test suite loaded` al abrir Chrome); el backend se verificó a mano en un navegador real (claves `afs:*` en localStorage, datos e idioma tras recargar). `flutter test` (VM) lo omite.
  - Files: `lib/engine/storage/key_value_backend.dart`, `local_storage_backend.dart`, `local_storage_backend_stub.dart`, `local_storage_backend_web.dart`, `pubspec.yaml`, tests

- [x] **W2: `JsonStore` sobre un backend**
  - Acceptance: `JsonStore.backed(backend, prefix)`; `inMemory()` usa `MemoryBackend`; JSON dañado en el backend devuelve el valor por defecto; todos los tests existentes siguen en verde
  - Verify: `fvm flutter test test/engine/storage test/engine/projects`
  - Files: `lib/engine/storage/json_store.dart`, tests

- [x] **W3: `ProjectsRepository.web`**
  - Acceptance: índice + un `JsonStore` por proyecto con prefijo propio; borrar un proyecto borra sus claves; dos proyectos no se pisan; sobrevive a "reiniciar" (nuevo repositorio sobre el mismo backend)
  - Verify: `fvm flutter test test/engine/projects`
  - Files: `lib/engine/projects/projects_repository.dart`, tests

- [x] **W4: `main.dart` persiste en web, también el idioma**
  - Acceptance: en web usa `LocalStorageBackend`; `app_settings.json` en el ámbito `afs:app:`; el escritorio no cambia
  - Verify: `fvm flutter analyze` + build web + recargar conserva proyectos e idioma (navegador)
  - Files: `lib/main.dart`

- [x] **Checkpoint 1:** `fvm flutter analyze` y `fvm flutter test` completos en verde; en el navegador, crear una request, cambiar idioma, recargar

## Corte 2 — Archivos sin rutas

- [x] **W5: abrir archivos en web (bytes)**
  - Acceptance: `FilePickerImportFileDialogs` y `FilePickerWorkspaceDialogs.openText` usan `withData` y los bytes cuando no hay ruta; sin lanzar por `.path`
  - Verify: tests con fakes + prueba manual en Chrome
  - Files: `lib/ui/import/import_file_dialogs.dart`, `lib/ui/workspace_transfer/workspace_file_dialogs.dart`, tests

- [x] **W6: exportar por descarga**
  - Acceptance: exportar workspace, endpoints y flows descarga el archivo con su nombre en web; el escritorio sigue usando el diálogo de guardado
  - Verify: tests con fakes + prueba manual en Chrome
  - Files: `lib/ui/workspace_transfer/workspace_file_dialogs.dart`, `lib/ui/collections/sidebar_tree.dart`, `lib/ui/files/*`, tests

- [x] **W7: import grande sin `Isolate`**
  - Acceptance: en web los archivos > 256 KB se traducen en el hilo principal; el escritorio mantiene el isolate
  - Verify: `fvm flutter test test/ui/import` + importar un OpenAPI grande en Chrome
  - Files: `lib/ui/import/import_actions.dart`, tests

- [x] **W8: campo File de Form Data deshabilitado en web**
  - Acceptance: el tipo *File* no se puede elegir en web; los campos *Text* funcionan; nota visible; el escritorio no cambia
  - Verify: widget test con flag de plataforma inyectado
  - Files: `lib/ui/request_builder/multipart_table.dart`, `lib/ui/platform/platform_capabilities.dart`, `.arb`, tests

- [x] **Checkpoint 2:** analyze + test en verde; importar y exportar de punta a punta en Chrome

## Corte 3 — Mensajes del navegador

- [x] **W9: pistas honestas**
  - Acceptance: pista de CORS en un error de red en web; nota en la pestaña Cookies; aviso de `http://` no local; toast de cuota llena sin perder lo guardado; textos en en/es
  - Verify: widget tests + `fvm flutter test test/ui/l10n`
  - Files: `lib/ui/response_viewer/*`, `lib/ui/shell/*`, `lib/ui/l10n`, `.arb`, tests

## Corte 4 — Despliegue

- [x] **W10: `pages.yml`**
  - Acceptance: en push a `master` y `workflow_dispatch`: analyze, test, `build web --base-href /api_flow_studio/`, subir artefacto y desplegar; permisos mínimos (`pages: write`, `id-token: write`); `concurrency` propia; `release.yml` intacto
  - Verify: revisión del YAML + primera ejecución en Actions
  - Files: `.github/workflows/pages.yml`

- [ ] **W11: README y humo en la URL**
  - Acceptance: README con URL, límites del navegador y cómo activar Pages; lista de verificación del spec ejecutada contra la URL publicada
  - Verify: lista manual del spec
  - Files: `README.md`, `docs/SPEC-web-deploy.md`

- [ ] **Checkpoint final:** criterios de éxito del spec, uno por uno

## Pendiente de quien administra el repositorio

- [ ] Settings → Pages → Source: **GitHub Actions** (sin esto el job `deploy` falla)
- [ ] Tras el primer despliegue, ejecutar la lista de verificación manual del spec contra la URL publicada
- [ ] (Opcional) Ejecutar `flutter test --platform chrome test/web` en una máquina con Chrome libre
