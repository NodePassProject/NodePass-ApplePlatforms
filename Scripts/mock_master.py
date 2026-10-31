#!/usr/bin/env python3
"""
Local stand-in for a NodePass master / Nowhere OpenCtrl controller.

Serves the shared REST + SSE contract on two prefixes:

    /api/v1   NodePass flavor  (server:// and client:// instances)
    /api/v2   OpenCtrl flavor  (portal:// vector:// egress:// instances)

Usage:
    python3 Scripts/mock_master.py --port 9090 --key demo

Then add a master in the app with URL http://127.0.0.1:9090/api/v1 (or /api/v2) and key "demo".
Running instances accumulate fake traffic once per second and emit log lines; every mutation is
broadcast to SSE subscribers exactly like the real master does.
"""

import argparse
import json
import queue
import random
import secrets
import threading
import time
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

API_KEY_ID = "********"
START = time.time()


def now_rfc3339():
    return datetime.now(timezone.utc).isoformat(timespec="microseconds").replace("+00:00", "Z")


def gen_id():
    return secrets.token_hex(4)


class Flavor:
    def __init__(self, name, roles, seed):
        self.name = name
        self.roles = roles
        self.lock = threading.RLock()
        self.subscribers = []  # list[queue.Queue]
        self.alias = f"mock-{name}"
        self.mid = secrets.token_hex(8)
        self.instances = {
            API_KEY_ID: {
                "id": API_KEY_ID, "alias": self.alias, "type": "", "status": "", "url": "", "config": self.mid,
                "restart": False, "meta": {"peer": {"sid": "", "type": "", "alias": ""}, "tags": {}},
                "mode": 0, "ping": 0, "pool": 0, "tcps": 0, "udps": 0, "tcprx": 0, "tcptx": 0, "udprx": 0, "udptx": 0,
            }
        }
        for alias, url, status, tags in seed:
            inst = self.make_instance(url, alias)
            inst["status"] = status
            inst["meta"]["tags"] = tags
            if status == "running":
                inst["tcprx"] = random.randint(10**6, 10**9)
                inst["tcptx"] = random.randint(10**6, 10**9)
                inst["pool"] = random.randint(8, 64)
                inst["ping"] = random.randint(5, 80)
            self.instances[inst["id"]] = inst

    def make_instance(self, url, alias=""):
        scheme = url.split("://", 1)[0]
        if scheme not in self.roles:
            raise ValueError("Invalid URL scheme")
        config = url + ("&" if "?" in url else "?") + "log=info" + ("&tls=1" if scheme == "server" and "tls=" not in url else "")
        return {
            "id": gen_id(), "alias": alias or "", "type": scheme, "status": "stopped", "url": url, "config": config,
            "restart": True, "meta": {"peer": {"sid": "", "type": "", "alias": ""}, "tags": {}},
            "mode": 0, "ping": 0, "pool": 0, "tcps": 0, "udps": 0, "tcprx": 0, "tcptx": 0, "udprx": 0, "udptx": 0,
        }

    def broadcast(self, kind, instance, logs=""):
        event = {"type": kind, "time": now_rfc3339(), "instance": instance, "logs": logs}
        for q in list(self.subscribers):
            try:
                q.put_nowait(event)
            except queue.Full:
                pass

    def tick(self):
        with self.lock:
            for inst in self.instances.values():
                if inst["id"] == API_KEY_ID or inst["status"] != "running":
                    continue
                inst["tcprx"] += random.randint(0, 400_000)
                inst["tcptx"] += random.randint(0, 150_000)
                inst["udprx"] += random.randint(0, 20_000)
                inst["udptx"] += random.randint(0, 20_000)
                inst["tcps"] = max(0, inst["tcps"] + random.randint(-2, 3))
                inst["udps"] = max(0, inst["udps"] + random.randint(-1, 1))
                inst["ping"] = max(1, inst["ping"] + random.randint(-3, 3))
                inst["pool"] = max(0, inst["pool"] + random.randint(-1, 1))
                self.broadcast("update", dict(inst))
                if random.random() < 0.25:
                    level = random.choice(["INFO", "INFO", "DEBUG", "WARN", "EVENT"])
                    msg = random.choice([
                        "Tunnel connection established", "Pool connection ready", "Health check OK",
                        "Target dial succeeded", "Signal queue drained", "DNS cache refreshed",
                    ])
                    line = f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]}  {level}  {msg} [{inst['id']}]"
                    self.broadcast("log", dict(inst), line)

    def info(self):
        uptime = int(time.time() - START)
        return {
            "mid": self.mid, "alias": self.alias, "os": "linux", "arch": "amd64", "noc": 4,
            "cpu": random.randint(5, 60), "mem_total": 8 * 1024**3, "mem_used": int(8 * 1024**3 * random.uniform(0.3, 0.6)),
            "swap_total": 2 * 1024**3, "swap_used": int(2 * 1024**3 * 0.1),
            "netrx": int(uptime * 1_500_000), "nettx": int(uptime * 600_000),
            "diskr": int(uptime * 20_000), "diskw": int(uptime * 50_000), "sysup": 864_000 + uptime,
            "ver": "mock-1.9.0", "name": "mock-host", "uptime": uptime, "log": "info", "tls": "0", "crt": "", "key": "",
        }


