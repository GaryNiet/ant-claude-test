extends SceneTree
## Balance test: plays a level without graphics, with a scripted player following one
## strategy, and prints the colony every 2 (real) minutes. Run from the project folder:
##
##   godot --headless --path . -s tools/balance_test.gd -- <level> <strategy> <larvae_at> <minutes> <seed>
##
##   level       e.g. res://levels/level_1.level
##   strategy    grow     only lays larvae
##               econ<N>  first buys N economy upgrades (carry more, mushroom harvest, motherbase, faster larvae)
##               up<N>    first buys N upgrades from a mixed list (carry more, armor, restraining bite...)
##               cricket  armor and restraining bite first, then hunts crickets
##               raid     armor and restraining bite first, then sends the attack ants at the rival nest
##   larvae_at   game seconds before it sends the attack ants at the beetle larvae (-1 = never)
##   minutes     real minutes to play (the game runs at [simulation] game_speed)
##   seed        random seed (run a few to see the spread)
##
## While saving for an upgrade it only lays larvae with the food left over. With Restraining bite
## (or 40 ants) it sends the attack ants at the nearest cricket every 20 game seconds.
## (The player script is loaded once the game's autoloads exist: see balance_player.gd.)

var _player


func _initialize() -> void:
	await process_frame
	_player = load("res://tools/balance_player.gd").new()
	_player.run(OS.get_cmdline_user_args())
	quit()
