extends CharacterBody2D

signal died(monster)

# Stats — override in subclasses
var monster_id: String = ""
var hp: int = 60
var max_hp: int = 60
var attack_power: int = 8
var defense: int = 1
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
	pass

func _on_ready_extra():
	pass

func _on_damage_taken(_raw_damage: int, final_damage: int) -> int:
	return final_damage

func _on_hp_changed(_new_hp: int, _max_hp_val: int):
	pass

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
			body.take_damage(attack_power, global_position)
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

func take_damage(raw_damage: int, attacker_position: Vector2):
	if current_state == State.DEAD:
		return

	var base_damage = maxi(1, raw_damage - defense)
	var final_damage = _on_damage_taken(raw_damage, base_damage)
	hp -= final_damage
	_on_hp_changed(hp, max_hp)

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
	$CollisionShape2D.set_deferred("disabled", true)
	detection_area.set_deferred("monitoring", false)
	attack_area.set_deferred("monitoring", false)
	# Trigger drop system
	if monster_id != "":
		DropSystem.on_monster_died(monster_id, global_position)
	# Fade out
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

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
		body.take_damage(dmg, global_position)