FLAVORS = {
    "v1": Flavor("nodepass", {"server", "client"}, [
        ("edge-tokyo", "server://0.0.0.0:10101/127.0.0.1:8080?tls=1&mode=2", "running", {"env": "prod", "region": "ap-ne-1"}),
        ("db-relay", "client://secret@relay.example.com:10101/127.0.0.1:3306?min=32&read=30s", "running", {"env": "prod"}),
        ("lab", "client://127.0.0.1:1080/app1.local:8080,app2.local:8080?mode=1&lbs=1&log=debug", "stopped", {"env": "dev"}),
        ("broken", "server://:20202/:9000?tls=2", "error", {"env": "dev", "owner": "ops"}),
    ]),
    "v2": Flavor("openctrl", {"portal", "vector", "egress"}, [
        ("portal-hk", "portal://0123456789abcdef0123456789abcdef@*/tcp:2000/udp:2001?out=egress", "running", {"site": "hk"}),
        ("vector-office", "vector://0123456789abcdef0123456789abcdef@portal.example:2000?in=127.0.0.1:1080", "running", {}),
        ("egress-home", "egress://0123456789abcdef0123456789abcdef@portal.example/udp:2001", "stopped", {"site": "home"}),
    ]),
}


class Handler(BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.1"
    server_version = "mock-master/1.0"
    api_key = "demo"

    def log_message(self, fmt, *args):  # quieter logging
        print(f"{self.command} {self.path} -> {fmt % args}")

    # ---- helpers

    def route(self):
        parsed = urlparse(self.path)
        parts = parsed.path.strip("/").split("/")
        if len(parts) < 2 or parts[0] != "api" or parts[1] not in FLAVORS:
            return None, None, None
        return FLAVORS[parts[1]], parts[2:], parse_qs(parsed.query)

    def send_json(self, code, payload):
        body = json.dumps(payload).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(body)

    def error(self, code, message):
        self.send_json(code, {"error": message})

    def read_body(self):
        length = int(self.headers.get("Content-Length") or 0)
        raw = self.rfile.read(length) if length else b""
        if not raw:
            return {}
        try:
            return json.loads(raw)
        except json.JSONDecodeError:
            return None

    def authorized(self, flavor):
        key = self.headers.get("X-API-Key", "")
        return key == self.api_key

    # ---- verbs

    def do_OPTIONS(self):
        self.send_response(200)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, PATCH, POST, PUT, DELETE, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type, X-API-Key")
        self.send_header("Content-Length", "0")
        self.end_headers()

    def do_GET(self):
        flavor, parts, query = self.route()
        if flavor is None:
            return self.error(404, "Not found")
        if parts == ["openapi.json"]:
            if flavor.name != "nodepass":
                return self.error(404, "Not found")
            return self.send_json(200, {"openapi": "3.1.1", "info": {"title": "NodePass API (mock)", "version": "1.0"}, "paths": {}})
        if not self.authorized(flavor):
            return self.error(401, "Unauthorized: Invalid API key")
        if parts == ["instances"]:
            with flavor.lock:
                return self.send_json(200, list(flavor.instances.values()))
        if len(parts) == 2 and parts[0] == "instances":
            with flavor.lock:
                inst = flavor.instances.get(parts[1])
            return self.send_json(200, inst) if inst else self.error(404, "Instance not found")
        if parts == ["info"]:
            return self.send_json(200, flavor.info())
        if parts == ["tcping"]:
            target = (query.get("target") or [""])[0]
            if not target:
                return self.error(400, "Target address required")
            ok = random.random() > 0.2
            return self.send_json(200, {"target": target, "connected": ok, "latency": random.randint(3, 180) if ok else 0,
                                        "error": None if ok else "dial tcp: i/o timeout"})
        if parts == ["events"]:
            return self.stream_events(flavor)
        return self.error(404, "Not found")

    def do_POST(self):
        flavor, parts, _ = self.route()
        if flavor is None:
            return self.error(404, "Not found")
        if not self.authorized(flavor):
            return self.error(401, "Unauthorized: Invalid API key")
        body = self.read_body()
        if body is None:
            return self.error(400, "Invalid request body")
        if parts == ["instances"]:
            url = body.get("url", "")
            if not url:
                return self.error(400, "Invalid request body")
            try:
                inst = flavor.make_instance(url, body.get("alias", ""))
            except ValueError as exc:
                return self.error(400, str(exc))
            with flavor.lock:
                flavor.instances[inst["id"]] = inst
            self.send_json(201, inst)
            flavor.broadcast("create", dict(inst))
            threading.Timer(1.0, lambda: self.set_status(flavor, inst["id"], "running")).start()
            return
        if parts == ["info"]:
            alias = body.get("alias", "")
            if len(alias) > 256:
                return self.error(400, "Master alias exceeds maximum length 256")
            flavor.alias = alias
            return self.send_json(200, flavor.info())
        return self.error(404, "Not found")

    def do_PATCH(self):
        flavor, parts, _ = self.route()
        if flavor is None or len(parts) != 2 or parts[0] != "instances":
            return self.error(404, "Not found")
        if not self.authorized(flavor):
            return self.error(401, "Unauthorized: Invalid API key")
        body = self.read_body() or {}
        with flavor.lock:
            inst = flavor.instances.get(parts[1])
            if not inst:
                return self.error(404, "Instance not found")
            if inst["id"] == API_KEY_ID:
                if body.get("action") == "restart":
                    Handler.api_key = secrets.token_hex(16)
                    inst["url"] = Handler.api_key
                    print(f"*** API key rotated: {Handler.api_key}")
                return self.send_json(200, inst)
            if body.get("alias"):
                inst["alias"] = body["alias"]
            action = body.get("action")
            if action:
                if action not in {"start", "stop", "restart", "reset"}:
                    return self.error(400, f"Invalid action: {action}")
                if action == "reset":
                    for k in ("tcprx", "tcptx", "udprx", "udptx"):
                        inst[k] = 0
                elif action == "start":
                    threading.Timer(0.7, lambda: self.set_status(flavor, inst["id"], "running")).start()
                elif action == "stop":
                    threading.Timer(0.5, lambda: self.set_status(flavor, inst["id"], "stopped")).start()
                elif action == "restart":
                    threading.Timer(0.4, lambda: self.set_status(flavor, inst["id"], "stopped")).start()
                    threading.Timer(1.6, lambda: self.set_status(flavor, inst["id"], "running")).start()
            if "restart" in body and isinstance(body["restart"], bool):
                inst["restart"] = body["restart"]
            meta = body.get("meta")
            if isinstance(meta, dict):
                if isinstance(meta.get("peer"), dict):
                    peer = meta["peer"]
                    inst["meta"]["peer"] = {"sid": peer.get("sid", ""), "type": peer.get("type", ""), "alias": peer.get("alias", "")}
                if isinstance(meta.get("tags"), dict):
                    for k, v in meta["tags"].items():
                        if len(k) > 256 or len(str(v)) > 256:
                            return self.error(400, "Meta tag exceeds maximum length 256")
                    inst["meta"]["tags"] = dict(meta["tags"])
            snapshot = dict(inst)
        self.send_json(200, snapshot)
        flavor.broadcast("update", snapshot)

    def do_PUT(self):
        flavor, parts, _ = self.route()
        if flavor is None or len(parts) != 2 or parts[0] != "instances":
            return self.error(404, "Not found")
        if not self.authorized(flavor):
            return self.error(401, "Unauthorized: Invalid API key")
        if parts[1] == API_KEY_ID:
            return self.error(403, "Forbidden: API Key")
        body = self.read_body()
        if not body or not body.get("url"):
            return self.error(400, "Invalid request body")
        url = body["url"]
        scheme = url.split("://", 1)[0]
        if scheme not in flavor.roles:
            return self.error(400, "Invalid URL scheme")
        with flavor.lock:
            inst = flavor.instances.get(parts[1])
            if not inst:
                return self.error(404, "Instance not found")
            if inst["url"] == url:
                return self.error(409, "Instance URL conflict")
            inst["url"] = url
            inst["type"] = scheme
            inst["config"] = url + ("&" if "?" in url else "?") + "log=info"
            inst["status"] = "stopped"
            snapshot = dict(inst)
        self.send_json(200, snapshot)
        flavor.broadcast("update", snapshot)
        threading.Timer(1.2, lambda: self.set_status(flavor, snapshot["id"], "running")).start()

    def do_DELETE(self):
        flavor, parts, _ = self.route()
        if flavor is None or len(parts) != 2 or parts[0] != "instances":
            return self.error(404, "Not found")
        if not self.authorized(flavor):
            return self.error(401, "Unauthorized: Invalid API key")
        if parts[1] == API_KEY_ID:
            return self.error(403, "Forbidden: API Key")
        with flavor.lock:
            inst = flavor.instances.pop(parts[1], None)
        if not inst:
            return self.error(404, "Instance not found")
        self.send_response(204)
        self.send_header("Content-Length", "0")
        self.end_headers()
        flavor.broadcast("delete", inst)

    # ---- SSE

    def stream_events(self, flavor):
        self.send_response(200)
        self.send_header("Content-Type", "text/event-stream")
        self.send_header("Cache-Control", "no-cache")
        self.send_header("Connection", "keep-alive")
        self.send_header("Transfer-Encoding", "chunked")
        self.end_headers()
        q = queue.Queue(maxsize=256)
        flavor.subscribers.append(q)
        try:
            self.write_chunk(b"retry: 3000\n\n")
            with flavor.lock:
                snapshot = list(flavor.instances.values())
            for inst in snapshot:
                self.write_event({"type": "initial", "time": now_rfc3339(), "instance": inst, "logs": ""})
            while True:
                try:
                    event = q.get(timeout=15)
                    self.write_event(event)
                except queue.Empty:
                    self.write_chunk(b": keep-alive\n\n")
        except (BrokenPipeError, ConnectionResetError):
            pass
        finally:
            if q in flavor.subscribers:
                flavor.subscribers.remove(q)

    def write_event(self, event):
        payload = json.dumps(event).encode()
        self.write_chunk(b"event: instance\ndata: " + payload + b"\n\n")

    def write_chunk(self, data):
        """HTTP/1.1 chunked transfer, like Go's net/http does when a handler flushes."""
        self.wfile.write(f"{len(data):x}\r\n".encode() + data + b"\r\n")
        self.wfile.flush()

    @staticmethod
    def set_status(flavor, instance_id, status):
        with flavor.lock:
            inst = flavor.instances.get(instance_id)
            if not inst:
                return
            inst["status"] = status
            if status == "running" and inst["pool"] == 0:
                inst["pool"] = random.randint(8, 64)
                inst["ping"] = random.randint(5, 80)
            if status != "running":
                inst["tcps"] = inst["udps"] = 0
            snapshot = dict(inst)
        flavor.broadcast("update", snapshot)
        if status == "running":
            line = f"{datetime.now().strftime('%Y-%m-%d %H:%M:%S.%f')[:-3]}  INFO  Instance started [{instance_id}]"
            flavor.broadcast("log", snapshot, line)


def ticker():
    while True:
        time.sleep(1)
        for flavor in FLAVORS.values():
            flavor.tick()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--port", type=int, default=9090)
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--key", default="demo")
    args = parser.parse_args()
    Handler.api_key = args.key
    threading.Thread(target=ticker, daemon=True).start()
    server = ThreadingHTTPServer((args.host, args.port), Handler)
    server.daemon_threads = True
    print(f"mock master listening on http://{args.host}:{args.port}/api/v1 and /api/v2 (X-API-Key: {args.key})")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass


if __name__ == "__main__":
    main()
