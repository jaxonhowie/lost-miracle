extends "res://scenes/monsters/BaseMonster.gd"

enum Phase { ONE, TWO, THREE }
var current_phase: Phase = Phase.ONE
var phase_transition_lock: bool = false

var projectile_scene: PackedScene
var hazard_scene: PackedScene
var summoned_skeleton_scene: PackedScene
var summoned_count: int = 0
const MAX_SUMMONS: int = 4

func _setup_stats():
	monster_id = "grave_keeper_boss"
	hp = 1800
	max_hp = 1800
	attack_power = 42
	defense = 10
	move_speed = 70.0
	attack_interval = 1.5
	experience = 200
	sprite.color = Color(0.25, 0.3, 0.2, 1)

	projectile_scene = preload("res://scenes/monsters/Projectile.tscn")
	hazard_scene = preload("res://scenes/monsters/HazardZone.tscn")
	summoned_skeleton_scene = preload("res://scenes/monsters/SummonedSkeleton.tscn")

	_setup_phase_one()

func _on_hp_changed(new_hp: int, max_hp_val: int):
	var hp_pct = float(new_hp) / float(max_hp_val)
	if hp_pct <= 0.25 and current_phase != Phase.THREE:
		_transition_to_phase(Phase.THREE)
	elif hp_pct <= 0.60 and current_phase == Phase.ONE:
		_transition_to_phase(Phase.TWO)

func _transition_to_phase(new_phase: Phase):
	if phase_transition_lock:
		return
	phase_transition_lock = true
	current_phase = new_phase

	sprite.color = Color(1, 1, 1, 0.5)
	await get_tree().create_timer(0.8).timeout

	if current_state == State.DEAD:
		phase_transition_lock = false
		return

	match new_phase:
		Phase.TWO:
			_setup_phase_two()
			sprite.color = Color(0.3, 0.15, 0.3, 1)
		Phase.THREE:
			_setup_phase_three()
			sprite.color = Color(0.6, 0.1, 0.1, 1)
			move_speed = 110.0

	phase_transition_lock = false

func _setup_phase_one():
	skills = [
		{"name": "Slash", "cooldown": 3.0, "timer": 0.0, "range": 90.0, "execute": _boss_slash},
		{"name": "Ground Shockwave", "cooldown": 7.0, "timer": 0.0, "range": 150.0, "execute": _ground_shockwave},
		{"name": "Short Charge", "cooldown": 6.0, "timer": 0.0, "range": 180.0, "execute": _boss_charge}
	]

func _setup_phase_two():
	skills = [
		{"name": "Summon Skeletons", "cooldown": 10.0, "timer": 0.0, "range": -1.0, "execute": _boss_summon},
		{"name": "Wide Sweep", "cooldown": 4.0, "timer": 0.0, "range": 100.0, "execute": _wide_sweep},
		{"name": "Undead Flame", "cooldown": 8.0, "timer": 0.0, "range": 200.0, "execute": _undead_flame}
	]

func _setup_phase_three():
	skills = [
		{"name": "Triple Slash", "cooldown": 4.5, "timer": 0.0, "range": 100.0, "execute": _triple_slash},
		{"name": "Falling Bones", "cooldown": 10.0, "timer": 0.0, "range": -1.0, "execute": _falling_bones},
		{"name": "Wide Sweep", "cooldown": 3.0, "timer": 0.0, "range": 100.0, "execute": _wide_sweep}
	]

# --- Phase 1 Skills ---

func _boss_slash():
	attack_area.monitoring = true
	await get_tree().create_timer(0.2).timeout
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(int(attack_power * 1.3), global_position)
	await get_tree().create_timer(0.1).timeout
	attack_area.monitoring = false

func _ground_shockwave():
	var hazard = hazard_scene.instantiate()
	var dir_sign = 1 if sprite.scale.x > 0 else -1
	hazard.global_position = global_position + Vector2(dir_sign * 60, 20)
	hazard.setup(int(attack_power * 0.8), 0.3, 1.5, Vector2(200, 40), global_position)
	get_tree().current_scene.add_child(hazard)

func _boss_charge():
	if not is_instance_valid(player_ref):
		return
	var dir = (player_ref.global_position - global_position).normalized()
	_update_facing_toward(player_ref.global_position)
	var charge_dur = 0.5
	while charge_dur > 0 and current_state != State.DEAD:
		velocity.x = dir.x * 350.0
		for body in attack_area.get_overlapping_bodies():
			if body.is_in_group("player") and body.has_method("take_damage"):
				body.take_damage(int(attack_power * 1.1), global_position)
		await get_tree().physics_frame
		charge_dur -= get_physics_process_delta_time()
	velocity.x = 0

# --- Phase 2 Skills ---

func _boss_summon():
	if summoned_count >= MAX_SUMMONS:
		return
	var to_spawn = mini(2, MAX_SUMMONS - summoned_count)
	for i in range(to_spawn):
		var skel = summoned_skeleton_scene.instantiate()
		skel.global_position = global_position + Vector2(randf_range(-80, 80), -30)
		get_tree().current_scene.add_child(skel)
		skel.died.connect(_on_summon_died)
		summoned_count += 1

func _on_summon_died(_monster):
	summoned_count = maxi(0, summoned_count - 1)

func _wide_sweep():
	var shape = attack_area.get_node("CollisionShape2D").shape
	var orig = shape.size
	shape.size = Vector2(orig.x * 1.8, orig.y * 1.5)
	attack_area.monitoring = true
	await get_tree().create_timer(0.25).timeout
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(int(attack_power * 1.2), global_position)
	await get_tree().create_timer(0.1).timeout
	attack_area.monitoring = false
	shape.size = orig

func _undead_flame():
	var dir_sign = 1 if sprite.scale.x > 0 else -1
	var hazard = hazard_scene.instantiate()
	hazard.global_position = global_position + Vector2(dir_sign * 120, 10)
	hazard.setup(int(attack_power * 0.6), 0.4, 4.0, Vector2(160, 50), global_position)
	get_tree().current_scene.add_child(hazard)

# --- Phase 3 Skills ---

func _triple_slash():
	for i in range(3):
		if current_state == State.DEAD:
			return
		_boss_slash()
		await get_tree().create_timer(0.35).timeout

func _falling_bones():
	if not is_instance_valid(player_ref):
		return
	for i in range(3):
		if current_state == State.DEAD:
			return
		var offset_x = randf_range(-200, 200)
		var hazard = hazard_scene.instantiate()
		hazard.global_position = player_ref.global_position + Vector2(offset_x, -100)
		hazard.setup(int(attack_power * 0.7), 0.5, 3.0, Vector2(80, 300), global_position)
		get_tree().current_scene.add_child(hazard)
		await get_tree().create_timer(0.4).timeout
