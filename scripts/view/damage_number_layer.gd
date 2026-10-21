extends Node2D
## Damage numbers: every hit shows how much damage it did, as a number that rises above the
## ant, spider or nest that was hurt and fades away. Colors (see [damage_numbers]):
##   received   damage our colony (and its allies) took
##   inflicted  damage our colony dealt
##   other      fights we are not part of (a rival colony against a spider)
## Hits on the same victim within merge_time add up into one number, so a long fight shows
## a steady stream of numbers instead of a blur. Numbers start above the victim's sprite,
## a little to the left or right at random, so the numbers of a crowd don't stack up. Drawn in both views, always the same size
## on screen whatever the zoom.

@onready var view: Node2D = get_parent()  ## SimulationView

var _waiting := {}             ## victim -> {position, height, amount, color}: hits being added up
var _time_until_flush := 0.0
var _numbers: Array[Dictionary] = []   ## {position, height, sideways, text, color, age}: the numbers shown
var _shown_for: ColonySimulation       ## forget everything when a new level starts

var _enabled: bool = GameSettings.get_setting("damage_numbers", "show")
var _received_color: Color = GameSettings.get_color("damage_numbers", "received_color")
var _inflicted_color: Color = GameSettings.get_color("damage_numbers", "inflicted_color")
var _other_color: Color = GameSettings.get_color("damage_numbers", "other_color")
var _outline_color: Color = GameSettings.get_color("damage_numbers", "outline_color")
var _font_size: int = GameSettings.get_setting("damage_numbers", "font_size")
var _outline_size: int = GameSettings.get_setting("damage_numbers", "outline_size")
var _merge_time: float = GameSettings.get_setting("damage_numbers", "merge_time")
var _lifetime: float = GameSettings.get_setting("damage_numbers", "lifetime")
var _rise: float = GameSettings.get_setting("damage_numbers", "rise")
var _height_above_ant: float = GameSettings.get_setting("damage_numbers", "height_above_ant")
var _height_above_spider: float = GameSettings.get_setting("damage_numbers", "height_above_spider")
var _height_above_nest: float = GameSettings.get_setting("damage_numbers", "height_above_nest")
var _spread: float = GameSettings.get_setting("damage_numbers", "spread")
var _max_numbers: int = GameSettings.get_setting("damage_numbers", "max_numbers")
var _font: Font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	var simulation: ColonySimulation = view.simulation
	if simulation != _shown_for:
		_waiting.clear()
		_numbers.clear()
		_shown_for = simulation
	var events := simulation.take_damage_events()
	if not _enabled:
		return
	_add_up(events, simulation.player_colony.team)
	_time_until_flush -= delta
	if _time_until_flush <= 0.0:
		_time_until_flush = _merge_time
		_show_waiting()
	if not view.is_paused:
		_age_numbers(delta)
	queue_redraw()


## Adds each hit to the number waiting for its victim.
func _add_up(events: Array[Dictionary], our_team: int) -> void:
	for event in events:
		var waiting: Dictionary = _waiting.get(event.victim, {amount = 0.0})
		waiting.amount += event.amount
		waiting.position = event.position
		waiting.height = _height_above(event.victim)
		waiting.color = _color_for(event, our_team)
		_waiting[event.victim] = waiting


func _height_above(victim: Object) -> float:
	if victim is Ant:
		return _height_above_ant
	if victim is Colony:
		return _height_above_nest
	return _height_above_spider


func _color_for(event: Dictionary, our_team: int) -> Color:
	if event.victim_team == our_team:
		return _received_color
	if event.attacker_team == our_team:
		return _inflicted_color
	return _other_color


## Turns the added-up hits into numbers on screen (the oldest go if there are too many).
func _show_waiting() -> void:
	for victim in _waiting:
		var waiting: Dictionary = _waiting[victim]
		var text := "%d" % maxi(1, roundi(waiting.amount))
		var sideways := randf_range(-_spread, _spread)
		_numbers.append({position = waiting.position, height = waiting.height, sideways = sideways,
			text = text, color = waiting.color, age = 0.0})
	_waiting.clear()
	if _numbers.size() > _max_numbers:
		_numbers = _numbers.slice(_numbers.size() - _max_numbers)


func _age_numbers(delta: float) -> void:
	for index in range(_numbers.size() - 1, -1, -1):
		_numbers[index].age += delta
		if _numbers[index].age >= _lifetime:
			_numbers.remove_at(index)


func _draw() -> void:
	var to_screen: Transform2D = view.map_space.transform
	var unzoom := Vector2.ONE / view.scale  # same size on screen at every zoom
	for number in _numbers:
		var progress: float = number.age / _lifetime
		var spot: Vector2 = to_screen * number.position + Vector2(0.0, -number.height)
		draw_set_transform(spot, 0.0, unzoom)
		var color: Color = number.color
		color.a = 1.0 - progress * progress  # fades out at the end
		var outline := _outline_color
		outline.a = color.a
		var width := _font.get_string_size(number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size).x
		var place := Vector2(number.sideways - width / 2.0, -_rise * progress)
		draw_string_outline(_font, place, number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, _outline_size, outline)
		draw_string(_font, place, number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, _font_size, color)
	draw_set_transform(Vector2.ZERO)
