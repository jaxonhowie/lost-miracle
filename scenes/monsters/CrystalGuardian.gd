extends "res://scenes/monsters/BaseMonster.gd"

var _shield_active: bool = false
var _shield_timer: float = 0.0
const SHIELD_COOLDOWN: float = 12.0
const SHIELD_DURATION: float = 4.0

func _setup_stats():
	monster_id = "elite_crystal_guardian"
	super()
	sprite.color = Color(0.3, 0.6, 0.95, 1)
	sprite.size = Vector2(56, 56)
	skills.append({
		"name": "crystal_shield",
		"cooldown": SHIELD_COOLDOWN,
		"timer": 8.0,
		"range": -1.0,
		"execute": _activate_shield,
	})

func _activate_shield():
	_shield_active = true
	_shield_timer = SHIELD_DURATION
	sprite.modulate = Color(0.5, 0.8, 1.0, 0.8)
	# Visual feedback
	var tween = create_tween()
	tween.tween_property(sprite, "modulate", Color(0.3, 0.6, 0.95, 1), 0.3)

func _process(delta):
	super(delta)
	if _shield_active:
		_shield_timer -= delta
		if _shield_timer <= 0:
			_shield_active = false
			sprite.modulate = Color(1, 1, 1, 1)

func _on_damage_taken(_raw_damage: int, final_damage: int) -> int:
	if _shield_active:
		return maxi(1, final_damage / 3)
	return final_damage
