class_name ColonySimulation
extends RefCounted
## The whole simulation: the ground (tiles: dirt, grass, water, nest), the map grid on top
## of it (pheromones, food and path wear, in smaller cells), the objects placed on the map
## (food items like blueberries, obstacles like rocks), the colonies (each with its nest),
## the ants and the other creatures (spiders, beetle larvae, crickets: see Creature).
## It starts from a Level (the map layout).
## Food delivered to a nest is stored; the nest turns it into larvae, which hatch into ants
## when the player says so, and the player can spend food on tech tree upgrades. A colony
## matures (unlocking more upgrades) as it grows. A nest grows with its colony.
## A level can have rival colonies: ants of different teams fight when they meet, carry dead
## rival ants home as food (their own dead are left to fade away) and raid rival nests
## (stealing larvae, or damaging a nest with none left until it is destroyed).
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
var colonies: Array[Colony] = []   ## destroyed colonies stay in the list (their index is their trails)
var tech_tree := TechTree.new()
var player_colony: Colony
var ants: Array[Ant] = []    ## ants of all colonies
var creatures: Array[Creature] = []   ## spiders, beetle larvae, crickets
var creature_settings := {}            ## kind -> CreatureSettings
var collisions: AntCollisions
## Damage dealt since the view last took them (see take_damage_events): one entry per thing
## hurt during a tick: {victim, position, amount, victim_team, attacker_team} (team -1 = a creature).
var damage_events: Array[Dictionary] = []
var _max_damage_events: int = GameSettings.get_setting("damage_numbers", "max_waiting_events")

var _nest_min_radius: float = GameSettings.get_setting("nest", "radius")
var _nest_area_per_ant: float = GameSettings.get_setting("nest", "area_per_ant")
var _nest_sized_for := {}    ## colony index -> ant count its nest was last sized for

# Statistics
var elapsed_time := 0.0
var creatures_killed := {}    ## kind -> how many were killed
var creatures_killed_total := 0
var creatures_escaped := {}   ## kind -> how many left the map alive
var spiders_arrived := 0
var food_eaten_by_spiders := 0

# Ant spawning
var _emerge_interval: float = GameSettings.get_setting("nest", "emerge_interval")
var food_per_larva: int = GameSettings.get_setting("nest", "food_per_larva")
var _max_larvae: int = GameSettings.get_setting("nest", "max_larvae")
var _max_ants: int = GameSettings.get_setting("nest", "max_ants")
var _larva_food: int = GameSettings.get_setting("nest", "larva_food")
var _raid_food: int = GameSettings.get_setting("nest", "raid_food")
var _maturity_ants: PackedStringArray = GameSettings.get_list("maturity", "ants_needed")
var _time_until_next_spider: float
var _time_until_next_cricket: float
var _dead_rival_food: int = GameSettings.get_setting("ant_life", "dead_rival_food")

var _contact_margin: float = GameSettings.get_setting("creatures", "contact_margin")

# Objects and painting
var _object_at_cell := PackedInt32Array()  ## id of the object covering each cell, 0 = none
var _objects_by_id := {}                   ## id -> MapObject
var _next_object_id := 1
var _obstacle_free_radius: float = GameSettings.get_setting("painting", "obstacle_free_radius_around_nest")
var _dead_ant_fade_time: float = GameSettings.get_setting("ant_life", "dead_ant_fade_time")
var _focus_width: float = GameSettings.get_setting("focus", "trail_width")
var _focus_start_strength: float = GameSettings.get_setting("focus", "start_strength")
var _focus_target_radius: float = GameSettings.get_setting("focus", "target_radius")


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
	for kind in GameSettings.get_list("creatures", "kinds"):
		creature_settings[kind] = CreatureSettings.new(kind)
		creatures_killed[kind] = 0
		creatures_escaped[kind] = 0
	_time_until_next_spider = creature_settings.spider.value("first_arrival")
	_time_until_next_cricket = creature_settings.cricket.value("respawn_interval")
	_place_starting_creatures()


