# Spec: postman-import

Módulo 3 del mapa [SPEC-import-map.md](SPEC-import-map.md). Depende de
[`import-core`](SPEC-import-core.md) (el contrato `Importer` y el botón Import) y de
[`multipart-body`](SPEC-multipart-body.md) (los cuerpos `formdata`), ya implementados.

## Objective

Quien viene de Postman tiene sus pruebas en una colección. Este módulo hace que el botón
Import del panel lateral las entienda: una **colección Postman v2.1** (o v2.0) entra como una
carpeta nueva con su árbol de carpetas y requests, y un **archivo de ambientes de Postman**
entra como un ambiente nuevo. Lo que Postman tiene y esta app no (scripts, OAuth, ejemplos
guardados…) no se ejecuta ni se inventa: se deja fuera **y se dice**.

**Usuario:** el desarrollador dueño de la app.

**Éxito:** se exporta una colección desde Postman, se elige el archivo con Import, y aparece una
carpeta con el mismo árbol y los mismos requests (método, URL con sus parámetros, headers, cuerpo,
autenticación); las `{{variables}}` siguen funcionando porque las variables de la colección llegan
como un ambiente; y un resumen enumera cada cosa que no se pudo traer, con su ubicación.

## ASSUMPTIONS (corregir ahora o procedo con estas)

1. **Dos importadores**, no uno: `PostmanCollectionImporter` ("Postman collection") y
   `PostmanEnvironmentImporter` ("Postman environment"). Se registran después del de la app.
2. **Versiones:** colecciones v2.0 y v2.1 (JSON). Las v1 (`requests`/`folders`, sin `info.schema`)
   se reconocen para dar un mensaje útil: `That is a Postman collection v1, which is not supported. Export it again as v2.1.`
3. **Nada se ejecuta:** los scripts (`event`: pre-request y test) no se corren ni se traducen; solo
   se avisa. Tampoco se sigue ninguna URL ni se lee ningún archivo que el JSON mencione.
4. **El modelo de la app manda:** lo que no cabe se simplifica con aviso (ver Mapeo) en lugar de
   ampliar el modelo para este módulo. Sin dependencias nuevas.
5. **Las rutas de archivo no se importan** (regla común del mapa): los campos `file` de un `formdata`
   llegan como "sin archivo elegido".
6. **Los nombres de variable** solo pueden tener letras, dígitos y `_` en esta app (`{{base-url}}`
   no se resolvería). Se renombran de forma coherente en todo el archivo (`base-url` → `base_url`) y
   se avisa una sola vez con la lista de cambios.
7. Los avisos de algo definido en una carpeta o en la colección (un script, una autenticación no
   soportada) se dan **una vez en el sitio donde está definido**, no repetidos en cada request que lo hereda.

## Mapeo: colección

| Postman | Aquí |
|---|---|
| `info.name` | carpeta raíz (si falta: `Postman collection`) |
| `item` con `item` dentro | carpeta (subcarpeta de la que la contiene); `order` = posición entre hermanas |
| `item` con `request` | un request, en el orden del archivo |
| `item.name` | nombre del request (vacío → `<MÉTODO> <url>`) |
| `request` como texto | solo la URL (método `GET`) |
| `request.method` | método en mayúsculas (por defecto `GET`) |
| `request.description` / `item.description` (texto u objeto `{content}`) | descripción |
| `request.header[]` | headers; `disabled: true` → desactivado |
| `request.url` (texto u objeto) | URL base + parámetros de query (ver abajo) |
| `request.body` | cuerpo (ver abajo) |
| `auth` (request, carpeta o colección) | autenticación, heredada hacia abajo (ver abajo) |
| `variable` de la colección | un ambiente nuevo `<nombre> (imported)` |
| `event` (scripts) | **no se traduce**: aviso |
| `response` (ejemplos guardados) | **no se importan**: un aviso con la cuenta total |

### URL y parámetros
- Si `url` es un objeto, la base es `url.raw` sin su parte `?…`; si no hay `raw`, se reconstruye con
  `protocol://host(.host)[:port]/path/path`. Los parámetros salen de `url.query[]` (con
  `disabled`); si no hay `query`, se leen de la parte `?…` de la URL.
- Una URL en texto se parte igual: base y parámetros.
- Los segmentos de ruta `:nombre` se sustituyen por el valor de `url.variable[]` si lo tiene; si no,
  quedan como `{{nombre}}` con el aviso `path variable :nombre has no value; written as {{nombre}}`.
  Solo se tocan segmentos que empiezan por `/:` (un `localhost:3000` no se toca).

