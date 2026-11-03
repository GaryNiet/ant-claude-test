class_name GameSession
extends RefCounted
## Moving between the main menu and the game. The menu picks a level, then switches
## to the game scene, which reads `level_path` to know what to load.

const MAIN_MENU_SCENE := "res://scenes/main_menu.tscn"
const GAME_SCENE := "res://scenes/game.tscn"

## The level the game scene loads. Empty when the game scene is started on its own
## (F6 in the Godot editor): then the first level of the menu is used.
static var level_path := ""


static func play_level(tree: SceneTree, path: String) -> void:
	level_path = path
	tree.change_scene_to_file(GAME_SCENE)


static func back_to_main_menu(tree: SceneTree) -> void:
	tree.change_scene_to_file(MAIN_MENU_SCENE)


## The level to load in the game scene.
static func current_level_path() -> String:
	if level_path.is_empty():
		return GameSettings.get_list("menu", "levels")[0]
	return level_path
