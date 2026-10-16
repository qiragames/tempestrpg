"""M10: a friend brings their own character into a host's world (real processes): refused when the
owner allows only new characters; when allowed it arrives with its level, Zeni, gear and title,
without the home world's chests; progress made at the friend's is written back home (the home
world's own parts — position, chests — stay)."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
WORK = Path(tempfile.mkdtemp(prefix="tempestrpg-network-import-"))
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
    options.update(report=report, stop=WORK / f"{name}.stop")
    args = [GODOT, "--headless", "--path", str(ROOT), "--script", "tests/network_import_peer.gd", "--"]
    proc = subprocess.Popen(args + [f"--{k}={v}" for k, v in options.items()], stdout=log, stderr=subprocess.STDOUT)
    processes.append((proc, log, name))
    return proc, report

def wait(path, key, timeout=20):
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
        time.sleep(0.05)
    raise AssertionError(f"Timed out waiting for {path.name}: {key}")

def own_world():
    return json.loads((WORK / "home.json").read_text(encoding="utf-8"))["players"]["host"]

try:
    maker, report = start("make", mode="make", port=port(), save=WORK / "home.json")
    check(wait(report, "made")["made"] and maker.wait(timeout=20) == 0, "The friend's own world with a level 20 Demon")
    before = own_world()
    # The owner allows only new characters.
    udp = port()
    host, host_report = start("strict", mode="server", port=udp, save=WORK / "strict_world.json", imports="no")
    wait(host_report, "ready")
    guest, guest_report = start("refused", mode="client", port=udp, identity=WORK / "id1.json", own=WORK / "home.json")
    denied = wait(guest_report, "denied")
    check("only new characters" in denied["denied"] and guest.wait(timeout=10) == 0, "A world for new characters only refuses a brought character")
    (WORK / "strict.stop").touch()
    host.wait(timeout=10)
    # The owner allows guests' own characters.
    udp = port()
    host, host_report = start("open", mode="server", port=udp, save=WORK / "open_world.json", imports="yes")
    check(wait(host_report, "ready")["imports"], "The host allows guests' own characters")
    guest, guest_report = start("brought", mode="client", port=udp, identity=WORK / "id2.json", own=WORK / "home.json")
    joined = wait(guest_report, "joined", timeout=25)
    arrived = joined["arrived"]
    check(arrived["level"] == 20 and arrived["race"] == "Demon" and arrived["zeni"] == 12345, "The character arrives with its level, race and Zeni")
    home_items = [item["id"] for item in before["gear"]["items"]]
    check(len(home_items) == 1 and arrived["items"] == home_items and arrived["title"] == "leviathan", "...with its gear and its title")
    check(arrived["chests"] == [], "...but not the home world's opened chests")
    check(guest.wait(timeout=10) == 0, "The friend leaves cleanly")
    (WORK / "open.stop").touch()
    saved = wait(host_report, "saved")
    check(joined["id"] in saved["records"] and saved["players"][joined["id"]]["progression"]["level"] == 20, "The host's world keeps the brought character")
    after = own_world()
    check("demon_hunger" in after["progression"]["tree"]["nodes"] and after["progression"]["skill_points"] == before["progression"]["skill_points"] - 1, "The skill bought at the friend's is written back into the own world")
    check(after["position"] == before["position"] and after["progression"]["chests"] == ["chest_keep"], "The own world keeps its position and opened chests")
    check(after["progression"]["level"] == 20 and after["progression"]["zeni"] == 12345, "Level and Zeni are unchanged at home")
    for proc, log, name in processes:
        log.flush()
        output = (WORK / f"{name}.log").read_text(encoding="utf-8")
        check("SCRIPT ERROR" not in output, f"{name} has no script errors")
    print(f"Import network integration: {checks} checks passed")
finally:
    for proc, log, _ in processes:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
        log.close()
