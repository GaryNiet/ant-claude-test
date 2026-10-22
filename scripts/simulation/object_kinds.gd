class_name ObjectKinds
extends RefCounted
## The kinds of objects that can be placed on the map, read from game_settings.cfg:
##   food       blueberry, strawberry, larva... (ants cut pieces off them)
##   obstacles  rock, twig, tree trunk... (block ants and spiders)
## [objects] lists the kinds; each kind has its own [object_<kind>] section with its name,
## the size of the ground it covers (footprint), its sprite size and, for food, how much
## food it holds, what type of food it is (fruit, larva, hard shell, aphids), how long an
## ant takes to cut a piece off, how much food a piece is worth, and whether it fills up
## again (renewable, like aphids).

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


## Its type of food, e.g. "fruit" or "hard shell" (food kinds only).
func food_type(kind: String) -> String:
	return GameSettings.get_setting("object_" + kind, "food_type")


## Food in one piece an ant cuts off and carries home (food kinds only).
func piece_food(kind: String) -> int:
	return GameSettings.get_setting("object_" + kind, "piece_food")


## Seconds an ant needs to cut one piece off it (food kinds only).
func cut_time(kind: String) -> float:
	return GameSettings.get_setting("object_" + kind, "cut_time")


## How many ants can cut from it at the same time (0 = no limit) (food kinds only).
func max_ants(kind: String) -> int:
	return GameSettings.get_setting("object_" + kind, "max_ants")


## True if it never runs out for good: it stays when empty and fills up again (food kinds only).
func is_renewable(kind: String) -> bool:
	return GameSettings.get_setting("object_" + kind, "renewable")


## Food it gets back per minute while not full (renewable food kinds only).
func regrow_per_minute(kind: String) -> float:
	return GameSettings.get_setting("object_" + kind, "regrow_per_minute")
