# ant-claude-test — Godot prototype

A video game prototype made with **Godot 4.7** (standard version, not .NET).
Use 4.7 so the `.import` and `.uid` files in the repository stay as they are: another Godot
version rewrites them all when it opens the project.

## Run it
1. Get the code (first time): `git clone https://github.com/GaryNiet/ant-claude-test.git`
   Later updates: `git pull`
2. Open Godot → **Import** → select `project.godot` in this folder.
   With Godot 4.4 or newer, F5 runs the game embedded in the editor's **Game** tab (small).
   To get a real window, untick **Embed Game on Next Play** in the Game tab, or press F11 in the game.
3. Press **F5** (Run). The game opens on the main menu: pick Level 1 to 4, or open Settings.

Screen: the map in the top left. Under it the **gameplay bar**: play/pause, **Lay 1**, **Lay 5**
(with the laying bar), **Hatch 1**, **Hatch 5**, **Auto hatch** (with the hatching bar), **Focus**,
**Behaviour**, **Tech tree**, the colony's food, ants, maturity and larvae, and **Menu** (restart,
save level, load level, settings, main menu).
On the right the **building / testing tools** (inspect, food, obstacles, terrain, nest, erase),
debug buttons (fit map, debug view, trails) and all the data (level, selection, colony statistics).

| Control | Action |
|---|---|
| Building tools (right) or keys **1**-**6** | Inspect / **Food** (apple) / **Obstacles** (stop sign) / **Terrain** (mountains) / Nest / Erase |
| Food, Obstacles, Terrain | The tools turn into that page, one button per item showing the item itself (blueberry, strawberry, larva...; rock, twig, tree trunk...; dirt, grass, water). **Backspace** or Back returns |
| Left mouse | Use the tool: inspect anything, place one object per click, paint terrain, erase, move the nest |
| Right mouse | Erase objects under the brush (any tool) |
| **F** or Focus (gameplay bar) | Click a spot to send the attack ants there: an attack trail (orange-red, always shown) goes from the nest to the spot, the ants follow it and attack anything on the way and there. It fades after about a minute; click again to renew it, click our nest to call them back |
| **L** or Lay 1 / Lay 5 | Spend 20 food per larva; larvae are laid one after the other (10 s each), then hatch (Auto hatch is on at the start) |
| **[** / **]** or **-** / **=** | Brush size |
| Mouse wheel | Zoom (towards the mouse) |
| Middle mouse drag, arrows or **WASD** | Move the map |
| **Space** | Pause (you can still paint while paused) |
| **R** | Restart the level |
| Gameplay bar | Lay and hatch larvae, Focus, Behaviour sliders, Tech tree upgrades (paid with food stored in the nest) |
| Save level / Load level (in Menu) | Save the current map as a level / start another level |
| Settings (main menu or Menu) | Window resolution: 720p, 1080p, 1440p or 4K (16:9, remembered) |
| **F11** or Settings | Fullscreen on / off (remembered) |
| **Escape** or Menu (gameplay bar) | Game menu: restart, save level, load level, settings, main menu |
| **Tab** or the view button (tool bar) | Switch between the isometric view and the flat debug view |
| **T** or the trails button (tool bar) | Show / hide the pheromone trails |

All controls can be changed in `game_settings.cfg` under `[controls]`.

## What you see
An ant colony simulation, seen at an angle (isometric) with pixel-art tiles and sprites:
orange ants (darker ones are scouts) and the other animals (spiders, beetle larvae, crickets; with
a health bar once hurt) stand upright facing the screen, in 6 directions with a walking animation; an ant hill that grows with the
colony (a bigger hill with 3 entrances past ~160 ants); mossy patches on the dirt (decoration).
Ants carrying food hold a crumb. Dead ants lie on their back and fade away.

**The start:** every nest starts with 5 ants and 100 food. Every decision is about food: where to
get it early, and whether to spend it on larvae (more ants) or upgrades (a specialized colony).

**Larvae and hatching:** nothing is laid on its own: **Lay 1** / **Lay 5** spend 20 food per larva,
and the queen lays them one after the other, 10 seconds each (the bar next to the buttons fills
until the next one is laid). Laid larvae hatch one after the other too (Auto hatch is on at the
start; turn it off to hatch them yourself with Hatch 1 / Hatch 5). Rival and allied colonies lay
whenever they can afford it. Times in `[nest]` are game seconds (the game runs at half speed).

**Focus:** the player's way to fight. Click a spot and the colony's attack ants (about half of the
ants: those with a will to fight of 0.5 or more, and majors; the Behaviour aggressivity slider
makes more of them) follow an attack trail from the nest to the spot and attack anything on the
way and there: beetle larvae, crickets, spiders, rival ants and nests. Settings in `[focus]`.

**Food:** each food type is collected differently: time to cut a piece off, and food in a piece.
| Type | Items | Collect | Food per piece |
|---|---|---|---|
| Larva | a killed beetle larva (or a placed larva) | fast (1 s) | high (8) |
| Fruit | blueberry, strawberry (seed: slower, smaller) | fast (1 s) | medium (5) |
| Hard shell | dead spider, dead cricket | slow (3 s) | high (8) |
| Aphids | aphid flower: ants climb the stem to milk them; it never runs out, it fills up again | slow (3 s) | medium (4) |

