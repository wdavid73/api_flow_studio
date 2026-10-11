# Plan: multipart-body

Spec: [SPEC-multipart-body.md](../../SPEC-multipart-body.md) · Mapa: [SPEC-import-map.md](../../SPEC-import-map.md).
Plan separado de los de los demás módulos (`tasks/<módulo>/`).

## Overview

Cinco tareas, cada una un corte vertical con su test y su commit, en este orden:
**M1** enviar un multipart (engine) → **M2** pegar un curl con `-F` → **M3** higiene de rutas
de archivo (export/import, versión 3) → **M4** editor en la pestaña Body → **M5** journeys,
CLI de punta a punta y README. La suite existente debe seguir verde en cada tarea; los únicos
tests que cambian son los que la spec dice (versión "futura" 3→4 y el mensaje de la importación).
Se aplican las respuestas por defecto de la spec: sin parseo del multipart en crudo de Chrome, sin
conversión entre tipos de cuerpo, tipo de contenido solo para archivos, nombre de archivo = nombre
base, tabla MIME propia.

## Hallazgos del código que condicionan el plan

- **Añadir una variante a la unión rompe la compilación en todos los `when`/`map` exhaustivos.**
  Los sitios son: `interpolator.dart`, `request_executor.dart`, `curl_builder.dart`,
  `body_tab.dart`, `step_card.dart` y `integration_test/support/fake_backend.dart`
  (`curl_parser.dart` solo construye, no cambia el tipo de lo que compila). Por eso **M1 toca los
  seis a la vez**, y deja la UI con una rama mínima de solo lectura (`Form Data body (N fields)`)
  que M4 sustituye por el editor.
- **`dio` 5.11 siempre sobrescribe `Content-Type` cuando `data` es `FormData`** (con el `boundary`),
  y su `MultipartFile` usa `application/octet-stream` por defecto: no infiere. De ahí la tabla MIME
  propia y el descarte explícito del `Content-Type` manual (no depende de que dio lo pise).
- **`FormData` no se puede comparar ni reutilizar:** los tests del ejecutor inspeccionan
  `formData.fields` / `formData.files` (con `MultipartFile.filename`, `.contentType`, `.length`) y el
  ejecutor lo construye de nuevo en cada `execute`.
- **El import JSON del panel lateral vive en la UI** (`_importCollections` con `FilePicker` directo,
  no inyectable) pero termina en `CollectionsNotifier.importCollections`. El vaciado de rutas se pone
  **dentro de `importCollections`** (testable con `collections_provider_test.dart` y común a cualquier
  importación futura), no en la función de UI.
- **`secretsToFill` se calcula sobre el archivo antes de importar.** Todo campo de archivo
  habilitado cuenta, porque tras importar todos quedan sin ruta.
- **Compatibilidad hacia atrás confirmada en el código:** `JsonStore._readOrDefault` ante un parseo
  fallido copia a `.corrupt-<fecha>` y devuelve el valor por defecto; una app antigua verá colecciones
  vacías, no un fallo. Se documenta en M5.
- **Tests que cambian por la spec:** `workspace_file_test.dart` (export `version` 2→3; "futuro" 3→4),
  `workspace_transfer_test.dart` ("version 3" de "newer" → 4 y el texto `1 secret value to fill in` →
  `1 value to fill in`). `import_workspace_test.dart` ("how many secrets…") se revisa.
- **No usar `dart format`** en archivos existentes.

## Dependency graph

```
M1 modelo + envío + interpolación + MIME + curl copiar ──┬─ M2 curl pegar (-F)
                                                         ├─ M3 rutas fuera de export/import + versión 3 ─┐
                                                         └─ M4 editor + selector de archivos ─────────────┴─ M5 journeys, CLI, README
```

## Tareas

Cada tarea sigue TDD (test rojo primero) y termina con `fvm flutter analyze` y la suite relevante
en verde; el commit incluye solo los archivos de la tarea.

