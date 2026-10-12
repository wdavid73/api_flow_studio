# Spec: generated-variables

Módulo 1 del mapa "Flows de testing" (`generated-variables` → `flow-assertions`).
No depende de otros módulos. Es independiente de
[`flow-assertions`](SPEC-flow-assertions.md) (aún sin escribir).

## Objective

Permitir `{{$uuid}}`, `{{$timestamp}}`, `{{$randomEmail}}`… en la URL, query
params, headers, body y auth de cualquier request, para que un flujo (o un
request manual) pueda repetirse sin chocar con datos que ya existen — p. ej.
"crear usuario" dos veces con un correo distinto cada vez.

**Usuario:** el desarrollador dueño de la app.

**Éxito:** escribir `{"email": "{{$randomEmail}}"}` en un body y enviar el
request dos veces manda dos correos distintos; el mismo token funciona en un paso
de flujo; el valor que se envió se puede ver después y reutilizar en pasos
siguientes extrayéndolo a una variable normal.

## ASSUMPTIONS (corregir ahora o procedo con estas)

1. Un token dinámico es `{{$nombre}}` (prefijo `$`). Un nombre sin `$` sigue
   siendo variable normal; no cambia nada para los datos existentes.
2. **Un valor nuevo por cada aparición** del token (dos `{{$uuid}}` en el mismo
   body dan dos uuid distintos). Para reutilizar un valor, se extrae de la
   respuesta o del request a una variable normal.
3. Un token dinámico **no puede ser sobrescrito** por una variable de ambiente
   con el mismo nombre (el `$` no entra en `\w`, así que no hay colisión).
4. Un token `{{$desconocido}}` se deja literal, igual que una variable no
   resuelta hoy.
5. Sin dependencias nuevas: `uuid` ya está en `pubspec.yaml`; el resto usa
   `dart:math` y `DateTime`.

## Variables incluidas (v1)

| Token | Valor | Ejemplo |
|---|---|---|
| `{{$uuid}}` | UUID v4 | `3f2b8c1e-…` |
| `{{$timestamp}}` | Epoch en segundos (entero) | `1760000000` |
| `{{$isoTimestamp}}` | ISO-8601 UTC | `2026-10-11T14:03:22.000Z` |
| `{{$randomInt}}` | Entero 0–999 999 | `48213` |
| `{{$randomString}}` | 12 caracteres `[a-z0-9]` | `k3x9a0pq7zrt` |
| `{{$randomEmail}}` | `test.<8 chars>@example.com` | `test.q8x2m1za@example.com` |

Fuera de alcance: parámetros (`{{$randomInt(1,10)}}`), nombres/direcciones falsos,
tokens definidos por el usuario.

## Comportamiento

- **Dónde se resuelven:** en `RequestExecutor.execute` (único punto que envía), en
  los mismos campos que hoy pasan por `interpolate*`: URL, query params,
  headers, body json/form-urlencoded, username/password/token de auth.
- **Orden:** primero variables normales, luego dinámicas. Así un valor de
  ambiente puede contener `{{$uuid}}` (p. ej. `run_id = {{$uuid}}`) y se
  resuelve al enviar. Un valor generado nunca se vuelve a interpolar (no se
  re-escanea).
- **Preview y curl:** `curl_builder` y la vista previa de URL del flujo no
  generan; muestran el token literal (`{{$uuid}}`), porque el valor real solo
  existe al enviar. La UI lo comunica con el resaltado (ver abajo).
- **Request enviado:** hoy ni el historial ni `ExecutedResponse` guardan el
  request enviado; la pestaña "Request Sent" del inspector del flujo
  reconstruye `método + URL` interpolando de nuevo, lo que con valores
  aleatorios mostraría una URL distinta de la enviada. Por eso el executor
  devuelve la URL **realmente enviada** (`ExecutedResponse.requestUrl`, solo en
  memoria, no se persiste) y el inspector la usa. El historial no guarda
  requests y no cambia.
- **Highlighting:** en los campos con `VariableHighlightingController`, un token
  dinámico conocido se pinta como resuelto (cian); uno desconocido como no
  resuelto (ámbar), igual que hoy.
