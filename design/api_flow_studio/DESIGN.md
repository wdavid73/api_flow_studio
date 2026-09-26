---
name: API Flow Studio
colors:
  surface: '#111319'
  surface-dim: '#111319'
  surface-bright: '#373940'
  surface-container-lowest: '#0c0e14'
  surface-container-low: '#191b22'
  surface-container: '#1e1f26'
  surface-container-high: '#282a30'
  surface-container-highest: '#33343b'
  on-surface: '#e2e2eb'
  on-surface-variant: '#c7c4d7'
  inverse-surface: '#e2e2eb'
  inverse-on-surface: '#2e3037'
  outline: '#908fa0'
  outline-variant: '#464554'
  surface-tint: '#c0c1ff'
  primary: '#c0c1ff'
  on-primary: '#1000a9'
  primary-container: '#8083ff'
  on-primary-container: '#0d0096'
  inverse-primary: '#494bd6'
  secondary: '#4cd7f6'
  on-secondary: '#003640'
  secondary-container: '#03b5d3'
  on-secondary-container: '#00424e'
  tertiary: '#4edea3'
  on-tertiary: '#003824'
  tertiary-container: '#00885d'
  on-tertiary-container: '#000703'
  error: '#ffb4ab'
  on-error: '#690005'
  error-container: '#93000a'
  on-error-container: '#ffdad6'
  primary-fixed: '#e1e0ff'
  primary-fixed-dim: '#c0c1ff'
  on-primary-fixed: '#07006c'
  on-primary-fixed-variant: '#2f2ebe'
  secondary-fixed: '#acedff'
  secondary-fixed-dim: '#4cd7f6'
  on-secondary-fixed: '#001f26'
  on-secondary-fixed-variant: '#004e5c'
  tertiary-fixed: '#6ffbbe'
  tertiary-fixed-dim: '#4edea3'
  on-tertiary-fixed: '#002113'
  on-tertiary-fixed-variant: '#005236'
  background: '#111319'
  on-background: '#e2e2eb'
  surface-variant: '#33343b'
typography:
  headline-lg:
    fontFamily: Geist
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  headline-md:
    fontFamily: Geist
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 24px
  headline-sm:
    fontFamily: Geist
    fontSize: 14px
    fontWeight: '600'
    lineHeight: 20px
  body-lg:
    fontFamily: Geist
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-md:
    fontFamily: Geist
    fontSize: 13px
    fontWeight: '400'
    lineHeight: 18px
  body-sm:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 16px
  code-lg:
    fontFamily: JetBrains Mono
    fontSize: 13px
    fontWeight: '500'
    lineHeight: 20px
  code-md:
    fontFamily: JetBrains Mono
    fontSize: 12px
    fontWeight: '400'
    lineHeight: 18px
  code-sm:
    fontFamily: JetBrains Mono
    fontSize: 11px
    fontWeight: '400'
    lineHeight: 16px
  label-md:
    fontFamily: Geist
    fontSize: 12px
    fontWeight: '500'
    lineHeight: 16px
    letterSpacing: 0.01em
  label-sm:
    fontFamily: Geist
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
    letterSpacing: 0.02em
  badge-mono:
    fontFamily: JetBrains Mono
    fontSize: 10px
    fontWeight: '700'
    lineHeight: 12px
    letterSpacing: 0.04em
rounded:
  sm: 0.125rem
  DEFAULT: 0.25rem
  md: 0.375rem
  lg: 0.5rem
  xl: 0.75rem
  full: 9999px
spacing:
  gutter: 1px
  gutter-split: 4px
  margin: 0.75rem
  space-xs: 0.25rem
  space-sm: 0.375rem
  space-md: 0.625rem
  space-lg: 0.875rem
  space-xl: 1.25rem
---

## Brand & Style

This design system delivers a high-density, professional developer cockpit optimized for sustained technical workflows. It addresses backend engineers, API architects, and QA automation teams who require surgical precision, extreme data density, and zero visual friction.

The aesthetic merges **minimalism** with **high-contrast developer-tool utility**:
- Deep, balanced slate-black foundations eliminate eye fatigue across multi-monitor setups.
- Visual hierarchy is established strictly through crisp 1px structural outlines and luminous semantic tokens rather than gratuitous drop shadows or blurred surfaces.
- Fast, predictable ergonomics model modern IDE conventions: split panes, draggable divider gutters, persistent status strips, and instant keyboard-navigable feedback.
- The emotional tone is authoritative, focused, and calibrated—every pixel exists to clarify state, payload structure, and network latency.

