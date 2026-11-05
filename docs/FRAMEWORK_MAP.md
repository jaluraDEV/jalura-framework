# Framework Architecture Map

Inventory and architecture roadmap for transitioning into the standalone "Jalura Framework".
Baseline: 195 GDScript files, ~33,000 lines of code, 67 scenes.

## 1. Codebase Breakdown

| Domain | Files | Lines | Share |
|---|---:|---:|---:|
| Editor Addons (`addons/`) | 24 | 7,045 | 21 % |
| World Object / Interaction System | 43 | 6,647 | 20 % |
| Game Scene Scripts (`szenen/`) | 18 | 5,411 | 16 % |
| Scratch / Debug Scripts | 65 | 5,823 | 18 % |
| Player Controller & Movement | 9 | 2,678 | 8 % |
| Core Autoload Managers | 8 | 2,381 | 7 % |
| World Tools (Scene, Spawn, Rail, Trail) | 5 | 1,573 | 5 % |
| Camera, Audio, Interactables, Components | 6 | 741 | 2 % |
| Resource Data Model (Items, Quests, World Map) | 16 | 458 | 1 % |

**Almost a fifth of the original code was disposable scratch tooling:** 65 files (`test_*`, `check_*`, `inspect_*`, `probe_*`, `capture_*`, `debug_*`, `measure_*`, `analyze_*`, `build_*`, `generate_*`, `trace_*`). These ran as one-off `SceneTree` scripts and have been cleanly excluded from the framework.

---

## 2. Modules & Architecture Decisions

### KEEP – Retained & Modularized

| Module | Files | Decision | Notes |
|---|---:|---|---|
| Editor Addons | 24 | KEEP → Renamed | Modularized editor tools into `jalura_toolkit` |
| World Object System | 43 | KEEP | Hub, 14 Behaviors, 9 Actions, 15 Prefabs, Live Validator |
| World Tools | 5 | KEEP | `world_scene`, `spawn_point`, `rail_3d`, `trail_path_3d`, `grass_exclusion_zone` |
| Camera System | 2 | KEEP | `diorama_camera_3d`, `player_camera_rig` |
| Resource Model | 16 | KEEP | `ItemData`, `QuestData`, Objectives, Conditions, `WorldMap` |
| Interactables | 3 | KEEP | `Interactable`, `DoorTrigger3D`, `LocationTrigger3D` |
| Quest Giver / Pixel Filter | 2 | KEEP | Lightweight, clean components |

### ADAPT – Decoupled from Game Logic

| Module | Files | Changes |
|---|---:|---|
| Core Managers | 8 | Generic `energy` currency, decoupled hardcoded references, configurable scene IDs |
| UI (HUD, Inventory, Options, Pause) | 4 | Generalized item & quest terminology, rights-safe fonts, theme overrides |
| Player Controller (`player.gd`) | 1 | Modularized gadgets, water interaction, and clean animation state machine |
| Player Modules | 9 | Equipment handles glider/rail shoes/flashlight via resources; decoupled sound effects |
| Celebration Stage | 1 | Modular item display without hardcoded model dependencies |

### DROP – Archived & Excluded

| Domain | Files | Rationale |
|---|---:|---|
| Scratch / Debug Scripts | 65 | One-off development tools |
| Specific Story Scene Scripts | 10 | Legacy story-specific scripts |
| Legacy Story Scenes | 30 | Old story levels, testbeds, and cutscenes |
| Specific Game Data | 13 | Legacy story quests and items |

---

## 3. Decoupling Critical Dependencies

Key points decoupled during the framework transition:

| File | Issue | Resolution |
|---|---|---|
| `scripts/core/save_manager.gd` | Hardcoded references to game-specific objects | Switched to dynamic scene traversal and group calls |
| `scripts/core/quest_manager.gd` | Procedural demo quest creation | Moved into resource files (`resources/quests/*.tres`) |
| `scripts/core/scene_transition.gd` | Hardcoded scene IDs | Resolved via dynamic `WorldMap` resource registry |
| `scripts/core/inventory_manager.gd` | "Battery" currency | Generic configurable `energy` currency attribute |
| `scenes/ui/hud.gd` | Hardcoded story strings | Data-driven titles, toast notifications, and reward text |
| `scenes/ui/inventory_menu.gd` | Specific story categories | Modular tabs: Quests, Items, Equipment |

---

## 4. Framework Directory Structure

```
addons/jalura_toolkit/     Level-design tools, asset palette, quest & world-map studio
addons/collision_maker/    1-click collision generator plugin
scripts/core/              Managers: Inventory, Quests, Save, Flags, Settings, Transitions, Camera
scripts/data/              ItemData, QuestData, Objectives, Conditions, WorldMap
scripts/interaction/       Hub, Behaviors, Actions, Prefabs, Validator
scripts/player/            Character controller, step climber, water hazard, and equipment
scripts/world/             WorldScene, SpawnPoint, Rail3D, TrailPath3D
scripts/ui/                HUD, Inventory, Options, Pause, Title Screen, Pixel Filter
scenes/objects/            Modular interactive world object prefabs
scenes/items/              Pickable 3D item scenes
scenes/ui/                 UI scenes (Title Screen, HUD, Menus)
scenes/demo/               Playable demo harbor level and interior ship cabin
assets/                    Rights-audited models, materials, textures, and shaders
docs/                      Documentation and Architecture Map
```

---

## 5. Verification Pipeline

Every development iteration must pass headless validation without errors:

1. **Class Registry Build:** `godot --headless --path . --import` then `--quit` (Exit 0).
2. **Smoke Test:** `godot --headless --path . -s res://tests/smoke_prefabs.gd` (verifies all 32 scenes instantiate cleanly).
3. **Player Physics Check:** `godot --headless --path . -s res://tests/inspect_player.gd`.
4. **UI Runtime Check:** `godot --headless --path . -s res://tests/runtime_ui.gd`.
