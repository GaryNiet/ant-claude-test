extends Node2D
## Isometric view only: soft mossy patches on the dirt. Pure decoration, no effect on the game.
## Where the moss grows comes from smooth noise (the same every time for a given spot), only
## on dirt tiles. Drawn with the moss image (tiles/moss.png) through the same shader as the
## paths, so the patches have soft edges. Rebuilt when the ground changes.

@onready var view: Node2D = get_parent().get_parent()  ## SimulationView (the parent is its MapSpace)

var _mask: ImageTexture
var _drawn_version := -1
var _drawn_simulation: ColonySimulation
var _noise := FastNoiseLite.new()
var _coverage: float = GameSettings.get_setting("moss", "coverage")
var _tile_folder: String = GameSettings.get_setting("ground", "tile_image_folder")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR  # smooths the mask between cells
	_noise.frequency = GameSettings.get_setting("moss", "frequency")
	var shader_material := ShaderMaterial.new()
	shader_material.shader = load("res://scripts/view/ground_overlay.gdshader")
	shader_material.set_shader_parameter("overlay_texture", load(_tile_folder + "/moss.png"))
	shader_material.set_shader_parameter("edge_softness", GameSettings.get_setting("moss", "edge_softness"))
	material = shader_material


func _process(_delta: float) -> void:
	var simulation: ColonySimulation = view.simulation
	if simulation.ground.version != _drawn_version or simulation != _drawn_simulation:
		_drawn_version = simulation.ground.version
		_drawn_simulation = simulation
		_update_mask(simulation)


## White where there is moss: dirt cells where the noise is in its top `coverage` share.
func _update_mask(simulation: ColonySimulation) -> void:
	var grid := simulation.grid
	var ground := simulation.ground
	var pixels := PackedByteArray()
	pixels.resize(grid.width * grid.height)
	var threshold := 1.0 - _coverage * 2.0  # noise goes from about -1 to 1
	for row in grid.height:
		for column in grid.width:
			var tile := Vector2i(column / ground.tile_cells, row / ground.tile_cells)
			if ground.type_at(tile.x, tile.y) != GroundMap.Type.DIRT:
				continue
			var amount := (_noise.get_noise_2d(column, row) - threshold) * 4.0 + 0.75
			pixels[row * grid.width + column] = int(clampf(amount, 0.0, 1.0) * 255.0)
	_mask = ImageTexture.create_from_image(Image.create_from_data(grid.width, grid.height, false, Image.FORMAT_L8, pixels))
	material.set_shader_parameter("tiles_on_map", Vector2(ground.columns, ground.rows))
	queue_redraw()


func _draw() -> void:
	if _mask != null:
		draw_texture_rect(_mask, Rect2(Vector2.ZERO, view.simulation.grid.world_size()), false)
