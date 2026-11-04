# Spec: flow-canvas

Rediseño del editor de **Flows**: de una lista vertical de tarjetas a un **canvas
ordenado** donde cada paso muestra lo que usa y lo que devuelve, y los datos entre
pasos se conectan arrastrando un campo de la respuesta en vez de escribir rutas a
mano. Mockup elegido: opción **B** de la sesión de diseño (canvas ordenado, con la
respuesta dentro de cada paso).

## Objective

Armar un flujo básico (registro → login → get user → home) tomó mucho más de lo
esperado. No por el orden de los pasos, sino porque el editor **nunca muestra qué
devuelve cada request**: para extraer un dato hay que ir a Workspace, enviar el
request, leer el JSON, volver a Flows y escribir `response.body.x.y` a ciegas, y
después abrir otra pantalla para correr el flujo y ver si funcionó.

Este módulo pone la respuesta real **dentro** del editor y convierte "extraer una
variable" en un gesto: arrastrar el campo hasta la entrada del paso que lo necesita.

**Usuario:** el desarrollador dueño de la app.

**Éxito:** el flujo registro → login → get user → home se arma en pocos minutos,
sin escribir ninguna ruta a mano y sin salir de la pantalla de Flows; de un vistazo
se ve qué variable usa cada paso, de dónde sale y cuál no tiene origen.

### Goals
- Ver en cada paso los campos de su última respuesta real.
- Ver en cada paso las `{{variables}}` que usa y de dónde sale cada una
  (otro paso, environment, generada, sesión) o que no tiene origen.
- Conectar un campo de la respuesta con la entrada de otro paso arrastrando, o con
  un clic ("Usar como variable").
- Correr el flujo, o solo hasta un paso, en el mismo canvas.

### Non-goals (v1)
- Ramas Success/Fail, loops, condiciones, delays o bloques que no sean requests.
- Posicionar nodos a mano o guardar posiciones.
- Editar el request (URL, headers, body) desde el canvas: eso sigue en Workspace.

### Anti-goals (aunque funcione, sería un fracaso si…)
- …el canvas se vuelve un enredo de cables como un canvas libre: el layout es
  automático y un cable solo existe donde hay un dato que viaja.
- …el caso común todavía obliga a escribir una ruta a mano.
- …un flujo guardado, un archivo de flujos exportado o el runner de terminal dejan de
  funcionar igual que hoy.

## Decisiones

Acordadas en la sesión de diseño:

1. **Canvas ordenado, no libre.** Los pasos se colocan solos en una fila de izquierda
   a derecha, en el orden del flujo. Con muchos pasos el canvas se desplaza y tiene zoom.
2. **Cada nodo trae dentro su respuesta** (los campos, con un pin cada uno) y sus
   **entradas** (las `{{variables}}` del request, con su origen).
3. **Conectar = arrastrar** el pin de un campo a una entrada de un paso posterior, o
   clic en el campo → "Usar como variable". Se **sugieren** conexiones por nombre.
4. **El modelo no cambia.** Un cable es exactamente lo que ya existe: un `extract`
   (`user_id ← response.body.user.id`) en el paso de origen, más el `{{user_id}}` que
   el request del paso destino ya contiene. No se guardan cables ni posiciones.
5. **Panel lateral** al hacer clic en un nodo para lo que no cabe en el nodo:
   assertions, stop on failure, extracts escritos a mano, respuesta completa,
   resultado de la última ejecución.
6. **Ejecutar pinta el resultado sobre el mismo canvas.** La pantalla aparte
   (`FlowRunViewScreen`) desaparece; sus piezas se reutilizan en el panel lateral.
7. **El token del login lo maneja la sesión que ya existe** (`SessionRequestExecutor`):
   el canvas lo muestra (🔑) en vez de pedir que se extraiga.

Decididas por mí al escribir este documento (marcadas **[mía]** donde aparecen; revisar):
ver la lista al final, en *Decisiones a revisar*.

## Modelo y compatibilidad

**Sin cambios** en `Flow`, `FlowStep`, `Assertion`, `flows.json`, el archivo de
flujos (`flowsFileVersion = 1`), el archivo de workspace ni el runner de terminal.
Todo lo nuevo se calcula a partir de lo que ya se guarda:

