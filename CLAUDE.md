# Claude Code entry point

Read and follow `AGENTS.md` first. It is the shared workflow for Claude Code and Codex. Then read `docs/AI_HANDOFF.md`, `ROADMAP.md`, and `docs/MULTIPLAYER_AND_SAVES.md` before gameplay changes. Read `README.md` for controls and runnable tests; consult `docs/ART_REFERENCES.md` and `docs/UI_REFERENCES.md` for presentation work.

Use the repository state and current user instructions as the source of truth. The handoff describes the last completed step; verify the actual branch, commits and working tree before continuing. Update the shared handoff and roadmap when completing a step. Keep engine/network/save invariants intact and publish each finished roadmap step on its own branch as described in `AGENTS.md`.

Before taking a critical step and before committing, check for new Codex work in the working tree, handoff and GitHub branch heads/recent commits. Discover branches with `git ls-remote --heads origin`; explicitly fetch relevant updated branches if the default fetch is restricted. Compare and account for Codex's changes before overlapping edits. Codex follows the same rule for Claude's work. Keep your completed work and next action in the shared handoff.
