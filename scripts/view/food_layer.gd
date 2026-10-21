extends Node2D
## Draws the food lying on the ground: one pixel per map cell, stretched over the map with
## sharp edges. Food cells get more opaque the more food they hold. Only redrawn when the
## food or the view changed. The isometric view draws it in its own color (seeds and crumbs).
## (The ground itself is drawn by the ground layer.)

@onready var view: Node2D = get_parent().get_parent()  ## SimulationView (the parent is its MapSpace)

var _image: Image
var _texture: ImageTexture
var _pixels := PackedByteArray()
var _drawn_version := -1
var _drawn_simulation: ColonySimulation

var _debug_food_color: Color = GameSettings.get_color("colors", "food")
var _iso_food_color: Color = GameSettings.get_color("iso_view", "food_color")
var _full_food: float = GameSettings.get_setting("display", "food_full_opacity")
var _faintest_food: float = GameSettings.get_setting("display", "food_min_opacity")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.view_mode_changed.connect(func() -> void: _drawn_version = -1)


func _process(_delta: float) -> void:
	var simulation: ColonySimulation = view.simulation
	if simulation.grid.terrain_version != _drawn_version or simulation != _drawn_simulation:
		_update_texture(simulation.grid)
		_drawn_version = simulation.grid.terrain_version
		_drawn_simulation = simulation


func _update_texture(grid: MapGrid) -> void:
	if _image == null or _image.get_width() != grid.width or _image.get_height() != grid.height:
		_pixels.resize(grid.width * grid.height * 4)
		_image = Image.create_from_data(grid.width, grid.height, false, Image.FORMAT_RGBA8, _pixels)
		_texture = ImageTexture.create_from_image(_image)
	for index in grid.food.size():
		var color := Color.TRANSPARENT
		if grid.food[index] > 0:
			color = _iso_food_color if view.is_iso_view else _debug_food_color
			color.a = lerpf(_faintest_food, 1.0, minf(grid.food[index] / _full_food, 1.0))
		_pixels[index * 4] = color.r8
		_pixels[index * 4 + 1] = color.g8
		_pixels[index * 4 + 2] = color.b8
		_pixels[index * 4 + 3] = color.a8
	_image.set_data(grid.width, grid.height, false, Image.FORMAT_RGBA8, _pixels)
	_texture.update(_image)
	queue_redraw()


func _draw() -> void:
	if _texture == null:
		return  # first frame: nothing built yet
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, view.simulation.grid.world_size()), false)
