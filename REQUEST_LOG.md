# Request log

Newest first. Each entry: date, request (verbatim), what was done, commits.

---

## #2 — 2026-10-20

**Request:**
> Okay, let's start the game.
> This is a game based on an advanced simulation system. I haven't decided what the game looks like, but we can start with the simulation system which is a 2D plane with many nodes that'll hold values.
>
> See it as an ant nest simulation. There is a center point that is the ant nest and ants emerge from there. Some will stay around the nest others will go out exploring based o. Their senses. Elle these ants leave pheromone trails which are saved to the simulation grid. Pheromones decay over time, naturally by having more movement around the nest the pheromones should be stronger there.
>
> Ants have 2 different pheromones for now, when they are going out and when they are going home.
>
> Ants have 4 functioning modes for now, exploring, gathering, going home with food and going home.
>
> When exploring they try to go where other ants have not been before. They can base this on other ants pheromone trails. When exploring they leave a going out trail.
>
> When going home with food, they find their way back by following other ants going out pheromone trail backwards. They can sense pheromones around them and they'll move to where the pheromones are stronger, follow going home trails and can have a little push in the right direction if the simulation is struggling. When with food, they leave a going home trail. When without food, they leave no trail.
>
> When gathering they go straight to the food, gather and come back following trails. They follow "going home pheromones" in both directions.
>
> Right now the nest can be a single point. Food will randomly spawn across the map with random values. Ants will pick up 1 food and go home. The aim of the ants is to pick up as much food as possible. Start with 100 ants.
>
> The simulation updates at 30hz
>
> Make sure there is some sense in the values. How much food there is, ant movement speed, home much pheromone are laid behind, how fast it decays. Size of map, ants etc.
>
> Ants will enventually go home when they don't find food.
>
> Make this simulation and a way to visualize it. Just spots and colors on a black background will do for now. I want to see the nest, the ants, the food and the pheromones. Display some data like food per second, total food
>
> This will do for now

**Done:**
- Replaced the demo square with an ant colony simulation (`scripts/simulation/`) on a
  160 x 90 cell pheromone grid (1280 x 720 px), stepped at a fixed 30 Hz.
- 100 ants emerge from the central nest one by one, each with 4 modes (exploring, gathering,
  carrying food, returning home). 30% are "homebodies" that only explore briefly near the nest.
- Trails are strongest where they start (ants lay less the longer they've walked), so
  following "stronger smell" leads back to the nest (going-out trail) or to food (going-home trail).
- Going home: follow the going-out trail + a push towards the nest that grows over time.
- Food piles (15-60 units) appear randomly, never near the nest, up to 12 at once.
- Visualization: black background, colored pheromone glow, dots for nest/ants/food,
  stats panel (time, total food, food per second, food left, ants per mode). Space = pause, R = restart.
- All values in `game_settings.cfg`. Tested headless in Godot 4.3: ~3 food/s, ~2.6 ms per tick.

**Commits:**
- `7f33e79` — Add ant colony simulation with pheromone grid and visualization

---

## #1 — 2026-10-20

**Request:**
> I'm making a prototype for a video game using Godot.
> I want you to generate the code, keep it as readable as possible by humans, make all hard
> coded variables modifiable on a single text file. Keep a log in a file, dated, of all my
> request and log which commits correspond to the demand.
> I just want to pull the code from my home PC when it's done. Is this possible?

**Done:**
- Set up a minimal Godot 4 project: a colored square you move with arrows/WASD.
- `game_settings.cfg`: single text file holding every tunable value, read by the
  `GameSettings` autoload (`scripts/game_settings.gd`).
- This request log, plus `CLAUDE.md` rules so every future change follows the same conventions.
- README with instructions to pull and run on your PC.

**Commits:**
- `67f89cb` — Set up Godot prototype with central settings file and request log
