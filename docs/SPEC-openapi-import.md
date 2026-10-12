# Spec: openapi-import

Módulo 4 (el último) del mapa [SPEC-import-map.md](SPEC-import-map.md). Depende de
[`import-core`](SPEC-import-core.md) (el contrato `Importer` y el botón Import) y de
[`multipart-body`](SPEC-multipart-body.md) (los cuerpos `multipart/form-data`), ya
implementados; reutiliza lo común de [`postman-import`](SPEC-postman-import.md) (lectores
tolerantes, saneado de nombres de variable).

## Objective

Una especificación OpenAPI describe una API entera: es la forma más rápida de tener un
request por cada endpoint. Este módulo hace que el botón Import del panel lateral entienda una
**especificación OpenAPI 3.0 o 3.1, en JSON o en YAML**: cada operación (`GET /pets`,
`POST /pets/{id}`…) entra como un request listo para enviar, agrupado por tag dentro de una carpeta
nueva con el nombre de la API, y los datos que dependen de ti (el servidor, los parámetros de ruta,
las credenciales) llegan como variables de un ambiente nuevo.

**Usuario:** el desarrollador dueño de la app.

**Éxito:** se elige `openapi.yaml` con Import y aparece una carpeta con una subcarpeta por tag y un
request por operación, con su método, su URL `{{base_url}}/pets/{{petId}}`, sus parámetros, un cuerpo
de ejemplo y su autenticación; el ambiente `<título> (imported)` trae `base_url` ya puesta; basta
rellenar las credenciales para empezar a probar; y un resumen enumera lo que no se pudo traer.

## ASSUMPTIONS (corregir ahora o procedo con estas)

1. **Un solo importador**, `OpenApiImporter` ("OpenAPI spec"), para JSON y YAML. Acepta 3.0.x y 3.1.x. Un
   archivo **Swagger 2.0** se reconoce solo para dar un mensaje útil:
   `That is a Swagger 2.0 file, which is not supported. Convert it to OpenAPI 3 first.`
2. **Dependencia nueva `yaml`** (paquete de dart-lang, ya resuelto como transitivo en `pubspec.lock`, 3.1.4):
   se declara en `pubspec.yaml`. Es la decisión 1 del mapa; no cambia ninguna versión instalada.
3. **Nada sale del archivo:** las referencias `$ref` solo se resuelven si son locales (`#/…`). Una
   externa (otro archivo o una URL) **no se sigue ni se lee**: se avisa y se trata como ausente.
4. **Un ejemplo, no un esquema:** los cuerpos y valores de ejemplo salen de `example`/`examples`/`default`/`enum`
   del archivo y, si no hay, de una muestra generada del esquema (con límites de profundidad y tamaño).
5. **Las rutas de archivo no existen aquí:** un campo binario de `multipart/form-data` llega como "archivo
   sin elegir" (regla común del mapa) y cuenta en los valores por rellenar.
6. **Lo que no se puede traducir no rompe la importación:** se simplifica o se omite **con un aviso**
   (lista cerrada abajo). Las respuestas (`responses`) no son parte de un request y no se importan ni se avisan.
7. **Una operación, un request:** si tiene varios tags, vive bajo el primero; sin tags, en la carpeta raíz.
8. **Sin cambios en el modelo ni en el ejecutor.**

## Reconocimiento
- **JSON:** objeto con `openapi` de texto que empieza por `3.`; o con `swagger` de texto (para el mensaje de Swagger).
- **YAML:** como leer todo el YAML para decidir sería caro (cada importador mira el archivo), `matches` hace una
  comprobación barata del texto: una línea en la columna 0 que sea `openapi: 3.…` (con o sin comillas) o
  `swagger: …`. El YAML se interpreta de verdad solo en `parse`.
- Extensiones ofrecidas por el diálogo: `json`, `yaml`, `yml`.
- Un YAML que no es válido → `That file is not valid YAML.` (con la línea si el parser la da).

## Mapeo

