# Spec: proyectos (workspaces) y workspace exportable

Spec de una feature de API Flow Studio, aparte de `SPEC.md` (que describe el
producto y su rediseño). Los tests de integración existentes
(`SPEC-integration-tests.md`) son la red de seguridad de esta feature.

## Objective

Hoy la app tiene **un solo conjunto de datos**: ambientes, colecciones, flows,
historial y notas de hosts son globales. Quien trabaja en varios productos
(`commodo` en el trabajo, `fin_track_pro` en lo personal) ve todo mezclado.

Esta feature agrega **proyectos**: unidades aisladas, cada una con sus propios
ambientes, colecciones, flows, historial y notas de hosts. Se cambia de proyecto
desde el header. Un proyecto se puede **exportar a un archivo** y otra persona
lo puede **importar** como proyecto nuevo.

Usuarios: una persona que alterna entre varios productos en la misma máquina, y
un equipo que quiere pasarse la configuración de una API sin compartir secretos.

Fuera de alcance: nube o sincronización, colaboración en vivo, cuentas, y
cambiar el motor de almacenamiento (se mantiene JSON local; ver Open Questions).

## Decisiones ya tomadas

- Aislamiento total entre proyectos: nada se comparte (ni variables globales ni
  ambientes comunes).
- Almacenamiento local, una carpeta por proyecto, JSON como hoy.
- Los datos actuales pasan a un proyecto **Default** al primer arranque; no se
  pierde nada.
- Exportar: **un solo `.json`** con número de versión del formato.
- Exportar **vacía los valores de las variables secretas** (se conservan el
  nombre y la marca de secreto). Los tokens de sesión nunca se exportan.
- Exportar **no incluye el historial**.
- Importar **siempre crea un proyecto nuevo** (nombre único, ids regenerados).
  Nunca pisa ni mezcla datos existentes.
- La sesión de tokens sigue siendo por ambiente y en memoria; queda aislada por
  proyecto sin cambios, porque las claves de ambiente son únicas por proyecto.
- El historial se acota: límite de tamaño del cuerpo guardado, límite global por
  proyecto y acción "Borrar historial".

## Mapa de capacidades

| # | Módulo | Depende de | Qué entrega |
|---|---|---|---|
| 1 | `projects-core` | — | Índice de proyectos, un `JsonStore` por proyecto, proyecto activo, migración a Default, providers que recargan al cambiar |
| 2 | `projects-ui` | 1 | Selector en el header con color; crear, renombrar, eliminar |
| 3 | `history-limits` | 1 | Recorte del cuerpo, límite global, borrar historial |
| 4 | `workspace-transfer` | 1, 2 | Exportar proyecto a `.json`; importar como proyecto nuevo |

Orden de construcción: 1, 2, 3, 4. El 3 es independiente del 2.

## Comportamiento

### 1. projects-core

- Existe un **índice** `projects.json` en la carpeta de datos con la lista de
  proyectos (`id`, `name`, `colorIndex`, `createdAt`) y el `activeProjectId`.
- Cada proyecto vive en `projects/<id>/` con los archivos de hoy:
  `environments.json`, `settings.json`, `collections.json`, `flows.json`,
  `history.json`, `host_notes.json`.
- **Migración**: si no existe `projects.json` y sí existen archivos de datos en
  la raíz, se crea el proyecto **Default** moviendo esos archivos a su carpeta.
  Es idempotente: arrancar dos veces no duplica nada. Con datos vacíos se crea
  un Default vacío.
- `jsonStoreProvider` pasa a devolver el store del **proyecto activo**. Cambiar
  de proyecto recarga ambientes, sidebar, flows, historial y notas de hosts, y
  descarta la edición en curso y las respuestas mostradas del proyecto anterior.
- No se puede eliminar el último proyecto.
- En web (sin sistema de archivos) funciona en memoria, como hoy.

### 2. projects-ui

- Un selector de proyecto en el header, junto al logo, que muestra el nombre y
  un punto de color. El color distingue proyectos de un vistazo.
- Menú: lista de proyectos (el activo marcado), "Nuevo proyecto", "Renombrar",
  "Eliminar", "Importar workspace…", "Exportar workspace…".
- Nuevo proyecto: pide nombre (único, no vacío, hasta 40 caracteres) y asigna
  un color. Nace vacío y pasa a ser el activo.
- Eliminar: confirmación que nombra el proyecto y dice que se borran sus
  ambientes, colecciones, flows e historial. No se puede deshacer.
- Los avisos de producción siguen funcionando dentro de cada proyecto.

### 3. history-limits

- El cuerpo de cada respuesta guardada se **trunca** a un máximo (100 KB) y la
  entrada queda marcada como truncada; la UI lo indica.
- Se mantiene el límite por endpoint (20) y se agrega un **límite global por
  proyecto** (500 entradas): al superarlo se descartan las más antiguas.
- "Borrar historial" (por proyecto) con confirmación.
- Los límites se aplican al guardar y también al leer un historial ya grande.

