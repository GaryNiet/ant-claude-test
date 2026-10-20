extends Node2D
## A colored square that moves with the keyboard and stays on screen.

var speed: float
var size: float
var color: Color


func _ready() -> void:
	speed = GameSettings.get_setting("player", "speed")
	size = GameSettings.get_setting("player", "size")
	color = GameSettings.get_color("player", "color")
	position = Vector2(
		GameSettings.get_setting("player", "start_x"),
		GameSettings.get_setting("player", "start_y"))


func _process(delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	position += direction * speed * delta
	_stay_on_screen()


func _stay_on_screen() -> void:
	var half_size := Vector2(size, size) / 2
	var screen_size := get_viewport_rect().size
	position = position.clamp(half_size, screen_size - half_size)


func _draw() -> void:
	draw_rect(Rect2(-size / 2, -size / 2, size, size), color)