### Estructura
| OpenAPI | Aquí |
|---|---|
| `info.title` | carpeta raíz (sin título: `OpenAPI spec`) |
| `tags` (orden declarado) y los tags usados | subcarpetas, en ese orden; después, las de tags no declarados por orden de aparición |
| operación de `paths` | un request en la carpeta de su **primer** tag (sin tags: la raíz) |
| orden | el de `paths` en el archivo, y dentro de cada ruta `get, put, post, delete, options, head, patch, trace` según aparezcan |
| `operation.summary`, si no `operationId`, si no `<MÉTODO> <ruta>` | nombre |
| `operation.description` (si no, `summary`) | descripción |
| `parameters` a nivel de ruta + de operación | los de la operación pisan a los de la ruta con el mismo `in`+`name` |

### URL y servidor
- URL = `{{base_url}}` + la ruta con cada `{param}` convertido en `{{param}}` (nombre saneado a letras, dígitos y `_`).
- `servers[0].url` → variable `base_url` del ambiente, con las variables del servidor (`{env}`) sustituidas por su
  `default`. Una URL **relativa** (`/v1`) se pone tal cual con el aviso `server URL is relative; set base_url to the host`.
  Sin `servers` → `base_url` vacía con el aviso `the file declares no servers; set base_url in the imported environment`.
  Si hay más servidores: un aviso que los lista (`other servers were not imported: …`).

### Parámetros
- **path:** `{{nombre}}`, y una variable `nombre` en el ambiente con su `example`/`default` (o vacía) la primera vez que aparece.
- **query:** una fila por parámetro; los `required` activados y el resto **desactivados**. Valor: `example`, si no
  `default`, si no el primer `enum`, si no una muestra del esquema; un `required` sin nada de eso lleva `{{nombre}}` (y la
  variable en el ambiente). Un array con `explode` (por defecto en `form`) se reparte en una fila por elemento; sin `explode`,
  separado por comas.
- **header:** igual que query (se ignoran `Accept`, `Content-Type` y `Authorization`, que OpenAPI reserva).
- **cookie:** no se importan; aviso `cookie parameter "x" was not imported`.
- Un parámetro **objeto** (`style: deepObject`, etc.) no se importa; aviso `parameter "x" is an object and was not imported`.

### Cuerpo (`requestBody.content`)
Se elige un tipo de contenido por preferencia: `application/json` (o cualquier `+json`), luego
`application/x-www-form-urlencoded`, luego `multipart/form-data`, luego los de texto (`text/*`, `application/xml`…).
| Tipo | Resultado |
|---|---|
| JSON | cuerpo JSON con el ejemplo (`example` del tipo, o el primer valor de `examples`, o la muestra del esquema), con indentación; un `+json` distinto de `application/json` añade su `Content-Type` |
| urlencoded | filas por cada propiedad del esquema: `required` activadas con su ejemplo (o `{{nombre}}`), el resto desactivadas |
| multipart | un campo por propiedad: las `string` con `format: binary` (o `contentMediaType`) son **archivos sin elegir** (con el `contentType` de `encoding.<prop>.contentType` si lo hay); el resto, texto con su ejemplo |
| texto / XML | el `example` como texto con su `Content-Type` y el aviso `request body in "application/xml" imported as text with Content-Type application/xml`; sin ejemplo: cuerpo vacío y el aviso `the "application/xml" body has no example; left empty` |
| solo tipos binarios (`application/octet-stream`, `image/*`…) | sin cuerpo; aviso `binary request body is not supported; the body was left empty` |

### Muestra de un esquema
Para una muestra generada: `example` > `default` > `const` > `enum[0]`; `allOf` fusiona las propiedades; `oneOf`/`anyOf`
toman la primera alternativa; `object` → sus propiedades (sin las `readOnly`); `array` → un elemento; `string` según
`format` (`date-time` → `2024-01-01T00:00:00Z`, `date` → `2024-01-01`, `email` → `user@example.com`, `uuid` →
`00000000-0000-0000-0000-000000000000`, `uri` → `https://example.com`, otro → `string`); `integer`/`number` → `0`;
`boolean` → `true`; `type: [x, "null"]` (3.1) → `x`. **Límites:** profundidad 8; 2 000 nodos por muestra; un esquema que se
referencia a sí mismo se corta en el primer ciclo. Si se corta algo, aviso `the example for <where> was cut short`.

