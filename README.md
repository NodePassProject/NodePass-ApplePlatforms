# NodePass for Apple Platforms

A professional control plane for [NodePass](https://github.com/NodePassProject/nodepass) masters and
[Nowhere](https://github.com/NodePassProject/Nowhere) OpenCtrl controllers on iPhone, iPad, Mac and Apple Watch.

Both backends speak the same REST + SSE contract; the app treats them as two *flavors* of one API
(`…/api/v1` with `server`/`client` instances, `…/api/v2` with `portal`/`vector`/`egress` instances).

## What it does

- **Masters** — add by URL + key, QR code or `np://master?…` deep link. Test the connection before saving,
  pick the API flavor explicitly or let the app detect it, decide per master whether self-signed certificates are trusted.
- **Live instance table** — fed by Server-Sent Events with polling fallback. Search (including `tag:value` and `#tag`),
  filter by status / type / auto-restart, sort by name, status, traffic, connections or latency, group by status, type or any tag key.
- **Batch operations** — select many instances and start, stop, restart, reset counters, delete, flip the auto-restart
  policy or stamp a tag on all of them. Every batch ends with a per-instance report.
- **Instance detail** — controls, live throughput sparkline, TCP/UDP/pool metrics, the stored URL next to the config the
  master actually runs (with the defaults it injected called out), peer/tag metadata editor, and a log console with level
  filters, follow mode and export.
- **Typed key–value editor** — the instance URL is edited as a table of parameters. Every known key gets a control matched
  to its type (enum, integer, duration, boolean, bit set, host, path…), its default and its applicability to the chosen role;
  unknown keys stay editable as text. Switch to raw URL mode at any time without losing data; validation runs live.
- **Tools** — TCP ping from any master (or all of them), a URL inspector that explains every parameter and can turn a URL
  into a new instance, and a raw API console with request templates.
- **Widgets** — *Master Overview* shows the host gauges and the instances of one master (errors first); *Masters* shows
  the health of several masters at once. Every size from small to extra large, on the Home Screen and the Mac desktop;
  rows open the master or instance in the app. Layouts fit what the widget has room for, and status reads from symbol
  shape as well as color, so it stays clear on a tinted Home Screen or an inactive Mac desktop. Both widgets also come
  in the accessory sizes: circular, rectangular and inline on the iPhone Lock Screen, those plus corner on Apple Watch.
- **Shortcuts, Siri and Spotlight** — masters and instances are App Intents entities, so Shortcuts can find them
  (*Find Instances* filters by status, type, master, endpoint or tag) and pass them between actions. Actions: Get Master
  Status, Get Instance Status, Start / Stop / Restart Instance, Reset Instance Traffic, Set Auto-restart, Create Instance,
  Delete Instance (confirmed), TCP Ping, Open Master / Instance / Tool. App Shortcuts work out of the box: "Restart
  *edge-tunnel* in NodePass", "Is *edge-tunnel* running in NodePass", "Check *Home Lab* in NodePass", "Open TCP Ping in
  NodePass". Status answers come with an interactive card (start, stop, restart, open), masters and instances appear in
  Spotlight, and the instance on screen is known to Siri and Apple Intelligence. Everything runs in the background
  without opening the app; API keys never leave the app.

### On Apple Watch

NodePass on Apple Watch is for the glance and the quick fix, not for editing.

- **Your masters, without setup** — the iPhone app sends its saved masters (keys included) to the watch over Watch
  Connectivity whenever they change, and the watch asks for them on first launch. Nothing is typed on the watch, and the
  identifiers stay the ones your other devices know, so a shortcut built anywhere works on the watch too.
- **Live** — while the app is on screen every enabled master streams events, with polling as the fallback. The list
  shows each master's health and counts; a master shows its connection, CPU and memory rings, throughput and uptime,
  then its instances with errors first; an instance shows status, endpoint, a throughput sparkline, connections,
  traffic and latency.
- **Act** — Start, Stop and Restart in the bottom bar (the disruptive ones ask first), the auto-restart policy as a
  toggle, haptic feedback when the master has acted. Always On dims to the static numbers.
- **Complications and Smart Stack** — *Master Overview* and *Masters* as circular, rectangular, inline and corner
  widgets; watch faces offer one per master, and masters in trouble come forward in the Smart Stack.
- **Siri and Shortcuts** — the same App Shortcuts and actions as on iPhone (except the tools), run on the watch itself.

### On the Mac

NodePass is a native macOS app, not a port of the iPad layout.

- **Instance table** — sortable, resizable columns you can show or hide (endpoint, connections, latency, live
  throughput, traffic, tags, auto-restart…), multiple selection, grouping into sections, an inspector for the
  selection and Activity Monitor-style host metrics along the bottom.
- **Drag and drop** — drag rows out as instance URLs; drop or paste a URL onto a master to create an instance from it.
- **Menus and shortcuts** — every operation is in the Instance and Master menus: ⌘N new instance, ⌘↩ start,
  ⌘. stop, ⇧⌘R restart, ⌘E edit, ⌘D duplicate, ⌘L console, ⇧⌘C copy URL, ⌘⌫ delete, ⌘R refresh.
- **Windows** — open masters in their own windows and follow instance logs in separate console windows with
  multi-line selection and Save Log….
- **Menu bar** — a status item shows the health of every master and keeps live data flowing after the last window
  closes. Optional: open at login.
- **QR codes** — import a master from a QR code image or screenshot (choose or drop the file).
- **Desktop widgets** — large and extra-large layouts with full instance lists and a fleet table of every master.

## Project layout

```
Shared/               Core compiled into every target: models, MasterClient (REST + SSE), URL grammar, parameter catalog,
                      the Master entity shared with the widget, the master list as it travels to the watch
AppShared/            Compiled into both apps but not the widget: sessions, App Intents (intents, entities, snippets,
                      App Shortcuts), the design system
NodePass/             The iPhone, iPad and Mac app: features (Masters, Instances, Tools, Settings), Spotlight, menus
NodePass Watch App/   The Apple Watch app: Watch Connectivity, the three screens, the intent navigator
NodePass Widget/      WidgetKit extension for iOS, macOS and watchOS: Master Overview and Masters widgets
NodePassTests/        Swift Testing suite for the grammar, catalog, wire formats, filters and intents
Scripts/              mock_master.py — a local stand-in master for development
docs/                 Architecture notes
```

All folders are Xcode *synchronized folders*: adding a file on disk adds it to the right target.

## Development

Requirements: Xcode 27 with the iOS 27, macOS 27 and watchOS 27 SDKs. Open `NodePass.xcodeproj` and run the
`NodePass` scheme on an iPhone, iPad or "My Mac" destination, or the `NodePass Watch App` scheme on an Apple Watch
simulator. The watch gets its masters from the iPhone app, so run `NodePass` on the simulator paired with that watch and
add a master there first.

To work without a real master:

```bash
python3 Scripts/mock_master.py --port 9090 --key demo
```

Then add a master with URL `http://127.0.0.1:9090/api/v1` (NodePass flavor) or `http://127.0.0.1:9090/api/v2`
(Nowhere flavor) and key `demo`. The mock streams fake traffic and logs, honours every mutation and rotates the API key.

Run the tests with `xcodebuild test -scheme NodePass -destination 'platform=iOS Simulator,name=iPhone 18 Pro'` or
`-destination 'platform=macOS'`.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the design.

## License

See [LICENSE](LICENSE).
