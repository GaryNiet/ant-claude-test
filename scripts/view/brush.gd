extends Node2D
## Lets the player paint on the map with the mouse: hold the paint button to add the
## selected material (food or obstacle), hold the erase button to remove both.
## Shows the brush as a circle under the mouse.

enum Tool { FOOD, OBSTACLE }

@onready var view: Node2D = get_parent()

var selected_tool := Tool.FOOD
var radius: float = GameSettings.get_setting("painting", "brush_radius")

var _min_radius: float = GameSettings.get_setting("painting", "brush_min_radius")
var _max_radius: float = GameSettings.get_setting("painting", "brush_max_radius")
var _radius_step: float = GameSettings.get_setting("painting", "brush_radius_step")
var _outline_color: Color = GameSettings.get_color("colors", "brush_outline")
var _last_paint_position := Vector2.INF  ## where the previous frame painted (INF = not painting)


func tool_name() -> String:
	return "food" if selected_tool == Tool.FOOD else "obstacle"


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("tool_food"):
		selected_tool = Tool.FOOD
	elif event.is_action_pressed("tool_obstacle"):
		selected_tool = Tool.OBSTACLE
	elif event.is_action_pressed("brush_bigger"):
		radius = minf(radius + _radius_step, _max_radius)
	elif event.is_action_pressed("brush_smaller"):
		radius = maxf(radius - _radius_step, _min_radius)


func _process(_delta: float) -> void:
	var mouse := get_local_mouse_position()  # already in map pixels (this node is scaled with the map)
	if Input.is_action_pressed("paint") or Input.is_action_pressed("erase"):
		_paint_line(_last_paint_position if _last_paint_position != Vector2.INF else mouse, mouse)
		_last_paint_position = mouse
	else:
		_last_paint_position = Vector2.INF
	queue_redraw()


## Paints dabs along the line from `from` to `to`, so fast mouse moves leave no gaps.
func _paint_line(from: Vector2, to: Vector2) -> void:
	var dab_spacing := maxf(radius * 0.5, 1.0)
	var dabs := maxi(ceili(from.distance_to(to) / dab_spacing), 1)
	for dab in dabs + 1:
		_paint_dab(from.lerp(to, float(dab) / dabs))


func _paint_dab(center: Vector2) -> void:
	var simulation: ColonySimulation = view.simulation
	if Input.is_action_pressed("erase"):
		simulation.erase(center, radius)
	elif selected_tool == Tool.FOOD:
		simulation.paint_food(center, radius)
	else:
		simulation.paint_obstacle(center, radius)


func _draw() -> void:
	draw_arc(get_local_mouse_position(), radius, 0.0, TAU, 48, _outline_color, 1.0)
