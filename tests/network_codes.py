"""Join codes with real processes: a host and a friend connect through WebRTC only by swapping
an invite code and a reply code (no address, no port), then play in the same world."""
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
WORK = Path(tempfile.mkdtemp(prefix="tempestrpg-network-codes-"))
GODOT = os.environ.get("GODOT_BIN", "godot")
processes = []
checks = 0

def check(ok, message):
    global checks
    checks += 1
    if not ok:
        raise AssertionError(message)

def start(name, **options):
    report = WORK / f"{name}.json"
    log = (WORK / f"{name}.log").open("w")
    options.update(report=report, dir=WORK)
    args = [GODOT, "--headless", "--path", str(ROOT), "--script", "tests/network_codes_peer.gd", "--"]
    proc = subprocess.Popen(args + [f"--{k}={v}" for k, v in options.items()], stdout=log, stderr=subprocess.STDOUT)
    processes.append((proc, log))
    return proc, report

def wait(path, timeout=60):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
        except (FileNotFoundError, json.JSONDecodeError):
            data = {}
        if data.get("error"):
            raise AssertionError(data["error"])
        if data.get("ready"):
            return data
        time.sleep(0.1)
    raise AssertionError(f"Timed out waiting for {path.name}")

try:
    host, host_report = start("host", mode="host", save=WORK / "codes_world.json")
    friend, friend_report = start("friend", mode="friend", identity=WORK / "friend_profile.json")
    joined = wait(friend_report)
    hosted = wait(host_report)
    check((WORK / "invite.txt").read_text().startswith("TRPG1-") and (WORK / "reply.txt").read_text().startswith("TRPG1-"), "Invite and reply are join codes")
    check(hosted["accepted"] and not hosted["bad_reply"], "The host accepts the friend's reply (and rejects garbage)")
    check(joined["id"].startswith("character_") and "host" in joined["players"], "The friend joined through the codes and sees the host")
    check(len(hosted["owners"]) == 2, "The host counts two players")
    (WORK / "stop").touch()
    check(host.wait(timeout=20) == 0 and friend.wait(timeout=20) == 0, "Both leave cleanly")
    data = json.loads((WORK / "codes_world.json").read_text(encoding="utf-8"))
    check(len(data["players"]) == 2, "The world saved the friend's character")
    print(f"Join code network integration: {checks} checks passed (invite {hosted['invite_length']} chars, reply {joined['reply_length']} chars)")
finally:
    for proc, handle in processes:
        if proc.poll() is None:
            proc.kill()
            proc.wait()
        handle.close()
