extends Node2D
## The player's mouse tools on the map:
##   Inspect   click on anything to see information about it (in the side panel)
##   Food      hold to paint food (on ground that can be walked on)
##   Obstacle  hold to paint obstacle tiles
##   Erase     hold to remove food (right click erases food with any tool)
##   Nest      click to move the nest
##   Dirt, Grass, Water   hold to paint ground tiles
## Shows the brush as a circle under the mouse for the painting tools.
## Ground tools paint whole tiles: every tile whose center is in the circle, at least the
## tile under the mouse.

enum Tool { INSPECT, FOOD, OBSTACLE, ERASE, NEST, DIRT, GRASS, WATER }

const TOOL_NAMES := {
	Tool.INSPECT: "Inspect",
	Tool.FOOD: "Food",
	Tool.OBSTACLE: "Obstacle",
	Tool.ERASE: "Erase",
	Tool.NEST: "Nest",
	Tool.DIRT: "Dirt",
	Tool.GRASS: "Grass",
	Tool.WATER: "Water",
}

## The ground each ground tool paints.
const TOOL_GROUND := {
	Tool.OBSTACLE: GroundMap.Type.OBSTACLE,
	Tool.DIRT: GroundMap.Type.DIRT,
	Tool.GRASS: GroundMap.Type.GRASS,
	Tool.WATER: GroundMap.Type.WATER,
}

## Keyboard action for each tool (see [controls]).
const TOOL_ACTIONS := {
	Tool.INSPECT: "tool_inspect",
	Tool.FOOD: "tool_food",
	Tool.OBSTACLE: "tool_obstacle",
	Tool.ERASE: "tool_erase",
	Tool.NEST: "tool_nest",
	Tool.DIRT: "tool_dirt",
	Tool.GRASS: "tool_grass",
	Tool.WATER: "tool_water",
}

@onready var view: Node2D = get_parent()

var selected_tool := Tool.INSPECT
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
	for tool in TOOL_ACTIONS:
		if event.is_action_pressed(TOOL_ACTIONS[tool]):
			selected_tool = tool
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
	var spot := get_local_mouse_position()  # already in map pixels (this node is scaled with the map)
	match selected_tool:
		Tool.INSPECT:
			view.select_at(spot)
		Tool.NEST:
			view.simulation.move_nest(spot)
		Tool.ERASE:
			_start_stroke(true)
		_:
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
		simulation.erase_food(center, radius)
	elif selected_tool == Tool.FOOD:
		simulation.paint_food(center, radius)
	elif TOOL_GROUND.has(selected_tool):
		simulation.paint_ground(center, radius, TOOL_GROUND[selected_tool])


func _draw() -> void:
	if selected_tool not in [Tool.INSPECT, Tool.NEST]:
		draw_arc(get_local_mouse_position(), radius, 0.0, TAU, 48, _outline_color, 1.0 / view.scale.x)
