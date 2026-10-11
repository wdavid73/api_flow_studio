# Plan: openapi-import

Spec: [SPEC-openapi-import.md](../../SPEC-openapi-import.md) · Mapa: [SPEC-import-map.md](../../SPEC-import-map.md).
Plan separado de los de los demás módulos (`tasks/<módulo>/`).

## Overview

Nueve tareas, cada una un corte vertical con su test y su commit. Primero lo común y lo
arriesgado, después el importador completo: **O1** preparación (lectores y saneado de nombres
compartidos, `yaml` declarada) → **O2** reconocer y leer JSON/YAML → **O3** referencias `$ref` →
**O4** muestras de esquemas → **O5** operaciones (estructura, URL, servidor, parámetros) →
**O6** cuerpos → **O7** seguridad → **O8** el importador completo, las dos especificaciones
realistas y el registro → **O9** UI, journey y README. El importador **no se registra hasta O8**: antes,
un archivo OpenAPI real daría "no tiene requests", que confunde. La suite existente debe seguir verde
en cada tarea. Se aplican las respuestas por defecto de la spec: solo el primer servidor, `{{nombre}}`
para requeridos sin ejemplo, opcionales desactivados, primer tag, nombres de credenciales derivados del
esquema, Swagger 2.0 rechazado.

## Hallazgos del código que condicionan el plan

- **`yaml` ya está resuelta** en `pubspec.lock` (transitiva, 3.1.4): declararla no cambia versiones.
- **`ImportSource.json` es null para YAML** y `AppCollectionsImporter`/`PostmanCollectionImporter`
  solo miran `json`, así que no se pelean con un YAML; el reconocimiento del OpenAPI en YAML se hace
  sobre el texto (una línea en la columna 0 `openapi: 3.…`), sin interpretar todo el archivo en cada
  `matches`.
- **`asMap` de `postman_json.dart` hace `Map<String, dynamic>.from(value)`**, que **lanza** si una clave
  no es texto: en YAML `200:` (códigos de respuesta) son claves enteras. O1 lo hace robusto
  (`'${key}'`) antes de que nadie lo use con YAML.
- **`YamlMap`/`YamlList` implementan `Map`/`List`**, así que los mismos lectores tolerantes sirven sin
  copiar el documento (importante contra alias anidados: no se hace una copia profunda).
- **`PostmanCollectionImporter.matches` exige `info` Map **y** `item` List**, y `AppCollectionsImporter`
  excluye `openapi`/`swagger`: un JSON OpenAPI no es robado por ninguno de los dos (se añade un test del
  registro real con los cuatro formatos).
- **`VariableTranslator` mezcla** el saneado de nombres (genérico) con las dinámicas de Postman: O1 extrae
  el saneado a `variable_names.dart` para que OpenAPI no dependa de `postman/`.
- **`supportedExtensions(importers)` alimenta el diálogo:** al registrar el importador pasa de `['json']`
  a `['json','yaml','yml']`; el test de la UI que lo comprueba (`import_file_test.dart`) y el de
  `app_collections_importer_test.dart` se actualizan en O8 (cambio previsto por la spec).
- **El mensaje "Supported: …"** ya sale del registro (no se escribe a mano en los tests).
- **Los journeys corren también en `integration_test/` con el cwd del dispositivo**, así que el journey
  lleva su especificación embebida (como el de Postman), no lee archivos de `test/`.
- **No usar `dart format`** en archivos existentes.

## Dependency graph

```
O1 preparación ─ O2 reconocer/leer ─ O3 $ref ─ O4 muestras ─ O5 operaciones ─ O6 cuerpos ─ O7 seguridad ─ O8 importador + registro ─ O9 UI, journey, README
```

## Tareas

Cada tarea sigue TDD (test rojo primero) y termina con `fvm flutter analyze` y la suite relevante
en verde; el commit incluye solo los archivos de la tarea.

### O1 — Preparación: lectores y saneado compartidos, `yaml` declarada
Mover `postman/postman_json.dart` a `import/import_json.dart` (actualizar imports de código y tests);
hacer `asMap` tolerante a claves que no son texto; extraer `VariableNames` (saneado, registro de renombres,
`renamedWarning`) a `import/variable_names.dart` y que `VariableTranslator` lo use sin cambiar su API;
declarar `yaml: ^3.1.4` en `pubspec.yaml`.
**Aceptación:** los tests de Postman pasan sin cambios de comportamiento; `asMap` sobre un mapa con claves
enteras no lanza; `VariableNames` tiene sus propios tests; `pubspec.lock` solo reclasifica `yaml` como directa.
**Verify:** `fvm flutter pub get && fvm flutter test test/engine/import`

### O2 — Reconocer y leer JSON y YAML
`openapi_importer.dart` con `matches` (JSON y sniff de YAML, Swagger) y la carga del documento (`loadYaml`,
error `That file is not valid YAML.`); sin registrar todavía.
**Aceptación:** los casos de "Reconocimiento" de la spec; un YAML válido se lee con tipos correctos
(números, booleanos, texto multilínea, claves enteras); uno inválido da el mensaje; Swagger 2.0 (JSON y
YAML) lanza el mensaje de conversión; un documento con alias anidados se carga en tiempo acotado.
**Verify:** `fvm flutter test test/engine/import/openapi`

