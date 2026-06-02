extends CharacterBody2D

signal died(monster)

# Stats — override in subclasses
var monster_id: String = ""
var hp: int = 60
var max_hp: int = 60
var attack_power: int = 8
var defense: int = 1
var agi: int = 5
var move_speed: float = 80.0
var attack_interval: float = 1.2
var experience: int = 5

# State machine
enum State { IDLE, PATROL, CHASE, ATTACK, HIT, DEAD }
var current_state: State = State.IDLE

# Patrol
var patrol_origin: Vector2
var patrol_range: float = 120.0
var patrol_direction: int = 1
var patrol_wait_timer: float = 0.0

# Chase
var player_ref: Node2D = null
const DETECTION_RANGE: float = 200.0
const ATTACK_RANGE: float = 50.0

# Attack
var attack_cooldown: float = 0.0

# Hit
var hit_timer: float = 0.0
const HIT_DURATION: float = 0.25

# Knockback
var knockback_velocity: Vector2 = Vector2.ZERO
const KNOCKBACK_FRICTION: float = 800.0

# Skill system
var skills: Array = []

# Boss system
var is_boss: bool = false
var boss_phase: int = 1
var boss_phase_timer: float = 0.0
var boss_aoe_cooldown: float = 0.0
var boss_charge_cooldown: float = 0.0
var boss_summon_cooldown: float = 0.0
const BOSS_AOE_INTERVAL: float = 8.0
const BOSS_CHARGE_INTERVAL: float = 12.0
const BOSS_SUMMON_INTERVAL: float = 20.0
const BOSS_AOE_RANGE: float = 120.0
const BOSS_CHARGE_SPEED: float = 400.0

@onready var sprite: ColorRect = $SpritePlaceholder
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var anim_player: AnimationPlayer = $AnimationPlayer

var health_bar: ProgressBar = null
var health_bar_timer: float = 0.0
const HEALTH_BAR_VISIBLE_TIME: float = 3.0

func _ready():
	patrol_origin = global_position
	attack_area.monitoring = false
	add_to_group("monsters")
	_setup_stats()
	_create_health_bar()
	_on_ready_extra()

func _create_health_bar():
	health_bar = ProgressBar.new()
	health_bar.size = Vector2(80, 12)
	health_bar.position = Vector2(-40, -50)
	health_bar.max_value = max_hp
	health_bar.value = hp
	health_bar.visible = false
	health_bar.z_index = 10
	add_child(health_bar)

	# Style
	var bg = StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.2)
	bg.corner_radius_top_left = 2
	bg.corner_radius_top_right = 2
	bg.corner_radius_bottom_left = 2
	bg.corner_radius_bottom_right = 2
	health_bar.add_theme_stylebox_override("background", bg)

	var fill = StyleBoxFlat.new()
	fill.bg_color = Color(0.8, 0.15, 0.15)
	fill.corner_radius_top_left = 2
	fill.corner_radius_top_right = 2
	fill.corner_radius_bottom_left = 2
	fill.corner_radius_bottom_right = 2
	health_bar.add_theme_stylebox_override("fill", fill)

func _setup_stats():
	if monster_id.is_empty():
		return
	var data = MonsterDatabase.get_monster(monster_id)
	if data.is_empty():
		return
	hp = data.get("hp", hp)
	max_hp = data.get("hp", max_hp)
	attack_power = data.get("attack_power", attack_power)
	defense = data.get("defense", defense)
	agi = data.get("agi", agi)
	move_speed = data.get("move_speed", move_speed)
	attack_interval = data.get("attack_interval", attack_interval)
	experience = data.get("experience", experience)
	# Apply difficulty scaling
	var diff_sys = get_node_or_null("/root/DifficultySystem")
	if diff_sys:
		var scaled = diff_sys.get_stats(hp, attack_power, defense, experience, agi)
		hp = scaled["hp"]
		max_hp = scaled["hp"]
		attack_power = scaled["attack"]
		defense = scaled["defense"]
		experience = scaled["xp"]
		agi = scaled["agi"]
	# Boss init
	is_boss = monster_id.ends_with("_boss")
	if is_boss:
		boss_aoe_cooldown = BOSS_AOE_INTERVAL
		boss_charge_cooldown = BOSS_CHARGE_INTERVAL
		boss_summon_cooldown = BOSS_SUMMON_INTERVAL

