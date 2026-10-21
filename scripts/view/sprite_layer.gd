extends Node2D
## Isometric view only: draws the things standing on the ground as sprites, at their
## projected positions:
##   objects     food items (blueberry, larva, dead spider...) with a yellow glow under them,
##               losing pixels as ants eat them; obstacles (rock, twig, tree trunk...)
##   nests       ant hills; the big one once the colony has grown; ours has a flag on top
##               (rival colonies' ants are red)
##   dead ants   lying on their back, fading away
##   ants        upright, parallel to the screen, in one of 4 directions (towards the screen
##               or away from it, to the left or right) matching where they walk on screen,
##               with a 2-frame walk; an ant carrying food holds a crumb; scouts are darker
##   spiders     the enemies, drawn like the ants, with a health bar above them
## Ants and spiders are drawn between their previous and current position (see
## SimulationView.tick_fraction), so they move smoothly between simulation ticks.
## Everything is drawn from back to front (sorted by how far down the screen it stands),
## so whatever is in front covers what is behind it.

## Sprite files in [iso_view] sprite_folder (made by tools/make_art.py):
## <creature>_<direction>_<frame>.png, direction = se, sw, ne, nw (s = towards the screen);
## objects/<kind>.png, with optional variants objects/<kind>_2.png, _3...
const ANT_NAME := "ant"
const RIVAL_ANT_NAME := "ant_rival"
const MAJOR_ANT_NAME := "ant_major"
const RIVAL_MAJOR_ANT_NAME := "ant_rival_major"
const FLAG_IMAGE := "flag.png"
const SPIDER_NAME := "spider"
const DIRECTIONS := ["se", "sw", "ne", "nw"]
const WALK_FRAMES := 2
## Creatures, objects and the nest touch the ground this many image pixels above the bottom
## of the image (GROUND_MARGIN in tools/make_art.py).
const GROUND_MARGIN_PIXELS := 3.0
## Where an ant's mouth is, as a fraction of the image size, when it faces right:
## towards the screen / away from it (mirrored when it faces left).
const MOUTH_TOWARDS_SCREEN := Vector2(0.84, 0.62)
const MOUTH_AWAY_FROM_SCREEN := Vector2(0.78, 0.36)
const CRUMB_IMAGE := "food_crumb.png"
const NEST_SMALL_IMAGE := "nest_small.png"
const NEST_BIG_IMAGE := "nest_big.png"
const DEAD_ANT_IMAGES := {"e": "ant_dead_e.png", "w": "ant_dead_w.png"}
const DEAD_RIVAL_ANT_IMAGES := {"e": "ant_rival_dead_e.png", "w": "ant_rival_dead_w.png"}
const GLOW_IMAGE := "food_glow.png"
const OBJECT_FOLDER := "objects"

enum Kind { OBJECT, NEST, ANT, DEAD_ANT, SPIDER }

@onready var view: Node2D = get_parent()  ## SimulationView

var _ant_frames := {}      ## direction -> Array of textures (walk frames)
var _rival_ant_frames := {}
var _major_ant_frames := {}
var _rival_major_ant_frames := {}
var _flag_texture: Texture2D
var _spider_frames := {}
var _crumb_texture: Texture2D
var _nest_small_texture: Texture2D
var _nest_big_texture: Texture2D
var _dead_ant_textures := {}   ## "e" / "w" -> texture
var _dead_rival_ant_textures := {}
var _glow_texture: Texture2D
var _object_variants := {}     ## kind -> Array of textures
var _eaten := {}               ## food object id -> {food_left, texture}: its sprite with pixels removed
var _eaten_simulation: ColonySimulation  ## ids start again in a new simulation: forget _eaten then
var _folder: String = GameSettings.get_setting("iso_view", "sprite_folder")

