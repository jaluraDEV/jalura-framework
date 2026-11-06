# Contributing to Jalura Framework

Thank you for your interest in contributing to the **Jalura Framework**!  
We welcome bug reports, feature suggestions, documentation improvements, and code contributions.

---

## 🛠️ Development Workflow

1. **Fork & Clone:**
   ```bash
   git clone https://github.com/your-username/jalura-framework.git
   cd jalura-framework
   ```

2. **Branching:**
   - Create a feature branch: `git checkout -b feature/your-feature-name`
   - Keep pull requests focused on a single feature or bug fix.

3. **Code Style & Principles:**
   - Write clean, commented GDScript following Godot standard naming conventions.
   - Favor **data-driven design** (Resources and Inspector `@export`) over hardcoded values.
   - Maintain modularity: Components and world objects should instantiate cleanly on their own.
   - Keep assets lightweight and free of copyrighted material.

4. **Testing Before Submitting:**
   Run the headless test suite to verify project integrity:
   ```powershell
   godot --headless --path . -s res://tests/smoke_prefabs.gd
   godot --headless --path . -s res://tests/inspect_player.gd
   godot --headless --path . -s res://tests/runtime_ui.gd
   ```
   Ensure all 32 scenes pass with 0 errors.

---

## 🐛 Reporting Issues

- Use the GitHub Issue Tracker to report bugs or request features.
- Please include your Godot version, OS, and reproduction steps or error logs.

---

## 📜 License

By contributing to the Jalura Framework, you agree that your contributions will be licensed under the project's [MIT License](LICENSE).
