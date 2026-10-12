# Spec: ui-theme

Módulo 1 de [SPEC-ui-redesign.md](SPEC-ui-redesign.md). Sin dependencias.

## Objective

Reemplazar la paleta actual (tokens de `design/api_flow_studio/DESIGN.md`:
índigo/cyan) por la del playground de Commodo (oscuro, acento verde lima),
**conservando las fuentes actuales (Geist y JetBrains Mono)**, de modo que todos los
módulos posteriores solo consuman tokens y no definan colores propios.

**Usuario:** el desarrollador dueño de la app (uso personal).

**Éxito:** la app compila y corre con el tema nuevo sin cambios de layout; todos
los widgets existentes muestran la paleta, tipografía y badges nuevos; ningún
color índigo/cyan viejo queda referenciado.

## Tech Stack

Flutter Desktop 3.44.6 (FVM), Material 3, `flutter_riverpod`. Fuentes: las
que ya están empaquetadas en `assets/fonts/` (Geist, JetBrains Mono); no se
agregan fuentes ni dependencias (la app es portable y funciona offline).

## Design tokens (fuente: bloque `:root` del HTML)

### Mapeo a roles M3 en `AppColors`

Se **conservan los nombres de los miembros** de `AppColors` (27 archivos los
consumen) y solo cambian sus valores, para que el cambio sea un reemplazo de
tokens y no una reescritura.

| HTML | Valor | Rol `AppColors` |
|---|---|---|
| `--bg` | `#10110e` | `surface`, `surfaceDim`, `background` |
| (pre/código) | `#0c0d0a` | `surfaceContainerLowest` |
| `--bg-2` | `#171910` | `surfaceContainerLow` |
| `--bg-3` | `#202318` | `surfaceContainer` |
| `--bg-4` | `#282b1e` | `surfaceContainerHigh` |
| (derivado) | `#31351f` | `surfaceContainerHighest`, `surfaceVariant` |
| `--text` | `#f4f5ee` | `onSurface` |
| `--muted` | `#a3a892` | `onSurfaceVariant` |
| `--faint` | `#737864` | `outline` |
| `--line` | `rgba(243,244,230,.10)` | `outlineVariant` (≈ `#2b2d26` sólido) |
| `--accent` | `#d6ff4a` | `primary` |
| `--ink` | `#141a08` | `onPrimary` |
| `--danger` | `#ff6b4a` | `error` (con `onError` = ink `#141a08`: el blanco del HTML da solo 2.8:1) |
| `--ok` | `#b6f25c` | `tertiary` |
| `--warn` | `#ffd27a` | token nuevo `warning` |

Derivados del verde lima (el HTML no los define; contraste verificado por test):

| Rol `AppColors` | Valor |
|---|---|
| `secondary` | `#a3d93a` |
| `onSecondary` | `#141a08` |
| `secondaryContainer` | `#3d5212` |
| `onSecondaryContainer` | `#e0f7a8` |
| `primaryContainer` | `#4a6600` |
| `onPrimaryContainer` | `#e6ffa0` |
| `inversePrimary` | `#5a7a00` |
| `surfaceTint` | `#d6ff4a` |
| `errorContainer` / `onErrorContainer` | `#5c1a0d` / `#ffdad2` |
| `tertiaryContainer` / `onTertiaryContainer` | `#3a5a14` / `#e8ffc4` |
| `onTertiary` | `#141a08` |

### Tokens semánticos (extensión)

- **Método:** GET `#9dffb0`, POST `#9ec1ff`, PUT `#ffd27a`, PATCH `#ffb86b`,
  DELETE `#ff8d8d`, otro = `outline`. Se muestran como texto monoespaciado
  coloreado (no como pill rellena), como en el HTML.
- **Estado HTTP:** 2xx `#b6f25c`, 3xx `#9ec1ff`, 4xx `#ffd27a`,
  5xx/0 `#ff6b4a`.
- **Variables `{{x}}`:** resueltas = acento; sin resolver = `warning`.
- **Sintaxis JSON:** clave `#d6ff4a`, string `#ffd7a8`, número `#9ec1ff`,
  booleano/null `#ff8d8d`.
- **Fondo de respuesta:** `#14160f`; fondo de banner de aviso `#2a2416`;
  fondo de callout info `#171c28`.
- **Gradiente de fondo:** radial `rgba(214,255,74,.08)` arriba a la izquierda
  sobre `surface`.

### Tipografía

- UI: **Geist** (sin cambio). Código/paths/badges: **JetBrains Mono** (sin
  cambio). `uiFontFamily`/`codeFontFamily` no se tocan.
- Se mantienen los nombres de `AppTypography`; solo se ajustan tamaños y
  tracking donde el HTML difiere (título de request 18px / -0.03em; kicker
  11px mayúsculas con 0.08em, estilo nuevo `kicker`). El resto de la escala
  se deja igual.

### Forma

