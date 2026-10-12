"""Mimic forms with real host/client processes: owned requests, single cost, replication, save/reload."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
WORK = Path(tempfile.mkdtemp(prefix="tempestrpg-network-forms-"))
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
    options.update(report=report, phase=WORK / "phase", stop=WORK / f"{name}.stop")
    args = [GODOT, "--headless", "--path", str(ROOT), "--script", "tests/network_form_peer.gd", "--"]
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
    save = WORK / "world.json"
    udp = port()
    host, host_report = start("host", mode="server", port=udp, save=save)
    wait(host_report, "ready")
    clients = []
    for i in range(2):
        clients.append(start(f"guest_{i}", mode="client", port=udp, identity=WORK / f"identity_{i}.json"))
        wait(clients[-1][1], "ready")
    (WORK / "phase").write_text("transform")
    results = [wait(report, "phase") for _, report in clients]
    for result in results:
        check(result["guard"], "Client replicas cannot transform locally")
    analyst = [r for r in results if "forest_gnasher" in r["analyzed"]]
    other = [r for r in results if "forest_gnasher" not in r["analyzed"]]
    check(len(analyst) == 1 and len(other) == 1, "Exactly one guest has Gnasher analysis evidence")
    analyst, other = analyst[0], other[0]
    check(analyst["forms"][analyst["id"]] == "gnasher" and analyst["local_form"] == "gnasher", "The analyst's owned request transforms it")
    check(other["forms"][other["id"]] == "slime", "A guest without the analysis is rejected and stays a slime")
    check(abs(analyst["magicules"] - 80.0) < 0.01 and abs(other["magicules"] - 100.0) < 0.01, "Duplicate requests charge one 20-Magicule cost; rejected requests charge nothing")
    check(results[0]["forms"] == results[1]["forms"], "Both clients observe identical forms for every character")
    for i, (proc, _) in enumerate(clients):
        finish(proc, f"guest_{i}")
    finish(host, "host")
    saved = wait(host_report, "saved")
    check(saved["forms"][analyst["id"]] == "gnasher" and saved["forms"][other["id"]] == "slime", "Host saves each character's form")
    (WORK / "phase").unlink()
    udp = port()
    host, host_report = start("reload", mode="server", port=udp, save=save, reload="yes")
    reloaded = wait(host_report, "ready")
    check(reloaded["forms"] == saved["forms"], "Host restart restores every character's form")
    finish(host, "reload")
    for _, log, name in processes:
        log.flush()
        output = (WORK / f"{name}.log").read_text()
        check("SCRIPT ERROR" not in output and "ERROR:" not in output, f"{name} has no engine errors")
    print(f"Form network integration: {checks} checks passed")
finally:
    for proc, log, _ in processes:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
        log.close()
