# Spec: web-deploy

Publicar API Flow Studio como app web en GitHub Pages, además de las apps de escritorio.

Estado: **borrador para revisión** (nada implementado todavía).
Decisiones ya tomadas con el equipo: CORS = avisar y documentar; persistencia = `localStorage`;
despliegue = en cada push a `master`.

## Objetivo

Que cualquier persona abra `https://wdavid73.github.io/api_flow_studio/` y use la app sin instalar
nada: armar requests, enviarlas, encadenarlas en flows, importar/exportar, cambiar de idioma, y
**encontrar sus datos al volver** (hoy en web todo vive en memoria y se pierde al recargar).

Usuarias/os: quien quiere probar la app o consultar su workspace desde otro equipo sin instalar el
binario; el equipo, para compartir un enlace en lugar de un zip.

La web **no reemplaza** al escritorio: hay cosas que un navegador no puede hacer (ver
[Límites del navegador](#límites-del-navegador)) y la app debe decirlo en vez de fallar en silencio.

### Qué se encontró al analizar el proyecto

`flutter build web --release --base-href /api_flow_studio/` **ya compila** (38 s, 43 MB en `build/web`)
y la app arranca sin errores de consola. Lo que falla es en ejecución:

| # | Qué | Dónde | Efecto hoy en web |
|---|---|---|---|
| 1 | Datos solo en memoria | `JsonStore` (`_memory` si `_isWeb`), `ProjectsRepository.inMemory()` en `main.dart`, idioma saltado con `kIsWeb` | Se pierde todo al recargar; el idioma elegido tampoco se recuerda |
| 2 | Importar archivos | `import_file_dialogs.dart`, `workspace_file_dialogs.dart` leen `result.files.single.path` | `path` no existe en web: lanza error. Import de colecciones, OpenAPI/Postman y workspace no funcionan |
| 3 | Exportar archivos | `workspace_file_dialogs.dart`, `_exportCollections` (`sidebar_tree.dart`) usan `saveFile` + `File(path).writeAsString` | `File` no existe en web. Exportar workspace/endpoints/flows no funciona |
| 4 | Import grande en otro isolate | `import_actions.dart` → `Isolate.run` para archivos > 256 KB | `Isolate.run` no existe en web: los archivos grandes fallan |
| 5 | Subir archivos (Form Data) | `request_executor.dart` → `MultipartFile.fromFile(path)`; `file_picker_service.dart` | Sin ruta local no hay archivo que enviar |
| 6 | CORS | el navegador | Las APIs que no permitan el origen `github.io` fallan con un error de red genérico |
| 7 | Cabeceras y cookies | el navegador | `Cookie`, `User-Agent`, `Host`… se ignoran al enviar; `Set-Cookie` no se puede leer (la pestaña Cookies sale vacía) |
| 8 | Contenido mixto | el navegador | Una página `https` no puede llamar a `http://` (salvo `localhost`) |
| 9 | Runner de terminal | `bin/`, `lib/cli/` | No aplica a web (se queda solo en escritorio) |

## Supuestos

1. Repo `wdavid73/api_flow_studio`; URL final `https://wdavid73.github.io/api_flow_studio/`
   (de ahí `--base-href /api_flow_studio/`).
2. GitHub Pages disponible para ese repo (público, o plan que lo permita). **Acción manual de
   quien administra el repo:** Settings → Pages → Source: *GitHub Actions*.
3. Se despliega el build **CanvasKit por defecto** (sin `--wasm` por ahora).
4. Navegadores modernos de escritorio (Chrome, Edge, Firefox, Safari recientes). Móvil: no es objetivo.
5. Un solo origen (`wdavid73.github.io`) comparte `localStorage` con cualquier otra página de ese
   usuario: las claves llevan prefijo `afs:` para no chocar.
6. Los workflows de escritorio (`release.yml`) no cambian.

## Límites del navegador

Se aceptan y se **comunican en la UI y en el README**, no se intentan evitar:

- **CORS:** si una petición falla por red en web, el panel de respuesta añade una pista: «En el
  navegador esto suele ser CORS: la API debe permitir el origen de esta página, o usa la app de
  escritorio». (Un fallo de red y uno de CORS son indistinguibles para el código: es una pista, no
  un diagnóstico.)
- **Form Data con archivos:** el campo *File* no está disponible en web (se muestra deshabilitado
  con una nota). Los campos *Text* funcionan.
- **Cookies:** la pestaña muestra «El navegador no expone Set-Cookie».
- **`http://`:** una URL `http://` que no sea `localhost` se avisa como contenido mixto.
- **Almacenamiento:** `localStorage` tiene unos 5 MB por origen. Si se llena, se avisa con un toast
  («No hay espacio en el navegador: exporta tu workspace y borra historial») y **no se pierde lo ya
  guardado**.

## Stack

- Flutter 3.44.6 (el de `.fvmrc` y `release.yml`), Dart 3.12.2, Riverpod, dio, file_picker 8.x.
- Nueva dependencia directa: `web` (acceso a `window.localStorage` y a la descarga de archivos;
  ya llega transitiva con Flutter). **Pedir aprobación antes de añadirla.**
- GitHub Actions: `actions/checkout`, `subosito/flutter-action` (como `release.yml`),
  `actions/configure-pages`, `actions/upload-pages-artifact`, `actions/deploy-pages`.

## Comandos

```
Analizar:        fvm flutter analyze
Tests:           fvm flutter test
Build web:       fvm flutter build web --release --base-href /api_flow_studio/
                 (en Git Bash anteponer MSYS_NO_PATHCONV=1, o usar PowerShell)
Servir local:    cd build && python -m http.server 8099   # abrir /web/ con base-href "/"
                 o: fvm flutter run -d chrome
Test en Chrome:  fvm flutter test --platform chrome test/web   # solo los tests de web
```

## Estructura del proyecto

```
lib/engine/storage/
  json_store.dart            → ya existe: ahora recibe un KeyValueBackend en vez de ramificar por _isWeb
  key_value_backend.dart     → interfaz (read/write/remove por clave) + MemoryBackend
  local_storage_backend.dart → backend de localStorage (prefijo afs:, maneja QuotaExceeded)
  local_storage_backend_stub.dart → stub para VM (import condicional, if (dart.library.js_interop))
lib/engine/projects/projects_repository.dart → ProjectsRepository.web(backend): índice + un JsonStore por proyecto
lib/ui/files/                → nuevo: abstracción de archivos web/escritorio
  file_io.dart               → interfaz pick/save con bytes (no rutas)
  file_io_io.dart, file_io_web.dart → implementaciones (import condicional)
lib/ui/response_viewer/      → pista de CORS y nota de cookies en web
lib/ui/request_builder/      → campo File deshabilitado en web
web/index.html, manifest.json → ya con nombre y descripción; añadir <meta> de theme-color
.github/workflows/pages.yml  → build + deploy a GitHub Pages
test/web/                    → tests que corren en Chrome (backend de localStorage)
docs/SPEC-web-deploy.md      → este archivo
```

## Estilo de código

El del proyecto: modelos inmutables con freezed, estado con Riverpod, dependencias de plataforma
detrás de una interfaz inyectable por provider (como `ImportFileDialogs`), de modo que los tests
usan un fake y no un diálogo real. Ejemplo del patrón a seguir:

```dart
/// Lee y escribe texto por clave. Detrás de una interfaz para que JsonStore no sepa si hay
/// disco, localStorage o memoria.
abstract interface class KeyValueBackend {
  Future<String?> read(String key);
  Future<void> write(String key, String value); // lanza StorageFullException si no cabe
  Future<void> remove(String key);
}
```

Reglas: nada de `if (kIsWeb)` repartido por la UI; la diferencia vive en un solo punto
(import condicional o provider) y el resto del código no la conoce. Textos nuevos, siempre en
ambos `.arb` (en/es).

## Estrategia de pruebas

| Qué | Cómo | Dónde |
|---|---|---|
| Lógica de `JsonStore` sobre un backend | tests existentes + `MemoryBackend` (VM) | `test/engine/storage/` |
| `ProjectsRepository.web` (índice, proyectos, borrar) | VM con `MemoryBackend` | `test/engine/projects/` |
| Backend real de `localStorage` (prefijo, cuota llena) | `--platform chrome` | `test/web/` |
| Import/export vía `file_io` | fakes de `FileIo`; la ruta de descarga web se prueba en Chrome | `test/ui/…`, `test/web/` |
| Pista de CORS, campo File deshabilitado | widget tests con un flag de plataforma inyectado | `test/ui/…` |
| Build web + despliegue | el workflow corre `analyze`, `test` y `build web` antes de publicar | CI |
| Humo manual en la URL publicada | lista de verificación abajo | manual |

Los tests existentes (1712) deben seguir pasando sin cambios.

## Límites de trabajo

**Siempre**
- Correr `flutter analyze` y `flutter test` antes de cada commit.
- Mantener los textos en los dos `.arb`.
- Que el escritorio siga funcionando igual: ningún cambio de comportamiento fuera de web.
- Guardar nada personal en la web más allá de lo que ya se guarda en disco (los secretos siguen
  fuera de los archivos exportados).

**Preguntar antes**
- Añadir la dependencia `web` u otra nueva.
- Cambiar el formato de los datos guardados o su versión.
- Activar `--wasm`, un proxy CORS, o cualquier servicio externo.
- Tocar `release.yml`.

**Nunca**
- Subir tokens o secretos a `localStorage` en claro **sin** que ya estén en el modelo de datos
  actual (la sesión de tokens sigue solo en memoria).
- Enviar el tráfico de las peticiones del usuario a un servidor propio o de terceros.
- Eliminar tests que fallen para que el CI pase.
- Hacer commit de `build/`.

## Criterios de éxito

1. `https://wdavid73.github.io/api_flow_studio/` carga la app sin errores de consola.
2. Recargar la página conserva proyectos, colecciones, entornos, flows, historial e idioma.
3. Una petición `GET` a una API con CORS abierto responde y se ve en el panel (probar con una API
   pública de prueba).
4. Una petición bloqueada por CORS muestra la pista del navegador, no solo «network error».
5. Importar un `.workspace.json`, una colección Postman y un OpenAPI **grande (> 256 KB)** funciona.
6. Exportar workspace, endpoints y flows descarga el archivo con el nombre esperado.
7. Con el `localStorage` lleno, guardar avisa y no corrompe lo existente.
8. El campo *File* de Form Data aparece deshabilitado con su nota.
9. Un push a `master` publica la web sin intervención; un fallo de `analyze`/`test`/`build` **no**
   publica.
10. `release.yml` y las apps de escritorio no cambian de comportamiento.

## Lista de verificación manual (humo en la URL)

- [ ] Abre sin errores; el título es «API Flow Studio» y el icono nuevo aparece en la pestaña.
- [ ] Crear carpeta + request, recargar: siguen ahí.
- [ ] Cambiar a Español, recargar: sigue en español.
- [ ] Enviar a una API con CORS abierto: respuesta correcta.
- [ ] Enviar a una API sin CORS: aparece la pista.
- [ ] Importar `sample-flows.json` y `sample-endpoints.json`.
- [ ] Exportar workspace y volver a importarlo.
- [ ] Llenar el almacenamiento (historial enorme) y comprobar el aviso.

## Plan de implementación (orden de dependencias)

Una sola especificación con cuatro cortes verticales, cada uno verificable por separado:

1. **Persistencia web** — `KeyValueBackend`, `LocalStorageBackend`, `JsonStore` sobre backend,
   `ProjectsRepository.web`, idioma persistente en web. *(Desbloquea 2 y 3.)*
2. **Archivos sin rutas** — `FileIo` con bytes; import (incluye grandes sin `Isolate`), export por
   descarga; campo *File* deshabilitado en web.
3. **Mensajes del navegador** — pista de CORS, nota de cookies, aviso `http://`, aviso de cuota.
4. **Despliegue** — `pages.yml`, README (URL, límites, cómo activar Pages), verificación manual.

El plan detallado y la lista de tareas irán a `tasks/plan.md` y `tasks/todo.md` cuando esta spec
esté aprobada.

## Preguntas abiertas

1. ¿El repositorio es **público**? Pages en repos privados exige un plan de pago.
2. ¿Quieres un **dominio propio** (`CNAME`) más adelante? Cambiaría `--base-href` a `/`.
3. ¿La web debe **mostrar la versión** (la de `pubspec.yaml`) en el pie de la barra lateral? Hoy
   ya la muestra; confirmar que el valor sale bien en web.
4. ¿Hace falta **analítica** o algo parecido? Por defecto: ninguna.
