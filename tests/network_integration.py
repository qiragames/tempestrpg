"""Run actual Godot host/client processes; keep reconnect credentials out of logs."""
import json
import os
from pathlib import Path
import socket
import subprocess
import tempfile
import time

ROOT = Path(__file__).resolve().parents[1]
GODOT = os.environ.get("GODOT_BIN", "godot")
WORK = Path(tempfile.mkdtemp(prefix="tempestrpg-network-"))
processes = []
checks = 0


def check(condition, message):
    global checks
    checks += 1
    if not condition:
        raise AssertionError(message)


def free_port():
    with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def start(name, **options):
    log = (WORK / f"{name}.log").open("w")
    report = WORK / f"{name}.json"
    command = [GODOT, "--headless", "--path", str(ROOT), "--script", "tests/network_peer.gd", "--"]
    options["report"] = report
    command += [f"--{key}={value}" for key, value in options.items()]
    proc = subprocess.Popen(command, cwd=ROOT, stdout=log, stderr=subprocess.STDOUT)
    processes.append((proc, log, name))
    return proc, report


def wait_report(path, predicate=lambda value: True, timeout=12):
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if path.exists():
            try:
                value = json.loads(path.read_text(encoding="utf-8"))
            except json.JSONDecodeError:
                value = {}
            if value.get("error"):
                raise AssertionError(value["error"])
            if value and predicate(value):
                return value
        time.sleep(0.03)
    raise AssertionError(f"Timed out waiting for {path.name}")


def finish(proc):
    check(proc.wait(timeout=8) == 0, "Integration process must exit successfully")