### Autenticación (`security` + `components.securitySchemes`)
Efectiva por operación: `operation.security` si existe (`[]` = ninguna), si no el `security` global. De las alternativas
(OR) se toma la primera que no esté vacía; las partes de una alternativa (AND) se aplican todas.
| Esquema | Resultado |
|---|---|
| `http` `bearer` | bearer con `{{<esquema>_token}}` |
| `http` `basic` | basic con `{{<esquema>_username}}` / `{{<esquema>_password}}` |
| `apiKey` en header / query | un header o parámetro `name: {{<esquema>}}` |
| `apiKey` en cookie | no se importa; aviso |
| `oauth2`, `openIdConnect`, `mutualTLS`, otros `http` | ninguna; aviso **una vez por esquema** (donde se define, `components.securitySchemes.<nombre>`): `security scheme "x" (oauth2) is not supported; requests that use it have no authentication` |
| dos esquemas que ocupan el mismo sitio (bearer y basic) | se aplica el primero; aviso `only the first of several authentication schemes was applied` |
Las variables de las credenciales se crean en el ambiente como **secretas y vacías**, así que cuentan en los "valores por rellenar".

### Ambiente
`<título> (imported)` con, en este orden: `base_url`, las variables de ruta/parámetros (no secretas, con su ejemplo o
vacías) y las de credenciales (secretas, vacías). Nunca se activa.

### `$ref`
Solo punteros locales (`#/components/schemas/Pet`), con `~0`/`~1` y `%`-escapes del estándar. Una referencia que no
resuelve → aviso `reference "#/…" was not found`; una externa → `external reference "x" was not followed` (una vez por
referencia). Se cortan los ciclos.

### Webhooks y callbacks
No se importan; un aviso global `webhooks and callbacks were not imported` si el archivo los trae.

## Avisos: criterio
Lista cerrada: versión Swagger 2.0 (error), YAML inválido (error), servidor relativo/ausente/otros, parámetros
cookie y objeto, cuerpos binarios o sin ejemplo, cuerpo de texto con su `Content-Type`, campos de archivo por elegir,
esquema de seguridad no soportado o cookie, varios esquemas en conflicto, `$ref` externa o inexistente, ejemplo
cortado, webhooks/callbacks, y nombres de variable renombrados (uno solo para todo el archivo, como en Postman).
Cada uno lleva `where` (`GET /pets/{id}`, `components.securitySchemes.x`; vacío si es del archivo entero).

## Commands

```bash
fvm flutter pub get
fvm flutter test test/engine/import test/ui/import
fvm flutter test                       # suite completa
fvm flutter test test/integration      # journeys sin ventana
fvm flutter analyze
# NO ejecutar `dart format` sobre archivos existentes: el repo no usa el estilo nuevo.
```

## Project Structure

```
lib/engine/import/openapi/
  openapi_importer.dart      # OpenApiImporter: reconocer, parsear YAML/JSON, recorrer paths
  openapi_refs.dart          # resolver $ref locales, ciclos, externas
  openapi_schema.dart        # muestras de esquemas (límites de profundidad y tamaño)
  openapi_operation.dart     # una operación → Endpoint (URL, parámetros, headers)
  openapi_body.dart          # requestBody → cuerpo
  openapi_security.dart      # esquemas de seguridad → auth
lib/engine/import/import_json.dart       # lectores tolerantes (movidos desde postman/postman_json.dart)
lib/engine/import/variable_names.dart    # saneado de nombres y su aviso (extraído de VariableTranslator)
lib/engine/import/import_registry.dart   # + OpenApiImporter
pubspec.yaml                             # yaml: ^3.1.4
test/engine/import/openapi/ + fixtures/  # unitarias y dos especificaciones realistas (JSON 3.0, YAML 3.1)
integration_test/journeys/import_journey.dart  # + importar una especificación
README.md
```

Todo en `engine/`, sin `package:flutter`. El YAML se lee con `loadYaml` (seguro, sin ejecución de código) y no se copia
entero: se recorre directamente con los lectores tolerantes, y los alias se tratan como la misma referencia.

## Code Style

Cada pieza es una función pura con un contexto compartido (referencias, avisos, nombres), como en Postman:

```dart
/// One operation as an [Endpoint]. Everything that cannot be carried over is
/// added to [context.warnings], located by `METHOD /path`.
Endpoint operationToEndpoint({
  required String path,
  required String method,
  required Map<String, dynamic> operation,
  required List<dynamic> pathParameters,
  required OpenApiContext context,
}) { ... }
```

Convenciones: comentarios `///` con el porqué, mensajes en inglés, lectores tolerantes que ignoran tipos inesperados.

