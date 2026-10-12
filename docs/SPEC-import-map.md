# Capability Map: multipart e importación (Postman y OpenAPI)

Aprobado. Cada módulo tiene su propia spec, nombrada por su id; este mapa es el
índice de lo que existe. Se especifican, planean y construyen en el orden de abajo.

| Module id | Responsabilidad | Depende de | Spec |
|---|---|---|---|
| `multipart-body` | Cuerpo `multipart/form-data` con campos de texto y de archivo: modelo (variante nueva de `RequestBody`), envío con `dio`, editor en la pestaña Body, `-F` en el curl copiado y pegado, y cambio de versión del formato de workspace. | — | [SPEC-multipart-body.md](SPEC-multipart-body.md) |
| `import-core` | Base común de toda importación: resultado puro (carpetas, requests, ambientes y avisos), detección del formato del archivo, inserción no destructiva en una carpeta nueva del proyecto activo, resumen de lo importado y lo omitido. Mueve a engine la importación del JSON propio, hoy dentro de `sidebar_tree.dart`. | — | [SPEC-import-core.md](SPEC-import-core.md) |
| `postman-import` | Colección Postman v2.1 y archivo de ambientes: carpetas, requests, cuerpos (raw/JSON, urlencoded, formdata), auth bearer/basic, variables. Los scripts no se ejecutan y se avisa. | `multipart-body`, `import-core` | [SPEC-postman-import.md](SPEC-postman-import.md) |
| `openapi-import` | OpenAPI 3.0/3.1: un request por ruta y método agrupado por tag, `servers` → `base_url`, parámetros, cuerpo de ejemplo, seguridad como auth con marcador. | `multipart-body`, `import-core` | [SPEC-openapi-import.md](SPEC-openapi-import.md) |

**Orden de build:** `multipart-body` e `import-core` (independientes) → `postman-import` y
`openapi-import` (independientes entre sí).

## Interfaces en el límite
- `import-core` define el tipo de resultado y el contrato "un importador recibe el texto y
  devuelve resultado más avisos". Los dos importadores lo implementan; la UI solo conoce el contrato.
- `multipart-body` expone la variante de `RequestBody` que usan los importadores
  (`formdata` de Postman, `multipart/form-data` de OpenAPI).
- **Regla común a todo lo que lee un archivo ajeno** (definida en `multipart-body`, obligatoria
  para `import-core` y los importadores): las rutas de archivo de un cuerpo multipart **nunca se
  importan**; el campo queda como archivo sin elegir y se cuenta como valor por rellenar.

## Supuestos
1. Toda importación crea una carpeta nueva con el nombre de la colección o la spec; no sobrescribe ni mezcla.
2. Postman: solo v2.1 en JSON. OpenAPI: solo 3.0 y 3.1, no Swagger 2.0.
3. Lo que no se puede traducir no rompe la importación: se omite o se simplifica y queda en los avisos.
4. `engine/` sin imports de Flutter; TDD; un commit por tarea.

## Decisiones tomadas al aprobar el mapa
(Las preguntas del mapa se resolvieron con la recomendación de cada una; se revisan si cambias de idea.)
1. **YAML:** `openapi-import` añadirá la dependencia `yaml` (paquete de dart-lang) para leer specs en YAML.
2. **Rutas de archivo al exportar un workspace:** se vacían, igual que los secretos, y se cuentan en "valores por rellenar".
3. **Runner CLI:** una ruta relativa se resuelve desde el directorio de trabajo; un archivo inexistente falla el paso con un mensaje claro.
4. **Variables de una colección Postman:** crean un ambiente nuevo (`<colección> (imported)`); un archivo de ambientes Postman también se puede importar por separado.
5. **`multipart-body` sale primero y solo**, antes de las importaciones.
