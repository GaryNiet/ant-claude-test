# Study: collisions between ants

Date: 2026-10-20. Status: **explored, not added to the game** (prototype code kept out of the project).

## Setup
- Godot 4.3, GDScript, cloud test machine (4 cores). Your PC will likely be somewhat faster,
  so treat the numbers as relative, not absolute.
- Collision = each ant is a circle (radius 2 px, same as how it's drawn). Overlapping ants are
  pushed apart by half the overlap each ("soft" collision, no bouncing/physics).
- Budget: the simulation runs at 30 Hz, so one tick must take **< 33 ms** at most.
  To keep the screen smooth (60 fps) it should stay **under ~16 ms**.

## Collision detection methods compared

| Method | How it works | Cost |
|---|---|---|
| Brute force | Every ant checks every other ant (n² pairs) | Measured: 90 ms at 500 ants, 1.1 s at 2000. Unusable beyond ~150 ants. |
| **Uniform grid (spatial hash)** | Ants are sorted into map squares each tick; an ant only checks the 9 squares around it | Measured: see below. Grows linearly with the number of ants. **Best fit**: all ants have the same size. |
| Godot physics (Area2D / RigidBody2D) | Engine does it in C++ | Not measured. C++ is fast, but each ant becomes a physics body that must be synced from GDScript every tick, plus solver features we don't need. Expected slower than the grid at thousands of ants, and harder to control. |
| Quadtree | Recursive splitting of space | Not measured. Helps when objects have very different sizes; with identical ants it's slower than a grid. |

The grid uses a "counting sort" (flat arrays, nothing created per tick). Square size matters:
8 px squares (2x the ant diameter) were faster than 4 px squares at normal ant counts
(1.0 ms vs 2.6 ms for 100 ants), because there are fewer empty squares to loop over.

## Performance (ms per tick, ants spread over the map)

| Ants | No collisions | Grid collisions (8 px squares) | Brute force |
|---:|---:|---:|---:|
| 100 | 2.7 | 3.5 | 4.4 |
| 500 | 7.0 | 11.6 | 100 |
| 1,000 | 17.8 | 18.7 | 271 |
| 2,000 | 27.9 | 39.0 | 1,150 |
| 5,000 | 63.1 | 124.7 | – |
| 10,000 | 124.2 | 324.6 | – |

(Measurements vary ±20% between runs.)

**Key finding: the ants' own brain is the main cost, not collisions.** Each ant costs
~13 µs per tick in GDScript (smelling 6 spots, looking for food, steering). Collisions with a
grid add roughly 40–60% on top of that.

## Limits (current GDScript code, this machine)

| | Smooth (≤16 ms) | Absolute max at 30 Hz (≤33 ms) |
|---|---:|---:|
| No collisions | ~1,000 ants | ~2,000 ants |
| With grid collisions | ~700 ants | ~1,500 ants |
| With brute-force collisions | ~150 ants | ~250 ants |

At 5,000+ ants on a 1280x720 map the trails get so crowded that ants are constantly
overlapping (5,000–30,000 contacts per tick), so collisions cost more than linear growth.
A bigger map would help.

## Effect on the simulation (100 ants, 4 maps x 5 minutes)

| | Food collected (avg) | Trip home with food | Real walking speed | Contacts per tick | Strong trail cells |
|---|---:|---:|---:|---:|---:|
| No collisions | 643 | 9.8 s | 45.0 px/s | 0 | 105 |
| Collisions, radius 2 px | 681 | 10.4 s | 44.8 px/s | 3–8 | 89 |
| Collisions, radius 3 px | 597 | 10.4 s | 44.3 px/s | 7–12 | 98 |

- **Speed**: almost no change at 100 ants (−0.5% to −1.5% walking speed, trips home ~6% longer,
  which is within the noise). Only ~5–15% of ants touch another ant in any tick.
- **Trails**: slightly wider and less concentrated (~15% fewer "very strong" cells), because
  ants pushed sideways lay pheromone next to the trail instead of on it. Total trail area unchanged.
- **Food**: differences are within the run-to-run noise (±15%), so no clear gain or loss.
- **Where it would matter**: with more or bigger ants. Expected effects then: traffic jams at
  the nest (10 px radius) and at food piles (pickup within 4 px), two-way traffic on the same
  trail pushing ants into side-by-side lanes (like real ants), wider and weaker trails, and
  slower round trips.

## How to go further if you want thousands of ants
1. **Optimize the ant brain** (biggest win): e.g. look for food using the same grid instead of
   checking every pile, smell fewer spots per tick, update far-away ants less often.
2. **Move the simulation loop to C++ (GDExtension)**: such loops are typically 10–50x faster than
   GDScript. Estimate (not measured): 10,000–50,000 ants with collisions.
3. **GPU compute shader**: 100,000+ ants, but the whole simulation (pheromones, ants, collisions)
   would have to move to the GPU. Much harder to read and change.
