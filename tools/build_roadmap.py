"""Generate a portable, interactive roadmap from the project's living Markdown."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "ROADMAP.md").read_text(encoding="utf-8")
rows = re.findall(r"^\| ([^|]+) \| (Done|Next|Planned) \| ([^|]+) \| ([^|]+) \|$", source.split("## Current milestone tasks")[0], re.M)
ids = ["brief", "engine", "roadmap", "install", "project", "movement", "validation"]
dependencies = [[], ["brief"], ["brief", "engine"], ["engine"], ["install"], ["project"], ["movement"]]
purposes = [
    "Establish the world rules and core loop so implementation serves a coherent game.",
    "Use Godot 4 and GDScript to build and validate the 2D game with a lightweight toolchain.",
    "Keep priorities, dependencies, and completion evidence visible to both collaborators.",
    "Make a compatible, pinned Godot executable available before creating engine-dependent files.",
    "Provide the project settings and scene entry point that all gameplay systems will use.",
    "Establish movement, camera, input, and pixel rendering before adding real-time combat.",
    "Prove the foundation runs and capture installation and startup steps for future cloud tasks.",
]
titles = ["Game design brief", "Godot + GDScript", "Living roadmap", "Install Godot", "Godot project", "Movement + pixel setup", "Validate foundation"]
positions = [(300, 30), (155, 145), (445, 145), (155, 260), (155, 375), (155, 490), (155, 605)]
if len(rows) != len(ids):
    raise ValueError("Foundation tasks changed: update the graph task mapping before generating.")
nodes = []
for i, row in enumerate(rows):
    task, status, prerequisite, evidence = (s.strip() for s in row)
    x, y = positions[i]
    nodes.append(dict(id=ids[i], title=titles[i], status=status.lower(), deps=dependencies[i],
                      what=task, why=purposes[i], evidence=evidence, x=x, y=y, phase="Foundation"))
combat_rows = re.findall(r"^\| ([^|]+) \| (Done|Next|Planned) \| ([^|]+) \| ([^|]+) \|$", source.split("## Current milestone tasks")[1].split("## Milestones")[0], re.M)
combat_ids = ["combat", "magicules", "drops", "absorption", "skill_ui"]
combat_deps = [["validation"], ["validation"], ["combat", "magicules"], ["drops"], ["absorption"]]
combat_titles = ["Combat + first enemy", "Magicules + regeneration", "Difficulty-based drops", "Absorption + analysis", "Skill hotbar + storage"]
ally_rows = re.findall(r"^\| ([^|]+) \| (Done|Next|Planned) \| ([^|]+) \| ([^|]+) \|$", source.split("## Ally progression tasks")[1].split("## Settlement tasks")[0], re.M)
if len(ally_rows) != 2:
    raise ValueError("Ally progression mapping changed.")
for i, (task, status, prerequisite, evidence) in enumerate(ally_rows):
    nodes.append(dict(id=["recruitment", "naming_evolution"][i], title=["Recruit the first ally", "Naming + evolution + recovery"][i], status=status.lower(), deps=[["network_saves"], ["recruitment"]][i], what=task.strip(), why=["Build relationships and persistent character-owned citizens before naming and settlement roles.", "Balance evolved allies against the namer's finite Magicules, with recovery that survives saves and reconnects."][i], evidence=evidence.strip(), x=300, y=1410+i*115, phase="M2"))
camp_rows = re.findall(r"^\| ([^|]+) \| (Done|Next|Planned) \| ([^|]+) \| ([^|]+) \|$", source.split("## Settlement tasks")[1].split("## M4 proposed steps")[0], re.M)
if len(camp_rows) != 3:
    raise ValueError("Settlement task mapping changed.")
for i, (task, status, prerequisite, evidence) in enumerate(camp_rows):
    nodes.append(dict(id=["first_camp", "ally_work", "camp_growth"][i], title=["Found camp + build first hut", "Ally work assignments", "Exploration + camp growth"][i], status=status.lower(), deps=[["M2"], ["first_camp"], ["ally_work"]][i], what=task.strip(), why=["Give evolved allies a persistent home and introduce shared finite resources and construction costs.", "Make citizens contribute through explicit saved roles before expanding the economy.", "Connect adventuring and settlement production into a complete playable growth loop."][i], evidence=evidence.strip(), x=300, y=1755+i*115, phase="M3"))
m4_rows = re.findall(r"^\| ([^|]+) \| (Done|Next|Planned) \| ([^|]+) \| ([^|]+) \|$", source.split("## M4 proposed steps")[1].split("## Update contract")[0], re.M)
if len(m4_rows) != 13:
    raise ValueError("M4 proposal mapping changed.")
for i, (task, status, prerequisite, evidence) in enumerate(m4_rows):
    mid = "m4_approval" if i == 0 else "m4_" + task.split()[0]
    deps = ["M3"] if i == 0 else ["m4_approval" if d.strip() == "Approve M4 plan" else "m4_" + d.strip() for d in prerequisite.split(",")]
    x = 300 if i == 0 else 155 if i <= 5 else 445 if i == 6 else 300
    y = 2215 if i == 0 else 2330 if i == 6 else 2330 + (i - 1) * 115
    nodes.append(dict(id=mid, title=task.strip(), status=status.lower(), deps=deps, what="Proposed M4 task; implementation awaits user approval. " + task.strip(), why="Build a bounded progression/presentation slice while preserving authority and old saves. See docs/M4_PLAN.md for ownership, scope and tier rules.", evidence=evidence.strip(), x=x, y=y, phase="M4 proposal"))
combat_why = ["Make encounters playable before awarding skills from defeated creatures.", "Provide the shared resource that constrains skills, absorption, and later naming.", "Reward harder encounters with larger Magicule drops while preserving full-pool overflow.", "Turn a defeated creature into analyzed properties and one learnable Common Skill.", "Let the player use acquired skills and manage their rewards; complete the core loop."]
for i, row in enumerate(combat_rows):
    task, status, prerequisite, evidence = (s.strip() for s in row)
    x, y = [(155, 720), (445, 720), (300, 835), (300, 950), (300, 1065)][i]
    nodes.append(dict(id=combat_ids[i], title=combat_titles[i], status=status.lower(), deps=combat_deps[i],
                      what=task, why=combat_why[i], evidence=evidence, x=x, y=y, phase="M1"))
if len(combat_rows) != 5:
    raise ValueError("Combat tasks changed: review the graph mapping.")
milestones = re.findall(r"### (M\d) — (.*?) · ([^\n]+)\n(.*?)(?=\n### |\n## |\Z)", source, re.S)
network = re.search(r"### N0 — (.*?) · ([^\n]+)\n(.*?)(?=\n### |\n## |\Z)", source, re.S)
if not network:
    raise ValueError("Hosted multiplayer/save foundation milestone is missing.")
network_title, network_status, network_body = network.groups()
network_bullets = re.findall(r"^- (.*)$", network_body, re.M)
nodes.append(dict(id="network_saves", title=network_title, status="next" if network_status.lower().startswith("next") else "done" if network_status.lower().startswith("done") else "planned", deps=["M1"],
                  what="\n".join(b for b in network_bullets if not b.startswith("Exit goal:")),
                  why="Host friends on the user's machine and preserve each character and shared world before deeper progression.",
                  evidence=next(b.removeprefix("Exit goal: ") for b in network_bullets if b.startswith("Exit goal:")), x=300, y=1295, phase="N0"))
why = [
    "Establish the distinctive fight → absorb → acquire → use loop before expanding progression.",
    "Turn progression into relationships, with meaningful Magicule costs and persistent evolution.",
    "Connect adventure rewards and evolved allies to a functioning camp; complete the first playable slice.",
    "Test and polish the small playable slice before scaling the simulation and content.",
    "Give settlement growth external consequences through trade, factions, and conflict.",
    "Extend a proven economy and combat loop into squad warfare and endgame progression.",
]
for index, (mid, title, status_text, body) in enumerate(milestones):
    if mid == "M0":
        continue
    number = int(mid[1:])
    bullets = re.findall(r"^- (.*)$", body, re.M)
    evidence = next((b.removeprefix("Exit goal: ") for b in bullets if b.startswith("Exit goal:")), "")
    status = "done" if status_text.lower().startswith("done") else "next" if status_text.lower().startswith("next") else "planned"
    nodes.append(dict(id=mid, title=title, status=status, deps=["skill_ui" if number == 1 else "naming_evolution" if number == 2 else "camp_growth" if number == 3 else "m4_24" if number == 4 else f"M{number-1}"],
                      what="\n".join(b for b in bullets if not b.startswith("Exit goal:")),
                      why=why[number-1], evidence=evidence, x=300, y=1180+(number-1)*115+(345 if number >= 2 else 0)+(345 if number >= 3 else 0)+(1495 if number >= 4 else 0), phase=mid))
if len(nodes) != 37:
    raise ValueError("Milestone structure changed: review the graph mapping.")
updated = re.search(r"Last updated: (.*)", source).group(1)
template = (ROOT / "tools/roadmap.template.html").read_text(encoding="utf-8")
payload = json.dumps(dict(nodes=nodes, updated=updated), ensure_ascii=False).replace("<", "\\u003c")
(ROOT / "ROADMAP.html").write_text(template.replace("__ROADMAP_DATA__", payload), encoding="utf-8", newline="\n")
print(f"Generated ROADMAP.html: {len(nodes)} nodes, {sum(len(n['deps']) for n in nodes)} dependencies")
