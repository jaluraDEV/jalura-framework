# 🎥 Modular Camera System (Inspector First)

The camera system in the **Jalura Framework** is built strictly **Inspector First**:  
As a level designer, **you** configure exactly how the camera behaves in each scene directly via the Godot Inspector (e.g. fixed diorama rail on harbor docks, full 360° orbit camera across open fields, or a static camera for interior rooms). Player controls seamlessly adapt without requiring manual settings or camera hacks.

---

## 🏛️ System Architecture

```mermaid
graph TD
    subgraph Level Design & Inspector
        Editor["Godot 3D Viewport & Inspector"] -->|camera_mode / bounds| DioCam["DioramaCamera3D Node"]
        Editor -->|3D Viewport Gizmos| Gizmo["CameraRailGizmoPlugin<br/>Cyan Rail + Amber Bounds Box"]
        DioCam -->|1-Click Presets| Presets["Harbor Pier / Cabin / Open Field / Fixed Room"]
    end

    subgraph Runtime & Camera Management
        DioCam -->|register_diorama_camera| CM["CameraManager (Autoload)"]
        Player["Player SpringArm3D"] -->|register_player| CM
        CM -->|Activates selected camera| Viewport["Godot Render Viewport"]
    end

    subgraph Player Controls (Gameplay Only)
        PlayerIn["Mouse & Right Gamepad Stick"] -->|Active only in FREE_360 mode| Player
    end
```

---

## 🎬 The Three Inspector Camera Modes

When dropping a [`DioramaCamera3D`](file:///c:/Users/janlu/Desktop/projekte/jalura_framework/scripts/camera/diorama_camera_3d.gd) into your scene, choose the mode under **🎬 Scene Camera Mode (Developer Default)**:

| Mode | Description | Typical Use Case |
| :--- | :--- | :--- |
| **`DIORAMA_RAIL`** | Smoothly follows the player along a tracking rail (e.g., X axis) with configurable clamp bounds and dynamic yaw swivel. | Docks, beaches, side-scrolling paths, town streets |
| **`FREE_360_ORBIT`** | Hands full rotation control over to the player's third-person `SpringArm3D`. The player orbits 360° using mouse or gamepad right stick. | Open outdoor zones, exploration islands, testbeds |
| **`FIXED_ROOM`** | Stays rigidly placed at the editor coordinate, looking down into the room from a fixed cinematic angle. | Small rooms, puzzle chambers, cutscenes |

---

## ⚡ 1-Click Presets for Level Designers

Under **⚡ 1-Click Presets for Developers** in the Inspector, apply standard camera configurations with a single click:

1. **`HARBOR_DOCK`**:
   - Mode: `DIORAMA_RAIL`
   - Rail: 3.5 m left, 4.0 m right
   - Smooth Lerp: `smooth_speed = 3.5`
   - Dynamic Yaw Swivel: `yaw_swivel = 1.6°/m`
2. **`SHIP_CABIN`**:
   - Mode: `DIORAMA_RAIL` (Compact)
   - Rail: X-axis only (0.65 m left/right), fixed height (rigid Y/Z)
   - Fast Snap: `smooth_speed = 5.0`
3. **`OPEN_WORLD_360`**:
   - Mode: `FREE_360_ORBIT` (Activates 360° orbit camera on the player)
4. **`FIXED_ROOM`**:
   - Mode: `FIXED_ROOM` (Rigid static camera without movement)

---

## 👁️ 3D Viewport Gizmos (Visual In-Engine Helpers)

When selecting a `DioramaCamera3D` in the Godot 3D editor, the integrated **[`CameraRailGizmoPlugin`](file:///c:/Users/janlu/Desktop/projekte/jalura_framework/addons/jalura_toolkit/modules/viewport_gizmos/camera_rail_gizmo_plugin.gd)** renders colorful helper guides directly in the viewport:

- **Cyan Rail (Line with tick marks):** Shows the exact horizontal traversal path of the camera from `max_pan_left` to `max_pan_right`.
- **Amber / Yellow Boundary Box:** Visualizes the vertical height clamps (`max_pan_up` / `down`) and lateral limits.
- **Green Focus Line:** Shows the forward target vector towards the player anchor.

---

## 🛡️ Zero Hardcoding & Relative Placement

You can freely move, elevate, or rotate the `DioramaCamera3D` anywhere in the Godot 3D viewport:
- At scene start, the camera captures its in-editor coordinate as an immutable reference point (`_base_cam_pos`).
- All rail tracking, offsets, and clamping boundaries are calculated **relative** to this base point.
- Moving the camera 10 meters in the editor maintains full rail integrity without any code changes.
