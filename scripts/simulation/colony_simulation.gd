class_name ColonySimulation
extends RefCounted
## The whole simulation: the ground (tiles: dirt, grass, water, nest), the map grid on top
## of it (pheromones, food and path wear, in smaller cells), the objects placed on the map
## (food items like blueberries, obstacles like rocks), the colonies (each with its nest),
## the ants and the enemies (spiders). It starts from a Level (the map layout).
## Food delivered to a nest is stored; the nest turns it into new ants, and the player can
## spend it on upgrades. A nest grows with its colony: the more ants, the more tiles it covers.
## A level can have rival colonies: ants of different colonies fight when they meet, and
## carry dead rival ants home as food (their own dead are left to fade away).
## It knows nothing about drawing; call step() at a fixed rate to advance it.
## The player places objects and paints ground tiles while it runs.

var level: Level   ## the level this simulation started from
var rng := RandomNumberGenerator.new()
var grid: MapGrid
var ground: GroundMap
var object_kinds := ObjectKinds.new()
var objects: Array[MapObject] = []
var objects_version := 0   ## goes up whenever an object is placed or removed
## Ants that died recently: {position, heading, time_dead, colony}. They fade away; rival
## colonies' ants can carry them home as food.
var dead_ants: Array[Dictionary] = []
var colonies: Array[Colony] = []
var player_colony: Colony
var ants: Array[Ant] = []    ## ants of all colonies
var enemies: Array[Enemy] = []
var enemy_settings := EnemySettings.new()
var collisions: AntCollisions

var _nest_min_radius: float = GameSettings.get_setting("nest", "radius")
var _nest_area_per_ant: float = GameSettings.get_setting("nest", "area_per_ant")
var _nest_sized_for := {}    ## colony index -> ant count its nest was last sized for

# Statistics
var elapsed_time := 0.0
var enemies_killed := 0
var enemies_escaped := 0
var food_eaten_by_enemies := 0

# Ant spawning
var _emerge_interval: float = GameSettings.get_setting("nest", "emerge_interval")
var food_per_new_ant: int = GameSettings.get_setting("nest", "food_per_new_ant")
var _max_ants: int = GameSettings.get_setting("nest", "max_ants")
var _time_until_next_enemy: float
var _dead_rival_food: int = GameSettings.get_setting("ant_life", "dead_rival_food")

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
	_create_colonies()
	grid = MapGrid.new(level.width(), level.height(), level.cell_size, colonies.size())
	_object_at_cell.resize(grid.width * grid.height)
	ground = GroundMap.new(level.columns, level.rows, level.tile_cells, level.cell_size, level.tiles)
	_grow_nests()
	for row in ground.rows:
		for column in ground.columns:
			_update_cells_of_tile(Vector2i(column, row))
	for placed in level.objects:
		place_object(placed.kind, (Vector2(placed.cell) + Vector2(0.5, 0.5)) * grid.cell_size, true)
	collisions = AntCollisions.new(grid.world_size())
	_time_until_next_enemy = enemy_settings.first_arrival


## The player's colony at the level's nest, then one rival colony per rival nest.
func _create_colonies() -> void:
	var nests: Array[Vector2i] = [level.nest_cell]
	nests.append_array(level.rival_nest_cells)
	for number in nests.size():
		var is_player := number == 0
		var colony_name: String = GameSettings.get_setting("colonies", "player_name") if is_player \
			else str(GameSettings.get_setting("colonies", "rival_name")) % number
		var nest := (Vector2(nests[number]) + Vector2(0.5, 0.5)) * level.cell_size
		colonies.append(Colony.new(number, colony_name, is_player, nest, level.starting_ants))
	player_colony = colonies[0]


