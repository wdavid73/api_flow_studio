# Spec: session-tokens

Módulo 5 de [SPEC-ui-redesign.md](SPEC-ui-redesign.md). Depende de
[`app-shell`](SPEC-app-shell.md) (zona de acciones del header, toast) y del
envío del [`workspace`](SPEC-workspace.md), ambos implementados.

## Objective

Dar a la app la "sesión" del playground de Commodo: un par de tokens
(access y refresh) por ambiente que se adjunta solo como `Authorization:
Bearer` a los requests, se captura de las respuestas de login y se muestra en
el header con su vencimiento. Así se hace login una vez y el resto de requests
funcionan sin copiar tokens a mano.

**Usuario:** el desarrollador dueño de la app.

**Éxito:** al enviar un login, los tokens de la respuesta quedan guardados para
el ambiente activo y el header muestra "Expires in 12 min"; el siguiente
request guardado sale con `Authorization: Bearer …` sin tocar nada; al cambiar
de ambiente se usa el token de ese ambiente; al cerrar la app los tokens
desaparecen.

## Decisiones ya tomadas

- **Una sesión por ambiente.** El token de Dev nunca se manda por error a
  Prod. Sin ambiente activo existe una sesión aparte (la del "sin ambiente").
- **Solo en memoria.** Los tokens no se escriben a disco: no hay cambios en
  `JsonStore` ni en el JSON guardado. Al cerrar la app se pierden.
- **Lo explícito gana:** si un request ya tiene `AuthConfig` (basic/bearer) o
  un header `Authorization`, la sesión no lo pisa. (El HTML sí lo pisa siempre.)
- **No se incluye "Borrar todo lo local"** del HTML: sin persistencia no hay
  nada local de la sesión que borrar; queda solo `Clear tokens`.
- **Los textos van en inglés**, como el resto de la app.

## Comportamiento

### Modelo y reglas (motor, Dart puro)
- `Session`: `accessToken`, `refreshToken` (cadenas, vacías = sin token),
  `attachAuth` (por defecto `true`) y `captureTokens` (por defecto `true`).
- **Adjuntar:** con `attachAuth` y un `accessToken` no vacío, un request sin
  `AuthConfig` y sin header `Authorization` (insensible a mayúsculas) sale con
  `Authorization: Bearer <accessToken>`.
- **Variables de sesión:** `{{session_access_token}}` y
  `{{session_refresh_token}}` quedan disponibles en URL, headers y body (solo
  las no vacías). Si el ambiente define una variable con el mismo nombre, la
  del ambiente gana. Sustituye al `__REFRESH_TOKEN__` del HTML.
- **Capturar:** tras una respuesta 2xx con cuerpo JSON y `captureTokens`
  activo, se busca por anchura (máx. 300 nodos) la primera clave `accessToken`
  o `access_token` y la primera `refreshToken` o `refresh_token` con valor
  cadena; los hallados reemplazan los de la sesión (uno solo puede
  actualizarse sin el otro).
- **JWT:** si el access token tiene forma de JWT se decodifica su payload
  (base64url) para leer `sub` y `exp`; un token que no lo es no es error.
  `expiresIn(now)` devuelve la duración restante o negativa si venció.
- **Etiqueta de vencimiento:** vencido → `Token expired`; menos de 90 min →
  `Expires in N min`; si no `Expires in N h`; JWT sin `exp` o token no JWT →
  `Token saved`.
- **Decorador de ejecución:** `SessionRequestExecutor` envuelve a
  `RequestExecutor`: aplica adjuntar y variables antes de enviar y captura
  después. Lo usan por igual el envío del Workspace y la ejecución de flows
  (un paso de login en un flow deja la sesión lista para los siguientes).

### Header: botón de sesión
- En la zona de acciones del `AppHeader`, un botón de dos líneas (como el
  `.session-btn` del HTML): arriba la etiqueta de vencimiento o `No token`,
  abajo `Authorization: Bearer` (con token) o `kept in memory only` (sin
  token).
- Color de la línea de arriba: `tertiary` con token vigente, `warning` con token
  vencido, `onSurface` sin token. Borde `outlineVariant`, radio 10.
- Pulsarlo abre o cierra el popover de sesión.

### Popover de sesión
- Anclado bajo el header a la derecha, ancho 420, fondo `surfaceContainerLow`,
  borde `outlineVariant`, radio 16; se cierra con `Esc` o al pulsar fuera.
- Título con el nombre del ambiente al que pertenece (`Session · Dev`, o
  `Session · No environment`).
- Campos `Access token` y `Refresh token` (ocultos por defecto), casilla
  `Show`, casillas `Send Authorization` y `Capture tokens from 2xx`.
- Línea de metadatos: `sub <valor> · Expires in 12 min`, o `Doesn't look like a
  JWT. It is still sent as a Bearer.` si no lo es, vacía sin token.
- Botón `Clear tokens`: vacía access y refresh del ambiente (las casillas se
  conservan).
- Al capturar tokens se muestra el toast `Tokens captured for <ambiente>`.

### Variables efectivas
- Un solo lugar combina variables del ambiente activo y de la sesión
  (`effectiveVariables`); lo usan el envío, la ejecución de flows, el botón
  `curl`, y el resaltado de `{{variables}}` del campo de URL (una variable de
  sesión se muestra como resuelta cuando hay token).

## Tech Stack

Flutter 3.44.6 (FVM), Material 3, `flutter_riverpod`. Sin dependencias nuevas
(la decodificación base64url y JSON usa `dart:convert`).

