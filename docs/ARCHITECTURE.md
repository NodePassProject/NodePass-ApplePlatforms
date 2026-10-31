# NodePass for Apple Platforms — Architecture

NodePass 2.0 is a control plane for NodePass **masters** and Nowhere **OpenCtrl**
controllers. Both expose the same REST + SSE contract; the app treats them as two
*flavors* of one API.

## Terminology

| Term | Meaning |
|---|---|
| Master | A reachable management API (`…/api/v1` for NodePass, `…/api/v2` for OpenCtrl). Persisted locally as the SwiftData entity `Server` (kept for CloudKit continuity). |
| Instance | A managed process. NodePass roles: `server`, `client`. Nowhere roles: `portal`, `vector`, `egress`. |
| Flavor | `nodePass` or `openCtrl`. Chooses the URL grammar and parameter catalog. |

## Layers

```
Shared/                 Pure core, compiled into App, Widget and Tests. No UI, no 3rd-party imports.
  Core/                 Constants, UserDefaults suite, formatters
  Persistence/          SwiftData container + `Server` model (+ snapshot DTO for extensions)
  Models/               Codable wire types: Instance, MasterInfo, InstanceEvent, TCPingResult…
  API/                  MasterClient (actor: REST calls + the SSE event stream), MasterEndpoint, APIError, SSE parser, TLS trust policy
  Grammar/              InstanceURL parser/serializer, Endpoint (host:port, IPv6), ParameterCatalog + validation

NodePass/               iOS / iPadOS / native macOS app
  App/                  Scenes, per-window NavigationModel, root NavigationSplitView, deep links, shared environment
  Platform/             Thin wrappers over platform-only APIs (clipboard, haptics, text input, sheet sizing)
  Sessions/             MasterSession: live state per master (SSE, polling fallback, log ring buffer, rate samples)
  Features/             Masters, Instances (list, detail, editor, console), Tools (TCPing, URL inspector, API console), Settings
    Workspace/          macOS: instance table, filter bar, host status bar, inspector, InstanceWorkspace
    Commands/           macOS: menu bar commands and the focused values they read
    MenuBar/            macOS: status item with fleet health
  DesignSystem/         Small reusable views (badges, metric tiles, sparkline, key-value rows, mono text)
  Components/           QR rendering, QR scanning (iOS camera) and reading (images, both platforms), text documents

Widget/                 WidgetKit extension
  Data/                 MasterStore (read-only SwiftData access), MasterReport (one-pass fetch), entities and intents
  Components/           Status glyphs, host rings, instance rows, size-fitting row lists
  MasterOverview/       One master, small to extra large
  Fleet/                Several masters ("Masters" widget)
NodePassTests/          Swift Testing: grammar round-trips, catalog validation, SSE parsing, formatters
Scripts/                mock_master.py — a local stand-in master for development
```

## Live data flow

1. `SessionStore` creates one `MasterSession` per enabled master. Every scene root that shows live data
   applies `keepsSessionsInSync()`, so the store follows SwiftData edits whichever windows are open.
2. `MasterSession` opens `GET /events` through `MasterClient.events()`. The stream is split into
   lines by hand (`AsyncBytes.lines` drops the empty lines SSE uses as event terminators).
   `initial` / `create` / `update` events upsert the instance table, `delete` removes, `log` feeds a
   per-instance ring buffer and `shutdown` marks the master offline until it answers again.
3. Every (re)connect also issues one `GET /instances` to drop instances that vanished while the
   stream was down; while the stream is down the session keeps polling at the configured interval.
4. `GET /info` is polled on its own cadence for system metrics; deltas of `netrx`/`nettx`
   produce throughput.
5. Mutations go through `MasterClient` and are confirmed by the next SSE `update`.

Sessions stream while any window is on screen (the app-level, aggregated `scenePhase`). On macOS they keep
streaming while the menu bar item is shown, so it reflects health after the last window closes. Settings that
affect sessions reach them as one `SessionConfiguration` value.