| En el canvas | Sale de |
|---|---|
| Orden de los nodos | `Flow.steps` |
| Entradas de un nodo | los `{{nombre}}` del `Endpoint` del paso |
| Origen de una entrada | `extract` de pasos anteriores, environment activo, sesión |
| Campos de la respuesta | última respuesta conocida del paso (ver *Fuente de la respuesta*) |
| Un cable | `steps[j].extract[nombre]` + `{{nombre}}` en el request de un paso `i > j` |

Única extensión del engine: `FlowRunner.runFrom` acepta un `endIndex` opcional
(inclusive) para "Ejecutar hasta aquí". Sin él, se comporta como hoy.

## Conceptos

### Entradas de un paso

`stepInputs(Endpoint)` devuelve, sin duplicados y en orden de aparición, cada
`{{nombre}}` (`\{\{(\w+)\}\}`) que aparece en: la URL; key y value de los query
params **habilitados**; key y value de los headers **habilitados**; el body (raw de
`json`; campos habilitados de `formUrlEncoded`; nombre, valor y content type de los
campos habilitados de `multipart`); y `authConfig` (`basic`: usuario y contraseña;
`bearer`: token). Los tokens generados (`{{$uuid}}`, `{{$randomEmail}}`…) se devuelven
aparte: se muestran como "generado" y no tienen pin.

Además, el nodo muestra una entrada fija **"Authorization · 🔑 sesión"** cuando la
sesión del environment activo tiene `attachAuth` encendido y el request la aceptaría
(misma regla que `applySession`: `authConfig` es `none` y no hay header
`Authorization` habilitado). No tiene pin.

Las `{{variables}}` del valor esperado de una assertion **no** son entradas del nodo
en v1: no se envían, solo se comparan. **[mía]**

### Origen de una entrada

`resolveInputOrigin(flow, stepIndex, nombre, envVars)` sigue la misma precedencia que
el runner al ejecutar:

1. **Paso anterior:** el paso `j < stepIndex` más cercano cuyo `extract` contiene
   `nombre` → `fromStep(j, ruta)`. (Los extracts de un paso nunca alimentan sus
   propias entradas: se calculan después de enviarlo.)
2. **Environment:** `nombre` existe en las variables resueltas del environment activo.
3. **Sesión:** `nombre` es `session_access_token` o `session_refresh_token`.
4. **Sin origen** → la entrada se marca "⚠ sin origen".

Si el origen es "sin origen" pero un paso anterior tiene un campo que encaja por
nombre, se muestra una **sugerencia** (ver *Sugerencias*).

### Campos de la respuesta

`responseFields(body, {limit = 200})` aplana un body JSON decodificado (`Map` o
`List`) en hojas, cada una con su ruta completa (`response.body.user.id`) y una vista
previa corta del valor (texto recortado a ~24 caracteres). En una lista solo se
expande el elemento `0` (`items.0.id`) y la lista misma aparece como hoja con su
longitud (`items [3]`). Más allá de `limit` hojas se corta y se informa cuántas
quedaron fuera. Si el body no es JSON, no hay campos (el panel muestra el texto).

El nodo muestra la ruta **sin** el prefijo `response.body.` y como mucho **8 campos**;
"+N más" abre el panel en la pestaña Respuesta, donde están todos, además de
`status` y headers. **[mía]**

Un campo que coincide con lo que la sesión captura (`findTokens`: `accessToken`,
`access_token`, `refreshToken`, `refresh_token`) lleva la etiqueta "🔑 → sesión"
cuando la sesión tiene `captureTokens` encendido. Sigue teniendo pin.

### Fuente de la respuesta de un nodo

En orden:

1. El resultado de ese paso en la **última ejecución de este flujo en la sesión de la
   app** (memoria). Etiqueta: "última ejecución · hace 2 min".
2. La entrada más reciente del **historial** del endpoint (`historyProvider`) que
   tenga body. Etiqueta: "historial · hace 3 días". Si el body está recortado
   (`truncated`) o no es JSON válido, no hay campos y el nodo lo dice
   ("respuesta recortada: ejecuta el paso para verla completa").
3. Nada → el nodo muestra "Aún no se ha enviado" y el botón **▶ Ejecutar hasta aquí**.

Una ejecución desde el canvas **no** escribe en el historial (decidido): los
resultados viven solo en memoria, así que tras reiniciar la app un nodo muestra la
respuesta de su último envío hecho a mano en Workspace, o "Aún no se ha enviado".

## Conectar

