# Plan: proyectos (workspaces) y workspace exportable

Spec: [SPEC-workspaces.md](../../SPEC-workspaces.md). Plan separado de
`tasks/plan.md` (rediseño) y `tasks/integration-tests/` (recorridos).

## Overview

Cuatro módulos en orden: `projects-core` → `projects-ui` → `history-limits` →
`workspace-transfer`. Once tareas, cada una un corte vertical que deja la app
funcionando, con su test y su commit. Los 693 tests y los 68 recorridos de
integración existentes deben seguir verdes en cada tarea.

## Decisiones de diseño que condicionan el plan

- **El proyecto activo se calcula por encima de `jsonStoreProvider`.** Hoy ese
  provider devuelve `JsonStore()` y lo sobreescriben todos los tests. Se agrega
  `projectsRepositoryProvider`; su valor por defecto es un repositorio de *un
  solo proyecto* que envuelve el `JsonStore()` de siempre, así nada existente
  cambia. `main.dart` lo sobreescribe con el repositorio real (disco) ya migrado.
- **Un repositorio, dos implementaciones**: disco (`projects/<id>/…`) y memoria
  (para tests y web). `storeFor(projectId)` devuelve el `JsonStore` del proyecto.
- **Cambiar de proyecto = recargar todo.** Los providers que hoy hacen
  `ref.read(jsonStoreProvider)` en `build` pasan a `ref.watch` para recargar solos.
  Además se reinicia el estado de UI que no vive en disco (request abierta,
  borrador, respuesta mostrada, flow abierto, resultado de la corrida).
  Es el riesgo principal del módulo 1; la tarea P3 empieza con un spike.
- **Migración segura**: se *copia* a `projects/<id>/`, se verifica y solo
  entonces se borra el original; idempotente.
- **El diálogo de archivos se inyecta** (`WorkspaceFileDialogs`) para que los
  recorridos de integración no abran el selector del sistema.

## Dependency graph

```
P1 modelos + repositorio ──┬─ P2 migración a Default
                           └─ P3 cableado: store activo + recarga ── P4 selector en el header
                                                                      │
                                                    P5 crear/renombrar/eliminar + recorrido
                                                                      │
              ┌───────────────────────────────────────────────────────┤
   P6 recorte del historial ── P7 borrar historial                    │
                                                P8 formato y exportar ── P9 importar ── P10 UI exportar/importar
                                                                                                │
                                                                              P11 recorrido ida y vuelta + docs
```

P6–P7 solo necesitan P3; P8–P9 (motor) solo necesitan P1, y pueden hacerse antes
de la UI si conviene. El orden de la lista es el de construcción.

## Task list

### Phase 1: projects-core
- [x] P1: Modelo de proyecto y repositorio
- [x] P2: Migración de los datos actuales a Default
- [x] P3: El proyecto activo decide el store; todo recarga al cambiar

### Checkpoint: Core
- [x] analyze limpio, `fvm flutter test` y recorridos en memoria verdes

### Phase 2: projects-ui
- [x] P4: Selector de proyecto en el header
- [x] P5: Crear, renombrar y eliminar, con recorrido de proyectos

### Checkpoint: Proyectos
- [x] analyze limpio, ambos runners verdes

### Phase 3: history-limits
- [ ] P6: Recorte del cuerpo y límite global
- [ ] P7: Borrar historial

### Phase 4: workspace-transfer
- [ ] P8: Formato del workspace y exportar (motor)
- [ ] P9: Importar como proyecto nuevo (motor)
- [ ] P10: Acciones de exportar e importar en la UI
- [ ] P11: Recorrido ida y vuelta, docs y corridas finales

### Checkpoint: Done
- [ ] Todos los criterios del spec cumplidos o justificados

---

## P1: Modelo de proyecto y repositorio

**Description:** `Project` (id, name, colorIndex, createdAt) y `ProjectsRepository`:
lista, activo, crear, renombrar, eliminar, `storeFor(id)`. Índice en
`projects.json`. Implementaciones disco y memoria. Reglas: nombre único y no
vacío (hasta 40), no se elimina el último proyecto, eliminar el activo activa otro.

**Acceptance criteria:**
- [ ] Crear, renombrar, activar y eliminar persisten en `projects.json` y sobreviven a reabrir el repositorio.
- [ ] `storeFor(a)` y `storeFor(b)` son almacenes independientes: escribir en uno no cambia el otro.
- [ ] Nombre vacío, repetido (sin distinguir mayúsculas) o de más de 40 caracteres se rechaza con un error tipado.
- [ ] Eliminar un proyecto borra su carpeta; el último no se puede eliminar.
- [ ] `projects.json` corrupto se respalda como `.corrupt-<ts>` y se recrea un índice vacío, igual que `JsonStore`.

