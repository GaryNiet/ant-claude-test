extends Node2D
## Isometric view only: draws the things standing on the ground as sprites, at their
## projected positions:
##   rocks       one per obstacle tile, upright
##   nest        a dirt mound, upright; the big one once the colony has grown
##   ants        upright, parallel to the screen, in one of 4 directions (towards the screen
##               or away from it, to the left or right) matching where they walk on screen,
##               with a 2-frame walk; an ant carrying food holds a crumb; scouts are darker
##   spiders     the enemies, drawn like the ants, with a health bar above them
## Everything is drawn from back to front (sorted by how far down the screen it stands),
## so whatever is in front covers what is behind it.

## Sprite files in [iso_view] sprite_folder (made by tools/make_art.py):
## <creature>_<direction>_<frame>.png, direction = se, sw, ne, nw (s = towards the screen).
const ANT_NAME := "ant"
const SPIDER_NAME := "spider"
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const WALK_FRAMES := 2
## Creatures' feet touch the ground this many image pixels above the bottom of the image
## (GROUND_MARGIN in tools/make_art.py).
const GROUND_MARGIN_PIXELS := 3.0
## Where an ant's mouth is, as a fraction of the image size, when it faces right:
## towards the screen / away from it (mirrored when it faces left).
const MOUTH_TOWARDS_SCREEN := Vector2(0.84, 0.62)
const MOUTH_AWAY_FROM_SCREEN := Vector2(0.78, 0.36)
const CRUMB_IMAGE := "food_crumb.png"
const NEST_SMALL_IMAGE := "nest_small.png"
const NEST_BIG_IMAGE := "nest_big.png"
const ROCK_IMAGES := ["rock_1.png", "rock_2.png", "rock_3.png"]

enum Kind { ROCK, NEST, ANT, SPIDER }

@onready var view: Node2D = get_parent()  ## SimulationView

var _ant_frames := {}      ## direction -> Array of textures (walk frames)
var _spider_frames := {}
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
var _walk_frames_per_second: float = GameSettings.get_setting("iso_view", "walk_frames_per_second")
var _time := 0.0
var _health_bar_color: Color = GameSettings.get_color("colors", "enemy_health_bar")
var _health_bar_thickness: float = GameSettings.get_setting("display", "enemy_health_bar_thickness")

var _rocks: Array[Dictionary] = []   ## obstacle tiles: {spot, texture}, rebuilt when the ground changes
var _rocks_version := -1
var _rocks_simulation: ColonySimulation


func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixel art
	var folder: String = GameSettings.get_setting("iso_view", "sprite_folder")
	_ant_frames = _load_directions(folder, ANT_NAME)
	_spider_frames = _load_directions(folder, SPIDER_NAME)
	_crumb_texture = load("%s/%s" % [folder, CRUMB_IMAGE])
	_nest_small_texture = load("%s/%s" % [folder, NEST_SMALL_IMAGE])
	_nest_big_texture = load("%s/%s" % [folder, NEST_BIG_IMAGE])
	for image in ROCK_IMAGES:
		_rock_textures.append(load("%s/%s" % [folder, image]))


## direction -> [frame 1, frame 2] for one creature.
func _load_directions(folder: String, creature: String) -> Dictionary:
	var frames := {}
	for direction in DIRECTIONS:
		frames[direction] = []
		for frame in WALK_FRAMES:
			frames[direction].append(load("%s/%s_%s_%d.png" % [folder, creature, direction, frame + 1]))
	return frames


func _process(delta: float) -> void:
	if visible:
		if not view.is_paused:
			_time += delta
		queue_redraw()


func _draw() -> void:
	var simulation: ColonySimulation = view.simulation
	var to_screen: Transform2D = view.map_space.transform
	for item in _things_back_to_front(simulation, to_screen):
		match item.kind:
			Kind.ROCK:
				_draw_upright(item.texture, item.spot, _rock_width, 0.85)
			Kind.NEST:
				_draw_nest(simulation, item.spot)
			Kind.ANT:
				_draw_ant(item.thing, item.spot, to_screen)
			Kind.SPIDER:
				_draw_spider(item.thing, item.spot, to_screen)


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


