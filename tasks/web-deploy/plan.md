# Plan: web-deploy

Spec: [SPEC-web-deploy.md](../../docs/SPEC-web-deploy.md). Estado: **aprobada** (repo público; dependencia `web` aprobada).

## Decisiones de diseño

1. **Un backend de clave-valor, no un `if (kIsWeb)` por todos lados.** `JsonStore` ya tiene un modo
   "en memoria" que guarda `nombre de archivo → texto JSON`. Ese modo pasa a ser un
   `KeyValueBackend` intercambiable: `MemoryBackend` (tests), `LocalStorageBackend` (web). El disco
   queda como está (archivos con escritura atómica): no se toca para no arriesgar el escritorio.
2. **Prefijos por proyecto.** En `localStorage` cada archivo es una clave `afs:<ámbito>:<archivo>`:
   `afs:index:projects.json`, `afs:p:<idProyecto>:flows.json`, `afs:app:app_settings.json`. Borrar un
   proyecto borra sus claves por prefijo.
3. **Import condicional, no ramas en la UI.** El backend de `localStorage` y el de descarga de
   archivos viven en archivos `*_web.dart` / `*_stub.dart` elegidos con
   `if (dart.library.js_interop)`. El resto del código solo ve la interfaz.
4. **Archivos con bytes, no con rutas.** Los diálogos devuelven `PickedImportFile` (ya tiene `name`,
   `sizeBytes`, `read()`): en web se arma desde los bytes que entrega `file_picker`. Exportar usa
   `FilePicker.saveFile(bytes: …)`, que en web descarga el archivo.
5. **Cuota llena = error tipado.** `StorageFullException` sale del backend; los puntos de escritura
   de la UI la capturan en el corte 3 (toast). Hasta entonces se propaga igual que cualquier error
   de escritura de hoy.
6. **Despliegue separado.** `pages.yml` no toca `release.yml`. Corre `analyze` + `test` antes de
   construir; solo despliega si todo pasa.

## Orden y dependencias

```
W1 backend ─┬─> W2 JsonStore sobre backend ──> W3 ProjectsRepository.web ──> W4 main (web persiste, idioma)
            │
            └─ (independientes entre sí) ─> W5 file picker web ─> W6 export web ─> W7 import grande sin Isolate
                                            W8 Form Data/File ┐
                                            W9 pistas (CORS, cookies, http, cuota) ┘
W10 pages.yml ──> W11 README + verificación
```

Checkpoints: tras W4 (persistencia completa), tras W7 (archivos), tras W9 (mensajes), y final tras
W11.

## Riesgos

| Riesgo | Mitigación |
|---|---|
| `localStorage` ~5 MB y el historial crece | Los límites de historial ya existen; `StorageFullException` + aviso (W9). Prueba con cuota llena en Chrome (W1). |
| `dart:io` sigue importado en archivos de `lib/` | Compila en web (verificado); solo se evita **usarlo** en rutas web. Los archivos con `File` quedan detrás de la interfaz. |
| `flutter test --platform chrome` necesita Chrome en CI | `ubuntu-latest` ya trae Chrome; localmente se prueba a mano. |
| Service worker de Flutter sirve la versión vieja tras desplegar | Es el comportamiento normal (recarga la nueva al segundo arranque); se documenta en el README. |
| `file_picker` 8.x en web: `saveFile` exige `bytes` | Verificado al implementar W6; si falta, descarga con `package:web` (`<a download>`). |
| Git Bash convierte `--base-href /x/` en una ruta de Windows | Documentado en el spec: `MSYS_NO_PATHCONV=1` o PowerShell. |
