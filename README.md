# NodePass for Apple Platforms

A professional control plane for [NodePass](https://github.com/NodePassProject/nodepass) masters and
[Nowhere](https://github.com/NodePassProject/Nowhere) OpenCtrl controllers on iPhone, iPad and Mac (Catalyst).

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
- **Widget** — host metrics and instance counts of a master on the Home Screen.

## Project layout

```
Shared/          Core compiled into every target: models, MasterClient (REST + SSE), URL grammar, parameter catalog
NodePass/        The app: sessions, features (Masters, Instances, Tools, Settings), design system
Widget/          WidgetKit extension
NodePassTests/   Swift Testing suite for the grammar, catalog, wire formats and filters
Scripts/         mock_master.py — a local stand-in master for development
docs/            Architecture notes
```

All folders are Xcode *synchronized folders*: adding a file on disk adds it to the right target.

## Development

Requirements: Xcode 27, iOS 26 SDK. Open `NodePass.xcodeproj` and run the `NodePass` scheme.

To work without a real master:

```bash
python3 Scripts/mock_master.py --port 9090 --key demo
```

Then add a master with URL `http://127.0.0.1:9090/api/v1` (NodePass flavor) or `http://127.0.0.1:9090/api/v2`
(Nowhere flavor) and key `demo`. The mock streams fake traffic and logs, honours every mutation and rotates the API key.

Run the tests with `xcodebuild test -scheme NodePass -destination 'platform=iOS Simulator,name=iPhone 18 Pro'`.

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the design.

## License

See [LICENSE](LICENSE).
