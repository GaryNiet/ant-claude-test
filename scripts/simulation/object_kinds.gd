class_name ObjectKinds
extends RefCounted
## The kinds of objects that can be placed on the map, read from game_settings.cfg:
##   food       blueberry, strawberry, larva... (ants cut pieces off them)
##   obstacles  rock, twig, tree trunk... (block ants and spiders)
## [objects] lists the kinds; each kind has its own [object_<kind>] section with its name,
## the size of the ground it covers (footprint), its sprite size and, for food, how much
## food it holds.

enum Category { FOOD, OBSTACLE }

var food_kinds: PackedStringArray = GameSettings.get_list("objects", "food_kinds")
var obstacle_kinds: PackedStringArray = GameSettings.get_list("objects", "obstacle_kinds")


func category(kind: String) -> Category:
	return Category.FOOD if kind in food_kinds else Category.OBSTACLE


func label(kind: String) -> String:
	return GameSettings.get_setting("object_" + kind, "label")


## Radius (map pixels) of the ground it covers: every cell whose center is inside.
func footprint_radius(kind: String) -> float:
	return GameSettings.get_setting("object_" + kind, "footprint_radius")


## Width of its sprite in map pixels (isometric view).
func sprite_width(kind: String) -> float:
	return GameSettings.get_setting("object_" + kind, "sprite_width")


## Food it holds when placed (food kinds only).
func food(kind: String) -> int:
	return GameSettings.get_setting("object_" + kind, "food")