**Animals:** they live their own lives, they aren't video game opponents (`[creature_<kind>]`).
- **Beetle larvae:** 2 fat grubs near every nest from the start. They crawl about slowly and keep
  growing: worth 50 food at the start, up to 200. Ants leave them alone unless you Focus on them.
  Kill them early for a quick boost, or let them grow for a bigger one later.
- **Crickets:** hop about in small areas away from the nests, faster than ants. Attacked, a cricket
  freezes for a moment, then flees to the map edge in long hops. Catch them with Restraining bite
  (bitten animals stay slowed; it caught every cricket in tests) or with many ants at once (about
  half the time with 20 or more ants); a lone ant never does. Worth 120 food (hard shell).
- **Spiders:** come in from the edge now and then (the first after about 10 minutes). They never
  go for the nest: they head for a food item and hunt the ants they see, and leave after killing
  5 ants or eating their fill. Strong (250 health, a bite kills an ant); killed, they leave 400 food.

**Balance** (tested with a scripted player, `tools/balance_test.gd`, see Where things are): maturity 2 (40 ants) comes after about
7-10 real minutes when only growing, about the same with 2-4 economy upgrades bought first (carry
more, mushroom harvest, motherbase, faster larvae), and those colonies end up bigger; buying
fighting upgrades first (restraining bite to hunt crickets) reaches it after 10-14 minutes.
Ants live 15-25 minutes; at most 1000 ants on the map.

**Damage numbers:** every hit shows its damage, rising over whoever was hurt: gold = damage our
ants dealt, red = damage our ants or nest took, grey = fights we're not part of. Settings in
`[damage_numbers]`.

**Sound:** calm background music (looping, on every screen) and sound effects: a spider arriving,
an animal killed, one of our larvae hatching, button clicks. Music and effects volumes are in the
Settings menu. The sounds are generated by `tools/make_sounds.py`; volumes in `[sound]`.

**Maturity:** like ages in Age of Empires. A colony reaches maturity 2 at 40 ants (it never goes
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
Food (blueberry, strawberry, seed, larva, dead spider, dead cricket, aphid flower) glows yellow and
loses pixels as ants eat it (not the aphid flower, which fills up again); a killed animal becomes a
food item. Obstacles (rock, twig, high grass, pine cone, dead leaf, tree trunk, mushroom) block ants
and animals; tree trunks are taller than the screen.
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
Big arrows = animals, with a health bar (red = spiders, cream = beetle larvae, green = crickets).
Orange-red glow = our attack trail (Focus). Blue glow = "going out" pheromone,
red glow = "going home" pheromone (pink where both overlap), yellow glow = fight pheromone. Stats are in the side panel.

The art (tiles in `tiles/`, sprites in `sprites/`) is generated by `tools/make_art.py` in the colors
of the inspiration images in `art/inspiration/`. Tiles support variants and transitions (e.g. a dirt
tile with grass on one side): see `tiles/README.md`.

## Where things are
| File | What it is |
|------|------------|
| `levels/` | Level files (`*.level`): map size, nests (ours and rivals), starting ants, ground tiles and objects (food and obstacles), as editable text. Levels 1-4 are listed in `[menu] levels`. |
| `tiles/` | Ground tile images (with variants and transitions). `tiles/README.md` explains the file names. |
| `sprites/` | Ant (ours and red rivals), spider, cricket and beetle larva sprites (6 directions x 2 walk frames), dead ants, food crumb and glow, ant hills, our flag; `sprites/objects/` food and obstacle sprites; `sprites/icons/` tool bar icons. |
| `tools/make_art.py` | Generates all tiles and sprites (Python + Pillow + numpy). Edit colors/shapes and re-run. |
| `sounds/`, `tools/make_sounds.py` | Music and sound effects (WAV), generated by the script (Python + numpy). Edit notes/sounds and re-run. |
| `art/inspiration/` | The inspiration images the art is based on. |
| `game_settings.cfg` | **All tunable values** (speeds, sizes, colors, keys, window). Edit this to tweak the game. |
| `REQUEST_LOG.md` | Dated log of every request and the commits that implemented it. |
| `scripts/simulation/` | The simulation itself (no drawing): `colony_simulation.gd` runs it, `ant.gd` is the ant brain, `creature.gd` the other animals (`spider.gd`, `beetle_larva.gd`, `cricket.gd`), `ground_map.gd` the tiles, `map_grid.gd` the cells (smells and food). |
| `tools/balance_test.gd` | Balance test: plays a level without graphics with a scripted strategy (only grow, economy or fighting upgrades first, raid the rival...) and prints the colony every 2 minutes. How to run it is at the top of the file. |
| `scripts/view/` | Drawing the map (both views; `sprite_layer.gd` = isometric sprites, `damage_number_layer.gd` = damage numbers), camera (zoom/pan), painting, selection, and `sound_cues.gd` (which game events play a sound). `scripts/sounds.gd` plays music and effects. |
| `scripts/ui/` | Main menu, settings menu, tool bar and side panel (timer, upgrades, selected-object info, stats). |
| `scenes/` | Godot scenes: `main_menu.tscn` (first screen) and `game.tscn`. |
| `CLAUDE.md` | Rules the AI assistant follows when changing this project. |