## The player's colony at the level's nest, then one rival colony per rival nest.
func _create_colonies() -> void:
	var nests: Array[Vector2i] = [level.nest_cell]
	nests.append_array(level.rival_nest_cells)
	for number in nests.size():
		var is_player := number == 0
		var colony_name: String = GameSettings.get_setting("colonies", "player_name") if is_player \
			else str(GameSettings.get_setting("colonies", "rival_name")) % number
		var nest := (Vector2(nests[number]) + Vector2(0.5, 0.5)) * level.cell_size
		colonies.append(Colony.new(number, colony_name, is_player, number, nest, level.starting_ants))
	player_colony = colonies[0]


## Advances the simulation by one tick of `delta` seconds.
func step(delta: float) -> void:
	elapsed_time += delta
	for colony in colonies:
		if colony.destroyed:
			continue
		_spawn_first_ants(colony)
		_lay_larvae(colony, delta)
		_hatch_larvae(colony, delta)
		_mature(colony)
		_grow_mushrooms(colony, delta)
		if colony.hp <= 0.0:
			_destroy(colony)
	_grow_nests()
	_spawn_creatures_over_time(delta)
	for ant in ants:
		ant.update(self, delta)
	for creature in creatures:
		creature.update(self, delta)
	collisions.resolve(ants, grid)
	for pair in collisions.rival_contacts:
		pair[0].touch_rival(pair[1])
		pair[1].touch_rival(pair[0])
	_report_damage()
	_remove_the_dead()
	_fade_dead_ants(delta)
	_handle_creature_contacts()
	grid.decay(delta)
	_regrow_food(delta)


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


## Focus tool: sends `colony`'s attack ants to `target`. Lays its attack trail in a straight
## line from the nest to the target, stronger towards the target (ants follow it towards the
## stronger smell), and a patch of the strongest smell around the target. The trail fades
## ([focus] half_life); focusing again renews it.
func focus(colony: Colony, target: Vector2) -> void:
	var start := colony.nest_position
	var step_length := grid.cell_size * 0.5
	var steps := maxi(1, ceili(start.distance_to(target) / step_length))
	for step in steps + 1:
		var progress := float(step) / steps
		var strength := lerpf(_focus_start_strength, grid.max_strength, progress)
		grid.raise_attack_zone(start.lerp(target, progress), _focus_width, strength, colony.index)
	grid.raise_attack_zone(target, _focus_target_radius, grid.max_strength, colony.index)
	colony.focus_target = target


## Calls `colony`'s attack ants back: its attack trail is gone.
func clear_focus(colony: Colony) -> void:
	grid.clear_attack(colony.index)
	colony.focus_target = Vector2.INF


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
## The food item it belongs to shrinks, and disappears when it's empty (a renewable one,
## like an aphid flower, stays and fills up again).
func take_food(spot: Vector2) -> bool:
	var object := object_at(spot)
	if not grid.take_food(spot):
		return false
	if object != null and object.is_food():
		object.food_left -= 1
		if object.food_left <= 0 and not object_kinds.is_renewable(object.kind):
			remove_object(object)
	return true


## An ant cuts a piece off the food at `spot`: up to its food item's piece_food units (less
## if the cell has less). Returns the food taken (0 if there was none).
func take_food_piece(spot: Vector2) -> int:
	var object := object_at(spot)
	var index := grid.cell_index(spot)
	if object == null or not object.is_food() or index == -1:
		return 0
	var taken := grid.take_food_from_cell(index, object_kinds.piece_food(object.kind))
	object.food_left -= taken
	if object.food_left <= 0 and not object_kinds.is_renewable(object.kind):
		remove_object(object)
	return taken


## Seconds an ant needs to cut one piece off the food at `spot` (its food item's cut_time).
func cut_time_at(spot: Vector2) -> float:
	var object := object_at(spot)
	return object_kinds.cut_time(object.kind) if object != null else 0.0


## Renewable food items (aphid flowers) fill up again, food_per_minute, up to their full amount.
func _regrow_food(delta: float) -> void:
	for object in objects:
		if not object.is_food() or not object_kinds.is_renewable(object.kind) or object.food_left >= object.total_food:
			continue
		object.regrowth += object_kinds.regrow_per_minute(object.kind) / 60.0 * delta
		while object.regrowth >= 1.0 and object.food_left < object.total_food:
			object.regrowth -= 1.0
			_add_food_to_object(object)


