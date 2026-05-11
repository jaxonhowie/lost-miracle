extends CharacterBody2D

signal died(monster)

# Stats — override in subclasses
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

@onready var sprite: ColorRect = $SpritePlaceholder
@onready var detection_area: Area2D = $DetectionArea
@onready var attack_area: Area2D = $AttackArea
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _ready():
	patrol_origin = global_position
	attack_area.monitoring = false
	_setup_stats()

func _setup_stats():
	pass

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

	# Apply knockback
	if knockback_velocity.length() > 10:
		knockback_velocity = knockback_velocity.move_toward(Vector2.ZERO, KNOCKBACK_FRICTION * delta)
		velocity += knockback_velocity

	move_and_slide()

func _process_idle(delta):
	velocity.x = 0
	patrol_wait_timer -= delta
	if patrol_wait_timer <= 0:
		current_state = State.PATROL
		patrol_direction = 1 if randf() > 0.5 else -1
	_update_facing()

func _process_patrol(delta):
	velocity.x = patrol_direction * move_speed
	_update_facing()

	var dist = global_position.x - patrol_origin.x
	if abs(dist) > patrol_range:
		patrol_direction *= -1
		patrol_wait_timer = randf_range(1.0, 3.0)
		current_state = State.IDLE

	# Check for player
	if _player_in_range(DETECTION_RANGE):
		current_state = State.CHASE

func _process_chase(delta):
	if not is_instance_valid(player_ref) or not _player_in_range(DETECTION_RANGE * 1.5):
		current_state = State.PATROL
		patrol_wait_timer = 0.5
		return

	var dir = (player_ref.global_position - global_position).normalized()
	velocity.x = dir.x * move_speed
	_update_facing_toward(player_ref.global_position)

	if _player_in_range(ATTACK_RANGE):
		current_state = State.ATTACK
		attack_cooldown = attack_interval

func _process_attack(delta):
	velocity.x = 0
	attack_cooldown -= delta

	if attack_cooldown <= 0:
		_perform_attack()
		attack_cooldown = attack_interval

	if not is_instance_valid(player_ref) or not _player_in_range(ATTACK_RANGE * 1.5):
		current_state = State.CHASE

func _process_hit(delta):
	hit_timer -= delta
	if hit_timer <= 0:
		if hp <= 0:
			_die()
		else:
			current_state = State.CHASE if is_instance_valid(player_ref) and _player_in_range(DETECTION_RANGE) else State.PATROL

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
	if dist < range:
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

	var final_damage = maxi(1, raw_damage - defense)
	hp -= final_damage

	# Knockback
	var kb_dir = (global_position - attacker_position).normalized()
	knockback_velocity = kb_dir * 250
	knockback_velocity.y = -80

	current_state = State.HIT
	hit_timer = HIT_DURATION
	sprite.color = Color(1, 0.3, 0.3, 1)

	if hp <= 0:
		_die()

func _die():
	current_state = State.DEAD
	velocity = Vector2.ZERO
	died.emit(self)
	$CollisionShape2D.set_deferred("disabled", true)
	detection_area.set_deferred("monitoring", false)
	attack_area.set_deferred("monitoring", false)
	# Fade out
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

func _on_detection_area_body_entered(body):
	if body.is_in_group("player"):
		player_ref = body
		current_state = State.CHASE

func _on_detection_area_body_exited(body):
	if body == player_ref and current_state == State.CHASE:
		current_state = State.PATROL
		patrol_wait_timer = 0.5

func _on_attack_area_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage"):
		var is_crit = randf() < 0.0
		var dmg = attack_power
		body.take_damage(dmg, global_position)