- **Arrastrar** el pin del campo `ruta` del paso `j` y soltarlo sobre la entrada
  `nombre` del paso `i`:
  - Solo resaltan como destino válido las entradas de pasos `i > j`.
  - Efecto: `steps[j].extract[nombre] = ruta` (si ya existía con otra ruta, se reemplaza).
  - Si un paso `k` con `j < k < i` también extrae `nombre`, el soltado se rechaza con
    el mensaje "El paso k ya define {{nombre}} y lo sobrescribe". **[mía]**
- **Clic en un campo** → menú:
  - **Usar como variable…** — popover con un nombre sugerido editable; al confirmar se
    añade `extract[nombre] = ruta`. Si un paso posterior ya usa `{{nombre}}`, el cable
    aparece solo.
  - **Añadir assertion** — añade `Assertion(field: ruta, operator: exists)` al paso y
    abre el panel en sus assertions. **[mía]** (`exists` y no `==` porque los ids y
    tokens cambian en cada ejecución.)
  - **Copiar ruta** — copia `response.body.…` completa.
- **Desconectar** — clic en un cable o en la etiqueta de origen de una entrada →
  "Desconectar" quita `extract[nombre]` del paso origen. Si esa variable alimenta a
  más de un paso, el menú lo dice antes ("la usan 2 pasos"). **[mía]**
- **Nombre sugerido** (`suggestVariableName(ruta)`): el último segmento que no sea un
  índice; si es genérico (`id`, `name`, `token`, `code`, `value`, `key`, `uuid`) se le
  antepone el segmento anterior con `_` (`user.id` → `user_id`, `data.token` → `token`
  si el anterior es `data`/`result`/`response`/`body`). Siempre `snake_case`
  (`userId` → `user_id`). **[mía]**

### Sugerencias

Para cada entrada **sin origen**, `suggestConnection(...)` busca en los pasos
anteriores, del más cercano al más lejano, el primer campo cuyo nombre normalizado
coincide con el de la entrada. Normalizar: minúsculas y sin `_`/`-`
(`userId` = `user_id` = `userid`); se compara contra el último segmento y contra los
dos últimos unidos (`user.id` → `userid`). La sugerencia se dibuja como un cable
punteado más un chip "¿conectar {nombre}?"; un clic la acepta (crea el `extract`). Como
mucho una sugerencia por entrada.

## UI

### Pantalla de Flows

- La lista de flujos de la izquierda (`ListDetailLayout`) **se queda**. Se puede
  plegar para dar sitio al canvas. **[mía]**
- **Barra superior del canvas:** nombre del flujo (editable en el sitio, como hoy),
  **▶ Ejecutar flujo**, resumen de la última ejecución (`3 passed · 0 failed ·
  0 skipped · 420 ms`, mismas cadenas que hoy), controles de zoom (−, %, +,
  "Ajustar"), importar/exportar se quedan en la cabecera de la lista.
- Se **elimina** el botón "Guardar" deshabilitado: el guardado ya es automático.
- **Canvas:** fondo con puntos (`surfaceContainerLowest`), los nodos en una fila
  alineados arriba, ancho fijo (~240 px) y separación fija (~56 px), unidos por una
  flecha de secuencia entre cabeceras. Desplazamiento horizontal y zoom 50 %–150 %
  (`InteractiveViewer` o equivalente). Al final de la fila, un nodo **"+ Agregar
  paso"** que abre el `showAddStepPicker` de hoy.
- **Flujo vacío:** solo el nodo "+ Agregar primer paso" con el texto de hoy.

### Nodo

De arriba abajo (ver mockup B):

1. **Cabecera:** `MethodBadge`, nombre del request, estado (`201 ✓`, `404 ✗`,
   `omitido`, `sin enviar`, o spinner mientras corre), menú `⋮`.
2. **Ruta** del request, en mono.
3. **ENTRADAS:** una fila por entrada. Cada una con su pin a la izquierda y el origen a
   la derecha: `← Login`, `env`, `generado`, `🔑 sesión` o `⚠ sin origen` en rojo.
4. **RESPUESTA · {fuente}:** hasta 8 campos, cada uno con su vista previa y un pin a la
   derecha; un campo ya extraído muestra `→ {{nombre}}`. "+N más" si hay más.
   Si no hay respuesta, el recuadro "Aún no se ha enviado · ▶ Ejecutar hasta aquí".