### Cuerpos (`body.mode`)
| Modo | Resultado |
|---|---|
| ausente / `null` | sin cuerpo |
| `raw`, lenguaje `json` (o sin lenguaje y el texto es JSON) | cuerpo JSON |
| `raw`, otro lenguaje (`xml`, `html`, `text`, `javascript`) | cuerpo en el editor JSON **más** un header `Content-Type` (`application/xml`, `text/html`, `text/plain`, `application/javascript`) si el request no trae uno; aviso `raw body in "xml" imported as text with Content-Type application/xml` |
| `urlencoded` | form URL-encoded (`disabled` → desactivado) |
| `formdata` | Form Data: `text` → campo de texto; `file` → campo de archivo **sin ruta** (con su `contentType` si lo tiene) y el aviso `file field "avatar" needs a file chosen` |
| `graphql` | cuerpo JSON `{"query": …, "variables": …}`; si `variables` no es JSON válido, `{}` con aviso |
| `file` (binario) | sin cuerpo; aviso `binary (file) body is not supported; the body was left empty` |
| `body.disabled: true` | sin cuerpo; aviso `the body is disabled in Postman; left empty` |

### Autenticación
Se resuelve subiendo: la del request, si no la de la carpeta, si no la de la colección.
| Tipo | Resultado |
|---|---|
| `noauth` | ninguna |
| `bearer` | bearer con su `token` |
| `basic` | basic con `username` y `password` |
| `apikey` en header | un header `key: value` |
| `apikey` en query | un parámetro de query `key=value` |
| cualquier otro (`oauth1/2`, `digest`, `awsv4`, `hawk`, `ntlm`…) | ninguna, con el aviso `auth type "oauth2" is not supported; requests that inherit it have no authentication` en el sitio donde se define |

Tanto la forma de lista (`[{key, value}]`) como la de objeto (`{token: …}`) se aceptan.

### Variables
- **Dinámicas de Postman → las de esta app**, en todos los textos: `{{$guid}}` y `{{$randomUUID}}` →
  `{{$uuid}}`; `{{$timestamp}}`, `{{$isoTimestamp}}`, `{{$randomInt}}`, `{{$randomEmail}}` se conservan;
  `{{$randomAlphaNumeric}}` → `{{$randomString}}`. Cualquier otra (`{{$randomFirstName}}`) queda
  escrita tal cual con el aviso `unknown dynamic variable {{$randomFirstName}} left as written`.
- **Nombres:** los que no sean `\w+` se renombran (ver supuesto 6), también en las claves del ambiente.
- **Ambiente de la colección:** las `variable` de la colección (y las de sus carpetas, fundidas en el
  mismo, con aviso por carpeta y sin pisar un nombre que ya existe) forman un ambiente
  `<nombre de la colección> (imported)`. `type: secret` → variable secreta (con el valor que traiga).
  Sin variables → no se crea ambiente.

## Mapeo: archivo de ambientes (`values`)
Un archivo con `values: [{key, value, enabled, type}]` (de un ambiente o de las globales de Postman)
se importa como **un ambiente** con ese nombre (`name`, o `Postman environment` si falta; las globales,
`_postman_variable_scope: "globals"`, con su `name` o `Postman globals` si falta). `type: secret` →
variable secreta. Las entradas con `enabled: false` se omiten con un aviso que las nombra. Los
nombres se sanean igual que arriba.

## Avisos: criterio
Todo lo que se deja fuera o se cambia produce un `ImportWarning` con `where` (ruta
`Carpeta / Subcarpeta / Request`, vacío si es del archivo entero) y un mensaje corto en inglés.
Esta es la lista cerrada: scripts, ejemplos guardados, auth no soportada, cuerpo binario,
cuerpo deshabilitado, cuerpo raw no JSON, campos de archivo, GraphQL con variables inválidas,
variable de ruta sin valor, variables dinámicas desconocidas, nombres de variable renombrados,
variables de carpeta fundidas, entradas de ambiente deshabilitadas, un `item` sin request ni
`item` (se omite), e imposibilidad de seguir bajando por carpetas (más de 50 niveles).

## Cambio en `import-core`
`ImportSummary.valuesToFill` hoy cuenta solo secretos de ambiente vacíos. Pasa a sumar también los
campos de archivo sin elegir de los requests importados (`filePathsToFill`), para todos los
importadores; el texto `— N values to fill in` no cambia. Se prueba con el importador de la app y con
este.

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
lib/engine/import/postman/
  postman_collection_importer.dart   # PostmanCollectionImporter: matches/parse, recorrido del árbol
  postman_request.dart               # un item → Endpoint (URL, headers, cuerpo)
  postman_auth.dart                  # auth heredada y su traducción
  postman_variables.dart             # {{variables}}: dinámicas, nombres, ambiente de la colección
  postman_environment_importer.dart  # PostmanEnvironmentImporter
