# Spec: import-core

Módulo 2 del mapa [SPEC-import-map.md](SPEC-import-map.md). No depende de otros módulos
(`multipart-body` ya está implementado y no hace falta para esto). `postman-import` y
`openapi-import` dependen de este.

## Objective

Hoy el panel lateral solo importa el JSON de colecciones de la propia app, y esa lógica vive
dentro de una función de UI (`_importCollections` en `sidebar_tree.dart`, con `FilePicker` directo,
sin pruebas propias). Para importar desde Postman y OpenAPI hace falta una base común y
probable: un contrato para "un importador", la detección del formato, una forma segura de meter
el resultado en el proyecto activo y un resumen claro de lo que entró y lo que se dejó fuera.
Este módulo la construye y migra a ella la importación que ya existe, sin añadir formatos nuevos.

**Usuario:** el desarrollador dueño de la app.

**Éxito:** el botón Import del panel lateral acepta un archivo, averigua qué formato es, y
(1) si lo entiende, lo mete en una carpeta nueva del proyecto activo sin tocar nada de lo que había
y dice cuántas carpetas, requests y ambientes entraron y qué se omitió y por qué; (2) si no lo
entiende, lo dice con un mensaje útil y no cambia nada. Los importadores de Postman y OpenAPI se
enchufan después sin tocar este código.

## ASSUMPTIONS (corregir ahora o procedo con estas)

1. **Un importador** convierte el texto de un archivo en un `ImportResult` (carpetas, requests,
   ambientes y avisos) y no sabe nada de la UI ni de dónde se guarda.
2. **La detección es por el contenido**, no por la extensión (`.json` puede ser cualquiera de los
   cuatro). Cada importador decide con una comprobación barata si el archivo es suyo; el primero que
   dice que sí lo procesa, en el orden en que están registrados.
3. **Importar nunca sobrescribe ni mezcla:** todo entra como carpetas nuevas y ambientes nuevos con
   ids nuevos; un nombre ya usado se numera (`Petstore`, `Petstore (2)`). Los ambientes importados
   **nunca se activan**.
4. **Todo o nada:** si algo falla al guardar, el proyecto queda como estaba.
5. **Las rutas de archivo no se importan** (regla común del mapa): todo request pasa por
   `withoutFilePaths`, que ya aplica `mergeImportedCollections`.
6. **Sin dependencias nuevas** (el YAML de OpenAPI llega con su módulo).
7. El formato de colecciones de la propia app (`{groups, endpoints}`) pasa a ser el primer
   importador registrado. Su comportamiento se conserva, con una mejora: las carpetas raíz importadas
   cuyo nombre ya existe se numeran en vez de duplicarse.

## Contrato

```dart
/// Lo que un archivo contenía, ya traducido al modelo de la app. Sin ids definitivos
/// (el motor los regenera) y sin efectos: solo datos.
class ImportResult {
  final String source;                       // "Postman collection", "OpenAPI 3.0 spec"…
  final List<Group> groups;                  // árbol completo; las raíces tienen parentGroupId null
  final List<Endpoint> endpoints;            // groupId apunta a un id de [groups]
  final List<Environment> environments;
  final List<ImportWarning> warnings;
}

class ImportWarning {
  final String where;                        // "Auth / Login", "paths./pets.get", "" si es global
  final String message;                      // "pre-request script ignored"
}

/// El texto de un archivo, con su JSON decodificado una sola vez a demanda.
class ImportSource {
  ImportSource(this.text, {this.fileName});
  final String text;
  final String? fileName;
  Object? get json;                          // null si no es JSON; se decodifica y se guarda la 1.ª vez
}

abstract interface class Importer {
  String get formatName;                     // para mensajes y para el resumen
  bool matches(ImportSource source);         // barato, nunca lanza
  ImportResult parse(ImportSource source);   // lanza ImportException con un mensaje legible
}

class ImportException implements Exception { final String message; }

/// Elige el importador y lo ejecuta. Lanza ImportException si ninguno reconoce el archivo,
/// si el importador falla, o si el resultado no trae nada que importar.
ImportResult runImport(String text, List<Importer> importers, {String? fileName});

const List<Importer> importers = [AppCollectionsImporter(), /* Postman y OpenAPI se añaden aquí */];
```