## Advances the simulation by one tick of `delta` seconds.
func step(delta: float) -> void:
	elapsed_time += delta
	for colony in colonies:
		_spawn_first_ants(colony)
		_give_birth_over_time(colony, delta)
	_grow_nests()
	_spawn_enemies_over_time(delta)
	for ant in ants:
		ant.update(self, delta)
	for enemy in enemies:
		enemy.update(self, delta)
	collisions.resolve(ants, grid)
	for pair in collisions.rival_contacts:
		pair[0].touch_rival(pair[1])
		pair[1].touch_rival(pair[0])
	_remove_the_dead()
	_fade_dead_ants(delta)
	_handle_enemy_contacts()
	grid.decay(delta)


# --- Painting (called by the player's brush) --------------------------------

## Changes the ground of the tiles in the circle (at least the tile under the brush).
## Water is not painted right around the nest. Objects on tiles turned into water are removed.
func paint_ground(center: Vector2, radius: float, type: GroundMap.Type) -> void:
	for tile in ground.tiles_in_circle(center, radius):
		var too_close_to_nest := _is_near_a_nest(ground.tile_center(tile.x, tile.y), _obstacle_free_radius)
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


func _is_near_a_nest(spot: Vector2, distance: float) -> bool:
	for colony in colonies:
		if spot.distance_to(colony.nest_position) <= distance:
			return true
	return false


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
	if is_obstacle and not from_level and _is_near_a_nest(center, _obstacle_free_radius):
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


# --- Colonies: births, upgrades, nests ---------------------------------------

## Every birth_interval seconds, if there is enough food stored, a new ant is born.
func _give_birth_over_time(colony: Colony, delta: float) -> void:
	colony.time_until_birth -= delta
	if colony.time_until_birth > 0.0:
		return
	colony.time_until_birth = colony.birth_interval()
	if colony.food_stored >= food_per_new_ant and ants.size() < _max_ants:
		colony.food_stored -= food_per_new_ant
		_add_ant(colony, 0.0)
		colony.ants_born += 1


func _add_ant(colony: Colony, starting_age: float) -> void:
	ants.append(Ant.new(colony, rng, starting_age))
	colony.ant_count += 1


## Spends `colony`'s stored food on the next level of an upgrade. Returns false if not possible.
func buy_upgrade(colony: Colony, kind: ColonyUpgrades.Kind) -> bool:
	var upgrades := colony.upgrades
	if upgrades.is_maxed(kind) or colony.food_stored < upgrades.cost(kind):
		return false
	colony.food_stored -= upgrades.cost(kind)
	upgrades.raise(kind)
	var old_hp := colony.ant_settings.hp
	colony.ant_settings.apply_upgrades(upgrades)
	if kind == ColonyUpgrades.Kind.HP:  # living ants of the colony get the extra health too
		for ant in ants:
			if ant.colony == colony:
				ant.hp += colony.ant_settings.hp - old_hp
				ant.max_hp = colony.ant_settings.hp
	return true


## Moves `colony`'s nest to the cell at `spot` (not onto water or an obstacle), removes
## obstacles right around it and turns water there into dirt.
func move_nest(colony: Colony, spot: Vector2) -> void:
	if grid.is_obstacle(spot):
		return
	colony.nest_position = grid.cell_center(spot)
	for object in objects.duplicate():
		var reach := _obstacle_free_radius + object_kinds.footprint_radius(object.kind)
		if not object.is_food() and object.position.distance_to(colony.nest_position) <= reach:
			remove_object(object)
	for tile in ground.tiles_in_circle(colony.nest_position, _obstacle_free_radius):
		if not ground.is_walkable_type(ground.tiles[tile.y * ground.columns + tile.x]):
			ground.set_ground(tile.x, tile.y, GroundMap.Type.DIRT)
	_nest_sized_for.clear()  # redraw the nests
	_grow_nests()


