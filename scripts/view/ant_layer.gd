extends Node2D
## Draws the nest, the ants (dots) and the enemies (big dots with a health bar).

@onready var view: Node2D = get_parent()

var _nest_color: Color = GameSettings.get_color("colors", "nest")
var _ant_color: Color = GameSettings.get_color("colors", "ant")
var _scout_color: Color = GameSettings.get_color("colors", "scout")
var _ant_with_food_color: Color = GameSettings.get_color("colors", "ant_with_food")
var _ant_fighting_color: Color = GameSettings.get_color("colors", "ant_fighting")
var _ant_cutting_color: Color = GameSettings.get_color("colors", "ant_cutting")
var _enemy_color: Color = GameSettings.get_color("colors", "enemy")
var _health_bar_color: Color = GameSettings.get_color("colors", "enemy_health_bar")
var _enemy_radius: float = GameSettings.get_setting("enemies", "radius")
var _enemy_appetite: float = GameSettings.get_setting("enemies", "appetite")
var _food_color: Color = GameSettings.get_color("colors", "food")
var _health_bar_gap: float = GameSettings.get_setting("display", "enemy_health_bar_gap")
var _health_bar_thickness: float = GameSettings.get_setting("display", "enemy_health_bar_thickness")
var _ant_radius: float = GameSettings.get_setting("display", "ant_radius")
var _nest_draw_radius: float = GameSettings.get_setting("display", "nest_draw_radius")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var simulation: ColonySimulation = view.simulation
	draw_circle(simulation.nest_position, _nest_draw_radius, _nest_color)
	for ant in simulation.ants:
		draw_circle(ant.position, _ant_radius, _ant_dot_color(ant))
	for enemy in simulation.enemies:
		_draw_enemy(enemy)


func _draw_enemy(enemy: Enemy) -> void:
	draw_circle(enemy.position, _enemy_radius, _enemy_color)
	if enemy.food_eaten > 0:  # belly: a green dot that grows with the food eaten
		var fullness := minf(enemy.food_eaten / _enemy_appetite, 1.0)
		draw_circle(enemy.position, _enemy_radius * 0.7 * fullness, _food_color)
	var bar_width := _enemy_radius * 2.0
	var bar_start := enemy.position + Vector2(-_enemy_radius, -_enemy_radius - _health_bar_gap)
	var bar_end := bar_start + Vector2(bar_width * enemy.hp / enemy.max_hp, 0.0)
	draw_line(bar_start, bar_end, _health_bar_color, _health_bar_thickness)


func _ant_dot_color(ant: Ant) -> Color:
	if ant.mode == Ant.Mode.FIGHTING:
		return _ant_fighting_color
	if ant.mode == Ant.Mode.CUTTING_FOOD:
		return _ant_cutting_color
	if ant.is_carrying_food():
		return _ant_with_food_color
	if ant.is_scout:
		return _scout_color
	return _ant_color
