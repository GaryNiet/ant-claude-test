extends Node2D
## Runs the simulation at a fixed rate and draws it: pheromones as colored glow,
## food as green dots, the nest as a purple dot and the ants as small dots.

var simulation: ColonySimulation
var is_paused := false

var _tick_length: float
var _max_ticks_per_frame: int
var _time_not_yet_simulated := 0.0

var _pheromone_image: Image
var _pheromone_texture: ImageTexture
var _pheromone_pixels := PackedByteArray()

# Drawing settings
var _nest_color: Color = GameSettings.get_color("colors", "nest")
var _ant_color: Color = GameSettings.get_color("colors", "ant")
var _ant_with_food_color: Color = GameSettings.get_color("colors", "ant_with_food")
var _food_color: Color = GameSettings.get_color("colors", "food")
var _going_out_color: Color = GameSettings.get_color("colors", "going_out_pheromone")
var _going_home_color: Color = GameSettings.get_color("colors", "going_home_pheromone")
var _ant_radius: float = GameSettings.get_setting("display", "ant_radius")
var _nest_draw_radius: float = GameSettings.get_setting("display", "nest_draw_radius")
var _food_radius_per_unit: float = GameSettings.get_setting("display", "food_radius_per_unit")
var _pheromone_full_brightness: float = GameSettings.get_setting("display", "pheromone_full_brightness")


func _ready() -> void:
	var ticks_per_second: float = GameSettings.get_setting("simulation", "ticks_per_second")
	_tick_length = 1.0 / ticks_per_second
	_max_ticks_per_frame = GameSettings.get_setting("simulation", "max_ticks_per_frame")
	start_new_simulation()


func start_new_simulation() -> void:
	simulation = ColonySimulation.new()
	var grid := simulation.pheromones
	_pheromone_pixels.resize(grid.width * grid.height * 3)
	_pheromone_pixels.fill(0)
	_pheromone_image = Image.create_from_data(grid.width, grid.height, false, Image.FORMAT_RGB8, _pheromone_pixels)
	_pheromone_texture = ImageTexture.create_from_image(_pheromone_image)
	_time_not_yet_simulated = 0.0


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		is_paused = not is_paused
	if Input.is_action_just_pressed("restart"):
		start_new_simulation()
	if not is_paused and _run_simulation_ticks(delta) > 0:
		_update_pheromone_texture()
	_fit_map_to_window()
	queue_redraw()


## Runs as many fixed-length ticks as fit in the time that passed. Returns how many ran.
func _run_simulation_ticks(delta: float) -> int:
	_time_not_yet_simulated += delta
	var ticks_run := 0
	while _time_not_yet_simulated >= _tick_length and ticks_run < _max_ticks_per_frame:
		simulation.step(_tick_length)
		_time_not_yet_simulated -= _tick_length
		ticks_run += 1
	if ticks_run == _max_ticks_per_frame:
		_time_not_yet_simulated = 0.0  # computer too slow: drop the backlog instead of freezing
	return ticks_run


## Scales and centers the map so it fills the window without stretching.
func _fit_map_to_window() -> void:
	var map_size := simulation.pheromones.world_size()
	var window_size := get_viewport_rect().size
	var zoom := minf(window_size.x / map_size.x, window_size.y / map_size.y)
	scale = Vector2(zoom, zoom)
	position = (window_size - map_size * zoom) / 2.0


## Turns the pheromone grid into an image: one pixel per cell, the two colors added together.
func _update_pheromone_texture() -> void:
	var grid := simulation.pheromones
	for index in grid.going_out.size():
		var out_brightness := minf(grid.going_out[index] / _pheromone_full_brightness, 1.0)
		var home_brightness := minf(grid.going_home[index] / _pheromone_full_brightness, 1.0)
		var color := _going_out_color * out_brightness + _going_home_color * home_brightness
		_pheromone_pixels[index * 3] = int(minf(color.r, 1.0) * 255.0)
		_pheromone_pixels[index * 3 + 1] = int(minf(color.g, 1.0) * 255.0)
		_pheromone_pixels[index * 3 + 2] = int(minf(color.b, 1.0) * 255.0)
	_pheromone_image.set_data(grid.width, grid.height, false, Image.FORMAT_RGB8, _pheromone_pixels)
	_pheromone_texture.update(_pheromone_image)


func _draw() -> void:
	draw_texture_rect(_pheromone_texture, Rect2(Vector2.ZERO, simulation.pheromones.world_size()), false)
	for food in simulation.food_sources:
		draw_circle(food.position, sqrt(food.amount) * _food_radius_per_unit * 2.0, _food_color)
	draw_circle(simulation.nest_position, _nest_draw_radius, _nest_color)
	for ant in simulation.ants:
		var color := _ant_with_food_color if ant.is_carrying_food() else _ant_color
		draw_circle(ant.position, _ant_radius, color)
