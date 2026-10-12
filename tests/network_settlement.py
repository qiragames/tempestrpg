"""Concurrent shared camp claims and persistence with actual host/client processes."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
WORK = Path(tempfile.mkdtemp(prefix="tempestrpg-network-camp-"))
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
    args = [GODOT, "--headless", "--path", str(ROOT), "--script", "tests/network_camp_peer.gd", "--"]
    options.update(report=report, phase=WORK / "phase", stop=WORK / f"{name}.stop")
    proc = subprocess.Popen(args + [f"--{k}={v}" for k, v in options.items()], stdout=log, stderr=subprocess.STDOUT)
    processes.append((proc, log, name))
    return proc, report

def wait(path, key, value=True):
    deadline = time.monotonic() + 10
    while time.monotonic() < deadline:
        try:
            data = json.loads(path.read_text())
        except (FileNotFoundError, json.JSONDecodeError):
            data = {}
        if data.get("error"):
            raise AssertionError(data["error"])
        if data.get(key) == value:
            return data
        time.sleep(0.03)
    raise AssertionError(f"Timed out waiting for {path.name}: {key}")

def finish(proc, name):
    (WORK / f"{name}.stop").touch()
    check(proc.wait(timeout=8) == 0, f"{name} exits successfully")

try:
    udp_port = port()
    save = WORK / "world.json"
    host, report = start("host", mode="server", port=udp_port, save=save)
    check(wait(report, "ready")["camp"]["founded"], "Host establishes a shared camp")
    clients = [start(f"guest_{i}", mode="client", port=udp_port, identity=WORK / f"identity_{i}.json") for i in range(2)]
    for _, path in clients:
        wait(path, "ready")
    expectations = [("wood_1", 8, 0, False), ("wood_2", 16, 0, False), ("stone_1", 16, 8, False), ("hut_1", 4, 2, True)]
    for phase, wood, stone, hut in expectations:
        (WORK / "phase").write_text(phase)
        results = [wait(path, "phase", phase) for _, path in clients]
        for result in results:
            check(result["guard"], "Replica rejects direct settlement mutation")
            check(result["menu_local"], "Camp menu keeps shared simulation running")
            state = result["camp"]
            check(state["wood"] == wood and state["stone"] == stone and state["hut"] == hut, "Concurrent repeated actions resolve once and balance shared resources")
        check(results[0]["camp"] == results[1]["camp"], "Clients observe identical shared camp state")
    for i, (proc, _) in enumerate(clients):
        finish(proc, f"guest_{i}")
    finish(host, "host")
    saved = wait(report, "saved")
    check(saved["camp"]["hut"] and all(v == 0 for v in saved["camp"]["deposits"].values()), "Host saves hut and depleted deposits together")
    (WORK / "phase").unlink()
    udp_port = port()
    host, report = start("reload_host", mode="server", port=udp_port, save=save, reload="yes")
    check(wait(report, "ready")["camp"] == saved["camp"], "Host restart restores complete camp state")
    guest, guest_report = start("resumed", mode="client", port=udp_port, identity=WORK / "identity_0.json", reload="yes")
    check(wait(guest_report, "restored")["camp"] == saved["camp"], "Returning guest receives restored camp state")
    check(guest.wait(timeout=8) == 0, "Returning client exits successfully")
    finish(host, "reload_host")
    for _, log, name in processes:
        log.flush()
        output = (WORK / f"{name}.log").read_text()
        check("ERROR:" not in output and "SCRIPT ERROR" not in output, f"{name} has no engine errors")
    print(f"Settlement network integration: {checks} checks passed")
finally:
    for proc, log, _ in processes:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
        log.close()