### O3 — Referencias `$ref`
`openapi_refs.dart`: resolver punteros locales (`~0`, `~1`, `%`), anidados, ciclos, inexistentes y
externas con su aviso, sin leer nada.
**Aceptación:** los casos de la sección `$ref`; un `$ref` externo no abre ningún archivo ni URL (se prueba
con un resolver que fallaría si se le pidiera); una referencia que apunta a otra referencia se sigue hasta
un límite.
**Verify:** `fvm flutter test test/engine/import/openapi`

### O4 — Muestras de esquemas
`openapi_schema.dart`: `sampleOf(schema)` con todas las ramas de la spec y los límites (profundidad 8, 2 000
nodos, ciclo cortado) y el aviso de recorte.
**Aceptación:** cada rama de la muestra; `readOnly` omitido; 3.1 `type: [x, "null"]`; un esquema circular y
uno enorme terminan acotados con aviso; un documento con alias anidados genera su muestra en tiempo acotado.
**Verify:** `fvm flutter test test/engine/import/openapi`

### O5 — Operaciones: estructura, URL, servidor y parámetros
`openapi_operation.dart` y el recorrido de `paths` en el importador (aún sin cuerpos ni seguridad): carpeta
raíz, tags en orden, primer tag, orden de rutas y métodos, nombres y descripción, `{{base_url}}` y
`{param}`→`{{param}}`, `servers[0]` con variables, relativo/ausente/otros, parámetros path/query/header,
cookie y objeto avisados, herencia ruta→operación, variables de ambiente.
**Aceptación:** los casos de URL/servidor/parámetros/estructura de la sección de pruebas.
**Verify:** `fvm flutter test test/engine/import/openapi`

### O6 — Cuerpos
`openapi_body.dart`: elección del tipo de contenido por preferencia, JSON (`example`/`examples`/muestra, `+json`),
urlencoded, multipart (binario → archivo por elegir, `encoding`), texto/XML con `Content-Type` y sin ejemplo,
solo binario.
**Aceptación:** los casos de la tabla de cuerpos; ninguna ruta de archivo; un `$ref` roto en el esquema avisa.
**Verify:** `fvm flutter test test/engine/import/openapi`
**Checkpoint tras O6:** `fvm flutter analyze` y `fvm flutter test` completos en verde.

### O7 — Seguridad
`openapi_security.dart`: seguridad efectiva por operación (global, `[]`, alternativas), bearer, basic, apiKey
(header/query/cookie), no soportados avisados una vez por esquema, conflicto de dos esquemas, variables de
credenciales secretas y vacías en el ambiente.
**Aceptación:** los casos de la tabla de seguridad.
**Verify:** `fvm flutter test test/engine/import/openapi`

### O8 — El importador completo y el registro
Unir todo en `OpenApiImporter.parse` (+ webhooks/callbacks, renombrados, ambiente `<título> (imported)`),
las dos especificaciones realistas (JSON 3.0 y YAML 3.1) como fixtures, registro en `importers`, y los tests
que cambian (extensiones, lista de formatos).
**Aceptación:** las fixtures dan las cifras esperadas; `runImport` con el registro real elige bien entre los
cuatro formatos; `applyImport` deja carpeta y ambiente nuevos, sin activar, y `valuesToFill` suma
credenciales y archivos; un `$ref` externo no se lee; documento hostil acotado.
**Verify:** `fvm flutter test test/engine/import test/ui/import`

### O9 — UI, journey y README
Un widget test (especificación con avisos → el resumen), un journey con un YAML embebido, y el README
(formatos soportados, lo que no se importa). Marcar los criterios de la spec.
**Aceptación:** journeys verdes; README completo.
**Verify:** `fvm flutter test && fvm flutter analyze`

## Riesgos

| Riesgo | Mitigación |
|---|---|
| Un documento con alias o esquemas circulares agota tiempo o memoria | Sin copia profunda del YAML; límites de profundidad, nodos y ciclos; tests de documento hostil con un tope de tiempo |
| La variedad de OpenAPI (3.0 vs 3.1, `$ref` con vecinos, `example` vs `examples`) | Lectores tolerantes y tests por cada forma; dos especificaciones realistas, una por versión y formato |
| Claves enteras de YAML (`200:`) rompen `asMap` | Se arregla en O1 antes de usarlo, con test |
| Variables de ambiente que chocan entre operaciones (`id`) | La primera aparición manda; test que lo documenta |
| Un importador a medias registrado | No se registra hasta O8 |
| Tests de UI con I/O real intermitentes | Los nuevos usan el almacén en memoria y el diálogo falso |

## Fuera del plan (seguimiento)
- Un ambiente por servidor; duplicar la operación bajo cada tag.
- Convertir Swagger 2.0.
- OAuth2 y otros esquemas; cuerpos de texto propios en el modelo.
- Referencias externas (siempre fuera por seguridad, salvo decisión explícita).
