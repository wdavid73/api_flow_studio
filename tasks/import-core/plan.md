# Plan: import-core

Spec: [SPEC-import-core.md](../../SPEC-import-core.md) · Mapa: [SPEC-import-map.md](../../SPEC-import-map.md).
Plan separado de los de los demás módulos (`tasks/<módulo>/`).

## Overview

Cinco tareas, cada una un corte vertical con su test y su commit: **I1** el contrato del
importador y `runImport` (engine puro) → **I2** el importador de la propia app y el registro →
**I3** aplicar un resultado (carpetas con raíces únicas, ambientes nuevos, todo o nada) →
**I4** la UI del botón Import con diálogos inyectables, resumen y errores → **I5** journey,
README y criterios. La suite existente debe seguir verde en cada tarea. Se aplican las respuestas
por defecto de la spec: se numeran las carpetas raíz que chocan (también las del formato de la app),
límite de 32 MB, sin tope de requests, sin deshacer, y el workspace solo se explica.

## Hallazgos del código que condicionan el plan

- **La importación actual es una función de UI sin pruebas** (`_importCollections` en
  `sidebar_tree.dart`, con `FilePicker` directo). Ya existe `test/sample_endpoints_test.dart`, que
  garantiza que `sample-endpoints.json` se parsea con los modelos; I2 lo reutiliza como prueba de que
  el importador lee ese archivo.
- **`mergeImportedCollections` descarta en silencio** los requests cuyo grupo no está en el archivo
  (`if (idMap[e.groupId] case final newGroupId?)`). El importador de la app debe avisar de ellos antes
  de llegar ahí, y `applyImport` cuenta lo que realmente entró.
- **`EnvironmentsNotifier` no tiene una operación para añadir ambientes importados** (`create`,
  `duplicate`, `updateEnvironment`…). I3 añade `addImported` con la misma cola `_mutate`.
- **Dos notifiers, dos archivos (`collections.json`, `environments.json`)**: no hay una transacción.
  El "todo o nada" se hace con un respaldo del estado de las colecciones y una restauración si falla
  la escritura de ambientes (`CollectionsNotifier.restore`, que pasa por la misma cola).
- **El patrón de diálogos inyectables ya existe** (`WorkspaceFileDialogs`, `FilePickerService`): el
  nuevo `ImportFileDialogs` lo sigue, y devuelve un archivo con su tamaño **antes** de leer el texto
  (lección del runner CLI: comprobar el tamaño primero).
- **El toast** se lee en tests como `container.read(toastProvider)` (así lo hace
  `workspace_transfer_test.dart`); los diálogos de error del import de workspace usan `showDialog`.
- **Un fallo de escritura se prueba subclasificando `JsonStore.inMemory()`** y haciendo que
  `writeEnvironments` lance; no hace falta un mock.
- **No usar `dart format`** en archivos existentes.

## Dependency graph

```
I1 contrato + runImport ── I2 importador de la app + registro ── I3 aplicar (raíces únicas, ambientes, rollback)
                                                                      │
                                                I4 UI: botón Import, diálogos, resumen ─── I5 journey + README
```

## Tareas

Cada tarea sigue TDD (test rojo primero) y termina con `fvm flutter analyze` y la suite relevante
en verde; el commit incluye solo los archivos de la tarea.

### I1 — El contrato y `runImport` (engine puro)
`lib/engine/import/`: `ImportResult`, `ImportWarning`, `ImportSummary` (con `describe()`),
`ImportSource` (JSON decodificado una vez), `Importer` (con `extensions`), `ImportException`,
`runImport`, detección de workspace (pista), `uniqueName`. Sin importadores reales.
**Aceptación:** `ImportSource.json` decodifica una vez y es null si no es JSON; `runImport` elige el
primero que coincide respetando el orden, mensaje con la lista de formatos si ninguno, propaga el
mensaje del importador, `Nothing to import…` si el resultado está vacío, pista de workspace aunque un
importador dijera que sí, un `matches` que lanza cuenta como "no"; `uniqueName` (sin choque, un choque,
varios, sin distinguir mayúsculas, con tope de longitud); `ImportSummary.describe()` con plurales
(`1 request in 1 folder`, `12 requests in 4 folders`, ambientes, valores por rellenar).
**Verify:** `fvm flutter test test/engine/import`

