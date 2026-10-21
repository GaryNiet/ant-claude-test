extends Node2D
## The player's mouse tools on the map (picked in the tool bar):
##   Inspect   click on anything to see information about it (in the side panel)
##   Place     click to place one object (a food item or an obstacle) of the chosen kind
##   Terrain   hold to paint dirt, grass or water, in whole tiles: every tile whose center
##             is in the brush circle, at least the tile under the mouse
##   Erase     hold to remove the objects under the brush (right click erases with any tool)
##   Nest      click to move the nest
## Shows the brush circle (terrain, erase) or the object's footprint (place) under the mouse.

enum Tool { INSPECT, PLACE, TERRAIN, ERASE, NEST }

@onready var view: Node2D = get_parent().get_parent()  ## SimulationView (the parent is its MapSpace)

var selected_tool := Tool.INSPECT
var object_kind := ""                     ## what the Place tool places
var ground_type := GroundMap.Type.DIRT    ## what the Terrain tool paints
var radius: float = GameSettings.get_setting("painting", "brush_radius")

var _min_radius: float = GameSettings.get_setting("painting", "brush_min_radius")
var _max_radius: float = GameSettings.get_setting("painting", "brush_max_radius")
var _radius_step: float = GameSettings.get_setting("painting", "brush_radius_step")
var _outline_color: Color = GameSettings.get_color("colors", "brush_outline")
var _is_painting := false
var _is_erasing := false
var _last_paint_position := Vector2.INF  ## where the previous frame painted (INF = just started)


func change_size(steps: int) -> void:
	radius = clampf(radius + steps * _radius_step, _min_radius, _max_radius)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("brush_bigger"):
		change_size(1)
	elif event.is_action_pressed("brush_smaller"):
		change_size(-1)
	elif event.is_action_pressed("paint"):
		_use_tool()
	elif event.is_action_pressed("erase"):
		_start_stroke(true)
	elif event.is_action_released("paint") or event.is_action_released("erase"):
		_is_painting = false


func _use_tool() -> void:
	var spot := get_local_mouse_position()  # already in map pixels (this node is in the map space)
	match selected_tool:
		Tool.INSPECT:
			view.select_at(spot)
		Tool.NEST:
			view.simulation.move_nest(spot)
		Tool.PLACE:
			view.simulation.place_object(object_kind, spot)
		Tool.ERASE:
			_start_stroke(true)
		Tool.TERRAIN:
			_start_stroke(false)


func _start_stroke(erase: bool) -> void:
	_is_painting = true
	_is_erasing = erase
	_last_paint_position = Vector2.INF


func _process(_delta: float) -> void:
	if _is_painting:
		var mouse := get_local_mouse_position()
		var from := _last_paint_position if _last_paint_position != Vector2.INF else mouse
		_paint_line(from, mouse)
		_last_paint_position = mouse
	queue_redraw()


## Paints dabs along the line from `from` to `to`, so fast mouse moves leave no gaps.
func _paint_line(from: Vector2, to: Vector2) -> void:
	var dab_spacing := maxf(radius * 0.5, 1.0)
	var dabs := maxi(ceili(from.distance_to(to) / dab_spacing), 1)
	for dab in dabs + 1:
		_paint_dab(from.lerp(to, float(dab) / dabs))


func _paint_dab(center: Vector2) -> void:
	var simulation: ColonySimulation = view.simulation
	if _is_erasing:
		simulation.erase_objects(center, radius)
	else:
		simulation.paint_ground(center, radius, ground_type)


func _draw() -> void:
	var line_width := 1.0 / view.scale.x
	if selected_tool == Tool.TERRAIN or selected_tool == Tool.ERASE:
		draw_arc(get_local_mouse_position(), radius, 0.0, TAU, 48, _outline_color, line_width)
	elif selected_tool == Tool.PLACE:
		var footprint: float = view.simulation.object_kinds.footprint_radius(object_kind)
		var center: Vector2 = view.simulation.grid.cell_center(get_local_mouse_position())
		draw_arc(center, footprint, 0.0, TAU, 32, _outline_color, line_width)
