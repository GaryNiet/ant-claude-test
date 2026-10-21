class_name ColonySimulation
extends RefCounted
## The whole simulation: the ground (tiles: dirt, grass, water, obstacles, nest), the map
## grid on top of it (pheromones and food, in smaller cells), the nest, the ants and the
## enemies. It starts from a Level (the map layout). Food delivered to the nest is stored;
## the nest turns it into new ants, and the player can spend it on upgrades.
## The nest grows with the colony: the more ants, the more tiles it covers.
## It knows nothing about drawing; call step() at a fixed rate to advance it.
## The player paints food and ground tiles while it runs.

var level: Level   ## the level this simulation started from
var rng := RandomNumberGenerator.new()
var grid: MapGrid
var ground: GroundMap
var ant_settings := AntSettings.new()
var upgrades := ColonyUpgrades.new()
var ants: Array[Ant] = []
var enemies: Array[Enemy] = []
var enemy_settings := EnemySettings.new()
var collisions: AntCollisions

var nest_position: Vector2
var nest_radius: float          ## ants count as "home" inside this distance; grows with the colony
var _nest_min_radius: float = GameSettings.get_setting("nest", "radius")
var _nest_area_per_ant: float = GameSettings.get_setting("nest", "area_per_ant")
var _nest_sized_for_ants := -1  ## colony size the nest was last sized for

# Statistics
var elapsed_time := 0.0
var total_food_collected := 0
var ants_born := 0
var ants_killed := 0         ## by enemies
var ants_died_of_old_age := 0
var enemies_killed := 0
var enemies_escaped := 0
var food_eaten_by_enemies := 0
var food_stored := 0  ## food in the nest, for new ants and upgrades
var time_until_birth := 0.0
var _delivery_times: Array[float] = []  ## when each recent food arrived, for food per second
var _food_rate_window: float = GameSettings.get_setting("display", "food_rate_window")

# Ant spawning
var _emerge_interval: float = GameSettings.get_setting("nest", "emerge_interval")
var _base_birth_interval: float = GameSettings.get_setting("nest", "birth_interval")
var food_per_new_ant: int = GameSettings.get_setting("nest", "food_per_new_ant")
var _max_ants: int = GameSettings.get_setting("nest", "max_ants")
var _first_ants_spawned := 0  ## the starting colony emerges over time; this counts them
var _time_until_next_enemy: float

var _contact_margin: float = GameSettings.get_setting("enemies", "contact_margin")

# Painting
var _painted_food_per_cell: int = GameSettings.get_setting("painting", "food_per_cell")
var _obstacle_free_radius: float = GameSettings.get_setting("painting", "obstacle_free_radius_around_nest")


func _init(starting_level: Level) -> void:
	level = starting_level
	var random_seed: int = GameSettings.get_setting("simulation", "random_seed")
	if random_seed == 0:
		rng.randomize()
	else:
		rng.seed = random_seed
	grid = MapGrid.new(level.width(), level.height(), level.cell_size)
	ground = GroundMap.new(level.columns, level.rows, level.tile_cells, level.cell_size, level.tiles)
	nest_position = (Vector2(level.nest_cell) + Vector2(0.5, 0.5)) * grid.cell_size
	_grow_nest()
	for row in ground.rows:
		for column in ground.columns:
			_update_cells_of_tile(Vector2i(column, row))
	for index in level.food.size():
		if grid.obstacle[index] == 0 and level.food[index] > 0:
			grid.set_food(index, level.food[index])
	collisions = AntCollisions.new(grid.world_size())
	time_until_birth = birth_interval()
	_time_until_next_enemy = enemy_settings.first_arrival


## Advances the simulation by one tick of `delta` seconds.
func step(delta: float) -> void:
	elapsed_time += delta
	_spawn_first_ants()
	_give_birth_over_time(delta)
	_grow_nest()
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


## Changes the ground of the tiles in the circle (at least the tile under the brush).
## Tiles that can't be walked on (water, obstacles) are not painted right around the nest.
func paint_ground(center: Vector2, radius: float, type: GroundMap.Type) -> void:
	for tile in ground.tiles_in_circle(center, radius):
		var too_close_to_nest := ground.tile_center(tile.x, tile.y).distance_to(nest_position) <= _obstacle_free_radius
		if too_close_to_nest and not ground.is_walkable_type(type):
			continue
		if ground.set_ground(tile.x, tile.y, type):
			_update_cells_of_tile(tile)