func _on_ready_extra():
	pass

func _on_damage_taken(_raw_damage: int, final_damage: int) -> int:
	return final_damage

func _on_hp_changed(_new_hp: int, _max_hp_val: int):
	if is_boss and boss_phase == 1 and _new_hp <= _max_hp_val / 2:
		_boss_enter_phase2()

func _on_state_entered(_new_state: State):
	pass

func _set_state(new_state: State):
	if current_state != new_state:
		current_state = new_state
		_on_state_entered(new_state)

func _process_skills(delta: float):
	for skill in skills:
		skill["timer"] = maxf(0.0, skill["timer"] - delta)

func _try_use_skill() -> bool:
	if skills.is_empty():
		return false
	for skill in skills:
		if skill["timer"] > 0.0:
			continue
		var in_range = skill["range"] < 0 or _player_in_range(skill["range"])
		if in_range:
			skill["timer"] = skill["cooldown"]
			skill["execute"].call()
			return true
	return false

func _physics_process(delta):
	match current_state:
		State.IDLE:
			_process_idle(delta)
		State.PATROL:
			_process_patrol(delta)
		State.CHASE:
			_process_chase(delta)
		State.ATTACK:
			_process_attack(delta)
		State.HIT:
			_process_hit(delta)
		State.DEAD:
			return

	# Gravity
	if not is_on_floor():
		velocity.y += 980.0 * delta
	else:
		velocity.y = 0

	# Apply knockback
	if knockback_velocity.length() > 10:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
		velocity += knockback_velocity

	_process_skills(delta)
	move_and_slide()

	# Health bar timer
	if health_bar.visible:
		health_bar_timer -= delta
		if health_bar_timer <= 0:
			health_bar.visible = false

func _process_idle(delta):
	velocity.x = 0
	patrol_wait_timer -= delta
	if patrol_wait_timer <= 0:
		_set_state(State.PATROL)
		patrol_direction = 1 if randf() > 0.5 else -1
	_update_facing()

func _process_patrol(delta):
	# Check for edge before moving
	if is_on_floor() and _is_near_edge():
		patrol_direction *= -1
		patrol_wait_timer = randf_range(1.0, 2.0)
		_set_state(State.IDLE)
		return

	velocity.x = patrol_direction * move_speed
	_update_facing()

	var dist = global_position.x - patrol_origin.x
	if abs(dist) > patrol_range:
		patrol_direction *= -1
		patrol_wait_timer = randf_range(1.0, 3.0)
		_set_state(State.IDLE)

	# Check for player
	if _player_in_range(DETECTION_RANGE):
		_set_state(State.CHASE)

func _is_near_edge() -> bool:
	# Raycast downward slightly ahead to detect platform edge
	var check_dir = patrol_direction
	var check_pos = global_position + Vector2(check_dir * 25, 0)
	var space_state = get_world_2d().direct_space_state
	var query = PhysicsRayQueryParameters2D.create(
		global_position + Vector2(0, 10),
		check_pos + Vector2(0, 50),
		4  # environment layer
	)
	query.exclude = [self]
	var result = space_state.intersect_ray(query)
	return result.is_empty()

func _process_chase(delta):
	if not is_instance_valid(player_ref) or not _player_in_range(DETECTION_RANGE * 1.5):
		_set_state(State.PATROL)
		patrol_wait_timer = 0.5
		return

	# Don't chase off edges
	if is_on_floor() and _is_near_edge():
		velocity.x = 0
		return

	var dir = (player_ref.global_position - global_position).normalized()
	velocity.x = dir.x * move_speed
	_update_facing_toward(player_ref.global_position)

	if _player_in_range(ATTACK_RANGE):
		_set_state(State.ATTACK)
		attack_cooldown = attack_interval

