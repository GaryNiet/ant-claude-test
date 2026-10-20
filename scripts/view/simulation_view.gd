extends Node2D
## Runs the simulation at a fixed rate and scales the map to fit the window.
## The drawing itself is done by the child layers (pheromones, terrain, ants, brush).

signal stepped  ## emitted after one or more simulation ticks ran this frame

var simulation: ColonySimulation
var is_paused := false

var _tick_length: float
var _max_ticks_per_frame: int
var _time_not_yet_simulated := 0.0


# Done in _enter_tree (not _ready) so the simulation exists before the child layers start:
# Godot readies children before their parent.
func _enter_tree() -> void:
	var ticks_per_second: float = GameSettings.get_setting("simulation", "ticks_per_second")
	_tick_length = 1.0 / ticks_per_second
	_max_ticks_per_frame = GameSettings.get_setting("simulation", "max_ticks_per_frame")
	start_new_simulation()


func start_new_simulation() -> void:
	simulation = ColonySimulation.new()
	_time_not_yet_simulated = 0.0
	stepped.emit()


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("pause"):
		is_paused = not is_paused
	if Input.is_action_just_pressed("restart"):
		start_new_simulation()
	if not is_paused and _run_simulation_ticks(delta) > 0:
		stepped.emit()
	_fit_map_to_window()


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
	var map_size := simulation.grid.world_size()
	var window_size := get_viewport_rect().size
	var zoom := minf(window_size.x / map_size.x, window_size.y / map_size.y)
	scale = Vector2(zoom, zoom)
	position = (window_size - map_size * zoom) / 2.0
