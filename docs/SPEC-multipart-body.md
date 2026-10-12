# Spec: multipart-body

Módulo 1 del mapa [SPEC-import-map.md](SPEC-import-map.md). No depende de otros
módulos; `postman-import` y `openapi-import` dependen de este.

## Objective

Hoy un request solo puede llevar cuerpo `none`, `json` o `formUrlEncoded`. No se puede
probar un endpoint que sube un archivo ni uno que espera `multipart/form-data`. Este
módulo añade ese cuerpo, con campos de texto y de archivo, de punta a punta: se edita
en la app, se envía, se copia y se pega como curl, viaja en un workspace (sin rutas de
tu máquina) y lo corre el runner CLI.

**Usuario:** el desarrollador dueño de la app.

**Éxito:** en la pestaña Body se elige **Form Data**, se añaden un campo de texto
(`title`) y un archivo (`avatar`, elegido con el selector del sistema); al enviar, el
servidor recibe un `multipart/form-data` con los dos, con el nombre y el tipo del archivo
correctos; "Copy as curl" da un comando con `-F` que hace lo mismo; el workspace exportado
no contiene la ruta del archivo.

## ASSUMPTIONS (corregir ahora o procedo con estas)

1. Un campo multipart tiene: nombre, tipo (**texto** o **archivo**), valor (el texto, o la
   ruta del archivo), tipo de contenido opcional (solo para archivos) y habilitado/deshabilitado.
2. Sin dependencias nuevas: `dio` ya trae `FormData` y `MultipartFile`; `file_picker` ya está
   declarado. Los tipos MIME se infieren con una tabla propia pequeña (dio no infiere: su
   valor por defecto es `application/octet-stream`).
3. El nombre del archivo enviado es el nombre base de la ruta; no hay campo para cambiarlo en v1.
4. Las rutas de archivo se guardan tal cual las devuelve el selector (absolutas). Admiten
   `{{variables}}`, así que `{{fixtures}}/avatar.png` sirve en CI.
5. Un archivo se **abre en el momento de enviar**, no al editar: guardar un request no copia
   ni lee el archivo, y el historial no guarda cuerpos de request.
6. Cambiar el tipo de cuerpo en la UI **reinicia** el cuerpo, como hoy (JSON → Form no conserva
   nada). No hay conversión entre `Form URL-Encoded` y `Form Data`.

## Modelo

```dart
enum MultipartFieldKind { text, file }

@freezed
class MultipartField with _$MultipartField {
  const factory MultipartField({
    required String name,
    @Default(MultipartFieldKind.text) MultipartFieldKind kind,
    @Default('') String value,          // el texto, o la ruta del archivo
    String? contentType,                // solo archivos; null = inferir por extensión
    @Default(true) bool enabled,
  }) = _MultipartField;
}

// RequestBody: + const factory RequestBody.multipart(List<MultipartField> fields)
```

JSON: `{"runtimeType": "multipart", "fields": [{"name": "avatar", "kind": "file", "value": "/tmp/a.png", "contentType": null, "enabled": true}]}`.

## Comportamiento

### Envío (`RequestExecutor`)
- Los campos habilitados con nombre no vacío, en orden, se convierten en un `FormData`:
  texto → entrada de texto; archivo → `MultipartFile.fromFile(ruta, filename: nombre base,
  contentType: el indicado o el inferido)`. Un campo con nombre repetido se envía repetido.
  Los campos deshabilitados o sin nombre se ignoran.
- Nombre, valor de texto, ruta y tipo de contenido pasan por la interpolación de
  `{{variables}}` y `{{$tokens}}`, como el resto del request.
- `Content-Type` lo fija `dio` con el `boundary` (comprobado en `dio` 5.11: siempre sobrescribe
  el valor). Un `Content-Type` puesto a mano en Headers se **descarta** para este cuerpo.
- Un archivo no se carga en memoria: `dio` lo envía en streaming y con su tamaño.
- **Errores antes de enviar** (no se envía ningún request y se devuelve un `ExecutedResponse`
  con `error`, igual que un fallo de red; nunca una excepción):
  - ruta vacía: `Field "avatar" has no file chosen`
  - archivo inexistente, directorio o ilegible: `Cannot read the file for field "avatar": /ruta (No such file or directory)`
  - tipo de contenido inválido: `Invalid content type "x" for field "avatar"`
