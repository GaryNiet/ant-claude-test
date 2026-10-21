class_name ColonySimulation
extends RefCounted
## The whole simulation: the ground (tiles: dirt, grass, water, nest), the map grid on top
## of it (pheromones, food and path wear, in smaller cells), the objects placed on the map
## (food items like blueberries, obstacles like rocks), the nest, the ants and the enemies
## (spiders). It starts from a Level (the map layout). Food delivered to the nest is stored;
## the nest turns it into new ants, and the player can spend it on upgrades.
## The nest grows with the colony: the more ants, the more tiles it covers.
## It knows nothing about drawing; call step() at a fixed rate to advance it.
## The player places objects and paints ground tiles while it runs.

var level: Level   ## the level this simulation started from
var rng := RandomNumberGenerator.new()
var grid: MapGrid
var ground: GroundMap
var object_kinds := ObjectKinds.new()
var objects: Array[MapObject] = []
var objects_version := 0   ## goes up whenever an object is placed or removed
## Ants that died recently: {position, heading, time_dead}. Only for drawing; they fade away.
var dead_ants: Array[Dictionary] = []
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

# Objects and painting
var _object_at_cell := PackedInt32Array()  ## id of the object covering each cell, 0 = none
var _objects_by_id := {}                   ## id -> MapObject
var _next_object_id := 1
var _obstacle_free_radius: float = GameSettings.get_setting("painting", "obstacle_free_radius_around_nest")
var _dead_ant_fade_time: float = GameSettings.get_setting("ant_life", "dead_ant_fade_time")


func _init(starting_level: Level) -> void:
	level = starting_level
	var random_seed: int = GameSettings.get_setting("simulation", "random_seed")
	if random_seed == 0:
		rng.randomize()
	else:
		rng.seed = random_seed
	grid = MapGrid.new(level.width(), level.height(), level.cell_size)
	_object_at_cell.resize(grid.width * grid.height)
	ground = GroundMap.new(level.columns, level.rows, level.tile_cells, level.cell_size, level.tiles)
	nest_position = (Vector2(level.nest_cell) + Vector2(0.5, 0.5)) * grid.cell_size
	_grow_nest()
	for row in ground.rows:
		for column in ground.columns:
			_update_cells_of_tile(Vector2i(column, row))
	for placed in level.objects:
		place_object(placed.kind, (Vector2(placed.cell) + Vector2(0.5, 0.5)) * grid.cell_size, true)
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
	_fade_dead_ants(delta)
	_handle_enemy_contacts()
	grid.decay(delta)


# --- Painting (called by the player's brush) --------------------------------

## Changes the ground of the tiles in the circle (at least the tile under the brush).
## Water is not painted right around the nest. Objects on tiles turned into water are removed.
func paint_ground(center: Vector2, radius: float, type: GroundMap.Type) -> void:
	for tile in ground.tiles_in_circle(center, radius):
		var too_close_to_nest := ground.tile_center(tile.x, tile.y).distance_to(nest_position) <= _obstacle_free_radius
		if too_close_to_nest and not ground.is_walkable_type(type):
			continue
		if ground.set_ground(tile.x, tile.y, type):
			if not ground.is_walkable_type(type):
				_remove_objects_on_tile(tile)
			_update_cells_of_tile(tile)


## Makes the cells of a tile blocked or free: blocked if the tile can't be walked on
## (water) or an obstacle object covers the cell. Blocking a cell removes its pheromones.
func _update_cells_of_tile(tile: Vector2i) -> void:
	var tile_blocked := not ground.is_walkable(tile.x, tile.y)
	for row in range(tile.y * ground.tile_cells, (tile.y + 1) * ground.tile_cells):
		for column in range(tile.x * ground.tile_cells, (tile.x + 1) * ground.tile_cells):
			var index := row * grid.width + column
			var blocked := 1 if tile_blocked or is_obstacle_object_cell(index) else 0
			if grid.obstacle[index] != blocked:
				grid.set_obstacle(index, blocked == 1)


## True if an obstacle object (rock, twig...) covers the cell at `index`.
func is_obstacle_object_cell(index: int) -> bool:
	var id := _object_at_cell[index]
	return id != 0 and not _objects_by_id[id].is_food()


func _remove_objects_on_tile(tile: Vector2i) -> void:
	for object in objects.duplicate():
		for index in object.cells:
			if _tile_of_cell(index) == tile:
				remove_object(object)
				break


func _tile_of_cell(index: int) -> Vector2i:
	return Vector2i((index % grid.width) / ground.tile_cells, (index / grid.width) / ground.tile_cells)


# --- Objects: food items and obstacles --------------------------------------