## One more unit of food in the object's emptiest cell.
func _add_food_to_object(object: MapObject) -> void:
	var emptiest := object.cells[0]
	for index in object.cells:
		if grid.food[index] < grid.food[emptiest]:
			emptiest = index
	grid.set_food(emptiest, grid.food[emptiest] + 1)
	object.food_left += 1


# --- Colonies: births, upgrades, nests ---------------------------------------

## The player's Lay buttons: pays for up to `count` larvae of `colony` (as many as its food
## allows, and no more than max_larvae waiting in the nest). Returns how many.
func lay_larvae(colony: Colony, count: int) -> int:
	var room := _max_larvae - colony.larvae - colony.laying - colony.hatching
	return colony.lay(mini(count, maxi(room, 0)), food_per_larva, tech_tree)


## Larvae being laid come out one after the other. Colonies the player doesn't control
## (rivals, allies) lay a larva whenever they can afford one.
func _lay_larvae(colony: Colony, delta: float) -> void:
	if not colony.is_player and colony.laying == 0:
		lay_larvae(colony, 1)
	colony.larvae += colony.update_laying(delta, tech_tree)


## Hatched larvae become ants (or wait, as larvae, while the map has max_ants). Larvae
## hatch one after the other. With infinite hatch, every stored larva joins the queue.
func _hatch_larvae(colony: Colony, delta: float) -> void:
	if colony.infinite_hatch:
		colony.hatch(colony.larvae)
	for larva in colony.update_hatching(delta):
		if ants.size() < _max_ants:
			_add_ant(colony, 0.0)
			colony.ants_born += 1
		else:
			colony.larvae += 1


## A colony matures when it has enough ants, and never goes back.
func _mature(colony: Colony) -> void:
	while colony.maturity < _maturity_ants.size() and colony.ant_count >= _maturity_ants[colony.maturity].to_int():
		colony.maturity += 1


## Mushroom harvest (and Improved mushrooms): a slow trickle of free food.
func _grow_mushrooms(colony: Colony, delta: float) -> void:
	var food_per_minute := 0.0
	for node in ["mushroom_harvest", "improved_mushrooms"]:
		if colony.has_tech(node):
			food_per_minute += float(tech_tree.value(node, "food_per_minute"))
	if food_per_minute > 0.0:
		colony.grow_mushrooms(food_per_minute, delta)


## A nest whose health ran out is destroyed: its ants die, it lays and hatches no more.
func _destroy(colony: Colony) -> void:
	colony.destroyed = true
	colony.larvae = 0
	colony.hatching = 0
	for ant in ants:
		if ant.colony == colony:
			ant.hp = 0.0
	_nest_sized_for.clear()  # its nest tiles go back to the ground below


func _add_ant(colony: Colony, starting_age: float) -> void:
	ants.append(Ant.new(colony, rng, starting_age, tech_tree))
	colony.ant_count += 1


## The highest maturity level there is.
func max_maturity() -> int:
	return _maturity_ants.size()


## Ants needed for `colony`'s next maturity level (-1 if it is at the highest).
func ants_for_next_maturity(colony: Colony) -> int:
	if colony.maturity >= _maturity_ants.size():
		return -1
	return _maturity_ants[colony.maturity].to_int()


# --- Tech tree ------------------------------------------------------------------

## Spends `colony`'s stored food on a tech tree node. Returns false if not possible
## (see TechTree.why_not). Allies share their upgrades.
func buy_tech(colony: Colony, node: String) -> bool:
	if tech_tree.why_not(colony, node) != "":
		return false
	colony.food_stored -= tech_tree.cost(node)
	colony.techs[node] = true
	for other in colonies:
		if other.techs == colony.techs:  # the same dictionary: allies
			other.ant_settings.apply_techs(other, tech_tree)
	if node == "nuptial_flights":
		colony.nests_to_found += 1
	return true


