# Spec: hosts-notes

Módulo 6 (el último) de [SPEC-ui-redesign.md](SPEC-ui-redesign.md). Depende de
[`app-shell`](SPEC-app-shell.md) (zona de acciones del header), ya
implementado, y reutiliza los ambientes y sus variables.

## Objective

Dar a la app el diálogo "Hosts y notas" del playground de Commodo: una sola
tabla que muestra, para cada base (host), su URL en cada ambiente, avisa de las
que faltan en alguno y permite anotar para qué sirve cada una. Así se ve de un
vistazo "a dónde va cada ambiente" y se arreglan las URLs sin abrir ambiente
por ambiente.

**Usuario:** el desarrollador dueño de la app.

**Éxito:** al abrir el diálogo desde el header se ve una fila por base y una
columna por ambiente; se edita una URL en su celda y el ambiente se guarda; las
bases que faltan en algún ambiente quedan señaladas con un aviso claro; cada
base tiene una nota editable y cuántos requests la usan.

## Decisiones ya tomadas

- **Vista matriz sobre las variables de ambiente:** no hay un catálogo de hosts
  aparte. Una "base" es una variable de ambiente cuyo valor es una URL, y se
  guarda donde siempre (`environments.json`).
- **Sin selector de versión v1/v2:** es una regla propia de Commodo y se omite.
  El usuario puede escribir `{{base_url}}/v2/...` o tener una variable por
  versión.
- **Se omiten** la tabla "Misma ruta, distinto host" y las notas fijas sobre
  Commodo del HTML: son contenido de su inventario, no de la app genérica.
- **Los textos van en inglés**, como el resto de la app.

## Comportamiento

### Qué es una base
- Una variable cuenta como base si, en al menos un ambiente, su valor (sin
  espacios en los extremos) empieza por `http://` o `https://`
  (insensible a mayúsculas) y la variable **no** está marcada como `secret`
  en ningún ambiente. Las variables secretas nunca aparecen en el diálogo.
- Las filas se ordenan alfabéticamente por nombre; las columnas siguen el orden
  de los ambientes.

### Botón y diálogo
- Botón `Hosts & notes` (fantasma) en la zona de acciones del header, a la
  izquierda del botón de sesión.
- Diálogo de hasta 1040px de ancho (`min(1040, ancho − 32)`), 16px de radio,
  `surfaceContainerLow`. Cabecera `Hosts by environment` y botón `Close`.
- Texto de ayuda: "Hosts are environment variables whose value is a URL. Edit a
  cell to change it in that environment; clear it to remove the variable there."

### Tabla
- Primera columna (fija): nombre de la base en mono, debajo `Used by N
  request(s)` en `onSurfaceVariant` (cuenta los requests guardados cuya URL
  contiene `{{nombre}}`).
- Una columna por ambiente con su nombre en la cabecera; el ambiente activo con
  un punto `primary`; los de producción (misma regla por nombre del shell) con la
  etiqueta `PROD` en `error`. Con muchos ambientes la tabla se desplaza en
  horizontal.
- Cada celda es un campo de texto mono con el valor de esa variable en ese
  ambiente. Una celda vacía significa "no definida ahí" y se dibuja con borde
  `warning` y el texto de ayuda `missing`.
- Última columna: nota de la base (campo de una línea, `Note…`).

### Edición
- Escribir en una celda guarda ese valor en el ambiente (crea la variable si no
  existía en él; los demás campos del ambiente no se tocan).
- Vaciar una celda **quita la variable de ese ambiente** (deja de estar definida
  ahí). No pide confirmación: se deshace volviendo a escribir el valor.
- Si el valor escrito deja de ser una URL en todos los ambientes, la fila
  desaparece de la tabla en cuanto se cierra el campo (la variable sigue
  existiendo). Mientras se edita, la fila no desaparece.
- La nota se guarda por nombre de base, común a todos los ambientes.
- Añadir una base nueva: botón `Add host` pide el nombre y crea la fila vacía (sin
  valor en ningún ambiente); la fila persiste hasta que se escriba una URL y,
  mientras no tenga ninguna, solo existe en el diálogo abierto.

### Avisos
- Debajo de la tabla, un aviso `warning` por cada base que falta en algún
  ambiente: `HOST_NAME isn't defined in QA, Prod. Requests that use
  {{HOST_NAME}} will be sent with that text unresolved there.`
- Si la base la usa algún request y falta en el ambiente **activo**, el aviso
  lleva además la etiqueta `ACTIVE` y se muestra primero.
- Sin avisos, un texto `Every host is defined in every environment.`
- Sin ninguna base: `No hosts yet — add an environment variable whose value is
  a URL, or use Add host.`