func _process_attack(delta):
	velocity.x = 0
	attack_cooldown -= delta

	if is_boss:
		_process_boss_skills(delta)

	if attack_cooldown <= 0:
		if not _try_use_skill():
			_perform_attack()
		attack_cooldown = attack_interval

	if not is_instance_valid(player_ref) or not _player_in_range(ATTACK_RANGE * 1.5):
		_set_state(State.CHASE)

func _process_hit(delta):
	hit_timer -= delta
	if hit_timer <= 0:
		if hp <= 0:
			_die()
		else:
			if is_instance_valid(player_ref) and _player_in_range(DETECTION_RANGE):
				_set_state(State.CHASE)
			else:
				_set_state(State.PATROL)

func _perform_attack():
	attack_area.monitoring = true
	await get_tree().process_frame
	# Check bodies already overlapping
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(attack_power, global_position, agi)
	await get_tree().create_timer(0.15).timeout
	attack_area.monitoring = false

func _player_in_range(range: float) -> bool:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return false
	var p = players[0]
	var dist = global_position.distance_to(p.global_position)
	if dist > range:
		return false

	# Check if player is in front (fan-shaped detection)
	# Calculate angle between facing direction and direction to player
	var to_player = (p.global_position - global_position).normalized()
	var facing_dir = Vector2(sprite.scale.x, 0)  # sprite.scale.x is 1 or -1
	var dot = to_player.dot(facing_dir)

	# 120 degree cone (dot > 0.5 means within 60 degrees on each side)
	if dot > 0.3:
		player_ref = p
		return true
	return false

func _update_facing():
	if velocity.x > 0:
		sprite.scale.x = 1
		attack_area.position.x = abs(attack_area.position.x)
	elif velocity.x < 0:
		sprite.scale.x = -1
		attack_area.position.x = -abs(attack_area.position.x)

func _update_facing_toward(target_pos: Vector2):
	if target_pos.x > global_position.x:
		sprite.scale.x = 1
		attack_area.position.x = abs(attack_area.position.x)
	else:
		sprite.scale.x = -1
		attack_area.position.x = -abs(attack_area.position.x)

func take_damage(raw_damage: int, attacker_position: Vector2, is_crit: bool = false):
	if current_state == State.DEAD:
		return

	var base_damage = maxi(1, raw_damage - defense)
	var final_damage = _on_damage_taken(raw_damage, base_damage)
	hp -= final_damage
	_on_hp_changed(hp, max_hp)

	_spawn_floating_damage(final_damage, is_crit)
	AudioManager.play_sfx("res://assets/audio/sfx_hit.ogg")

	# Hit particle effect
	preload("res://scenes/effects/HitEffect.gd").spawn(get_parent(), global_position + Vector2(0, -15))

	if is_crit:
		VFX.shake(4.0, 0.15)
	else:
		VFX.shake(2.0, 0.10)

	# Show health bar
	health_bar.value = hp
	health_bar.visible = true
	health_bar_timer = HEALTH_BAR_VISIBLE_TIME

	# Knockback
	var kb_dir = (global_position - attacker_position).normalized()
	knockback_velocity = kb_dir * 100
	knockback_velocity.y = -30

	_set_state(State.HIT)
	hit_timer = HIT_DURATION
	sprite.color = Color(1, 0.3, 0.3, 1)

	if hp <= 0:
		_die()