- **Menú `⋮`:** Ejecutar hasta aquí · Volver a ejecutar desde aquí (solo si hay
  resultados previos) · Cambiar petición · Mover a la izquierda · Mover a la derecha ·
  Eliminar paso.
- **Request inexistente** (endpoint borrado): nodo en estado de error con "Petición no
  encontrada" y "Cambiar petición", como `StepCard` hoy.
- **Seleccionado:** borde `primaryContainer`; abre el panel lateral.
- Reordenar arrastrando un nodo es **opcional** en v1; "Mover a la izquierda/derecha"
  es obligatorio. Tras un cambio de orden los orígenes se recalculan: una entrada cuyo
  `extract` quedó en un paso posterior pasa a "⚠ sin origen" (el `extract` no se borra).

### Cables

- Sólidos (`primary`) del pin del campo al pin de la entrada; curvas Bézier
  horizontales. Punteados (color de advertencia) para sugerencias.
- Las entradas con origen `env`, `generado` o `sesión` no tienen cable.
- Mientras se arrastra: cable fantasma que sigue al puntero y entradas válidas
  resaltadas; soltar fuera cancela.

### Panel lateral

Se abre al seleccionar un nodo, a la derecha (~400 px), con botón de cerrar. Pestañas:

- **Paso:** request (método, nombre, URL) con "Cambiar petición"; **Entradas** con su
  origen; **Variables que extrae** — la lista editable de hoy (`nombre ← ruta`), para
  rutas que no salen en el nodo (`response.status`, `response.headers.x`) o que ya no
  aparecen en la última respuesta (con aviso "no aparece en la última respuesta");
  **Assertions** (`AssertionsEditor` de hoy); **Detener si falla**; **Eliminar paso**.
- **Respuesta:** la respuesta completa del nodo como árbol (status, headers, body),
  donde clic en cualquier valor abre el mismo menú que un campo del nodo.
- **Si hay resultado de ejecución**, las pestañas de `RunStepInspector`: Error Details
  (solo si falló), Assertions, Request Sent, Headers, y "Volver a ejecutar desde aquí".

### Ejecutar

- **▶ Ejecutar flujo** corre todos los pasos con `FlowRunner.run` y el executor de la
  sesión (como hoy). Cada nodo pasa a "corriendo" y luego muestra su estado; sus
  campos se actualizan con la respuesta nueva. Al terminar se selecciona el primer
  paso que falló (o el último que corrió), como `_autoSelect` hoy, y el panel abre su
  pestaña de error.
- **▶ Ejecutar hasta aquí** (paso `i`): corre desde el primer paso que no tenga un
  resultado **exitoso** en esta sesión (sin resultado, fallido u omitido cuentan como
  pendientes) hasta `i` inclusive (`runFrom(startIndex, endIndex: i)`), sembrando el
  pool con el environment más lo extraído por los pasos anteriores
  (como `_variablesEnteringStep` hoy). Si todos los anteriores tienen éxito, solo
  envía `i`. Los resultados de los pasos posteriores a `i` se borran, porque dependían
  de los valores anteriores; esos nodos vuelven a mostrar la respuesta del historial
  si la hay. `stopOnFailure` se respeta igual que en una ejecución completa. **[mía]**
- **Volver a ejecutar desde aquí:** igual que hoy (`runFrom`), hasta el final.
- Los resultados viven **en memoria por flujo** mientras la app está abierta: cambiar
  de flujo y volver los conserva; cambiar de proyecto los borra. Un cambio de
  estructura (agregar, quitar, mover o cambiar la petición de un paso) borra los
  resultados desde el primer paso afectado en adelante. **[mía]**
- Mientras corre, editar el flujo está bloqueado (los botones de ejecutar y los menús
  que cambian la estructura se deshabilitan). **[mía]**

## Commands

```bash
fvm flutter pub get
fvm flutter gen-l10n                        # si no corre solo con `flutter test`
fvm flutter test test/engine/flows
fvm flutter test test/ui/flows
fvm flutter test                            # suite completa
fvm flutter test test/integration           # journeys sin ventana
fvm flutter analyze
fvm flutter build web --release --base-href /api_flow_studio/   # el canvas también corre en web
# NO ejecutar `dart format` sobre archivos existentes: el repo no usa el estilo nuevo.
```

## Project Structure

