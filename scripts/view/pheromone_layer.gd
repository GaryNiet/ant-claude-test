extends Node2D
## Draws the three pheromones as a colored glow: one pixel per map cell, stretched over the
## map with smoothing, the two colors added together (pink where both overlap).

@onready var view: Node2D = get_parent()

var _image: Image
var _texture: ImageTexture
var _pixels := PackedByteArray()

var _going_out_color: Color = GameSettings.get_color("colors", "going_out_pheromone")
var _going_home_color: Color = GameSettings.get_color("colors", "going_home_pheromone")
var _fight_color: Color = GameSettings.get_color("colors", "fight_pheromone")
var _full_brightness: float = GameSettings.get_setting("display", "pheromone_full_brightness")


func _ready() -> void:
	view.stepped.connect(_update_texture)
	_update_texture()


func _update_texture() -> void:
	var grid: MapGrid = view.simulation.grid
	if _image == null:
		_pixels.resize(grid.width * grid.height * 3)
		_image = Image.create_from_data(grid.width, grid.height, false, Image.FORMAT_RGB8, _pixels)
		_texture = ImageTexture.create_from_image(_image)
	for index in grid.going_out.size():
		var out_brightness := minf(grid.going_out[index] / _full_brightness, 1.0)
		var home_brightness := minf(grid.going_home[index] / _full_brightness, 1.0)
		var fight_brightness := minf(grid.fight[index] / _full_brightness, 1.0)
		var color := (_going_out_color * out_brightness + _going_home_color * home_brightness
			+ _fight_color * fight_brightness)
		_pixels[index * 3] = int(minf(color.r, 1.0) * 255.0)
		_pixels[index * 3 + 1] = int(minf(color.g, 1.0) * 255.0)
		_pixels[index * 3 + 2] = int(minf(color.b, 1.0) * 255.0)
	_image.set_data(grid.width, grid.height, false, Image.FORMAT_RGB8, _pixels)
	_texture.update(_image)
	queue_redraw()


func _draw() -> void:
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, view.simulation.grid.world_size()), false)
