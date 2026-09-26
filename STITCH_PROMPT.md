# Stitch Prompt — API Flow Studio UI

Prompt en inglés (los generadores de UI por texto rinden mejor así, y la
convención de un dev tool es UI en inglés). Pégalo completo en Stitch.

---

Design a desktop developer tool called **"API Flow Studio"** — a
Postman/Insomnia-style app for testing HTTP APIs, built for a technical
audience (backend/API developers). Target platform: **desktop app**, wide
viewport (1440x900 baseline), dense information layout, not mobile-first.

## Visual style

- Dark theme by default (near-black background, e.g. #121212 / #1a1a1a),
  with a light-theme variant as an alternate screen.
- Monospace font (e.g. JetBrains Mono / Fira Code style) for URLs, JSON,
  headers, and code — a clean sans-serif (e.g. Inter) for UI chrome/labels.
- Accent color: a single vivid accent (teal or violet) used only for
  primary actions (the "Send" button, active tab indicator, active nav
  item) — everything else stays neutral gray/white so the accent stands out.
- HTTP method badges with distinct colors: GET (blue), POST (green), PUT
  (orange), PATCH (yellow), DELETE (red).
- Status code colors: 2xx green, 3xx blue, 4xx orange, 5xx red.
- Compact, information-dense spacing (like an IDE or Postman), not
  consumer-app spacious spacing.

## Screens to generate

### 1. Main workspace (request builder + response viewer)

Three-zone layout:

- **Left sidebar (fixed width, collapsible):** environment switcher at the
  top (a dropdown showing the active environment, e.g. "Development",
  with a small colored dot per environment — dev/qa/prod each a different
  color), then below it a searchable, collapsible tree of collections:
  folders (categories) containing endpoints, each endpoint row showing its
  method badge + name. A "Flows" section lower in the sidebar, listing
  saved flows by name with a small chain/link icon.
- **Center/top area:** a request bar — method dropdown, URL input (with
  `{{variable}}` tokens visually highlighted inside the text field), a
  primary "Send" button (accent color). Below the request bar, tabs:
  `Params | Headers | Body | Auth`. Each tab shows an editable key-value
  table (Params/Headers) or a JSON code editor with syntax highlighting
  (Body).
- **Bottom or right panel: response viewer** — a status line (status code
  badge, response time in ms, response size), then tabs `Body | Headers`,
  body shown as formatted/highlighted JSON with line numbers.

### 2. Environment manager (modal or full screen)

A list of environment cards/rows (Development, QA, Production, + "New
Environment" button), each showing a colored dot and variable count. Selecting
one opens a two-column key-value table (Variable / Value) that's editable
inline, with a "+ Add variable" row at the bottom.

### 3. Flow builder

A vertical, ordered list of steps (not a node graph) connected by a thin
line/connector, similar to a CI pipeline view. Each step is a card showing:
the endpoint's method badge + name, a small "extract" section listing
`variable ← response.path` mappings, and a "stop on failure" toggle. An
"+ Add step" button at the bottom picks an existing saved endpoint. Header
of the screen shows the flow's name (e.g. "User Registration Flow") and a
"Run Flow" primary button.

### 4. Flow run view

Same vertical step list as the Flow builder, but now each step shows a
result state: a status icon (checkmark/green, X/red, spinner while
running), the actual response status + time for that step, and an
expandable section to view that step's full request/response. Steps after
a failed one (when "stop on failure" is on) appear visually dimmed/skipped.

## Interaction notes to reflect visually

- The active environment's color dot should also appear as a subtle strip
  at the very top of the window, so it's obvious which environment
  (dev/qa/prod) is active without opening a menu — this prevents
  accidentally hitting production.
- `{{variable}}` tokens inside URL/header/body fields render as pill-shaped
  highlighted chips, not plain text, so unresolved variables are obvious.
- Empty states: an empty collection ("No endpoints yet — add your first
  request"), an empty flow ("No steps yet — add a saved endpoint to get
  started").

Generate the main workspace screen first, then the environment manager,
then the flow builder, then the flow run view, keeping the same design
system (colors, spacing, typography, method/status badges) consistent
across all four.
