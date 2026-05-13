extends "res://scenes/monsters/BaseMonster.gd"

var projectile_scene: PackedScene
var summoned_skeleton_scene: PackedScene
var summoned_count: int = 0
const MAX_SUMMONS: int = 2

func _setup_stats():
	monster_id = "elite_necromancer"
	hp = 360
	max_hp = 360
	attack_power = 30
	defense = 3
	move_speed = 60.0
	attack_interval = 1.8
	experience = 60
	sprite.color = Color(0.5, 0.2, 0.7, 1)

	projectile_scene = preload("res://scenes/monsters/Projectile.tscn")
	summoned_skeleton_scene = preload("res://scenes/monsters/SummonedSkeleton.tscn")

	skills = [
		{
			"name": "Shadow Arrow",
			"cooldown": 2.5,
			"timer": 0.0,
			"range": 300.0,
			"execute": _shadow_arrow
		},
		{
			"name": "Summon Skeleton",
			"cooldown": 12.0,
			"timer": 0.0,
			"range": -1.0,
			"execute": _summon_skeleton
		},
		{
			"name": "Soul Burst",
			"cooldown": 6.0,
			"timer": 0.0,
			"range": 70.0,
			"execute": _soul_burst
		}
	]

func _process_chase(delta):
	if not is_instance_valid(player_ref):
		_set_state(State.PATROL)
		patrol_wait_timer = 0.5
		return

	var dist = global_position.distance_to(player_ref.global_position)

	if dist > DETECTION_RANGE * 1.5:
		_set_state(State.PATROL)
		patrol_wait_timer = 0.5
		return

	if dist < 100:
		var dir = (global_position - player_ref.global_position).normalized()
		velocity.x = dir.x * move_speed
	elif dist > 250:
		var dir = (player_ref.global_position - global_position).normalized()
		velocity.x = dir.x * move_speed
	else:
		velocity.x = 0

	_update_facing_toward(player_ref.global_position)

	if dist <= ATTACK_RANGE * 3:
		_set_state(State.ATTACK)
		attack_cooldown = attack_interval

func _shadow_arrow():
	if not is_instance_valid(player_ref):
		return
	var proj = projectile_scene.instantiate()
	var dir = (player_ref.global_position - global_position).normalized()
	proj.global_position = global_position + dir * 20
	proj.setup(dir, 250.0, attack_power, global_position)
	get_tree().current_scene.add_child(proj)

func _summon_skeleton():
	if summoned_count >= MAX_SUMMONS:
		return
	var to_spawn = 2 - summoned_count
	for i in range(to_spawn):
		var skel = summoned_skeleton_scene.instantiate()
		skel.global_position = global_position + Vector2(randf_range(-60, 60), -20)
		get_tree().current_scene.add_child(skel)
		skel.died.connect(_on_summon_died)
		summoned_count += 1

func _on_summon_died(_monster):
	summoned_count = maxi(0, summoned_count - 1)

func _soul_burst():
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if global_position.distance_to(p.global_position) <= 70:
			if p.has_method("take_damage"):
				p.take_damage(int(attack_power * 1.3), global_position)
	sprite.color = Color(1.0, 0.3, 1.0, 1)
	await get_tree().create_timer(0.3).timeout
	if current_state != State.DEAD:
		sprite.color = Color(0.5, 0.2, 0.7, 1)
