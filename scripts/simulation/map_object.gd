class_name MapObject
extends RefCounted
## One object placed on the map: a food item (a blueberry, a larva, a dead spider...) or an
## obstacle (a rock, a twig, a tree trunk...). It covers the map cells of its footprint:
## a food item puts its food in those cells, an obstacle blocks them.

var id: int                       ## unique in its simulation (also picks its sprite variant)
var kind: String                  ## e.g. "blueberry", see ObjectKinds
var category: ObjectKinds.Category
var position: Vector2             ## center, in map pixels
var cells := PackedInt32Array()   ## indexes of the map cells it covers
var total_food := 0               ## food it held when placed (0 for obstacles)
var food_left := 0               ## food still in it


func _init(object_id: int, object_kind: String, object_category: ObjectKinds.Category, spot: Vector2) -> void:
	id = object_id
	kind = object_kind
	category = object_category
	position = spot


func is_food() -> bool:
	return category == ObjectKinds.Category.FOOD
