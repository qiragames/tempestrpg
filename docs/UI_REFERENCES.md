# Interface direction

The user supplied a gameplay HUD reference in chat on 2026-10-12, with a dark framed pixel-art layout, gold trim, parchment objectives, and cyan assistant accents. Treat it as the project's interface direction, not proof that the shown gameplay systems exist.

## Layout

- Top left: portrait, name/race/role, HP, Magicules, and eventually progression information.
- Top right: region title, clock, circular minimap, and compass.
- Right: parchment quest panel and cyan internal-assistant analysis panel.
- Bottom center: skill hotbar with key hints, cooldowns, item slots, and resource feedback.
- Bottom left: System Voice and combat event log.

The current prototype has health, Magicules, combat feedback, and controls. Quests, experience, clock, minimap, assistant analysis, skill inventory, and item systems remain unimplemented. Only display live values for implemented systems; introduce later panels with their actual gameplay feature.

## Asset preparation

Separate transparent PNGs or a documented atlas will make the reference implementable: panel/frame pieces, bar backgrounds/fills, icons, portraits, hotbar slot states, and minimap/compass decoration. Prefer scalable frame pieces where possible. Keep names, numbers, labels, notifications, and key hints out of baked textures so Godot can update and localize them. Retain readable pixel sizes at the provisional 480 × 320 viewport and test gameplay visibility.

The source reference image is in the conversation, not imported into this repository. The user offered separate elements and plans to supply title-screen and pause-menu propositions. Those menus have not been designed or implemented yet; incorporate the new references when received.

Implement the acquired-skill hotbar during M1 and broader visual polish during M4. A title screen and pause menu can be planned as a separate usability step once their references arrive. Basic combat input must remain available beneath noninteractive HUD panels.
