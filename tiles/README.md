# Tile images

The images here are made by `tools/make_art.py` (run `python3 tools/make_art.py` to rebuild
them after changing it). You can also replace any of them with hand-made art.

The isometric view draws the ground with these images; the debug view uses the plain colors.
A tile is **32 x 32 px**
on the map (4 x 4 cells of 8 px); images of any size are stretched to fit, so 32, 64 or
128 px squares all work.

Tile types: `dirt`, `grass`, `water`, `obstacle`, `nest`.

For each tile the game uses the most specific image that exists:

1. `<type>_<neighbour>_<sides>.png`: a transition. `<neighbour>` is the most common other
   type touching the tile, `<sides>` lists the sides it touches, always in the order
   `n`, `e`, `s`, `w`. Examples:
   - `dirt_grass_n.png`: dirt with grass above it
   - `dirt_grass_ne.png`: dirt with grass above and to the right
   - `grass_water_nesw.png`: a grass tile surrounded by water
2. `<type>.png`: the plain tile, e.g. `dirt.png`.
3. Nothing found: the tile is drawn in its color from `[colors]` in `game_settings.cfg`.

Any image can have **variants**: `dirt.png`, `dirt_2.png`, `dirt_3.png`... Each tile always
uses the same variant (picked from its position), so the ground doesn't look repetitive.

So you can add images little by little: start with `dirt.png`, `grass.png` and so on, then
add transitions where they matter. The folder is set by `[ground] tile_image_folder`.
