# Published-work watcher

`python3 tools/claude_watcher.py` checks origin every ten minutes for published
`claude/` and `codex/` branch changes. Windows: use `python` instead of `python3`.
It prints the status-page path at startup. Open that HTML file in a browser;
it refreshes every 30 seconds. Each changed branch gets a readable handoff
snapshot at its fetched commit. The first check records a baseline; subsequent
checks record updates, new branches and deletions. Repeated checks do not repeat events.

The watcher fetches into private `refs/claude-watcher/` refs. It does not switch
branches, edit the working tree, merge, run downloaded code or push anything.
Detection means **awaiting review**, never tested/approved. It monitors commits
and handoffs published to GitHub, not Claude's local uncommitted work.

Run one watcher per state directory. Stop the foreground process with Ctrl+C.
For a single check: `python3 tools/claude_watcher.py --once`.
Use `--interval 600` to change the interval (minimum ten seconds), and
`--state-dir /path/to/local/status` to choose where local state lives. Default
state is outside the repository in the machine's temporary directory. Do not
commit state or handoff snapshots. Failed checks retain the last successful
baseline and retry; check the page's last-success timestamp for stale results.

The cloud copy runs only while its execution machine remains active. Keeping
the app open does not guarantee the machine stays alive. This is a Git monitor,
not a recurring ChatGPT task: it cannot wake an idle conversation, send chat
notifications, perform a code review, or publish review acknowledgments.
Codex and Claude should read its changed-branch events when starting work,
then follow `docs/AI_HANDOFF.md` for actual review and acknowledgment.

Checks: `python3 tests/claude_watcher.py` exercises a real disposable Git remote,
handoff updates, repeat suppression, new/deleted branches, failed access,
working-tree preservation and HTML escaping.