var _ant_size: float = GameSettings.get_setting("iso_view", "ant_size")
var _spider_size: float = GameSettings.get_setting("iso_view", "spider_size")
var _crumb_size: float = GameSettings.get_setting("iso_view", "crumb_size")
var _glow_size: float = GameSettings.get_setting("objects", "food_glow_size")
var _glow_color: Color = GameSettings.get_color("objects", "food_glow_color")
var _dead_ant_fade_time: float = GameSettings.get_setting("ant_life", "dead_ant_fade_time")
var _nest_width_per_radius: float = GameSettings.get_setting("iso_view", "nest_width_per_radius")
var _nest_big_from_radius: float = GameSettings.get_setting("iso_view", "nest_big_from_radius")
var _flag_width: float = GameSettings.get_setting("iso_view", "flag_width")
var _scout_tint: Color = GameSettings.get_color("iso_view", "scout_tint")
var _walk_frames_per_second: float = GameSettings.get_setting("iso_view", "walk_frames_per_second")
var _time := 0.0
var _health_bar_color: Color = GameSettings.get_color("colors", "enemy_health_bar")
var _health_bar_thickness: float = GameSettings.get_setting("display", "enemy_health_bar_thickness")



func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # crisp pixel art
	_glow_color.a = GameSettings.get_setting("objects", "food_glow_opacity")
	_ant_frames = _load_directions(_folder, ANT_NAME)
	_rival_ant_frames = _load_directions(_folder, RIVAL_ANT_NAME)
	_major_ant_frames = _load_directions(_folder, MAJOR_ANT_NAME)
	_rival_major_ant_frames = _load_directions(_folder, RIVAL_MAJOR_ANT_NAME)
	_flag_texture = load("%s/%s" % [_folder, FLAG_IMAGE])
	_spider_frames = _load_directions(_folder, SPIDER_NAME)
	_crumb_texture = load("%s/%s" % [_folder, CRUMB_IMAGE])
	_nest_small_texture = load("%s/%s" % [_folder, NEST_SMALL_IMAGE])
	_nest_big_texture = load("%s/%s" % [_folder, NEST_BIG_IMAGE])
	_glow_texture = load("%s/%s" % [_folder, GLOW_IMAGE])
	for side in DEAD_ANT_IMAGES:
		_dead_ant_textures[side] = load("%s/%s" % [_folder, DEAD_ANT_IMAGES[side]])
		_dead_rival_ant_textures[side] = load("%s/%s" % [_folder, DEAD_RIVAL_ANT_IMAGES[side]])


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
	if simulation != _eaten_simulation:
		_eaten.clear()
		_eaten_simulation = simulation
	_draw_food_glows(simulation, to_screen)
	for item in _things_back_to_front(simulation, to_screen):
		match item.kind:
			Kind.OBJECT:
				_draw_object(simulation, item.thing, item.spot)
			Kind.DEAD_ANT:
				_draw_dead_ant(item.thing, item.spot, to_screen)
			Kind.NEST:
				_draw_nest(item.thing, item.spot)
			Kind.ANT:
				_draw_ant(item.thing, item.spot, to_screen)
			Kind.SPIDER:
				_draw_spider(item.thing, item.spot, to_screen)


## Everything to draw, with its projected position, sorted from the top of the screen down.
func _things_back_to_front(simulation: ColonySimulation, to_screen: Transform2D) -> Array[Dictionary]:
	var things: Array[Dictionary] = []
	for object in simulation.objects:
		things.append({kind = Kind.OBJECT, spot = to_screen * object.position, thing = object})
	for dead in simulation.dead_ants:
		things.append({kind = Kind.DEAD_ANT, spot = to_screen * dead.position, thing = dead})
	for colony in simulation.colonies:
		if not colony.destroyed:
			things.append({kind = Kind.NEST, spot = to_screen * colony.nest_position, thing = colony})
	var between_ticks: float = view.tick_fraction()
	for ant in simulation.ants:
		var spot := ant.previous_position.lerp(ant.position, between_ticks)
		things.append({kind = Kind.ANT, spot = to_screen * spot, thing = ant})
	for enemy in simulation.enemies:
		var spot := enemy.previous_position.lerp(enemy.position, between_ticks)
		things.append({kind = Kind.SPIDER, spot = to_screen * spot, thing = enemy})
	things.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.spot.y < b.spot.y)
	return things