```
lib/engine/flows/step_inputs.dart        # NUEVO: stepInputs(Endpoint) → entradas y tokens generados (puro)
lib/engine/flows/input_origin.dart       # NUEVO: resolveInputOrigin(...) (puro)
lib/engine/flows/response_fields.dart    # NUEVO: responseFields(body) → hojas con ruta y vista previa (puro)
lib/engine/flows/variable_naming.dart    # NUEVO: suggestVariableName, suggestConnection (puro)
lib/engine/flows/flow_runner.dart        # runFrom(..., endIndex)
lib/ui/flows/flows_screen.dart           # lista + canvas + panel; se va _FlowBuilder vertical
lib/ui/flows/canvas/flow_canvas.dart     # NUEVO: fila de nodos, zoom/scroll, capa de cables, arrastre
lib/ui/flows/canvas/step_node.dart       # NUEVO: el nodo (cabecera, entradas, campos, menú)
lib/ui/flows/canvas/wire_painter.dart    # NUEVO: CustomPainter de cables y sugerencias
lib/ui/flows/canvas/step_panel.dart      # NUEVO: panel lateral (Paso / Respuesta / resultado)
lib/ui/flows/flow_run_provider.dart      # NUEVO: resultados en memoria por flujo + ejecutar / hasta aquí / desde aquí
lib/ui/flows/run_step_inspector.dart     # se reutiliza dentro del panel
lib/ui/flows/assertions_editor.dart      # se reutiliza dentro del panel
lib/ui/flows/flow_run_view_screen.dart   # SE ELIMINA
lib/ui/flows/step_card.dart              # SE ELIMINA (el editor de extracts pasa al panel)
lib/ui/flows/run_step_card.dart          # SE ELIMINA si nada más lo usa
lib/l10n/app_en.arb, app_es.arb          # textos nuevos en los dos idiomas
test/engine/flows/*_test.dart            # uno por archivo nuevo del engine
test/ui/flows/                           # canvas, nodo, panel, conectar, ejecutar
integration_test/journeys/flow_journey.dart  # journey actualizado al canvas
```

Los archivos nuevos de `engine/` no importan `package:flutter`. Nada nuevo usa
`dart:io` (la app también se publica en web).

## Code Style

Funciones puras en el engine, con `///` que explica el porqué; la UI lee de
providers y llama a `FlowsNotifier` para cambiar el flujo (cada gesto del canvas es
un `updateStep`, `reorderStep`, `addStep` o `removeStep` de hoy). `Key`s con índice
para tests, al estilo del repo:

- `flow-canvas`, `step-node-$i`, `step-node-menu-$i`
- `step-input-$i-$nombre`, `step-input-origin-$i-$nombre`
- `step-field-$i-$k` (k = posición del campo en el nodo), `step-field-pin-$i-$k`
- `wire-$j-$i-$nombre`, `suggestion-$i-$nombre`
- `step-panel`, `run-flow-button`, `run-until-$i`, `run-summary-total` (se conserva)

Textos de la UI siempre por `context.l10n`, en inglés y español.

## Testing Strategy

TDD: test rojo primero.

- **Engine (sin mocks):**
  - `stepInputs`: variables en cada lugar (URL, query, headers, cada tipo de body,
    auth basic/bearer); entradas deshabilitadas ignoradas; sin duplicados y en orden;
    `{{$token}}` separados; `{{ espacio }}` no cuenta.
  - `resolveInputOrigin`: paso anterior más cercano gana; un extract del propio paso
    no cuenta; environment; sesión; sin origen; tras reordenar.
  - `responseFields`: objeto anidado, lista (solo índice 0 + longitud), escalar en
    raíz, body no JSON, límite y conteo de lo que quedó fuera, vista previa recortada.
  - `suggestVariableName` y `suggestConnection`: la tabla de ejemplos de este
    documento (`user.id` → `user_id`, `userId` ↔ `user_id`, el más cercano gana, una
    por entrada).
  - `runFrom(endIndex)`: se detiene después de `endIndex`; sin él, igual que hoy
    (la suite actual de `flow_runner_test.dart` sigue verde sin tocarla).
- **Widget:** canvas con 4 nodos en orden; entrada con cada tipo de origen;
  arrastrar un pin a una entrada crea el `extract` y aparece el cable; soltar hacia
  atrás no hace nada; soltar con un paso intermedio que sobrescribe se rechaza;
  "Usar como variable" con nombre sugerido; aceptar una sugerencia; desconectar;
  "Añadir assertion"; mover izquierda/derecha recalcula orígenes; panel lateral con
  sus pestañas; ejecutar pinta estados y abre el primer fallo; "Ejecutar hasta aquí"
  solo llama a los pasos necesarios; ejecutar no escribe en el historial; nodo con
  request borrado.
