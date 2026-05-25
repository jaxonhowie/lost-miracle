extends "res://scenes/monsters/BaseMonster.gd"

var _shield_active: bool = false
var _shield_timer: float = 0.0
const SHIELD_DURATION: float = 2.0

func _setup_stats():
	monster_id = "skeleton_soldier"
	super()
	sprite.color = Color(0.9, 0.85, 0.7, 1)

	skills = [
		{
			"name": "Shield Block",
			"cooldown": 8.0,
			"timer": 3.0,
			"range": -1.0,
			"execute": _shield_block
		}
	]

func _shield_block():
	_shield_active = true
	_shield_timer = SHIELD_DURATION
	sprite.color = Color(0.9, 0.85, 0.5, 1)  # Yellow tint

func _process_skills(delta):
	super(delta)
	if _shield_active:
		_shield_timer -= delta
		if _shield_timer <= 0:
			_shield_active = false
			sprite.color = Color(0.9, 0.85, 0.7, 1)

func _on_damage_taken(_raw_damage: int, final_damage: int) -> int:
	if _shield_active:
		return int(final_damage * 0.5)
	return final_damage
