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

NodePass/               iOS / iPadOS / Mac Catalyst app
  App/                  Entry point, root NavigationSplitView, deep links
  Sessions/             MasterSession: live state per master (SSE, polling fallback, log ring buffer, rate samples)
  Features/             Masters, Instances (list, detail, editor), Tools (TCPing, URL inspector, API console), Settings
  DesignSystem/         Small reusable views (badges, metric tiles, sparkline, key-value rows, mono text)

Widget/                 WidgetKit extension (master overview)
NodePassTests/          Swift Testing: grammar round-trips, catalog validation, SSE parsing, formatters
Scripts/                mock_master.py — a local stand-in master for development
```

## Live data flow

1. `SessionStore` creates one `MasterSession` per enabled master.
2. `MasterSession` opens `GET /events` through `MasterClient.events()`. The stream is split into
   lines by hand (`AsyncBytes.lines` drops the empty lines SSE uses as event terminators).
   `initial` / `create` / `update` events upsert the instance table, `delete` removes, `log` feeds a
   per-instance ring buffer and `shutdown` marks the master offline until it answers again.
3. Every (re)connect also issues one `GET /instances` to drop instances that vanished while the
   stream was down; while the stream is down the session keeps polling at the configured interval.
4. `GET /info` is polled on its own cadence for system metrics; deltas of `netrx`/`nettx`
   produce throughput.
5. Mutations go through `MasterClient` and are confirmed by the next SSE `update`.

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