### 4. workspace-transfer

Formato `.json`:

```json
{
  "format": "api-flow-studio-workspace",
  "version": 1,
  "exportedAt": "2026-10-03T10:00:00Z",
  "project": { "name": "commodo", "colorIndex": 3 },
  "environments": [], "collections": {}, "flows": [], "hostNotes": {}
}
```

- **Exportar**: abre el diálogo de guardado con `commodo.workspace.json`. Las
  variables secretas salen con `value: ""` y `secret: true`. Sin historial, sin
  tokens, sin ambiente activo ni estado de UI.
- **Importar**: elige un `.json`, lo valida y crea un proyecto **nuevo** con
  nombre único (`commodo`, `commodo (2)`…), ids de ambientes, grupos,
  endpoints y flows **regenerados** (referencias entre ellos remapeadas) y pasa
  a ser el activo. Tras importar se avisa cuántas variables secretas hay que
  rellenar.
- Un archivo inválido, de otra versión mayor o que no sea del formato se
  rechaza con un mensaje claro y **sin crear nada**.

## Tech Stack

Sin dependencias nuevas: Flutter 3.44.6 (FVM), Riverpod, freezed, `JsonStore`,
`file_picker` (ya está). Motor y UI separados como hoy: la lógica va en
`lib/engine/` (sin imports de Flutter), la interfaz en `lib/ui/`.

## Commands

```bash
fvm flutter test                          # unitarios y de widgets
fvm flutter test test/integration         # recorridos con la app completa, sin ventana
fvm flutter test integration_test -d windows   # recorridos con la app real
fvm flutter analyze
```

## Project Structure

```
lib/engine/projects/        # Project, ProjectIndex, ProjectStore, migración
lib/engine/workspace/       # WorkspaceFile (formato), exportar, importar, remapeo de ids
lib/engine/storage/         # JsonStore: truncado y límites del historial
lib/ui/projects/            # selector, diálogos, providers
lib/ui/workspace_transfer/  # acciones exportar / importar
integration_test/journeys/  # projects_journey.dart, workspace_transfer_journey.dart
```

## Code Style

El del repo: nombres y comentarios como el código vecino, motor sin Flutter,
providers Riverpod, modelos freezed, `Key`s en lo que un recorrido toca
(`project-switcher`, `project-option-<id>`, `new-project-button`,
`export-workspace-button`, `import-workspace-button`…).

## Testing Strategy

- **TDD por módulo.** Unitarios del motor: migración (con datos, sin datos,
  idempotente), aislamiento entre dos proyectos, remapeo de ids al importar,
  vaciado de secretos al exportar, validación de archivos inválidos, truncado y
  límites del historial.
- **Widgets**: selector, diálogos de crear, renombrar y eliminar.
- **Recorridos de integración** nuevos (ambos runners): cambiar de proyecto
  muestra otros datos; lo creado en uno no aparece en el otro; ida y vuelta
  exportar → importar conserva colecciones, flows, ambientes y notas, vacía los
  secretos y deja los dos proyectos independientes. El harness gana un
  directorio raíz de proyectos; los recorridos actuales siguen pasando sin
  cambios sobre un proyecto único.
- Los 693 tests existentes siguen verdes.

## Boundaries

- **Siempre**: migrar sin perder datos; validar el archivo antes de crear nada;
  pedir confirmación antes de eliminar un proyecto o borrar historial.
- **Preguntar antes**: cambiar el formato de archivos existentes de forma
  incompatible; agregar dependencias.
- **Nunca**: exportar valores secretos o tokens de sesión; importar sobre un
  proyecto existente; subir datos a ningún servicio externo; borrar los datos
  originales antes de comprobar que la migración terminó.

## Success Criteria

- [ ] Existen varios proyectos aislados; cambiar de proyecto cambia ambientes, sidebar, flows, historial y notas.
- [ ] Los datos de una instalación anterior aparecen en el proyecto Default, intactos.
- [ ] El selector del header muestra nombre y color; crear, renombrar y eliminar funcionan, y el último proyecto no se puede eliminar.
- [ ] El historial guarda como máximo 100 KB por cuerpo y 500 entradas por proyecto, y se puede borrar.
- [ ] Un proyecto exportado e importado en otra instalación conserva colecciones, flows, ambientes y notas, con los secretos vacíos y sin historial.
- [ ] Importar nunca pisa un proyecto; un archivo inválido no crea nada y explica por qué.
- [ ] Recorridos de integración nuevos verdes en ambos runners; la suite existente intacta; `fvm flutter analyze` limpio.

## Open Questions

- Si el historial crece más allá de los límites, el siguiente paso sería moverlo
  a SQLite por proyecto. Queda fuera de esta feature.
- ¿Se quiere en el futuro compartir proyectos por git o carpeta sincronizada
  (abrir un proyecto desde una carpeta elegida)? Fuera de esta feature.
