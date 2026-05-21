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

# Skills
var _skill_cooldowns: Dictionary = {
	"whirlwind": 0.0,
	"charge": 0.0,
	"war_cry": 0.0,
}
const SKILL_COOLDOWNS = {
	"whirlwind": 6.0,
	"charge": 8.0,
	"war_cry": 15.0,
}

# Buffs
var _buffs: Dictionary = {}  # buff_id -> { timer, value }

# Combo
var combo_count: int = 0
var combo_last_hit_ms: int = 0
const COMBO_WINDOW_MS: int = 2000

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: ColorRect = $SpritePlaceholder
@onready var hitbox: Area2D = $HitBox
@onready var hurtbox: Area2D = $HurtBox

func _ready():
	hitbox.monitoring = false
	add_to_group("player")
	_setup_consumable_listener()

func _setup_consumable_listener():
	var inv = get_node_or_null("/root/InventorySystem")
	if inv:
		inv.item_used.connect(_on_item_used)

func _physics_process(delta):
	if is_dead:
		return

	# Combo expiry
	if combo_count > 0 and Time.get_ticks_msec() - combo_last_hit_ms > COMBO_WINDOW_MS:
		combo_count = 0

	_process_skills(delta)
	_process_buffs(delta)

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

	# Movement (apply speed buff)
	var move_speed = MOVE_SPEED
	if _buffs.has("speed"):
		move_speed *= 1.5

	var direction = Input.get_axis("ui_left", "ui_right")
	if direction != 0 and not is_attacking:
		velocity.x = direction * move_speed
		facing_right = direction > 0
		sprite.scale.x = 1 if facing_right else -1
		# Flip hitbox position
		hitbox.position.x = abs(hitbox.position.x) * (1 if facing_right else -1)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_attacking:
		velocity.y = JUMP_VELOCITY

	# Attack
	if Input.is_action_just_pressed("attack") and attack_cooldown_timer <= 0 and not is_attacking:
		_start_attack()

	# Skills
	if Input.is_action_just_pressed("skill_1") and not is_attacking:
		_try_use_skill("whirlwind")
	if Input.is_action_just_pressed("skill_2") and not is_attacking:
		_try_use_skill("charge")
	if Input.is_action_just_pressed("skill_3") and not is_attacking:
		_try_use_skill("war_cry")

	# Quick use item (F1)
	if Input.is_action_just_pressed("use_item_1"):
		_quick_use_item()

	move_and_slide()

	# Animation
	_update_animation(direction)

func _start_attack():
	is_attacking = true
	attack_cooldown_timer = ATTACK_COOLDOWN
	hitbox.monitoring = true
	AudioManager.play_sfx("res://assets/audio/sfx_attack.ogg")
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

	_spawn_floating_damage(final_damage, false)
	AudioManager.play_sfx("res://assets/audio/sfx_hit.ogg")

	# Hit particle effect
	preload("res://scenes/effects/HitEffect.gd").spawn(get_parent(), global_position + Vector2(0, -15), Color(1, 0.2, 0.2))

	VFX.shake(3.0, 0.12)
	VFX.flash(Color(1, 0, 0, 1), 0.1)

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
	AudioManager.play_sfx("res://assets/audio/sfx_death.ogg")
	anim_player.play("death")
	# Disable collision
	$CollisionShape2D.set_deferred("disabled", true)
	hurtbox.set_deferred("monitoring", false)
	# Show death screen
	var death_screen = get_tree().current_scene.get_node_or_null("DeathScreen")
	if death_screen:
		death_screen.show_death()
	else:
		# Fallback: auto-respawn after 3 seconds
		await get_tree().create_timer(3.0).timeout
		var save_sys = get_node_or_null("/root/SaveSystem")
		if save_sys:
			save_sys.respawn_player()
		else:
			hp = get_total_max_hp()
			is_dead = false
			$CollisionShape2D.disabled = false
			hurtbox.monitoring = true

func add_gold(amount: int):
	gold += amount

func get_total_attack() -> int:
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	var base = attack
	if equip_sys:
		base += equip_sys.get_total_stats()["attack"]
	if _buffs.has("war_cry"):
		base = int(base * 1.3)
	return base

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

func _process_skills(delta):
	for skill_id in _skill_cooldowns:
		if _skill_cooldowns[skill_id] > 0:
			_skill_cooldowns[skill_id] = maxf(0.0, _skill_cooldowns[skill_id] - delta)

func _process_buffs(delta):
	var expired = []
	for buff_id in _buffs:
		_buffs[buff_id]["timer"] -= delta
		if _buffs[buff_id]["timer"] <= 0:
			expired.append(buff_id)
	for buff_id in expired:
		_buffs.erase(buff_id)

func _try_use_skill(skill_id: String):
	if _skill_cooldowns.get(skill_id, 0.0) > 0:
		return
	_skill_cooldowns[skill_id] = SKILL_COOLDOWNS[skill_id]
	is_attacking = true
	AudioManager.play_sfx("res://assets/audio/sfx_skill.ogg")
	match skill_id:
		"whirlwind":
			await _skill_whirlwind()
		"charge":
			await _skill_charge()
		"war_cry":
			await _skill_war_cry()
	is_attacking = false

