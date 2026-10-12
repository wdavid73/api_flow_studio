# Spec: secondary-screens

Módulo 4 de [SPEC-ui-redesign.md](SPEC-ui-redesign.md). Depende de
[`ui-theme`](SPEC-ui-theme.md) y [`app-shell`](SPEC-app-shell.md), ya
implementados. No depende de `workspace`, pero reutiliza sus patrones
(panel de lista de 300px, filas seleccionadas, botones fantasma, `kicker`).

## Objective

Llevar las pantallas Environments, Flows (constructor y vista de ejecución) e
History al mismo lenguaje visual que el Workspace, y convertir el destino
History —hoy un texto "History placeholder"— en una pantalla global de
historial. De paso corregir una etiqueta engañosa de Environments.

**Usuario:** el desarrollador dueño de la app.

**Éxito:** las cuatro pantallas se ven coherentes con el Workspace (mismos
paneles, filas, botones, estados vacíos); History lista todos los envíos
guardados y permite saltar al request; todo lo que ya funciona en
Environments y Flows sigue funcionando igual.

## Decisiones ya tomadas

- **History es una pantalla global** (lista de todos los envíos de todos los
  requests guardados), no se quita del menú.
- **Solo restyling en Environments y Flows**: sin lógica ni modelos nuevos.
- **El único cambio de motor es aditivo**: `JsonStore.readAllHistory()` para
  la pantalla de historial.
- **Los textos se quedan en inglés**, como el resto de la app.
- Solo se registra historial de requests guardados (comportamiento actual);
  los envíos de un borrador sin guardar no aparecen.

## Comportamiento

### Patrón compartido (lista a la izquierda, detalle a la derecha)
- Environments y Flows usan un panel de lista de 300px con borde derecho
  `outlineVariant`, cabecera con rótulo `kicker` y botón fantasma de crear, y
  a la derecha el editor flexible.
- Fila seleccionada: fondo `surfaceContainerHigh`, radio 8, sin la barra
  lateral de color actual; hover `surfaceContainer`.
- Botones secundarios con `HeaderGhostButton`; el principal con el filled
  lima del tema.
- Estados vacíos en `onSurfaceVariant`, centrados, con el mismo texto de hoy.

### Environments
- Cabecera de la lista: `ENVIRONMENTS` (kicker) y `New Environment` fantasma.
- Punto de color de cada ambiente: **rojo (`error`) si es de producción**
  (misma regla `isProductionEnvironment` del shell) y, si no, cíclico entre
  `primary`, `tertiary` y `secondary`. Se reemplaza la paleta actual
  `[tertiary, secondary, error]`, donde el rojo caía en el tercero aunque no
  fuera prod.
- **Corrección:** la etiqueta `ACTIVE` hoy aparece en el ambiente
  *seleccionado en el editor*, no en el activo de verdad (el de la pastilla
  del header). Pasa a mostrarse solo en el ambiente que es
  `activeEnvironmentId`. Un ambiente de producción lleva además la etiqueta
  `PROD` en `error`.
- Fila: nombre en `headlineSm`, `N variables` debajo en `bodySm`, botón de
  borrar con el estilo actual.
- Editor: título del ambiente seleccionado, cabecera de tabla (`NAME`,
  `VALUE`, `SECRET`) en `kicker`, filas con campos redondeados del tema,
  `Add variable` fantasma y la tarjeta de consejo con `surfaceContainer`.

### Flows (lista y constructor)
- Lista: igual que Environments (`FLOWS` + `New flow`).
- Constructor: campo de nombre, `Save` fantasma, `Run` lima; tarjetas de paso
  con `MethodBadge`, nombre del request, y los bloques de extracciones y
  aserciones en filas con campos del tema; `Add step` fantasma al final.
- El selector de pasos (`add_step_picker`) ya usa tokens; solo se alinea con
  los chips de método del sidebar (misma cuadrícula y estilo de chip).

### Flows (vista de ejecución)
- Franja de resumen arriba: `N passed` en `tertiary`, `N failed` en `error`,
  `N skipped` en `outline`, con el tiempo total; botones `Back` y `Re-run`.
- Tarjetas de paso con icono y color por estado (pasó `tertiary`, falló
  `error`, omitido `outline`); la seleccionada con `surfaceContainerHigh` y
  borde `primary`.
- Inspector del paso (derecha): estilo del panel de respuesta
  (`responseBackground`, estado en línea `200 · 124 ms · 512 B`, bloque de
  código `surfaceContainerLowest`); el panel de error con
  `errorContainer`.

### History (pantalla global)
- Motor: `JsonStore.readAllHistory()` devuelve todas las entradas guardadas
  (de todos los endpoints) en una lista plana, la más reciente primero.
- Cabecera: kicker `HISTORY`, título `Request history`, campo de búsqueda
  (`Filter history…`) que busca en nombre, método y URL del request.
- Cada fila: `MethodBadge`, nombre del request, URL en mono `onSurfaceVariant`
  con elipsis, y a la derecha `StatusBadge` (o `Error` en `error` si falló),
  `124 ms` y la hora (`HH:mm`).
- Agrupado por día con cabeceras `kicker`: `TODAY`, `YESTERDAY` o la fecha
  (`2026-10-02`).
