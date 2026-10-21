extends Node2D
## Isometric view only: draws the things standing on the ground as sprites, at their
## projected positions:
##   rocks       one per obstacle tile, upright
##   nest        a dirt mound, upright; the big one once the colony has grown
##   ants        turned to where they walk and squashed like the ground (ants are flat);
##               an ant carrying food holds a crumb in front of its head; scouts are darker
##   spiders     the enemies, drawn like the ants, with a health bar above them
## Everything is drawn from back to front (sorted by how far down the screen it stands),
## so whatever is in front covers what is behind it.

## Sprite files in [iso_view] sprite_folder (made by tools/make_art.py).
const ANT_IMAGE := "ant.png"
const SPIDER_IMAGE := "spider.png"
const CRUMB_IMAGE := "food_crumb.png"
const NEST_SMALL_IMAGE := "nest_small.png"
const NEST_BIG_IMAGE := "nest_big.png"
const ROCK_IMAGES := ["rock_1.png", "rock_2.png", "rock_3.png"]

enum Kind { ROCK, NEST, ANT, SPIDER }

@onready var view: Node2D = get_parent()  ## SimulationView

var _ant_texture: Texture2D
var _spider_texture: Texture2D
var _crumb_texture: Texture2D
var _nest_small_texture: Texture2D
var _nest_big_texture: Texture2D
var _rock_textures: Array[Texture2D] = []

var _ant_size: float = GameSettings.get_setting("iso_view", "ant_size")
var _spider_size: float = GameSettings.get_setting("iso_view", "spider_size")
var _crumb_size: float = GameSettings.get_setting("iso_view", "crumb_size")
var _rock_width: float = GameSettings.get_setting("iso_view", "rock_width")
var _nest_width_per_radius: float = GameSettings.get_setting("iso_view", "nest_width_per_radius")
var _nest_big_from_radius: float = GameSettings.get_setting("iso_view", "nest_big_from_radius")
var _scout_tint: Color = GameSettings.get_color("iso_view", "scout_tint")
var _health_bar_color: Color = GameSettings.get_color("colors", "enemy_health_bar")
var _health_bar_thickness: float = GameSettings.get_setting("display", "enemy_health_bar_thickness")

var _rocks: Array[Dictionary] = []   ## obstacle tiles: {spot, texture}, rebuilt when the ground changes
var _rocks_version := -1
var _rocks_simulation: ColonySimulation


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixel art
	var folder: String = GameSettings.get_setting("iso_view", "sprite_folder")
	_ant_texture = load("%s/%s" % [folder, ANT_IMAGE])
	_spider_texture = load("%s/%s" % [folder, SPIDER_IMAGE])
	_crumb_texture = load("%s/%s" % [folder, CRUMB_IMAGE])
	_nest_small_texture = load("%s/%s" % [folder, NEST_SMALL_IMAGE])
	_nest_big_texture = load("%s/%s" % [folder, NEST_BIG_IMAGE])
	for image in ROCK_IMAGES:
		_rock_textures.append(load("%s/%s" % [folder, image]))


func _process(_delta: float) -> void:
	if visible:
		queue_redraw()


func _draw() -> void:
	var simulation: ColonySimulation = view.simulation
	var to_screen: Transform2D = view.map_space.transform
	for item in _things_back_to_front(simulation, to_screen):
		match item.kind:
			Kind.ROCK:
				_draw_upright(item.texture, item.spot, _rock_width)
			Kind.NEST:
				_draw_nest(simulation, item.spot)
			Kind.ANT:
				_draw_ant(item.thing, item.spot, to_screen)
			Kind.SPIDER:
				_draw_spider(item.thing, item.spot, to_screen)
	draw_set_transform_matrix(Transform2D.IDENTITY)


