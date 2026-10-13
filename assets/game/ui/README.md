# Prepared UI frames, font and icons

Step 18 (asset preparation). Copied unchanged from the third-party packs in `assets/source/packs/` by `tools/prepare_assets.py`; previews (x3, nearest) in `docs/asset_previews/`. **Status: partly integrated in step 21:** material icons (`icons/essence.png`, `icons/quill.png`; wood/stone/essence for camp resources) and all 60 gear icons are shown in the bag and equipment window via `scripts/ui/ui_style.gd`. The dialog frames are light-coloured and do not match the dark/gold reference, so panels use code-drawn frames instead; `font_normal.ttf` breaks at 8–11 px and is not used. Hearts, mini life bars, coins and the money bag remain available for later steps.

Pixel scale 1:1 with the 640x360 viewport; nearest filtering (project default). Foot pivot: bottom-centre of each frame unless noted.

| File | Size | Frames / layout | Source |
| --- | --- | --- | --- |
| `dialog_box.png` | 300x58 | Dialog/panel frame (9-slice) | `assets/source/packs/ninja_adventure/Ui/Dialog/DialogBox.png` |
| `dialog_box_faceset.png` | 300x58 | Dialog with portrait slot | `assets/source/packs/ninja_adventure/Ui/Dialog/DialogBoxFaceset.png` |
| `choice_box.png` | 64x20 | Menu/choice frame | `assets/source/packs/ninja_adventure/Ui/Dialog/ChoiceBox.png` |
| `faceset_box.png` | 48x48 | Portrait frame | `assets/source/packs/ninja_adventure/Ui/Dialog/FacesetBox.png` |
| `heart.png` | 80x16 | HP heart icon | `assets/source/packs/ninja_adventure/Ui/Receptacle/Heart.png` |
| `lifebar_mini_under.png` | 18x4 | Small bar background (enemy HP) | `assets/source/packs/ninja_adventure/Ui/Receptacle/LifeBarMiniUnder.png` |
| `lifebar_mini_progress.png` | 18x4 | Small bar fill (enemy HP) | `assets/source/packs/ninja_adventure/Ui/Receptacle/LifeBarMiniProgress.png` |
| `font_normal.ttf` | — | Pixel font (CC0) | `assets/source/packs/ninja_adventure/Ui/Font/NormalFont.ttf` |
| `icons/sword.png` | 6x17 | Weapon icon: sword | `assets/source/packs/ninja_adventure/Items/Weapons/Sword/Sprite.png` |
| `icons/bow.png` | 15x7 | Weapon icon: bow | `assets/source/packs/ninja_adventure/Items/Weapons/Bow/Sprite.png` |
| `icons/chest_closed.png` | 32x16 | Chest (closed) | `assets/source/packs/ninja_adventure/Items/Treasure/LittleTreasureChest.png` |
| `icons/chest_big.png` | 32x14 | Chest (big) | `assets/source/packs/ninja_adventure/Items/Treasure/BigTreasureChest.png` |
| `icons/bag.png` | 16x16 | Bag / storage icon | `assets/source/packs/ninja_adventure/Items/Object/Bag.png` |
| `icons/money_bag.png` | 14x15 | Currency (M4.5) | `assets/source/packs/ninja_adventure/Items/Object/MoneyBag.png` |
| `icons/coin_gold.png` | 7x7 | Currency coin (M4.5) | `assets/source/packs/ninja_adventure/Items/Treasure/GoldCoin.png` |
| `icons/wood.png` | 16x16 | Camp resource: wood | `assets/source/packs/ninja_adventure/Items/Resource/Branch.png` |
| `icons/stone.png` | 16x16 | Camp resource: stone | `assets/source/packs/ninja_adventure/Items/Resource/Rock.png` |
| `icons/essence.png` | 16x16 | Camp resource: essence / Gnasher Essence | `assets/source/packs/ninja_adventure/Items/Resource/GemGreen.png` |
| `icons/quill.png` | 16x16 | Thornback Quill | `assets/source/packs/ninja_adventure/Items/Resource/feather.png` |
| `icons/bar_iron.png` | 16x15 | Forge material (later recipes) | `assets/source/packs/ninja_adventure/Items/Resource/BarIron.png` |
| `icons/gear/cloth_hood_0.png` | 16x16 | cloth_hood: rarity 0..4 = Kyrise variants a..e (CC BY 4.0, credit Kyrise) | `assets/source/packs/kyrise_icons/icons/16x16/hat_01a..e.png` |
| `icons/gear/iron_helm_0.png` | 16x16 | iron_helm: rarity 0..4 = Kyrise variants a..e (CC BY 4.0, credit Kyrise) | `assets/source/packs/kyrise_icons/icons/16x16/helmet_01a..e.png` |
| `icons/gear/padded_vest_0.png` | 16x16 | padded_vest: rarity 0..4 = Kyrise variants a..e (CC BY 4.0, credit Kyrise) | `assets/source/packs/kyrise_icons/icons/16x16/armor_01a..e.png` |
| `icons/gear/scale_mail_0.png` | 16x16 | scale_mail: rarity 0..4 = Kyrise variants a..e (CC BY 4.0, credit Kyrise) | `assets/source/packs/kyrise_icons/icons/16x16/armor_01a..e.png` |
| `icons/gear/leather_gloves_0.png` | 16x16 | leather_gloves: rarity 0..4 = Kyrise variants a..e (CC BY 4.0, credit Kyrise) | `assets/source/packs/kyrise_icons/icons/16x16/gloves_01a..e.png` |
| `icons/gear/travel_boots_0.png` | 16x16 | travel_boots: rarity 0..4 = Kyrise variants a..e (CC BY 4.0, credit Kyrise) | `assets/source/packs/kyrise_icons/icons/16x16/boots_01a..e.png` |
| `icons/gear/copper_ring_0.png` | 16x16 | copper_ring: rarity 0..4 = Kyrise variants a..e (CC BY 4.0, credit Kyrise) | `assets/source/packs/kyrise_icons/icons/16x16/ring_01a..e.png` |
| `icons/gear/spirit_amulet_0.png` | 16x16 | spirit_amulet: rarity 0..4 = Kyrise variants a..e (CC BY 4.0, credit Kyrise) | `assets/source/packs/kyrise_icons/icons/16x16/necklace_01a..e.png` |
| `icons/gear/iron_sword_0.png` | 16x16 | iron_sword: rarity 0..4 = Kyrise variants a..e (CC BY 4.0, credit Kyrise) | `assets/source/packs/kyrise_icons/icons/16x16/sword_01a..e.png` |
| `icons/gear/hunting_bow_0.png` | 16x16 | hunting_bow: rarity 0..4 = Kyrise variants a..e (CC BY 4.0, credit Kyrise) | `assets/source/packs/kyrise_icons/icons/16x16/bow_01a..e.png` |
| `icons/gear/field_scythe_0.png` | 16x16 | field_scythe: cell 14,10; rarity 0..4 = bronze, iron, steel, gold, gold (Shade, free incl. commercial, no credit needed) | `assets/source/packs/shade_weapons/16x16 Weapons RPG Icons/iron-weapons.png` |
| `icons/gear/ash_spear_0.png` | 16x16 | ash_spear: cell 16,0; rarity 0..4 = bronze, iron, steel, gold, gold (Shade, free incl. commercial, no credit needed) | `assets/source/packs/shade_weapons/16x16 Weapons RPG Icons/iron-weapons.png` |

Licences and credits: see `CREDITS.md` at the repository root and the licence files next to each pack in `assets/source/packs/`.