### M1 — Enviar un cuerpo multipart (engine)
Nuevos: `multipart_field.dart`, `mime_types.dart`; `RequestBody.multipart`; interpolación; ejecutor con
`FormData` y errores previos al envío; `buildCurl` con `--form-string`/`-F`; ramas mínimas en
`body_tab.dart`, `step_card.dart` y `FakeBackend` (resume `name=valor&archivo=@nombre`).
**Aceptación:** JSON round-trip; texto y archivo en orden con nombres repetidos; `filename` = nombre
base (`/` y `\`); tipo inferido (mayúsculas, desconocida) o explícito; deshabilitados y sin nombre
ignorados; `Content-Type` manual descartado; ruta vacía / archivo inexistente / directorio / tipo
inválido → `ExecutedResponse.error` **sin llamar a dio**; `{{var}}`/`{{$token}}` en nombre, texto, ruta
y tipo; `buildCurl` (texto, archivo con y sin tipo, ruta con `;` y espacios, deshabilitado); archivo
temporal real con longitud conocida.
**Verify:** `fvm dart run build_runner build --delete-conflicting-outputs && fvm flutter test test/engine test/ui/request_builder test/ui/flows`
**Checkpoint tras M1:** `fvm flutter analyze` y `fvm flutter test` completos en verde.

### M2 — Pegar un curl con `-F`
`parseCurl`: `-F`/`--form`/`--form-string`, repetibles; `@ruta` → archivo (`;type=` → tipo,
`;filename=` ignorado); lo demás texto; `<ruta` queda como texto; implica `POST`; mezcla con
`--data` → `CurlParseException('Cannot mix --form with --data')`.
**Aceptación:** los casos de la spec y round-trip `buildCurl` → `parseCurl` (incluida una ruta con
`;` y espacios); el parseo existente de `-d`, `-u`, `-b`, etc. sin cambios.
**Verify:** `fvm flutter test test/engine/curl test/ui/collections/paste_curl_dialog_test.dart`

### M3 — Rutas de archivo fuera de exportaciones e importaciones; versión 3
`file_paths.dart` (`withoutFilePaths`, conteo); `exportWorkspace` y `importWorkspace` vacían rutas;
`CollectionsNotifier.importCollections` también; `workspaceFormatVersion = 3`; `secretsToFill` suma
los archivos habilitados; mensaje `N value(s) to fill in`.
**Aceptación:** exportar vacía la ruta y conserva nombre, tipo y tipo de contenido; importar un archivo
**con** rutas (workspace y JSON de colecciones) las vacía; el conteo suma los archivos; se leen
versiones 1–3 y ≥4 → "newer version"; `collections.json` con multipart se lee y escribe sin pérdida;
se actualizan solo los tests listados arriba.
**Verify:** `fvm flutter test test/engine/workspace test/engine/storage test/ui/projects test/ui/collections`

### M4 — Editor Form Data y selector de archivos
`FilePickerService` (+ implementación real y provider), `MultipartTable` (filas con id propio:
habilitar, nombre, Text/File, valor o ruta + `Choose…` + tipo de contenido, quitar, `Add field`),
segmento **Form Data** en `BodyTab`; la rama de solo lectura de M1 desaparece.
**Aceptación:** añadir/quitar filas; Text↔File conserva el nombre; el selector falso rellena la ruta;
aviso `No file chosen`; quitar una fila no deja texto viejo en la siguiente; un cuerpo distinto en la
misma posición muestra sus propios campos; escribir no reconstruye el campo; el selector de tipo
reinicia el cuerpo como hoy.
**Verify:** `fvm flutter test test/ui/request_builder`

### M5 — Journeys, CLI de punta a punta y README
Journey en `test/integration` + `integration_test/` (crear request con texto + archivo con el
selector falso, enviarlo contra el backend falso, importar un workspace con rutas y ver el aviso);
prueba del runner CLI con un `HttpServer` que lee el multipart real (separado por `boundary`) y con un
archivo inexistente (paso fallido, código 1); README (Form Data, rutas fuera de los archivos,
compatibilidad con versiones anteriores, relativas desde el cwd en CI); marcar los criterios.
**Aceptación:** journeys y prueba del CLI verdes; README completo.
**Verify:** `fvm flutter test && fvm flutter analyze`

## Riesgos

| Riesgo | Mitigación |
|---|---|
| M1 toca muchos archivos a la vez (la unión rompe cada `when`) | Es inevitable al añadir una variante; el compilador lista los sitios y la rama de UI mínima limita el cambio visual |
| Comparar `FormData` en tests | Inspeccionar `fields`/`files` y la longitud, no el objeto |
| Tests con archivos reales dentro de `testWidgets` (reloj falso) | Los de ejecutor/CLI usan `test()`; los widget usan un selector falso y no tocan el disco |
| Dos copias de la regla "vaciar rutas" | Una sola función `withoutFilePaths`, usada por export, import de workspace e `importCollections` |
| Tests intermitentes de UI con I/O real (`flow_builder_screen_test`, `sidebar_tree_test`) | No añadir esperas reales nuevas; si fallan, repetir el test aislado y anotarlo |
| `file_picker` no funciona en tests | Servicio inyectado, con una implementación falsa |
| Versión 3 del workspace y colecciones vacías en una app anterior | Documentado en el README (M5); la copia `.corrupt-…` conserva los datos |

## Fuera del plan (seguimiento)
- Interpretar el multipart en crudo del "Copy as cURL" de Chrome.
- Convertir campos entre Form URL-Encoded y Form Data al cambiar de tipo.
- Tipo de contenido para campos de texto; nombre de archivo distinto del de la ruta.
- Reenvío de `FormData` en redirecciones 307/308 (limitación de `dio`).
