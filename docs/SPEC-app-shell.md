# Spec: app-shell

Módulo 2 de [SPEC-ui-redesign.md](SPEC-ui-redesign.md). Depende de
[`ui-theme`](SPEC-ui-theme.md) (ya implementado).

## Objective

Rediseñar el marco de la app (lo que rodea a cada pantalla) según el header
del playground de Commodo y dar a los módulos siguientes los puntos de
anclaje que necesitan: un header con espacio para acciones, un banner de
avisos, un toast y la señal visual de "estás en producción".

**Usuario:** el desarrollador dueño de la app.

**Éxito:** al abrir la app se ve el header nuevo con el selector de ambiente
en pastilla; al activar un ambiente de producción aparece un borde rojo
arriba; cualquier pantalla puede mostrar un toast o un banner con una línea
de código; las cuatro pantallas actuales siguen funcionando igual.

## Decisiones ya tomadas

- **Prod se detecta por nombre**, sin cambiar el motor: un ambiente es prod si
  su nombre, sin distinguir mayúsculas ni espacios en los extremos, es `prod`,
  `production` o `prd`.
- **Selector en pastilla segmentada**, un botón por ambiente, como el HTML.
  Con más de 4 ambientes, los primeros 3 se muestran como botones y el resto
  van a un botón `…` con menú.
- Se conserva la navegación por destinos (Workspace, Environments, Flows,
  History); el HTML no la tiene porque es una sola pantalla.
- Sin cambios en `lib/engine/`.

## Comportamiento

### Header (reemplaza `_NavBar`)
- Izquierda: `AppLogoMark` (28px) + nombre "API Flow Studio" (peso 650,
  tracking -0.03em) y debajo un subtítulo pequeño en `onSurfaceVariant`
  ("Local API workspace", texto provisional).
- Centro-izquierda: destinos de navegación como pastillas; el activo con
  fondo `surfaceContainerHigh` y texto `onSurface`.
- Después de la navegación: selector de ambiente (abajo).
- Derecha (`Spacer` + zona de acciones): contenedor vacío en este módulo, donde
  `hosts-notes` y `session-tokens` añaden sus botones. El shell expone el
  widget `HeaderGhostButton` (borde `outlineVariant`, radio 10, texto 13px)
  para que esos botones se vean iguales al del HTML.
- Fondo `surface` al 90% con borde inferior `outlineVariant`; alto 56.
- Con ancho < 1100 el header pasa a varias líneas (`Wrap`) sin cortar nada.

### Selector de ambiente
- Pastilla redondeada (fondo `surfaceContainer`, borde `outlineVariant`,
  padding 3). Cada botón: texto 13px/600; el activo con fondo `primary` y
  texto `onPrimary`; el activo de prod con fondo `error` y texto `onError`.
- Al pulsar llama a `environmentsProvider.notifier.setActive(id)`; mismo
  efecto inmediato que el dropdown actual.
- Sin ambientes: no se muestra (igual que hoy).
- Mantiene la `Key('environment-switcher')` en el contenedor.

### Señal de producción
- Si el ambiente activo es prod: franja de 3px en `error` en el borde
  superior de la ventana. Si no, no hay franja (hoy hay una de color por
  ambiente; se elimina).
- Mantiene la `Key('active-environment-strip')`; en no-prod el widget existe
  con alto 0 para que las pruebas lo encuentren.

### Banner
- `bannerProvider` (`StateProvider<AppBanner?>`) con `AppBanner(message,
  kind)` donde `kind` ∈ `warning` (fondo `bannerBackground`, texto
  `warning`) o `info` (fondo `infoBackground`, texto `onSurfaceVariant`).
- Se dibuja debajo del header, a todo el ancho, 13px, con borde inferior; el
  texto admite fragmentos en código (JetBrains Mono 12px).
- `null` = oculto, sin ocupar espacio.

### Toast
- `toastProvider` + función `showToast(WidgetRef ref, String message)`.
- Pastilla `primary`/`onPrimary`, 13px/650, centrada abajo a 16px del borde,
  aparece con fade + desplazamiento de 12px en 160ms y se oculta a los
  2200ms. Un toast nuevo reemplaza al anterior y reinicia el temporizador.
- Se dibuja como overlay encima de cualquier destino y no intercepta clics.

### Fondo
- Gradiente radial `rgba(214,255,74,.08)` arriba a la izquierda sobre
  `surface`, detrás de todo el shell.

## Tech Stack

