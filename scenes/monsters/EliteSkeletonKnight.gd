extends "res://scenes/monsters/BaseMonster.gd"

var is_blocking: bool = false
var block_timer: float = 0.0
const BLOCK_DURATION: float = 2.0
const BLOCK_REDUCTION: float = 0.5

var charge_speed: float = 400.0
var is_charging: bool = false

func _setup_stats():
	monster_id = "elite_skeleton_knight"
	hp = 450
	max_hp = 450
	attack_power = 24
	defense = 6
	move_speed = 95.0
	attack_interval = 1.1
	experience = 50
	sprite.color = Color(0.7, 0.7, 0.75, 1)

	skills = [
		{
			"name": "Heavy Slash",
			"cooldown": 5.0,
			"timer": 0.0,
			"range": 80.0,
			"execute": _heavy_slash
		},
		{
			"name": "Charge",
			"cooldown": 8.0,
			"timer": 0.0,
			"range": 200.0,
			"execute": _charge
		},
		{
			"name": "Block",
			"cooldown": 10.0,
			"timer": 0.0,
			"range": -1.0,
			"execute": _block
		}
	]

func _heavy_slash():
	attack_area.monitoring = true
	var shape = attack_area.get_node("CollisionShape2D").shape
	var orig_size = shape.size
	shape.size = Vector2(orig_size.x * 1.4, orig_size.y * 1.3)
	await get_tree().create_timer(0.2).timeout
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(int(attack_power * 1.4), global_position)
	await get_tree().create_timer(0.15).timeout
	attack_area.monitoring = false
	shape.size = orig_size

func _charge():
	if not is_instance_valid(player_ref):
		return
	is_charging = true
	var dir = (player_ref.global_position - global_position).normalized()
	_update_facing_toward(player_ref.global_position)
	var charge_dur = 0.4
	while charge_dur > 0 and current_state != State.DEAD:
		velocity.x = dir.x * charge_speed
		for body in attack_area.get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(int(attack_power * 1.2), global_position)
		await get_tree().physics_frame
		charge_dur -= get_physics_process_delta_time()
	velocity.x = 0
	is_charging = false

func _block():
	is_blocking = true
	block_timer = BLOCK_DURATION
	sprite.color = Color(0.5, 0.5, 0.8, 1)

func _on_damage_taken(_raw_damage: int, final_damage: int) -> int:
	if is_blocking:
		return int(final_damage * BLOCK_REDUCTION)
	return final_damage

func _process_skills(delta):
	super(delta)
	if is_blocking:
		block_timer -= delta
		if block_timer <= 0:
			is_blocking = false
			sprite.color = Color(0.7, 0.7, 0.75, 1)
