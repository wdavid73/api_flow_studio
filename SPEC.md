# Spec: API Flow Studio

## Objetivo

Una app de escritorio (Windows, con macOS/Linux habilitados) estilo
Postman/Insomnia para probar endpoints HTTP sin depender de aplicaciones de
terceros. Soporta múltiples entornos (dev/qa/prod), agrupa endpoints por
categoría, y permite definir **flujos**: secuencias de llamadas encadenadas
donde la respuesta de un paso alimenta variables del siguiente (ej. un flujo
de registro: validar si el usuario existe → enviar OTP → validar OTP →
verificar si el correo está en uso → crear usuario).

**Usuario:** el propio desarrollador, uso personal. No es multiusuario ni
colaborativo en v1.

**Éxito se ve como:** armar una colección agrupada, cambiar de entorno sin
editar cada request a mano, correr un flujo de varios pasos viendo el
resultado de cada paso, y que las colecciones sobrevivan a reiniciar la
app — todo sin abrir Postman.

## Tech Stack

- **Flutter Desktop** `3.44.6` (pinneado vía FVM, `.fvmrc`) — Windows como
  plataforma principal, macOS/Linux habilitados de fábrica.
- **`dio`** `^5.7.0` — cliente HTTP (interceptors, timeouts, multipart,
  redirects). Sin CORS: tráfico HTTP nativo, no de navegador.
- **`flutter_riverpod`** `^2.6.1` + **`riverpod_annotation`** — estado de
  la app.
- **`freezed`** `^2.5.7` + **`json_serializable`** `^6.8.0` — modelos
  inmutables (Environment, Group, Endpoint, Flow, FlowStep, HistoryEntry)
  con `copyWith`/`toJson`/`fromJson`.
- **Persistencia:** JSON plano en disco vía `dart:io` puro, en una carpeta
  `api_flow_studio_data/` junto al ejecutable (no en la carpeta de datos
  del SO) — así la app es portable: copiar la carpeta del build (a un USB,
  para compartir) se lleva los datos con ella. No es versionable con git
  automáticamente; queda como limitación conocida (ver Open Questions).
- **`uuid`** `^4.5.1` — ids de entidades.
- **`mocktail`** `^1.0.4` + `flutter_test` — tests del motor (`engine/`),
  mockeando el cliente `dio`.
- Sin Node, sin Electron, sin base de datos, sin backend separado.

## Commands

```bash
# Instalar dependencias
fvm flutter pub get

# Codegen (freezed / json_serializable / riverpod_generator)
fvm dart run build_runner build --delete-conflicting-outputs

# Correr en desarrollo (Windows)
fvm flutter run -d windows

# Build de release (Windows)
fvm flutter build windows

# Tests
fvm flutter test

# Lint / análisis estático
fvm flutter analyze

# Formateo
fvm dart format .
```

Todo comando `flutter`/`dart` va siempre vía `fvm` — nunca el binario
global (misma convención que el resto de proyectos Flutter del autor).

## Project Structure

```
lib/
  engine/                       # Dart puro, SIN imports de package:flutter
    models/                     # Environment, Group, Endpoint, Flow, FlowStep, HistoryEntry (freezed)
    http/
      request_executor.dart     # arma y ejecuta un HttpRequest resuelto con dio
    variables/
      interpolator.dart         # reemplaza {{variable}} en url/headers/body
    flows/
      flow_runner.dart          # ejecuta pasos en orden, resuelve variables entre pasos
      value_extractor.dart      # dot-notation: "response.body.data.otp" -> valor
    storage/
      json_store.dart           # lee/escribe colecciones/entornos/flujos en disco (portable, junto al .exe)
    curl/
      curl_parser.dart          # parsea un comando curl pegado a un Endpoint
  ui/                            # feature-first, consume engine/ vía Riverpod providers
    environments/
    collections/
    request_builder/
    response_viewer/
    flows/
    theme/                      # ThemeData construido desde design/DESIGN.md (tokens de color/tipografía)
  app.dart
  main.dart
test/
  engine/                       # tests unitarios, espejo de lib/engine/
design/                          # export de Stitch: screen.png + code.html + DESIGN.md (tokens)
PROJECT_CONTEXT.md               # contexto de diseño/arquitectura ya acordado
SPEC.md                          # este archivo
```

Regla de diseño: nada bajo `lib/engine/` importa `package:flutter`. Toda la
lógica de "¿qué pasa cuando corro este request/flujo?" debe poder probarse
con `flutter_test` puro, sin renderizar UI.

## Code Style

`flutter_lints` default + effective Dart. `lowerCamelCase` para
variables/funciones, `UpperCamelCase` para clases/widgets,
`snake_case.dart` para nombres de archivo. Preferir widgets pequeños y
funciones puras en `engine/` sobre `build()` methods gigantes.

Ejemplo de estilo esperado (modelo freezed + función pura del motor):