## Testing Strategy

- **Reconocimiento:** JSON 3.0/3.1, YAML con y sin comillas, Swagger (JSON y YAML), un Postman / app / ambiente **no** coinciden,
  texto, vacío, un YAML con `openapi:` indentado no cuenta.
- **YAML:** un YAML válido y uno inválido (mensaje claro), tipos de YAML (números, booleanos, fechas, multilínea) leídos bien, un
  alias reutilizado, un YAML con muchos alias anidados no hace explotar el tiempo ni la memoria.
- **`$ref`:** local simple, anidada, con `~1`, ciclo, inexistente (aviso), externa (aviso, **sin leer nada**).
- **Esquemas:** cada rama de la muestra (ejemplo, default, enum, const, allOf, oneOf, objeto, array, formatos, 3.1 con `null`),
  `readOnly` omitido, ciclo cortado, límite de profundidad y de nodos con el aviso.
- **Estructura:** título, tags en su orden, operación bajo su primer tag, sin tags en la raíz, orden de rutas y métodos, nombres.
- **URL/servidor:** `base_url` con variables de servidor, relativo, ausente, varios; `{param}` → `{{param}}`; nombres saneados.
- **Parámetros:** path (con y sin ejemplo), query requerido/opcional, arrays con y sin `explode`, header, ignorados reservados,
  cookie, objeto, herencia y pisado ruta → operación.
- **Cuerpos:** JSON con `example`, con `examples`, con muestra; `+json`; urlencoded; multipart con binario y texto; texto/XML con y
  sin ejemplo; solo binario; preferencia entre varios tipos.
- **Seguridad:** cada esquema, global vs operación, `[]` que anula, alternativas OR y combinación AND, esquema no soportado avisado
  una vez, variables secretas vacías en el ambiente.
- **Fixtures realistas:** una especificación 3.0 en JSON (Petstore ampliada) y una 3.1 en YAML (con `$ref`, `allOf`, `oneOf`,
  ciclo, multipart, seguridad) con las cifras esperadas de carpetas, requests, avisos y variables.
- **Integración con el core:** `runImport` con el registro real elige bien entre los cuatro formatos; `applyImport` deja carpeta y
  ambiente nuevos, sin activar; `valuesToFill` suma credenciales y archivos; ningún `$ref` externo se lee.
- **UI:** el botón Import ofrece `json`, `yaml`, `yml`; una especificación con avisos abre el resumen.
- **Journey:** importar un YAML pequeño y ver las subcarpetas, el ambiente con `base_url` y el resumen.

## Boundaries

- **Always:** TDD (test rojo primero); `fvm flutter analyze` y la suite completa antes de cada commit; cada cosa omitida o
  cambiada deja un aviso; leer de forma tolerante; límites de profundidad, nodos y ciclos en todo lo recursivo; la importación es
  no destructiva (carpeta y ambiente nuevos, ninguno activo); `engine/` sin imports de Flutter; commits por tarea con solo sus archivos.
- **Ask first:** añadir otra dependencia además de `yaml`; ampliar el modelo (por ejemplo, un cuerpo "texto" propio u OAuth);
  seguir referencias externas; crear un ambiente por servidor.
- **Never:** seguir una URL o leer un archivo que el documento mencione; ejecutar nada; importar una ruta de archivo; activar un
  ambiente; inventar un valor para un secreto; recorrer sin límite un documento con alias o ciclos; debilitar o borrar tests existentes.

## Success Criteria

1. Una especificación OpenAPI 3.0 en JSON y una 3.1 en YAML se importan con una carpeta raíz, una subcarpeta por tag y un request por
   operación, en el orden del archivo.
2. Método, URL con `{{base_url}}` y `{{param}}`, parámetros (requeridos activados, opcionales desactivados), headers y descripción
   son los de la operación.
3. Los cuerpos JSON, urlencoded, multipart y de texto salen según la tabla, con ejemplos del archivo o muestras del esquema dentro de
   los límites; los binarios se avisan.
4. La autenticación bearer, basic y apiKey se importa con variables secretas vacías en el ambiente; oauth2 y similares se avisan una vez
   por esquema.
