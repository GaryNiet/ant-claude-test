class_name GroundMap
extends RefCounted
## The ground of the map, in tiles: what the ground IS (dirt, grass, water, obstacle, nest).
## What lies ON the ground (food, pheromones) is stored per cell in MapGrid, which is finer:
## one tile covers tile_cells x tile_cells cells.
##
## The nest is not stored in `tiles`: it is an overlay that grows with the colony and
## covers the ground below it. When it shrinks, the original ground shows again.
## Whether a tile can be walked on comes from [ground] walkable in game_settings.cfg.

enum Type { DIRT, GRASS, WATER, OBSTACLE, NEST }

## Names used in game_settings.cfg ([colors], [ground] walkable) and for tile image files.
const TYPE_NAMES := {
	Type.DIRT: "dirt",
	Type.GRASS: "grass",
	Type.WATER: "water",
	Type.OBSTACLE: "obstacle",
	Type.NEST: "nest",
}

var columns: int        ## number of tiles horizontally
var rows: int           ## number of tiles vertically
var tile_cells: int     ## cells per tile side
var tile_size: float    ## pixels per tile side
var tiles := PackedByteArray()       ## ground type per tile (never NEST)
var nest_tiles := PackedByteArray()  ## 1 = covered by the nest
var version := 0        ## goes up whenever a tile changes (tells the view to redraw)

var _walkable := {}     ## Type -> true for the types ants and enemies can walk on


func _init(tile_columns: int, tile_rows: int, cells_per_tile: int, cell_size: float, ground: PackedByteArray) -> void:
	columns = tile_columns
	rows = tile_rows
	tile_cells = cells_per_tile
	tile_size = cells_per_tile * cell_size
	tiles = ground.duplicate()
	nest_tiles.resize(columns * rows)
	for type_name in GameSettings.get_list("ground", "walkable"):
		_walkable[type_from_name(type_name)] = true


static func type_from_name(type_name: String) -> Type:
	return TYPE_NAMES.find_key(type_name)


## What the tile shows: the nest if the nest covers it, otherwise its ground.
func type_at(column: int, row: int) -> Type:
	var index := row * columns + column
	return Type.NEST if nest_tiles[index] == 1 else tiles[index]


func is_walkable(column: int, row: int) -> bool:
	return _walkable.has(type_at(column, row))


func is_walkable_type(type: Type) -> bool:
	return _walkable.has(type)


## Column and row of the tile under `world_position` (may be outside the map).
func tile_coords(world_position: Vector2) -> Vector2i:
	return Vector2i(floori(world_position.x / tile_size), floori(world_position.y / tile_size))


func tile_center(column: int, row: int) -> Vector2:
	return (Vector2(column, row) + Vector2(0.5, 0.5)) * tile_size


func is_inside(column: int, row: int) -> bool:
	return column >= 0 and row >= 0 and column < columns and row < rows


## Tiles whose center is within `radius` pixels of `center`, plus the tile under `center`.
func tiles_in_circle(center: Vector2, radius: float) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var middle := tile_coords(center)
	var reach := ceili(radius / tile_size) + 1
	for row in range(maxi(middle.y - reach, 0), mini(middle.y + reach + 1, rows)):
		for column in range(maxi(middle.x - reach, 0), mini(middle.x + reach + 1, columns)):
			var is_under_center := column == middle.x and row == middle.y
			if is_under_center or tile_center(column, row).distance_to(center) <= radius:
				found.append(Vector2i(column, row))
	return found


## Changes the ground of a tile. Returns true if it changed.
func set_ground(column: int, row: int, type: Type) -> bool:
	var index := row * columns + column
	if tiles[index] == type:
		return false
	tiles[index] = type
	version += 1
	return true


## Sets which tiles the nest covers. Returns the tiles that changed.
func set_nest_tiles(covered: PackedByteArray) -> Array[Vector2i]:
	var changed: Array[Vector2i] = []
	for index in covered.size():
		if covered[index] != nest_tiles[index]:
			changed.append(Vector2i(index % columns, index / columns))
	if not changed.is_empty():
		nest_tiles = covered
		version += 1
	return changed


## For tile images: which sides (n, e, s, w) of the tile touch a different type, and the
## most common of those types. Returns ["", ""] when all 4 neighbours are the same type.
## Example: a dirt tile with grass above and to the right gives ["grass", "ne"].
func transition(column: int, row: int) -> Array[String]:
	var own_type := type_at(column, row)
	var sides := {"n": Vector2i(0, -1), "e": Vector2i(1, 0), "s": Vector2i(0, 1), "w": Vector2i(-1, 0)}
	var side_types := {}  ## side letter -> neighbour type
	var counts := {}      ## neighbour type -> number of sides
	for side in sides:
		var neighbour: Vector2i = Vector2i(column, row) + sides[side]
		if not is_inside(neighbour.x, neighbour.y):
			continue  # the map edge is no transition
		var neighbour_type := type_at(neighbour.x, neighbour.y)
		if neighbour_type != own_type:
			side_types[side] = neighbour_type
			counts[neighbour_type] = counts.get(neighbour_type, 0) + 1
	if counts.is_empty():
		return ["", ""]
	var main_type: Type = counts.keys()[0]
	for type in counts:
		if counts[type] > counts[main_type]:
			main_type = type
	var letters := ""
	for side in side_types:
		if side_types[side] == main_type:
			letters += side
	return [TYPE_NAMES[main_type], letters]
