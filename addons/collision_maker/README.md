# 🚀 Collision Maker Plugin for Godot 4

A powerful Godot 4 editor plugin that generates ready-to-use 3D scenes (`.tscn`) with collision shapes (`CollisionShape3D`) from `.glb`, `.gltf`, or `.obj` files with a single right-click.

---

## 🛠 Features

- **Right-Click in FileSystem Dock**:
  - `✨ Create Static Scene (Convex Shape)`: Instant 1-click creation with convex hull (ideal for props, furniture, crates, obstacles).
  - `✨ Create Static Scene (Trimesh / Concave)`: Exact 1:1 geometry collision (ideal for houses, walls, terrain).
  - `✨ Create Static Scene (Bounding Box)`: Simple bounding box (extremely lightweight).
  - `⚙️ Create Collision Scene (Custom Options...)`: Configuration dialog for body type, save path, and simplification.
- **Batch Processing**: Select multiple `.glb` files at once in the FileSystem – the plugin converts all of them simultaneously!
- **Inspector Integration**: When a `MeshInstance3D` is selected, a button *"✨ Collision Maker: Save as Scene..."* appears at the top of the Inspector.
- **Tools Menu**: Also accessible via `Project -> Tools -> Collision Maker...`.
- **Clean Scene References**: The generated `.tscn` preserves inherited links to the original GLB. When you update and re-export the model from Blender, the scene updates automatically!

---

## 📥 Installation into your Project

1. Copy the folder `addons/collision_maker` into your project's `addons/` directory.
   - Your project structure should look like this:
     ```
     YourGodotProject/
     └── addons/
         └── collision_maker/
             ├── plugin.cfg
             ├── collision_maker_plugin.gd
             ├── collision_generator.gd
             ├── collision_context_menu.gd
             ├── collision_inspector_plugin.gd
             └── collision_dialog.gd
     ```
2. Open your project in Godot.
3. Go to **Project -> Project Settings**.
4. Switch to the **Plugins** tab (top right of the dialog).
5. Check **Enable** next to **Collision Maker**.

---

## 💡 How to Use

### Method 1: Right-Click on GLB File (Recommended)
1. In the **FileSystem Dock** (bottom left), right-click on a `.glb`, `.gltf`, or `.obj` file.
2. Choose one of the options:
   - `✨ Create Static Scene (Convex Shape)`
   - `✨ Create Static Scene (Trimesh / Concave)`
   - `✨ Create Static Scene (Bounding Box)`
3. Done! The generated `.tscn` file is created in the same folder and ready to drag into your world!

### Method 2: Inspector
1. Select any `MeshInstance3D` in your scene.
2. Click *"✨ Collision Maker: Save as Scene..."* at the top of the **Inspector**.
3. Configure options and click *"Generate Scene"*.

---

## 🔍 When to Choose Which Collision Type?

- **Convex Polygon**: Best balance of performance and fidelity. Default for everything without hollow interiors or doorways.
- **Trimesh / Concave**: Perfect for static level geometry, houses with interiors, bridges, caves. *(Note: Trimesh is only supported for StaticBody3D, not RigidBody3D).*
- **Bounding Box**: Fastest option, useful for small decorative items or distant background props.