- `requestUrl` no cambia (URL con query, como hoy).
- Una redirección 307/308 con cuerpo `FormData` no se puede reenviar con `dio`; se trata como
  hoy cualquier error de red (limitación conocida, ver FYI).

### Tipos MIME inferidos
`png`→`image/png`, `jpg`/`jpeg`→`image/jpeg`, `gif`, `webp`, `svg`→`image/svg+xml`,
`pdf`→`application/pdf`, `json`, `txt`→`text/plain`, `csv`→`text/csv`, `xml`→`application/xml`,
`html`→`text/html`, `zip`→`application/zip`; cualquier otra → `application/octet-stream`.
La extensión no distingue mayúsculas.

### curl (copiar y pegar)
- **Copiar** (`buildCurl`): un `--form-string 'nombre=valor'` por campo de texto y un
  `-F 'nombre=@ruta;type=tipo'` por archivo (el `;type=` solo si hay tipo explícito). Una ruta
  con `;`, `,`, `"` o espacios va entre comillas dobles dentro del valor
  (`-F 'f=@"/ruta con ;.png"'`). No se añade `Content-Type` (curl lo calcula). Los campos
  deshabilitados no salen; las `{{variables}}` se resuelven como en los otros cuerpos.
- **Pegar** (`parseCurl`): `-F`/`--form nombre=valor` y `--form-string nombre=valor` (repetibles).
  `@ruta` → campo de archivo (con `;type=` → tipo de contenido; `;filename=` se ignora);
  cualquier otra cosa → texto. `nombre=<ruta` (contenido de archivo como texto) no se soporta y
  queda como texto literal. Implica `POST` si no hay `-X`, igual que `-d`. Mezclar `--form` con
  `--data` es un error de curl y aquí también: `CurlParseException('Cannot mix --form with --data')`.
- Fuera de v1: el "Copy as cURL" de Chrome para subidas emite el cuerpo multipart en crudo con
  `--data-raw`; eso sigue interpretándose como hoy (cuerpo JSON). Ver Open Questions.

### Editor (pestaña Body)
- Nuevo segmento **Form Data** junto a None / JSON / Form URL-Encoded. Teclas de prueba:
  `body-kind-selector` (existente).
- Una tabla de filas (`MultipartTable`): casilla habilitar (`multipart-enabled-$i`), nombre
  (`multipart-name-$i`), selector de tipo Text/File (`multipart-kind-$i`), y según el tipo:
  - **Text:** campo de valor (`multipart-value-$i`).
  - **File:** campo de ruta editable (`multipart-path-$i`; así admite `{{variables}}`), botón
    `Choose…` (`multipart-choose-$i`) que abre el selector del sistema, y un campo de tipo de
    contenido (`multipart-type-$i`, pista `auto`).
  - botón quitar (`multipart-remove-$i`) y, debajo, `Add field` (`add-multipart-field`).
- Una fila de archivo habilitada con la ruta vacía muestra el aviso ámbar `No file chosen`
  (`multipart-no-file-$i`). La existencia del archivo **no** se comprueba al editar; se informa al
  enviar.
- El selector de archivos se inyecta (`FilePickerService`, con una implementación real sobre
  `file_picker` y una falsa en tests), como `WorkspaceFileDialogs`.
- Las filas se identifican con un id propio (no por posición), para que quitar o reordenar no deje
  texto viejo en los campos: es el mismo defecto que ya se corrigió en el editor de assertions.
- Textos en inglés, estilo y espaciados de `KeyValueTable`.

### Almacenamiento y compatibilidad
- `collections.json` y el borrador guardan la variante nueva sin más cambios.
- **Una versión anterior de la app no entiende `runtimeType: multipart`:** al leer
  `collections.json` falla el parseo, `JsonStore` guarda una copia `collections.json.corrupt-<fecha>`
  y esa versión ve las colecciones **vacías** hasta que se vuelve a la nueva (nada se pierde: la
  copia y el archivo original conservan los datos, pero un guardado desde la versión vieja
  sobrescribiría `collections.json`). Se documenta en el README.
- **`workspaceFormatVersion` pasa a 3** (la v2 de assertions queda como está): un archivo con un
  cuerpo multipart no debe abrirse "en silencio" en una versión anterior. Se leen 1, 2 y 3; ≥4 →
  "newer version". Los tests que usan 3 como "futuro" pasan a 4.