## Places an object of `kind` centered on the cell under `spot`. It covers the free cells of
## its footprint (not water, not other objects); returns null if there is no free cell, or
## for an obstacle too close to the nest. Food items share their food over their cells.
## `food` overrides the kind's amount (a dead spider holds what the spider ate too).
## `from_level` = placed while loading a level (obstacles may then be next to the nest).
func place_object(kind: String, spot: Vector2, from_level := false, food := -1) -> MapObject:
	if grid.cell_index(spot) == -1:
		return null
	var category := object_kinds.category(kind)
	var center := grid.cell_center(spot)
	var is_obstacle := category == ObjectKinds.Category.OBSTACLE
	if is_obstacle and not from_level and center.distance_to(nest_position) <= _obstacle_free_radius:
		return null
	var object := MapObject.new(_next_object_id, kind, category, center)
	for index in grid.cells_in_circle(center, object_kinds.footprint_radius(kind)):
		if grid.obstacle[index] == 0 and _object_at_cell[index] == 0:
			object.cells.append(index)
	if object.cells.is_empty():
		object.cells = _free_cell_under(center)
		if object.cells.is_empty():
			return null
	_next_object_id += 1
	_objects_by_id[object.id] = object
	objects.append(object)
	for index in object.cells:
		_object_at_cell[index] = object.id
		if is_obstacle:
			grid.set_obstacle(index, true)
	if not is_obstacle:
		_fill_with_food(object, food if food >= 0 else object_kinds.food(kind))
	objects_version += 1
	return object


## The cell under `spot` if it is free (for objects smaller than a cell).
func _free_cell_under(spot: Vector2) -> PackedInt32Array:
	var index := grid.cell_index(spot)
	if grid.obstacle[index] == 0 and _object_at_cell[index] == 0:
		return PackedInt32Array([index])
	return PackedInt32Array()


## Shares `amount` food over the object's cells as evenly as possible.
func _fill_with_food(object: MapObject, amount: int) -> void:
	object.total_food = amount
	object.food_left = amount
	var cell_count := object.cells.size()
	for number in cell_count:
		var share := amount / cell_count + (1 if number < amount % cell_count else 0)
		grid.set_food(object.cells[number], share)


func remove_object(object: MapObject) -> void:
	objects.erase(object)
	_objects_by_id.erase(object.id)
	for index in object.cells:
		_object_at_cell[index] = 0
		if object.is_food():
			grid.set_food(index, 0)
	if not object.is_food():
		var tiles := {}
		for index in object.cells:
			tiles[_tile_of_cell(index)] = true
		for tile in tiles:
			_update_cells_of_tile(tile)
	objects_version += 1


## The object covering the cell under `spot`, or null.
func object_at(spot: Vector2) -> MapObject:
	var index := grid.cell_index(spot)
	if index == -1 or _object_at_cell[index] == 0:
		return null
	return _objects_by_id[_object_at_cell[index]]


## Removes every object whose footprint touches the circle.
func erase_objects(center: Vector2, radius: float) -> void:
	for object in objects.duplicate():
		if object.position.distance_to(center) <= radius + object_kinds.footprint_radius(object.kind):
			remove_object(object)


## Takes 1 unit of food from the cell under `spot` (called by ants and spiders).
## The food item it belongs to shrinks, and disappears when it's empty.
func take_food(spot: Vector2) -> bool:
	var object := object_at(spot)
	if not grid.take_food(spot):
		return false
	if object != null and object.is_food():
		object.food_left -= 1
		if object.food_left <= 0:
			remove_object(object)
	return true


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


## Moves the nest to the cell at `spot` (not onto water or an obstacle), removes obstacles
## right around it and turns water there into dirt.
func move_nest(spot: Vector2) -> void:
	if grid.is_obstacle(spot):
		return
	nest_position = grid.cell_center(spot)
	for object in objects.duplicate():
		var reach := _obstacle_free_radius + object_kinds.footprint_radius(object.kind)
		if not object.is_food() and object.position.distance_to(nest_position) <= reach:
			remove_object(object)
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


## Dead ants lie on the ground for a while (with any food they carried lost); dead enemies
## become a dead spider food item;
## enemies that reached the edge on their way out are gone (with the food they ate).
func _remove_the_dead() -> void:
	for index in range(ants.size() - 1, -1, -1):
		if ants[index].is_dead():
			if ants[index].died_of_old_age:
				ants_died_of_old_age += 1
			else:
				ants_killed += 1
			dead_ants.append({position = ants[index].position, heading = ants[index].heading, time_dead = 0.0})
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


## A killed spider becomes a dead spider food item: its own food value plus what it ate.
func _turn_into_food(enemy: Enemy) -> void:
	place_object("dead_spider", enemy.position, true, enemy_settings.food_when_killed + enemy.food_eaten)


## Dead ants fade away; after dead_ant_fade_time they are gone.
func _fade_dead_ants(delta: float) -> void:
	for index in range(dead_ants.size() - 1, -1, -1):
		dead_ants[index].time_dead += delta
		if dead_ants[index].time_dead >= _dead_ant_fade_time:
			dead_ants.remove_at(index)


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