lib/engine/import/import_registry.dart    # + los dos importadores
lib/ui/import/import_actions.dart         # valuesToFill suma archivos sin elegir
test/engine/import/postman/ + fixtures/   # unitarias y una colección realista de ejemplo
integration_test/journeys/import_journey.dart  # + importar una colección Postman
README.md                                 # formatos soportados y lo que no
```

Todo en `engine/`, sin `package:flutter`.

## Code Style

Un `item` se traduce con una función pura que recibe un contexto (ruta, avisos, auth heredada,
traductor de variables) y devuelve el `Endpoint`; los avisos se acumulan en el contexto, no se lanzan:

```dart
/// One Postman item that has a `request`, as an [Endpoint]. Everything that cannot
/// be carried over is added to [context.warnings] with the item's path.
Endpoint requestToEndpoint(Map<String, dynamic> item, _Context context) {
  final request = _asRequest(item['request']);
  final url = translateUrl(request['url'], context);
  // ...
}
```

Convenciones: comentarios `///` con el porqué, mensajes en inglés, `Map<String, dynamic>` leídos con
ayudantes tolerantes (`_string`, `_list`, `_map`) que ignoran tipos inesperados en vez de lanzar.

## Testing Strategy

- **Reconocimiento (`matches`):** colección v2.1 y v2.0; v1; archivo de ambiente; globales; un archivo de
  la propia app y un OpenAPI **no** coinciden; un JSON sin relación, texto, vacío.
- **URL:** texto, objeto con `raw`, objeto sin `raw`, con puerto, con query (activa y desactivada), con
  `{{base_url}}`, variables de ruta con y sin valor, `localhost:3000` intacto, URL sin protocolo.
- **Headers:** activos, desactivados, repetidos.
- **Cuerpos:** cada modo de la tabla, incluidos `raw` JSON / sin lenguaje con JSON / xml con y sin
  `Content-Type` previo, `formdata` con archivo (sin ruta y con aviso), `graphql` con variables válidas e
  inválidas, binario, deshabilitado.
- **Autenticación:** cada tipo, herencia colección → carpeta → request, `noauth` que corta la herencia,
  tipo no soportado avisado **una vez** donde se define, ambas formas (lista y objeto).
- **Variables:** cada dinámica, una desconocida, nombres con `-`/`.`/espacio renombrados de forma
  coherente en URL, headers, cuerpo y ambiente, un solo aviso de renombrados.
- **Ambiente de la colección:** nombre, `secret`, deshabilitadas, vacío → sin ambiente, variables de
  carpeta fundidas con aviso.
- **Árbol:** carpetas anidadas y su `order`, un `item` sin nada (omitido con aviso), nombres vacíos,
  scripts en colección/carpeta/request (un aviso por sitio), ejemplos guardados (un aviso con la cuenta),
  profundidad > 50.
- **Archivo de ambientes:** ambiente y globales, `secret`, `enabled: false`, nombres saneados, sin nombre.
- **Fixture realista:** una colección Postman v2.1 completa (carpetas, los cuatro tipos de cuerpo, auth
  heredada, scripts, variables) con las cifras esperadas de carpetas, requests, avisos y ambientes.
- **Integración con el core:** `runImport` con el registro real elige el importador correcto para cada
  uno de los tres tipos de archivo; `applyImport` de una colección con ambiente deja carpeta y ambiente
  nuevos; `valuesToFill` suma archivos sin elegir; una colección Postman con una ruta de archivo en
  `src` no la deja en el proyecto.
- **UI:** el botón Import con una colección que trae avisos abre el resumen con ellos.
- **Journey:** importar una colección y ver la carpeta, el ambiente (sin activar) y el resumen.

## Boundaries

- **Always:** TDD (test rojo primero); `fvm flutter analyze` y la suite completa antes de cada commit;
  cada cosa omitida o cambiada deja un aviso; leer los tipos de forma tolerante (nunca lanzar por un
  campo inesperado); la importación es no destructiva (carpeta y ambiente nuevos, ninguno activo);
  `engine/` sin imports de Flutter; commits por tarea con solo sus archivos.
- **Ask first:** añadir una dependencia; ampliar el modelo (por ejemplo, un cuerpo "texto" propio o
  autenticación OAuth) para cubrir algo que hoy es un aviso; traducir scripts.
