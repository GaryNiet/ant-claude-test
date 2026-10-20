# ant-claude-test — Godot prototype

A video game prototype made with **Godot 4.3+** (standard version, not .NET).

## Run it
1. Get the code (first time): `git clone https://github.com/GaryNiet/ant-claude-test.git`
   Later updates: `git pull`
2. Open Godot → **Import** → select `project.godot` in this folder.
3. Press **F5** (Run). The game opens on `levels/default.level`.

| Control | Action |
|---|---|
| Tool bar (top) or keys **1**-**5** | Tool: Inspect / Food / Obstacle / Erase / Nest |
| Left mouse | Use the tool (Inspect: click anything to see its info in the side panel) |
| Right mouse | Erase food and obstacles (any tool) |
| **[** / **]** or **-** / **=** | Brush size |
| Mouse wheel | Zoom (towards the mouse) |
| Middle mouse drag, arrows or **WASD** | Move the map |
| **Space** | Pause (you can still paint while paused) |
| **R** | Restart the level |
| Side panel buttons | Upgrades, paid with food stored in the nest |
| Save level / Load level | Save the current map as a level / start another level |

All controls can be changed in `game_settings.cfg` under `[controls]`.

## What you see
An ant colony simulation. Purple dot = nest, white dots = collector ants, light-blue dots = scout ants, orange dots = ants carrying
food, green squares = food (brighter = more), grey = obstacles (ants can't cross them), big red dots = enemies (with a health bar; green belly = food
they ate), yellow dots = ants fighting, light green dots = ants cutting food. Blue glow = "going out" pheromone,
red glow = "going home" pheromone (pink where both overlap), yellow glow = fight pheromone. Stats are in the top-left corner.

![screenshot](docs/screenshot.png)

## Where things are
| File | What it is |
|------|------------|
| `levels/` | Level files (`*.level`): map size, nest, starting ants, obstacles and food, as editable text. |
| `game_settings.cfg` | **All tunable values** (speeds, sizes, colors, keys, window). Edit this to tweak the game. |
| `REQUEST_LOG.md` | Dated log of every request and the commits that implemented it. |
| `scripts/simulation/` | The simulation itself (no drawing): `colony_simulation.gd` runs it, `ant.gd` is the ant brain, `pheromone_grid.gd` the map of smells. |
| `scripts/view/` | Drawing the map, camera (zoom/pan), painting and selection. |
| `scripts/ui/` | Tool bar and side panel (timer, upgrades, selected-object info, stats). |
| `scenes/` | Godot scenes. |
| `CLAUDE.md` | Rules the AI assistant follows when changing this project. |
