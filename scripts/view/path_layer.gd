extends Node2D
## Draws the unobstructed areas: ground worn into paths by ants walking over it a lot.
## In the isometric view paths show the smooth, light path image (tiles/path.png) laid over
## the ground; in the debug view a flat color. Any ground can have path on part of it.
##
## A mask texture holds one pixel per map cell: how worn it is, up to the unobstructed
## level (white). The shader (path_layer.gdshader) smooths the mask between cells, so paths
## get soft edges. Paths change slowly, so the mask is only updated every redraw_interval.

@onready var view: Node2D = get_parent().get_parent()  ## SimulationView (the parent is its MapSpace)

var _image: Image
var _mask: ImageTexture
var _pixels := PackedByteArray()
var _time_until_update := 0.0

var _redraw_interval: float = GameSettings.get_setting("paths", "redraw_interval")
var _tile_folder: String = GameSettings.get_setting("ground", "tile_image_folder")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # smooths the mask between cells
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://scripts/view/path_layer.gdshader")
	shader_material.set_shader_parameter("path_texture", load(_tile_folder + "/path.png"))
	shader_material.set_shader_parameter("flat_color", GameSettings.get_color("colors", "path"))
	shader_material.set_shader_parameter("edge_softness", GameSettings.get_setting("paths", "edge_softness"))
	material = shader_material
	view.view_mode_changed.connect(func() -> void: material.set_shader_parameter("use_texture", view.is_iso_view))
	view.level_loaded.connect(_update_mask)


func _process(delta: float) -> void:
	_time_until_update -= delta
	if _time_until_update <= 0.0:
		_time_until_update = _redraw_interval
		_update_mask()


func _update_mask() -> void:
	var grid: MapGrid = view.simulation.grid
	if _image == null or _image.get_width() != grid.width or _image.get_height() != grid.height:
		_pixels.resize(grid.width * grid.height)
		_image = Image.create_from_data(grid.width, grid.height, false, Image.FORMAT_L8, _pixels)
		_mask = ImageTexture.create_from_image(_image)
		var ground: GroundMap = view.simulation.ground
		material.set_shader_parameter("tiles_on_map", Vector2(ground.columns, ground.rows))
	for index in grid.path_wear.size():
		_pixels[index] = int(minf(grid.path_wear[index] / grid.unobstructed_wear, 1.0) * 255.0)
	_image.set_data(grid.width, grid.height, false, Image.FORMAT_L8, _pixels)
	_mask.update(_image)
	queue_redraw()


func _draw() -> void:
	if _mask != null:
		draw_texture_rect(_mask, Rect2(Vector2.ZERO, view.simulation.grid.world_size()), false)
