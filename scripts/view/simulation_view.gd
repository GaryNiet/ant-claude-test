extends Node2D
## Runs the simulation at a fixed rate, loads levels, and handles the camera (zoom and pan)
## and selection (what the player clicked on). The drawing itself is done by the child
## layers (pheromones, terrain, ants, brush).

signal stepped        ## emitted after one or more simulation ticks ran this frame
signal level_loaded   ## emitted after a level was loaded (or restarted)

const SELECTED_NEST := "nest"  ## value of `selection` when the nest is selected

var simulation: ColonySimulation
var level_path := ""          ## file the current level was loaded from
var is_paused := false
var play_time := 0.0          ## seconds played on this level; stops while paused
## What the player clicked on: an Ant, an Enemy, SELECTED_NEST, a Vector2i cell, or null.
var selection: Variant = null

var _tick_length: float
var _max_ticks_per_frame: int
var _game_speed: float = GameSettings.get_setting("simulation", "game_speed")
var _time_not_yet_simulated := 0.0

# Camera
var _zoom_step: float = GameSettings.get_setting("camera", "zoom_step")
var _min_zoom: float = GameSettings.get_setting("camera", "min_zoom")
var _max_zoom: float = GameSettings.get_setting("camera", "max_zoom")
var _pan_speed: float = GameSettings.get_setting("camera", "pan_speed")
var _pick_radius: float = GameSettings.get_setting("camera", "inspect_pick_radius")
var _toolbar_height: float = GameSettings.get_setting("ui", "toolbar_height")
var _side_panel_width: float = GameSettings.get_setting("ui", "side_panel_width")
var _fit_zoom := 1.0           ## zoom at which the whole map fits the map area
var _needs_fit := true


# Done in _enter_tree (not _ready) so the simulation exists before the child layers start:
# Godot readies children before their parent.
func _enter_tree() -> void:
	var ticks_per_second: float = GameSettings.get_setting("simulation", "ticks_per_second")
	_tick_length = 1.0 / ticks_per_second
	_max_ticks_per_frame = GameSettings.get_setting("simulation", "max_ticks_per_frame")
	if not load_level(GameSettings.get_setting("game", "start_level")):
		push_error("Could not load the start level; check [game] start_level")
	get_viewport().size_changed.connect(func() -> void: _needs_fit = true)


## Starts a new game on the level stored in `path`. Returns false if it can't be read.
func load_level(path: String) -> bool:
	var level := Level.load_file(path)
	if level == null:
		return false
	level_path = path
	simulation = ColonySimulation.new(level)
	play_time = 0.0
	selection = null
	_time_not_yet_simulated = 0.0
	_needs_fit = true
	stepped.emit()
	level_loaded.emit()
	return true


func restart_level() -> void:
	load_level(level_path)


## The part of the window where the map is shown (not covered by the tool bar or side panel).
func map_area() -> Rect2:
	var window_size := get_viewport_rect().size
	return Rect2(0.0, _toolbar_height, window_size.x - _side_panel_width, window_size.y - _toolbar_height)


## Zooms so the whole map fits the map area, centered.
func fit_map_to_area() -> void:
	var area := map_area()
	var map_size := simulation.grid.world_size()
	_fit_zoom = minf(area.size.x / map_size.x, area.size.y / map_size.y)
	scale = Vector2(_fit_zoom, _fit_zoom)
	position = area.position + (area.size - map_size * _fit_zoom) / 2.0


func _process(delta: float) -> void:
	if _needs_fit:
		fit_map_to_area()
		_needs_fit = false
	_pan_with_keys(delta)
	if not is_paused:
		play_time += delta
		if _run_simulation_ticks(delta) > 0:
			stepped.emit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		is_paused = not is_paused
	elif event.is_action_pressed("restart"):
		restart_level()
	elif event.is_action_pressed("zoom_in"):
		_zoom_at(get_viewport().get_mouse_position(), _zoom_step)
	elif event.is_action_pressed("zoom_out"):
		_zoom_at(get_viewport().get_mouse_position(), 1.0 / _zoom_step)
	elif event is InputEventMouseMotion and Input.is_action_pressed("pan"):
		position += event.relative


## Runs as many fixed-length ticks as fit in the time that passed. Returns how many ran.
## Each tick advances the simulation by tick length x game speed.
func _run_simulation_ticks(delta: float) -> int:
	_time_not_yet_simulated += delta
	var ticks_run := 0
	while _time_not_yet_simulated >= _tick_length and ticks_run < _max_ticks_per_frame:
		simulation.step(_tick_length * _game_speed)
		_time_not_yet_simulated -= _tick_length
		ticks_run += 1
	if ticks_run == _max_ticks_per_frame:
		_time_not_yet_simulated = 0.0  # computer too slow: drop the backlog instead of freezing
	return ticks_run


## Zooms by `factor`, keeping the map point under `screen_point` in place.
func _zoom_at(screen_point: Vector2, factor: float) -> void:
	var map_point := (screen_point - position) / scale.x
	var zoom := clampf(scale.x * factor, _fit_zoom * _min_zoom, _max_zoom)
	scale = Vector2(zoom, zoom)
	position = screen_point - map_point * zoom


func _pan_with_keys(delta: float) -> void:
	if get_viewport().gui_get_focus_owner() is LineEdit:
		return  # typing a file name, not panning
	var direction := Input.get_vector("pan_left", "pan_right", "pan_up", "pan_down")
	position -= direction * _pan_speed * delta


# --- Selection ----------------------------------------------------------------

## Selects whatever is at map position `spot`: an enemy, an ant, the nest, or else the cell.
func select_at(spot: Vector2) -> void:
	for enemy in simulation.enemies:
		if enemy.position.distance_to(spot) <= simulation.enemy_settings.radius:
			selection = enemy
			return
	var closest_ant: Ant = null
	var closest_distance := _pick_radius
	for ant in simulation.ants:
		var distance := ant.position.distance_to(spot)
		if distance <= closest_distance:
			closest_ant = ant
			closest_distance = distance
	if closest_ant != null:
		selection = closest_ant
	elif spot.distance_to(simulation.nest_position) <= simulation.nest_radius:
		selection = SELECTED_NEST
	elif simulation.grid.cell_index(spot) != -1:
		selection = simulation.grid.cell_coords(spot)
	else:
		selection = null
