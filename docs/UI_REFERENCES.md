# Interface direction

The user supplied a gameplay HUD reference in chat on 2026-10-12, with a dark framed pixel-art layout, gold trim, parchment objectives, and cyan assistant accents. Treat it as the project's interface direction, not proof that the shown gameplay systems exist.

## Layout

- Top left: portrait, name/race/role, HP, Magicules, and eventually progression information.
- Top right: region title, clock, circular minimap, and compass.
- Right: parchment quest panel and cyan internal-assistant analysis panel.
- Bottom center: skill hotbar with key hints, cooldowns, item slots, and resource feedback.
- Bottom left: System Voice and combat event log.

The current prototype has health, Magicules, combat feedback, and controls. Quests, experience, clock, minimap, experience/quest/time/minimap systems remain unimplemented. Analysis, acquired-skill slots, and a dimensional material bag now have prototype UI; equipment and usable items remain unimplemented. Only display live values for implemented systems; introduce later panels with their actual gameplay feature.

## Asset preparation

Separate transparent PNGs or a documented atlas will make the reference implementable: panel/frame pieces, bar backgrounds/fills, icons, portraits, hotbar slot states, and minimap/compass decoration. Prefer scalable frame pieces where possible. Keep names, numbers, labels, notifications, and key hints out of baked textures so Godot can update and localize them. Retain readable pixel sizes at the provisional 480 × 320 viewport and test gameplay visibility.

The source reference images are in the conversation, not imported into this repository. The user offered separate elements. Title-screen, pause-menu, and inventory propositions are described below. The material bag now has a functional prototype; their complete styled layouts have not been implemented yet.

Implement the acquired-skill hotbar during M1 and broader visual polish during M4. A title screen and pause menu can be planned as a separate usability step once their references arrive. Basic combat input must remain available beneath noninteractive HUD panels.

## Title screen reference

The user also supplied a title-screen proposition on 2026-10-12: a pixel-art storm/tornado and lightning over a distant castle and forest, a large Tempest RPG logo on the right, qiragames presentation/developer credits, and a dark gold-trimmed menu on the left. A small blue slime marks selection. Proposed entries: New Game, Continue, Load Game, Settings, Credits, Quit.

Use separate backdrop, logo, menu frame, and cursor artwork if available. Render menu labels and version dynamically. Support keyboard/gamepad focus and pointer selection. Continue and Load Game require the later save system and must remain unavailable until backed by real saved data. This is an art reference, not an implemented title menu or an imported source image.

## Pause screen reference

The user's pause reference shows the gameplay HUD/world dimmed behind a large GAME PAUSED banner, a central dark gold-trimmed menu, and a right-side player/zone summary card. The slime selection marker is reused. Proposed entries: Resume, Status & Class, Inventory & Equipment, Skill Tree, Quest Log, Save / Load Game, Options, Quit to Main Menu. A bottom hint explains back/resume and choosing an entry.

When implemented, freeze gameplay physics, enemy timers, resource regeneration, pickups, and other gameplay updates while allowing pause-menu UI input. Resume should restore the previous state; returning to a main menu needs an actual title scene. Keep status, play time, currency, region, and world-level values backed by real systems. Do not copy the reference's sample character stats into the game as functional progression. Unavailable systems need clear disabled entries rather than dead buttons. Preserve focus and readable contrast on the overlay.

## Inventory reference

The user supplied a three-column inventory overlay on 2026-10-12: Equipped on the left with a character paper doll and equipment slots; Bag in the middle with item stacks, currency, and capacity; Item Details on the right with icon, rarity, description, stats, and Equip/Discard actions. Category tabs: All, Gear, Usables, Materials, Quest Items. Dark panels, gold trim, purple accents, selection borders, and a close button match the other references.

Start with actual absorbed materials and readable item details in a small dimensional-storage panel. Introduce equipment, usable items, rarity, currency, capacity, and quest-item tabs only alongside their real gameplay systems. Keep all counts and details data-driven; the reference's items, sample currency, stats, and player are examples rather than starting inventory. Full equipment and paper-doll UI belongs to a later inventory/equipment step. Preserve keyboard navigation and dynamic text, and pause gameplay while a modal inventory is open.
