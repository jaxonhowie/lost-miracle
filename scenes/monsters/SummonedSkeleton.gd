extends "res://scenes/monsters/BaseMonster.gd"

var summon_lifetime: float = 15.0

func _setup_stats():
	monster_id = "skeleton_soldier"
	hp = 30
	max_hp = 30
	attack_power = 5
	defense = 0
	move_speed = 90.0
	attack_interval = 1.0
	experience = 0
	sprite.color = Color(0.6, 0.55, 0.4, 0.8)
	sprite.size = Vector2(30, 30)

func _on_ready_extra():
	monster_id = ""

func _physics_process(delta):
	super(delta)
	summon_lifetime -= delta
	if summon_lifetime <= 0 and current_state != State.DEAD:
		_die()
