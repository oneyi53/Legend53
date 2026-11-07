# HERO WORLD

An original offline, portrait-first fantasy ARPG. The new runtime direction is **pure HTML5**:
- HTML for the application shell and semantic UI
- CSS for responsive portrait HUD, panels and touch controls
- Native JavaScript ES modules for gameplay systems
- Canvas 2D for the isometric-style world renderer

## Run the browser version

Serve the repository root with any static HTTP server:

```bash
python3 -m http.server 8000
```

Then open http://localhost:8000/.

The first browser-playable slice includes the three classes, touch joystick, manual/automatic combat, class skills, forest enemies, drops, experience, leveling, a quest, a boss encounter, inventory and localStorage saves.

## Migration status

The original Godot 4.7.2 project remains in the repository as a legacy/reference implementation while systems are ported and tested in JavaScript. GDScript cannot run directly in a browser and must be rewritten module-by-module. The browser save is currently separate from the Godot save; import/migration is planned and must preserve a backup.

See [HTML5 migration notes](docs/HTML5_MIGRATION.md) and [browser runtime notes](web/README.md).

All characters, art, maps, skills, audio, names and writing are original. The project is offline-first and has no required game server.
