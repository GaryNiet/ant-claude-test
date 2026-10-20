class_name ColonySimulation
extends RefCounted
## The whole simulation: the map grid (pheromones, food, obstacles), the nest, the ants
## and the enemies. Food delivered to the nest is stored and turned into new ants.
## It knows nothing about drawing; call step() at a fixed rate to advance it.
## It starts with one blob of food; the player paints more food and obstacles while it runs.

var rng := RandomNumberGenerator.new()
var grid := MapGrid.new()
var ant_settings := AntSettings.new()
var ants: Array[Ant] = []
var enemies: Array[Enemy] = []
var enemy_settings := EnemySettings.new()
var collisions := AntCollisions.new(grid.world_size())

var nest_position: Vector2
var nest_radius: float = GameSettings.get_setting("nest", "radius")

# Statistics
var elapsed_time := 0.0
var total_food_collected := 0
var ants_born := 0
var ants_killed := 0         ## by enemies
var ants_died_of_old_age := 0
var enemies_killed := 0
var enemies_escaped := 0
var food_eaten_by_enemies := 0
var food_stored := 0  ## food in the nest, waiting to be turned into new ants
var _delivery_times: Array[float] = []  ## when each recent food arrived, for food per second
var _food_rate_window: float = GameSettings.get_setting("display", "food_rate_window")

# Ant spawning
var _ant_count: int = GameSettings.get_setting("nest", "ant_count")
var _ant_spawn_interval: float = GameSettings.get_setting("nest", "spawn_interval")
var _food_per_new_ant: int = GameSettings.get_setting("nest", "food_per_new_ant")
var _max_ants: int = GameSettings.get_setting("nest", "max_ants")
var _first_ants_spawned := 0  ## the starting colony emerges over time; this counts them
var _time_until_next_enemy: float

# Starting food
var _start_food_distance: float = GameSettings.get_setting("food", "start_blob_distance")
var _start_food_direction: float = GameSettings.get_setting("food", "start_blob_direction")
var _start_food_radius: float = GameSettings.get_setting("food", "start_blob_radius")
var _start_food_per_cell: int = GameSettings.get_setting("food", "food_per_cell")
var _contact_margin: float = GameSettings.get_setting("enemies", "contact_margin")

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
	_time_until_next_enemy = enemy_settings.first_arrival


## Advances the simulation by one tick of `delta` seconds.
func step(delta: float) -> void:
	elapsed_time += delta
	_spawn_first_ants()
	_spawn_enemies_over_time(delta)
	for ant in ants:
		ant.update(self, delta)
	for enemy in enemies:
		enemy.update(self, delta)
	collisions.resolve(ants, grid)
	_remove_the_dead()
	_handle_enemy_contacts()
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

## Food arriving at the nest is stored; every food_per_new_ant units become a new ant.
func deliver_food() -> void:
	total_food_collected += 1
	_delivery_times.append(elapsed_time)
	food_stored += 1
	if food_stored >= _food_per_new_ant and ants.size() < _max_ants:
		food_stored -= _food_per_new_ant
		ants.append(Ant.new(nest_position, ant_settings, rng))
		ants_born += 1


## Closest living enemy within `radius` of `from`, or null if none.
func nearest_enemy(from: Vector2, radius: float) -> Enemy:
	var closest: Enemy = null
	var closest_distance := radius
	for enemy in enemies:
		var distance := from.distance_to(enemy.position) - enemy_settings.radius
		if distance <= closest_distance:
			closest = enemy
			closest_distance = distance
	return closest


# --- Enemies and fighting ---------------------------------------------------

