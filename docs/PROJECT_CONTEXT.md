# Project Context: API Flow Studio

## Objetivo

Una herramienta de escritorio, estilo Postman/Insomnia, para probar endpoints
HTTP sin depender de aplicaciones de terceros. Además de lo básico (enviar un
request y ver la respuesta), soporta **múltiples entornos**, **agrupar
endpoints por categoría**, y **flujos**: secuencias de llamadas encadenadas
donde la respuesta de un paso alimenta variables del siguiente (ej. un flujo
de registro: validar si el usuario existe → enviar OTP → validar OTP →
verificar si el correo está en uso → crear usuario).

**Usuario:** el propio desarrollador, uso personal/individual. No es un
producto multiusuario ni colaborativo (al menos no en v1).

**Éxito se ve como:** poder armar una colección de endpoints agrupada,
cambiar de entorno (dev/qa/prod) sin editar cada request a mano, y correr un
flujo de varios pasos viendo el resultado de cada paso, sin abrir Postman.

## Por qué monolito Flutter Desktop (sin backend separado)

CORS es una restricción de navegadores (fetch/XHR desde JS), no de clientes
HTTP nativos. Un binario de Flutter Desktop (Windows/macOS/Linux) que hace
requests con `dio` es tráfico HTTP nativo — igual que Postman — sin
restricciones de CORS ni de headers. Esto permite tener **UI + motor de
ejecución de requests + persistencia en disco, todo en un solo proyecto
Dart**, sin mantener dos runtimes (frontend JS + backend).

## Tech Stack

- **Flutter Desktop** (Windows como plataforma principal; macOS/Linux
  habilitados de fábrica). Flutter `3.44.6` pinneado vía FVM (`.fvmrc`), igual
  que el resto de proyectos Flutter del autor — nunca usar el `flutter`
  global.
- **`dio`** — cliente HTTP: interceptors, timeouts, multipart, redirects,
  cookie jar si hace falta.
- **`flutter_riverpod`** + **`riverpod_annotation`** — estado de la app.
- **`freezed`** + **`json_serializable`** — modelos inmutables con
  `copyWith`/`toJson`/`fromJson` para Environment, Group, Endpoint, Flow,
  FlowStep, HistoryEntry.
- **Persistencia:** JSON plano en disco vía `dart:io` puro, en una carpeta
  junto al ejecutable (app portable, sin instalador). Versionable a mano,
  inspeccionable, sin motor de base de datos.
- **`uuid`** — ids de entidades.
- **`mocktail`** + `flutter_test` — tests del motor (engine) aislado de la UI.
- Nada de Node, Electron, ni base de datos.

## Arquitectura

Monolito con el "motor" (lógica de negocio) separado de la UI, para poder
testear ejecución de requests y flujos sin montar widgets:

```
lib/
  engine/                      # Dart puro, sin imports de Flutter
    models/                    # Environment, Group, Endpoint, Flow, FlowStep, HistoryEntry
    http/request_executor.dart # arma y ejecuta un HttpRequest resuelto con dio
    variables/interpolator.dart # reemplaza {{variable}} en url/headers/body
    flows/flow_runner.dart     # ejecuta pasos en orden, resuelve variables entre pasos
    flows/value_extractor.dart # dot-notation: "response.body.data.otp" -> valor
    storage/json_store.dart    # lee/escribe colecciones/entornos/flujos en disco
  ui/                          # feature-first
    environments/
    collections/
    request_builder/
    response_viewer/
    flows/
  app.dart
  main.dart
```

Regla de diseño: nada bajo `engine/` importa `package:flutter`. Toda la
lógica de "¿qué pasa cuando corro este request/flujo?" debe poder probarse
con `flutter_test` puro, sin renderizar UI.

## Modelo de datos

- **Environment**: `{ id, name, variables: Map<String,String> }`. Uno activo
  a la vez; sus variables se interpolan en `{{clave}}` dentro de URL,
  headers y body de cualquier request.
- **Group**: carpeta/categoría, anidable (categoría → subcategoría →
  endpoint), con nombre y orden.
- **Endpoint** (request guardado): `{ id, groupId, name, method, url,
  headers, queryParams, body, authConfig }`.
- **HistoryEntry**: respuesta guardada de una ejecución pasada de un
  Endpoint (status, headers, body, tiempo, timestamp) — hasta N por
  endpoint.
- **Flow**: `{ id, name, steps: List<FlowStep> }`.
- **FlowStep**: `{ endpointId, extract: Map<String,String> (variable ->
  dot-path en la respuesta), assertion: { field, expected }?, stopOnFailure:
  bool }`.

## Alcance MVP (v1)

1. Entornos: crear/editar/duplicar/eliminar; cambiar el activo
   globalmente; variables clave-valor; interpolación `{{var}}`.
2. Colecciones agrupadas por carpeta/categoría; búsqueda por nombre.
3. Request builder: método, query params, headers, body (ninguno/raw
   JSON/form-urlencoded), auth básica/bearer (solo setean el header
   correcto).
4. Response viewer: status, tiempo, tamaño, headers, body con JSON
   formateado y resaltado de sintaxis.
5. Historial de respuestas por request (últimas N).
6. Flujos: lista ordenada de pasos, cada uno referencia un endpoint
   guardado + extracción de variables (dot-notation) + assertion simple
   (status/campo esperado) + "detener si falla"; vista de ejecución que
   muestra el resultado de cada paso.
7. Pegar un comando `curl` → autocompleta un request nuevo.

## Fuera de alcance en v1 (backlog / v2)

- Import/export de OpenAPI/Swagger y de colecciones Postman.
- Diff de la respuesta actual contra un "golden example" guardado.
- Pestañas de múltiples requests abiertos a la vez.
- Editor visual tipo grafo para flujos (v1 es solo lista ordenada).
- Marcar variables de entorno como "secret" (se enmascaran en UI — **no**
  es un vault: igual quedan en texto plano en el archivo JSON en disco).
- Generar snippet `curl` a partir de un request guardado.
- Atajos de teclado / paleta de comandos.
- Soporte WebSocket/SSE.

## Límites conocidos / cosas que NO hacer sin pedir permiso

- No introducir un backend HTTP separado ni base de datos — el punto del
  diseño es un monolito Dart.
- No agregar autenticación multiusuario ni sincronización en la nube.
- No convertir las variables "secret" en un manejo de secretos real
  (vault, cifrado) sin que se pida explícitamente — dejar claro en la UI
  que es solo una máscara visual.
- No romper la regla `engine/` sin imports de Flutter.

## Testing

- Tests unitarios de `engine/` (interpolación de variables, extracción por
  dot-notation, `flow_runner`, `json_store`) con `flutter_test` +
  `mocktail` para el cliente HTTP.
- Sin tests end-to-end/integración en v1 — verificación manual corriendo
  la app en Windows.