## Each nest covers about area_per_ant square pixels per ant of its colony (never less than
## the minimum radius), so it grows as the colony grows. It covers every tile whose center
## is inside it. Only recomputed when a colony's size changed.
func _grow_nests() -> void:
	var changed := false
	for colony in colonies:
		if _nest_sized_for.get(colony.index, -1) != colony.ant_count:
			_nest_sized_for[colony.index] = colony.ant_count
			colony.nest_radius = maxf(_nest_min_radius, sqrt(colony.ant_count * _nest_area_per_ant / PI))
			changed = true
	if not changed:
		return
	var covered := PackedByteArray()
	covered.resize(ground.columns * ground.rows)
	for colony in colonies:
		for tile in ground.tiles_in_circle(colony.nest_position, colony.nest_radius):
			covered[tile.y * ground.columns + tile.x] = 1
	for tile in ground.set_nest_tiles(covered):
		_update_cells_of_tile(tile)


## Number of tiles `colony`'s nest covers.
func nest_tile_count(colony: Colony) -> int:
	return ground.tiles_in_circle(colony.nest_position, colony.nest_radius).size()


## The colony whose nest is closest to `spot`.
func nearest_colony(spot: Vector2) -> Colony:
	var closest := colonies[0]
	for colony in colonies:
		if spot.distance_to(colony.nest_position) < spot.distance_to(closest.nest_position):
			closest = colony
	return closest


## The colony whose nest covers `spot`, or null.
func colony_at(spot: Vector2) -> Colony:
	for colony in colonies:
		if spot.distance_to(colony.nest_position) <= colony.nest_radius:
			return colony
	return null


# --- Dead rival ants as food ---------------------------------------------------

## Position of the closest dead ant of ANOTHER colony than `colony` within `radius`
## (ants carry those home as food), or MapGrid.NO_FOOD.
func rival_corpse_near(spot: Vector2, radius: float, colony: Colony) -> Vector2:
	var closest := MapGrid.NO_FOOD
	var closest_distance := radius
	for dead in dead_ants:
		var distance := spot.distance_to(dead.position)
		if dead.colony != colony and distance <= closest_distance:
			closest = dead.position
			closest_distance = distance
	return closest


## Picks up a dead rival ant within `reach` of `spot` in a single chunk. Returns the food
## it is worth, or 0 if there is none.
func take_rival_corpse(spot: Vector2, reach: float, colony: Colony) -> int:
	for index in dead_ants.size():
		if dead_ants[index].colony != colony and spot.distance_to(dead_ants[index].position) <= reach:
			dead_ants.remove_at(index)
			return _dead_rival_food
	return 0


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
		var ant := ants[index]
		if ant.is_dead():
			if ant.died_of_old_age:
				ant.colony.ants_died_of_old_age += 1
			else:
				ant.colony.ants_killed += 1
			ant.colony.ant_count -= 1
			dead_ants.append({position = ant.position, heading = ant.heading, time_dead = 0.0, colony = ant.colony})
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
			enemy.heading = (nearest_colony(spot).nest_position - spot).angle()
			enemies.append(enemy)
			return


# --- Statistics -------------------------------------------------------------

func count_scouts(colony: Colony) -> int:
	var count := 0
	for ant in ants:
		if ant.colony == colony and ant.is_scout:
			count += 1
	return count


func count_ants_in_mode(colony: Colony, mode: Ant.Mode) -> int:
	var count := 0
	for ant in ants:
		if ant.colony == colony and ant.mode == mode:
			count += 1
	return count


# --- Spawning ---------------------------------------------------------------

## The starting colony emerges from the nest one ant at a time. They start at random ages,
## so they don't all die of old age at the same moment.
func _spawn_first_ants(colony: Colony) -> void:
	var ants_that_should_have_emerged := mini(colony.starting_ants, int(elapsed_time / _emerge_interval) + 1)
	while colony.first_ants_spawned < ants_that_should_have_emerged:
		_add_ant(colony, rng.randf_range(0.0, colony.ant_settings.starting_colony_max_age))
		colony.first_ants_spawned += 1