**Verification:** `fvm flutter test test/engine/projects` · `fvm flutter analyze`

**Dependencies:** ninguna

**Files likely touched:** `lib/engine/projects/project.dart` (+freezed),
`lib/engine/projects/projects_repository.dart`, tests en `test/engine/projects/`

**Estimated scope:** Medium (5 archivos)

## P2: Migración de los datos actuales a Default

**Description:** Al abrir un repositorio de disco sin `projects.json` pero con
archivos de datos en la raíz, crear **Default** y moverlos a su carpeta.

**Acceptance criteria:**
- [ ] Con datos en la raíz: aparece Default con exactamente esos datos, y la raíz queda sin ellos.
- [ ] Sin datos: se crea un Default vacío.
- [ ] Idempotente: abrir dos veces no crea un segundo proyecto ni duplica archivos.
- [ ] Si falla a mitad (archivo de destino ya existe, error de E/S), no se borra ningún original y el siguiente arranque reintenta.
- [ ] Los `.corrupt-*` y `.tmp-*` de la raíz no se tratan como datos.

**Verification:** `fvm flutter test test/engine/projects` (con carpetas temporales)

**Dependencies:** P1

**Files likely touched:** `lib/engine/projects/legacy_migration.dart`,
`lib/engine/projects/projects_repository.dart`, tests

**Estimated scope:** Small–Medium (3 archivos)

## P3: El proyecto activo decide el store; todo recarga al cambiar

**Description:** `projectsRepositoryProvider` (por defecto, un solo proyecto sobre
`JsonStore()`), `activeProjectProvider` y `jsonStoreProvider` derivado del activo.
Los providers de ambientes, colecciones, flows, historial y notas de hosts pasan a
`watch`. Se reinicia el estado de UI no persistido. `main.dart` crea el
repositorio real, migra y lo inyecta. **Empieza con un spike** de media hora:
cambiar de proyecto en un test de providers y ver qué queda sin recargar.

**Acceptance criteria:**
- [ ] Con dos proyectos y datos distintos, cambiar el activo cambia ambientes, colecciones, flows, historial y notas.
- [ ] Tras cambiar no queda request abierta, borrador, respuesta ni resultado de flow del proyecto anterior.
- [ ] La sesión de tokens de un ambiente no aparece en otro proyecto.
- [ ] Sin sobreescribir el repositorio, la app se comporta como hoy: los 693 tests y los 68 recorridos pasan sin tocarlos.
- [ ] Un envío en curso al cambiar de proyecto no escribe su historial en el proyecto nuevo.

**Verification:** `fvm flutter test` · `fvm flutter test test/integration` · `fvm flutter analyze`

**Dependencies:** P1, P2

**Files likely touched:** `lib/ui/projects/projects_provider.dart`, `lib/main.dart`,
`lib/ui/environments/environments_provider.dart` y los otros cinco providers que usan
el store, tests

**Estimated scope:** Medium–Large (9+ archivos); partir en dos commits si crece.

### Checkpoint: Core
- [ ] `fvm flutter analyze` limpio
- [ ] `fvm flutter test` y `fvm flutter test test/integration` verdes
- [ ] Revisar con el humano antes de la UI

## P4: Selector de proyecto en el header

**Description:** Botón junto al logo con nombre y punto de color; menú con la lista
(activo marcado). El arnés de recorridos se amplía: monta la app sobre un
repositorio en memoria con el store de siempre como Default, así los recorridos
actuales no cambian.

**Acceptance criteria:**
- [ ] El header muestra el nombre y el color del proyecto activo.
- [ ] El menú lista los proyectos y elegir uno lo activa y recarga la app.
- [ ] Con un solo proyecto el selector sigue visible y no estorba al layout con el header en una o varias líneas.
- [ ] Los 68 recorridos existentes pasan sin cambios.

**Verification:** tests de widgets · `fvm flutter test test/integration` · `fvm flutter test integration_test -d windows`

**Dependencies:** P3

**Files likely touched:** `lib/ui/projects/project_switcher.dart`, `lib/app.dart`,
`lib/ui/shell/app_header.dart`, `integration_test/support/journey_harness.dart`,
tests