El importador de la app (`AppCollectionsImporter`) reconoce un objeto JSON con `groups` y/o
`endpoints` que son listas, y sin las claves que delatan a otros formatos (`info`, `openapi`,
`swagger`, `values`). Un request cuyo `groupId` no existe en el archivo se **omite con un aviso**
(`"<nombre>": folder not found, skipped`), no se pierde en silencio como hoy.

### Archivos que son otra cosa (mensajes)
| Archivo | Mensaje |
|---|---|
| Un workspace (`"format": "api-flow-studio-workspace"`) | `This is a workspace file. Use Project ▸ Import workspace… to open it as a new project.` |
| JSON que ningún importador reconoce | `That file is not a format I can import. Supported: <lista de formatName>.` |
| No es JSON ni texto legible | `That file is not valid JSON.` (cuando `fileName` termina en `.json`; si no, el mensaje de formato no reconocido) |
| Reconocido pero sin nada que importar | `Nothing to import: <formatName> had no requests.` |
| Demasiado grande | `That file is too large to import (the limit is 32 MB).` |

La detección del workspace vive en el core (no es un importador: no se importa aquí, solo se explica).

## Comportamiento

### Aplicar un resultado (`applyImport`)
Un único paso con todo o nada, que usa los notifiers que ya existen:
1. **Carpetas y requests:** `mergeImportedCollections` (ids nuevos, raíces añadidas al final, rutas de
   archivo vacías) con una mejora: cada **carpeta raíz** importada cuyo nombre coincide, sin distinguir
   mayúsculas, con una raíz existente (o con otra importada) se numera `Nombre (2)`, `Nombre (3)`…
2. **Ambientes:** `EnvironmentsNotifier.addImported(...)` nuevo: ids nuevos, nombre único (`Dev`,
   `Dev (2)`), sin activar ninguno, sin tocar el activo.
3. **Atomicidad:** se calcula el estado nuevo de colecciones y de ambientes antes de escribir; si
   escribir los ambientes falla tras escribir las colecciones, se restaura el estado anterior de las
   colecciones y se propaga el error.
4. Devuelve un `ImportSummary`: `source`, `folders`, `requests`, `environments`, `warnings`,
   `valuesToFill` (variables secretas de los ambientes importados que quedaron vacías).

### Botón Import del panel lateral
- Sigue en el mismo sitio (`import-collections-button`); el tooltip pasa de `Import endpoints (JSON)`
  a `Import…` y el selector acepta `json` (y en el futuro `yaml`/`yml`; los importadores declaran las
  extensiones que quieren).
- El diálogo de archivo se **inyecta** (`ImportFileDialogs`, como `WorkspaceFileDialogs`): devuelve el
  nombre y el texto del archivo elegido, o null si se cancela (no pasa nada). Antes de leer se
  comprueba el tamaño: más de 32 MB (bytes) → mensaje de "demasiado grande" sin cargarlo.
- Resultado:
  - **Sin avisos:** un aviso breve (toast) `Imported <source>: 12 requests in 4 folders` (plural
    correcto; con ambientes: `, 1 environment`; con valores por rellenar: `— N values to fill in`).
  - **Con avisos:** un diálogo `Import summary` con las mismas cifras y la lista de avisos
    (`where` en mono, `message` debajo), con scroll y un botón `Close` (`import-summary-close`).
  - **Error** (`ImportException`): un diálogo o aviso con el mensaje; nada cambia.
- El resumen y la lista de avisos son el único lugar donde se ve lo omitido: ningún importador debe
  descartar algo sin dejar un aviso.

### Qué ve el sidebar tras importar
La carpeta nueva queda al final del árbol, sin expandir ni seleccionar nada; el toast o el resumen
dice cómo se llama. Sin cambios de navegación.

## Commands

```bash
fvm flutter pub get
fvm flutter test test/engine/import test/ui/import test/ui/collections test/ui/environments
fvm flutter test                       # suite completa
fvm flutter test test/integration      # journeys sin ventana
fvm flutter analyze
# NO ejecutar `dart format` sobre archivos existentes: el repo no usa el estilo nuevo.
```

## Project Structure

