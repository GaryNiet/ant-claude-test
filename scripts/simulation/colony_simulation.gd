class_name ColonySimulation
extends RefCounted
## The whole simulation: the pheromone grid, the nest, the ants and the food.
## It knows nothing about drawing; call step() at a fixed rate to advance it.

var rng := RandomNumberGenerator.new()
var pheromones := PheromoneGrid.new()
var ant_settings := AntSettings.new()
var ants: Array[Ant] = []
var food_sources: Array[FoodSource] = []
var collisions := AntCollisions.new(pheromones.world_size())

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

# Food spawning
var _max_food_sources: int = GameSettings.get_setting("food", "max_sources")
var _food_spawn_interval: float = GameSettings.get_setting("food", "spawn_interval")
var _food_min_amount: int = GameSettings.get_setting("food", "min_amount")
var _food_max_amount: int = GameSettings.get_setting("food", "max_amount")
var _food_min_distance_from_nest: float = GameSettings.get_setting("food", "min_distance_from_nest")
var _food_edge_margin: float = GameSettings.get_setting("food", "edge_margin")
var _time_until_next_food := 0.0


func _init() -> void:
	var random_seed: int = GameSettings.get_setting("simulation", "random_seed")
	if random_seed == 0:
		rng.randomize()
	else:
		rng.seed = random_seed
	nest_position = pheromones.world_size() / 2.0
	_time_until_next_food = _food_spawn_interval
	var initial_sources: int = GameSettings.get_setting("food", "initial_sources")
	for i in initial_sources:
		_spawn_food_source()


## Advances the simulation by one tick of `delta` seconds.
func step(delta: float) -> void:
	elapsed_time += delta
	_spawn_ants()
	_spawn_food_over_time(delta)
	for ant in ants:
		ant.update(self, delta)
	collisions.resolve(ants, pheromones.world_size())
	pheromones.decay(delta)


# --- Called by ants ---------------------------------------------------------

## Closest food pile within `radius` of `from`, or null if none.
func nearest_food(from: Vector2, radius: float) -> FoodSource:
	var closest: FoodSource = null
	var closest_distance := radius
	for food in food_sources:
		var distance := from.distance_to(food.position)
		if distance <= closest_distance:
			closest = food
			closest_distance = distance
	return closest


## Takes 1 unit from `food`. Returns false if it was already empty.
func take_food(food: FoodSource) -> bool:
	if food.is_empty():
		return false
	food.amount -= 1
	if food.is_empty():
		food_sources.erase(food)
	return true


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


func food_left_on_map() -> int:
	var total := 0
	for food in food_sources:
		total += food.amount
	return total


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
	if food_sources.size() < _max_food_sources:
		_spawn_food_source()


## Places a pile with a random amount at a random spot far enough from the nest.
func _spawn_food_source() -> void:
	var map_size := pheromones.world_size()
	for attempt in 100:
		var spot := Vector2(
			rng.randf_range(_food_edge_margin, map_size.x - _food_edge_margin),
			rng.randf_range(_food_edge_margin, map_size.y - _food_edge_margin))
		if spot.distance_to(nest_position) >= _food_min_distance_from_nest:
			food_sources.append(FoodSource.new(spot, rng.randi_range(_food_min_amount, _food_max_amount)))
			return