### Rutas de archivo y archivos ajenos (seguridad)
Un cuerpo multipart manda el contenido de un archivo local a una URL. Si un archivo recibido de
otra persona pudiera traer una ruta (`~/.ssh/id_rsa`) y tú pulsaras Send, se enviaría sin que lo
hayas elegido. Por eso:
- **Exportar un workspace vacía la ruta** de todo campo de archivo (el nombre, el tipo y el tipo de
  contenido se conservan), igual que los secretos.
- **Importar un workspace** (`importWorkspace`) y **la importación del JSON de colecciones** del
  panel lateral **también vacían las rutas**, aunque el archivo las traiga. Un campo de archivo sin
  ruta no envía nada.
- Los campos de archivo con la ruta vacía se cuentan como "valores por rellenar" en el resumen de
  la importación. El mensaje pasa de `N secret value(s) to fill in` a `N value(s) to fill in`
  (cubre secretos y archivos); `WorkspaceFile.secretsToFill` los suma.
- Una única función de engine (`withoutFilePaths`) lo hace para los tres caminos, y las
  importaciones futuras (`import-core`) deben usarla.

### Runner CLI
Sin cambios de código: usa el mismo `RequestExecutor`. Una ruta relativa se resuelve desde el
directorio de trabajo del proceso; un archivo inexistente o sin elegir hace fallar el paso con el
mensaje de arriba (el CI lo ve como un fallo de red del paso). Se documenta en el README, y las
rutas no se redactan (no son secretos).

### Run view y demás UI
`step_card.dart` (vista previa de "Payload Template", que hoy distingue JSON de lo demás) trata
`multipart` como "sin vista previa JSON". Ninguna otra pantalla cambia.

## Commands

```bash
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs   # cambia RequestBody y nuevo MultipartField
fvm flutter test test/engine/models test/engine/http test/engine/curl test/engine/workspace
fvm flutter test test/ui/request_builder test/ui/collections test/ui/projects
fvm flutter test test/cli
fvm flutter test                       # suite completa
fvm flutter test test/integration      # journeys sin ventana
fvm flutter analyze
# NO ejecutar `dart format` sobre archivos existentes: el repo no usa el estilo nuevo.
```

## Project Structure

```
lib/engine/models/multipart_field.dart       # NUEVO: MultipartField, MultipartFieldKind (freezed)
lib/engine/models/request_body.dart          # + multipart
lib/engine/models/models.dart                # export
lib/engine/models/file_paths.dart            # NUEVO: withoutFilePaths(Endpoint), filePathsToFill(...)
lib/engine/http/mime_types.dart              # NUEVO: contentTypeForPath(String)
lib/engine/http/request_executor.dart        # FormData, errores antes de enviar
lib/engine/variables/interpolator.dart       # interpolateBody: multipart
lib/engine/curl/curl_builder.dart, curl_parser.dart   # -F / --form-string
lib/engine/workspace/export_workspace.dart   # vacía rutas
lib/engine/workspace/import_workspace.dart   # vacía rutas
lib/engine/workspace/workspace_file.dart     # versión 3, secretsToFill suma archivos
lib/ui/request_builder/multipart_table.dart  # NUEVO: editor
lib/ui/request_builder/file_picker_service.dart  # NUEVO: FilePickerService + provider
lib/ui/request_builder/tabs/body_tab.dart    # segmento Form Data
lib/ui/collections/sidebar_tree.dart         # el import JSON usa withoutFilePaths
lib/ui/workspace_transfer/workspace_transfer_actions.dart  # mensaje "values to fill in"
lib/ui/flows/step_card.dart                  # multipart: sin vista previa JSON
integration_test/support/fake_backend.dart   # resume el cuerpo multipart
test/...                                     # ver Testing Strategy
README.md                                    # Form Data, compatibilidad, CLI
```

## Code Style

El editor sigue el patrón de `AssertionsEditor` (ids de fila, `_emit`) y el ejecutor construye el
cuerpo en una función propia que devuelve `FormData` o un mensaje de error, sin lanzar:

```dart
/// The `FormData` for [fields], or an error message when a file cannot be read.
/// Never throws: a missing file is a failed request, like a refused connection.
Future<({FormData? data, String? error})> _buildFormData(List<MultipartField> fields) async {
  final form = FormData();
  for (final field in fields) {
    if (!field.enabled || field.name.isEmpty) continue;
    switch (field.kind) {
      case MultipartFieldKind.text:
        form.fields.add(MapEntry(field.name, field.value));
      case MultipartFieldKind.file:
        // ...
    }
  }
  return (data: form, error: null);
}
```

