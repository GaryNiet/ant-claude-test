extends Node2D
## Draws the ground tiles (dirt, grass, water, obstacles, nest). In the isometric view each
## tile is drawn with its image (if one exists); the debug view uses plain colors.
## Only redrawn when a tile or the view changed.

@onready var view: Node2D = get_parent().get_parent()  ## SimulationView (the parent is its MapSpace)

var _art := TileArt.new()
var _drawn_version := -1
var _drawn_simulation: ColonySimulation


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	view.view_mode_changed.connect(queue_redraw)


func _process(_delta: float) -> void:
	var simulation: ColonySimulation = view.simulation
	if simulation.ground.version != _drawn_version or simulation != _drawn_simulation:
		_drawn_version = simulation.ground.version
		_drawn_simulation = simulation
		queue_redraw()


func _draw() -> void:
	var ground: GroundMap = view.simulation.ground
	var tile_size := Vector2(ground.tile_size, ground.tile_size)
	for row in ground.rows:
		for column in ground.columns:
			var area := Rect2(Vector2(column, row) * ground.tile_size, tile_size)
			var texture := _art.texture_for(ground, column, row) if view.is_iso_view else null
			if texture != null:
				draw_texture_rect(texture, area, false)
			else:
				draw_rect(area, _art.color_of(ground.type_at(column, row)))
