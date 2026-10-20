class_name ColonySimulation
extends RefCounted
## The whole simulation: the map grid (pheromones, food, obstacles), the nest and the ants.
## It knows nothing about drawing; call step() at a fixed rate to advance it.
## It starts with one blob of food; the player paints more food and obstacles while it runs.

var rng := RandomNumberGenerator.new()
var grid := MapGrid.new()
var ant_settings := AntSettings.new()
var ants: Array[Ant] = []
var collisions := AntCollisions.new(grid.world_size())

var nest_position: Vector2
var nest_radius: float = GameSettings.get_setting("nest", "radius")

# Statistics
var elapsed_time := 0.0
var total_food_collected := 0
var _delivery_times: Array[float] = []  ## when each recent food arrived, for food per second
var _food_rate_window: float = GameSettings.get_setting("display", "food_rate_window")

# Ant spawning
var _ant_count: int = GameSettings.get_setting("nest", "ant_count")
var _ant_spawn_interval: float = GameSettings.get_setting("nest", "spawn_interval")

# Starting food
var _start_food_distance: float = GameSettings.get_setting("food", "start_blob_distance")
var _start_food_direction: float = GameSettings.get_setting("food", "start_blob_direction")
var _start_food_radius: float = GameSettings.get_setting("food", "start_blob_radius")
var _start_food_per_cell: int = GameSettings.get_setting("food", "food_per_cell")

# Painting
var _painted_food_per_cell: int = GameSettings.get_setting("painting", "food_per_cell")
var _obstacle_free_radius: float = GameSettings.get_setting("painting", "obstacle_free_radius_around_nest")


func _init() -> void:
	var random_seed: int = GameSettings.get_setting("simulation", "random_seed")
	if random_seed == 0:
		rng.randomize()
	else:
		rng.seed = random_seed
	nest_position = grid.world_size() / 2.0
	_place_starting_food()


## Advances the simulation by one tick of `delta` seconds.
func step(delta: float) -> void:
	elapsed_time += delta
	_spawn_ants()
	for ant in ants:
		ant.update(self, delta)
	collisions.resolve(ants, grid)
	grid.decay(delta)


# --- Painting (called by the player's brush) --------------------------------

## Fills the cells in the circle with food (cells that already have more keep it).
func paint_food(center: Vector2, radius: float) -> void:
	for index in grid.cells_in_circle(center, radius):
		if grid.obstacle[index] == 0 and grid.food[index] < _painted_food_per_cell:
			grid.set_food(index, _painted_food_per_cell)


## Turns the cells in the circle into obstacles, except right around the nest.
func paint_obstacle(center: Vector2, radius: float) -> void:
	for index in grid.cells_in_circle(center, radius):
		var cell_middle := (Vector2(index % grid.width, index / grid.width) + Vector2(0.5, 0.5)) * grid.cell_size
		if cell_middle.distance_to(nest_position) > _obstacle_free_radius and grid.obstacle[index] == 0:
			grid.set_obstacle(index, true)


## Removes food and obstacles in the circle (pheromones are left alone).
func erase(center: Vector2, radius: float) -> void:
	for index in grid.cells_in_circle(center, radius):
		grid.set_food(index, 0)
		if grid.obstacle[index] == 1:
			grid.set_obstacle(index, false)


# --- Called by ants ---------------------------------------------------------

func deliver_food() -> void:
	total_food_collected += 1
	_delivery_times.append(elapsed_time)


# --- Statistics -------------------------------------------------------------

## Average food delivered per second over the last few seconds.
func food_per_second() -> float:
	while not _delivery_times.is_empty() and _delivery_times[0] < elapsed_time - _food_rate_window:
		_delivery_times.pop_front()
	var window := minf(elapsed_time, _food_rate_window)
	if window <= 0.0:
		return 0.0
	return _delivery_times.size() / window


func count_scouts() -> int:
	var count := 0
	for ant in ants:
		if ant.is_scout:
			count += 1
	return count


func count_ants_in_mode(mode: Ant.Mode) -> int:
	var count := 0
	for ant in ants:
		if ant.mode == mode:
			count += 1
	return count


# --- Spawning ---------------------------------------------------------------

## Ants emerge from the nest one at a time until the colony is complete.
func _spawn_ants() -> void:
	var ants_that_should_exist := mini(_ant_count, int(elapsed_time / _ant_spawn_interval) + 1)
	while ants.size() < ants_that_should_exist:
		ants.append(Ant.new(nest_position, ant_settings, rng))


## Puts one round blob of food at a set distance from the nest.
func _place_starting_food() -> void:
	var angle := deg_to_rad(_start_food_direction)
	if _start_food_direction < 0.0:
		angle = rng.randf() * TAU  # negative direction = random
	var center := nest_position + Vector2.from_angle(angle) * _start_food_distance
	for index in grid.cells_in_circle(center, _start_food_radius):
		grid.set_food(index, _start_food_per_cell)