# --- Objects -------------------------------------------------------------------------

## A soft yellow light on the ground under every food item (drawn before everything else).
func _draw_food_glows(simulation: ColonySimulation, to_screen: Transform2D) -> void:
	for object in simulation.objects:
		if object.is_food():
			var width := simulation.object_kinds.sprite_width(object.kind) * _glow_size
			var size := Vector2(width, width * view.projection().y.y)  # flattened like the ground
			draw_texture_rect(_glow_texture, Rect2(to_screen * object.position - size * 0.5, size), false, _glow_color)


func _draw_object(simulation: ColonySimulation, object: MapObject, spot: Vector2) -> void:
	var texture := _object_texture(object)
	if object.is_food() and object.food_left < object.total_food:
		texture = _eaten_texture(object, texture)
	_draw_upright(texture, spot, simulation.object_kinds.sprite_width(object.kind), _foot_height(texture))


## The object's sprite: its kind's image, or one of its variants (picked from its id).
func _object_texture(object: MapObject) -> Texture2D:
	if not _object_variants.has(object.kind):
		var found: Array = []
		var path := "%s/%s/%s.png" % [_folder, OBJECT_FOLDER, object.kind]
		while ResourceLoader.exists(path):
			found.append(load(path))
			path = "%s/%s/%s_%d.png" % [_folder, OBJECT_FOLDER, object.kind, found.size() + 1]
		_object_variants[object.kind] = found
	var variants: Array = _object_variants[object.kind]
	return variants[object.id % variants.size()]


## A partly eaten food item: the same share of its pixels as of its food is removed, in
## an order that looks random but is always the same for this item. Rebuilt only when its
## food changes.
func _eaten_texture(object: MapObject, full: Texture2D) -> Texture2D:
	if _eaten.has(object.id) and _eaten[object.id].food_left == object.food_left:
		return _eaten[object.id].texture
	var image := full.get_image()
	image.convert(Image.FORMAT_RGBA8)
	var solid_pixels: Array[Vector2i] = []
	for y in image.get_height():
		for x in image.get_width():
			if image.get_pixel(x, y).a > 0.9:
				solid_pixels.append(Vector2i(x, y))
	var order := RandomNumberGenerator.new()
	order.seed = object.id
	for index in range(solid_pixels.size() - 1, 0, -1):  # shuffle (Fisher-Yates)
		var other := order.randi_range(0, index)
		var swap := solid_pixels[index]
		solid_pixels[index] = solid_pixels[other]
		solid_pixels[other] = swap
	var eaten_share := 1.0 - float(object.food_left) / object.total_food
	for index in int(solid_pixels.size() * eaten_share):
		image.set_pixelv(solid_pixels[index], Color.TRANSPARENT)
	_eaten[object.id] = {food_left = object.food_left, texture = ImageTexture.create_from_image(image)}
	return _eaten[object.id].texture


func _draw_dead_ant(dead: Dictionary, spot: Vector2, to_screen: Transform2D) -> void:
	var side := "e" if to_screen.basis_xform(Vector2.from_angle(dead.heading)).x >= 0.0 else "w"
	var textures: Dictionary = _dead_ant_textures if dead.colony.is_player else _dead_rival_ant_textures
	var texture: Texture2D = textures[side]
	var fade := Color(1.0, 1.0, 1.0, 1.0 - dead.time_dead / _dead_ant_fade_time)
	_draw_upright(texture, spot, _ant_size, _foot_height(texture), fade)


## A sprite standing on `foot`, `width` map pixels wide. `foot_height` = where its foot line
## is, as a fraction of the image height from the top.
func _draw_upright(texture: Texture2D, foot: Vector2, width: float, foot_height: float, tint := Color.WHITE) -> Rect2:
	var size := texture.get_size() * (width / texture.get_width())
	var area := Rect2(foot - Vector2(size.x * 0.5, size.y * foot_height), size)
	draw_texture_rect(texture, area, false, tint)
	return area