**Estimated scope:** Medium (5 archivos)

## P5: Crear, renombrar y eliminar, con recorrido de proyectos

**Description:** Diálogos de nuevo proyecto (nombre, color), renombrar y eliminar
(confirmación que nombra el proyecto y lo que se pierde). Journey 11 de integración.

**Acceptance criteria:**
- [ ] Un proyecto nuevo nace vacío y pasa a ser el activo; los errores de nombre se muestran en el diálogo.
- [ ] Renombrar conserva todos los datos; eliminar pide confirmación y no se ofrece para el último.
- [ ] Recorrido: lo creado en un proyecto no aparece en el otro (carpeta, request, variable de ambiente, flow, nota de host) y volver lo muestra intacto.
- [ ] Recorrido: tras reiniciar, el proyecto activo y los datos de cada uno siguen ahí (runner de disco).

**Verification:** `fvm flutter test test/integration` · `fvm flutter test integration_test -d windows`

**Dependencies:** P4

**Files likely touched:** `lib/ui/projects/project_dialogs.dart`,
`lib/ui/projects/project_switcher.dart`, `integration_test/journeys/projects_journey.dart`,
ambos runners

**Estimated scope:** Medium (5 archivos)

### Checkpoint: Proyectos
- [ ] analyze limpio, `fvm flutter test`, ambos runners verdes
- [ ] Revisar con el humano

## P6: Recorte del cuerpo y límite global

**Description:** Al guardar una entrada, el cuerpo se trunca a 100 KB y se marca
(`truncated`); el modelo se lee sin romper historiales viejos. Límite global de
500 entradas por proyecto (se descartan las más antiguas) además del de 20 por
endpoint; también se aplica al leer un historial ya grande. La UI indica "cuerpo
truncado".

**Acceptance criteria:**
- [ ] Un cuerpo de 300 KB se guarda con ≤ 100 KB y `truncated: true`; uno pequeño no cambia.
- [ ] Con 520 entradas repartidas en varios endpoints quedan 500, las más recientes.
- [ ] Un `history.json` anterior (sin el campo nuevo) se lee sin error.
- [ ] El truncado respeta los límites de carácter (no corta un par UTF-16).
- [ ] Las vistas de History muestran el aviso cuando el cuerpo está truncado.

**Verification:** `fvm flutter test test/engine test/ui/history` · analyze

**Dependencies:** P3

**Files likely touched:** `lib/engine/models/history_entry.dart` (+freezed),
`lib/engine/storage/json_store.dart`, `lib/ui/history/*`, tests

**Estimated scope:** Medium (6 archivos)

## P7: Borrar historial

**Description:** Acción "Borrar historial" del proyecto activo con confirmación, en
la pantalla History.

**Acceptance criteria:**
- [ ] Pide confirmación; cancelar no borra nada.
- [ ] Confirmar vacía el historial solo del proyecto activo, y la pantalla y la pestaña de cada request quedan vacías.
- [ ] Recorrido: enviar, borrar, ver vacío, enviar de nuevo y ver una sola entrada.

**Verification:** tests de widgets · recorrido (ambos runners)

**Dependencies:** P6

**Files likely touched:** `lib/engine/storage/json_store.dart`, `lib/ui/history/history_screen.dart`,
`integration_test/journeys/history_journey.dart`, tests

**Estimated scope:** Small–Medium (4 archivos)

## P8: Formato del workspace y exportar (motor)

**Description:** `WorkspaceFile` (formato, versión 1) y `exportWorkspace(store, project)`:
ambientes, colecciones, flows y notas; secretos vacíos; sin historial, tokens,
ambiente activo ni estado de UI. Parseo con errores tipados.

**Acceptance criteria:**
- [ ] Un proyecto exportado y parseado devuelve los mismos datos, salvo los valores secretos.
- [ ] Las variables secretas salen con `secret: true` y `value: ""`; las no secretas conservan su valor.
- [ ] El JSON no contiene historial ni ningún token de sesión (test con un token conocido).
- [ ] Un archivo que no es del formato, está roto, o tiene una versión mayor, falla con un error que explica por qué.

**Verification:** `fvm flutter test test/engine/workspace`

**Dependencies:** P1

**Files likely touched:** `lib/engine/workspace/workspace_file.dart`,
`lib/engine/workspace/export_workspace.dart`, tests

**Estimated scope:** Medium (4 archivos)

## P9: Importar como proyecto nuevo (motor)

