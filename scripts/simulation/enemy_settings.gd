class_name EnemySettings
extends RefCounted
## All enemy values, read once from the [enemies] section of game_settings.cfg.

var radius: float = GameSettings.get_setting("enemies", "radius")
var speed: float = GameSettings.get_setting("enemies", "speed")
var turn_speed: float = GameSettings.get_setting("enemies", "turn_speed")
var wander: float = GameSettings.get_setting("enemies", "wander")
var hp: float = GameSettings.get_setting("enemies", "hp")
var attack: float = GameSettings.get_setting("enemies", "attack")
var attack_interval: float = GameSettings.get_setting("enemies", "attack_interval")
var food_when_killed: int = GameSettings.get_setting("enemies", "food_when_killed")
var food_pile_radius: float = GameSettings.get_setting("enemies", "food_pile_radius")
var first_arrival: float = GameSettings.get_setting("enemies", "first_arrival")
var arrival_interval: float = GameSettings.get_setting("enemies", "arrival_interval")
var max_alive: int = GameSettings.get_setting("enemies", "max_alive")