### I2 — `AppCollectionsImporter` y el registro
Reconoce `{groups, endpoints}`; rechaza formas ajenas (`info`, `openapi`, `swagger`, `values`);
omite con aviso los requests de una carpeta inexistente; `importers` con él como único elemento.
**Aceptación:** parsea el `sample-endpoints.json` del repo con las cifras correctas; formas válidas e
inválidas; request huérfano → omitido con aviso; JSON a medias → `ImportException` legible; ids
repetidos no rompen; `runImport` con `importers` real importa el sample y rechaza un workspace.
**Verify:** `fvm flutter test test/engine/import test/sample_endpoints_test.dart`

### I3 — Aplicar un resultado
`mergeImportedCollections`: raíces importadas con nombre único contra las existentes y entre sí;
`EnvironmentsNotifier.addImported`; `CollectionsNotifier.restore`; `applyImport(ref, result)` que
devuelve el `ImportSummary` (cifras reales, `valuesToFill`) y restaura las colecciones si falla la
escritura de ambientes.
**Aceptación:** raíces `Nombre`/`Nombre (2)`/`(3)` sin distinguir mayúsculas y subcarpetas intactas;
ambientes con nombre único, ids nuevos, sin activar y sin tocar el activo; secretas vacías →
`valuesToFill`; con un store que falla al escribir ambientes, las colecciones quedan como estaban y el
error se propaga; sin ambientes no se toca `environments.json`; los tests existentes de importación
siguen pasando.
**Verify:** `fvm flutter test test/ui/collections test/ui/environments test/ui/import`
**Checkpoint tras I3:** `fvm flutter analyze` y `fvm flutter test` completos en verde.

### I4 — La UI del botón Import
`ImportFileDialogs` (+ implementación con `file_picker`, + provider), `importFile(context, ref)`
(elegir, tamaño, leer, `runImport`, `applyImport`, informar), `ImportSummaryDialog` y el diálogo de
error; el botón `import-collections-button` llama a `importFile`, tooltip `Import…`; se elimina
`_importCollections`.
**Aceptación:** con un diálogo falso: importar el sample muestra el toast con las cifras y el sidebar
muestra la carpeta; con avisos aparece `import-summary-dialog` con la lista y `import-summary-close`;
cancelar no hace nada; un workspace muestra la pista; un archivo de ningún formato muestra el mensaje;
un archivo de más de 32 MB se rechaza **sin leer su texto**; un error no cambia las colecciones.
**Verify:** `fvm flutter test test/ui/import test/ui/collections`

### I5 — Journey y README
Journey (`integration_test/journeys/import_journey.dart`, registrado en `app_test.dart` y
`journeys_test.dart`) con un `FakeImportFileDialogs` en el harness: importar el JSON de la app y ver la
carpeta y el toast; importarlo dos veces y ver `Nombre (2)`. README: sección "Importing" (formatos,
nunca sobrescribe, ambientes nuevos sin activar, resumen de avisos, límite de 32 MB, workspace aparte).
Marcar los criterios.
**Aceptación:** journeys verdes; README completo.
**Verify:** `fvm flutter test && fvm flutter analyze`

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Reemplazar una función de UI sin pruebas | Se escriben primero los widget tests con el diálogo falso (I4) y se compara con el comportamiento que documenta el comentario original (toast con cifras, error si no es válido) |
| Numerar raíces cambia el comportamiento de hoy | Es la decisión 1 de la spec; los tests existentes importan nombres que no chocan, y hay tests nuevos del choque |
| Rollback entre dos notifiers con colas distintas | `restore` pasa por la cola de colecciones; se prueba con un store que falla |
| Archivos enormes cargados en memoria antes de comprobar el tamaño | El diálogo devuelve el tamaño y el texto es perezoso; un test verifica que `read` no se llama |
| Diálogos y toasts en widget tests | Leer `toastProvider` y buscar el diálogo por `Key`, como en `workspace_transfer_test.dart`; sin esperas reales nuevas (los tests con I/O real ya son intermitentes) |
| Importadores futuros acoplados al core | `runImport` recibe la lista; los tests usan importadores falsos |

## Fuera del plan (seguimiento)
- Importadores de Postman y OpenAPI (sus propios módulos, que se registran en `importers`).
- Deshacer la última importación; tope de requests importados.
- Que el sidebar redirija a "Import workspace…" en vez de solo explicarlo.