Flutter 3.44.6 (FVM), Material 3, `flutter_riverpod` (`StateProvider` ya se
usa en `app.dart`). Sin dependencias nuevas; tema, fuentes y tokens de
`ui-theme`.

## Commands

```bash
fvm flutter pub get
fvm flutter analyze
fvm flutter test test/ui/app_shell_test.dart test/ui/shell
fvm flutter test
fvm flutter run -d windows
```

## Project Structure

```
lib/app.dart                          → ApiFlowStudioApp + AppShell (se adelgaza)
lib/ui/shell/
  app_header.dart                     → header, navegación, zona de acciones
  environment_pill.dart               → selector segmentado + menú de desbordamiento
  header_ghost_button.dart            → botón fantasma reutilizable por otros módulos
  production_strip.dart               → franja roja (reemplaza ActiveEnvironmentStrip)
  app_banner.dart                     → bannerProvider + widget
  app_toast.dart                      → toastProvider + overlay + showToast
  environment_kind.dart               → isProductionEnvironment(name)
lib/ui/environments/
  active_environment_strip.dart       → se elimina (lo sustituye production_strip)
  environment_switcher.dart           → se elimina (lo sustituye environment_pill)
test/ui/shell/                        → tests por archivo de arriba
test/ui/app_shell_test.dart           → se actualiza
```

## Code Style

Igual que el resto de `lib/ui`: widgets `const`, estado con Riverpod,
tokens solo de `AppColors`/`AppTypography`/`AppRadius`, sin hex sueltos.
Ejemplo de la regla de producción (puro y probable sin widgets):

```dart
/// True when [name] denotes a production environment (case-insensitive).
bool isProductionEnvironment(String name) {
  const names = {'prod', 'production', 'prd'};
  return names.contains(name.trim().toLowerCase());
}
```

## Testing Strategy

- **Unit:** `isProductionEnvironment` (prod, PROD, " Production ", prd; no:
  "staging", "preprod", "product").
- **Widget:**
  - Header muestra marca, 4 destinos y selecciona el activo.
  - Pastilla: un botón por ambiente, el activo con `primary`, el de prod con
    `error`; pulsar cambia el activo; con 5 ambientes aparece el menú `…`.
  - Franja: roja con ambiente prod activo, alto 0 con otro o ninguno.
  - Banner: `null` no ocupa espacio; `warning` e `info` usan sus colores.
  - Toast: aparece con el mensaje, desaparece a los 2200ms (usar
    `tester.pump(Duration)`), uno nuevo reemplaza al anterior.
- **Regresión:** `app_shell_test` y `variable_interpolation_test` (que hoy
  comprueba el color de la franja por ambiente) se actualizan, no se borran.
- **Visual:** arrancar la app, alternar ambientes, comparar con el header del
  HTML.

## Boundaries

- **Always:** conservar las `Key` existentes que usan los tests
  (`environment-switcher`, `active-environment-strip`); usar los tokens de
  `ui-theme`; correr `analyze` y `test` antes de cada commit.
- **Ask first:** añadir el campo "es producción" al modelo; cambiar los
  nombres de los destinos o añadir uno nuevo; añadir dependencias.
- **Never:** tocar `lib/engine/`; implementar el popover de sesión o el
  diálogo de hosts (son de otros módulos); cambiar el contenido de las
  pantallas de destino; dejar el dropdown viejo conviviendo con la pastilla.

## Success Criteria

- [ ] Header con marca, subtítulo, 4 destinos, pastilla de ambiente y zona de
  acciones vacía.
- [ ] Pastilla: activo en `primary`, activo prod en `error`; cambiar de
  ambiente actualiza la interpolación de variables como antes.
- [ ] `isProductionEnvironment` cubierto por tests de los casos listados.
- [ ] Franja roja de 3px solo con ambiente prod activo.
- [ ] `bannerProvider` y `showToast` funcionan desde cualquier destino y están
  cubiertos por tests.
- [ ] `HeaderGhostButton` exportado y usado en un test como ejemplo.
- [ ] Sin referencias a `EnvironmentSwitcher` ni `ActiveEnvironmentStrip`.
- [ ] `fvm flutter analyze` limpio y `fvm flutter test` verde.
- [ ] Comparación visual con el HTML hecha en una ventana ≥ 1100px y en una
  < 1100px.

## Open Questions

1. El subtítulo bajo el nombre ("Local API workspace") es texto provisional;
   el HTML dice "API playground". ¿Cuál prefieres?
2. Con más de 4 ambientes, ¿te sirve el menú `…`, o prefieres que la pastilla
   haga scroll horizontal?