func _die():
	_set_state(State.DEAD)
	velocity = Vector2.ZERO
	died.emit(self)
	AudioManager.play_sfx("res://assets/audio/sfx_monster_death.ogg")
	# VFX based on monster type
	if monster_id.ends_with("_boss"):
		VFX.shake(6.0, 0.25)
		VFX.hitstop(80)
	elif monster_id.begins_with("elite_"):
		VFX.shake(5.0, 0.2)
		VFX.hitstop(40)
	else:
		VFX.shake(3.0, 0.15)
		VFX.hitstop(40)
	$CollisionShape2D.set_deferred("disabled", true)
	# Death particle effect
	preload("res://scenes/effects/DeathEffect.gd").spawn(get_parent(), global_position)
	detection_area.set_deferred("monitoring", false)
	attack_area.set_deferred("monitoring", false)
	# Trigger drop system (skip for summoned monsters)
	if monster_id != "" and not get("is_summoned"):
		DropSystem.on_monster_died(monster_id, global_position)
	# Boss guaranteed drops: epic equipment + enhance core
	if is_boss:
		_boss_guaranteed_drops()
	# Award XP
	if experience > 0:
		var level_sys = get_node_or_null("/root/LevelSystem")
		if level_sys:
			level_sys.add_xp(experience)
	# Boss kill: grant talent points and skill points and honor
	if monster_id.begins_with("elite_") or monster_id.ends_with("_boss"):
		var talent_sys = get_node_or_null("/root/TalentSystem")
		if talent_sys:
			talent_sys.add_talent_points(2)
		var skill_tree_sys = get_node_or_null("/root/SkillTreeSystem")
		if skill_tree_sys:
			skill_tree_sys.add_skill_points(2)
		var honor_sys = get_node_or_null("/root/HonorSystem")
		if honor_sys:
			var honor_amount = 100 if monster_id.ends_with("_boss") else 50
			honor_sys.add_honor(honor_amount, "击杀" + ("Boss" if monster_id.ends_with("_boss") else "精英"))
	# Trigger auto-save
	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys:
		save_sys.on_monster_died()
	# Fade out
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func _spawn_floating_damage(damage: int, is_crit: bool = false):
	var fd = Label.new()
	fd.set_script(preload("res://scenes/ui/FloatingDamage.gd"))
	fd.position = Vector2(randf_range(-20, 20), -40)
	add_child(fd)
	fd.setup(damage, is_crit)

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player_ref = body
		_set_state(State.CHASE)

func _on_detection_area_body_exited(body):
	if body == player_ref and current_state == State.CHASE:
		_set_state(State.PATROL)
		patrol_wait_timer = 0.5

func _on_attack_area_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage"):
		var is_crit = randf() < 0.0
		var dmg = attack_power
		body.take_damage(dmg, global_position, agi)

# --- Boss System ---

func _process_boss_skills(delta: float):
	boss_aoe_cooldown -= delta
	boss_charge_cooldown -= delta
	boss_summon_cooldown -= delta

	# Phase 2: faster cooldowns
	var cd_mult = 0.6 if boss_phase == 2 else 1.0

	if boss_aoe_cooldown <= 0:
		_boss_aoe_attack()
		boss_aoe_cooldown = BOSS_AOE_INTERVAL * cd_mult
	elif boss_charge_cooldown <= 0 and is_instance_valid(player_ref):
		_boss_charge_attack()
		boss_charge_cooldown = BOSS_CHARGE_INTERVAL * cd_mult
	elif boss_summon_cooldown <= 0 and boss_phase == 2:
		_boss_summon_minions()
		boss_summon_cooldown = BOSS_SUMMON_INTERVAL * cd_mult

func _boss_enter_phase2():
	boss_phase = 2
	boss_phase_timer = 1.5
	# Visual feedback: flash red, grow slightly
	var tween = create_tween()
	tween.tween_property(sprite, "color", Color(1.0, 0.2, 0.2, 1.0), 0.3)
	tween.tween_property(sprite, "color", Color(0.8, 0.1, 0.1, 1.0), 0.3)
	tween.set_loops(3)
	# Increase stats for phase 2
	attack_power = int(attack_power * 1.3)
	move_speed *= 1.2
	# Announce
	_spawn_boss_text("Phase 2!", Color(1, 0.3, 0.1))

func _boss_aoe_attack():
	# AOE: damage all players within range
	var players = get_tree().get_nodes_in_group("player")
	for p in players:
		if is_instance_valid(p) and p.has_method("take_damage"):
			var dist = global_position.distance_to(p.global_position)
			if dist <= BOSS_AOE_RANGE:
				p.take_damage(int(attack_power * 1.5), global_position, agi)
	# Visual: expanding circle
	_spawn_aoe_visual()
	AudioManager.play_sfx("res://assets/audio/sfx_hit.ogg")