## Windows and navigation

Each window owns a `NavigationModel`: the sidebar selection, the selected instances and the master-level
presentations (add, edit, share, delete, key rotation). The main `WindowGroup` is keyed by `SidebarItem`, so a
window restores what it showed and "Open in New Window" can put each master in its own window. Selection is a
set of instance IDs; the list-based layout reads it through `selectedInstanceID`.

## Platforms

Shared views use `Form`, `LabeledContent` and the wrappers in `Platform/`, so the same code reads naturally on
both platforms. Files that only make sense on one platform are wrapped in `#if os(iOS)` or `#if os(macOS)` as a
whole; small differences stay inline.

**iPhone and iPad** use a three-column split view: masters & tools → `InstanceListView` → instance detail or
master overview.

**macOS** uses two columns and an inspector:

| Piece | Role |
|---|---|
| `MasterWorkspaceView` | Filter chips on top, the instance `Table`, live host metrics at the bottom, a customizable toolbar and the inspector. |
| `InstanceTable` | Sortable columns (mapped onto the same persisted sort settings as iOS), column customization in scene storage, multiple selection, sections when grouped, rows that drag out as URLs; dropping or pasting a URL opens a prefilled editor. |
| `InstanceInspector` | Master overview with no selection, instance detail for one instance, a batch summary for several. |
| `InstanceWorkspace` | Every instance operation of one master. The table, its context menu, the toolbar, the inspector and the Instance menu act through it, and `MasterWorkspaceView` presents what it asks for. |
| `NodePassCommands` | Menu bar commands. They read the key window's `NavigationModel` and `InstanceWorkspace` as focused values, so each window's menus follow its own selection. |
| Scenes | Main windows, one console window per instance (`ConsoleTarget`), a `Settings` window and a `MenuBarExtra`. |

## Widgets

Widgets fetch for themselves: `MasterReport.load` asks a master for `/info` and `/instances` in parallel with a
short timeout, and the Masters widget loads its masters concurrently. Timelines refresh every 15 minutes, and the
app reloads them whenever it stops being active, so changes made in the app show up as soon as the user leaves.

Layouts are written once for every platform. `FittingRows` and `ViewThatFits` pick how many rows and how much
detail fit, because the same family is far larger on a Mac desktop than on an iPad. Status is carried by symbol
shape as well as color (`StatusGlyph`, `MasterHealthGlyph`), and colors go through
`WidgetRenderingMode.tint`, so widgets stay legible in the accented and vibrant rendering modes.

Rows link back with `DeepLink.master(_:instance:)`; the app selects the master and, when given, the instance.

## Instance editor

The editor is a typed key–value table over the URL grammar:

* `InstanceURL` is the single source of truth: role, credential, tunnel endpoint,
  targets / carriers, and an **ordered** list of query parameters.
* `ParameterCatalog` describes every known key per flavor and role: kind (enum, integer,
  duration, boolean, bit set, host, path, text), default, applicability, and validation.
  Unknown keys remain editable as free text.
* The structured table and the raw URL text stay in two-way sync; switching modes never loses
  data.

## Concurrency

Swift 6 language mode with default `MainActor` isolation. Core types in `Shared/` are
declared `nonisolated`; `MasterClient` is an `actor`; sessions and view models are
`@Observable @MainActor`.

## Compatibility notes

* The persisted entity stays named `Server` and only gains optional attributes, so existing
  iCloud data survives the upgrade.
* `Service` / `Implementation` entities from 1.x are no longer part of the schema.
* The special instance `********` (API key holder) is hidden from lists and used only for
  key regeneration and master-ID lookup.
* The App Group is used only when the process is entitled to it. macOS hands out group container
  paths even to unentitled processes, so `NPCore.isAppGroupAvailable` checks the entitlement there.
  Unsigned builds then use `Application Support/NodePass/NodePass.store` and standard defaults
  instead of shared data.
