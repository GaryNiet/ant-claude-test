class_name Level
extends RefCounted
## A level: the starting layout of the map. Saved as a plain text file (*.level) that can
## also be edited by hand. It remembers the map size, the nest, the starting colony size,
## the ground tiles and the food. It does not remember pheromones, ants or enemies.
##
## The ground is made of tiles; food lies on top of it in smaller cells
## (a tile is tile_cells x tile_cells cells).
##
## File format:
##     ; comment lines start with ;
##     name = My level
##     cell_size = 8                <- pixels per cell
##     tile_cells = 4               <- cells per tile side (4 x 8 px = 32 px tiles)
##     starting_ants = 100
##     nest = 80, 45                <- column, row of the nest CELL
##     tiles:                       <- then one text line per row of TILES:
##     ddddggggwwww##dd
##       "d" = dirt   "g" = grass   "w" = water   "#" = obstacle
##     food:                        <- then one text line per row of CELLS:
##     ..........3a.....
##       "." = no food   "1".."9" = 1..9 food, "a".."z" = 10..35 food (more is saved as 35)
## The map size is the number of characters per line and the number of lines of `tiles:`.

const FOOD_SYMBOLS := "123456789abcdefghijklmnopqrstuvwxyz"
const NO_FOOD_SYMBOL := "."
const GROUND_SYMBOLS := {
	"d": GroundMap.Type.DIRT,
	"g": GroundMap.Type.GRASS,
	"w": GroundMap.Type.WATER,
	"#": GroundMap.Type.OBSTACLE,
}

var name := "Untitled"
var columns := 0        ## tiles
var rows := 0           ## tiles
var cell_size := 8.0    ## pixels per cell
var tile_cells := 4     ## cells per tile side
var starting_ants := 100
var nest_cell := Vector2i.ZERO
var tiles := PackedByteArray()      ## ground type per tile, row by row
var food := PackedInt32Array()      ## food per cell, row by row


## Map size in cells.
func width() -> int:
	return columns * tile_cells


func height() -> int:
	return rows * tile_cells


## Reads a level file. Returns null (and prints an error) if it can't be read.
static func load_file(path: String) -> Level:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Can't open level %s (error %d)" % [path, FileAccess.get_open_error()])
		return null
	var level := Level.new()
	var tile_rows := PackedStringArray()
	var food_rows := PackedStringArray()
	var section := ""  ## "", "tiles:" or "food:"
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with(";"):
			continue
		if line == "tiles:" or line == "food:":
			section = line
		elif section == "tiles:":
			tile_rows.append(line)
		elif section == "food:":
			food_rows.append(line)
		else:
			level._read_setting(line)
	if not level._read_tiles(tile_rows):
		push_error("Level %s has an empty or uneven tile map" % path)
		return null
	if not level._read_food(food_rows):
		push_error("Level %s: the food map must be %d x %d cells" % [path, level.width(), level.height()])
		return null
	return level


## Captures the current map of a running simulation as a level.
static func from_simulation(sim: ColonySimulation, level_name: String) -> Level:
	var level := Level.new()
	level.name = level_name
	level.columns = sim.ground.columns
	level.rows = sim.ground.rows
	level.cell_size = sim.grid.cell_size
	level.tile_cells = sim.ground.tile_cells
	level.starting_ants = sim.level.starting_ants
	level.nest_cell = sim.grid.cell_coords(sim.nest_position)
	level.tiles = sim.ground.tiles.duplicate()
	level.food = sim.grid.food.duplicate()
	return level


## Writes the level to `path`. Returns OK or an error code.
func save_file(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_line("; Ant colony level. Tiles: d dirt, g grass, w water, # obstacle. Food: . none, 1-9 / a-z = 1-35.")
	file.store_line("name = %s" % name)
	file.store_line("cell_size = %s" % cell_size)
	file.store_line("tile_cells = %d" % tile_cells)
	file.store_line("starting_ants = %d" % starting_ants)
	file.store_line("nest = %d, %d" % [nest_cell.x, nest_cell.y])
	file.store_line("tiles:")
	for row in rows:
		var line := ""
		for column in columns:
			line += GROUND_SYMBOLS.find_key(tiles[row * columns + column])
		file.store_line(line)
	file.store_line("food:")
	for row in height():
		var line := ""
		for column in width():
			line += _food_symbol(food[row * width() + column])
		file.store_line(line)
	return OK


func _food_symbol(amount: int) -> String:
	if amount <= 0:
		return NO_FOOD_SYMBOL
	return FOOD_SYMBOLS[mini(amount, FOOD_SYMBOLS.length()) - 1]


func _read_setting(line: String) -> void:
	var parts := line.split("=", false, 1)
	if parts.size() != 2:
		push_error("Level: can't read line '%s'" % line)
		return
	var key := parts[0].strip_edges()
	var value := parts[1].strip_edges()
	match key:
		"name":
			name = value
		"cell_size":
			cell_size = value.to_float()
		"tile_cells":
			tile_cells = value.to_int()
		"starting_ants":
			starting_ants = value.to_int()
		"nest":
			var numbers := value.split(",")
			nest_cell = Vector2i(numbers[0].to_int(), numbers[1].to_int())
		_:
			push_error("Level: unknown setting '%s'" % key)


func _read_tiles(lines: PackedStringArray) -> bool:
	if lines.is_empty():
		return false
	columns = lines[0].length()
	rows = lines.size()
	tiles.resize(columns * rows)
	for row in rows:
		if lines[row].length() != columns:
			return false
		for column in columns:
			var symbol := lines[row][column]
			if not GROUND_SYMBOLS.has(symbol):
				push_error("Level: unknown tile '%s' (use d, g, w or #)" % symbol)
				return false
			tiles[row * columns + column] = GROUND_SYMBOLS[symbol]
	return true


## A level without a `food:` section has no food.
func _read_food(lines: PackedStringArray) -> bool:
	food.resize(width() * height())
	if lines.is_empty():
		return true
	if lines.size() != height():
		return false
	for row in height():
		if lines[row].length() != width():
			return false
		for column in width():
			var symbol := lines[row][column]
			if symbol != NO_FOOD_SYMBOL:
				food[row * width() + column] = FOOD_SYMBOLS.find(symbol) + 1
	return true