```
lib/engine/import/
  import_result.dart            # ImportResult, ImportWarning, ImportSummary
  import_source.dart            # ImportSource (JSON decodificado una vez)
  importer.dart                 # Importer, ImportException, runImport, importers (registro)
  app_collections_importer.dart # el formato {groups, endpoints} de la app
  import_naming.dart            # uniqueName(...) para carpetas y ambientes
lib/ui/import/
  import_file_dialogs.dart      # ImportFileDialogs + implementación con file_picker + provider
  import_actions.dart           # importFile(context, ref): leer, detectar, aplicar, informar
  import_summary_dialog.dart    # el resumen con avisos
lib/ui/collections/collections_provider.dart   # applyImport / mergeImportedCollections (raíces únicas)
lib/ui/environments/environments_provider.dart # addImported(...)
lib/ui/collections/sidebar_tree.dart           # el botón llama a importFile; _importCollections se va
test/engine/import/ , test/ui/import/ , test/ui/collections/ , test/ui/environments/
integration_test/journeys/import_journey.dart  # + registro en app_test.dart y journeys_test.dart
README.md
```

`lib/engine/import/` sin `package:flutter`, como el resto de `engine/`.

## Code Style

El registro es una lista pura y `runImport` no sabe qué importadores hay (se le pasan), de modo que
las pruebas usan importadores falsos y los módulos futuros solo añaden uno a la lista:

```dart
ImportResult runImport(String text, List<Importer> importers, {String? fileName}) {
  final source = ImportSource(text, fileName: fileName);
  if (looksLikeWorkspace(source)) throw const ImportException(_workspaceHint);
  for (final importer in importers) {
    if (!importer.matches(source)) continue;
    final result = importer.parse(source);
    if (result.endpoints.isEmpty && result.environments.isEmpty) {
      throw ImportException('Nothing to import: ${importer.formatName} had no requests.');
    }
    return result;
  }
  throw ImportException('That file is not a format I can import. Supported: ${...}.');
}
```

Convenciones: comentarios `///` con el porqué, textos de UI en inglés, `Key`s con nombre para los
tests, sin `print`, estilo de línea largo del repo.

## Testing Strategy

- **`ImportSource`:** `json` decodifica una vez, devuelve null si no es JSON, y no relanza.
- **`runImport` con importadores falsos:** elige el primero que coincide y respeta el orden; ninguno
  coincide → mensaje con la lista de formatos; el importador lanza → su mensaje; resultado vacío →
  `Nothing to import`; un workspace → la pista (aunque algún importador dijera que sí); `matches` que
  lanza no rompe la detección (se trata como "no").
- **`AppCollectionsImporter`:** reconoce y rechaza las formas (con/sin `groups`, `endpoints` no lista,
  claves de otros formatos); parsea el JSON del `sample-endpoints.json` del repo; un request con
  carpeta inexistente se omite con aviso; un JSON dañado a medias lanza `ImportException` legible;
  ids repetidos no rompen.
- **Nombres únicos:** `uniqueName` sin choque, con choque, con varios choques, sin distinguir
  mayúsculas, con el tope de longitud.
- **`applyImport` / providers:** raíces numeradas contra las existentes y entre sí; subcarpetas intactas;
  rutas de archivo vacías (ya cubierto, se mantiene); ambientes nuevos con nombre único, sin activar y
  sin tocar el activo; secretas vacías → `valuesToFill`; **todo o nada**: si la escritura de ambientes
  falla (store que lanza), las colecciones vuelven al estado anterior; contadores del resumen.
- **Widget (`ImportFileDialogs` falso):** importar `sample-endpoints.json` muestra el toast con las
  cifras; con avisos aparece el diálogo con la lista y `Close`; cancelar no hace nada; un workspace
  muestra la pista; un archivo que no es de ningún formato muestra el mensaje; un archivo grande se
  rechaza sin leerlo; el resultado entra en el sidebar.
- **Integración (`test/integration` + `integration_test/`):** un journey que importa el JSON de la app
  desde el sidebar y ve la carpeta y el toast, importa dos veces el mismo archivo y ve `Nombre (2)`.
- La suite existente solo cambia donde la mejora de nombres únicos lo exige; nada se debilita ni se borra.

## Boundaries

- **Always:** TDD (test rojo primero); `fvm flutter analyze` y la suite completa antes de cada commit;
  importar crea carpetas y ambientes **nuevos** con ids nuevos y no activa ambientes; todo request
  importado pasa por `withoutFilePaths`; todo lo omitido deja un aviso; comprobar el tamaño antes de
  leer; `engine/` sin imports de Flutter; commits por tarea con solo sus archivos.