## Commands

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test test/engine/session test/ui/session
fvm flutter test
fvm flutter run -d windows
```

## Project Structure

```
lib/engine/session/
  session.dart                  → Session (inmutable) + sessionVariables()
  jwt_claims.dart               → decodificación de payload, exp, sub, expiresIn
  token_finder.dart             → búsqueda de access/refresh en un JSON
  session_apply.dart            → applySession(): Authorization Bearer
  session_request_executor.dart → decorador de RequestExecutor
lib/ui/session/
  session_provider.dart         → sesiones por ambiente en memoria + effectiveVariables
  session_button.dart           → botón del header
  session_popover.dart          → popover y sus campos
lib/ui/request_builder/send_provider.dart  → usa el ejecutor con sesión
lib/ui/request_builder/url_field.dart      → resalta variables de sesión
lib/ui/response_viewer/response_panel.dart → curl con sesión
lib/ui/flows/flow_run_view_screen.dart     → variables efectivas
lib/app.dart                               → pone SessionButton en las acciones del header
test/engine/session/, test/ui/session/
```

## Code Style

Motor puro, sin `package:flutter`; modelos inmutables a mano o con `freezed` si
el resto del motor lo usa; funciones pequeñas y probables. Ejemplo:

```dart
/// A copy of [endpoint] carrying the session's Bearer token, or [endpoint]
/// itself when nothing should be attached.
Endpoint applySession(Endpoint endpoint, Session session) {
  if (!session.attachAuth || session.accessToken.isEmpty) return endpoint;
  final hasAuthHeader = endpoint.headers.any((h) => h.key.toLowerCase() == 'authorization');
  if (hasAuthHeader || endpoint.authConfig is! AuthConfigNone) return endpoint;
  return endpoint.copyWith(headers: [
    ...endpoint.headers,
    KeyValueEntry(key: 'Authorization', value: 'Bearer ${session.accessToken}'),
  ]);
}
```

## Testing Strategy

- **Motor (unit):**
  - `applySession`: adjunta; no adjunta con `attachAuth` apagado, sin token, con
    `AuthConfig` o con header `Authorization` en cualquier capitalización.
  - `sessionVariables` y su precedencia frente a las del ambiente.
  - `findTokens`: tokens en la raíz y anidados; `snake_case`; límite de nodos;
    JSON sin tokens; solo uno de los dos.
  - `jwt_claims`: JWT válido, base64url con relleno ausente, token que no es JWT,
    `exp` pasado, futuro, en minutos y en horas, sin `exp`.
  - `SessionRequestExecutor` con un ejecutor falso: adjunta antes de enviar,
    captura tras 2xx, no captura con 4xx/5xx, con `captureTokens` apagado ni
    con cuerpo que no es JSON.
- **Widget:** el botón muestra cada estado (sin token, vigente, vencido, no JWT);
  el popover edita tokens, alterna `Show`, `Clear tokens` vacía y conserva las
  casillas; cambiar de ambiente cambia lo mostrado; toast al capturar; se cierra
  con `Esc`.
- **Integración:** enviar un login mock deja la sesión del ambiente activo; el
  siguiente envío lleva el `Authorization`; otro ambiente no lo lleva.
- **Regresión:** `request_bar_test`, `history_wiring_test`, `variable_interpolation_test`
  y los de flows se actualizan si cambia el ejecutor que reciben, no se borran.

## Boundaries

- **Always:** tokens solo en memoria; no escribir tokens en logs, toasts ni
  mensajes de error; campos de token ocultos por defecto; tests antes del código.
- **Ask first:** persistir tokens en disco o en el JSON; añadir cifrado o una
  dependencia de almacenamiento seguro; renovar el token automáticamente con el
  refresh token; guardar método/URL del login en el historial.
- **Never:** mandar el token de un ambiente a otro; pisar un `Authorization`
  explícito del request; imprimir el valor de un token fuera del campo del
  popover y del comando `curl` que el usuario copia a propósito.

## Success Criteria

- [ ] `Session`, `applySession`, `sessionVariables`, `findTokens` y `jwt_claims`
  en `lib/engine/session/` con tests, sin importar Flutter.
- [ ] `SessionRequestExecutor` adjunta y captura como se describe.
- [ ] Una sesión por ambiente, solo en memoria; nada nuevo en `api_flow_studio_data/`.
- [ ] Botón de sesión en el header con las cuatro etiquetas y colores.
- [ ] Popover con campos, `Show`, las dos casillas, metadatos JWT y `Clear tokens`.
- [ ] Enviar un login con tokens en la respuesta los guarda y muestra el toast.
- [ ] El envío, los flows, `curl` y el resaltado de URL usan las variables
  efectivas (incluidas `{{session_*}}`).
- [ ] `fvm flutter analyze` limpio y `fvm flutter test` verde.
- [ ] Comprobación visual del botón y el popover con tokens de ejemplo.

## Open Questions

1. **El historial guarda cuerpos de respuesta en disco en texto plano**, así que
   la respuesta de un login con tokens queda en `history.json` aunque la sesión
   solo viva en memoria. Esto ya ocurre hoy y este módulo no lo cambia.
   Propuesta: dejarlo y avisarlo aquí; la alternativa es ocultar los valores de
   `accessToken`/`refreshToken` al guardar el historial (cambio extra).
2. El botón `curl` del panel de respuesta incluiría el `Authorization: Bearer`
   de la sesión (reproduce lo que se envía). ¿Está bien, o prefieres que `curl`
   deje un marcador `<token>` en lugar del valor? Propuesta: valor real, porque
   copiarlo es una acción explícita.
