"""Server mode with real processes: a console server (no character of its own), the owner joining
from the same computer as the host character, a friend joining as a guest, the owner leaving
while the world keeps running for the friend, and the owner returning."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
WORK = Path(tempfile.mkdtemp(prefix="tempestrpg-network-server-"))
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

def client(name, udp, identity):
    report = WORK / f"{name}.json"
    stop = WORK / f"{name}.stop"
    if stop.exists():
        stop.unlink()
    if report.exists():
        report.unlink()
    log = (WORK / f"{name}.log").open("w")
    args = [GODOT, "--headless", "--path", str(ROOT), "--script", "tests/network_server_peer.gd", "--", f"--port={udp}", f"--identity={identity}", f"--report={report}", f"--stop={stop}"]
    proc = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT)
    processes.append((proc, log))
    return proc, report, stop

def wait(path, key, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (FileNotFoundError, json.JSONDecodeError):
            data = {}
        if data.get("denied"):
            raise AssertionError(data["denied"])
        if data.get(key):
            return data
        time.sleep(0.05)
    raise AssertionError(f"Timed out waiting for {path.name}: {key}")

def server_log():
    return (WORK / "server.log").read_text(encoding="utf-8", errors="replace")

def wait_log(text, timeout=20):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if text in server_log():
            return True
        time.sleep(0.05)
    raise AssertionError(f"Server never logged: {text}")

try:
    udp = port()
    save = WORK / "server_world.json"
    log = (WORK / "server.log").open("w")
    server = subprocess.Popen([GODOT, "--headless", "--path", str(ROOT), "--", "--server", "--no-upnp", f"--save={save}", f"--port={udp}"], stdout=log, stderr=subprocess.STDOUT)
    processes.append((server, log))
    wait_log("TempestRPG server")
    check(f"UDP {udp}" in server_log() and "127.0.0.1" in server_log(), "The console server starts and says how to join")
    check(save.exists(), "The server saved its world")
    owner, owner_report, owner_stop = client("owner", udp, WORK / "owner_profile.json")
    joined = wait(owner_report, "joined")
    check(joined["id"] == "host", "The owner on this computer plays the host character")
    wait_log("The owner joined")
    friend, friend_report, friend_stop = client("friend", udp, WORK / "friend_profile.json")
    guest = wait(friend_report, "joined")
    check(guest["id"].startswith("character_") and "host" in guest["players"], "A second game joins as a new character and sees the owner")
    owner_stop.touch()
    check(owner.wait(timeout=15) == 0, "The owner leaves")
    wait_log("The owner left")
    time.sleep(1.0)
    check(server.poll() is None, "The server keeps running for the friend")
    owner, owner_report, owner_stop = client("owner_again", udp, WORK / "owner_profile.json")
    again = wait(owner_report, "joined")
    check(again["id"] == "host", "The owner returns to the host character")
    data = json.loads(save.read_text(encoding="utf-8"))
    check("host" in data["players"] and len(data["players"]) == 2, "The world saves the owner's and the friend's characters")
    for stop in (owner_stop, friend_stop):
        stop.touch()
    owner.wait(timeout=15)
    friend.wait(timeout=15)
    print(f"Server network integration: {checks} checks passed")
finally:
    for proc, handle in processes:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        handle.close()