## Removes the food in the circle (pheromones are left alone).
func erase_food(center: Vector2, radius: float) -> void:
	for index in grid.cells_in_circle(center, radius):
		grid.set_food(index, 0)


## Makes the cells of a tile blocked or free, matching what the tile shows
## (blocking a cell removes its food and pheromones).
func _update_cells_of_tile(tile: Vector2i) -> void:
	var blocked := 0 if ground.is_walkable(tile.x, tile.y) else 1
	for row in range(tile.y * ground.tile_cells, (tile.y + 1) * ground.tile_cells):
		for column in range(tile.x * ground.tile_cells, (tile.x + 1) * ground.tile_cells):
			var index := row * grid.width + column
			if grid.obstacle[index] != blocked:
				grid.set_obstacle(index, blocked == 1)


# --- Called by ants ---------------------------------------------------------

## Food arriving at the nest is stored (for new ants and upgrades).
func deliver_food(amount: int) -> void:
	total_food_collected += amount
	food_stored += amount
	for i in amount:
		_delivery_times.append(elapsed_time)


# --- Nest: births and upgrades ----------------------------------------------

## Seconds between two births (shorter with the "Faster spawn" upgrade).
func birth_interval() -> float:
	return _base_birth_interval / (1.0 + upgrades.total_bonus(ColonyUpgrades.Kind.SPAWN))


## Every birth_interval seconds, if there is enough food stored, a new ant is born.
func _give_birth_over_time(delta: float) -> void:
	time_until_birth -= delta
	if time_until_birth > 0.0:
		return
	time_until_birth = birth_interval()
	if food_stored >= food_per_new_ant and ants.size() < _max_ants:
		food_stored -= food_per_new_ant
		ants.append(Ant.new(nest_position, ant_settings, rng))
		ants_born += 1


## Spends stored food on the next level of an upgrade. Returns false if not possible.
func buy_upgrade(kind: ColonyUpgrades.Kind) -> bool:
	if upgrades.is_maxed(kind) or food_stored < upgrades.cost(kind):
		return false
	food_stored -= upgrades.cost(kind)
	upgrades.raise(kind)
	var old_hp := ant_settings.hp
	ant_settings.apply_upgrades(upgrades)
	if kind == ColonyUpgrades.Kind.HP:  # living ants get the extra health too
		for ant in ants:
			ant.hp += ant_settings.hp - old_hp
			ant.max_hp = ant_settings.hp
	return true


## Moves the nest to the cell at `spot` (not onto water or an obstacle) and turns tiles
## that can't be walked on right around it into dirt.
func move_nest(spot: Vector2) -> void:
	if grid.is_obstacle(spot):
		return
	nest_position = grid.cell_center(spot)
	for tile in ground.tiles_in_circle(nest_position, _obstacle_free_radius):
		if not ground.is_walkable_type(ground.tiles[tile.y * ground.columns + tile.x]):
			ground.set_ground(tile.x, tile.y, GroundMap.Type.DIRT)
	_nest_sized_for_ants = -1  # redraw the nest at its new place
	_grow_nest()


## The nest covers about area_per_ant square pixels per ant (never less than the minimum
## radius), so it grows as the colony grows. It covers every tile whose center is inside it.
func _grow_nest() -> void:
	if ants.size() == _nest_sized_for_ants:
		return
	_nest_sized_for_ants = ants.size()
	nest_radius = maxf(_nest_min_radius, sqrt(ants.size() * _nest_area_per_ant / PI))
	var covered := PackedByteArray()
	covered.resize(ground.columns * ground.rows)
	for tile in ground.tiles_in_circle(nest_position, nest_radius):
		covered[tile.y * ground.columns + tile.x] = 1
	for tile in ground.set_nest_tiles(covered):
		_update_cells_of_tile(tile)


## Number of tiles the nest covers.
func nest_tile_count() -> int:
	return ground.nest_tiles.count(1)


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
	var ants_that_should_have_emerged := mini(level.starting_ants, int(elapsed_time / _emerge_interval) + 1)
	while _first_ants_spawned < ants_that_should_have_emerged:
		var starting_age := rng.randf_range(0.0, ant_settings.starting_colony_max_age)
		ants.append(Ant.new(nest_position, ant_settings, rng, starting_age))
		_first_ants_spawned += 1
