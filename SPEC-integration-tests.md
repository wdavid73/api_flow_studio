# Spec: integration tests

Complementa [SPEC.md](SPEC.md) (cuya sección "Testing Strategy" dice "sin
tests e2e/integración en v1") y los specs del rediseño de UI. No cambia el
comportamiento de la app: solo añade pruebas.

## Objective

Probar la app completa recorriendo lo que hace un usuario de principio a fin,
no pantalla por pantalla. Hoy hay 614 tests, todos unitarios o de widgets
sueltos; ninguno comprueba que, por ejemplo, un request guardado, enviado,
registrado en History y abierto de nuevo desde ahí funciona como una sola
cadena, ni que los datos sobreviven a reiniciar la app.

**Usuario:** el desarrollador dueño de la app (y quien la mantenga).

**Éxito:** un comando corre una batería de recorridos ("journeys") que usan
`ApiFlowStudioApp` real, con su motor real de variables, sesión, flows y
almacenamiento, y solo sustituyen el HTTP por un backend falso con respuestas
guiadas. Si se rompe una conexión entre módulos, un recorrido falla aunque
cada pieza siga pasando sus tests.

## Decisiones ya tomadas

- **Dos ejecutores, un solo conjunto de recorridos:** los mismos journeys se
  ejecutan (1) con `flutter_test` sobre la app completa, sin ventana, y (2) con
  el paquete `integration_test` lanzando la app real de escritorio en Windows.
  Los recorridos se escriben una vez y cada ejecutor aporta su "arnés".
- **HTTP falso:** no hay servidor local ni red. Un `FakeBackend` (un
  `RequestExecutor` de prueba con rutas guiadas) sustituye a `dio`
  sobrescribiendo `requestExecutorProvider`; así el envío con sesión, variables,
  historial y flows se ejercita de verdad.
- **Solo local:** un comando por ejecutor; no se tocan los workflows de GitHub.
- **Una dependencia nueva de desarrollo:** `integration_test` (SDK de Flutter).
- **Sin cambios en `lib/`** salvo que un recorrido destape un bug: si es pequeño
  y claro se corrige en el momento, aparte, con su propio test y commit; si
  implica rediseñar algo, se para a consultar.
- **Captura de pantalla al fallar:** cuando un recorrido falla se guarda una
  imagen PNG de la app en `build/integration_failures/` (en ambos ejecutores si
  es técnicamente posible; si en `flutter_test` no lo es, solo en Windows y se
  documenta). Es una ayuda para depurar, no un criterio de éxito de los recorridos.

## Recorridos (journeys)

Cada uno parte de una app recién abierta con datos sembrados y termina
comprobando lo que el usuario vería, no detalles internos.

1. **Arranque y navegación:** la app abre en Workspace con sus dos botones de
   header (`Hosts & notes`, sesión); se llega a Environments, Flows, History y
   de vuelta; la pastilla de ambientes aparece con los ambientes sembrados.
2. **Crear, guardar y enviar un request:** crear carpeta y request, escribir
   método y URL, guardar, enviar; el panel de respuesta muestra estado, tiempo
   y cuerpo; `Copy` copia el cuerpo y el toast lo confirma.
3. **Historial de punta a punta:** tras enviar un request guardado, aparece en
   la pestaña History del panel y en la pantalla History; pulsar la fila lo
   abre de nuevo en el Workspace; un envío fallido aparece como `Error`.
4. **Ambientes y variables:** con `{{base_url}}` en la URL, el request sale con
   el valor del ambiente activo; cambiar de ambiente en la pastilla cambia la URL
   enviada; una variable sin definir se envía literal.
5. **Sesión de login:** un login que devuelve tokens deja la sesión del ambiente
   activo (botón `Expires in …`, toast `Tokens captured for …`); el siguiente
   request lleva `Authorization: Bearer`; en otro ambiente no; `Clear tokens`
   quita el header; `curl` copiado incluye el header.
6. **Flujo de varios pasos:** crear un flow con tres requests, ejecutarlo; con
   todos OK la vista muestra `3 passed`; con un paso fallido, `1 failed` y el
   siguiente `skipped`; `Re-run` vuelve a ejecutar.
7. **Hosts y notas:** con URLs de host sembradas, abrir el diálogo, ver el aviso
   de una base ausente, editar una celda hasta que desaparezca el aviso, escribir
   una nota; el cambio se ve también en el editor de Environments.
8. **Persistencia al reiniciar:** crear datos (carpeta, request, ambiente,
   flow, nota de host), cerrar la app, abrirla de nuevo sobre el mismo
   almacenamiento y comprobar que todo sigue ahí y que los tokens de la sesión
   **no** sobreviven.
9. **Teclado:** `Ctrl+Enter` envía, `/` enfoca la búsqueda del sidebar,
   `Esc` cierra el popover de sesión y el diálogo de hosts.
10. **Ambiente de producción:** con un ambiente `Prod` sembrado y activo, la
    franja roja aparece y la pastilla marca el botón en rojo (no hay otra forma
    de probarlo: la app no permite renombrar ambientes).

## Arnés y datos de prueba

- **`FakeBackend`** (`RequestExecutor` de prueba): rutas guiadas por método y
  ruta — `POST /login` → 200 con tokens, `GET /me` → 200 con usuario si trae
  `Authorization: Bearer …` y 401 si no, `GET /items` → lista, `GET /boom` →
  error de transporte, `GET /flaky` → 500 —, y registro de cada llamada
  recibida (endpoint ya con sesión y variables) para comprobar lo que de verdad
  se envió.
- **Datos sembrados:** tres ambientes (`Dev` activo, `QA`, `Prod`) con
  `base_url` y una base ausente en `QA`; una colección con un puñado de
  requests; todo escrito en el almacenamiento antes de abrir la app.
- **Arnés por ejecutor:** una interfaz `JourneyHarness` con `launchApp()`
  (monta `ApiFlowStudioApp` con un `JsonStore` dado y el `FakeBackend`),
  `restartApp()` (desmonta y monta de nuevo sobre el mismo almacenamiento),
  `newStore()` y la ventana lógica (1440×900). En `flutter_test` el almacenamiento
  es `JsonStore.inMemory()`; en `integration_test` es una carpeta temporal real en
  disco, así el recorrido de persistencia ejercita archivos de verdad.

## Tech Stack

Flutter 3.44.6 (FVM), `flutter_test`, `integration_test` (SDK de Flutter, nueva
en `dev_dependencies`), `flutter_riverpod`, `mocktail` ya existente. Sin
paquetes de terceros nuevos.

## Commands

```bash
# Los recorridos sobre la app completa, sin ventana (rápido, cualquier máquina)
fvm flutter test test/integration

# Los mismos recorridos con la app real de escritorio (Windows)
fvm flutter test integration_test -d windows

# Todo lo demás, como siempre
fvm flutter analyze
fvm flutter test
```

`fvm flutter test` a secas debe seguir corriendo los tests de `test/`
(incluidos los `test/integration`) pero **no** los de `integration_test/`, que
requieren dispositivo.

## Project Structure

```
integration_test/
  app_test.dart                  → ejecutor con IntegrationTestWidgetsFlutterBinding (Windows)
  support/
    fake_backend.dart            → FakeBackend y rutas guiadas
    seed_data.dart               → ambientes, colección y flow sembrados
    journey_harness.dart         → interfaz JourneyHarness y helpers de pantalla
  journeys/
    navigation_journey.dart      → un archivo por recorrido; cada uno exporta
    send_request_journey.dart      `void defineXJourney(JourneyHarness Function() harness)`
    history_journey.dart
    environments_journey.dart
    session_journey.dart
    flow_journey.dart
    hosts_journey.dart
    persistence_journey.dart
    keyboard_journey.dart
    production_journey.dart
test/integration/
  journeys_test.dart             → ejecutor con flutter_test (arnés en memoria)
```

Los recorridos y el soporte viven en `integration_test/` (convención de Flutter)
y `test/integration/journeys_test.dart` los importa; así un recorrido se
escribe una vez.

## Code Style

Igual que el resto de `test/`: pruebas descriptivas que se leen como una
historia, `Key`s existentes para encontrar widgets (no textos que cambien),
sin esperas arbitrarias (`pumpAndSettle` o `pump` con duración justificada).
Un recorrido es una función que registra sus `testWidgets`:

```dart
void defineSessionJourney(JourneyHarness Function() harness) {
  group('Session journey', () {
    testWidgets('a login captures tokens and the next request carries them', (tester) async {
      final app = await harness().launchApp(tester);

      await app.send(url: '{{base_url}}/login', method: 'POST');
      expect(app.sessionButtonText, startsWith('Expires in'));

      await app.send(url: '{{base_url}}/me');
      expect(app.backend.lastCall.header('Authorization'), startsWith('Bearer '));
    });
  });
}
```

## Testing Strategy

- **Qué se prueba:** los 10 recorridos de arriba, cada uno con 2–5 pruebas
  (camino feliz, un error, un borde). Se prueba lo observable (texto en
  pantalla, lo que recibió el `FakeBackend`, lo que quedó en el almacenamiento),
  no el estado interno de los providers.
- **Qué NO se prueba aquí:** colores, tamaños, layout fino (ya cubierto por los
  tests de cada pantalla), ni HTTP real contra servidores.
- **Independencia:** cada prueba abre su propia app con su propio
  almacenamiento y `FakeBackend`; ningún recorrido depende de otro ni del orden.
- **Determinismo:** reloj de sesión inyectado (`sessionClockProvider`), tokens y
  respuestas fijas, sin red ni aleatoriedad.
- **Verificación del propio andamiaje:** al menos una prueba intencionalmente
  rota (rompiendo una conexión real, p. ej. no registrar el historial) debe hacer
  fallar el recorrido correspondiente, para comprobar que no pasan en vacío.
- **Regresión:** la suite existente (614) sigue verde y no se modifica.

## Boundaries

- **Always:** escribir cada recorrido una sola vez para ambos ejecutores;
  cada prueba con su propio almacenamiento aislado; usar `Key`s estables;
  correr `analyze` y la suite completa antes de cada commit; borrar las
  carpetas temporales al terminar.
- **Ask first:** añadir paquetes de terceros; levantar un servidor HTTP real;
  tocar los workflows de GitHub; modificar código de `lib/` para facilitar una
  prueba (salvo `Key`s).
- **Never:** usar red externa; escribir fuera de directorios temporales; dejar
  pruebas con `skip`/`@Tags` para que "pasen"; borrar o debilitar tests
  existentes; mockear el motor interno (`FlowRunner`, interpolador, sesión) en
  lugar de usarlo.

## Success Criteria

- [ ] `integration_test` añadido a `dev_dependencies` y `fvm flutter pub get` limpio.
- [ ] `FakeBackend`, datos sembrados y `JourneyHarness` en `integration_test/support/`.
- [ ] Los 10 recorridos implementados, cada uno una función reutilizable.
- [ ] `fvm flutter test test/integration` pasa con la app completa y almacenamiento en memoria.
- [ ] `fvm flutter test integration_test -d windows` pasa con la app real y disco temporal.
- [ ] `fvm flutter test` (sin argumentos) sigue verde y no intenta correr `integration_test/`.
- [ ] La prueba de "romper algo a propósito" demuestra que un recorrido falla cuando falla la conexión.
- [ ] Un recorrido que falla deja una captura PNG en `build/integration_failures/` (al menos en Windows).
- [ ] `fvm flutter analyze` limpio; la suite existente de 614 tests intacta.
- [ ] `README.md` documenta los dos comandos y `SPEC.md` ya no dice "sin tests de integración".

## Open Questions

Resueltas con el usuario: los bugs pequeños y claros que destapen los recorridos
se corrigen en el momento; se quieren capturas al fallar; se actualiza la frase
de `SPEC.md`. Una incógnita técnica queda para el plan: si
`IntegrationTestWidgetsFlutterBinding.takeScreenshot` funciona en Windows o hay
que capturar la capa raíz con `OffsetLayer.toImage` (se resuelve con una prueba
de concepto antes de implementar).
