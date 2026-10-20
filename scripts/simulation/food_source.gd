class_name FoodSource
extends RefCounted
## A pile of food on the map. Each ant takes 1 unit; the pile disappears when empty.

var position: Vector2
var amount: int


func _init(at: Vector2, starting_amount: int) -> void:
	position = at
	amount = starting_amount


func is_empty() -> bool:
	return amount <= 0
