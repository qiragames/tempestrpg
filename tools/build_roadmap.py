"""Generate a portable, interactive roadmap from the project's living Markdown."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
source = (ROOT / "ROADMAP.md").read_text()
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
combat_why = ["Make encounters playable before awarding skills from defeated creatures.", "Provide the shared resource that constrains skills, absorption, and later naming.", "Reward harder encounters with larger Magicule drops while preserving full-pool overflow.", "Turn a defeated creature into analyzed properties and one learnable Common Skill.", "Let the player use acquired skills and manage their rewards; complete the core loop."]
for i, row in enumerate(combat_rows):
    task, status, prerequisite, evidence = (s.strip() for s in row)
    x, y = [(155, 720), (445, 720), (300, 835), (300, 950), (300, 1065)][i]
    nodes.append(dict(id=combat_ids[i], title=combat_titles[i], status=status.lower(), deps=combat_deps[i],
                      what=task, why=combat_why[i], evidence=evidence, x=x, y=y, phase="M1"))
if len(combat_rows) != 5:
    raise ValueError("Combat tasks changed: review the graph mapping.")
milestones = re.findall(r"### (M\d) — (.*?) · ([^\n]+)\n(.*?)(?=\n### |\n## |\Z)", source, re.S)
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
    nodes.append(dict(id=mid, title=title, status=status, deps=["skill_ui" if number == 1 else f"M{number-1}"],
                      what="\n".join(b for b in bullets if not b.startswith("Exit goal:")),
                      why=why[number-1], evidence=evidence, x=300, y=1180+(number-1)*115, phase=mid))
if len(nodes) != 18:
    raise ValueError("Milestone structure changed: review the graph mapping.")
updated = re.search(r"Last updated: (.*)", source).group(1)
template = (ROOT / "tools/roadmap.template.html").read_text()
payload = json.dumps(dict(nodes=nodes, updated=updated), ensure_ascii=False).replace("<", "\\u003c")
(ROOT / "ROADMAP.html").write_text(template.replace("__ROADMAP_DATA__", payload))
print(f"Generated ROADMAP.html: {len(nodes)} nodes, {sum(len(n['deps']) for n in nodes)} dependencies")