func _boss_charge_attack():
	if not is_instance_valid(player_ref):
		return
	# Charge toward player position
	var target = player_ref.global_position
	var dir = (target - global_position).normalized()
	velocity = dir * BOSS_CHARGE_SPEED
	# Damage on contact
	for body in attack_area.get_overlapping_bodies():
		if body.is_in_group("player") and body.has_method("take_damage"):
			body.take_damage(int(attack_power * 2.0), global_position, agi)
	_spawn_boss_text("Charge!", Color(1, 0.8, 0.1))

func _boss_summon_minions():
	# Summon 2 weak minions
	var spawn_sys = get_node_or_null("/root/SpawnSystem")
	if not spawn_sys:
		return
	for i in 2:
		var offset = Vector2(randf_range(-80, 80), 0)
		var minion_pos = global_position + offset
		# Use a generic mob from the same floor
		var minion_id = _get_minion_id()
		if minion_id.is_empty():
			continue
		var data = MonsterDatabase.get_monster(minion_id)
		if data.is_empty():
			continue
		_spawn_boss_text("Minions!", Color(0.5, 0.3, 0.8))

func _get_minion_id() -> String:
	# Return a weak minion type based on boss floor
	var floor_id = monster_id.replace("_boss", "")
	# Map boss themes to minion types
	var minion_map = {
		"ancient_treant": "forest_spider",
		"lich_king": "skeleton_archer",
		"inferno_lord": "fire_slime",
		"crystal_dragon": "crystal_bat",
		"shadow_emperor": "shadow_wraith",
		"void_overlord": "void_horror"
	}
	return minion_map.get(floor_id, "")

func _spawn_aoe_visual():
	# Create expanding circle effect
	var circle = ColorRect.new()
	circle.size = Vector2(10, 10)
	circle.position = Vector2(-5, -5)
	circle.color = Color(1, 0.3, 0.1, 0.6)
	circle.z_index = 5
	add_child(circle)
	var tween = create_tween()
	tween.tween_property(circle, "size", Vector2(BOSS_AOE_RANGE * 2, BOSS_AOE_RANGE * 2), 0.4)
	tween.parallel().tween_property(circle, "position", Vector2(-BOSS_AOE_RANGE, -BOSS_AOE_RANGE), 0.4)
	tween.parallel().tween_property(circle, "modulate:a", 0.0, 0.4)
	tween.tween_callback(circle.queue_free)

func _spawn_boss_text(txt: String, color: Color):
	var label = Label.new()
	label.text = txt
	label.add_theme_font_size_override("font_size", 20)
	label.position = Vector2(-40, -70)
	label.modulate = color
	label.z_index = 15
	add_child(label)
	var tween = create_tween()
	tween.tween_property(label, "position:y", label.position.y - 30, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)

func _boss_guaranteed_drops():
	# Drop an epic equipment item appropriate to the boss level
	var drop_sys = get_node_or_null("/root/DropSystem")
	if not drop_sys:
		return
	# Find epic items from the drop table for this boss
	var table = DropTableDatabase.roll_drops(monster_id)
	var epic_items: Array = []
	for entry in table:
		var item_data = ItemDatabase.get_item(entry.get("item_id", ""))
		if not item_data.is_empty() and item_data.get("quality", "") == "epic":
			epic_items.append(entry)
	# Drop one guaranteed epic if found in table
	if not epic_items.is_empty():
		var chosen = epic_items[randi() % epic_items.size()]
		var item_id = chosen.get("item_id", "")
		if not item_id.is_empty():
			drop_sys.spawn_drop(item_id, global_position + Vector2(randf_range(-30, 30), -20))
	# Also drop enhance core
	drop_sys.spawn_drop("boss_enhance_core", global_position + Vector2(randf_range(-20, 20), -10))
