class_name TechTree
extends RefCounted
## The upgrades a colony can buy with stored food, read from game_settings.cfg ([tech_tree] and
## one [tech_<name>] section per node). They are grouped by vocation (fighting, hatching,
## harvesting) and maturity level; within a group they form a small tree: a node can only be
## bought once its `requires` nodes are owned and the colony is mature enough.

var vocations: PackedStringArray = GameSettings.get_list("tech_tree", "vocations")
var nodes: PackedStringArray = GameSettings.get_list("tech_tree", "nodes")


func label(node: String) -> String:
	return value(node, "label")


func description(node: String) -> String:
	return value(node, "description")


func vocation(node: String) -> String:
	return value(node, "vocation")


func maturity(node: String) -> int:
	return value(node, "maturity")


func cost(node: String) -> int:
	return value(node, "cost")


## The nodes that must be owned before `node` can be bought (empty for a tree's first node).
func requires(node: String) -> PackedStringArray:
	var needed := PackedStringArray()
	for name in GameSettings.get_list("tech_" + node, "requires"):
		if not name.is_empty():
			needed.append(name)
	return needed


## Any value of a node's section, e.g. value("chitinous_armor", "damage_reduction").
func value(node: String, key: String) -> Variant:
	return GameSettings.get_setting("tech_" + node, key)


## The nodes of one vocation and maturity level, in the order of [tech_tree] nodes.
func nodes_in(vocation_name: String, level: int) -> PackedStringArray:
	var found := PackedStringArray()
	for node in nodes:
		if vocation(node) == vocation_name and maturity(node) == level:
			found.append(node)
	return found


## Why `colony` can't buy `node` right now ("" if it can).
func why_not(colony: Colony, node: String) -> String:
	if colony.has_tech(node):
		return "owned"
	if colony.maturity < maturity(node):
		return "needs maturity %d" % maturity(node)
	for needed in requires(node):
		if not colony.has_tech(needed):
			return "needs %s" % label(needed)
	if colony.food_stored < cost(node):
		return "needs %d food" % cost(node)
	return ""