## A sprite standing on `foot`, `width` map pixels wide. `foot_height` = where its foot line
## is, as a fraction of the image height from the top.
func _draw_upright(texture: Texture2D, foot: Vector2, width: float, foot_height: float, tint := Color.WHITE) -> Rect2:
	var size := texture.get_size() * (width / texture.get_width())
	var area := Rect2(foot - Vector2(size.x * 0.5, size.y * foot_height), size)
	draw_texture_rect(texture, area, false, tint)
	return area


## The mound grows with the nest, and turns into the big mound past nest_big_from_radius.
func _draw_nest(simulation: ColonySimulation, spot: Vector2) -> void:
	var is_big := simulation.nest_radius >= _nest_big_from_radius
	var texture := _nest_big_texture if is_big else _nest_small_texture
	_draw_upright(texture, spot, simulation.nest_radius * _nest_width_per_radius, 0.85)


## Which of the 4 directions a creature walking along `heading` (on the map) looks like on
## screen: "s" = coming towards the screen (down), "n" = going away (up); then east / west.
func _screen_direction(heading: float, to_screen: Transform2D) -> String:
	var on_screen := to_screen.basis_xform(Vector2.from_angle(heading))
	return ("s" if on_screen.y >= 0.0 else "n") + ("e" if on_screen.x >= 0.0 else "w")


## The walking frame to show. Each creature starts its walk at its own moment (from its id),
## so they don't all step in sync. Creatures standing still show the first frame.
func _frame(creature: Object, frames: Array, is_walking: bool) -> Texture2D:
	if not is_walking:
		return frames[0]
	var offset := float(creature.get_instance_id() % 97) / 97.0
	return frames[int(_time * _walk_frames_per_second + offset * frames.size()) % frames.size()]


func _creature_foot_height(texture: Texture2D) -> float:
	return 1.0 - GROUND_MARGIN_PIXELS / texture.get_height()


func _draw_ant(ant: Ant, spot: Vector2, to_screen: Transform2D) -> void:
	var direction := _screen_direction(ant.heading, to_screen)
	var is_walking := ant.mode != Ant.Mode.FIGHTING and ant.mode != Ant.Mode.CUTTING_FOOD
	var texture := _frame(ant, _ant_frames[direction], is_walking)
	var tint := _scout_tint if ant.is_scout else Color.WHITE
	var towards_screen := direction.begins_with("s")
	if ant.is_carrying_food() and not towards_screen:
		_draw_crumb(ant, spot, texture, direction)  # held in front of the head, which faces away: behind the body
	_draw_upright(texture, spot, _ant_size, _creature_foot_height(texture), tint)
	if ant.is_carrying_food() and towards_screen:
		_draw_crumb(ant, spot, texture, direction)


## The crumb in the ant's mouth, bigger when it carries more pieces.
func _draw_crumb(ant: Ant, spot: Vector2, ant_texture: Texture2D, direction: String) -> void:
	var size := ant_texture.get_size() * (_ant_size / ant_texture.get_width())
	var top_left := spot - Vector2(size.x * 0.5, size.y * _creature_foot_height(ant_texture))
	var mouth := MOUTH_TOWARDS_SCREEN if direction.begins_with("s") else MOUTH_AWAY_FROM_SCREEN
	if direction.ends_with("w"):
		mouth.x = 1.0 - mouth.x
	var crumb := _crumb_size * sqrt(ant.carried_food)
	var center := top_left + mouth * size
	draw_texture_rect(_crumb_texture, Rect2(center - Vector2(crumb, crumb) * 0.5, Vector2(crumb, crumb)), false)


func _draw_spider(enemy: Enemy, spot: Vector2, to_screen: Transform2D) -> void:
	var direction := _screen_direction(enemy.heading, to_screen)
	var is_walking := enemy.ants_in_contact.is_empty() and enemy.state != Enemy.State.EATING
	var texture := _frame(enemy, _spider_frames[direction], is_walking)
	var area := _draw_upright(texture, spot, _spider_size, _creature_foot_height(texture))
	var bar_width := _spider_size * 0.6
	var bar_start := Vector2(spot.x - bar_width * 0.5, area.position.y - _health_bar_thickness * 2.0)
	draw_line(bar_start, bar_start + Vector2(bar_width * enemy.hp / enemy.max_hp, 0.0), _health_bar_color, _health_bar_thickness)