**Description:** `importWorkspace(repository, file)`: crea un proyecto con nombre
único (`commodo`, `commodo (2)`…), ids regenerados de ambientes, grupos, endpoints y
flows (referencias remapeadas), notas de hosts, y lo deja activo si se pide.
Devuelve cuántas variables secretas quedaron vacías.

**Acceptance criteria:**
- [ ] Todos los ids del proyecto importado son nuevos, y los pasos de los flows apuntan a los endpoints nuevos.
- [ ] Importar dos veces el mismo archivo da dos proyectos independientes con nombres únicos.
- [ ] Un archivo inválido no crea ninguna carpeta ni entrada del índice.
- [ ] Si algo falla a mitad, se elimina el proyecto parcial.
- [ ] Devuelve el número de secretos pendientes; el ambiente activo del proyecto importado es válido o ninguno.

**Verification:** `fvm flutter test test/engine/workspace`

**Dependencies:** P1, P8

**Files likely touched:** `lib/engine/workspace/import_workspace.dart`, tests

**Estimated scope:** Medium (3 archivos)

## P10: Acciones de exportar e importar en la UI

**Description:** "Exportar workspace…" e "Importar workspace…" en el menú del
selector, con `WorkspaceFileDialogs` inyectable (guardar y abrir archivo; el real usa
`file_picker`). Avisos: éxito, cuántos secretos hay que rellenar, errores de archivo.

**Acceptance criteria:**
- [ ] Exportar propone `<nombre>.workspace.json`, escribe el archivo y avisa; cancelar el diálogo no hace nada ni muestra error.
- [ ] Importar crea el proyecto, lo activa y avisa "N variables secretas por rellenar".
- [ ] Un archivo inválido muestra un mensaje claro y no cambia nada.
- [ ] Un fake de `WorkspaceFileDialogs` permite probarlo en widgets y recorridos.

**Verification:** tests de widgets · `fvm flutter analyze`

**Dependencies:** P5, P9

**Files likely touched:** `lib/ui/workspace_transfer/*`, `lib/ui/projects/project_switcher.dart`, tests

**Estimated scope:** Medium (5 archivos)

## P11: Recorrido ida y vuelta, docs y corridas finales

**Description:** Journey 12: exportar el proyecto de demo → importar → comprobar. README
y `SPEC.md` al día, criterios del spec marcados, corridas finales.

**Acceptance criteria:**
- [ ] Recorrido: tras exportar e importar, el proyecto nuevo tiene las mismas colecciones, flows, ambientes y notas; los secretos vacíos; sin historial; y editar uno no cambia el otro.
- [ ] Recorrido: importar un archivo inválido deja la lista de proyectos igual.
- [ ] README explica proyectos, exportar e importar (y qué no se exporta).
- [ ] Final: analyze limpio, `fvm flutter test`, `test/integration` e `integration_test -d windows` verdes.
- [ ] Cada criterio de `SPEC-workspaces.md` marcado o con el motivo.

**Verification:** las cuatro corridas finales

**Dependencies:** P7, P10

**Files likely touched:** `integration_test/journeys/workspace_transfer_journey.dart`, ambos runners,
`README.md`, `SPEC.md`, `SPEC-workspaces.md`

**Estimated scope:** Medium (6 archivos)

---

## Risks and mitigations

| Riesgo | Impacto | Mitigación |
|---|---|---|
| Estado que sobrevive al cambio de proyecto (request abierta, respuesta, flow) | Alto: datos de un proyecto en otro | Spike al inicio de P3 y criterio explícito de reinicio |
| Cambiar los providers a `watch` rompe tests existentes | Medio | El repositorio por defecto es de un solo proyecto; se corre toda la suite en cada paso |
| La migración pierde datos | Alto | Copiar, verificar y solo entonces borrar; idempotente; tests con carpetas temporales |
| Un envío en curso escribe en el proyecto equivocado | Medio | El store se captura al iniciar el envío (criterio de P3) |
| Archivo de importación hostil o enorme | Medio | Validar antes de crear nada; límite de tamaño razonable; ids siempre regenerados |
| Tiempo de la corrida en Windows (~4 min) | Bajo | Correrla al final de cada fase, no de cada tarea |

## Open questions

- ¿Los límites del historial (100 KB, 500 entradas) son los deseados? Se pueden cambiar sin tocar el diseño.
- El archivo de importación, ¿tiene un tamaño máximo (por ejemplo 10 MB)? Propongo sí, 10 MB.