## Keeps ants out of enemies' bodies and records which ants touch which enemy.
func _handle_enemy_contacts() -> void:
	var touching_distance := collisions.ant_radius + enemy_settings.radius
	for enemy in enemies:
		enemy.ants_in_contact.clear()
		for ant in ants:
			var offset := ant.position - enemy.position
			var distance := offset.length()
			if distance > touching_distance + _contact_margin:
				continue
			if distance < touching_distance:
				var direction := offset / distance if distance > 0.001 else Vector2.RIGHT
				var pushed_out := enemy.position + direction * touching_distance
				if not grid.is_obstacle(pushed_out):
					ant.position = pushed_out
			enemy.ants_in_contact.append(ant)
			ant.touch_enemy(self, enemy)


## Dead ants disappear (with any food they carried); dead enemies become food;
## enemies that reached the edge on their way out are gone (with the food they ate).
func _remove_the_dead() -> void:
	for index in range(ants.size() - 1, -1, -1):
		if ants[index].is_dead():
			if ants[index].died_of_old_age:
				ants_died_of_old_age += 1
			else:
				ants_killed += 1
			ants.remove_at(index)
	for index in range(enemies.size() - 1, -1, -1):
		var enemy := enemies[index]
		if enemy.is_dead():
			_turn_into_food(enemy)
			enemies.remove_at(index)
			enemies_killed += 1
		elif enemy.has_left_the_map:
			enemies.remove_at(index)
			enemies_escaped += 1


## Spreads the enemy's food value plus what it ate over the cells under its body.
func _turn_into_food(enemy: Enemy) -> void:
	var cells := grid.cells_in_circle(enemy.position, enemy_settings.food_pile_radius)
	var free_cells := PackedInt32Array()
	for index in cells:
		if grid.obstacle[index] == 0:
			free_cells.append(index)
	if free_cells.is_empty():
		return
	var total_food := enemy_settings.food_when_killed + enemy.food_eaten
	var food_per_cell := ceili(float(total_food) / free_cells.size())
	for index in free_cells:
		grid.set_food(index, grid.food[index] + food_per_cell)


func _spawn_enemies_over_time(delta: float) -> void:
	_time_until_next_enemy -= delta
	if _time_until_next_enemy > 0.0:
		return
	_time_until_next_enemy = enemy_settings.arrival_interval
	if enemies.size() < enemy_settings.max_alive:
		_spawn_enemy_at_edge()


## Places an enemy at a random free spot along the map edge.
func _spawn_enemy_at_edge() -> void:
	var map_size := grid.world_size()
	var inset := enemy_settings.radius + 1.0  # just inside the edge
	for attempt in 50:
		var spot: Vector2
		match rng.randi_range(0, 3):
			0: spot = Vector2(rng.randf_range(inset, map_size.x - inset), inset)
			1: spot = Vector2(rng.randf_range(inset, map_size.x - inset), map_size.y - inset)
			2: spot = Vector2(inset, rng.randf_range(inset, map_size.y - inset))
			_: spot = Vector2(map_size.x - inset, rng.randf_range(inset, map_size.y - inset))
		if not grid.is_obstacle(spot):
			var enemy := Enemy.new(spot, enemy_settings)
			enemy.heading = (nest_position - spot).angle()
			enemies.append(enemy)
			return


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

## The starting colony emerges from the nest one ant at a time. They start at random ages,
## so they don't all die of old age at the same moment.
func _spawn_first_ants() -> void:
	var ants_that_should_have_emerged := mini(_ant_count, int(elapsed_time / _ant_spawn_interval) + 1)
	while _first_ants_spawned < ants_that_should_have_emerged:
		var starting_age := rng.randf_range(0.0, ant_settings.starting_colony_max_age)
		ants.append(Ant.new(nest_position, ant_settings, rng, starting_age))
		_first_ants_spawned += 1


## Puts one round blob of food at a set distance from the nest.
func _place_starting_food() -> void:
	var angle := deg_to_rad(_start_food_direction)
	if _start_food_direction < 0.0:
		angle = rng.randf() * TAU  # negative direction = random
	var center := nest_position + Vector2.from_angle(angle) * _start_food_distance
	for index in grid.cells_in_circle(center, _start_food_radius):
		grid.set_food(index, _start_food_per_cell)