### Motor (aditivo, Dart puro)
- `lib/engine/hosts/host_matrix.dart`: `isHostUrl(String)`, `buildHostMatrix(
  environments, endpoints, notes)` → filas (nombre, valor por ambiente, nota,
  usos) y avisos de ausencia, y `setHostValue(Environment, name, value)` que
  devuelve el ambiente con la variable puesta o quitada.
- `JsonStore.readHostNotes()` / `writeHostNotes(Map<String, String>)` guardan
  las notas en un archivo nuevo `host_notes.json` (mapa nombre → nota). Los
  archivos existentes no cambian.

## Tech Stack

Flutter 3.44.6 (FVM), Material 3, `flutter_riverpod`. Sin dependencias nuevas.

## Commands

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test test/engine/hosts test/engine/storage test/ui/hosts
fvm flutter test
fvm flutter run -d windows
```

## Project Structure

```
lib/engine/hosts/host_matrix.dart       → isHostUrl, buildHostMatrix, setHostValue
lib/engine/storage/json_store.dart      → + readHostNotes / writeHostNotes
lib/ui/hosts/
  host_notes_provider.dart              → notas en memoria + disco
  hosts_button.dart                     → botón del header
  hosts_dialog.dart                     → diálogo, ayuda y avisos
  host_matrix_table.dart                → la tabla editable
lib/app.dart                            → HostsButton en las acciones del header
test/engine/hosts/, test/engine/storage/, test/ui/hosts/
```

## Code Style

Motor puro y funciones pequeñas; la UI usa los tokens de `ui-theme`. Ejemplo
del estilo del motor:

```dart
/// True when [value] looks like an http(s) URL (case-insensitive, trimmed).
bool isHostUrl(String value) {
  final v = value.trim().toLowerCase();
  return v.startsWith('http://') || v.startsWith('https://');
}
```

## Testing Strategy

- **Motor (unit):**
  - `isHostUrl` (http, HTTPS, con espacios; `{{x}}/api`, `ftp://`, vacío → no).
  - `buildHostMatrix`: una base que existe en un ambiente y falta en otro, una que
    está en todos, secretas excluidas, orden de filas y columnas, conteo de
    usos por `{{nombre}}`, notas.
  - `setHostValue`: crea, reemplaza, vacío quita, no toca el resto del ambiente.
  - `readHostNotes`/`writeHostNotes` en memoria y en disco, archivo ausente.
- **Widget:** botón en el header; el diálogo muestra filas y columnas; editar una
  celda actualiza el ambiente; vaciar la quita; el aviso de ausencia (con
  `ACTIVE`); `PROD` en la cabecera; la nota se guarda; estados vacíos; `Add
  host`; se cierra con `Close` y `Esc`.
- **Regresión:** los tests de ambientes y de `app_shell` no cambian de
  comportamiento; se actualizan solo si el header añade un botón.
- **Visual:** comparar con el diálogo del HTML con tres ambientes de ejemplo.

## Boundaries

- **Always:** respetar las variables `secret` (nunca mostrarlas ni editarlas aquí);
  tokens de `ui-theme`; `analyze` y `test` antes de cada commit; tests antes del
  código.
- **Ask first:** añadir campos a `Environment` o a `EnvironmentVariable`;
  introducir un catálogo de hosts propio; añadir el selector de versión.
- **Never:** borrar un ambiente ni un request desde este diálogo; reescribir las
  URLs de los requests; cambiar `environments.json` salvo la variable editada.

## Success Criteria

- [ ] `isHostUrl`, `buildHostMatrix` y `setHostValue` en `lib/engine/hosts/` con
  tests, sin importar Flutter.
- [ ] `JsonStore` guarda y lee las notas en `host_notes.json`.
- [ ] Botón `Hosts & notes` en el header y diálogo con tabla filas × ambientes.
- [ ] Editar una celda guarda el valor en ese ambiente; vaciarla quita la variable.
- [ ] Avisos de ausencia con el caso `ACTIVE`; `PROD` y el punto del ambiente
  activo en las cabeceras.
- [ ] Notas por base y conteo de requests que usan cada una.
- [ ] Las variables secretas no aparecen.
- [ ] `fvm flutter analyze` limpio y `fvm flutter test` verde.
- [ ] Comprobación visual del diálogo con tres ambientes de ejemplo.

## Open Questions

1. ¿Quieres además una nota general del espacio de trabajo (un texto libre en el
   diálogo, no atado a una base)? Propuesta: no; solo notas por base.
2. La heurística "valor que empieza por http(s)" excluye bases escritas con
   variables (`{{scheme}}://{{host}}`). Propuesta: dejarlo así y que el usuario
   use `Add host` si quiere ver una de esas; es un caso raro.
