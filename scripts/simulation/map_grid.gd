class_name MapGrid
extends RefCounted
## The 2D plane of the simulation: a grid of cells, each holding:
##
## - "going out" pheromone  : laid by ants walking away from the nest (exploring / gathering)
## - "going home" pheromone : laid by ants carrying food back to the nest
##                            (both are kept separately for each colony: ants only smell
##                            their own colony's trails)
## - "fight" pheromone      : laid in a zone around ants that are fighting an enemy
## - food                   : units of food in the cell (an ant carries 1 unit)
## - obstacle               : ants can't walk through obstacle cells
## - path wear              : how worn the ground is by ants walking over it. Above
##                            [paths] unobstructed_wear the cell is "unobstructed": a path
##                            where ants walk faster. Not a tile type: any walkable ground
##                            can have it, a dirt tile may have unobstructed parts.
##
## Pheromones fade over time (exponential decay with a configurable half-life), so busy
## paths stay strong while abandoned ones disappear. Path wear fades the same way, but much
## more slowly. To save time, each tick only a slice of the rows fades (by the amount for
## all the ticks since that slice last faded), see [pheromones] decay_slices.
## Everything outside the map counts as an obstacle.

enum Kind { GOING_OUT, GOING_HOME, FIGHT }

const NO_FOOD := Vector2.INF  ## returned by find_food_near() when there is none

var width: int          ## number of cells horizontally
var height: int         ## number of cells vertically
var cell_size: float    ## size of one cell in pixels
var max_strength: float

var colony_count: int
var cell_count: int     ## width x height
## Trails of all colonies in one array: colony c's value for cell i is at c * cell_count + i.
var going_out := PackedFloat32Array()
var going_home := PackedFloat32Array()
var fight := PackedFloat32Array()
var food := PackedInt32Array()
var obstacle := PackedByteArray()  ## 1 = obstacle, 0 = free
var path_wear := PackedFloat32Array()
var unobstructed_wear: float  ## path wear from which a cell counts as unobstructed
var _max_path_wear: float

var total_food := 0          ## sum of all food on the map, kept up to date
var terrain_version := 0     ## goes up whenever food or obstacles change (tells the view to redraw)

# Food lookup speed-up: the map is divided into regions of N x N cells, and we keep the total
# food per region. An ant looking for food first checks these totals and only scans
# individual cells when a nearby region has food (most of the map has none).
var _region_cells: int
var _region_columns: int
var _food_in_region := PackedInt32Array()

var _decay_per_second_log: float        ## precomputed for the decay formula
var _fight_decay_per_second_log: float  ## the fight pheromone fades faster
var _path_decay_per_second_log: float   ## path wear fades much slower
var _decay_slices: int                  ## the rows are faded in this many slices, one per tick
var _next_decay_slice := 0


## Creates an empty map of `columns` x `rows` cells, each `cell_size_in_pixels` wide, with
## trails for `colonies` colonies.
func _init(columns: int, rows: int, cell_size_in_pixels: float, colonies: int) -> void:
	width = columns
	height = rows
	cell_count = width * height
	colony_count = colonies
	_decay_slices = GameSettings.get_setting("pheromones", "decay_slices")
	cell_size = cell_size_in_pixels
	_region_cells = GameSettings.get_setting("map", "food_lookup_region_cells")
	max_strength = GameSettings.get_setting("pheromones", "max_strength")
	var half_life: float = GameSettings.get_setting("pheromones", "half_life")
	_decay_per_second_log = log(0.5) / half_life
	var fight_half_life: float = GameSettings.get_setting("ant_combat", "fight_pheromone_half_life")
	_fight_decay_per_second_log = log(0.5) / fight_half_life
	_path_decay_per_second_log = log(0.5) / float(GameSettings.get_setting("paths", "half_life"))
	unobstructed_wear = GameSettings.get_setting("paths", "unobstructed_wear")
	_max_path_wear = GameSettings.get_setting("paths", "max_wear")
	path_wear.resize(width * height)
	going_out.resize(cell_count * colony_count)
	going_home.resize(cell_count * colony_count)
	fight.resize(width * height)
	food.resize(width * height)
	obstacle.resize(width * height)
	_region_columns = ceili(float(width) / _region_cells)
	_food_in_region.resize(_region_columns * ceili(float(height) / _region_cells))


## Size of the whole map in pixels.
func world_size() -> Vector2:
	return Vector2(width, height) * cell_size


