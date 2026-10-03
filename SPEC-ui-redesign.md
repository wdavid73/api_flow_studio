# Capability Map: Rediseño UI basado en commodo-api-playground.html

Spec del rediseño visual y de layout de API Flow Studio, tomando como
referencia `C:\Users\Guicho\Documents\commodo-api-playground.html` (un
playground HTML de una sola página con tema oscuro, acento verde lima y tres
paneles). Complementa —no reemplaza— [SPEC.md](SPEC.md) (spec v1 de la app).

## Decisiones ya tomadas (confirmadas con el usuario)

- **Alcance:** toda la app (Workspace, Environments, Flows, History).
- **Tema:** la paleta nueva (verde lima) **reemplaza** a la actual
  (índigo/cyan). Un solo tema, sin selector. **Las fuentes actuales (Geist,
  JetBrains Mono) se conservan**; no se adoptan Instrument Sans/IBM Plex Mono.
- **`design/`** (exports de Stitch del diseño viejo) queda como histórico.
- **Funciones del HTML que se incorporan:** sesión/tokens, hosts por
  ambiente, filtro por método + búsqueda en el sidebar, borde rojo en prod +
  atajo Ctrl/Cmd+Enter.
- **Los datos de ejemplo de Commodo** (bases `AUTH_CORE`, rutas, etc.) no se
  embeben en la app; se cargan con Import / `sample-endpoints.json`.
- **El motor (`lib/engine/`) no cambia** salvo en `session-tokens` y
  `hosts-notes` (modelos y almacenamiento nuevos) un añadido puro en
  `workspace` (`curl_builder.dart`, el inverso del `curl_parser`) y otro en
  `secondary-screens` (`JsonStore.readAllHistory()` para el historial global) y otro en
  `session-tokens` (`lib/engine/session/`, solo en memoria: sin cambios de almacenamiento).

## Mapa

| Module id | Responsabilidad | Depende de |
|---|---|---|
| `ui-theme` | Tokens de color/tipografía/espaciado, `ThemeData`, widgets base (badges, chips de variable, JSON view, logo). Fuentes sin cambio. | — |
| `app-shell` | Header (marca, nav, selector Dev/QA/Prod en pastilla), borde rojo superior en prod, toast, layout responsive. | `ui-theme` |
| `workspace` | Sidebar (búsqueda, chips de método, grupos), constructor de request, panel de respuesta, Ctrl/Cmd+Enter. | `app-shell` |
| `session-tokens` | Sesión por ambiente, solo en memoria: access/refresh token, adjuntar Authorization, capturar tokens de 2xx, metadata JWT, borrar; botón en el header y popover. | `app-shell`, hook en el envío de `workspace` |
| `hosts-notes` | Diálogo de hosts/bases por ambiente con URL Dev/QA/Prod y avisos. | `app-shell` |
| `secondary-screens` | Environments y Flows (builder y run view) con el nuevo lenguaje visual, y History convertido en pantalla global de historial. | `ui-theme`, `app-shell` |

**Orden de construcción:**
`ui-theme` → `app-shell` → `workspace`, `secondary-screens` → `session-tokens`, `hosts-notes`

Reglas del mapa:
- Ids estables (kebab-case); no se renombran durante la iniciativa.
- Sin ciclos. Los contratos entre módulos viven en el spec del módulo
  proveedor.
- `ui-theme` es el único módulo que toca `lib/ui/theme/` (salvo widgets
  nuevos) y los widgets base compartidos.
- Cada módulo tendrá `SPEC-<module-id>.md` junto a este archivo. Specs
  escritos: `ui-theme` (aprobado e implementado), `app-shell` (aprobado e implementado), `workspace` (aprobado e implementado), `secondary-screens` (aprobado e implementado). Pendientes (se escriben en orden de dependencia
  antes de planificar cada módulo): 
  `hosts-notes`. `session-tokens` (pendiente de revisión).

## Ubicación del plan

El plan de este rediseño va en `tasks/ui-redesign/plan.md` y
`tasks/ui-redesign/todo.md`. `tasks/plan.md` y `tasks/todo.md` son del plan
v1 (con items abiertos) y no se tocan.
