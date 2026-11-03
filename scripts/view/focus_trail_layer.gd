extends Node2D
## Shows the attack trail the player laid with the Focus tool (for our colony, or the
## selected rival), in its own color, always (even while the pheromone trails display is
## off), with a ring on the focused spot, so the player sees where the attack ants are sent.
## One pixel per map cell, smoothed, more opaque where the trail is stronger; it fades with
## the trail. Only updated every [focus] redraw_interval.

@onready var view: Node2D = get_parent().get_parent()  ## SimulationView (the parent is its MapSpace)

var _image: Image
var _texture: ImageTexture
var _pixels := PackedByteArray()
var _time_until_update := 0.0
var _shows_trail := false     ## some trail was left at the last update
var _target := Vector2.INF     ## the focused spot shown with a ring

var _color: Color = GameSettings.get_color("focus", "trail_color")
var _opacity: float = GameSettings.get_setting("focus", "trail_opacity")
var _redraw_interval: float = GameSettings.get_setting("focus", "redraw_interval")
var _target_radius: float = GameSettings.get_setting("focus", "target_radius")
var _full_brightness: float = GameSettings.get_setting("display", "pheromone_full_brightness")
var _visible_from: float = GameSettings.get_setting("pheromones", "detection_threshold")


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR


func _process(delta: float) -> void:
	_time_until_update -= delta
	if _time_until_update > 0.0:
		return
	_time_until_update = _redraw_interval
	_update_texture(view.simulation.grid, view.target_colony())


## Copies the colony's attack trail into the texture (strength -> opacity).
func _update_texture(grid: MapGrid, colony: Colony) -> void:
	if _image == null or _image.get_width() != grid.width or _image.get_height() != grid.height:
		_pixels.resize(grid.width * grid.height * 4)
		_image = Image.create_from_data(grid.width, grid.height, false, Image.FORMAT_RGBA8, _pixels)
		_texture = ImageTexture.create_from_image(_image)
	var first := colony.index * grid.cell_count
	var found := false
	for index in grid.cell_count:
		var strength := grid.attack[first + index]
		if strength > _visible_from:
			found = true
		_pixels[index * 4] = _color.r8
		_pixels[index * 4 + 1] = _color.g8
		_pixels[index * 4 + 2] = _color.b8
		_pixels[index * 4 + 3] = int(minf(strength / _full_brightness, 1.0) * _opacity * 255.0) if strength > _visible_from else 0
	if found or _shows_trail:
		_image.set_data(grid.width, grid.height, false, Image.FORMAT_RGBA8, _pixels)
		_texture.update(_image)
	_shows_trail = found
	_target = colony.focus_target if found else Vector2.INF
	queue_redraw()


func _draw() -> void:
	if _texture == null or not _shows_trail:
		return
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, view.simulation.grid.world_size()), false)
	if _target != Vector2.INF:
		draw_arc(_target, _target_radius, 0.0, TAU, 32, _color, 2.0 / view.scale.x)
