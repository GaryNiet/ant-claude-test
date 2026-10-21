extends Node2D
## Draws a ring on the ground around whatever the player selected (ant, spider or nest),
## or a square around the selected cell. In both views: in the isometric view the ring is
## squashed like the ground. Lines are kept about 1 screen pixel thick whatever the zoom.

@onready var view: Node2D = get_parent().get_parent()  ## SimulationView (the parent is its MapSpace)

var _ant_length: float = GameSettings.get_setting("display", "ant_length")
var _enemy_radius: float = GameSettings.get_setting("enemies", "radius")
var _selection_color: Color = GameSettings.get_color("display", "selection_color")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var simulation: ColonySimulation = view.simulation
	var line_width := 1.5 / view.scale.x
	var selected: Variant = view.selection
	if selected is Ant and not selected.is_dead():
		draw_arc(selected.position, _ant_length, 0.0, TAU, 24, _selection_color, line_width)
	elif selected is Enemy and not selected.is_dead() and not selected.has_left_the_map:
		draw_arc(selected.position, _enemy_radius * 1.5, 0.0, TAU, 32, _selection_color, line_width)
	elif selected is String and selected == view.SELECTED_NEST:
		draw_arc(simulation.nest_position, simulation.nest_radius, 0.0, TAU, 48, _selection_color, line_width)
	elif selected is Vector2i:
		var cell_size := simulation.grid.cell_size
		draw_rect(Rect2(Vector2(selected) * cell_size, Vector2(cell_size, cell_size)), _selection_color, false, line_width)
