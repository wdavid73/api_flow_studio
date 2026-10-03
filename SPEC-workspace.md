# Spec: workspace

Módulo 3 de [SPEC-ui-redesign.md](SPEC-ui-redesign.md). Depende de
[`app-shell`](SPEC-app-shell.md) (implementado: header, toast, banner).

## Objective

Rediseñar la pantalla Workspace según los tres paneles del playground de
Commodo: sidebar con búsqueda y filtro por método, constructor de request al
centro y respuesta a la derecha, con atajos de teclado y botones de copiar.

**Usuario:** el desarrollador dueño de la app.

**Éxito:** en una ventana ≥ 1100px se ven sidebar, request y respuesta lado a
lado; se puede buscar y filtrar por método, enviar con Ctrl/Cmd+Enter, copiar
la respuesta o el comando curl con un toast de confirmación y ver el historial
junto a la respuesta; todo lo que ya funciona (guardar, importar/exportar,
pegar curl, carpetas, pestañas) sigue funcionando.

## Decisiones ya tomadas

- **Tres paneles** (sidebar 300px | request flexible | respuesta flexible).
  Por debajo de 1100px la respuesta pasa debajo del request, como hoy.
- **El historial se mueve al panel de respuesta** (pestañas Response / History
  arriba a la derecha) y se quita la pestaña History del request.
- **Se conservan** las funciones actuales: árbol de carpetas, Save, pestañas
  Docs/Params/Headers/Body/Auth, pegar curl, importar/exportar, pestañas de
  respuesta Body/Headers/Cookies/Timeline.
- **Los textos de la UI se quedan en inglés** (así está hoy la app); el HTML
  está en español pero no se traduce.
- **El selector de versión v1/v2 de la barra de URL no entra aquí**: depende
  de las bases por ambiente y lo trae `hosts-notes`.
- **Los parámetros de path `{name}` del HTML no entran**: el modelo
  `Endpoint` no los tiene y la app ya usa `{{variable}}` para eso.

## Comportamiento

### Layout
- `Row`: sidebar 300px · `VerticalDivider` · request (flex 1) · divisor ·
  respuesta (flex 0.92), como el grid del HTML.
- Con ancho < 1100px: sidebar de ancho fijo a la izquierda y, a su derecha,
  request y respuesta en columna (respuesta debajo).
- Fondo del panel de respuesta: `AppColors.responseBackground`, con borde
  izquierdo `outlineVariant`.

### Sidebar
- Cabecera con el rótulo EXPLORER (estilo `kicker`) y las cuatro acciones
  actuales (carpeta, pegar curl, importar, exportar), sin cambio funcional.
- Campo de búsqueda `Filter requests…` con atajo `/` (enfoca la búsqueda
  cuando ningún campo de texto tiene el foco).
- Fila de chips de método: `All`, `GET`, `POST`, `PUT`, `PATCH`, `DELETE`,
  en cuadrícula de 3 columnas; el activo con fondo `onSurface` y texto
  `surface`; uno solo activo a la vez (`All` por defecto). Los chips de
  método usan los colores de `MethodBadge.colorForMethod` en el texto.
- El filtro de texto (ya existente) y el de método se combinan: un endpoint
  se muestra si pasa los dos; una carpeta se muestra si tiene al menos un
  descendiente que pasa. El texto busca en nombre, método, URL y descripción.
- Filas: `MethodBadge` en una columna de 54px + nombre del endpoint en
  JetBrains Mono 12px con elipsis; seleccionada con fondo
  `surfaceContainerHigh`, hover con `surfaceContainer`; radio 8.
- Cabeceras de grupo en `kicker` (mayúsculas, `outline`), con el contador de
  endpoints entre corchetes en las carpetas de primer nivel.
- Sin resultados: `Nothing matches that search.` (hoy no hay mensaje).
- Pie con la versión de la app, sin cambio.

