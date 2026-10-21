extends Node2D
## Shows the trails the player drew with the Trail tool, in their own color, always (even
## while the pheromone trails display is off), so the player can see where they sent the ants.
## One pixel per map cell, smoothed, more opaque where the trail is stronger; it fades with
## the trail. Only updated every drawn_trail_redraw_interval, and only while there is some.

@onready var view: Node2D = get_parent().get_parent()  ## SimulationView (the parent is its MapSpace)

var _image: Image
var _texture: ImageTexture
var _pixels := PackedByteArray()
var _time_until_update := 0.0
var _was_showing := false

var _color: Color = GameSettings.get_color("painting", "drawn_trail_color")
var _opacity: float = GameSettings.get_setting("painting", "drawn_trail_opacity")
var _full_brightness: float = GameSettings.get_setting("display", "pheromone_full_brightness")
var _redraw_interval: float = GameSettings.get_setting("painting", "drawn_trail_redraw_interval")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _process(delta: float) -> void:
	_time_until_update -= delta
	if _time_until_update > 0.0:
		return
	_time_until_update = _redraw_interval
	var grid: MapGrid = view.simulation.grid
	if grid.drawn_trail_cells > 0 or _was_showing:
		_update_texture(grid)
		_was_showing = grid.drawn_trail_cells > 0


func _update_texture(grid: MapGrid) -> void:
	if _image == null or _image.get_width() != grid.width or _image.get_height() != grid.height:
		_pixels.resize(grid.width * grid.height * 4)
		_image = Image.create_from_data(grid.width, grid.height, false, Image.FORMAT_RGBA8, _pixels)
		_texture = ImageTexture.create_from_image(_image)
	for index in grid.cell_count:
		_pixels[index * 4] = _color.r8
		_pixels[index * 4 + 1] = _color.g8
		_pixels[index * 4 + 2] = _color.b8
		_pixels[index * 4 + 3] = int(minf(grid.drawn_trail[index] / _full_brightness, 1.0) * _opacity * 255.0)
	_image.set_data(grid.width, grid.height, false, Image.FORMAT_RGBA8, _pixels)
	_texture.update(_image)
	queue_redraw()


func _draw() -> void:
	if _texture != null:
		draw_texture_rect(_texture, Rect2(Vector2.ZERO, view.simulation.grid.world_size()), false)
