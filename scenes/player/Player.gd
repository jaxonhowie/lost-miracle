extends CharacterBody2D

# Movement
const MOVE_SPEED = 180.0
const JUMP_VELOCITY = -360.0
const GRAVITY = 980.0

# Stats
var hp: int = 100
var max_hp: int = 100
var attack: int = 12
var defense: int = 3
var crit_rate: float = 0.05
var crit_damage: float = 1.5
var gold: int = 0

# Attack
const ATTACK_COOLDOWN = 0.45
var attack_cooldown_timer: float = 0.0
var is_attacking: bool = false

# Hit
var is_hit: bool = false
var hit_timer: float = 0.0
const HIT_DURATION = 0.3

# State
var is_dead: bool = false
var facing_right: bool = true

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: ColorRect = $SpritePlaceholder
@onready var hitbox: Area2D = $HitBox
@onready var hurtbox: Area2D = $HurtBox

func _ready():
	hitbox.monitoring = false
	add_to_group("player")

func _physics_process(delta):
	if is_dead:
		return

	if is_hit:
		hit_timer -= delta
		if hit_timer <= 0:
			is_hit = false
		else:
			velocity.y += GRAVITY * delta
			move_and_slide()
			return

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Attack cooldown
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	# Movement
	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0 and not is_attacking:
		velocity.x = direction * MOVE_SPEED
		facing_right = direction > 0
		sprite.scale.x = 1 if facing_right else -1
		# Flip hitbox position
		hitbox.position.x = abs(hitbox.position.x) * (1 if facing_right else -1)
	else:
		velocity.x = move_toward(velocity.x, 0, MOVE_SPEED)

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_attacking:
		velocity.y = JUMP_VELOCITY

	# Attack
	if Input.is_action_just_pressed("attack") and attack_cooldown_timer <= 0 and not is_attacking:
		_start_attack()

	move_and_slide()

	# Animation
	_update_animation(direction)

func _start_attack():
	is_attacking = true
	attack_cooldown_timer = ATTACK_COOLDOWN
	hitbox.monitoring = true
	# Attack duration handled by animation or timer
	await get_tree().create_timer(0.3).timeout
	hitbox.monitoring = false
	is_attacking = false

func _update_animation(direction):
	if is_attacking:
		anim_player.play("attack")
	elif is_hit:
		anim_player.play("hit")
	elif not is_on_floor():
		anim_player.play("jump")
	elif direction != 0:
		anim_player.play("run")
	else:
		anim_player.play("idle")

func take_damage(raw_damage: int, attacker_position: Vector2):
	if is_dead:
		return

	var total_defense = get_total_defense()
	var final_damage = maxi(1, raw_damage - total_defense)
	hp -= final_damage

	# Knockback
	var knockback_dir = (global_position - attacker_position).normalized()
	velocity = knockback_dir * 80
	velocity.y = -40

	is_hit = true
	hit_timer = HIT_DURATION
	anim_player.play("hit")

	if hp <= 0:
		_die()

func _die():
	is_dead = true
	velocity = Vector2.ZERO
	anim_player.play("death")
	# Disable collision
	$CollisionShape2D.set_deferred("disabled", true)
	hurtbox.set_deferred("monitoring", false)

func add_gold(amount: int):
	gold += amount

func get_total_attack() -> int:
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	if equip_sys:
		return attack + equip_sys.get_total_stats()["attack"]
	return attack

func get_total_defense() -> int:
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	if equip_sys:
		return defense + equip_sys.get_total_stats()["defense"]
	return defense

func get_total_max_hp() -> int:
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	if equip_sys:
		return max_hp + equip_sys.get_total_stats()["hp"]
	return max_hp

func get_total_crit_rate() -> float:
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	if equip_sys:
		return crit_rate + equip_sys.get_total_stats()["crit_rate"]
	return crit_rate

func get_total_crit_damage() -> float:
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	if equip_sys:
		return crit_damage + equip_sys.get_total_stats()["crit_damage"]
	return crit_damage

func _on_hitbox_area_entered(area: Area2D):
	if area.get_parent().has_method("take_damage"):
		var total_attack = get_total_attack()
		var total_crit_rate = get_total_crit_rate()
		var total_crit_damage = get_total_crit_damage()
		var is_crit = randf() < total_crit_rate
		var dmg = total_attack
		if is_crit:
			dmg = int(dmg * total_crit_damage)
		area.get_parent().take_damage(dmg, global_position)