### Request
- Cabecera: kicker con el nombre de la carpeta del endpoint (o `UNSAVED`
  para un borrador), título (`AppTypography.title`) con el nombre, y una
  línea con la descripción si existe.
- Barra de URL: selector de método (texto mono coloreado), campo de URL con
  resaltado de `{{variables}}`, botón `Save` fantasma y `Send` (lima).
- Pestañas en píldora: Docs, Params, Headers, Body, Auth, Tests, Settings
  (History sale). La activa con `surfaceContainerHigh`.
- Body: botón `Format JSON` y botón `Restore example` solo si el cuerpo es
  de tipo JSON; aviso en línea (`warning`) con el texto `Invalid JSON` cuando
  no parsea. No cambian los tipos de cuerpo existentes.
- `Ctrl/Cmd + Enter` en cualquier lugar del Workspace dispara Send (igual que
  pulsar el botón; no hace nada mientras ya hay un envío en curso).

### Respuesta
- Fila superior: pestañas `Response` / `History` a la izquierda; botones
  fantasma `Copy` y `curl` a la derecha.
- Línea de estado: punto de color + `StatusBadge`-style texto mono: código,
  `{elapsed} ms`, `{size} B`, separados por ` · `. Sin respuesta:
  `No response yet` y, debajo, `Pick a request and send. Cmd/Ctrl + Enter also sends.`
- `Response` conserva las pestañas internas Body/Headers/Cookies/Timeline.
  Body ocupa un bloque `surfaceContainerLowest` con radio `AppRadius.block`.
- `Copy` copia el cuerpo crudo y muestra el toast `Response copied`; sin
  respuesta muestra `Nothing to copy`.
- `curl` copia el comando curl de la petición actual (con las variables del
  ambiente activo ya resueltas) y muestra el toast `curl copied`.
- `History` muestra el historial del endpoint (el contenido de la pestaña
  actual): sin guardar, `Save this request to start recording history`; sin
  entradas, `No history yet — send a request`.

### Motor (cambio aditivo mínimo)
- Nuevo `lib/engine/curl/curl_builder.dart` con
  `String buildCurl(Endpoint endpoint, {Map<String, String> variables})`:
  `curl -X METHOD 'url'` con `-H` por header activo y `--data` si hay body,
  escapando comillas simples. Es el inverso del `curl_parser` existente y no
  importa `package:flutter`.

## Tech Stack

Flutter 3.44.6 (FVM), Material 3, `flutter_riverpod`. Sin dependencias
nuevas. Tokens, fuentes y widgets de `ui-theme`; toast, banner y header de
`app-shell` (`showToast`).

## Commands

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test test/engine/curl test/ui/workspace test/ui/collections test/ui/request_builder test/ui/response_viewer test/ui/history
fvm flutter test
fvm flutter run -d windows
```

## Project Structure

```
lib/ui/workspace/
  workspace_screen.dart         → los tres paneles y el cambio a apilado < 1100px
  workspace_shortcuts.dart      → Ctrl/Cmd+Enter y atajo "/"
lib/ui/collections/
  sidebar_tree.dart             → filtros, chips, filas nuevas (se parte si crece)
  method_filter_chips.dart      → chips de método + sidebarMethodFilterProvider
lib/ui/request_builder/
  request_bar.dart              → solo el constructor (sin respuesta embebida)
  request_header.dart           → kicker, título, descripción
lib/ui/response_viewer/
  response_panel.dart           → pestañas Response/History, estado, Copy/curl
