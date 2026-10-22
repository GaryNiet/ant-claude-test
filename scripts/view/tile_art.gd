class_name TileArt
extends RefCounted
## Finds the image to draw for a ground tile (the plain colors are used in the debug view,
## or when there is no image).
##
## Images are PNG files in [ground] tile_image_folder, named after the tile type and,
## optionally, the transition to a neighbouring type (see tiles/README.md):
##     dirt_grass_ne.png   dirt tile with grass on its north and east sides
##     dirt.png            any other dirt tile
## Any image can have variants: dirt.png, dirt_2.png, dirt_3.png... Each tile always uses
## the same variant (picked from its position), so the ground doesn't look repetitive.
## The most specific image that exists is used. Lookups are remembered, so checking for
## files only happens once per name.

var _folder: String = GameSettings.get_setting("ground", "tile_image_folder")
var _colors := {}        ## GroundMap.Type -> Color
var _variants := {}      ## image name -> Array of textures (empty when there is no such file)


func _init() -> void:
	for type in GroundMap.TYPE_NAMES:
		_colors[type] = GameSettings.get_color("colors", GroundMap.TYPE_NAMES[type])


func color_of(type: GroundMap.Type) -> Color:
	return _colors[type]


## The image for the tile at `column`, `row`, or null to draw it as a color.
func texture_for(ground: GroundMap, column: int, row: int) -> Texture2D:
	var type_name: String = GroundMap.TYPE_NAMES[ground.type_at(column, row)]
	var transition := ground.transition(column, row)
	var choices: Array = []
	if transition[0] != "":
		choices = _textures("%s_%s_%s" % [type_name, transition[0], transition[1]])
	if choices.is_empty():
		choices = _textures(type_name)
	if choices.is_empty():
		return null
	return choices[_variant_number(column, row) % choices.size()]


## A number that looks random but is always the same for the same tile.
func _variant_number(column: int, row: int) -> int:
	return absi(hash(Vector2i(column, row)))


## `image_name`.png plus its variants _2, _3... that exist (empty if none).
func _textures(image_name: String) -> Array:
	if not _variants.has(image_name):
		var found: Array = []
		var path := "%s/%s.png" % [_folder, image_name]
		while ResourceLoader.exists(path):
			found.append(load(path))
			path = "%s/%s_%d.png" % [_folder, image_name, found.size() + 1]
		_variants[image_name] = found
	return _variants[image_name]