## Nuptial flights: founds an allied colony at `spot` (on free ground). It shares all of
## `parent`'s upgrades, is on its team, always hatches, and is not controlled by the player.
## Returns false if the spot is blocked or `parent` has no nest left to found.
func found_allied_nest(parent: Colony, spot: Vector2) -> bool:
	if parent.nests_to_found <= 0 or grid.is_obstacle(spot):
		return false
	parent.nests_to_found -= 1
	var number := colonies.size()
	var ally_name := str(GameSettings.get_setting("colonies", "ally_name")) % number
	var starting: int = tech_tree.value("nuptial_flights", "starting_ants")
	var ally := Colony.new(number, ally_name, false, parent.team, grid.cell_center(spot), starting)
	ally.techs = parent.techs
	ally.ant_settings.apply_techs(ally, tech_tree)
	ally.founded_time = elapsed_time
	colonies.append(ally)
	grid.add_colony()
	_nest_sized_for.clear()
	_grow_nests()
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
		if colony.destroyed:
			continue
		if _nest_sized_for.get(colony.index, -1) != colony.ant_count:
			_nest_sized_for[colony.index] = colony.ant_count
			colony.nest_radius = maxf(_nest_min_radius, sqrt(colony.ant_count * _nest_area_per_ant / PI))
			changed = true
	if not changed:
		return
	var covered := PackedByteArray()
	covered.resize(ground.columns * ground.rows)
	for colony in colonies:
		if colony.destroyed:
			continue
		for tile in ground.tiles_in_circle(colony.nest_position, colony.nest_radius):
			covered[tile.y * ground.columns + tile.x] = 1
	for tile in ground.set_nest_tiles(covered):
		_update_cells_of_tile(tile)


## Number of tiles `colony`'s nest covers.
func nest_tile_count(colony: Colony) -> int:
	return ground.tiles_in_circle(colony.nest_position, colony.nest_radius).size()


## The (not destroyed) colony whose nest is closest to `spot`.
func nearest_colony(spot: Vector2) -> Colony:
	var closest: Colony = null
	for colony in colonies:
		if not colony.destroyed and (closest == null or spot.distance_to(colony.nest_position) < spot.distance_to(closest.nest_position)):
			closest = colony
	return closest if closest != null else colonies[0]


## The (not destroyed) colony whose nest covers `spot`, or null.
func colony_at(spot: Vector2) -> Colony:
	for colony in colonies:
		if not colony.destroyed and spot.distance_to(colony.nest_position) <= colony.nest_radius:
			return colony
	return null


## The nest of another team than `team` that covers `spot` (an ant raiding it), or null.
func rival_colony_at(spot: Vector2, team: int) -> Colony:
	var colony := colony_at(spot)
	return colony if colony != null and colony.team != team else null


## The closest nest of another team than `team` within `radius` of `spot`, or null.
func rival_nest_near(spot: Vector2, radius: float, team: int) -> Colony:
	var closest: Colony = null
	var closest_distance := radius
	for colony in colonies:
		var distance := spot.distance_to(colony.nest_position)
		if not colony.destroyed and colony.team != team and distance <= closest_distance:
			closest = colony
			closest_distance = distance
	return closest


## A raiding ant takes a stored larva from `colony`'s nest, or else up to raid_food of its
## stored food. Returns the food it carries away (0 if the nest has neither).
func raid_nest(colony: Colony) -> int:
	if colony.larvae > 0:
		colony.larvae -= 1
		colony.larvae_stolen += 1
		return _larva_food
	var food := mini(_raid_food, colony.food_stored)
	colony.food_stored -= food
	colony.food_stolen += food
	return food


# --- Dead rival ants as food ---------------------------------------------------

## Position of the closest dead ant of ANOTHER team than `colony`'s within `radius`
## (ants carry those home as food), or MapGrid.NO_FOOD.
func rival_corpse_near(spot: Vector2, radius: float, colony: Colony) -> Vector2:
	var closest := MapGrid.NO_FOOD
	var closest_distance := radius
	for dead in dead_ants:
		var distance := spot.distance_to(dead.position)
		if dead.colony.team != colony.team and distance <= closest_distance:
			closest = dead.position
			closest_distance = distance
	return closest