Convenciones del repo: comentarios `///` con el porqué, `engine/` sin `package:flutter`, claves con
índice para tests, textos en inglés, línea larga existente (sin reformatear archivos ajenos).

## Testing Strategy

- **Modelo:** round-trip JSON de `MultipartField` y `RequestBody.multipart` para cada tipo y con
  `contentType` nulo y no nulo; un JSON sin `kind` lee `text`.
- **Interpolación:** nombre, texto, ruta y tipo de contenido resuelven `{{var}}` y `{{$token}}`;
  un campo deshabilitado queda intacto; `none`/`json`/`formUrlEncoded` no cambian.
- **Executor (dio mockeado, capturando el `FormData`):** campos de texto y archivo en orden y con
  nombres repetidos; `filename` = nombre base (con `/` y con `\`); tipo inferido por extensión
  (mayúsculas, extensión desconocida) y tipo explícito; campos deshabilitados o sin nombre
  ignorados; `Content-Type` manual descartado; archivo inexistente, directorio y ruta vacía →
  `ExecutedResponse.error` **sin llamar a dio**; tipo de contenido inválido; `requestUrl` intacto.
  Un archivo real temporal con contenido conocido para comprobar la longitud.
- **MIME:** la tabla completa y el caso por defecto.
- **curl:** `buildCurl` (texto, archivo, con y sin tipo, ruta con `;` y espacios, deshabilitado,
  variables); `parseCurl` (`-F`, `--form`, `--form-string`, `@ruta;type=`, `;filename=` ignorado,
  `<ruta` como texto, repetidos, implica `POST`, mezcla con `-d` → error); round-trip
  `buildCurl` → `parseCurl`.
- **Workspace:** exportar vacía rutas y conserva el resto; `withoutFilePaths` aislado; importar un
  archivo **con** rutas las vacía (workspace y JSON de colecciones); `secretsToFill` suma los
  archivos sin ruta; la versión exportada es 3; se leen 1, 2 y 3 y ≥4 se rechaza.
- **Almacenamiento:** una `collections.json` con multipart se lee y escribe sin pérdida.
- **Widget:** el segmento Form Data; añadir/quitar filas; cambiar Text↔File conserva el nombre y
  muestra el control correcto; elegir archivo con el selector falso rellena la ruta; el aviso
  `No file chosen`; quitar una fila no deja texto viejo en la siguiente; un cuerpo distinto en la
  misma posición muestra sus propios campos; escribir no reconstruye el campo (foco).
- **Integración (`test/integration` + `integration_test/`):** un journey que crea un request con un
  campo de texto y un archivo (selector falso), lo envía contra el backend falso y comprueba lo
  recibido; el flujo de importar un workspace con rutas muestra el aviso de valores por rellenar.
- **CLI de punta a punta:** un `HttpServer` local lee el cuerpo multipart (se separa por el
  `boundary`) y comprueba los campos, el nombre y el contenido del archivo; un archivo inexistente
  falla el paso con el mensaje esperado y código 1.
- La suite existente solo cambia donde se indica (versión 3→4 de "futuro", mensaje de la
  importación); nada se debilita ni se borra.

## Boundaries

- **Always:** TDD (test rojo primero); `fvm flutter analyze` y la suite completa antes de cada
  commit; leer el archivo solo al enviar; vaciar las rutas en toda exportación e importación;
  devolver un error legible (nunca lanzar) si un archivo no se puede leer; `engine/` sin imports
  de Flutter; commits por tarea con solo sus archivos.
- **Ask first:** añadir una dependencia (por ejemplo `mime` en vez de la tabla propia); cambiar
  otra vez `workspaceFormatVersion`; interpretar el multipart en crudo de un curl pegado; guardar
  contenido de archivos en el JSON, el historial o el workspace.
- **Never:** enviar un archivo que el request no referencia explícitamente; importar una ruta de
  archivo desde un archivo ajeno; leer un archivo en `build()` de un widget; cargar un archivo
  entero en memoria para enviarlo; debilitar o borrar tests existentes.

## Success Criteria

1. Un request con cuerpo Form Data (texto + archivo) llega al servidor como `multipart/form-data`
   con los campos, el `filename` y el tipo correctos, y el contenido íntegro del archivo.
2. Nombres repetidos, campos deshabilitados y campos sin nombre se comportan como se describe.
3. `{{variables}}` y `{{$tokens}}` funcionan en nombre, texto, ruta y tipo de contenido.
4. Archivo inexistente, directorio o ruta vacía fallan el request con un mensaje claro, sin
   enviarlo y sin excepciones.
5. `buildCurl` y `parseCurl` soportan `-F`, `--form` y `--form-string` según la spec, con
   round-trip.
6. El editor permite añadir, quitar, cambiar de tipo, escribir la ruta o elegirla con el selector,
   y no deja texto viejo al quitar filas.
7. Exportar un workspace deja las rutas vacías; importar (workspace o JSON de colecciones) las vacía
   siempre; el resumen cuenta los archivos por rellenar.
8. `workspaceFormatVersion` es 3; se leen 1, 2 y 3; 4 se rechaza como versión nueva.
9. El runner CLI envía un multipart real y falla el paso con un mensaje claro si falta el archivo.
10. `fvm flutter analyze` sin avisos y `fvm flutter test` en verde.

## Open Questions

1. **El "Copy as cURL" de Chrome para subidas** emite el multipart en crudo en `--data-raw`
   (`------WebKitFormBoundary…`). ¿Lo interpreto al pegar (cada parte → un campo; las partes con
   `filename=` → archivo sin ruta)? Es útil pero es un parser de multipart; lo dejo fuera de v1.
2. **¿Convertir al cambiar de tipo de cuerpo?** (Form URL-Encoded ↔ Form Data conservando los
   campos de texto). Hoy cambiar de tipo reinicia; mantengo eso en v1.
3. **¿Tipo de contenido también para los campos de texto?** (curl admite `;type=` en texto).
   Lo dejé solo para archivos.
4. **¿Un nombre de archivo distinto del de la ruta?** (`;filename=` de curl). Fuera de v1.
5. **FYI, sin acción:** `dio` no puede reenviar un `FormData` en una redirección 307/308; el paso
   falla con el error de red de siempre.
6. **¿Tabla MIME propia o el paquete `mime`?** Propongo la tabla (12 extensiones) para no añadir una
   dependencia; el paquete cubre cientos de tipos.

## Estado

Implementado de M1 a M5 (`tasks/multipart-body/`). Criterios de éxito y dónde se comprueban:

| # | Criterio | Pruebas |
|---|---|---|
| 1 | Llega como `multipart/form-data` con campos, `filename`, tipo y contenido | `request_executor_test.dart`, `test/cli/end_to_end_test.dart` (servidor real) |
| 2 | Nombres repetidos, deshabilitados y sin nombre | `request_executor_test.dart` |
| 3 | `{{variables}}` y `{{$tokens}}` | `interpolator_test.dart`, `request_executor_test.dart`, `end_to_end_test.dart` |
| 4 | Archivo inexistente / carpeta / sin elegir / tipo inválido fallan sin enviar | `request_executor_test.dart`, `end_to_end_test.dart` |
| 5 | `-F`, `--form`, `--form-string` con round-trip | `curl_builder_test.dart`, `curl_parser_test.dart` |
| 6 | Editor: añadir, quitar, cambiar tipo, ruta o selector, sin texto viejo | `multipart_table_test.dart`, `body_tab_test.dart`, `multipart_journey.dart` |
| 7 | Exportar e importar vacían las rutas; el resumen cuenta los archivos | `file_paths_test.dart`, `workspace_file_test.dart`, `import_workspace_test.dart`, `collections_provider_test.dart`, `multipart_journey.dart` |
| 8 | Versión 3; se leen 1–3; 4 rechazada | `workspace_file_test.dart`, `workspace_transfer_test.dart` |
| 9 | El runner CLI envía un multipart real y falla un archivo ausente | `test/cli/end_to_end_test.dart` |
| 10 | `analyze` y `test` en verde | CI |

Decisiones al implementar: la comprobación explícita de "es una carpeta" no hace falta (el SO
ya lo informa al abrir el archivo y el mensaje conserva el motivo); el conteo de "valores por
rellenar" suma solo los campos de archivo habilitados y con nombre; cambiar el tipo de una fila
(Text↔File) conserva el nombre y el estado habilitado, y vacía valor y tipo de contenido.