```dart
// lib/engine/models/flow_step.dart
@freezed
class FlowStep with _$FlowStep {
  const factory FlowStep({
    required String endpointId,
    @Default({}) Map<String, String> extract, // variable -> dot-path
    String? assertField,
    String? assertExpected,
    @Default(true) bool stopOnFailure,
  }) = _FlowStep;

  factory FlowStep.fromJson(Map<String, dynamic> json) =>
      _$FlowStepFromJson(json);
}

// lib/engine/variables/interpolator.dart
String interpolate(String template, Map<String, String> variables) {
  return template.replaceAllMapped(
    RegExp(r'\{\{(\w+)\}\}'),
    (match) => variables[match.group(1)] ?? match.group(0)!,
  );
}
```

## Testing Strategy

- **Unitarios** (`flutter_test` + `mocktail`) para todo `lib/engine/`:
  interpolación de variables, `value_extractor` (dot-notation), `flow_runner`
  (orden de pasos, detención en fallo, propagación de variables extraídas),
  `curl_parser`, `json_store` (round-trip de lectura/escritura).
- **Tests de integración (añadidos después del v1):** recorridos de usuario
  sobre la app completa con un backend HTTP falso, ejecutables con
  `fvm flutter test test/integration` (sin ventana) y
  `fvm flutter test integration_test -d windows` (app real). Ver
  [SPEC-integration-tests.md](SPEC-integration-tests.md). La verificación manual
  (`fvm flutter run -d windows`) sigue siendo útil para el aspecto visual.
- Sin porcentaje de cobertura fijo — regla práctica: toda función/clase
  nueva bajo `engine/` lleva al menos un test; la UI se verifica a mano.
- Correr `fvm flutter analyze` y `fvm flutter test` antes de dar por
  terminado cualquier cambio.

## Boundaries

- **Siempre:**
  - Correr todos los comandos Flutter/Dart vía `fvm`.
  - Mantener `lib/engine/` libre de imports de `package:flutter`.
  - Correr `fvm flutter analyze` antes de considerar un cambio terminado.
  - Seguir la paleta/tipografía/spacing de `design/*/DESIGN.md` al construir
    UI — no inventar valores nuevos de color o espaciado a mano.

- **Preguntar primero:**
  - Agregar cualquier dependencia fuera de las ya listadas en el stack.
  - Cambiar la versión de Flutter pinneada.
  - Habilitar plataformas adicionales (Android/iOS) — v1 es solo desktop.
  - Cualquier feature del backlog v2 (import OpenAPI/Postman, diff de
    respuestas, tabs múltiples, editor de flujo tipo grafo, vault de
    secretos real, atajos de teclado).

- **Nunca:**
  - Introducir un backend HTTP separado o una base de datos — el punto del
    diseño es un monolito Dart.
  - Agregar autenticación multiusuario o sincronización en la nube.
  - Convertir el flag "secret" de una variable en cifrado/vault real sin
    que se pida explícitamente — debe quedar claro en la UI que solo
    enmascara visualmente (el JSON en disco sigue en texto plano).
  - Commitear tokens/API keys reales.

## Success Criteria

- [ ] `fvm flutter run -d windows` levanta la app sin errores.
- [ ] Se pueden crear ≥2 entornos, cambiar cuál está activo, y un request
      resuelve `{{variable}}` con el valor del entorno activo.
- [ ] Se puede crear una colección con carpeta anidada + endpoint, guardar
      el request, cerrar y reabrir la app, y que siga ahí (persistencia en
      `api_flow_studio_data/` junto al ejecutable).
- [ ] Enviar un request muestra status, tiempo, tamaño y el body con
      resaltado de sintaxis JSON.
- [ ] El historial de un endpoint muestra sus últimas N respuestas.
- [ ] Un flujo de ≥3 pasos corre de punta a punta: el paso 1 extrae una
      variable de su respuesta (dot-notation) y el paso 2 la usa; si un
      paso falla con "stop on failure" activo, los pasos siguientes quedan
      marcados como saltados.
- [ ] Pegar un comando `curl` genera un Endpoint con método/URL/headers/body
      precargados.
- [ ] `fvm flutter analyze` pasa sin errores; `fvm flutter test` pasa para
      todos los tests de `engine/`.
- [ ] La UI implementada respeta los tokens de color/tipografía de
      `design/*/DESIGN.md` (comparación visual contra los `screen.png`
      exportados de Stitch).

## Open Questions

- **Storage no versionable con git:** al vivir en `api_flow_studio_data/`
  junto al ejecutable (fuera del repo fuente), las colecciones no quedan
  versionadas por defecto -- aunque sí viajan si se comparte la carpeta del
  build completa. Si en algún momento se quiere versionar el JSON en sí
  (compartir entre máquinas sin copiar el build, backup en git), se resuelve
  con import/export manual — no está en el alcance de v1, queda anotado
  para revisar si se vuelve necesario.
- **Logo:** existe un asset exportado en `design/api_flow_studio_logo/`
  sin definir todavía dónde se usa (icono de la ventana/taskbar vs. solo
  dentro de la UI) — resolver al implementar `windows/runner` icon.