- **Autocompletado:** v1 sin autocompletado; la lista vive en un tooltip/ayuda
  junto a la nota de sintaxis del gestor de ambientes ("Pro tip: Syntax &
  Resolution").

## Commands

```bash
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs   # solo si cambia un modelo freezed
fvm flutter test test/engine/variables test/engine/http test/engine/curl
fvm flutter test                       # suite completa
fvm flutter test test/integration      # journeys sin ventana
fvm flutter analyze
fvm dart format lib test
```

## Project Structure

```
lib/engine/variables/
  interpolator.dart          # interpolate*(…, {DynamicValues? dynamic}) — cambio mínimo
  dynamic_values.dart        # NUEVO: DynamicValues (Random + reloj inyectables)
lib/engine/http/request_executor.dart   # recibe DynamicValues, pasa a interpolate*, devuelve requestUrl
lib/engine/http/executed_response.dart  # + requestUrl (String?, en memoria; requiere build_runner)
lib/ui/flows/                           # inspector "Request Sent" usa requestUrl
lib/ui/request_builder/json_body.dart   # isValidJsonBody tolera {{$token}}
lib/ui/request_builder/variable_highlighting_controller.dart  # tokens $ conocidos
lib/ui/theme/widgets/json_syntax.dart   # tokenizeVariablesOnly reconoce $nombre
lib/ui/environments/environment_manager_screen.dart           # lista en la ayuda
test/engine/variables/dynamic_values_test.dart   # NUEVO
test/engine/variables/interpolator_test.dart     # casos nuevos
test/engine/http/request_executor_test.dart      # request enviado con valores reales
test/integration/                                # journey: dos envíos, dos correos
```

`dynamic_values.dart` no importa `package:flutter` (regla de `engine/`).

## Code Style

Funciones puras y dependencias inyectables para poder probar sin azar real:

```dart
/// Generates the values behind `{{$name}}` tokens. [random] and [now] are
/// injectable so tests are deterministic.
class DynamicValues {
  DynamicValues({Random? random, DateTime Function()? now})
      : _random = random ?? Random.secure(),
        _now = now ?? DateTime.now;

  final Random _random;
  final DateTime Function() _now;

  /// Returns a fresh value for [name] (without the `$`), or `null` if unknown.
  String? generate(String name) => switch (name) {
        'uuid' => const Uuid().v4(),
        'timestamp' => (_now().millisecondsSinceEpoch ~/ 1000).toString(),
        _ => null,
      };
}
```

Convenciones: comentarios `///` que explican el porqué, como en
`interpolator.dart`; mensajes y textos de UI en inglés; sin `package:flutter`
en `engine/`.

## Testing Strategy

- **Unit (`flutter_test`, sin mocks de dio):**
  - `DynamicValues` con `Random(seed)` y reloj fijo: formato de cada token
    (regex de UUID v4, longitud de `randomString`, dominio de `randomEmail`).
  - `interpolate`: un token → valor; dos apariciones → valores distintos;
    desconocido → literal; sin `DynamicValues` → literal; token normal no
    afectado; `{{$uuid}}` dentro del valor de una variable normal se resuelve
    y el resultado no se re-escanea.
  - `RequestExecutor` (mocktail sobre dio): el request que sale por la red y el
    registrado en la respuesta llevan los mismos valores reales.
  - `curl_builder`: deja el token literal.
- **Widget:** el controller de highlighting colorea `$uuid` como resuelto y
  `$nope` como no resuelto.
- **Integración (`test/integration`, backend falso):** un journey que envía el
  mismo request dos veces y comprueba que el campo con `{{$randomEmail}}` difiere
  entre ambos envíos.
- Cobertura: toda rama nueva de `dynamic_values.dart` e `interpolator.dart`;
  el resto de la suite existente debe pasar sin modificarse.

## Boundaries

- **Always:** TDD (test rojo primero); `fvm flutter analyze` y la suite completa
  antes de cada commit; `engine/` sin imports de Flutter; ids/valores
  generados solo en el punto de envío.
- **Ask first:** añadir una dependencia; cambiar el formato JSON de modelos o
  del workspace export; añadir tokens más allá de la tabla; cambiar la
  semántica de "valor nuevo por aparición".
- **Never:** generar valores en `curl_builder` o en previews; sobrescribir una
  variable de ambiente existente con un token; usar `Random()` sin inyección
  en lógica testeable; saltarse o borrar tests existentes.

## Success Criteria

1. Los seis tokens de la tabla se resuelven en URL, query, headers, body json,
   body form-urlencoded y auth bearer/basic al enviar.
2. Dos envíos consecutivos del mismo request producen valores distintos para
   `{{$uuid}}`, `{{$randomEmail}}`, `{{$randomString}}`.
3. Dos `{{$uuid}}` en el mismo body producen valores distintos entre sí.
4. Un token desconocido o sin generador queda literal; los `{{var}}` normales se
   comportan exactamente como antes (suite existente en verde sin cambios).
5. La pestaña "Request Sent" del inspector muestra la URL realmente enviada
   (con los valores generados); el historial no cambia.
6. Copiar como curl y la vista previa de URL del flujo muestran el token
   literal.
7. El highlighting distingue tokens `$` conocidos de desconocidos.
8. `fvm flutter analyze` sin avisos y `fvm flutter test` en verde.

## Open Questions

1. **Reuso dentro de un mismo envío:** ¿aceptas "nuevo por aparición" (supuesto
   2)? La alternativa es un valor estable por request o por corrida de flujo.
2. **Zona horaria / formato de `$timestamp`:** ¿segundos (como propongo) o
   milisegundos?
3. **Valores generados en el workspace export:** un `run_id = {{$uuid}}` en un
   ambiente se exporta literal; lo doy por correcto (no se resuelve al exportar).
4. ~~Dónde se construye el request del historial~~ — resuelto al planear: no
   existe; se añade `ExecutedResponse.requestUrl` (ver Comportamiento).
