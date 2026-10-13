#!/usr/bin/env python3
"""Poll published Git heads and preserve handoffs without changing the checkout."""
import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import subprocess
import tempfile
import time
from datetime import datetime, timezone


def now():
    return datetime.now(timezone.utc).isoformat(timespec="seconds")


def git(repo, *args):
    result = subprocess.run(["git", "-C", str(repo), *args], capture_output=True,
                            text=True, timeout=90, env={**os.environ, "GIT_TERMINAL_PROMPT": "0"})
    if result.returncode:
        # Never copy remote URLs, credential-helper output or private Git errors to the page.
        raise RuntimeError(f"Git operation failed ({args[0]}, exit {result.returncode}); check repository access.")
    return result.stdout


def write(path, value):
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(value, encoding="utf-8")
    temporary.replace(path)


def render(state, directory):
    events = state.get("events", [])
    rows = "".join("<tr><td>" + "</td><td>".join(html.escape(str(event[key]))
                      for key in ["time", "branch", "change", "commit"]) + "</td></tr>"
                   for event in reversed(events))
    handoffs = "".join(f'<li><a href="handoffs/{html.escape(filename)}">{html.escape(branch)}</a></li>'
                       for branch, filename in sorted(state.get("handoffs", {}).items()))
    page = f'''<!doctype html><html><head><meta charset="utf-8">
<meta http-equiv="refresh" content="30"><title>TempestRPG · Claude watcher</title>
<style>body{{background:#101923;color:#deedf1;font:16px system-ui;max-width:1100px;margin:40px auto;padding:20px}}a{{color:#8be1dc}}td,th{{padding:10px;text-align:left;border-bottom:1px solid #354353}}table{{width:100%}}small{{color:#a6bcc6}}</style></head><body>
<h1>Claude watcher</h1><p>{html.escape(state.get("status", "Starting"))}</p>
<p>Last attempt: {html.escape(state.get("last_attempt", "Never"))}<br>
Last successful check: {html.escape(state.get("last_success", "Never"))}</p>
<small>All times UTC. Checks every {state.get("interval", 600)} seconds; page refreshes every 30 seconds.
Published changes are awaiting review. Detection does not mean tested, approved or merged.</small>
<h2>Published changes</h2><table><tr><th>Detected</th><th>Branch</th><th>Change</th><th>Commit</th></tr>{rows}</table>
<h2>Latest handoff snapshots</h2><ul>{handoffs}</ul></body></html>'''
    write(directory / "status.html", page)
    write(directory / "state.json", json.dumps(state, indent=2))


def poll(repo, directory, state):
    state["last_attempt"] = now()
    try:
        output = git(repo, "ls-remote", "--heads", "origin")
        heads = {ref.removeprefix("refs/heads/"): sha for sha, ref in
                 (line.split() for line in output.splitlines())
                 if ref.startswith(("refs/heads/claude/", "refs/heads/codex/"))}
        previous = state.get("heads")
        changed = {branch: sha for branch, sha in heads.items()
                   if previous is None or previous.get(branch) != sha}
        if changed:
            specs = [f"+refs/heads/{branch}:refs/claude-watcher/{branch}" for branch in changed]
            git(repo, "fetch", "--no-tags", "--no-write-fetch-head", "origin", *specs)
        snapshots = directory / "handoffs"
        snapshots.mkdir(exist_ok=True)
        for branch, sha in changed.items():
            # A branch may advance during fetch. Capture only the exact fetched revision.
            fetched = git(repo, "rev-parse", f"refs/claude-watcher/{branch}").strip()
            heads[branch] = fetched
            filename = hashlib.sha256(branch.encode()).hexdigest()[:16] + ".txt"
            try:
                handoff = git(repo, "show", f"{fetched}:docs/AI_HANDOFF.md")
            except RuntimeError:
                handoff = "No docs/AI_HANDOFF.md at this commit."
            write(snapshots / filename, f"Branch: {branch}\nCommit: {fetched}\nDetected: {now()}\n\n{handoff}")
            state.setdefault("handoffs", {})[branch] = filename
            if previous is not None:
                state.setdefault("events", []).append({"time": now(), "branch": branch,
                    "change": "new branch" if branch not in previous else "updated; awaiting review",
                    "commit": fetched})
        if previous is not None:
            for branch in previous.keys() - heads.keys():
                state.setdefault("events", []).append({"time": now(), "branch": branch,
                    "change": "deleted", "commit": previous[branch]})
                state.setdefault("handoffs", {}).pop(branch, None)
        state["heads"] = heads
        state["events"] = state.get("events", [])[-200:]
        state["last_success"] = now()
        state["status"] = f"Watching {len(heads)} branches. {len(changed)} changed this check." if previous is not None else f"Baseline recorded: {len(heads)} branches."
    except (RuntimeError, subprocess.TimeoutExpired, OSError):
        state["status"] = "Check failed; retaining last successful baseline. Check GitHub access or connectivity. Will retry."
    render(state, directory)
    print(f'{state["last_attempt"]} {state["status"]}', flush=True)
    return "Check failed" not in state["status"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", type=Path, default=Path(__file__).resolve().parents[1])
    parser.add_argument("--state-dir", type=Path)
    parser.add_argument("--interval", type=int, default=600)
    parser.add_argument("--once", action="store_true")
    args = parser.parse_args()
    if args.interval < 10:
        parser.error("--interval must be at least 10 seconds")
    repo = args.repo.resolve()
    directory = args.state_dir or Path(tempfile.gettempdir()) / ("tempestrpg-claude-watch-" + hashlib.sha256(str(repo).encode()).hexdigest()[:12])
    directory.mkdir(parents=True, exist_ok=True)
    path = directory / "state.json"
    state = json.loads(path.read_text(encoding="utf-8")) if path.exists() else {}
    state["interval"] = args.interval
    print(f"Status page: {directory / 'status.html'}", flush=True)
    try:
        while True:
            success = poll(repo, directory, state)
            if args.once:
                return 0 if success else 1
            time.sleep(args.interval)
    except KeyboardInterrupt:
        return 0


if __name__ == "__main__":
    raise SystemExit(main())
