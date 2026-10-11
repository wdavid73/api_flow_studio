# Plan: postman-import

Spec: [SPEC-postman-import.md](../../SPEC-postman-import.md) · Mapa: [SPEC-import-map.md](../../SPEC-import-map.md).
Plan separado de los de los demás módulos (`tasks/<módulo>/`).

## Overview

Siete tareas, cada una un corte vertical con su test y su commit: **P1** el ajuste de
`valuesToFill` en `import-core` → **P2** variables de Postman y el importador de **ambientes**
(el primero que se puede usar de punta a punta) → **P3** un request: URL, parámetros, headers y
descripción → **P4** los cuerpos → **P5** la autenticación heredada → **P6** el importador de
**colecciones** (árbol, avisos de scripts y ejemplos, ambiente de la colección, registro) →
**P7** UI, journey y README. La suite existente debe seguir verde en cada tarea. Se aplican las
respuestas por defecto de la spec: raw no JSON en el editor JSON con su `Content-Type`, nombres de
variable renombrados con aviso, variables de carpeta fundidas, scripts solo avisados, sin tope de
requests.

## Hallazgos del código que condicionan el plan

- **El contrato ya está** (`Importer`, `ImportSource`, `ImportResult`, `runImport`,
  `importers`): este módulo solo añade implementaciones y las registra; no se toca `runImport`
  ni la UI salvo lo de `valuesToFill`.
- **`AppCollectionsImporter` ya excluye** `info`, `item`, `openapi`, `swagger` y `values`, así que el
  orden de registro no puede hacer que se coma una colección Postman; se añade un test de que el
  registro real elige bien cada uno de los tres tipos.
- **`mergeImportedCollections` descarta en silencio un request cuyo grupo no esté en `groups`:** el
  importador debe crear un grupo por cada carpeta que contenga requests (y la raíz), y nunca dejar un
  request huérfano.
- **`ImportSummary.valuesToFill` solo cuenta secretos de ambiente vacíos** (en
  `lib/ui/import/import_actions.dart`); los campos de archivo que borra el merge no cuentan. P1 lo
  corrige con `filePathsToFill`, que ya existe en `lib/engine/models/file_paths.dart`.
- **`runImport` acepta resultados con solo ambientes:** el importador de ambientes y una colección
  sin requests pero con variables producen un resultado válido.
- **El motor de variables solo resuelve `{{\w+}}`** (`interpolate`): de ahí el saneado de nombres, y
  las dinámicas deben coincidir con `DynamicValues.names` (`uuid`, `timestamp`, `isoTimestamp`,
  `randomInt`, `randomString`, `randomEmail`).
- **`jsonDecode` entrega `Map<String, dynamic>`**, pero los campos de Postman varían de forma
  (`url` texto u objeto, `auth` como lista u objeto, `description` texto u objeto): los lectores
  tolerantes (`_string`, `_list`, `_map`) son parte del diseño, no un detalle.
- **No hay una colección de ejemplo en el repo:** las pruebas llevan una colección realista como
  fixture (`test/engine/import/postman/fixtures/`, leída con `File(...)` desde la raíz, como ya hace
  `sample_endpoints_test.dart`).
- **No usar `dart format`** en archivos existentes.

## Dependency graph

```
P1 valuesToFill (core) ─────────────────────────────────────────────┐
P2 variables + ambientes ── P3 request (URL, headers) ── P4 cuerpos ─┤
                      └──────────────────── P5 autenticación ───────┴─ P6 colección + registro ── P7 UI, journey, README
```

## Tareas

Cada tarea sigue TDD (test rojo primero) y termina con `fvm flutter analyze` y la suite relevante
en verde; el commit incluye solo los archivos de la tarea.

### P1 — `valuesToFill` cuenta también los archivos sin elegir (core)
`applyImport` suma `filePathsToFill` de los requests importados al número de secretos vacíos.
**Aceptación:** una importación con un campo de archivo (y otra con uno deshabilitado) cuenta 1 (y 0);
secretos + archivos suman; el texto del resumen dice `— N values to fill in`; los tests de
`apply_import_test.dart` existentes siguen pasando.
**Verify:** `fvm flutter test test/ui/import test/engine/import`

### P2 — Variables de Postman y el importador de ambientes
`postman_variables.dart` (traducción de dinámicas, saneado de nombres con registro de cambios,
lectores tolerantes) y `PostmanEnvironmentImporter` registrado en `importers`.
**Aceptación:** `matches` para ambiente y globales y no para colecciones, archivos de la app ni
OpenAPI; ambiente con `secret`, entradas `enabled: false` omitidas con aviso que las nombra, nombre
(`name`, o `Postman environment`; globales `<name> (globals)`), nombres saneados con un solo aviso;
`{{ spaced }}` → `{{spaced}}`; cada dinámica traducida y las desconocidas avisadas; `runImport` del
registro real importa un ambiente y `applyImport` lo deja sin activar.
**Verify:** `fvm flutter test test/engine/import`

