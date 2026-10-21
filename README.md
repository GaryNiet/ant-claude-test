# ant-claude-test — Godot prototype

A video game prototype made with **Godot 4.3+** (standard version, not .NET).

## Run it
1. Get the code (first time): `git clone https://github.com/GaryNiet/ant-claude-test.git`
   Later updates: `git pull`
2. Open Godot → **Import** → select `project.godot` in this folder.
3. Press **F5** (Run). The game opens on the main menu: pick Level 1, 2 or 3, or open Settings.

| Control | Action |
|---|---|
| Tool bar (top) or keys **1**-**8** | Tool: Inspect / Food / Obstacle / Erase / Nest / Dirt / Grass / Water |
| Left mouse | Use the tool (Inspect: click anything to see its info in the side panel) |
| Right mouse | Erase food (any tool) |
| **[** / **]** or **-** / **=** | Brush size |
| Mouse wheel | Zoom (towards the mouse) |
| Middle mouse drag, arrows or **WASD** | Move the map |
| **Space** | Pause (you can still paint while paused) |
| **R** | Restart the level |
| Side panel buttons | Upgrades, paid with food stored in the nest |
| Save level / Load level | Save the current map as a level / start another level |
| Settings (main menu or tool bar) | Window resolution: 720p, 1080p, 1440p or 4K (16:9, remembered) |
| **Escape** or Menu (tool bar) | Back to the main menu |

All controls can be changed in `game_settings.cfg` under `[controls]`.

## What you see
An ant colony simulation on a tile map. The ground is made of 32 px tiles: brown = dirt, dark green = grass,
dark blue = water and grey = obstacles (ants can't cross water or obstacles), purple = the nest. The nest grows with the colony:
the more ants, the more tiles it covers. Food (bright green, brighter = more) lies on top of the ground in smaller 8 px cells.

Ants and enemies are arrows pointing where they are going: white = collector ants, light blue = scout ants, orange = ants
carrying food (you see the green food block they carry in front of them), yellow = fighting, light green = cutting food.
Big red arrows = enemies (with a health bar; green belly = food they ate). Blue glow = "going out" pheromone,
red glow = "going home" pheromone (pink where both overlap), yellow glow = fight pheromone. Stats are in the side panel.

The tiles are plain colors for now. Drop PNG images in `tiles/` to replace them, including transitions
(e.g. a dirt tile with grass on one side): see `tiles/README.md`.

![screenshot](docs/screenshot.png)

## Where things are
| File | What it is |
|------|------------|
| `levels/` | Level files (`*.level`): map size, nest, starting ants, ground tiles and food, as editable text. Levels 1-3 are listed in `[menu] levels`. |
| `tiles/` | Tile images (none yet: plain colors are used). `tiles/README.md` explains the file names. |
| `game_settings.cfg` | **All tunable values** (speeds, sizes, colors, keys, window). Edit this to tweak the game. |
| `REQUEST_LOG.md` | Dated log of every request and the commits that implemented it. |
| `scripts/simulation/` | The simulation itself (no drawing): `colony_simulation.gd` runs it, `ant.gd` is the ant brain, `ground_map.gd` the tiles, `map_grid.gd` the cells (smells and food). |
| `scripts/view/` | Drawing the map, camera (zoom/pan), painting and selection. |
| `scripts/ui/` | Main menu, settings menu, tool bar and side panel (timer, upgrades, selected-object info, stats). |
| `scenes/` | Godot scenes: `main_menu.tscn` (first screen) and `game.tscn`. |
| `CLAUDE.md` | Rules the AI assistant follows when changing this project. |