5. `servers[0]` es `base_url`; relativo, ausente y múltiples se avisan.
6. Las referencias locales (también anidadas y circulares) funcionan; las externas y rotas se avisan y **no se leen**.
7. Un YAML o JSON inválido, o un Swagger 2.0, dan un mensaje claro y no cambian nada.
8. El ambiente `<título> (imported)` nunca se activa; los campos de archivo y las credenciales cuentan como valores por rellenar.
9. Un documento hostil (alias anidados, esquemas circulares) se importa o se corta con aviso en tiempo y memoria acotados.
10. `fvm flutter analyze` sin avisos y `fvm flutter test` en verde.

## Open Questions

1. **¿Un ambiente por servidor?** Hoy solo el primero (`servers[0]`) y un aviso con los demás. Muchas especificaciones listan
   producción, staging y local; un ambiente por servidor (`<título> – <descripción>`) sería más cómodo pero crea varios
   ambientes (y uno puede llamarse "Production"). ¿Lo prefieres?
2. **Un requerido sin ejemplo lleva `{{nombre}}`** (y la variable vacía en el ambiente), en vez de enviar un valor vacío. ¿Te parece bien
   ese marcador visible, o prefieres un valor inventado de la muestra del esquema (`0`, `string`)?
3. **Parámetros opcionales desactivados:** así el request funciona de entrada sin enviar basura. ¿O los quieres activados?
4. **Varios tags:** la operación vive bajo el primero. La alternativa es duplicarla bajo cada tag (más fiel a Swagger UI, pero
   los requests repetidos confunden y cuentan doble).
5. **Nombres de las variables de credenciales** (`{{BearerAuth_token}}`, `{{ApiKeyAuth}}`): derivadas del nombre del esquema para que
   sean únicas. ¿Prefieres nombres fijos y cortos (`{{token}}`, `{{api_key}}`) aunque dos esquemas puedan chocar?
6. **Swagger 2.0:** hoy se rechaza con un mensaje. Convertirlo sería un módulo aparte; ¿lo anoto como idea?

## Estado

Implementado de O1 a O9 (`tasks/openapi-import/`). Criterios de éxito y dónde se comprueban:

| # | Criterio | Pruebas |
|---|---|---|
| 1 | Carpeta raíz, una subcarpeta por tag y un request por operación, en orden | `openapi_operation_test.dart`, `openapi_importer_test.dart` (Petstore JSON, Orders YAML) |
| 2 | Método, URL, parámetros (requeridos activados), headers, descripción | `openapi_operation_test.dart` |
| 3 | Cuerpos JSON, urlencoded, multipart, texto; binario avisado | `openapi_body_test.dart`, `openapi_schema_test.dart` |
| 4 | Autenticación con variables secretas vacías; no soportados avisados una vez por esquema | `openapi_security_test.dart` |
| 5 | `servers[0]` como `base_url`; relativo, ausente y varios avisados | `openapi_operation_test.dart` |
| 6 | `$ref` locales (anidadas, circulares); externas y rotas avisadas y nunca leídas | `openapi_refs_test.dart`, `openapi_importer_test.dart` |
| 7 | YAML/JSON inválido y Swagger 2.0: mensaje claro, nada cambia | `openapi_recognition_test.dart`, `openapi_apply_test.dart`, `import_file_test.dart` |
| 8 | Ambiente `<título> (imported)` sin activar; archivos y credenciales por rellenar | `openapi_apply_test.dart` |
| 9 | Documento hostil acotado en tiempo y tamaño | `openapi_recognition_test.dart`, `openapi_schema_test.dart`, `openapi_importer_test.dart` |
| 10 | `analyze` y `test` en verde | CI |

Decisiones al implementar: la muestra de un esquema que se refiere a sí mismo deja fuera la parte
recursiva y avisa **una vez por esquema** (`schema "#/…" refers to itself; the recursive part was left out of the
examples`), no una vez por operación; el aviso de recorte por tamaño o profundidad es `the example was cut short (it is
too deep or too large)`, ubicado en la operación; un esquema de seguridad que no existe se avisa
(`security scheme "x" is not defined; ignored`); las variables del ambiente salen en este orden: `base_url`, las de
rutas y parámetros y, al final, las credenciales (secretas); un parámetro opcional sin valor lleva `''` y va
desactivado; un `$ref` entre vecinos (3.1) se resuelve sin los vecinos; las respuestas no se leen; la selección del
tipo de contenido sin aviso entre alternativas equivalentes (JSON, `+json`, formulario, multipart, texto).
