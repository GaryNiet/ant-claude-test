# ant-claude-test — Godot prototype

A video game prototype made with **Godot 4.3+** (standard version, not .NET).

## Run it
1. Get the code (first time): `git clone https://github.com/GaryNiet/ant-claude-test.git`
   Later updates: `git pull`
2. Open Godot → **Import** → select `project.godot` in this folder.
   With Godot 4.4 or newer, F5 runs the game embedded in the editor's **Game** tab (small).
   To get a real window, untick **Embed Game on Next Play** in the Game tab, or press F11 in the game.
3. Press **F5** (Run). The game opens on the main menu: pick Level 1 to 4, or open Settings.

Screen: the map in the top left. Under it the **gameplay bar**: play/pause, **Hatch 1**, **Hatch 5**,
**Hatch all** (toggle), **Behaviour**, **Tech tree**, the colony's food, ants, maturity and larvae,
and **Menu** (restart, save level, load level, settings, main menu).
On the right the **building / testing tools** (inspect, food, obstacles, terrain, nest, erase),
debug buttons (fit map, debug view, trails) and all the data (level, selection, colony statistics).

| Control | Action |
|---|---|
| Building tools (right) or keys **1**-**6** | Inspect / **Food** (apple) / **Obstacles** (stop sign) / **Terrain** (mountains) / Nest / Erase |
| Food, Obstacles, Terrain | The tools turn into that page, one button per item showing the item itself (blueberry, strawberry, larva...; rock, twig, tree trunk...; dirt, grass, water). **Backspace** or Back returns |
| Left mouse | Use the tool: inspect anything, place one object per click, paint terrain, erase, move the nest |
| Right mouse | Erase objects under the brush (any tool) |
| **[** / **]** or **-** / **=** | Brush size |
| Mouse wheel | Zoom (towards the mouse) |
| Middle mouse drag, arrows or **WASD** | Move the map |
| **Space** | Pause (you can still paint while paused) |
| **R** | Restart the level |
| Gameplay bar | Hatch larvae, Behaviour sliders, Tech tree upgrades (paid with food stored in the nest) |
| Save level / Load level (in Menu) | Save the current map as a level / start another level |
| Settings (main menu or Menu) | Window resolution: 720p, 1080p, 1440p or 4K (16:9, remembered) |
| **F11** or Settings | Fullscreen on / off (remembered) |
| **Escape** or Menu (gameplay bar) | Game menu: restart, save level, load level, settings, main menu |
| **Tab** or the view button (tool bar) | Switch between the isometric view and the flat debug view |
| **T** or the trails button (tool bar) | Show / hide the pheromone trails |

All controls can be changed in `game_settings.cfg` under `[controls]`.

## What you see
An ant colony simulation, seen at an angle (isometric) with pixel-art tiles and sprites:
orange ants (darker ones are scouts) and spiders (the enemies, with a health bar) stand upright
facing the screen, in 4 directions with a walking animation; an ant hill that grows with the
colony (a bigger hill with 3 entrances past ~160 ants); mossy patches on the dirt (decoration).
Ants carrying food hold a crumb. Dead ants lie on their back and fade away.

