"""Solo-hosted world opened to friends mid-game, with real host/client processes, save and reload."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
WORK = Path(tempfile.mkdtemp(prefix="tempestrpg-network-worlds-"))
GODOT = os.environ.get("GODOT_BIN", "godot")
processes = []
checks = 0

def check(ok, message):
    global checks
    checks += 1
    if not ok:
        raise AssertionError(message)

def port():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]

def start(name, **options):
    report = WORK / f"{name}.json"
    log = (WORK / f"{name}.log").open("w")
    options.update(report=report, phase=WORK / f"{name}.phase", stop=WORK / f"{name}.stop")
    args = [GODOT, "--headless", "--path", str(ROOT), "--script", "tests/network_worlds_peer.gd", "--"]
    proc = subprocess.Popen(args + [f"--{k}={v}" for k, v in options.items()], stdout=log, stderr=subprocess.STDOUT)
    processes.append((proc, log, name))
    return proc, report

def wait(path, key, timeout=12):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            data = json.loads(path.read_text())
        except (FileNotFoundError, json.JSONDecodeError):
            data = {}
        if data.get("error"):
            raise AssertionError(data["error"])
        if data.get(key):
            return data
        time.sleep(0.03)
    raise AssertionError(f"Timed out waiting for {path.name}: {key}")

def finish(proc, name):
    (WORK / f"{name}.stop").touch()
    check(proc.wait(timeout=8) == 0, f"{name} exits successfully")

try:
    save = WORK / "friends_test.json"
    udp = port()
    host, report = start("host", mode="server", port=udp, save=save)
    ready = wait(report, "ready")
    check(not ready["listening"] and ready["offline_peer"], "A new world starts solo without opening a port")
    check(ready["meta"]["name"] == "Friends Test" and ready["meta"]["seed"] == 4242, "World meta set from the menu")
    (WORK / "host.phase").write_text("open")
    opened = wait(report, "opened")
    check(opened["listening"], "Open to friends starts listening without restarting the world")
    guest, guest_report = start("guest", mode="client", port=udp, identity=WORK / "identity.json")
    joined = wait(guest_report, "joined")
    check(joined["meta"].get("name") == "Friends Test", "The friend receives the world's name")
    check("host" in joined["players"] and joined["id"] in joined["players"], "Host and friend share the world")
    finish(guest, "guest")
    finish(host, "host")
    saved = wait(report, "saved")
    check(joined["id"] in saved["players"] and saved["meta"]["name"] == "Friends Test" and saved["world_id"] == opened["world_id"], "The host's save keeps the friend's character and the world identity")
    udp = port()
    host, report = start("reload", mode="server", port=udp, save=save)
    reloaded = wait(report, "ready")
    check(not reloaded["listening"] and joined["id"] in reloaded["records"], "Reloading starts solo again with the friend's character kept")
    (WORK / "reload.phase").write_text("open")
    wait(report, "opened")
    guest, guest_report = start("guest_again", mode="client", port=udp, identity=WORK / "identity.json")
    rejoined = wait(guest_report, "joined")
    check(rejoined["id"] == joined["id"], "The friend rejoins as the same character after reopening")
    finish(guest, "guest_again")
    finish(host, "reload")
    for _, log, name in processes:
        log.flush()
        output = (WORK / f"{name}.log").read_text()
        check("SCRIPT ERROR" not in output and "ERROR:" not in output, f"{name} has no engine errors")
    print(f"Worlds network integration: {checks} checks passed")
finally:
    for proc, log, _ in processes:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
        log.close()
