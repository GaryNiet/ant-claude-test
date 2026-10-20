class_name PheromoneGrid
extends RefCounted
## The 2D plane of the simulation: a grid of cells, each holding two pheromone values.
##
## - "going out"  : laid by ants walking away from the nest (exploring / gathering)
## - "going home" : laid by ants carrying food back to the nest
##
## Values fade a little every tick (exponential decay with a configurable half-life),
## so busy paths stay strong while abandoned ones disappear.

enum Kind { GOING_OUT, GOING_HOME }

var width: int          ## number of cells horizontally
var height: int         ## number of cells vertically
var cell_size: float    ## size of one cell in pixels
var max_strength: float

var going_out := PackedFloat32Array()
var going_home := PackedFloat32Array()

var _decay_per_second_log: float  ## precomputed for the decay formula


func _init() -> void:
	width = GameSettings.get_setting("map", "grid_width")
	height = GameSettings.get_setting("map", "grid_height")
	cell_size = GameSettings.get_setting("map", "cell_size")
	max_strength = GameSettings.get_setting("pheromones", "max_strength")
	var half_life: float = GameSettings.get_setting("pheromones", "half_life")
	_decay_per_second_log = log(0.5) / half_life
	going_out.resize(width * height)
	going_home.resize(width * height)


## Size of the whole map in pixels.
func world_size() -> Vector2:
	return Vector2(width, height) * cell_size


## Adds `amount` of pheromone `kind` to the cell under `world_position`.
func deposit(kind: Kind, world_position: Vector2, amount: float) -> void:
	var index := _cell_index(world_position)
	if index == -1:
		return
	if kind == Kind.GOING_OUT:
		going_out[index] = minf(going_out[index] + amount, max_strength)
	else:
		going_home[index] = minf(going_home[index] + amount, max_strength)


## Returns the strength of pheromone `kind` at `world_position` (0 outside the map).
func sample(kind: Kind, world_position: Vector2) -> float:
	var index := _cell_index(world_position)
	if index == -1:
		return 0.0
	if kind == Kind.GOING_OUT:
		return going_out[index]
	return going_home[index]


## Makes every pheromone fade by the amount matching `delta` seconds.
func decay(delta: float) -> void:
	var factor := exp(_decay_per_second_log * delta)
	for index in going_out.size():
		going_out[index] *= factor
		going_home[index] *= factor


func clear() -> void:
	going_out.fill(0.0)
	going_home.fill(0.0)


## Converts a pixel position to an index in the arrays, or -1 if outside the map.
func _cell_index(world_position: Vector2) -> int:
	var x := int(world_position.x / cell_size)
	var y := int(world_position.y / cell_size)
	if world_position.x < 0 or world_position.y < 0 or x >= width or y >= height:
		return -1
	return y * width + x
