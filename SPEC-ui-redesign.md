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
  `hosts-notes`, que necesitan modelos y almacenamiento nuevos.

## Mapa

| Module id | Responsabilidad | Depende de |
|---|---|---|
| `ui-theme` | Tokens de color/tipografía/espaciado, `ThemeData`, widgets base (badges, chips de variable, JSON view, logo). Fuentes sin cambio. | — |
| `app-shell` | Header (marca, nav, selector Dev/QA/Prod en pastilla), borde rojo superior en prod, toast, layout responsive. | `ui-theme` |
| `workspace` | Sidebar (búsqueda, chips de método, grupos), constructor de request, panel de respuesta, Ctrl/Cmd+Enter. | `app-shell` |
| `session-tokens` | Popover de sesión: access/refresh token, adjuntar Authorization, capturar tokens de 2xx, metadata JWT, borrar. | `app-shell`, hook en el envío de `workspace` |
| `hosts-notes` | Diálogo de hosts/bases por ambiente con URL Dev/QA/Prod y avisos. | `app-shell` |
| `secondary-screens` | Environments, Flows (builder y run view) e History con el nuevo lenguaje visual. Solo restyling. | `ui-theme`, `app-shell` |

**Orden de construcción:**
`ui-theme` → `app-shell` → `workspace`, `secondary-screens` → `session-tokens`, `hosts-notes`

Reglas del mapa:
- Ids estables (kebab-case); no se renombran durante la iniciativa.
- Sin ciclos. Los contratos entre módulos viven en el spec del módulo
  proveedor.
- `ui-theme` es el único módulo que toca `lib/ui/theme/` (salvo widgets
  nuevos) y los widgets base compartidos.
- Cada módulo tendrá `SPEC-<module-id>.md` junto a este archivo. Specs
  escritos: `ui-theme` (aprobado e implementado), `app-shell` (aprobado). Pendientes (se escriben en orden de dependencia
  antes de planificar cada módulo): `workspace`,
  `secondary-screens`, `session-tokens`, `hosts-notes`.

## Ubicación del plan

El plan de este rediseño va en `tasks/ui-redesign/plan.md` y
`tasks/ui-redesign/todo.md`. `tasks/plan.md` y `tasks/todo.md` son del plan
v1 (con items abiertos) y no se tocan.