## Center of the cell under `world_position`, in pixels.
func cell_center(world_position: Vector2) -> Vector2:
	return (Vector2(cell_coords(world_position)) + Vector2(0.5, 0.5)) * cell_size


## Indexes of all cells whose center is within `radius` pixels of `center` (inside the map).
func cells_in_circle(center: Vector2, radius: float) -> PackedInt32Array:
	var indexes := PackedInt32Array()
	var radius_in_cells := ceili(radius / cell_size)
	var middle := cell_coords(center)
	for row in range(maxi(middle.y - radius_in_cells, 0), mini(middle.y + radius_in_cells + 1, height)):
		for column in range(maxi(middle.x - radius_in_cells, 0), mini(middle.x + radius_in_cells + 1, width)):
			var cell_middle := (Vector2(column, row) + Vector2(0.5, 0.5)) * cell_size
			if cell_middle.distance_to(center) <= radius:
				indexes.append(row * width + column)
	return indexes


## Column and row of the cell under `world_position`.
func cell_coords(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / cell_size), floori(world_position.y / cell_size))


# --- Pheromones -------------------------------------------------------------

## Makes room for one more colony's trails (a nest founded during the game).
func add_colony() -> void:
	colony_count += 1
	going_out.resize(cell_count * colony_count)
	going_home.resize(cell_count * colony_count)


## Adds `amount` of pheromone `kind` of `colony` to the cell under `world_position`
## (the fight pheromone is shared by all colonies).
func deposit(kind: Kind, world_position: Vector2, amount: float, colony := 0) -> void:
	var index := cell_index(world_position)
	if index == -1:
		return
	if kind == Kind.GOING_OUT:
		index += colony * cell_count
		going_out[index] = minf(going_out[index] + amount, max_strength)
	elif kind == Kind.GOING_HOME:
		index += colony * cell_count
		going_home[index] = minf(going_home[index] + amount, max_strength)
	else:
		fight[index] = minf(fight[index] + amount, max_strength)


## Adds `amount` of pheromone `kind` to every cell within `radius` pixels of `center`.
func deposit_zone(kind: Kind, center: Vector2, radius: float, amount: float) -> void:
	for index in cells_in_circle(center, radius):
		var cell_middle := (Vector2(index % width, index / width) + Vector2(0.5, 0.5)) * cell_size
		deposit(kind, cell_middle, amount)


## Raises pheromone `kind` of `colony` to at least `strength` in every cell within `radius`
## of `center` (the player drawing a trail; never lowers a stronger smell).
func raise_zone(kind: Kind, center: Vector2, radius: float, strength: float, colony := 0) -> void:
	var trail := going_out if kind == Kind.GOING_OUT else going_home
	for index in cells_in_circle(center, radius):
		if obstacle[index] == 0:
			var slot := index + colony * cell_count
			trail[slot] = maxf(trail[slot], minf(strength, max_strength))


## Returns the strength of pheromone `kind` of `colony` at `world_position` (0 outside the map).
func sample(kind: Kind, world_position: Vector2, colony := 0) -> float:
	var index := cell_index(world_position)
	if index == -1:
		return 0.0
	if kind == Kind.GOING_OUT:
		return going_out[index + colony * cell_count]
	if kind == Kind.GOING_HOME:
		return going_home[index + colony * cell_count]
	return fight[index]


## Average strength of pheromone `kind` over a square of cells centered on `world_position`.
## `radius_in_cells` = 0 reads 1 cell, 1 reads 3x3 cells, 2 reads 5x5 cells...
## A bigger area lets ants notice a trail that is a bit to the side of their sensor.
func sample_area(kind: Kind, world_position: Vector2, radius_in_cells: int, colony := 0) -> float:
	if radius_in_cells == 0:
		return sample(kind, world_position, colony)
	var total := 0.0
	for row in range(-radius_in_cells, radius_in_cells + 1):
		for column in range(-radius_in_cells, radius_in_cells + 1):
			total += sample(kind, world_position + Vector2(column, row) * cell_size, colony)
	var cells_read := (radius_in_cells * 2 + 1) * (radius_in_cells * 2 + 1)
	return total / cells_read