## Picks up a dead rival ant within `reach` of `spot` in a single chunk. Returns the food
## it is worth (more with Hunter lifestyle), or 0 if there is none.
func take_rival_corpse(spot: Vector2, reach: float, colony: Colony) -> int:
	for index in dead_ants.size():
		if dead_ants[index].colony.team != colony.team and spot.distance_to(dead_ants[index].position) <= reach:
			dead_ants.remove_at(index)
			if colony.has_tech("hunter_lifestyle"):
				return roundi(_dead_rival_food * float(tech_tree.value("hunter_lifestyle", "food_multiplier")))
			return _dead_rival_food
	return 0


## Closest creature within `radius` of `from` (measured from its body's edge) that ants of
## `team` treat as an enemy, or null.
func nearest_hostile_creature(from: Vector2, radius: float, team: int) -> Creature:
	return _nearest_creature(from, radius, team)


## Closest creature of any kind within `radius` of `from` (measured from its body's edge), or null.
func nearest_creature(from: Vector2, radius: float) -> Creature:
	return _nearest_creature(from, radius, -1)


## `hostile_to` = only creatures hostile to that team (-1 = any creature).
func _nearest_creature(from: Vector2, radius: float, hostile_to: int) -> Creature:
	var closest: Creature = null
	var closest_distance := radius
	for creature in creatures:
		if hostile_to != -1 and not creature.is_hostile_to(hostile_to):
			continue
		var distance := from.distance_to(creature.position) - creature.settings.radius
		if distance <= closest_distance:
			closest = creature
			closest_distance = distance
	return closest


## A random food item on the map (where spiders go to feed), or null if there is none.
func random_food_object() -> MapObject:
	var food_items: Array[MapObject] = []
	for object in objects:
		if object.is_food() and object.food_left > 0:
			food_items.append(object)
	if food_items.is_empty():
		return null
	return food_items[rng.randi_range(0, food_items.size() - 1)]


# --- Creatures: contacts, death, arrival -------------------------------------------------

## Keeps ants out of creatures' bodies and records which ants touch which creature.
func _handle_creature_contacts() -> void:
	for creature in creatures:
		creature.ants_in_contact.clear()
		var touching_distance := collisions.ant_radius + creature.settings.radius
		for ant in ants:
			var offset := ant.position - creature.position
			if absf(offset.x) > touching_distance + _contact_margin or absf(offset.y) > touching_distance + _contact_margin:
				continue  # quick rejection: most ants are far away
			var distance := offset.length()
			if distance > touching_distance + _contact_margin:
				continue
			if distance < touching_distance:
				var direction := offset / distance if distance > 0.001 else Vector2.RIGHT
				var pushed_out := creature.position + direction * touching_distance
				if not grid.is_obstacle(pushed_out):
					ant.position = pushed_out
			creature.ants_in_contact.append(ant)
			ant.touch_creature(self, creature)


## Records the damage every ant, creature and nest took this tick (for the damage numbers).
## Nobody may be reading them (no view): then the oldest are dropped.
func _report_damage() -> void:
	var hurt: Array[Object] = []
	for ant in ants:
		if ant.damage_to_show > 0.0:
			hurt.append(ant)
	for creature in creatures:
		if creature.damage_to_show > 0.0:
			hurt.append(creature)
	for colony in colonies:
		if colony.damage_to_show > 0.0:
			hurt.append(colony)
	for thing in hurt:
		var victim_team: int = thing.team if thing is Colony else (thing.colony.team if thing is Ant else -1)
		damage_events.append({victim = thing, position = thing.position, amount = thing.damage_to_show,
			victim_team = victim_team, attacker_team = thing.damage_attacker_team})
		thing.damage_to_show = 0.0
	if damage_events.size() > _max_damage_events:
		damage_events = damage_events.slice(damage_events.size() - _max_damage_events)


## The damage dealt since the last call (see damage_events); the list is emptied.
func take_damage_events() -> Array[Dictionary]:
	var taken := damage_events
	damage_events = []
	return taken


## Dead ants lie on the ground for a while (with any food they carried lost); dead
## creatures become a food item; creatures that left the map are gone.
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
	for index in range(creatures.size() - 1, -1, -1):
		var creature := creatures[index]
		if creature.is_dead():
			place_object(creature.settings.food_object, creature.position, true, creature.food_value())
			creatures.remove_at(index)
			creatures_killed[creature.kind] += 1
			creatures_killed_total += 1
		elif creature.has_left_the_map:
			creatures.remove_at(index)
			creatures_escaped[creature.kind] += 1