try:
    port = free_port()
    world_save = WORK / "world.json"
    server_stop = WORK / "server.stop"
    server, server_report = start("host", mode="server", port=port, save=world_save, stop=server_stop)
    wait_report(server_report, lambda d: d.get("ready"))
    clients = [start(f"player_{i}", mode="client", port=port, identity=WORK / f"identity_{i}.json", case="play") for i in range(2)]
    results = [wait_report(report, lambda d: "state" in d) for _, report in clients]
    for proc, _ in clients:
        finish(proc)
    for result in results:
        check(result["moved"], "Host must accept owned movement intent")
        check(result["guards"], "Client mutations must be blocked")
        check(result["menu_local"], "Local inventory must not pause the host world")
        check(result["no_credentials"], "Replication must omit reconnect credential hashes")
    check(sum(len(r["state"]["skill_ids"]) for r in results) == 1, "Concurrent absorption must acquire a corpse once")
    check(sum(sum(r["state"]["inventory"]["counts"].values()) for r in results) == 1, "Concurrent absorption must award one material")
    check(sorted(len(r["state"]["skill_evidence"]["analyzed"]) for r in results) == [0, 1], "Concurrent absorption records unlock evidence for exactly one character")
    check(all(len(r["state"]["skill_ids"]) == len(r["state"]["skill_evidence"]["analyzed"]) for r in results), "Replicated skills match each character's own evidence")
    check(abs(sum(r["pre_naming"] for r in results) - 188) < 0.01, "Two paid attacks, one absorption, and one shared drop must balance without duplicate rewards")
    owner = results[0]["allies"][0]["owner"]
    check(owner in {r["state"]["id"] for r in results}, "Concurrent recruitment must assign one connected character")
    check(all(r["allies"][0]["owner"] == owner for r in results), "All clients must observe the same ally ownership")
    # 24a: naming the level-1 goblin costs 37.5% of max Magicules (38 of 100), not 80.
    check(abs(sum(r["state"]["magicules"]["current"] for r in results) - 150) < 0.01, "Concurrent/repeated naming charges exactly one 38-Magicule cost")
    for result in results:
        ally = result["allies"][0]
        check(ally["name"] == "Aster" and ally["race"] == "Hobgoblin" and ally["maximum_hp"] == 60 and ally["power"] == 8, "All clients observe the same evolved ally")
        low = result["state"]["magicules"]["current"] < result["state"]["magicules"]["maximum"] * 0.25
        check(result["state"]["exhaustion"]["active"] == (result["state"]["id"] == owner and low), "Only the authoritative namer can enter recovery, and only if naming left them below 25%")
    time.sleep(0.3)
    server_stop.touch()
    saved = wait_report(server_report, lambda d: d.get("saved"))
    finish(server)
    check(saved["rejected"] >= 4, "Host must reject forged ownership and nonfinite movement")
    check(saved["state"]["players"]["host"]["inventory"]["counts"].get("gnasher_essence") == 1, "A guest cannot discard the host's inventory")
    check(all(e["id"] != "gnasher_1" for e in saved["state"]["enemies"]), "Consumed corpse must be absent from world save")

    check(saved["state"]["allies"][0]["owner"] == owner, "Disconnect must preserve allied character ownership")

    # Restart the host and reconnect both characters using their private profiles.
    port = free_port()
    reload_stop = WORK / "reload.stop"
    server, server_report = start("reloaded_host", mode="server", port=port, save=world_save, stop=reload_stop, reload="yes")
    wait_report(server_report, lambda d: d.get("ready"))
    resumed = [start(f"resumed_{i}", mode="client", port=port, identity=WORK / f"identity_{i}.json", case="resume") for i in range(2)]
    restored = [wait_report(report, lambda d: "state" in d) for _, report in resumed]
    for proc, _ in resumed:
        finish(proc)
    for before, after in zip(results, restored):
        for field in ["id", "position", "skill_ids", "slots", "skill_evidence", "inventory", "progression"]:
            check(before["state"][field] == after["state"][field], f"Reconnect must restore {field}")
        # Absorbed-vitality healing keeps ticking on the host until the character disconnects.
        hb, ha = before["state"]["health"], after["state"]["health"]
        check(all(ha[k] == hb[k] for k in ("maximum", "immunity_seconds")), "Reconnect must restore health limits")
        check(hb["current"] <= ha["current"] <= ha["maximum"], "Reconnect never loses HP; running healing may only add up to the maximum")
        check(ha["regen_left"] <= hb["regen_left"] and (ha["regen_left"] == 0 or ha["regen_rate"] == hb["regen_rate"]), "Reconnect never resets or strengthens a running heal")
        before_pool = before["state"]["magicules"]
        after_pool = after["state"]["magicules"]
        check(all(after_pool[k] == before_pool[k] for k in before_pool if k != "delay"), "Reconnect restores resource amounts and parameters")
        check(0 <= after_pool["delay"] <= before_pool["delay"], "Regeneration delay resumes without resetting")
        check(after["allies"][0]["owner"] == owner, "Ally ownership must survive host reload and character reconnect")
        check(after["state"]["exhaustion"]["active"] == before["state"]["exhaustion"]["active"], "Reconnect preserves exhaustion")
        check(after["state"]["exhaustion"]["remaining"] <= before["state"]["exhaustion"]["remaining"], "Reload never resets the recovery timer")
        check(after["allies"][0]["name"] == "Aster" and after["allies"][0]["race"] == "Hobgoblin", "Named evolution survives host restart")
        check(after["world"]["settlements"]["camp"]["wood"] == 7, "Shared settlement state must survive reload")
    # A valid character ID with an invalid credential must be rejected.
    profile = json.loads((WORK / "identity_0.json").read_text(encoding="utf-8"))
    for entry in profile.values():
        entry["credential"] = "0" * 64
    forged = WORK / "forged_profile.json"
    forged.write_text(json.dumps(profile))
    bad, bad_report = start("forged_identity", mode="client", port=port, identity=forged, case="denied")
    check(wait_report(bad_report).get("denied"), "Reconnect must verify the credential, not just the character ID")
    finish(bad)
    reload_stop.touch()
    loaded = wait_report(server_report, lambda d: d.get("saved"))
    finish(server)
    check(loaded["state"]["players"]["host"]["health"]["current"] == 77 and loaded["state"]["players"]["host"]["progression"]["level"] == 3, "Host stats and progression must survive reload")

    # 1 host + 7 simultaneous guests; an eighth guest must not be admitted.
    port = free_port()
    capacity_stop = WORK / "capacity.stop"
    guest_stop = WORK / "guests.stop"
    server, server_report = start("capacity_host", mode="server", port=port, save=WORK / "capacity_world.json", stop=capacity_stop)
    wait_report(server_report, lambda d: d.get("ready"))
    guests = [start(f"guest_{i}", mode="client", port=port, identity=WORK / f"guest_{i}_identity.json", case="capacity", stop=guest_stop) for i in range(7)]
    joined = [wait_report(report) for _, report in guests]
    check(all(r.get("joined") for r in joined) and len({r["id"] for r in joined}) == 7, "Seven guests must join with distinct characters")
    excess, excess_report = start("excess_guest", mode="client", port=port, identity=WORK / "excess_identity.json", case="denied")
    check(wait_report(excess_report).get("denied"), "A ninth total player must be rejected")
    finish(excess)
    guest_stop.touch()
    for proc, _ in guests:
        finish(proc)
    capacity_stop.touch()
    wait_report(server_report, lambda d: d.get("saved"))
    finish(server)
    for _, log, name in processes:
        log.flush()
        text = (WORK / f"{name}.log").read_text(encoding="utf-8")
        check("SCRIPT ERROR" not in text and "ERROR:" not in text, f"{name} must finish without engine/script errors")
    print(f"Network integration: {checks} checks passed; real host/clients, concurrency, reload/reconnect, forged identity, 8-player cap")
finally:
    for proc, log, _ in processes:
        if proc.poll() is None:
            proc.terminate()
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                proc.kill()
        log.close()
