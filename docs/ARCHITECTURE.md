# NodePass for Apple Platforms — Architecture

NodePass 2.0 is a control plane for NodePass **masters** and Nowhere **OpenCtrl**
controllers. Both expose the same REST + SSE contract; the app treats them as two
*flavors* of one API. It ships as one app for iPhone, iPad and Mac, an Apple Watch app,
and a widget extension built for all three platforms.

## Terminology

| Term | Meaning |
|---|---|
| Master | A reachable management API (`…/api/v1` for NodePass, `…/api/v2` for OpenCtrl). Persisted locally as the SwiftData entity `Server` (kept for CloudKit continuity). |
| Instance | A managed process. NodePass roles: `server`, `client`. Nowhere roles: `portal`, `vector`, `egress`. |
| Flavor | `nodePass` or `openCtrl`. Chooses the URL grammar and parameter catalog. |

## Layers

```
Shared/                 Pure core, compiled into every target. No UI beyond gauge styles, no 3rd-party imports.
  Core/                 Constants, UserDefaults suite, formatters
  Persistence/          SwiftData container + `Server` model (+ snapshot DTO for extensions), MasterStore (reads for
                        intents; on watchOS it reads the mirror), MasterMirror (the master list as sent to the watch)
  Models/               Codable wire types: Instance, MasterInfo, InstanceEvent, TCPingResult…
  API/                  MasterClient (actor: REST calls + the SSE event stream), MasterEndpoint, APIError, SSE parser, TLS trust policy
  Grammar/              InstanceURL parser/serializer, Endpoint (host:port, IPv6), ParameterCatalog + validation
  AppIntents/           MasterEntity + MasterQuery (every target's one definition of a master)
  UI/                   Ring gauge styles, status colors

AppShared/              Compiled into the iPhone/Mac app and the watch app, not the widget
  Sessions/             MasterSession: live state per master (SSE, polling fallback, log ring buffer, rate samples), SessionStore
  AppIntents/           IntentModel, intents, entities, snippets and App Shortcuts (see "App Intents")
  DesignSystem/         Badges, metric tiles, sparklines, inline messages, presentation bindings

NodePass/               iOS / iPadOS / native macOS app
  App/                  Scenes, per-window NavigationModel, root NavigationSplitView, deep links, shared environment
  Platform/             Thin wrappers over platform-only APIs (clipboard, haptics, text input, sheet sizing), WatchBridge (iOS)
  Features/             Masters, Instances (list, detail, editor, console), Tools (TCPing, URL inspector, API console), Settings
    Workspace/          macOS: instance table, filter bar, host status bar, inspector, InstanceWorkspace
    Commands/           macOS: menu bar commands and the focused values they read
    MenuBar/            macOS: status item with fleet health
  AppIntents/           What only this app has: Spotlight indexing, the tool intent and enum, the macOS IntentNavigator
  DesignSystem/         Controls that need the clipboard or text input (mono text, key-value rows, code fields)
  Components/           QR rendering, QR scanning (iOS camera) and reading (images, both platforms), text documents

NodePass Watch App/     watchOS app
  App/                  Scene and dependencies, NavigationStack root, WatchRoute + IntentNavigator
  Connectivity/         WatchBridge: receives the masters from the iPhone
  Features/             Masters list, master detail, instance detail, session health
  Platform/             Haptics

NodePass Widget/        WidgetKit extension, built for iOS, macOS and watchOS
  Data/                 MasterReport (one-pass fetch), the configuration intents
  Components/           Status glyphs, host rings, meters, instance rows, size-fitting row lists, per-platform families
  MasterOverview/       One master, from accessory sizes to extra large
  Fleet/                Several masters ("Masters" widget)
NodePassTests/          Swift Testing: grammar round-trips, catalog validation, SSE parsing, formatters, intents
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

**Apple Watch** is its own target with its own views (see "Apple Watch"); it shares the sessions, intents and the
smaller design-system pieces through `AppShared/`.

**macOS** uses two columns and an inspector:

| Piece | Role |
|---|---|
| `MasterWorkspaceView` | Filter chips on top, the instance `Table`, live host metrics at the bottom, a customizable toolbar and the inspector. |
| `InstanceTable` | Sortable columns (mapped onto the same persisted sort settings as iOS), column customization in scene storage, multiple selection, sections when grouped, rows that drag out as URLs; dropping or pasting a URL opens a prefilled editor. |
| `InstanceInspector` | Master overview with no selection, instance detail for one instance, a batch summary for several. |
| `InstanceWorkspace` | Every instance operation of one master. The table, its context menu, the toolbar, the inspector and the Instance menu act through it, and `MasterWorkspaceView` presents what it asks for. |
| `NodePassCommands` | Menu bar commands. They read the key window's `NavigationModel` and `InstanceWorkspace` as focused values, so each window's menus follow its own selection. |
| Scenes | Main windows, one console window per instance (`ConsoleTarget`), a `Settings` window and a `MenuBarExtra`. |

## Apple Watch

The watch app mirrors the iPhone rather than syncing on its own. The phone is the source of truth for the
masters; the watch holds a copy and talks to the masters directly.

| Piece | Role |
|---|---|
| `MasterMirrorPayload` | The master list (snapshots, keys included) as one JSON `Data` in a Watch Connectivity dictionary, with the time it was sent, so an older reply never overwrites a newer context. |
| `WatchBridge` (iOS) | Activates `WCSession` at launch, sends the list as the *application context* whenever the saved masters change (`keepsWatchInSync()` on the root view) and whenever the session or watch state changes, and answers the watch's request message. The system delivers the context even while the watch app is closed, and a request wakes the iPhone app in the background. |
| `WatchBridge` (watchOS) | Takes the stored context on activation, every new context, and replies; asks on the first launch, when the copy is a day old, or on *Sync from iPhone*. |
| `MasterMirror` | The watch's copy, persisted in the App Group's `UserDefaults` so the widget extension reads the same list. Nothing is ever created on the watch: identifiers stay the ones CloudKit syncs between the other devices, so shortcuts resolve everywhere. |
| `MasterStore` | On watchOS, reads the mirror instead of SwiftData, with the same interface, so `MasterQuery`, the intents and the widgets are the same code. |

Why not CloudKit on the watch: the watch does not get an iCloud account of its own in the simulator and sync can
lag by minutes on a new watch, while the phone is right there. Why not SwiftData for the mirror: inserting the
phone's records into a CloudKit-mirrored store would upload them again as new records and duplicate every master
on every device.

Sessions are the same `MasterSession`s as on the phone, synced from snapshots (`SessionStore.sync(with:)` has an
overload for them) and running while the app is on screen, Always On included; the watch configuration polls
less often and keeps fewer log lines. Navigation is a `NavigationStack` over `WatchRoute`: widget links
(`onOpenURL`) and the Open intents (through the watch's `IntentNavigator`, since watchOS has no
`onAppIntentExecution`) set the path.

Design: one list, one master, one instance. Each master's and instance's screen carries a navigation container
gradient in its health or role color, status reads from symbol shape as well as color, Start/Stop/Restart sit in
the bottom bar with confirmation for the disruptive two, and `isLuminanceReduced` hides the live rates.

## Widgets

The one extension target builds for iOS, macOS and watchOS; the apps that embed it pick the platform, and its
bundle identifier changes under the watch app (`PRODUCT_BUNDLE_IDENTIFIER[sdk=watchos*]`). The families follow the
platform (`WidgetFamily.nodePassSupported`): the system sizes where they exist, the accessory sizes on iPhone and
Apple Watch, `accessoryCorner` on the watch only. Accessory layouts never use `Link` or `Button(intent:)`, since
neither works there. Entries carry a `TimelineEntryRelevance` (unreachable masters and errors score higher) for the
Smart Stack, and the providers offer `recommendations()` so watch faces list one complication per master.

Widgets fetch for themselves: `MasterReport.load` asks a master for `/info` and `/instances` in parallel with a
short timeout, and the Masters widget loads its masters concurrently. Timelines refresh every 15 minutes, and the
app reloads them whenever it stops being active, so changes made in the app show up as soon as the user leaves.

Layouts are written once for every platform. `FittingRows` and `ViewThatFits` pick how many rows and how much
detail fit, because the same family is far larger on a Mac desktop than on an iPad. Status is carried by symbol
shape as well as color (`StatusGlyph`, `MasterHealthGlyph`), and colors go through
`WidgetRenderingMode.tint`, so widgets stay legible in the accented and vibrant rendering modes.

Rows link back with `DeepLink.master(_:instance:)`; the app selects the master and, when given, the instance.

## App Intents

The App Intents layer mirrors Apple's "Adopting App Intents to support system experiences" sample, with the
synchronized folders standing in for its shared package: `Shared/AppIntents` holds what the widget needs too,
`AppShared/AppIntents` what both apps share (the intents, entities, snippets and App Shortcuts; the watch app
registers the same intents and shortcuts, minus the tool), and `NodePass/AppIntents` what only the iPhone/Mac app
has (Spotlight, the tool, the macOS navigator). The intents are deliberately not compiled into the widget, which
would register every action a second time.

| Piece | Role |
|---|---|
| `MasterEntity`, `MasterQuery` | A saved master. The identifier is the `Server` id, which CloudKit syncs, so shortcuts resolve on every device. Both the app and the widget register a `MasterStore` with `AppDependencyManager` at launch; the widget's master picker and the app's intents run the same query. |
| `InstanceEntity`, `InstanceQuery` | A managed instance. The identifier is `<master id>/<instance id>`; the system stores only that and asks the query for the rest, so status and counters are always current. Properties are `@ComputedProperty` over the wire `Instance`. |
| `IntentModel` | What intents act on. Masters come from `MasterStore`; instances come from the live `MasterSession` when the app is connected (no network, and the UI reflects changes at once) and straight from `MasterClient` otherwise, since Siri and Shortcuts run intents in the background. Recent answers are kept for a few seconds so a snippet rendered after an intent does not ask the master twice. |
| Intents | `Open{Master,Instance,Tool}` (foreground), `Get{Master,Instance}Status`, `Start/Stop/Restart/ResetInstanceTraffic` (one verb each, so Siri phrases can name the instance), `SetAutoRestart`, `CreateInstance` (parses and validates the URL like the editor), `DeleteInstance` (asks for confirmation), `TCPing`. Results are entities or transient entities (`MasterStatus`, `TCPingResultEntity`), so later actions in a shortcut can read their properties. |
| Snippets | `InstanceSnippetIntent` and `MasterStatusSnippetIntent` render the cards Siri shows. Their buttons are the control intents; the system performs the snippet again afterwards. |
| `NodePassShortcuts` | The App Shortcuts and their phrases. `SystemEntitySync` calls `updateAppShortcutParameters()` whenever masters or instances change, so Siri learns their names. |
| Spotlight | `MasterEntity` and `InstanceEntity` are `IndexedEntity`; `SystemEntitySync` donates masters and the instances of connected masters whenever the set or the names change, and removes what disappeared. Choosing a result runs the matching `Open…Intent`. |
| On-screen context | Instance rows, the macOS table selection, the instance detail and the master views carry `appEntityIdentifier`, and the detail advertises an `NSUserActivity` with the entity, so Siri and Apple Intelligence know what is on screen. Entities are `Transferable` as plain text without credentials. |

Foreground navigation differs per platform, as in the sample: on iOS the targeted scene handles the intent through
`onAppIntentExecution` in `RootView`; macOS has no such hook, so `IntentNavigator` opens the matching `np://` link,
which an open window handles (`handlesExternalEvents`) and which otherwise creates one. watchOS has neither, so its
`IntentNavigator` is an observable the root view watches. Spotlight does not exist on watchOS; the `IndexedEntity`
conformances and `SystemEntitySync` stay in the iPhone/Mac app, and the watch calls `updateAppShortcutParameters()`
whenever its mirrored masters change.

Concurrency: with the module's default `MainActor` isolation, entities are `nonisolated` value types with computed
properties, while intents and queries stay main-actor types whose conformances are declared `nonisolated` and whose
`perform()` / query methods are `@MainActor`. Static metadata and `init()` are `nonisolated` so the system can read
and construct them off the main actor.

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
