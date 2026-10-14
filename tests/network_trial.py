"""Personal trial with real host/client processes: owner-only start and credit, replication, save exclusion and reload."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
WORK = Path(tempfile.mkdtemp(prefix="tempestrpg-network-trial-"))
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
    args = [GODOT, "--headless", "--path", str(ROOT), "--script", "tests/network_trial_peer.gd", "--"]
    proc = subprocess.Popen(args + [f"--{k}={v}" for k, v in options.items()], stdout=log, stderr=subprocess.STDOUT)
    processes.append((proc, log, name))
    return proc, report

def wait(path, key, timeout=12):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        try:
            data = json.loads(path.read_text(encoding="utf-8"))
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
    (WORK / "phase").write_text("trial")
    results = [wait(report, "phase", timeout=15) for _, report in clients]
    qualified = [r for r in results if r["qualified"]]
    helper = [r for r in results if not r["qualified"]]
    check(len(qualified) == 1 and len(helper) == 1, "Exactly one guest knows the required Extra skill")
    qualified, helper = qualified[0], helper[0]
    for result in results:
        check(result["guard"], "Client replicas cannot start trials locally")
        check(result["during"].get("active") and result["during"].get("owner") == qualified["id"], "Both clients observe the qualified guest's running trial")
        check(result["creatures"] == 3, "Both clients receive the three trial creatures")
        check(not result["after_active"], "Both clients observe the trial ending")
    check("proving_trial" in qualified["trials"] and "predator_focus" in qualified["skills"] and not qualified["slotted_before"], "The owner earns trial evidence and learns Predator Focus (not usable until activated)")
    check("predator_focus" in qualified["progression"]["tree"]["active"] and "predator_focus" in qualified["slots"], "Activating it through the host puts Predator Focus on the hotbar")
    check(sorted(qualified["split_skills"]) == ["predator_focus", "rending_bite", "thorn_lash"] and "piercing_fang" in qualified["skills"] and "rending_bite" not in qualified["skills"], "The owner splits Piercing Fang and fuses it again through the host")
    check(helper["trials"] == [] and "predator_focus" not in helper["skills"], "The helper and the late requester are not credited")
    check(qualified["progression"]["experience"] == 1500 and qualified["progression"]["level"] == 3 and qualified["progression"]["skill_points"] == 2 and helper["progression"]["experience"] == 0, "Only the trial owner gains 1500 XP (24b: level 3, 3 points, 2 left after activating), replicated to its client")
    check(qualified["hud_level"].startswith("Lv 3 · XP 1500 / 2167") and helper["hud_level"].startswith("Lv 1 · XP 0 / 100"), "Each client's HUD shows its own level and XP")
    for i, (proc, _) in enumerate(clients):
        finish(proc, f"guest_{i}")
    finish(host, "host")
    saved = wait(host_report, "saved")
    check(saved["trial_enemies"] == 0 and not saved["has_trial"], "World saves contain no trial state or creatures")
    check("proving_trial" in saved["evidence"][qualified["id"]]["trials"] and saved["evidence"][helper["id"]]["trials"] == [], "Host saves personal trial evidence")
    (WORK / "phase").unlink()
    udp = port()
    host, host_report = start("reload", mode="server", port=udp, save=save, reload="yes")
    reloaded = wait(host_report, "ready")
    check(reloaded["evidence"] == saved["evidence"], "Host restart restores trial evidence and the Unique skill")
    finish(host, "reload")
    for _, log, name in processes:
        log.flush()
        output = (WORK / f"{name}.log").read_text(encoding="utf-8")
        check("SCRIPT ERROR" not in output and "ERROR:" not in output, f"{name} has no engine errors")
    print(f"Trial network integration: {checks} checks passed")
finally:
    for proc, log, _ in processes:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
        log.close()
