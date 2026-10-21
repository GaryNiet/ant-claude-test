class_name TileArt
extends RefCounted
## Finds the image to draw for a ground tile. Until images exist, tiles are plain colors.
##
## Images are PNG files in [ground] tile_image_folder, named after the tile type and,
## optionally, the transition to a neighbouring type (see tiles/README.md):
##     dirt_grass_ne.png   dirt tile with grass on its north and east sides
##     dirt.png            any other dirt tile
## The most specific image that exists is used; if none does, the tile is drawn in its
## [colors] color. Lookups are remembered, so checking for files only happens once per name.

var _folder: String = GameSettings.get_setting("ground", "tile_image_folder")
var _colors := {}        ## GroundMap.Type -> Color
var _textures := {}      ## image name -> Texture2D, or null when there is no such file


func _init() -> void:
	for type in GroundMap.TYPE_NAMES:
		_colors[type] = GameSettings.get_color("colors", GroundMap.TYPE_NAMES[type])


func color_of(type: GroundMap.Type) -> Color:
	return _colors[type]


## The image for the tile at `column`, `row`, or null to draw it as a color.
func texture_for(ground: GroundMap, column: int, row: int) -> Texture2D:
	var type_name: String = GroundMap.TYPE_NAMES[ground.type_at(column, row)]
	var transition := ground.transition(column, row)
	if transition[0] != "":
		var with_transition := _texture("%s_%s_%s" % [type_name, transition[0], transition[1]])
		if with_transition != null:
			return with_transition
	return _texture(type_name)


func _texture(image_name: String) -> Texture2D:
	if not _textures.has(image_name):
		var path := "%s/%s.png" % [_folder, image_name]
		_textures[image_name] = load(path) if ResourceLoader.exists(path) else null
	return _textures[image_name]