- Método, nombre y URL salen del request guardado (la entrada solo guarda el
  `endpointId`). Si el request ya no existe, la fila muestra
  `Deleted request`, sin método ni URL, y no es pulsable.
- Pulsar una fila abre ese request en el Workspace: carga el endpoint en el
  borrador y cambia el destino a Workspace.
- Vacío: `No history yet — send a saved request.`; sin coincidencias con la
  búsqueda: `Nothing matches that search.`
- Sin acciones destructivas (no hay "borrar historial" en esta versión).

## Tech Stack

Flutter 3.44.6 (FVM), Material 3, `flutter_riverpod`. Sin dependencias
nuevas. Tokens y widgets de `ui-theme`; `HeaderGhostButton`, `showToast` y
`isProductionEnvironment` de `app-shell`; `MethodBadge` y `StatusBadge` de
`ui-theme`.

## Commands

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test test/engine/storage test/ui/environments test/ui/flows test/ui/history test/ui/secondary
fvm flutter test
fvm flutter run -d windows
```

## Project Structure

```
lib/engine/storage/json_store.dart      → + readAllHistory() (aditivo)
lib/ui/history/
  history_screen.dart                   → pantalla global
  history_row.dart                      → fila de la lista global
  all_history_provider.dart             → carga y ordena las entradas
lib/ui/shared/
  list_detail_layout.dart               → panel de lista 300px + detalle (Environments, Flows)
lib/ui/environments/                    → restyling; ajuste de etiqueta ACTIVE y punto prod
lib/ui/flows/                           → restyling de lista, constructor, vista de ejecución
lib/ui/theme/app_colors.dart            → environmentDotPalette actualizada
lib/app.dart                            → History destination usa HistoryScreen
test/engine/storage/                    → readAllHistory
test/ui/history/, test/ui/environments/, test/ui/flows/
```

## Code Style

Igual que el resto de `lib/ui`: widgets `const`, estado en Riverpod, tokens
de `AppColors`/`AppTypography`/`AppRadius`, sin hex sueltos, `Key`s estables
en lo que prueban los tests. Motor puro, sin Flutter:

```dart
/// Every stored history entry across all endpoints, newest first.
Future<List<HistoryEntry>> readAllHistory() async {
  final all = await _readAllHistory();
  return [for (final entries in all.values) ...entries]
    ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
}
```

## Testing Strategy

- **Motor:** `readAllHistory` — vacío, varios endpoints mezclados y orden
  más reciente primero (con el almacén en memoria y con uno en disco).
- **Widget:**
  - History: filas con método/nombre/URL/estado/tiempo; agrupación por día;
    fila de request borrado no pulsable; pulsar una fila carga el endpoint y
    cambia a Workspace; búsqueda y mensajes de vacío.
  - Environments: la etiqueta `ACTIVE` solo en el ambiente activo; `PROD` en
    los de producción; punto rojo solo si es prod; selección sin cambiar el
    activo.
  - Flows: estados de las tarjetas de ejecución con sus colores; franja de
    resumen.
- **Regresión:** `environment_manager_screen_test`, `flow_builder_screen_test`,
  `flow_run_view_test`, `flow_run_view_detail_test`, `step_card_editor_test` y
  `app_shell_test` se actualizan, no se borran.
- **Visual:** comparar con el Workspace en ≥1100px, con una colección y
  ejecuciones de ejemplo.

## Boundaries

- **Always:** conservar las `Key` que usan los tests; tokens de `ui-theme`;
  `analyze` y `test` antes de cada commit; tests antes del código.
- **Ask first:** añadir campos a `Environment`, `Flow` o `HistoryEntry` (p. ej.
  guardar método y URL en cada entrada); añadir "borrar historial"; añadir
  dependencias.
- **Never:** tocar la lógica de ejecución de flujos, el `flow_runner`, el
  `request_executor` ni los modelos; borrar tests que fallen en lugar de
  actualizarlos; cambiar el comportamiento de crear/borrar/guardar.

## Success Criteria

- [ ] Environments y Flows con el panel de lista de 300px y detalle a la
  derecha; filas, botones y vacíos con el estilo del Workspace.
- [ ] `ACTIVE` solo en el ambiente realmente activo; `PROD` y punto rojo solo
  en ambientes de producción.
- [ ] Vista de ejecución de Flows con franja de resumen, tarjetas por estado
  e inspector estilo respuesta.
- [ ] `JsonStore.readAllHistory()` con tests.
- [ ] Pantalla History con filas, agrupación por día, búsqueda, estado vacío,
  fila de request borrado y salto al Workspace.
- [ ] Tests actualizados; `fvm flutter analyze` limpio; `fvm flutter test`
  verde.
- [ ] Comparación visual hecha en las cuatro pantallas.

## Open Questions

1. La pantalla de historial obtiene método, nombre y URL del request
   guardado porque `HistoryEntry` solo guarda el `endpointId`. Si borras un
   request, sus entradas quedan como `Deleted request`. ¿Te sirve, o prefieres
   que cada entrada guarde método y URL al enviarse (cambio de modelo y de
   JSON guardado)? Propuesta: dejarlo como está.
2. ¿Quieres un botón para borrar el historial? Propuesta: no en esta versión
   (es destructivo y queda fuera del rediseño).