## Colors

The palette is engineered around dark surfaces, muted text channels, and high-legibility semantic cues.

### Foundation Tiers
- **Canvas / App Root:** `#0f1117`
- **Sidebar & Inactive Panels:** `#161822`
- **Surface / Editors / Active Panels:** `#1e202e`
- **Elevated Surfaces / Flyouts / Menus:** `#25283a`
- **Borders & Dividers:** `#2b2d3d` (Subtle structural stroke)
- **Active / Focused Borders:** `#43475f`

### Typography Hierarchy
- **Text Strong (Titles, Active Elements):** `#f8fafc`
- **Text Body (Data, Code, Key Values):** `#cbd5e1`
- **Text Muted (Labels, Headers, Inactive States):** `#94a3b8`
- **Text Ghost (Placeholders, Line Numbers):** `#475569`

### Primary & Accent Actions
- **Primary Brand (Send, Run Flow, Active Indicators):** Electric Violet (`#6366f1`), Hover (`#4f46e5`)
- **Secondary Accent (Inspection, Variables, Query Tokens):** Cyan-Teal (`#06b6d4`), Light Tint Background (`rgba(6, 182, 212, 0.12)`)

### Method Badge System
- **GET:** Blue `#3b82f6` (`rgba(59, 130, 246, 0.12)` bg)
- **POST:** Emerald `#10b981` (`rgba(16, 185, 129, 0.12)` bg)
- **PUT:** Orange `#f97316` (`rgba(249, 115, 22, 0.12)` bg)
- **PATCH:** Amber `#eab308` (`rgba(234, 179, 8, 0.12)` bg)
- **DELETE:** Red `#ef4444` (`rgba(239, 68, 68, 0.12)` bg)
- **HEAD / OPTIONS:** Slate `#94a3b8` (`rgba(148, 163, 184, 0.12)` bg)

### Status Codes & Environment Markers
- **2xx Success / Dev Env:** `#10b981`
- **3xx Redirection:** `#3b82f6`
- **4xx Client Error / QA Env:** `#f97316` / `#f59e0b`
- **5xx Server Error / Prod Env:** `#ef4444`

## Typography

Typography enforces a strict separation of concerns between navigational UI chrome and technical data payload structures:

- **Geist** handles the structural envelope: workspace navigation, settings drawers, tab controls, modal overlays, and informational metadata. It provides neutral, uninhibited readability at 11px–14px sizes.
- **JetBrains Mono** governs the data plane: URL bars, raw query strings, HTTP headers, cURL commands, JSON/XML bodies, status pills, and variable tokens. Tabular figures and distinct character disambiguation (such as 0 vs O, 1 vs l) eliminate syntax misinterpretation.
- Monospace line heights are fixed to predictable increments (16px, 18px, 20px) to ensure absolute alignment with line-number gutters in payload editors.

## Layout & Spacing

The layout model is a split-pane, high-density desktop workbench designed for complex multi-panel coordination:

- **Structural Grid & Gutters:** Rather than conventional marketing columns, layout is divided using docked multi-axis panes separated by a standard `1px` border divider (`#2b2d3d`), expanding to a `4px` interactive hit area for resizable split handles (`gutter-split`).
- **Rhythm & Density:** Standard IDE controls use tight vertical padding (`space-xs` = 4px to `space-sm` = 6px) and horizontal padding (`space-md` = 10px). This maximizes visible payload lines and avoids empty, wasted vertical canvas space.
- **Window Architecture:**
  - *Top Layer:* A fixed 3px environment health indicator strip spanning the entire window top (`#10b981`, `#f59e0b`, or `#ef4444`).
  - *Sub-Header:* Global workbench controls, environment dropdown, quick search, and active request tab strip.
  - *Split Canvas:* Left persistent tree (Collections/History, width: 240px–360px resizable), Center Request Editor (Config, Headers, Body, Scripts), and Right or Bottom Response Inspector (Viewer, Headers, Timeline, Console).
- **Responsive Handling:** When the desktop viewport drops below 1100px width, the split response pane transforms from a side-by-side view to a stacked vertical tabbed layout automatically.

## Elevation & Depth

This design system eschews soft, diffuse skeuomorphic shadows in favor of **tonal layering** and **low-contrast outlines**:

- **Layer 0 (Canvas Base - `#0f1117`):** The primary root application background behind all frames.
- **Layer 1 (Side Panels & Inactive Blocks - `#161822`):** Delimited by a 1px border (`#2b2d3d`), grouping secondary tools.
- **Layer 2 (Workspaces & Active Editors - `#1e202e`):** The active focal zone for editing and inspecting calls.
- **Layer 3 (Popovers, Context Menus, Modals - `#25283a`):** Floating UI is framed by a 1px outline of `#43475f` paired with a directional, razor-thin dark drop shadow: `0 8px 24px -4px rgba(0, 0, 0, 0.65)`.
- **Active State Highlights:** Selection states, active tabs, and focused inputs receive a solid 1px inner or outer highlight in `#6366f1` or `#06b6d4`, accompanied by an ambient 2px outer glow (`rgba(99, 102, 241, 0.25)`).

## Shapes

The design system uses a **Soft (Level 1)** shape geometry:
- Standard interactive elements—buttons, inputs, key-value rows, dropdowns, and tabs—utilize `4px` (`0.25rem`) corner rounding. This maintains an engineered, compact IDE aesthetic without sharp, abrasive corners.
- Context cards, modals, and isolated surface panels use `rounded-lg` (`8px` / `0.5rem`).
- Monospace tokens, method badges, and status chips apply a tighter `3px` radius to maintain visual parity with dense terminal typography.
- Variable substitution chips (`{{variable}}`) uniquely feature fully rounded pill shapes (`9999px`) to immediately signal an atomic, non-editable token entity within plain-text inputs.

## Components

### Buttons
- **Primary ('Send', 'Run Flow'):** Solid background in `#6366f1`, text in `#f8fafc`, font weight 600. On hover, background shifts to `#4f46e5`. Active click induces a 1px downward translation. Includes an attached split dropdown button for "Send & Download" variants.
- **Secondary / Action:** Background `#1e202e`, border 1px `#2b2d3d`, text `#cbd5e1`. On hover: border `#43475f`, text `#f8fafc`.
- **Ghost / Icon:** Transparent background, text `#94a3b8`, 4px padding. On hover: background `#25283a`, text `#f8fafc`.

### Method Badges
- Displayed in JetBrains Mono 10px bold uppercase. Padding: 2px 6px, radius: 3px.
- Styled with semantic background tinting (`rgba(..., 0.12)`) and saturated foreground text:
  - `GET`: `#3b82f6`
  - `POST`: `#10b981`
  - `PUT`: `#f97316`
  - `PATCH`: `#eab308`
  - `DELETE`: `#ef4444`

### Variable Chips (`{{variable}}`)
- Inline replacement tags rendered inside address bars and body editors.
- Radius: `9999px` (pill), font: JetBrains Mono 11px.
- Styling: Text in `#06b6d4`, background in `rgba(6, 182, 212, 0.12)`, 1px border in `rgba(6, 182, 212, 0.28)`.
- Hovering reveals a mini inspection tooltip showing the resolved runtime value and active environment scope.
- Unresolved variables fall back to amber warning colors: `#f59e0b` text, `rgba(245, 158, 11, 0.15)` background.

### Input Fields & URL Bar
- Combined URL bar: Method selector dropdown on the left, full-width monospace input in the center, and primary Send action docked on the right.
- Input fields use background `#161822`, border 1px `#2b2d3d`, font: JetBrains Mono 12px, text `#f8fafc`. Focus state swaps border to `#6366f1` with an interior glow.

### Key-Value Parameter Tables
- Compact tabular grid for Query Params, Headers, and Multipart Forms.
- Zebra row hovering with `#1e202e`. Columns delineated with subtle vertical border strokes.
- Inline fast-toggle checkboxes: 12px square, background `#161822`, border 1px `#2b2d3d`, checked state filled with `#6366f1` containing a crisp white tick mark.

### Tab Bars
- Request/Response tabs use horizontal border-bottom navigation.
- Inactive tabs: text `#94a3b8`, padding 8px 12px, border-bottom 2px transparent.
- Active tab: text `#f8fafc`, font-weight 500, border-bottom 2px `#6366f1`.
- Tab close and unsaved dirty indicators (tiny circle in `#06b6d4`) dock seamlessly to the right side of tab labels.

### Status Code Badges
- JetBrains Mono 12px bold. Paired with round-trip latency (e.g., `200 OK • 42ms • 1.2KB`).
- Background: `rgba(..., 0.15)`, text matching the status category (2xx `#10b981`, 3xx `#3b82f6`, 4xx `#f97316`, 5xx `#ef4444`).