lib/engine/curl/curl_builder.dart
lib/app.dart                    → Workspace usa WorkspaceScreen
test/engine/curl/curl_builder_test.dart
test/ui/workspace/
```

## Code Style

Igual que el resto de `lib/ui`: widgets `const`, estado en Riverpod, tokens de
`AppColors`/`AppTypography`/`AppRadius`, sin hex sueltos, `Key`s estables en
lo que prueban los tests. Ejemplo del estilo del motor (puro, sin Flutter):

```dart
/// Builds a curl command for [endpoint], resolving `{{vars}}` from [variables].
String buildCurl(Endpoint endpoint, {Map<String, String> variables = const {}}) {
  String quote(String value) => "'${value.replaceAll("'", r"'\''")}'";
  final lines = ["curl -X ${endpoint.method} ${quote(resolvedUrl)}"];
  // ...one "  -H 'k: v'" per enabled header, "  --data '...'" for a body
  return lines.join(' \\\n');
}
```

## Testing Strategy

- **Motor:** `curl_builder_test` — GET sin body, POST con JSON, comillas
  simples escapadas, headers desactivados omitidos, variables resueltas, y
  round-trip con `curl_parser` (parsear lo construido devuelve método, URL y
  headers).
- **Widget:**
  - Sidebar: el filtro de método oculta endpoints de otros métodos; combinado
    con texto; carpeta sin coincidencias se oculta; mensaje de sin resultados.
  - Request: header con carpeta/nombre/descripción; pestañas sin History;
    `Format JSON` reformatea y `Invalid JSON` aparece con JSON roto.
  - Respuesta: línea de estado; `Copy` y `curl` ponen texto en el portapapeles
    y muestran su toast; pestaña History con los tres estados.
  - Atajos: Ctrl+Enter envía una vez y no durante un envío en curso; `/`
    enfoca la búsqueda y no actúa con un campo de texto enfocado.
  - Layout: a 1440px tres paneles en una fila; a 900px respuesta debajo.
- **Regresión:** `sidebar_tree_test`, `request_bar_test`, `history_wiring_test`,
  `history_panel_test` y `response_panel_test` se actualizan (History ya no
  está en el request), no se borran.
- **Visual:** comparar con el HTML a ≥1100px y < 1100px, con endpoints
  importados desde `sample-endpoints.json`.

## Boundaries

- **Always:** conservar las `Key` que usan los tests salvo las de la pestaña
  History del request (que se reubican); tokens de `ui-theme`; `analyze` y
  `test` antes de cada commit; tests antes del código.
- **Ask first:** añadir campos a `Endpoint` o a la persistencia; añadir
  dependencias; cambiar atajos fuera de los dos definidos; traducir textos.
- **Never:** tocar el motor fuera de `curl_builder.dart`; implementar el
  selector de versión, la sesión o los hosts (otros módulos); cambiar el
  comportamiento de Save, importar/exportar o pegar curl; borrar tests que
  fallen en lugar de actualizarlos.

## Success Criteria

- [ ] A ≥1100px: sidebar 300px, request y respuesta lado a lado; a < 1100px
  la respuesta queda debajo, sin overflow.
- [ ] Búsqueda + chips de método filtran el árbol como se describe, con
  mensaje de sin resultados.
- [ ] Filas del sidebar con `MethodBadge` en columna de 54px y selección
  resaltada.
- [ ] Request con kicker/título/descripción, pestañas sin History y botones
  `Format JSON` / aviso `Invalid JSON` en Body.
- [ ] `buildCurl` en el motor con tests, incluido el round-trip con el parser.
- [ ] Panel de respuesta con pestañas Response/History, línea de estado,
  `Copy` y `curl` con sus toasts.
- [ ] Ctrl/Cmd+Enter envía; `/` enfoca la búsqueda.
- [ ] Tests actualizados; `fvm flutter analyze` limpio; `fvm flutter test`
  verde.
- [ ] Comparación visual con el HTML hecha en ambos anchos.

## Open Questions

1. Las filas del sidebar muestran el **nombre** del endpoint; el HTML muestra
   el path. ¿Prefieres nombre (como hoy), o el path de la URL en mono?
2. `Format JSON` y `Restore example`: la app no guarda "ejemplo" por endpoint.
   ¿Dejo solo `Format JSON` y omito `Restore example`? (propuesta: sí, omitirlo).