func _skill_whirlwind():
	var total_atk = get_total_attack()
	var dmg = int(total_atk * 1.0)
	preload("res://scenes/effects/SkillVFX.gd").spawn_whirlwind(get_parent(), global_position + Vector2(0, -10))
	VFX.flash(Color(1, 0.8, 0.3, 1), 0.1)
	# Hit all monsters in 80px radius
	var hit_any = false
	for monster in get_tree().get_nodes_in_group("monsters"):
		if monster.has_method("take_damage") and monster.current_state != 5:  # not DEAD
			var dist = global_position.distance_to(monster.global_position)
			if dist <= 80.0:
				var is_crit = randf() < get_total_crit_rate()
				var final_dmg = dmg
				if is_crit:
					final_dmg = int(final_dmg * get_total_crit_damage())
				monster.take_damage(final_dmg, global_position, is_crit)
				_increment_combo()
				hit_any = true
	if hit_any:
		VFX.shake(3.5, 0.12)
		VFX.hitstop(30)
	await get_tree().create_timer(0.4).timeout

func _skill_charge():
	var total_atk = get_total_attack()
	var dmg = int(total_atk * 1.3)
	var dir = 1 if facing_right else -1
	var charge_dur = 0.3
	var hit_monsters = []
	var trail_frame := 0
	VFX.flash(Color(0.3, 0.8, 1.0, 1), 0.1)
	while charge_dur > 0 and not is_dead:
		velocity.x = dir * 400.0
		velocity.y = 0
		trail_frame += 1
		if trail_frame % 3 == 0:
			preload("res://scenes/effects/SkillVFX.gd").spawn_charge_trail(get_parent(), global_position + Vector2(0, -10))
		# Hit monsters in path
		for monster in get_tree().get_nodes_in_group("monsters"):
			if monster in hit_monsters:
				continue
			if monster.has_method("take_damage") and monster.current_state != 5:
				var dist = global_position.distance_to(monster.global_position)
				if dist <= 60.0:
					var is_crit = randf() < get_total_crit_rate()
					var final_dmg = dmg
					if is_crit:
						final_dmg = int(final_dmg * get_total_crit_damage())
					monster.take_damage(final_dmg, global_position, is_crit)
					hit_monsters.append(monster)
					_increment_combo()
					VFX.shake(3.0, 0.10)
					VFX.hitstop(30)
		await get_tree().physics_frame
		charge_dur -= get_physics_process_delta_time()
	velocity.x = 0

func _skill_war_cry():
	# Heal 30% max HP
	var heal_amount = int(get_total_max_hp() * 0.3)
	hp = mini(hp + heal_amount, get_total_max_hp())
	# Damage buff for 5 seconds
	_buffs["war_cry"] = { "timer": 5.0, "value": 0.3 }
	preload("res://scenes/effects/SkillVFX.gd").spawn_war_cry(get_parent(), global_position + Vector2(0, -10))
	VFX.flash(Color(1, 0.9, 0.2, 1), 0.15)
	VFX.shake(4.0, 0.2)
	# Scale punch
	var base_scale_x = 1.0 if facing_right else -1.0
	var tw = create_tween()
	tw.tween_property(sprite, "scale", Vector2(base_scale_x * 1.3, 1.3), 0.08)
	tw.tween_property(sprite, "scale", Vector2(base_scale_x, 1.0), 0.12)
	await tw.finished

func _quick_use_item():
	var inv = get_node_or_null("/root/InventorySystem")
	if not inv:
		return
	var item_id = inv.get_quick_use()
	if item_id == "":
		return
	inv.use_item(item_id)

func _on_item_used(item_id: String):
	var effect_data = ItemDatabase.get_consumable_effect(item_id)
	if effect_data.is_empty():
		return
	use_consumable(effect_data["effect"], effect_data["value"])

func use_consumable(effect: String, value: int):
	match effect:
		"heal":
			if value < 0:
				hp = get_total_max_hp()
			else:
				hp = mini(hp + value, get_total_max_hp())
			AudioManager.play_sfx("res://assets/audio/sfx_heal.ogg")
		"speed":
			_buffs["speed"] = { "timer": float(value), "value": 1.5 }
			AudioManager.play_sfx("res://assets/audio/sfx_buff.ogg")

func _increment_combo():
	var now = Time.get_ticks_msec()
	if now - combo_last_hit_ms > COMBO_WINDOW_MS:
		combo_count = 0
	combo_count += 1
	combo_last_hit_ms = now

func _spawn_floating_damage(damage: int, is_crit: bool = false):
	var fd = Label.new()
	fd.set_script(preload("res://scenes/ui/FloatingDamage.gd"))
	fd.position = Vector2(randf_range(-20, 20), -40)
	add_child(fd)
	fd.setup(damage, is_crit)

func _on_hitbox_area_entered(area: Area2D):
	if area.get_parent().has_method("take_damage"):
		var total_attack = get_total_attack()
		var total_crit_rate = get_total_crit_rate()
		var total_crit_damage = get_total_crit_damage()
		var is_crit = randf() < total_crit_rate
		var dmg = total_attack
		if is_crit:
			dmg = int(dmg * total_crit_damage)
		area.get_parent().take_damage(dmg, global_position, is_crit)
		_increment_combo()
		if is_crit:
			VFX.shake(4.0, 0.15)
			VFX.hitstop(50)
			VFX.flash(Color(1, 1, 1, 1), 0.1)
		else:
			VFX.shake(2.0, 0.10)