## Called every tick of `delta` seconds: fades the pheromones and the path wear of the next
## slice of rows, by the amount for decay_slices ticks (each row's turn comes back after
## that many ticks). Same result as fading everything every tick, for a fraction of the work.
func decay(delta: float) -> void:
	var slice_delta := delta * _decay_slices
	var factor := exp(_decay_per_second_log * slice_delta)
	var fight_factor := exp(_fight_decay_per_second_log * slice_delta)
	var path_factor := exp(_path_decay_per_second_log * slice_delta)
	var rows_per_slice := ceili(float(height) / _decay_slices)
	var first := mini(_next_decay_slice * rows_per_slice, height) * width
	var last := mini((_next_decay_slice + 1) * rows_per_slice, height) * width
	_next_decay_slice = (_next_decay_slice + 1) % _decay_slices
	for index in range(first, last):
		fight[index] *= fight_factor
		path_wear[index] *= path_factor
	for colony in colony_count:
		for index in range(first + colony * cell_count, last + colony * cell_count):
			going_out[index] *= factor
			going_home[index] *= factor


# --- Paths (unobstructed areas) ---------------------------------------------

## Wears the ground under `world_position` a little (an ant walking over it).
func wear_path(world_position: Vector2, amount: float) -> void:
	var index := cell_index(world_position)
	if index != -1:
		path_wear[index] = minf(path_wear[index] + amount, _max_path_wear)


## True if the cell under `world_position` is worn enough to be an unobstructed path.
func is_unobstructed(world_position: Vector2) -> bool:
	var index := cell_index(world_position)
	return index != -1 and path_wear[index] >= unobstructed_wear


# --- Obstacles --------------------------------------------------------------

## True if `world_position` is inside an obstacle or outside the map.
func is_obstacle(world_position: Vector2) -> bool:
	var index := cell_index(world_position)
	return index == -1 or obstacle[index] == 1


## Turns the cell at `index` into an obstacle (removing its food and pheromones) or clears it.
func set_obstacle(index: int, is_blocked: bool) -> void:
	if is_blocked:
		set_food(index, 0)
		for colony in colony_count:
			going_out[index + colony * cell_count] = 0.0
			going_home[index + colony * cell_count] = 0.0
		fight[index] = 0.0
		path_wear[index] = 0.0
	obstacle[index] = 1 if is_blocked else 0
	terrain_version += 1


# --- Food -------------------------------------------------------------------

## Sets the food in the cell at `index`, keeping the totals up to date.
func set_food(index: int, amount: int) -> void:
	var change := amount - food[index]
	if change == 0:
		return
	food[index] = amount
	total_food += change
	_food_in_region[_region_index(index % width, index / width)] += change
	terrain_version += 1


## Takes 1 unit of food from the cell under `world_position`. Returns false if it had none.
func take_food(world_position: Vector2) -> bool:
	var index := cell_index(world_position)
	if index == -1 or food[index] == 0:
		return false
	set_food(index, food[index] - 1)
	return true


## Center of the closest cell with food within `radius` pixels, or NO_FOOD.
func find_food_near(world_position: Vector2, radius: float) -> Vector2:
	if not _regions_have_food(world_position, radius):
		return NO_FOOD
	var center := cell_coords(world_position)
	var radius_in_cells := ceili(radius / cell_size)
	var closest := NO_FOOD
	var closest_distance := radius
	for row in range(maxi(center.y - radius_in_cells, 0), mini(center.y + radius_in_cells + 1, height)):
		for column in range(maxi(center.x - radius_in_cells, 0), mini(center.x + radius_in_cells + 1, width)):
			if food[row * width + column] == 0:
				continue
			var food_position := (Vector2(column, row) + Vector2(0.5, 0.5)) * cell_size
			var distance := world_position.distance_to(food_position)
			if distance <= closest_distance:
				closest = food_position
				closest_distance = distance
	return closest


## Quick check: is there any food in the regions touching the search area?
func _regions_have_food(world_position: Vector2, radius: float) -> bool:
	var region_size := _region_cells * cell_size
	var first := Vector2i(((world_position - Vector2(radius, radius)) / region_size).floor())
	var last := Vector2i(((world_position + Vector2(radius, radius)) / region_size).floor())
	var region_rows := _food_in_region.size() / _region_columns
	for row in range(maxi(first.y, 0), mini(last.y + 1, region_rows)):
		for column in range(maxi(first.x, 0), mini(last.x + 1, _region_columns)):
			if _food_in_region[row * _region_columns + column] > 0:
				return true
	return false


func _region_index(column: int, row: int) -> int:
	return (row / _region_cells) * _region_columns + column / _region_cells


## Converts a pixel position to an index in the arrays, or -1 if outside the map.
func cell_index(world_position: Vector2) -> int:
	if world_position.x < 0.0 or world_position.y < 0.0:
		return -1
	var column := int(world_position.x / cell_size)
	var row := int(world_position.y / cell_size)
	if column >= width or row >= height:
		return -1
	return row * width + column
