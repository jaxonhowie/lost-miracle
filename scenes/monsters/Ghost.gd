extends "res://scenes/monsters/BaseMonster.gd"

var _phase_active: bool = false
var _phase_timer: float = 0.0
const PHASE_DURATION: float = 3.0
var _original_collision_layer: int = 0

func _setup_stats():
	monster_id = "ghost"
	super()
	sprite.color = Color(0.6, 0.7, 1.0, 0.7)
	collision_mask = 0
	_original_collision_layer = collision_layer

	skills = [
		{
			"name": "Phase Shift",
			"cooldown": 10.0,
			"timer": 5.0,
			"range": -1.0,
			"execute": _phase_shift
		}
	]

func _phase_shift():
	_phase_active = true
	_phase_timer = PHASE_DURATION
	collision_layer = 0
	sprite.modulate.a = 0.3

func _process_skills(delta):
	super(delta)
	if _phase_active:
		_phase_timer -= delta
		if _phase_timer <= 0:
			_phase_active = false
			collision_layer = _original_collision_layer
			sprite.modulate.a = 1.0

func take_damage(raw_damage: int, attacker_position: Vector2, is_crit: bool = false):
	if _phase_active:
		return
	super(raw_damage, attacker_position, is_crit)
