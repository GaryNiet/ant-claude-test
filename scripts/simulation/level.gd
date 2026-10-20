class_name Level
extends RefCounted
## A level: the starting layout of the map. Saved as a plain text file (*.level) that can
## also be edited by hand. It remembers the map size, the nest, the starting colony size,
## obstacles and food. It does not remember pheromones, ants or enemies.
##
## File format:
##     ; comment lines start with ;
##     name = My level
##     cell_size = 8
##     starting_ants = 100
##     nest = 80, 45                <- column, row of the nest cell
##     map:                         <- then one text line per row of cells:
##     ......##.....3a...
##       "." = empty   "#" = obstacle
##       "1".."9" = 1..9 food, "a".."z" = 10..35 food (more than 35 is saved as 35)
## The map size is simply the number of characters per line and the number of lines.

const FOOD_SYMBOLS := "123456789abcdefghijklmnopqrstuvwxyz"
const EMPTY_SYMBOL := "."
const OBSTACLE_SYMBOL := "#"

var name := "Untitled"
var width := 0          ## cells
var height := 0         ## cells
var cell_size := 8.0    ## pixels per cell
var starting_ants := 100
var nest_cell := Vector2i.ZERO
var food := PackedInt32Array()      ## per cell, row by row
var obstacle := PackedByteArray()   ## per cell, 1 = obstacle


## Reads a level file. Returns null (and prints an error) if it can't be read.
static func load_file(path: String) -> Level:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("Can't open level %s (error %d)" % [path, FileAccess.get_open_error()])
		return null
	var level := Level.new()
	var map_rows := PackedStringArray()
	var reading_map := false
	while not file.eof_reached():
		var line := file.get_line().strip_edges()
		if line.is_empty() or line.begins_with(";"):
			continue
		if reading_map:
			map_rows.append(line)
		elif line == "map:":
			reading_map = true
		else:
			level._read_setting(line)
	if not level._read_map(map_rows):
		push_error("Level %s has an empty or uneven map" % path)
		return null
	return level


## Captures the current map of a running simulation as a level.
static func from_simulation(sim: ColonySimulation, level_name: String) -> Level:
	var level := Level.new()
	level.name = level_name
	level.width = sim.grid.width
	level.height = sim.grid.height
	level.cell_size = sim.grid.cell_size
	level.starting_ants = sim.level.starting_ants
	level.nest_cell = sim.grid.cell_coords(sim.nest_position)
	level.food = sim.grid.food.duplicate()
	level.obstacle = sim.grid.obstacle.duplicate()
	return level


## Writes the level to `path`. Returns OK or an error code.
func save_file(path: String) -> Error:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_line("; Ant colony level. Map: \".\" empty, \"#\" obstacle, 1-9 / a-z = 1-35 food.")
	file.store_line("name = %s" % name)
	file.store_line("cell_size = %s" % cell_size)
	file.store_line("starting_ants = %d" % starting_ants)
	file.store_line("nest = %d, %d" % [nest_cell.x, nest_cell.y])
	file.store_line("map:")
	for row in height:
		var line := ""
		for column in width:
			line += _symbol_for_cell(row * width + column)
		file.store_line(line)
	return OK


func _symbol_for_cell(index: int) -> String:
	if obstacle[index] == 1:
		return OBSTACLE_SYMBOL
	if food[index] <= 0:
		return EMPTY_SYMBOL
	return FOOD_SYMBOLS[mini(food[index], FOOD_SYMBOLS.length()) - 1]


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
		"starting_ants":
			starting_ants = value.to_int()
		"nest":
			var numbers := value.split(",")
			nest_cell = Vector2i(numbers[0].to_int(), numbers[1].to_int())
		_:
			push_error("Level: unknown setting '%s'" % key)


func _read_map(rows: PackedStringArray) -> bool:
	if rows.is_empty():
		return false
	width = rows[0].length()
	height = rows.size()
	food.resize(width * height)
	obstacle.resize(width * height)
	for row in height:
		if rows[row].length() != width:
			return false
		for column in width:
			var symbol := rows[row][column]
			var index := row * width + column
			if symbol == OBSTACLE_SYMBOL:
				obstacle[index] = 1
			elif symbol != EMPTY_SYMBOL:
				food[index] = FOOD_SYMBOLS.find(symbol) + 1
	return true