- **Never:** ejecutar o interpretar un script; seguir una URL o leer un archivo mencionado en la
  colección; importar la ruta de un archivo; activar un ambiente; inventar un valor para un secreto;
  debilitar o borrar tests existentes.

## Success Criteria

1. Una colección Postman v2.1 con carpetas anidadas se importa como una carpeta raíz con el mismo árbol y
   los mismos requests, en el mismo orden.
2. Método, URL base, parámetros (con su estado habilitado), headers y descripción de cada request son los de
   la colección; las variables de ruta se resuelven o se avisan.
3. Los cuerpos `raw` (JSON y otros), `urlencoded`, `formdata` y `graphql` se importan según la tabla; el binario y
   el deshabilitado se avisan.
4. La autenticación bearer, basic y apikey (header y query) se importa y se hereda de carpeta y colección; un tipo no
   soportado se avisa una vez donde se define.
5. Las variables dinámicas conocidas se traducen, las desconocidas y los nombres cambiados se avisan, y las
   `{{variables}}` de la colección llegan como un ambiente `<nombre> (imported)` sin activar.
6. Un archivo de ambientes (o de globales) se importa como un ambiente; las entradas deshabilitadas se avisan.
7. Nada se ejecuta ni se lee fuera del archivo; los campos de archivo llegan sin ruta y cuentan como valores por rellenar.
8. Un v1, un archivo de otro formato o uno dañado dan un mensaje claro y no cambian nada.
9. El resumen enumera los avisos con su ubicación; sin avisos basta el toast.
10. `fvm flutter analyze` sin avisos y `fvm flutter test` en verde.

## Open Questions

1. **Cuerpos `raw` que no son JSON** (xml, texto, html): hoy se importan en el editor JSON con su `Content-Type`
   y un aviso. ¿Prefieres un tipo de cuerpo "texto" propio en el modelo (más fiel, pero toca el modelo, el
   ejecutor, el curl y el editor) o te basta así?
2. **Renombrar variables** (`base-url` → `base_url`): lo propongo porque si no la variable nunca se resolvería.
   ¿Lo apruebas, o prefieres dejarlas como están y solo avisar?
3. **Variables de carpeta** (poco comunes): se funden con las de la colección. ¿Te sirve, o las omito con aviso?
4. **Scripts de pre-request:** a menudo fijan variables que el request necesita. Hoy solo se avisa. Un módulo
   futuro podría cubrir los casos simples (`pm.environment.set('x', 'valor')`); ¿lo anoto como idea?
5. **Salvaguarda de tamaño:** una colección enorme genera miles de filas en el sidebar. Sigo sin tope de requests
   (decisión de `import-core`); ¿lo quieres aquí al menos como aviso a partir de cierto número?

## Estado

Implementado de P1 a P7 (`tasks/postman-import/`). Criterios de éxito y dónde se comprueban:

| # | Criterio | Pruebas |
|---|---|---|
| 1 | Árbol de carpetas y requests, en orden | `postman_collection_importer_test.dart` (`the tree`, fixture realista) |
| 2 | Método, URL, params, headers, descripción; variables de ruta | `postman_request_test.dart` |
| 3 | Cuerpos raw, urlencoded, formdata, graphql; binario y deshabilitado avisados | `postman_body_test.dart` |
| 4 | Auth bearer, basic, apikey, heredada; tipo no soportado avisado una vez | `postman_auth_test.dart`, `postman_collection_importer_test.dart` |
| 5 | Dinámicas, nombres renombrados, ambiente `<nombre> (imported)` sin activar | `postman_variables_test.dart`, `postman_apply_test.dart` |
| 6 | Archivo de ambientes / globales | `postman_environment_importer_test.dart` |
| 7 | Nada se ejecuta ni se lee; archivos sin ruta y por rellenar | `postman_body_test.dart`, `postman_apply_test.dart` |
| 8 | v1, otro formato o dañado: mensaje claro | `postman_collection_importer_test.dart`, `import_file_test.dart` |
| 9 | Resumen con los avisos ubicados; toast si no hay | `import_file_test.dart`, `import_journey.dart` |
| 10 | `analyze` y `test` en verde | CI |

Decisiones al implementar: un `auth` sin `type` se hereda (no es una definición); las entradas de un
`formdata` o `urlencoded` sin clave se omiten sin aviso (son filas vacías), igual que los headers sin
clave; el aviso de una autenticación definida en la colección se ubica en `Collection`; si una variable
de carpeta repite un nombre ya definido se conserva la primera y se avisa; el archivo de ambientes avisa
de las entradas sin clave y de las repetidas, además de las deshabilitadas; las globales conservan su
`name` en vez de añadirle `(globals)`.
