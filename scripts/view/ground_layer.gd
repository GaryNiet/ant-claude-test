extends Node2D
## Draws the ground tiles (dirt, grass, water, obstacles, nest), each as its image if one
## exists, otherwise as a colored square. Only redrawn when a tile changed.

@onready var view: Node2D = get_parent()

var _art := TileArt.new()
var _drawn_version := -1
var _drawn_simulation: ColonySimulation


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


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
			var texture := _art.texture_for(ground, column, row)
			if texture != null:
				draw_texture_rect(texture, area, false)
			else:
				draw_rect(area, _art.color_of(ground.type_at(column, row)))
