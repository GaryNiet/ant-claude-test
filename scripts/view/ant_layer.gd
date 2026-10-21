extends Node2D
## Debug view only: draws the nest entrance, the ants and the enemies (spiders) as simple
## shapes. Ants and enemies are arrows pointing where they are heading (only the drawing:
## their collision size stays a circle). An ant carrying food holds the food block in front
## of it. (The nest tiles are drawn by the ground layer; the isometric view uses the
## sprite layer instead of this one.)

@onready var view: Node2D = get_parent().get_parent()  ## SimulationView (the parent is its MapSpace)

var _nest_entrance_color: Color = GameSettings.get_color("colors", "nest_entrance")
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
var _ant_length: float = GameSettings.get_setting("display", "ant_length")
var _ant_width: float = GameSettings.get_setting("display", "ant_width")
var _enemy_length: float = GameSettings.get_setting("display", "enemy_length")
var _enemy_width: float = GameSettings.get_setting("display", "enemy_width")
var _food_block_size: float = GameSettings.get_setting("display", "carried_food_block_size")
var _nest_entrance_radius: float = GameSettings.get_setting("display", "nest_entrance_radius")


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var simulation: ColonySimulation = view.simulation
	draw_circle(simulation.nest_position, _nest_entrance_radius, _nest_entrance_color)
	for ant in simulation.ants:
		_draw_ant(ant)
	for enemy in simulation.enemies:
		_draw_enemy(enemy)


func _draw_ant(ant: Ant) -> void:
	_draw_arrow(ant.position, ant.heading, _ant_length, _ant_width, _ant_color_for(ant))
	if ant.is_carrying_food():
		# The block grows with the pieces carried (its area is proportional to the food).
		var size := _food_block_size * sqrt(ant.carried_food)
		var forward := Vector2.from_angle(ant.heading)
		_draw_square(ant.position + forward * (_ant_length + size) * 0.5, ant.heading, size, _food_color)


func _draw_enemy(enemy: Enemy) -> void:
	_draw_arrow(enemy.position, enemy.heading, _enemy_length, _enemy_width, _enemy_color)
	if enemy.food_eaten > 0:  # belly: a green dot that grows with the food eaten
		var fullness := minf(enemy.food_eaten / _enemy_appetite, 1.0)
		draw_circle(enemy.position, _enemy_radius * 0.7 * fullness, _food_color)
	var bar_width := _enemy_radius * 2.0
	var bar_start := enemy.position + Vector2(-_enemy_radius, -_enemy_radius - _health_bar_gap)
	var bar_end := bar_start + Vector2(bar_width * enemy.hp / enemy.max_hp, 0.0)
	draw_line(bar_start, bar_end, _health_bar_color, _health_bar_thickness)


## An arrow head centered on `center`, pointing along `heading`: a triangle with a notch
## in its back, `length` long and `width` wide.
func _draw_arrow(center: Vector2, heading: float, length: float, width: float, color: Color) -> void:
	var forward := Vector2.from_angle(heading)
	var side := forward.orthogonal()
	var tip := center + forward * length * 0.5
	var back := center - forward * length * 0.5
	var notch := center - forward * length * 0.2
	draw_colored_polygon(PackedVector2Array([tip, back + side * width * 0.5, notch, back - side * width * 0.5]), color)


## A square of side `size` centered on `center`, turned by `angle`.
func _draw_square(center: Vector2, angle: float, size: float, color: Color) -> void:
	var half_forward := Vector2.from_angle(angle) * size * 0.5
	var half_side := half_forward.orthogonal()
	draw_colored_polygon(PackedVector2Array([
		center + half_forward + half_side, center + half_forward - half_side,
		center - half_forward - half_side, center - half_forward + half_side]), color)


func _ant_color_for(ant: Ant) -> Color:
	if ant.mode == Ant.Mode.FIGHTING:
		return _ant_fighting_color
	if ant.mode == Ant.Mode.CUTTING_FOOD:
		return _ant_cutting_color
	if ant.is_carrying_food():
		return _ant_with_food_color
	if ant.is_scout:
		return _scout_color
	return _ant_color
