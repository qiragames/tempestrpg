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

def wait(path, key, value=True, timeout=10):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
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
    # Each phase: both guests send the same request twice at once; the host must apply it exactly once
    # (offerings once per guest, since each guest carries one essence).
    expectations = [
        ("wood_1", dict(wood=8, stone=0, hut=False)), ("wood_2", dict(wood=16, stone=0)), ("stone_1", dict(wood=16, stone=8)),
        ("hut_1", dict(wood=4, stone=2, hut=True, storehouse=False)),
        ("wood_3", dict(wood=12, stone=2)), ("stone_2", dict(wood=12, stone=10)), ("stone_3", dict(wood=12, stone=18)),
        ("storehouse_1", dict(wood=2, stone=12, storehouse=True)),
        ("offer", dict(essence=2, essence_offered=2, shrine=False)),
        ("shrine_1", dict(wood=2, stone=4, essence=0, essence_offered=2, shrine=True)),
    ]
    for phase, expected in expectations:
        (WORK / "phase").write_text(phase)
        results = [wait(path, "phase", phase) for _, path in clients]
        for result in results:
            check(result["guard"], "Replica rejects direct settlement mutation")
            check(result["menu_local"], "Camp menu keeps shared simulation running")
            state = result["camp"]
            check(all(state[k] == v for k, v in expected.items()), f"{phase}: concurrent repeated actions resolve once and balance shared resources")
        check(results[0]["camp"] == results[1]["camp"], "Clients observe identical shared camp state")
    for i, (proc, _) in enumerate(clients):
        finish(proc, f"guest_{i}")
    finish(host, "host")
    saved = wait(report, "saved")
    check(saved["camp"]["hut"] and saved["camp"]["storehouse"] and saved["camp"]["shrine"] and all(v == 0 for v in saved["camp"]["deposits"].values()), "Host saves structures and depleted deposits together")
    (WORK / "phase").unlink()
    udp_port = port()
    host, report = start("reload_host", mode="server", port=udp_port, save=save, reload="yes")
    check(wait(report, "ready")["camp"] == saved["camp"], "Host restart restores complete camp state")
    guest, guest_report = start("resumed", mode="client", port=udp_port, identity=WORK / "identity_0.json", reload="yes")
    check(wait(guest_report, "restored")["camp"] == saved["camp"], "Returning guest receives restored camp state")
    check(guest.wait(timeout=8) == 0, "Returning client exits successfully")
    finish(host, "reload_host")
    # Owned worker jobs survive an actual host restart midway through gathering.
    udp_port = port()
    work_save = WORK / "work_world.json"
    host, report = start("work_host", mode="server", port=udp_port, save=work_save, work="yes")
    wait(report, "ready")
    workers = [start(f"worker_{i}", mode="client", port=udp_port, identity=WORK / f"worker_identity_{i}.json") for i in range(2)]
    for _, path in workers:
        wait(path, "ready")
    (WORK / "phase").write_text("work_gather")
    assigned = [wait(path, "phase", "work_gather") for _, path in workers]
    check(all(r["guard"] and r["menu_local"] for r in assigned), "Clients cannot mutate jobs; work menus remain local")
    check(all(r["work"]["role"] == "gather" for r in assigned), "Clients observe one authoritative gathering assignment")
    for i, (proc, _) in enumerate(workers):
        finish(proc, f"worker_{i}")
    finish(host, "work_host")
    partial = wait(report, "saved")
    check(partial["work"]["role"] == "gather", "Host persists an unfinished worker job")
    (WORK / "phase").unlink()
    udp_port = port()
    host, report = start("work_reload", mode="server", port=udp_port, save=work_save, reload="yes", work="yes")
    restored = wait(report, "ready")
    check(restored["work"]["owner"] == partial["work"]["owner"] and restored["work"]["role"] == "gather", "Restart restores worker ownership and role")
    check(restored["work"]["remaining"] <= partial["work"]["remaining"], "Restart cannot reset work timer")
    gathered = wait(report, "gathered", timeout=20)
    check(gathered["camp"]["wood"] == 16 and gathered["camp"]["stone"] == 8, "Disconnected owner's worker finishes finite gathering without duplicate stock")
    clients = [start(f"builder_{i}", mode="client", port=udp_port, identity=WORK / f"worker_identity_{i}.json") for i in range(2)]
    for _, path in clients:
        wait(path, "ready")
    (WORK / "phase").write_text("work_build")
    building = [wait(path, "phase", "work_build") for _, path in clients]
    check(all(r["work"]["role"] == "build" for r in building), "Owned construction assignment replicates to both clients")
    time.sleep(4.5)
    for i, (proc, _) in enumerate(clients):
        finish(proc, f"builder_{i}")
    finish(host, "work_reload")
    built = wait(report, "saved")
    check(built["camp"]["hut"] and built["camp"]["wood"] == 4 and built["camp"]["stone"] == 2, "Worker construction charges materials once and saves completed hut")
    check(built["work"]["role"] == "follow", "Completed builder returns to follow")
    for _, log, name in processes:
        log.flush()
        output = (WORK / f"{name}.log").read_text(encoding="utf-8")
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
