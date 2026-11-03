extends Node2D
## Runs the simulation at a fixed rate, loads levels, and handles the camera (zoom and pan),
## the two views and selection (what the player clicked on). The drawing itself is done by
## the layers.
##
## Two views of the same map:
##   isometric (default)  the map is seen at an angle: the ground is turned and squashed,
##                        ants, spiders, rocks and the nest are drawn as sprites
##   debug                the flat top-down view with simple shapes and colors
## The map layers live in the MapSpace child, whose transform is the projection (none in the
## debug view), so they draw in map pixels in both views. The sprite layer draws on top,
## upright, at the projected positions.

signal stepped        ## emitted after one or more simulation ticks ran this frame
signal level_loaded   ## emitted after a level was loaded (or restarted)
signal view_mode_changed  ## emitted when switching between the isometric and debug views
signal cancel_requested   ## a right click (not a drag): close the menus, back to the Inspect tool


var simulation: ColonySimulation
var level_path := ""          ## file the current level was loaded from
var is_paused := false
var play_time := 0.0          ## seconds played on this level; stops while paused
## What the player clicked on: an Ant, a Creature, a MapObject, a Colony (its nest), a Vector2i
## cell, or null.
var selection: Variant = null
var is_iso_view := false
var show_pheromones: bool = GameSettings.get_setting("display", "show_pheromones")

@onready var map_space: Node2D = $MapSpace
@onready var _debug_shapes: Node2D = $MapSpace/AntLayer
@onready var _debug_food: Node2D = $MapSpace/FoodLayer
@onready var _moss: Node2D = $MapSpace/MossLayer
@onready var _sprites: Node2D = $SpriteLayer
@onready var _pheromones: Node2D = $MapSpace/PheromoneLayer

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
var _click_max_drag: float = GameSettings.get_setting("camera", "click_max_drag")
var _is_panning := false        ## the pan button went down over the map
var _dragged_since_press := 0.0 ## screen pixels the mouse moved since the cancel button went down
var _toolbar_height: float = GameSettings.get_setting("ui", "toolbar_height")
var _side_panel_width: float = GameSettings.get_setting("ui", "side_panel_width")
var _fit_zoom := 1.0           ## zoom at which the whole map fits the map area
var _needs_fit := true

# Isometric projection
var _iso_rotation: float = deg_to_rad(GameSettings.get_setting("iso_view", "rotation_degrees"))
var _iso_squash: float = GameSettings.get_setting("iso_view", "vertical_squash")


# Done in _enter_tree (not _ready) so the simulation exists before the child layers start:
# Godot readies children before their parent.
func _enter_tree() -> void:
	var ticks_per_second: float = GameSettings.get_setting("simulation", "ticks_per_second")
	_tick_length = 1.0 / ticks_per_second
	_max_ticks_per_frame = GameSettings.get_setting("simulation", "max_ticks_per_frame")
	if not load_level(GameSession.current_level_path()):
		push_error("Could not load the level %s; check [menu] levels" % GameSession.current_level_path())
	get_viewport().size_changed.connect(func() -> void: _needs_fit = true)


func _ready() -> void:
	set_iso_view(GameSettings.get_setting("iso_view", "start_in_iso_view"))
	set_pheromones_visible(show_pheromones)


## Shows or hides the pheromone trails (in both views).
func set_pheromones_visible(shown: bool) -> void:
	show_pheromones = shown
	_pheromones.visible = shown
	stepped.emit()  # redraw the trails right away when they are shown again


## Switches between the isometric view (true) and the flat debug view (false).
func set_iso_view(iso: bool) -> void:
	is_iso_view = iso
	map_space.transform = projection()
	_debug_shapes.visible = not iso
	_debug_food.visible = not iso
	_moss.visible = iso
	_sprites.visible = iso
	_needs_fit = true
	view_mode_changed.emit()


## How map pixels are placed on screen (before zoom and pan): in the isometric view the map
## is turned by rotation_degrees, then squashed vertically by vertical_squash.
func projection() -> Transform2D:
	if not is_iso_view:
		return Transform2D.IDENTITY
	return Transform2D(_iso_rotation, Vector2.ZERO).scaled(Vector2(1.0, _iso_squash))


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


## The part of the window where the map is shown: above the tool bar, left of the side panel.
func map_area() -> Rect2:
	var window_size := get_viewport_rect().size
	return Rect2(0.0, 0.0, window_size.x - _side_panel_width, window_size.y - _toolbar_height)


## Zooms so the whole map fits the map area, centered.
func fit_map_to_area() -> void:
	var area := map_area()
	var bounds := _projected_map_bounds()
	_fit_zoom = minf(area.size.x / bounds.size.x, area.size.y / bounds.size.y)
	scale = Vector2(_fit_zoom, _fit_zoom)
	position = area.get_center() - bounds.get_center() * _fit_zoom


## The rectangle the map covers once projected (a diamond's bounding box in the iso view).
func _projected_map_bounds() -> Rect2:
	var map_size := simulation.grid.world_size()
	var corners := [Vector2.ZERO, Vector2(map_size.x, 0.0), map_size, Vector2(0.0, map_size.y)]
	var bounds := Rect2(map_space.transform * corners[0], Vector2.ZERO)
	for corner in corners:
		bounds = bounds.expand(map_space.transform * corner)
	return bounds


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
	elif event.is_action_pressed("toggle_view"):
		set_iso_view(not is_iso_view)
	elif event.is_action_pressed("toggle_pheromones"):
		set_pheromones_visible(not show_pheromones)
	elif event.is_action_pressed("zoom_in"):
		_zoom_at(get_viewport().get_mouse_position(), _zoom_step)
	elif event.is_action_pressed("zoom_out"):
		_zoom_at(get_viewport().get_mouse_position(), 1.0 / _zoom_step)


## The right mouse button (anywhere on screen): dragging it over the map moves the map,
## clicking it (without dragging) asks to cancel (see cancel_requested).
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pan"):
		_is_panning = map_area().has_point(get_viewport().get_mouse_position())
	if event.is_action_pressed("cancel"):
		_dragged_since_press = 0.0
	elif event.is_action_released("cancel") and _dragged_since_press <= _click_max_drag:
		cancel_requested.emit()
	if event.is_action_released("pan"):
		_is_panning = false
	if event is InputEventMouseMotion:
		_dragged_since_press += event.relative.length()
		if _is_panning and Input.is_action_pressed("pan"):
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

## The colony the upgrade buttons and the Nest tool act on: a rival colony while its nest is
## selected, otherwise ours.
func target_colony() -> Colony:
	return selection if selection is Colony else simulation.player_colony


## How far the time is between the last tick and the next one (0..1). Ants and spiders are
## drawn that far between their previous and current position, so they move smoothly even
## though the simulation only moves them ticks_per_second times per second.
func tick_fraction() -> float:
	return clampf(_time_not_yet_simulated / _tick_length, 0.0, 1.0)


## Selects whatever is at map position `spot`: a creature, an ant, a nest, an object
## (food item or obstacle), or else the cell.
func select_at(spot: Vector2) -> void:
	for creature in simulation.creatures:
		if creature.position.distance_to(spot) <= maxf(creature.settings.radius, _pick_radius):
			selection = creature
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
	elif simulation.colony_at(spot) != null:
		selection = simulation.colony_at(spot)
	elif simulation.object_at(spot) != null:
		selection = simulation.object_at(spot)
	elif simulation.grid.cell_index(spot) != -1:
		selection = simulation.grid.cell_coords(spot)
	else:
		selection = null