- **Integración (`test/integration` + `integration_test/`):** el journey de flows se
  reescribe sobre el canvas y conserva lo que comprueba hoy: los pasos en orden,
  `3 passed / 0 failed / 0 skipped`, las llamadas al backend en orden, el header
  `Authorization` de la sesión en los pasos 2 y 3, el paso que falla y el siguiente
  omitido. Más uno nuevo: conectar `user.id` del login con `{{user_id}}` de get user
  arrastrando, ejecutar, y ver que la URL enviada lleva el id.
- Los tests de las piezas que se eliminan (`flow_builder_screen_test`,
  `step_card_editor_test`, `flow_run_view*_test`) se **sustituyen** por los del canvas
  que cubren el mismo comportamiento, no se borran sin reemplazo.

## Boundaries

- **Always:** TDD; `fvm flutter analyze` y la suite completa antes de cada commit;
  `engine/` sin imports de Flutter; textos en `app_en.arb` y `app_es.arb`; commits por
  tarea, solo con los archivos de la tarea.
- **Ask first:** cualquier cambio en `Flow`/`FlowStep`, `flows.json`, el archivo de
  flujos o el de workspace; guardar posiciones o cables; añadir una dependencia (p. ej.
  un paquete de grafos); ramas, loops u otros bloques.
- **Never:** romper la lectura de flujos guardados o el runner de terminal; borrar o
  debilitar tests sin un reemplazo que cubra lo mismo; reescribir `flows.json` fuera
  del guardado normal; escribir en el historial desde una ejecución del canvas;
  reformatear archivos que no se tocan.

## Success Criteria

1. Un flujo de 4 pasos se ve como 4 nodos en una fila, en el orden de `Flow.steps`,
   con scroll horizontal y zoom.
2. Cada nodo lista las `{{variables}}` de su request con el origen correcto según la
   precedencia del runner, y marca "⚠ sin origen" las que no tienen.
3. Cada nodo con respuesta conocida (última ejecución o historial) lista sus campos;
   sin respuesta ofrece "Ejecutar hasta aquí".
4. Arrastrar el campo `user.id` de Login a `{{user_id}}` de Get user guarda
   `extract: {user_id: response.body.user.id}` en el paso de Login y dibuja el cable;
   ejecutar envía la URL con el id.
5. "Usar como variable", sugerencias por nombre, desconectar y "Añadir assertion"
   funcionan como se describe.
6. Ejecutar el flujo pinta el estado de cada nodo en el canvas y abre el primer fallo
   en el panel; ya no se abre otra pantalla.
7. El token del login llega a los pasos siguientes por la sesión y el canvas lo
   muestra con 🔑 sin pedir un extract.
8. Los `flows.json`, archivos de flujos y workspaces existentes se abren y ejecutan
   igual; `bin/api_flow_runner.dart` no cambia.
9. Funciona en escritorio y en el build web.
10. Ejecutar desde el canvas (flujo completo, hasta aquí o desde aquí) no añade
    entradas al historial.
11. `fvm flutter analyze` sin avisos y `fvm flutter test` en verde.

## Decisiones a revisar

Las tomé yo al escribir esto; cambiarlas no cambia la forma del feature:

- El nodo muestra como mucho 8 campos; el resto en el panel.
- "Añadir assertion" desde un campo crea `exists`, no `==`.
- Soltar un cable rechaza el caso en que un paso intermedio sobrescribe la variable,
  en vez de borrar ese extract intermedio.
- "Desconectar" borra el `extract` del paso origen (avisa si alimenta a varios pasos).
- Regla del nombre sugerido (`user.id` → `user_id`).
- "Ejecutar hasta aquí" reutiliza los pasos que ya tuvieron éxito en la sesión y
  borra los resultados de los pasos posteriores.
- Las `{{variables}}` del valor esperado de una assertion no se muestran como entradas.
- Los resultados viven en memoria por flujo y se borran desde el paso afectado al
  cambiar la estructura; editar está bloqueado mientras corre.
- La lista de flujos se puede plegar.

## Open Questions

Ninguna. Resuelta en la revisión: las ejecuciones desde el canvas **no** se guardan en
el historial del endpoint (el historial queda solo para envíos hechos a mano).
