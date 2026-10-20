extends Node2D
## Draws the nest and the ants as dots.

@onready var view: Node2D = get_parent()

var _nest_color: Color = GameSettings.get_color("colors", "nest")
var _ant_color: Color = GameSettings.get_color("colors", "ant")
var _scout_color: Color = GameSettings.get_color("colors", "scout")
var _ant_with_food_color: Color = GameSettings.get_color("colors", "ant_with_food")
var _ant_radius: float = GameSettings.get_setting("display", "ant_radius")
var _nest_draw_radius: float = GameSettings.get_setting("display", "nest_draw_radius")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var simulation: ColonySimulation = view.simulation
	draw_circle(simulation.nest_position, _nest_draw_radius, _nest_color)
	for ant in simulation.ants:
		draw_circle(ant.position, _ant_radius, _ant_dot_color(ant))


func _ant_dot_color(ant: Ant) -> Color:
	if ant.is_carrying_food():
		return _ant_with_food_color
	if ant.is_scout:
		return _scout_color
	return _ant_color
