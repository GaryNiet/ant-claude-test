extends Node2D
## Draws a ring on the ground around whatever the player selected (ant, spider, object or nest),
## or a square around the selected cell. In both views: in the isometric view the ring is
## squashed like the ground. Lines are kept about 1 screen pixel thick whatever the zoom.

@onready var view: Node2D = get_parent().get_parent()  ## SimulationView (the parent is its MapSpace)

var _ant_length: float = GameSettings.get_setting("display", "ant_length")
var _selection_color: Color = GameSettings.get_color("display", "selection_color")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var simulation: ColonySimulation = view.simulation
	var line_width := 1.5 / view.scale.x
	var selected: Variant = view.selection
	if selected is Ant and not selected.is_dead():
		draw_arc(selected.position, _ant_length, 0.0, TAU, 24, _selection_color, line_width)
	elif selected is Creature and not selected.is_dead() and not selected.has_left_the_map:
		draw_arc(selected.position, selected.settings.radius * 1.5, 0.0, TAU, 32, _selection_color, line_width)
	elif selected is MapObject and simulation.objects.has(selected):
		var radius := simulation.object_kinds.footprint_radius(selected.kind)
		draw_arc(selected.position, radius, 0.0, TAU, 32, _selection_color, line_width)
	elif selected is Colony:
		draw_arc(selected.nest_position, selected.nest_radius, 0.0, TAU, 48, _selection_color, line_width)
	elif selected is Vector2i:
		var cell_size := simulation.grid.cell_size
		draw_rect(Rect2(Vector2(selected) * cell_size, Vector2(cell_size, cell_size)), _selection_color, false, line_width)
