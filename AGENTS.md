# TempestRPG project workflow

- Read `ROADMAP.md` before planning or changing this project. It records the user's goals, dependencies, current state, and design constraints.
- Use Godot 4 with GDScript unless the user changes the engine decision.
- Begin with the current milestone and its nearest unmet prerequisite. Respect the user's latest request; record priority changes instead of silently dropping earlier goals.
- After meaningful project work, update `ROADMAP.md` in the same change: actual status, validation evidence, blockers, next action, and a short dated progress entry. Do not mark untested or merely planned work Done.
- After roadmap updates, run `python3 tools/build_roadmap.py` to refresh the interactive `ROADMAP.html`. If tasks or milestones change, adjust the generator mapping to preserve accurate dependencies. Keep the graphical view and Markdown consistent.
- Keep roadmap descriptions understandable to the user and distinguish implemented behavior from future design.
- The user requests a separate GitHub branch for each completed roadmap step. Create a descriptive `codex/roadmap-...` branch from the latest project state, commit all changes belonging to that step (including roadmap, docs, tests, and generated view), then push it to origin after appropriate checks pass. Carry previous completed work forward until integrated; do not reset it or push directly to main. Preserve unrelated user changes and exclude caches, secrets, and local runtime files. Do not merge branches without authorization.
- Preserve substantial Magicule costs and exhaustion risk when designing naming/evolution. Keep absorption, analysis, skill tiers, and settlement progression consistent with the supplied design brief summarized in the roadmap.
- Use modular scenes/scripts and concise comments where they explain intent. Start with a small playable slice before expanding later milestones.
- Cloud tasks already have isolated checkouts. Use the existing checkout; do not create a worktree unless the user explicitly requests one.

- The user wants to see the window used for testing. Open the actual game/browser test view when supported. This cloud session currently has no display or live desktop-sharing capability: clearly identify headless checks and do not imply the user can watch an invisible game window. Provide actual captures when a renderer/display is available, or a project package for local playtesting.
