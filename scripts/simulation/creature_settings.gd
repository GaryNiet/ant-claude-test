class_name CreatureSettings
extends RefCounted
## The values of one kind of creature (spider, beetle larva, cricket), read once from its
## [creature_<kind>] section of game_settings.cfg. The values every creature has are
## variables; the ones only one kind uses are read with value().

var kind: String
var label: String             ## its name in the side panel
var plural: String            ## the same, for several
var radius: float             ## body size in pixels (ants are pushed out of it)
var speed: float              ## pixels per second (ants walk 45)
var turn_speed: float         ## radians per second
var wander: float             ## random wobble, radians per second
var hp: float
var attack: float             ## damage per hit to a touching ant (0 = never fights back)
var attack_interval: float    ## seconds between two hits
var always_hostile: bool      ## true = ants fight it on sight; false = only once it was attacked
var hold_per_ant: float       ## share of its speed each touching ant takes away (0 = can't be held)
var food_object: String       ## the food item its body becomes when killed
var sprite: String            ## sprite name in [iso_view] sprite_folder
var sprite_size: float        ## width of its sprite in map pixels
var _section: String


func _init(creature_kind: String) -> void:
	kind = creature_kind
	_section = "creature_" + kind
	label = value("label")
	plural = value("plural")
	radius = value("radius")
	speed = value("speed")
	turn_speed = value("turn_speed")
	wander = value("wander")
	hp = value("hp")
	attack = value("attack")
	attack_interval = value("attack_interval")
	always_hostile = value("always_hostile")
	hold_per_ant = value("hold_per_ant")
	food_object = value("food_object")
	sprite = value("sprite")
	sprite_size = value("sprite_size")


## Any other value of this kind's section.
func value(key: String) -> Variant:
	return GameSettings.get_setting(_section, key)