### P3 — Un request: URL, parámetros, headers y descripción
`postman_request.dart`: `request` como texto u objeto, método, URL (texto/objeto/sin `raw`), query con
`disabled`, variables de ruta con y sin valor, `localhost:3000` intacto, headers con `disabled`,
descripción (texto u objeto), nombre por defecto, variables traducidas en todos los textos.
**Aceptación:** los casos de URL y headers de la sección de pruebas de la spec; ningún tipo inesperado
lanza.
**Verify:** `fvm flutter test test/engine/import/postman`

### P4 — Los cuerpos
`raw` (JSON, sin lenguaje con JSON, xml/html/text/javascript con `Content-Type` añadido solo si falta),
`urlencoded`, `formdata` (texto y archivo sin ruta con aviso), `graphql`, binario y deshabilitado.
**Aceptación:** cada fila de la tabla de cuerpos, con sus avisos; un `src` con ruta nunca llega al
resultado; un body con `{{variables}}` renombradas queda coherente.
**Verify:** `fvm flutter test test/engine/import/postman`

### P5 — Autenticación heredada
`postman_auth.dart`: bearer, basic, `apikey` (header y query), `noauth`, tipos no soportados, forma
de lista y de objeto, y la herencia colección → carpeta → request, con el aviso una sola vez donde se
define.
**Aceptación:** los casos de autenticación de la spec; un `noauth` en una carpeta corta la herencia; un
`oauth2` en la colección produce un aviso, no uno por request.
**Verify:** `fvm flutter test test/engine/import/postman`
**Checkpoint tras P5:** `fvm flutter analyze` y `fvm flutter test` completos en verde.

### P6 — El importador de colecciones y el registro
`PostmanCollectionImporter`: `matches` (v2.0, v2.1 y v1 con su mensaje), el recorrido del árbol (grupos
con `order`, requests en orden, `item` vacío omitido con aviso, profundidad ≤ 50), scripts avisados por
sitio, ejemplos guardados con su cuenta, el ambiente `<nombre> (imported)` con variables de la colección
y de carpeta, `secret` y deshabilitadas, y el registro.
**Aceptación:** la fixture realista da las cifras esperadas; `runImport` con el registro real elige el
importador correcto para colección, ambiente y archivo de la app; `applyImport` deja carpeta y ambiente
nuevos y ninguno activo; un `src` de archivo no deja ruta en el proyecto; colección vacía → `Nothing to
import`.
**Verify:** `fvm flutter test test/engine/import test/ui/import`

### P7 — UI, journey y README
Un test de widget (colección Postman con avisos → el resumen los lista), un journey en
`import_journey.dart` (carpeta, ambiente sin activar y resumen), y el README (formatos soportados, lo
que no se importa y por qué). Marcar los criterios de la spec.
**Aceptación:** journeys verdes; README completo.
**Verify:** `fvm flutter test && fvm flutter analyze`

## Riesgos

| Riesgo | Mitigación |
|---|---|
| La variedad de formas de Postman (`url`, `auth`, `description`) | Lectores tolerantes y tests por cada forma; la fixture realista se arma con formas reales de v2.0 y v2.1 |
| Reemplazar nombres de variable dentro de cuerpos JSON | Solo se tocan los tokens `{{…}}` sin llaves anidadas; test con un cuerpo JSON que tiene `}}` por anidación |
| Un request huérfano se pierde en silencio en el merge | Test del importador que cada request tiene su grupo; `import-core` ya cubre el aviso de los huérfanos |
| Avisos repetidos que ahogan el resumen | Se emiten en el sitio donde se define el script/auth y se deduplican; test con una colección de muchos requests |
| Rutas de archivo en `src` | Nunca se leen; test explícito de que no llegan al resultado y de que `applyImport` no las deja |
| Tests de UI con I/O real intermitentes | Los nuevos usan el almacén en memoria y el diálogo falso, sin esperas reales |

## Fuera del plan (seguimiento)
- Traducir scripts simples (`pm.environment.set(...)`).
- Un tipo de cuerpo "texto" propio para los `raw` que no son JSON.
- OAuth 1/2, digest y demás autenticaciones.
- Importar ejemplos guardados como documentación del request.
- Tope de requests importados.