## Dead ants fade away; after dead_ant_fade_time they are gone.
func _fade_dead_ants(delta: float) -> void:
	for index in range(dead_ants.size() - 1, -1, -1):
		dead_ants[index].time_dead += delta
		if dead_ants[index].time_dead >= _dead_ant_fade_time:
			dead_ants.remove_at(index)


## At the start: beetle larvae around every nest, and crickets away from the nests.
func _place_starting_creatures() -> void:
	var larva: CreatureSettings = creature_settings.beetle_larva
	for colony in colonies:
		for number in int(larva.value("count_per_nest")):
			var spot := _free_spot_around(colony.nest_position, larva.value("distance_from_nest_min"), larva.value("distance_from_nest_max"))
			if spot != Vector2.INF:
				creatures.append(BeetleLarva.new(spot, larva))
	for number in int(creature_settings.cricket.value("start_count")):
		_add_cricket()


## Spiders come in from the edge now and then; crickets come back when there are few left.
func _spawn_creatures_over_time(delta: float) -> void:
	var spider: CreatureSettings = creature_settings.spider
	_time_until_next_spider -= delta
	if _time_until_next_spider <= 0.0:
		_time_until_next_spider = spider.value("arrival_interval")
		if count_creatures("spider") < int(spider.value("max_alive")):
			_add_spider_at_edge()
	var cricket: CreatureSettings = creature_settings.cricket
	_time_until_next_cricket -= delta
	if _time_until_next_cricket <= 0.0:
		_time_until_next_cricket = cricket.value("respawn_interval")
		if count_creatures("cricket") < int(cricket.value("max_alive")):
			_add_cricket()


## Living creatures of `kind`.
func count_creatures(kind: String) -> int:
	var count := 0
	for creature in creatures:
		if creature.kind == kind:
			count += 1
	return count


## Places a spider at a random free spot along the map edge, heading for some food.
func _add_spider_at_edge() -> void:
	var spider: CreatureSettings = creature_settings.spider
	var map_size := grid.world_size()
	var inset := spider.radius + 1.0  # just inside the edge
	for attempt in 50:
		var spot: Vector2
		match rng.randi_range(0, 3):
			0: spot = Vector2(rng.randf_range(inset, map_size.x - inset), inset)
			1: spot = Vector2(rng.randf_range(inset, map_size.x - inset), map_size.y - inset)
			2: spot = Vector2(inset, rng.randf_range(inset, map_size.y - inset))
			_: spot = Vector2(map_size.x - inset, rng.randf_range(inset, map_size.y - inset))
		if not grid.is_obstacle(spot):
			var new_spider := Spider.new(spot, spider)
			new_spider.choose_target(self)
			creatures.append(new_spider)
			spiders_arrived += 1
			return


## A cricket at a random free spot far enough from every nest.
func _add_cricket() -> void:
	var cricket: CreatureSettings = creature_settings.cricket
	var map_size := grid.world_size()
	for attempt in 50:
		var spot := Vector2(rng.randf_range(0.0, map_size.x), rng.randf_range(0.0, map_size.y))
		if not grid.is_obstacle(spot) and not _is_near_a_nest(spot, cricket.value("min_distance_from_nest")):
			creatures.append(Cricket.new(spot, cricket))
			return


## A random free spot between `min_distance` and `max_distance` from `center` (INF if none found).
func _free_spot_around(center: Vector2, min_distance: float, max_distance: float) -> Vector2:
	for attempt in 50:
		var spot := center + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(min_distance, max_distance)
		if not grid.is_obstacle(spot) and object_at(spot) == null:
			return spot
	return Vector2.INF


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
	var ants_that_should_have_emerged := mini(colony.starting_ants, int((elapsed_time - colony.founded_time) / _emerge_interval) + 1)
	while colony.first_ants_spawned < ants_that_should_have_emerged:
		_add_ant(colony, rng.randf_range(0.0, colony.ant_settings.starting_colony_max_age))
		colony.first_ants_spawned += 1
