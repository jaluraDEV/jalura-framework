# 🐾 Player Controller & Locomotion

> **Main Coordinator:** [`scenes/player.tscn`](file:///c:/Users/janlu/Desktop/projekte/jalura_framework/scenes/player.tscn) with [`scripts/player/player.gd`](file:///c:/Users/janlu/Desktop/projekte/jalura_framework/scripts/player/player.gd) (`class_name Player`)  
> **Base Type:** `CharacterBody3D` (Godot 4 Jolt Physics)  
> **Architecture:** Clean coordinator with 9 modularized sub-components in [`scripts/player/`](file:///c:/Users/janlu/Desktop/projekte/jalura_framework/scripts/player/)  
> **Game Feel:** Responsive, tight platformer movement featuring 15 locomotion states, coyote time, jump buffering, stair step climbing, dynamic foot IK, and rail grinding.

---

## 🧭 1. Overview & Component Architecture

`player.gd` acts as the **central coordinator**: It captures inputs, drives the 15-state state machine, handles physics phases, and delegates specialized capabilities to 9 focused child components.

```mermaid
graph TD
    subgraph Coordinator ["player.gd (CharacterBody3D)"]
        StateMach["State Machine : 15 States"]
        PhysicsProc["_physics_process : 7 Phases"]
        APIContract["Public API Contract"]
    end

    subgraph Locomotion & Environment ["scripts/player/"]
        StepClimber["PlayerStepClimber (Stairs & Ledges)"]
        FootIK["PlayerFootIK (Dynamic Foot Planting)"]
        WaterHazard["PlayerWaterHazard (Water & Shore Respawn)"]
    end

    subgraph Visuals, Camera & Animation ["scripts/player/"]
        CameraRig["PlayerCameraRig (SpringArm & Dither Fade)"]
        Animator["PlayerAnimator (AnimationTree & States)"]
        Equipment["PlayerEquipment (Flashlight, Glider, Shoes)"]
    end

    subgraph Feedback & World Interaction ["scripts/player/"]
        Audio["PlayerAudio (3D-SFX, Steps, Grind Loop)"]
        Effects["PlayerEffects (Particles, Dust, Squash & Stretch)"]
        Interaction["PlayerInteraction (Proximity Scanner & Bump Push)"]
    end

    PhysicsProc --> StepClimber
    PhysicsProc --> FootIK
    PhysicsProc --> WaterHazard
    PhysicsProc --> CameraRig
    PhysicsProc --> Animator
    PhysicsProc --> Equipment
    PhysicsProc --> Audio
    PhysicsProc --> Effects
    PhysicsProc --> Interaction
```

### The 9 Modular Components

| Component | Script | Type | Core Responsibility |
| :--- | :--- | :---: | :--- |
| **`PlayerStepClimber`** | [`scripts/player/player_step_climber.gd`](file:///c:/Users/janlu/Desktop/projekte/jalura_framework/scripts/player/player_step_climber.gd) | `Node` | Dual raycast stair probing and smooth step climbing up to 0.42 m without physics snagging. |
| **`PlayerFootIK`** | [`scripts/player/player_foot_ik.gd`](file:///c:/Users/janlu/Desktop/projekte/jalura_framework/scripts/player/player_foot_ik.gd) | `Node` | Drives two `SkeletonIK3D` nodes on the character legs to plant feet onto slopes and stairs. |
| **`PlayerWaterHazard`** | [`scripts/player/player_water_hazard.gd`](file:///c:/Users/janlu/Desktop/projekte/jalura_framework/scripts/player/player_water_hazard.gd) | `Node` | Monitors water boundaries, manages ocean surface level, and teleports player safely to shore. |
| **`PlayerCameraRig`** | [`scripts/player/player_camera_rig.gd`](file:///c:/Users/janlu/Desktop/projekte/jalura_framework/scripts/player/player_camera_rig.gd) | `Node` | Manages `$CameraPivot`, SpringArm orbit, dynamic FOV, and proximity dither alpha fade. |
| **`PlayerAudio`** | [`scripts/player/player_audio.gd`](file:///c:/Users/janlu/Desktop/projekte/jalura_framework/scripts/player/player_audio.gd) | `Node3D` | Positional 3D audio on `&"SFX"` bus; cadence-based footsteps (grass/wood/stone), jump calls, grind loop. |
| **`PlayerEffects`** | [`scripts/player/player_effects.gd`](file:///c:/Users/janlu/Desktop/projekte/jalura_framework/scripts/player/player_effects.gd) | `Node3D` | 3D particle dust puffs (step, jump, land, skid, dash) and harmonic spring squash & stretch. |
| **`PlayerAnimator`** | [`scripts/player/player_animator.gd`](file:///c:/Users/janlu/Desktop/projekte/jalura_framework/scripts/player/player_animator.gd) | `Node` | Animation playback, state-to-animation mapping, and directional blend spaces. |
| **`PlayerEquipment`** | [`scripts/player/player_equipment.gd`](file:///c:/Users/janlu/Desktop/projekte/jalura_framework/scripts/player/player_equipment.gd) | `Node` | BoneAttachments for tools, glider visual attachment, and automatic inventory synchronization. |
| **`PlayerInteraction`** | [`scripts/player/player_interaction.gd`](file:///c:/Users/janlu/Desktop/projekte/jalura_framework/scripts/player/player_interaction.gd) | `Node` | 2.8 m proximity prompt scanner, HUD prompt updates, bump-push interaction, and celebrations. |

---

## ⏱️ 2. Physics Process Flow (`_physics_process`)

The physics loop runs in 7 deterministic stages:

```gdscript
func _physics_process(delta: float) -> void:
    # 1. Early exits & hazards
    if _process_water(delta):
        return

    # 2. Ground detection & landings
    var on_floor := _process_ground_detection(delta)

    # 3. Input buffers (coyote time, jump buffer, dash buffer)
    _process_jump_and_buffers(delta)

    # 4. Input reading & air actions
    var input_data := _process_input_and_movement(delta, on_floor)

    # 5. State machine resolution
    if _process_state(delta, on_floor, input_data):
        return

    # 6. Physics execution (Step climbing on ground vs move_and_slide in air)
    _process_step_and_physics(delta)

    # 7. Procedural feedback, IK, pushables & animations
    _process_juice(delta, input_data["is_running"])
```

---

## 📜 3. Public API Contract

External systems (world objects, UI, cutscenes, triggers) interface with `Player` through a clean API:

### Methods

| Signature | Caller | Description |
| :--- | :--- | :--- |
| `bounce(force: float, forward_boost: float, is_super: bool)` | Trampolines, Jump Pads | Catapults player upward/forward and transitions into `State.JUMP`. |
| `set_camera_fade_enabled(enabled: bool)` | `SceneTransition`, `DioramaCamera3D` | Enables or disables dither proximity fade. |
| `toggle_flashlight()` | Input, Inventory, UI | Toggles the handheld flashlight on/off. |
| `has_glider() -> bool` | Overworld, Air logic | Returns whether the glider tool is unlocked/equipped. |
| `has_rail_shoes() -> bool` | Rails, Air logic | Returns whether grind shoes are equipped. |

### State Enum (`Player.State`)

The controller transitions cleanly across 15 states:
`IDLE`, `WALK`, `BRAKE`, `JUMP`, `FALL`, `CROUCH`, `CRAWL`, `DASH`, `SPIN`, `BACKFLIP`, `LONG_JUMP`, `AIR_DIVE`, `DIVE_SLIDE`, `GLIDE`, `RAIL_GRIND`.

---

## 🛠️ 4. Inspector Tuning Guide

All movement tuning parameters are exposed as `@export` variables in the Inspector on [`scenes/player.tscn`](file:///c:/Users/janlu/Desktop/projekte/jalura_framework/scenes/player.tscn):

### 1. Motion & Jump
- **Walk & Run Speed:** `walk_speed` (`5.0 m/s`), `run_speed` (`7.5 m/s`), `acceleration` (`14.0`), `friction` (`22.0`).
- **Jump & Gravity:** `jump_velocity` (`5.8 m/s`), `min_jump_velocity` (`2.9 m/s`), `gravity` (`19.0 m/s²`), `fall_gravity` (`26.0 m/s²`).
- **Buffers:** `coyote_timer` (`0.15s`), `jump_buffer_timer` (`0.15s`).

### 2. Acrobatic Maneuvers
- **Dash:** `dash_force` (`14.5 m/s`), `dash_duration` (`0.32s`), `allowed_air_dashes` (`1`).
- **Spin Attack:** `spin_duration` (`0.44s`), `air_spin_lift` (`5.8 m/s`), `allowed_air_spins` (`1`).
- **Long Jump:** `long_jump_velocity` (`4.5 m/s`), `long_jump_forward_boost` (`11.5 m/s`), `long_jump_gravity` (`16.5 m/s²`). Triggered by `Crouch + Jump while sprinting`.
- **Backflip:** `backflip_jump_velocity` (`9.2 m/s`), `backflip_gravity` (`21.0 m/s²`), `backflip_turn_force` (`6.5 m/s`). Triggered by `Brake + Jump`.

### 3. Equipment & Gadgets
- **Glider:** `glider_speed` (`6.8 m/s`), `glider_gravity` (`3.5 m/s²`), `glider_max_fall_speed` (`2.2 m/s`). Hold `[Space]` in mid-air.
- **Rail Grinding:** `rail_grind_min_speed` (`6.0 m/s`), `rail_grind_max_speed` (`14.0 m/s`), `rail_grind_downhill_accel` (`8.0`), `rail_snap_distance` (`1.2m`). Jump onto any `Rail3D` path.

### 4. Stairs & Steps
- Configured in `PlayerStepClimber`: `max_step_height` (`0.42m`), `step_smooth_speed` (`22.0`), `floor_max_angle` (`58.0°`). Allows seamless walking up curbs and stairs without collision snagging.
