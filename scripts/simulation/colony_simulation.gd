class_name ColonySimulation
extends RefCounted
## The whole simulation: the map grid (pheromones, food, obstacles), the nest and the ants.
## It knows nothing about drawing; call step() at a fixed rate to advance it.
## The painting functions let the player add food and obstacles while it runs.

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

# Random food piles
var _food_spawn_interval: float = GameSettings.get_setting("food", "spawn_interval")
var _max_food_on_map: int = GameSettings.get_setting("food", "max_food_on_map")
var _pile_min_radius: float = GameSettings.get_setting("food", "pile_min_radius")
var _pile_max_radius: float = GameSettings.get_setting("food", "pile_max_radius")
var _pile_food_per_cell: int = GameSettings.get_setting("food", "food_per_cell")
var _food_min_distance_from_nest: float = GameSettings.get_setting("food", "min_distance_from_nest")
var _food_edge_margin: float = GameSettings.get_setting("food", "edge_margin")
var _time_until_next_food := 0.0

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
	_time_until_next_food = _food_spawn_interval
	var initial_piles: int = GameSettings.get_setting("food", "initial_piles")
	for i in initial_piles:
		_spawn_food_pile()


## Advances the simulation by one tick of `delta` seconds.
func step(delta: float) -> void:
	elapsed_time += delta
	_spawn_ants()
	_spawn_food_over_time(delta)
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


func _spawn_food_over_time(delta: float) -> void:
	_time_until_next_food -= delta
	if _time_until_next_food > 0.0:
		return
	_time_until_next_food = _food_spawn_interval
	if grid.total_food < _max_food_on_map:
		_spawn_food_pile()


## Places a round pile of random size at a random free spot far enough from the nest.
func _spawn_food_pile() -> void:
	var map_size := grid.world_size()
	for attempt in 100:
		var spot := Vector2(
			rng.randf_range(_food_edge_margin, map_size.x - _food_edge_margin),
			rng.randf_range(_food_edge_margin, map_size.y - _food_edge_margin))
		if spot.distance_to(nest_position) < _food_min_distance_from_nest or grid.is_obstacle(spot):
			continue
		for index in grid.cells_in_circle(spot, rng.randf_range(_pile_min_radius, _pile_max_radius)):
			if grid.obstacle[index] == 0 and grid.food[index] < _pile_food_per_cell:
				grid.set_food(index, _pile_food_per_cell)
		return
