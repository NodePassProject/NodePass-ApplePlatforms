# NodePass for Apple Platforms — Design Language

NodePass is a control plane. Its screens are read in a hurry, often while something is wrong, so the
design has one job: make state legible at a glance, then get out of the way. The language below is
what gives the app a recognizable face while it keeps every system behavior people expect from an
iOS, iPadOS or macOS app.

## Principles

1. **System chrome stays system.** Navigation bars, toolbars, sidebars, search, sheets, alerts,
   context menus, swipe actions and the macOS table and inspector are stock SwiftUI. They are where
   the platform conventions live, and they already adopt Liquid Glass. The app's own voice lives in
   the content area.
2. **Status is a signal, not a label.** Every row, card and header carries its state as color on
   its leading edge (the *signal bar*) or as a wash behind its header. Shape backs up color: the
   glyphs that stand for running, stopped, error and the master health states differ in silhouette,
   the same glyphs the widgets and the watch use.
3. **Three typographic voices.** Prose uses the system font. Numbers that change — counts, rates,
   latency, gauges — use the rounded design with monospaced digits and animate through
   `numericText`. Machine text — URLs, identifiers, keys, log lines — is monospaced. Instance URLs
   are additionally colored by part (scheme in the role's tint, keys dimmed) so they read as
   structure, not as a string.
4. **Calm lists, alive details.** Lists stay still: static dots, no pulsing. The screen of one
   thing is allowed to breathe: a running instance's status ripples, a live connection breathes,
   sparklines and numbers animate as values arrive. Every motion respects Reduce Motion.
5. **Panels in a masonry, not sections in a form.** Detail screens are compositions of panels
   (rounded cards with a quiet header) laid out by a custom masonry layout: one column on iPhone,
   two or three on iPad and in wide windows. `Form` remains for actual forms — settings, editors —
   where text fields, pickers and keyboard handling are what matter.
6. **Use the width you are given.** The instance list becomes a grid of cards on regular-width
   layouts (iPad, iPhone landscape with room); masonry panels fill wide detail columns; metric
   tiles flow into as many columns as fit.

## Vocabulary

| Piece | Where | What it is |
|---|---|---|
| `Panel` | `NodePass/DesignSystem/Panel.swift` | Rounded card with an optional header (title, symbol, trailing accessory) and an optional tint wash. Panels sit on the grouped background on iOS and on the window or inspector background on macOS. |
| `PanelRows` | same | Vertical stack of rows separated by hairlines, the panel-side counterpart of a form section. Rows are usually `KeyValueRow`s. |
| `MasonryLayout` | `NodePass/DesignSystem/MasonryLayout.swift` | Custom `Layout` that places panels into the shortest of *n* columns, *n* derived from the available width. `.spansAllColumns()` lets a panel take the full width. |
| `HeroHeader` | `NodePass/DesignSystem/HeroHeader.swift` | The bleeding header of a detail screen: a mesh-gradient wash in the subject's tint that fades into the canvas, with the subject's identity and primary actions on top. |
| `SignalBar` | `AppShared/DesignSystem/Badges.swift` | The 3-point capsule on the leading edge of rows and cards, in the status tint. |
| `StatusDot`, `StatusGlyph` | same | Dot (lists) and shaped glyph (headers) for an instance status. The dot can ripple when running; only one screen uses that at a time. |
| `MasterSession.Health`, `HealthGlyph` | `AppShared/Sessions/MasterSession+Health.swift` | A master's state in one word, one color and one glyph, shared by the iPhone, the Mac and the watch. |
| `MetricTile`, `MetricGrid` | `AppShared/DesignSystem/Metrics.swift` | A labeled number in rounded type; the grid flows tiles into as many columns as fit. |
| `InstanceURLText` | `NodePass/DesignSystem/InstanceURLText.swift` | An instance URL as colored monospaced text: scheme in the role tint, credential masked on request, keys dimmed. |
| `RoleSelector` | `NodePass/DesignSystem/RoleSelector.swift` | The instance type as a row of tiles with icon and name, selected one in the role's tint, summary below. |
| `InstanceCard` | `NodePass/Features/Instances/InstanceCard.swift` | One instance as a card for the grid layout: signal bar, name, type, endpoint, sparkline, counts. |
| `Pill`, `TagChip`, `InlineMessage`, `Sparkline`, `RingGaugeStyle` | existing | Unchanged roles; pills animate their selected state. |

## Tokens

Spacing is 4 / 8 / 12 / 16 / 20. Panel corner radius is 22 on iOS and 14 on macOS, tiles 14 / 10,
both continuous. Backgrounds are system colors so Dark Mode, Increase Contrast and vibrancy come
for free: canvas = grouped background (iOS only; the Mac leaves the window or inspector material
alone), panel = secondary grouped background / quaternary fill, tile = tertiary grouped background /
quinary fill. Status and role tints are defined once in `Shared/UI/StatusColors.swift` and used by
the app, the widgets and the watch.

Motion: `.snappy` for selection and filter changes, `.smooth` for values. Repeating animations are
limited to the hero header and the connection indicator and stop under Reduce Motion.

## Where each screen stands

* **Masters sidebar** — stock sidebar list. Rows carry a health-tinted glyph tile, the live summary
  and the running/total count with errors called out.
* **Instance list (iPhone)** — a stock list with a signal bar per row. Filter chips and the
  connection summary stay above the content. Selection, swipe actions, context menus and batch
  editing are unchanged.
* **Instance grid (iPad)** — on regular widths the instances take the whole width beside the
  sidebar as a grid of cards (or a list, by setting), and the selection opens in an inspector,
  exactly as the Mac's table and inspector. Cards share one structure so the grid stays even;
  selection mode adds a check mark in front of the name.
* **Instance detail** — hero header (status, type, name, identifier, latency, Start / Stop /
  Restart / Reset) followed by panels: Traffic, Configuration (with the auto-restart policy and the
  resolved parameters), URL, Metadata, Logs. The same view is the macOS inspector.
* **Master overview** — hero header in the health tint, then Host (ring gauges), Instances, Master
  identity, Administration and Notes panels.
* **Editors, settings, tools** — forms. The instance editor gains the role selector and the colored
  URL preview; the URL inspector uses the same colored URL; the TCP ping tool shows latency as a
  graded badge.
* **Apple Watch** — unchanged on purpose. It already follows the language (health gradients, shaped
  glyphs); the shared health model now lives in `AppShared` so both apps agree.