- **Ask first:** añadir una dependencia; cambiar la semántica de "nunca sobrescribe"; permitir que un
  importador ejecute algo (scripts); subir `workspaceFormatVersion`.
- **Never:** sobrescribir o fusionar con carpetas, requests o ambientes existentes; activar un
  ambiente importado; seguir una URL o leer otros archivos que un archivo importado mencione (por
  ejemplo un `$ref` externo); dejar el proyecto a medias tras un fallo; debilitar o borrar tests existentes.

## Success Criteria

1. Importar el `sample-endpoints.json` desde el sidebar crea sus carpetas y requests al final del árbol
   y muestra el toast con las cifras correctas; importarlo dos veces numera la carpeta raíz.
2. Un archivo de cualquier otro formato conocido (cuando existan los importadores) o desconocido, un
   workspace, uno demasiado grande o uno vacío se rechazan con el mensaje de la tabla y no cambian nada.
3. Un request cuya carpeta falta en el archivo se omite y aparece en la lista de avisos.
4. Los ambientes importados tienen nombres únicos y ids nuevos y no se activa ninguno; el activo
   anterior sigue activo.
5. Un fallo al escribir deja las colecciones y los ambientes como estaban.
6. Con avisos se muestra el diálogo de resumen con la lista; sin avisos, el toast.
7. Un importador nuevo se añade registrándolo en `importers`, sin tocar `runImport`, `applyImport` ni la UI.
8. `fvm flutter analyze` sin avisos y `fvm flutter test` en verde.

## Open Questions

1. **¿Numerar las carpetas raíz que chocan** también para el importador de la propia app? Cambia el
   comportamiento de hoy (que duplica nombres), y lo propongo porque importar dos veces el mismo
   archivo deja de producir dos carpetas idénticas. La alternativa es numerar solo los formatos nuevos.
2. **¿Límite de 32 MB?** Una spec grande de OpenAPI ronda los 5–10 MB; 32 MB deja margen. ¿Prefieres
   otro tope?
3. **¿Tope de requests importados** (por ejemplo 5 000, con un aviso)? Una spec enorme genera miles de
   filas en el sidebar. Lo dejé fuera de v1; ¿lo quieres como salvaguarda?
4. **¿Deshacer la última importación?** Sería "borrar la carpeta nueva y los ambientes nuevos".
   Fuera de v1, pero se puede construir encima de `ImportSummary` si lo pides.
5. **El import de workspace** (menú del proyecto) sigue siendo aparte, porque crea un proyecto entero
   y no una carpeta. ¿Te parece bien que el sidebar solo lo explique y no lo redirija?

## Estado

Implementado de I1 a I5 (`tasks/import-core/`). Criterios de éxito y dónde se comprueban:

| # | Criterio | Pruebas |
|---|---|---|
| 1 | Importar `sample-endpoints.json` crea carpetas y requests y muestra el toast; dos veces numera la raíz | `app_collections_importer_test.dart`, `import_file_test.dart`, `import_journey.dart` |
| 2 | Otro formato, workspace, demasiado grande o vacío se rechazan con su mensaje y no cambian nada | `run_import_test.dart`, `import_file_test.dart`, `import_journey.dart` |
| 3 | Un request con carpeta ausente se omite y aparece en los avisos | `app_collections_importer_test.dart`, `import_journey.dart` |
| 4 | Ambientes con nombres únicos e ids nuevos, ninguno activo, el activo sigue | `apply_import_test.dart` |
| 5 | Un fallo al escribir deja colecciones y ambientes como estaban | `apply_import_test.dart` (`all or nothing`) |
| 6 | Con avisos, diálogo de resumen; sin avisos, toast | `import_file_test.dart`, `import_journey.dart` |
| 7 | Un importador nuevo se añade solo en `importers` | `run_import_test.dart` (importadores falsos), `import_registry.dart` |
| 8 | `analyze` y `test` en verde | CI |

Decisiones al implementar: `ImportSource` no se pasa a los importadores como texto sino con su JSON
decodificado una vez; `applyImport` recibe `ref.read` (o `container.read`) en lugar de los notifiers,
porque `AsyncNotifier.future` es protegido; `EnvironmentsNotifier.addImported` escribe en disco
**antes** de actualizar el estado, para que un fallo no deje ambientes "importados" que no están
guardados; los avisos de carpetas con padre ausente y de requests huérfanos se generan en el
importador, donde todavía se conoce el nombre.