**Larvae and hatching:** the nest turns stored food into larvae (8 food each). You decide when they
hatch (Hatch 1 / Hatch 5, or Hatch all to hatch every larva as it's laid); hatching takes 6 seconds.

**Maturity:** like ages in Age of Empires. A colony reaches maturity 2 at 200 ants (it never goes
back); maturity unlocks more of the tech tree. Levels are in `[maturity]`.

**Behaviour** (sliders): aggressivity (how willing ants are to fight) and exploring distance. Only
ants hatched after a change are affected.

**Tech tree:** upgrades bought with stored food, in 3 vocations (fighting, hatching, harvesting) x
2 maturity levels; a node needs the one above it. Fighting: chitinous armor, restraining bite,
major ants, hunter lifestyle / powerful mandibles, acid spray, corrosive sting, super majors.
Hatching: motherbase, faster larvae / even faster larvae. Harvesting: carry more, mushroom harvest,
guarded paths / improved mushrooms, nuptial flights (found an allied nest by clicking the map).
Everything is in `[tech_tree]` and `[tech_<name>]` in `game_settings.cfg`.

**Raids:** an ant walking into a rival nest steals a larva (carried home as food); a nest with no
larvae left is attacked, and destroyed (with its ants) when its health runs out.

**Colonies:** a level can have rival colonies (Level 4). Our nest has a flag; rival ants are red.
Ants of different colonies fight when they meet, and carry dead rival ants home as food (in one
piece); their own dead fade away. The gameplay bar (hatching, behaviour, tech tree) acts on our
colony, or on a rival colony while its nest is selected (the bar says which). Settings in `[colonies]`.

**Objects:** food and obstacles are objects with a fixed shape and sprite, placed from the tool bar.
Food (blueberry, strawberry, seed, larva, dead spider) glows yellow and loses pixels as ants eat it;
a killed spider becomes a dead spider food item. Obstacles (rock, twig, high grass, pine cone,
dead leaf, tree trunk, mushroom) block ants and spiders; tree trunks are taller than the screen.
Each kind's size and food are in `[object_<kind>]` in `game_settings.cfg`.

**Paths:** where ants walk a lot, the ground wears into a smooth, lighter path (an "unobstructed
area") where ants walk 40% faster. Paths fade back slowly when ants stop using them (much slower
than pheromones). Settings in `[paths]`. Press **T** to hide the pheromone trails. Press **Tab** (or the tool bar
button) to switch to the **debug view**: the flat top-down map described below.
The angle and all sprite sizes are in `[iso_view]` in `game_settings.cfg`.

![screenshot](docs/screenshot.png)

### Debug view
The flat top-down map. The ground is made of 32 px tiles: brown = dirt, dark green = grass,
dark blue = water, purple = the nest (it grows with the colony: the more ants, the more tiles it covers).
Objects show as the 8 px cells they cover: food in bright green (brighter = more), obstacles in grey.
Ants can't cross water or obstacles. Worn paths are light brown.

Ants and enemies are arrows pointing where they are going: white = collector ants, light blue = scout ants, orange = ants
carrying food (you see the green food block they carry in front of them), yellow = fighting, light green = cutting food.
Big red arrows = enemies (spiders; with a health bar, green belly = food they ate). Blue glow = "going out" pheromone,
red glow = "going home" pheromone (pink where both overlap), yellow glow = fight pheromone. Stats are in the side panel.

The art (tiles in `tiles/`, sprites in `sprites/`) is generated by `tools/make_art.py` in the colors
of the inspiration images in `art/inspiration/`. Tiles support variants and transitions (e.g. a dirt
tile with grass on one side): see `tiles/README.md`.

## Where things are
| File | What it is |
|------|------------|
| `levels/` | Level files (`*.level`): map size, nests (ours and rivals), starting ants, ground tiles and objects (food and obstacles), as editable text. Levels 1-4 are listed in `[menu] levels`. |
| `tiles/` | Ground tile images (with variants and transitions). `tiles/README.md` explains the file names. |
| `sprites/` | Ant (ours and red rivals) and spider sprites (4 directions x 2 walk frames), dead ants, food crumb and glow, ant hills, our flag; `sprites/objects/` food and obstacle sprites; `sprites/icons/` tool bar icons. |
| `tools/make_art.py` | Generates all tiles and sprites (Python + Pillow + numpy). Edit colors/shapes and re-run. |
| `art/inspiration/` | The inspiration images the art is based on. |
| `game_settings.cfg` | **All tunable values** (speeds, sizes, colors, keys, window). Edit this to tweak the game. |
| `REQUEST_LOG.md` | Dated log of every request and the commits that implemented it. |
| `scripts/simulation/` | The simulation itself (no drawing): `colony_simulation.gd` runs it, `ant.gd` is the ant brain, `ground_map.gd` the tiles, `map_grid.gd` the cells (smells and food). |
| `scripts/view/` | Drawing the map (both views; `sprite_layer.gd` = isometric sprites), camera (zoom/pan), painting and selection. |
| `scripts/ui/` | Main menu, settings menu, tool bar and side panel (timer, upgrades, selected-object info, stats). |
| `scenes/` | Godot scenes: `main_menu.tscn` (first screen) and `game.tscn`. |
| `CLAUDE.md` | Rules the AI assistant follows when changing this project. |
