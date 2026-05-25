extends "res://scenes/monsters/BaseMonster.gd"

var summon_lifetime: float = 15.0
var is_summoned: bool = true

func _setup_stats():
	monster_id = "summoned_skeleton"
	super()
	sprite.color = Color(0.6, 0.55, 0.4, 0.8)
	sprite.size = Vector2(30, 30)
	collision_mask = 0

func _physics_process(delta):
	super(delta)
	summon_lifetime -= delta
	if summon_lifetime <= 0 and current_state != State.DEAD:
		_die()
