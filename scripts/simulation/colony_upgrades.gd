class_name ColonyUpgrades
extends RefCounted
## Upgrades the player buys with food stored in the nest. Each one has levels; every level
## costs more than the previous one (base_cost x cost_growth ^ level) and adds a fixed bonus.

enum Kind { ATTACK, HP, SPEED, CARRY, CUT_SPEED, SPAWN }

const LABELS := {
	Kind.ATTACK: "Attack",
	Kind.HP: "Health",
	Kind.SPEED: "Speed",
	Kind.CARRY: "Carry more",
	Kind.CUT_SPEED: "Cut faster",
	Kind.SPAWN: "Faster spawn",
}

## Name of each upgrade's bonus setting in [upgrades].
const BONUS_SETTINGS := {
	Kind.ATTACK: "attack_bonus",
	Kind.HP: "hp_bonus",
	Kind.SPEED: "speed_bonus",
	Kind.CARRY: "carry_bonus",
	Kind.CUT_SPEED: "cut_speed_bonus",
	Kind.SPAWN: "spawn_bonus",
}

var _levels := {}   ## Kind -> number of times bought
var _bonus := {}    ## Kind -> bonus per level
var _base_cost: float = GameSettings.get_setting("upgrades", "base_cost")
var _cost_growth: float = GameSettings.get_setting("upgrades", "cost_growth")
var _max_level: int = GameSettings.get_setting("upgrades", "max_level")


func _init() -> void:
	for kind in Kind.values():
		_levels[kind] = 0
		_bonus[kind] = GameSettings.get_setting("upgrades", BONUS_SETTINGS[kind])


func level_of(kind: Kind) -> int:
	return _levels[kind]


func max_level() -> int:
	return _max_level


func is_maxed(kind: Kind) -> bool:
	return _levels[kind] >= _max_level


## Food needed for the next level of `kind`.
func cost(kind: Kind) -> int:
	return int(round(_base_cost * pow(_cost_growth, _levels[kind])))


## Raises the level of `kind` by one (the caller pays).
func raise(kind: Kind) -> void:
	_levels[kind] += 1


## Total bonus from all levels bought, e.g. 0.5 after two levels of a 0.25 bonus.
func total_bonus(kind: Kind) -> float:
	return _bonus[kind] * _levels[kind]


## One-line description of what the next level does, e.g. "+25% attack".
func describe_bonus(kind: Kind) -> String:
	match kind:
		Kind.CARRY:
			return "+%d food per trip" % int(_bonus[kind])
		Kind.SPAWN:
			return "+%d%% birth speed" % int(_bonus[kind] * 100)
		Kind.CUT_SPEED:
			return "+%d%% cutting speed" % int(_bonus[kind] * 100)
		_:
			return "+%d%% %s" % [int(_bonus[kind] * 100), LABELS[kind].to_lower()]