## Everything to draw, with its projected position, sorted from the top of the screen down.
func _things_back_to_front(simulation: ColonySimulation, to_screen: Transform2D) -> Array[Dictionary]:
	_update_rocks(simulation)
	var things: Array[Dictionary] = []
	for rock in _rocks:
		things.append({kind = Kind.ROCK, spot = to_screen * rock.spot, texture = rock.texture})
	things.append({kind = Kind.NEST, spot = to_screen * simulation.nest_position})
	for ant in simulation.ants:
		things.append({kind = Kind.ANT, spot = to_screen * ant.position, thing = ant})
	for enemy in simulation.enemies:
		things.append({kind = Kind.SPIDER, spot = to_screen * enemy.position, thing = enemy})
	things.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.spot.y < b.spot.y)
	return things


## One rock per obstacle tile, standing on the tile's center. Each tile keeps its rock shape.
func _update_rocks(simulation: ColonySimulation) -> void:
	var ground := simulation.ground
	if ground.version == _rocks_version and simulation == _rocks_simulation:
		return
	_rocks_version = ground.version
	_rocks_simulation = simulation
	_rocks.clear()
	for row in ground.rows:
		for column in ground.columns:
			if ground.type_at(column, row) == GroundMap.Type.OBSTACLE:
				var shape := absi(hash(Vector2i(column, row))) % _rock_textures.size()
				_rocks.append({spot = ground.tile_center(column, row), texture = _rock_textures[shape]})


## A sprite standing on `foot` (its bottom middle), `width` map pixels wide.
func _draw_upright(texture: Texture2D, foot: Vector2, width: float) -> void:
	var size := texture.get_size() * (width / texture.get_width())
	draw_set_transform_matrix(Transform2D.IDENTITY)
	draw_texture_rect(texture, Rect2(foot - Vector2(size.x * 0.5, size.y * 0.85), size), false)


## The mound grows with the nest, and turns into the big mound past nest_big_from_radius.
func _draw_nest(simulation: ColonySimulation, spot: Vector2) -> void:
	var is_big := simulation.nest_radius >= _nest_big_from_radius
	var texture := _nest_big_texture if is_big else _nest_small_texture
	_draw_upright(texture, spot, simulation.nest_radius * _nest_width_per_radius)


## A flat sprite lying on the ground at `spot`: turned to `heading` on the map, then
## squashed by the projection like the ground under it. `size` = its length in map pixels.
func _lying_transform(spot: Vector2, heading: float, size: float, texture: Texture2D, to_screen: Transform2D) -> Transform2D:
	var on_map := Transform2D(heading, Vector2.ZERO).scaled(Vector2.ONE * size / texture.get_width())
	var projected := Transform2D(to_screen.x, to_screen.y, Vector2.ZERO) * on_map
	projected.origin = spot
	return projected


func _draw_ant(ant: Ant, spot: Vector2, to_screen: Transform2D) -> void:
	draw_set_transform_matrix(_lying_transform(spot, ant.heading, _ant_size, _ant_texture, to_screen))
	var tint := _scout_tint if ant.is_scout else Color.WHITE
	var half := _ant_texture.get_size() * 0.5
	draw_texture(_ant_texture, -half, tint)
	if ant.is_carrying_food():
		# In the ant's own (unscaled) picture: the crumb sits just in front of the head,
		# bigger when it carries more pieces.
		var crumb_size := _crumb_size * sqrt(ant.carried_food) * _ant_texture.get_width() / _ant_size
		var crumb_rect := Rect2(Vector2(half.x * 0.75, -crumb_size * 0.5), Vector2(crumb_size, crumb_size))
		draw_texture_rect(_crumb_texture, crumb_rect, false)


func _draw_spider(enemy: Enemy, spot: Vector2, to_screen: Transform2D) -> void:
	draw_set_transform_matrix(_lying_transform(spot, enemy.heading, _spider_size, _spider_texture, to_screen))
	draw_texture(_spider_texture, -_spider_texture.get_size() * 0.5)
	draw_set_transform_matrix(Transform2D.IDENTITY)
	var bar_width := _spider_size * 0.6
	var bar_start := spot + Vector2(-bar_width * 0.5, -_spider_size * 0.5)
	draw_line(bar_start, bar_start + Vector2(bar_width * enemy.hp / enemy.max_hp, 0.0), _health_bar_color, _health_bar_thickness)