## The hill grows with the nest, and turns into the big hill past nest_big_from_radius.
## Our colony's hill has a flag on top, so it's easy to tell apart from rival nests.
func _draw_nest(colony: Colony, spot: Vector2) -> void:
	var is_big := colony.nest_radius >= _nest_big_from_radius
	var texture := _nest_big_texture if is_big else _nest_small_texture
	var area := _draw_upright(texture, spot, colony.nest_radius * _nest_width_per_radius, _foot_height(texture))
	if colony.is_player:
		var hill_top := Vector2(area.get_center().x, area.position.y + area.size.y * 0.3)
		_draw_upright(_flag_texture, hill_top, _flag_width, _foot_height(_flag_texture))


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


## Where a sprite touches the ground, as a fraction of its height from the top.
func _foot_height(texture: Texture2D) -> float:
	return 1.0 - GROUND_MARGIN_PIXELS / texture.get_height()


func _draw_ant(ant: Ant, spot: Vector2, to_screen: Transform2D) -> void:
	var direction := _screen_direction(ant.heading, to_screen)
	var is_walking := ant.mode != Ant.Mode.FIGHTING and ant.mode != Ant.Mode.CUTTING_FOOD
	var texture := _frame(ant, _frames_for(ant)[direction], is_walking)
	var tint := _scout_tint if ant.is_scout else Color.WHITE
	var towards_screen := direction.begins_with("s")
	if ant.is_carrying_food() and not towards_screen:
		_draw_crumb(ant, spot, texture, direction)  # held in front of the head, which faces away: behind the body
	_draw_upright(texture, spot, _ant_size * ant.size_multiplier, _foot_height(texture), tint)
	if ant.is_carrying_food() and towards_screen:
		_draw_crumb(ant, spot, texture, direction)


## The crumb in the ant's mouth, bigger when it carries more pieces.
func _draw_crumb(ant: Ant, spot: Vector2, ant_texture: Texture2D, direction: String) -> void:
	var size := ant_texture.get_size() * (_ant_size * ant.size_multiplier / ant_texture.get_width())
	var top_left := spot - Vector2(size.x * 0.5, size.y * _foot_height(ant_texture))
	var mouth := MOUTH_TOWARDS_SCREEN if direction.begins_with("s") else MOUTH_AWAY_FROM_SCREEN
	if direction.ends_with("w"):
		mouth.x = 1.0 - mouth.x
	var crumb := _crumb_size * sqrt(ant.carried_food)
	var center := top_left + mouth * size
	draw_texture_rect(_crumb_texture, Rect2(center - Vector2(crumb, crumb) * 0.5, Vector2(crumb, crumb)), false)


## Our team's ants are orange, other teams' red; majors have their own sprites.
func _frames_for(ant: Ant) -> Dictionary:
	var ours: bool = ant.colony.team == view.simulation.player_colony.team
	if ant.is_major:
		return _major_ant_frames if ours else _rival_major_ant_frames
	return _ant_frames if ours else _rival_ant_frames


func _draw_spider(enemy: Enemy, spot: Vector2, to_screen: Transform2D) -> void:
	var direction := _screen_direction(enemy.heading, to_screen)
	var is_walking := enemy.ants_in_contact.is_empty() and enemy.state != Enemy.State.EATING
	var texture := _frame(enemy, _spider_frames[direction], is_walking)
	var area := _draw_upright(texture, spot, _spider_size, _foot_height(texture))
	var bar_width := _spider_size * 0.6
	var bar_start := Vector2(spot.x - bar_width * 0.5, area.position.y - _health_bar_thickness * 2.0)
	draw_line(bar_start, bar_start + Vector2(bar_width * enemy.hp / enemy.max_hp, 0.0), _health_bar_color, _health_bar_thickness)