Radios del HTML: campos y botones 10, pills 999, diálogos/popover 16,
bloques de código 12, filas del sidebar 8. `AppRadius` se ajusta a esta
escala. Espaciado: se conserva `AppSpacing` salvo que el shell requiera más.

## Commands

```bash
fvm flutter pub get
fvm dart run build_runner build --delete-conflicting-outputs
fvm flutter analyze
fvm flutter test test/ui/theme
fvm flutter test
fvm flutter run -d windows
```

## Project Structure

```
lib/ui/theme/
  app_colors.dart        → tokens de color (valores nuevos, mismos nombres)
  app_typography.dart    → familias y escala nuevas
  app_spacing.dart       → AppSpacing / AppRadius (radios nuevos)
  app_theme.dart         → ThemeData.dark() con componentes M3 (input, botón, dialog, tabs)
  widgets/               → method_badge, status_badge, variable_chip, json_*, app_logo
                           (app_logo pasa a la marca del HTML: cuadrado lima con dos puntos oscuros)
assets/fonts/, pubspec.yaml → sin cambios
test/ui/theme/           → app_theme_test.dart (+ tests de badges y tokens)
design/                  → exports Stitch del diseño viejo; se dejan como histórico
```

## Code Style

Igual que el código existente: `const` constructors, clases con constructor
privado para tokens, comentarios de una línea que indican el origen del
valor. Ejemplo del estilo esperado:

```dart
/// Tokens copiados de `:root` en commodo-api-playground.html.
class AppColors {
  const AppColors._();

  static const Color surface = Color(0xFF10110E); // --bg
  static const Color primary = Color(0xFFD6FF4A); // --accent
  static const Color onPrimary = Color(0xFF141A08); // --ink
  static const Color warning = Color(0xFFFFD27A); // --warn
}
```

## Testing Strategy

- `flutter_test`, tests de widgets/unitarios en `test/ui/theme/`, sin tocar
  el motor.
- Actualizar `test/ui/theme/app_theme_test.dart` a los valores nuevos y
  añadir: un test por token crítico (`primary`, `surface`, 5 métodos, 4
  rangos de estado) y que `ThemeData.textTheme` use las familias nuevas.
- Test de contraste: `onPrimary` sobre `primary` y `onSurface` sobre
  `surface` ≥ 4.5:1.
- Suite completa (`fvm flutter test`) debe seguir verde: los tests de otras
  pantallas que comparan colores o fuentes se actualizan, no se borran.
- Verificación visual: arrancar la app y comparar con el HTML abierto en el
  navegador (screenshot lado a lado).

## Boundaries

- **Always:** conservar los nombres públicos de `AppColors`/`AppTypography`;
  tokens solo vía `AppColors`, nunca hex sueltos en widgets; correr
  `analyze` + `test` antes de cada commit.
- **Ask first:** añadir dependencias o fuentes nuevas; borrar `design/`
  (decidido: queda como histórico).
- **Never:** tocar `lib/engine/`; cambiar layout o comportamiento de pantallas
  (eso es de los módulos siguientes); cambiar la familia de fuentes; dejar
  hex índigo/cyan viejos; commitear sin que `analyze` esté limpio.

## Success Criteria

- [ ] No quedan hex índigo/cyan viejos (`#6366F1`, `#06B6D4`, `#C0C1FF`,
  `#8083FF`, `#4CD7F6`) en `lib/`.
- [ ] Los hex de la tabla de tokens están en `AppColors` y cubiertos por tests.
- [ ] Las fuentes siguen siendo Geist (UI) y JetBrains Mono (código/paths).
- [ ] `MethodBadge` muestra GET/POST/PUT/PATCH/DELETE con los 5 colores nuevos.
- [ ] `StatusBadge` mapea 2xx/3xx/4xx/5xx a los colores nuevos.
- [ ] La app arranca en Windows sin errores y todas las pantallas existentes
  se ven con la paleta nueva (sin restos índigo/cyan).
- [ ] `fvm flutter analyze` limpio; `fvm flutter test` verde.
- [ ] Contraste ≥ 4.5:1 en texto principal y botón primario.

## Open Questions

Resueltas con el usuario: fuentes actuales se conservan; `secondary` se deriva
del verde lima; `design/` queda como histórico; `surfaceContainerHighest` y
`outlineVariant` derivados aprobados. Sin preguntas abiertas.

## Cambio posterior de paleta

Por petición del usuario, el acento verde lima del HTML (`#d6ff4a`) se cambió por
un violeta suave (`#a78bfa`), con `onPrimary` en un violeta oscuro (`#17102b`),
y los negros con tinte oliva pasaron a negros con tinte violeta (`surface`
`#0f0e14`, `onSurface` `#f1f0f7`, etc.). Los colores derivados (`secondary`,
contenedores, `surfaceTint`, resplandor del fondo, chips de variable) se
recalcularon sobre el violeta. El verde de éxito pasó a menta (`#86e7b0`) para
no chocar con el violeta. Los valores vigentes están en `AppColors` y en
`test/ui/theme/app_theme_test.dart`; la tabla de arriba describe la paleta
original.
