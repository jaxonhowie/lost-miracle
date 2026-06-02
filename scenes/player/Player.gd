extends CharacterBody2D

# Movement
const MOVE_SPEED = 180.0
const JUMP_VELOCITY = -360.0
const GRAVITY = 980.0

# Attributes
var class_id: String = "warrior"
var STR: int = 10
var AGI: int = 5
var INT: int = 5

# Runtime state
var hp: int = 100
var mp: int = 50
var gold: int = 0
var current_weight: float = 0.0

# Attack
const ATTACK_COOLDOWN = 0.45
var attack_cooldown_timer: float = 0.0
var is_attacking: bool = false

# Hit
var is_hit: bool = false
var hit_timer: float = 0.0
const HIT_DURATION = 0.3

# Dodge
var is_dodging: bool = false
var dodge_timer: float = 0.0
var dodge_cooldown: float = 0.0
const DODGE_DURATION: float = 0.25
const DODGE_COOLDOWN: float = 0.8
const DODGE_SPEED: float = 350.0

# State
var is_dead: bool = false
var facing_right: bool = true
var auto_attack: bool = false

# Skills
var _skill_cooldowns: Dictionary = {
	"whirlwind": 0.0,
	"charge": 0.0,
	"war_cry": 0.0,
	"shield_bash": 0.0,
	"berserker": 0.0,
	"summon_water": 0.0,
	"summon_fire": 0.0,
}
const SKILL_COOLDOWNS = {
	"whirlwind": 6.0,
	"charge": 8.0,
	"war_cry": 15.0,
	"shield_bash": 10.0,
	"berserker": 20.0,
	"summon_water": 15.0,
	"summon_fire": 15.0,
}
const SKILL_MP_COSTS = {
	"whirlwind": 15,
	"charge": 20,
	"war_cry": 25,
	"shield_bash": 18,
	"berserker": 35,
	"summon_water": 20,
	"summon_fire": 25,
}

# Buffs: buff_id -> { timer, value, category }
var _buffs: Dictionary = {}

# Combo
var combo_count: int = 0
var combo_last_hit_ms: int = 0
const COMBO_WINDOW_MS: int = 2000

# HP regen accumulator (from talents)
var _hp_regen_accumulator: float = 0.0
# MP regen accumulator
var _mp_regen_accumulator: float = 0.0

@onready var anim_player: AnimationPlayer = $AnimationPlayer
@onready var sprite: ColorRect = $SpritePlaceholder
@onready var hitbox: Area2D = $HitBox
@onready var hurtbox: Area2D = $HurtBox

var _anim: Node
var _was_on_floor: bool = true
var _anim_state: String = ""

func _ready():
	hitbox.monitoring = false
	add_to_group("player")
	_setup_consumable_listener()
	_anim = preload("res://scripts/systems/ProceduralAnimator.gd").new()
	add_child(_anim)
	_anim.setup(sprite)
	# Init HP/MP from derived stats
	await get_tree().process_frame
	hp = get_total_max_hp()
	mp = get_total_max_mp()
	# Connect equipment changes to weight update
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	if equip_sys:
		equip_sys.equipment_changed.connect(update_weight)
		equip_sys.equipment_changed.connect(_update_enhance_glow)
		update_weight()
		_update_enhance_glow()

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

	# Dodge
	if is_dodging:
		dodge_timer -= delta
		if dodge_timer <= 0:
			is_dodging = false
		velocity.y += GRAVITY * delta
		move_and_slide()
		return
	if dodge_cooldown > 0:
		dodge_cooldown -= delta

	# Gravity
	if not is_on_floor():
		velocity.y += GRAVITY * delta

	# Attack cooldown
	if attack_cooldown_timer > 0:
		attack_cooldown_timer -= delta

	# HP regen from talents
	var talent_sys = get_node_or_null("/root/TalentSystem")
	if talent_sys:
		var regen_rate = talent_sys.get_bonus("hp_regen")
		if regen_rate > 0:
			_hp_regen_accumulator += regen_rate * delta
			var regen_amount = int(_hp_regen_accumulator)
			if regen_amount > 0:
				hp = mini(hp + regen_amount, get_total_max_hp())
				_hp_regen_accumulator -= regen_amount

	# MP regen: base 0.5/s + INT * 0.1/s
	var mp_regen_rate = 0.5 + INT * 0.1
	if talent_sys:
		mp_regen_rate += talent_sys.get_bonus("mp_regen")
	_mp_regen_accumulator += mp_regen_rate * delta
	var mp_regen_amount = int(_mp_regen_accumulator)
	if mp_regen_amount > 0:
		mp = mini(mp + mp_regen_amount, get_total_max_mp())
		_mp_regen_accumulator -= mp_regen_amount

	# Movement (talent + AGI + speed buff)
	var move_speed = MOVE_SPEED
	move_speed *= (1.0 + get_agi_move_bonus())
	if talent_sys:
		move_speed *= (1.0 + talent_sys.get_bonus("move_speed"))
	if _buffs.has("speed"):
		move_speed *= _buffs["speed"]["value"]
	if is_overweight():
		move_speed *= 0.5
	if is_dodging:
		move_speed = DODGE_SPEED

	var direction = Input.get_axis("ui_left", "ui_right")
	if is_dodging:
		velocity.x = (1 if facing_right else -1) * DODGE_SPEED
	elif direction != 0 and not is_attacking:
		velocity.x = direction * move_speed
		facing_right = direction > 0
		sprite.scale.x = 1 if facing_right else -1
		# Flip hitbox position
		hitbox.position.x = abs(hitbox.position.x) * (1 if facing_right else -1)
	else:
		velocity.x = move_toward(velocity.x, 0, move_speed)

	# Dodge
	if Input.is_action_just_pressed("dodge") and not is_dodging and dodge_cooldown <= 0 and not is_attacking and not is_overweight():
		is_dodging = true
		dodge_timer = DODGE_DURATION
		dodge_cooldown = DODGE_COOLDOWN * get_agi_dodge_cd_mult()

	# Jump
	if Input.is_action_just_pressed("ui_accept") and is_on_floor() and not is_attacking and not is_dodging:
		velocity.y = JUMP_VELOCITY

	# Attack
	if Input.is_action_just_pressed("attack") and attack_cooldown_timer <= 0 and not is_attacking and not is_dodging:
		_start_attack()

	# Skills
	if Input.is_action_just_pressed("skill_1") and not is_attacking:
		_try_use_skill("whirlwind")
	if Input.is_action_just_pressed("skill_2") and not is_attacking:
		_try_use_skill("charge")
	if Input.is_action_just_pressed("skill_3") and not is_attacking:
		_try_use_skill("war_cry")
	if Input.is_action_just_pressed("skill_4") and not is_attacking:
		_try_use_skill("shield_bash")
	if Input.is_action_just_pressed("skill_5") and not is_attacking:
		_try_use_skill("berserker")

	# Quick use item (F1)
	if Input.is_action_just_pressed("use_item_1"):
		_quick_use_item()

	# Auto-attack toggle (Tab)
	if Input.is_action_just_pressed("ui_focus_next"):
		auto_attack = !auto_attack

	# Auto-attack logic
	if auto_attack and not is_attacking and not is_dodging:
		_process_auto_attack()

	move_and_slide()

	# Animation
	_update_animation(direction)

func _start_attack():
	is_attacking = true
	attack_cooldown_timer = ATTACK_COOLDOWN * get_agi_attack_cd_mult()
	hitbox.monitoring = true
	AudioManager.play_sfx("res://assets/audio/sfx_attack.ogg")
	# Attack duration handled by animation or timer
	await get_tree().create_timer(0.3).timeout
	hitbox.monitoring = false
	is_attacking = false

func _update_animation(direction):
	if is_attacking:
		anim_player.play("attack")
		_anim_state = "attack"
	elif is_hit:
		anim_player.play("hit")
		_anim_state = "hit"
	elif is_dodging:
		if _anim_state != "dodge":
			_anim.stop_all()
			_anim.lean(15.0 if facing_right else -15.0)
			_anim_state = "dodge"
	elif not is_on_floor():
		if _anim_state != "jump":
			_anim.stop_all()
			_anim.breathe(0.02, 3.0)
			_anim_state = "jump"
	elif direction != 0:
		if _anim_state != "run":
			_anim.stop_all()
			_anim.bounce(2.0, 10.0)
			_anim.lean(5.0 if direction > 0 else -5.0)
			_anim_state = "run"
	else:
		if _anim_state != "idle":
			_anim.stop_all()
			_anim.breathe()
			_anim.reset_lean()
			_anim_state = "idle"
	# Land detection
	if is_on_floor() and not _was_on_floor:
		_anim.squash_stretch(0.12, 0.15)
	_was_on_floor = is_on_floor()

func take_damage(raw_damage: int, attacker_position: Vector2, attacker_agi: int = 0):
	if is_dead or is_dodging:
		return

	# Dodge check
	var class_sys = get_node_or_null("/root/ClassSystem")
	if class_sys and not is_overweight():
		var dodge_chance = class_sys.calc_dodge_rate(AGI)
		if randf() < dodge_chance:
			_spawn_floating_text("闪避", Color(0.5, 1.0, 0.5))
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

func _get_equip_stats() -> Dictionary:
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	if equip_sys:
		return equip_sys.get_total_stats()
	return {}

func _get_derived_stats() -> Dictionary:
	var class_sys = get_node_or_null("/root/ClassSystem")
	if class_sys:
		return class_sys.compute_derived_stats(STR, AGI, INT, _get_equip_stats(), class_id)
	return { "attack": 0, "max_hp": 100, "defense": 0, "crit_rate": 0.05, "crit_damage": 1.5, "hit_rate": 0.8, "dodge_rate": 0.05, "weight_capacity": 500.0 }

func get_total_attack() -> int:
	var base = _get_derived_stats()["attack"]
	var talent_sys = get_node_or_null("/root/TalentSystem")
	if talent_sys:
		base += talent_sys.get_bonus("attack")
	if _buffs.has("war_cry"):
		base = int(base * (1.0 + _buffs["war_cry"]["value"]))
	if _buffs.has("attack_buff"):
		base += int(_buffs["attack_buff"]["value"])
	return base

func get_total_defense() -> int:
	var base = _get_derived_stats()["defense"]
	var talent_sys = get_node_or_null("/root/TalentSystem")
	if talent_sys:
		base += talent_sys.get_bonus("defense")
	if _buffs.has("defense_buff"):
		base += int(_buffs["defense_buff"]["value"])
	if _buffs.has("berserker_def"):
		base = int(base * (1.0 + _buffs["berserker_def"]["value"]))
	return maxi(0, base)

func get_total_max_hp() -> int:
	var base = _get_derived_stats()["max_hp"]
	var talent_sys = get_node_or_null("/root/TalentSystem")
	if talent_sys:
		base += talent_sys.get_bonus("max_hp")
	return base

func get_total_max_mp() -> int:
	return 50 + INT * 3

func get_total_crit_rate() -> float:
	var base = _get_derived_stats()["crit_rate"]
	var talent_sys = get_node_or_null("/root/TalentSystem")
	if talent_sys:
		base += talent_sys.get_bonus("crit_rate")
	return base

func get_total_crit_damage() -> float:
	var base = _get_derived_stats()["crit_damage"]
	var talent_sys = get_node_or_null("/root/TalentSystem")
	if talent_sys:
		base += talent_sys.get_bonus("crit_damage")
	return base

func get_total_hit_rate() -> float:
	var base = _get_derived_stats()["hit_rate"]
	var talent_sys = get_node_or_null("/root/TalentSystem")
	if talent_sys:
		base += talent_sys.get_bonus("hit_rate")
	return base

func get_total_dodge_rate() -> float:
	var base = _get_derived_stats()["dodge_rate"]
	var talent_sys = get_node_or_null("/root/TalentSystem")
	if talent_sys:
		base += talent_sys.get_bonus("dodge_rate")
	return base

# AGI scaling: movement speed, dodge cooldown, attack speed
func get_agi_move_bonus() -> float:
	return AGI * 0.01  # +1% per AGI

func get_agi_dodge_cd_mult() -> float:
	return maxf(0.5, 1.0 - AGI * 0.01)  # -1% per AGI, min 50%

func get_agi_attack_cd_mult() -> float:
	return maxf(0.7, 1.0 - AGI * 0.005)  # -0.5% per AGI, min 70%

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

func add_buff(buff_id: String, timer: float, value: float, category: String = ""):
	# Same ID: refresh timer
	if _buffs.has(buff_id):
		_buffs[buff_id]["timer"] = timer
		_buffs[buff_id]["value"] = value
		return
	# Same category: keep higher value, remove weaker
	if category != "":
		for existing_id in _buffs:
			if _buffs[existing_id].get("category", "") == category:
				if value >= _buffs[existing_id]["value"]:
					_buffs.erase(existing_id)
				else:
					return  # existing is stronger, skip
	_buffs[buff_id] = { "timer": timer, "value": value, "category": category }

func has_buff(buff_id: String) -> bool:
	return _buffs.has(buff_id)

func _try_use_skill(skill_id: String):
	if _skill_cooldowns.get(skill_id, 0.0) > 0:
		return
	var mp_cost = SKILL_MP_COSTS.get(skill_id, 0)
	if mp < mp_cost:
		return
	# Check if skill is unlocked
	var skill_tree = get_node_or_null("/root/SkillTreeSystem")
	if skill_tree and not skill_tree.is_unlocked(skill_id):
		return
	mp -= mp_cost
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
		"shield_bash":
			await _skill_shield_bash()
		"berserker":
			await _skill_berserker()
		"summon_water":
			_skill_summon_water()
		"summon_fire":
			_skill_summon_fire()
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
				var final_dmg = int(dmg * get_combo_multiplier())
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
					var final_dmg = int(dmg * get_combo_multiplier())
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
	add_buff("war_cry", 5.0, 0.3, "attack")
	preload("res://scenes/effects/SkillVFX.gd").spawn_war_cry(get_parent(), global_position + Vector2(0, -10))
	VFX.flash(Color(1, 0.9, 0.2, 1), 0.15)
	VFX.shake(4.0, 0.2)
	# Scale punch
	var base_scale_x = 1.0 if facing_right else -1.0
	var tw = create_tween()
	tw.tween_property(sprite, "scale", Vector2(base_scale_x * 1.3, 1.3), 0.08)
	tw.tween_property(sprite, "scale", Vector2(base_scale_x, 1.0), 0.12)
	await tw.finished

func _skill_shield_bash():
	var total_atk = get_total_attack()
	var dmg = int(total_atk * 0.8)
	preload("res://scenes/effects/SkillVFX.gd").spawn_whirlwind(get_parent(), global_position + Vector2(0, -10))
	VFX.flash(Color(0.5, 0.5, 1.0, 1), 0.1)
	# Hit single target in front
	for monster in get_tree().get_nodes_in_group("monsters"):
		if monster.has_method("take_damage") and monster.current_state != 5:
			var dist = global_position.distance_to(monster.global_position)
			if dist <= 60.0:
				var is_crit = randf() < get_total_crit_rate()
				var final_dmg = int(dmg * get_combo_multiplier())
				if is_crit:
					final_dmg = int(final_dmg * get_total_crit_damage())
				monster.take_damage(final_dmg, global_position, is_crit)
				_increment_combo()
				VFX.shake(3.0, 0.12)
				VFX.hitstop(40)
				break
	await get_tree().create_timer(0.3).timeout

func _skill_berserker():
	# Berserk buff: +50% attack, -30% defense for 8 seconds
	add_buff("berserker", 8.0, 0.5, "attack")
	add_buff("berserker_def", 8.0, -0.3, "defense")
	preload("res://scenes/effects/SkillVFX.gd").spawn_war_cry(get_parent(), global_position + Vector2(0, -10))
	VFX.flash(Color(1, 0.2, 0.2, 1), 0.15)
	VFX.shake(5.0, 0.25)
	# Scale punch
	var base_scale_x = 1.0 if facing_right else -1.0
	var tw = create_tween()
	tw.tween_property(sprite, "scale", Vector2(base_scale_x * 1.4, 1.4), 0.1)
	tw.tween_property(sprite, "scale", Vector2(base_scale_x * 1.1, 1.1), 0.15)
	await tw.finished

func _skill_summon_water():
	var water_scene = preload("res://scenes/summons/WaterSpirit.tscn")
	var spirit = water_scene.instantiate()
	spirit.global_position = global_position + Vector2(30 if facing_right else -30, -20)
	get_parent().add_child(spirit)
	var atk = int(get_total_attack() * 0.3)
	spirit.setup(self, atk, 10.0)
	VFX.flash(Color(0.3, 0.6, 1.0, 1), 0.1)

func _skill_summon_fire():
	var fire_scene = preload("res://scenes/summons/FireSpirit.tscn")
	var spirit = fire_scene.instantiate()
	spirit.global_position = global_position + Vector2(30 if facing_right else -30, -20)
	get_parent().add_child(spirit)
	var atk = int(get_total_attack() * 0.8)
	spirit.setup(self, atk, 10.0)
	VFX.flash(Color(1.0, 0.4, 0.2, 1), 0.1)

func _process_auto_attack():
	var nearest_monster = _find_nearest_monster(120.0)
	if nearest_monster == null:
		return
	# Face the monster
	facing_right = nearest_monster.global_position.x > global_position.x
	sprite.scale.x = 1 if facing_right else -1
	hitbox.position.x = abs(hitbox.position.x) * (1 if facing_right else -1)
	# Auto normal attack
	if attack_cooldown_timer <= 0:
		_start_attack()
	# Auto use skills (priority: war_cry > whirlwind > charge > shield_bash)
	if mp >= 25 and _skill_cooldowns.get("war_cry", 0.0) <= 0:
		_try_use_skill("war_cry")
	elif mp >= 15 and _skill_cooldowns.get("whirlwind", 0.0) <= 0:
		_try_use_skill("whirlwind")
	elif mp >= 20 and _skill_cooldowns.get("charge", 0.0) <= 0:
		_try_use_skill("charge")
	elif mp >= 18 and _skill_cooldowns.get("shield_bash", 0.0) <= 0:
		_try_use_skill("shield_bash")

func _find_nearest_monster(range: float) -> Node2D:
	var nearest = null
	var nearest_dist = range + 1.0
	for monster in get_tree().get_nodes_in_group("monsters"):
		if monster.has_method("take_damage") and monster.current_state != 5:
			var dist = global_position.distance_to(monster.global_position)
			if dist < nearest_dist:
				nearest = monster
				nearest_dist = dist
	return nearest

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
			add_buff("speed", 10.0, 1.5, "speed")
			AudioManager.play_sfx("res://assets/audio/sfx_buff.ogg")
		"defense_buff":
			add_buff("defense_buff", 15.0, float(value), "defense")
			AudioManager.play_sfx("res://assets/audio/sfx_buff.ogg")
		"attack_buff":
			add_buff("attack_buff", 15.0, float(value), "attack")
			AudioManager.play_sfx("res://assets/audio/sfx_buff.ogg")

func _increment_combo():
	var now = Time.get_ticks_msec()
	if now - combo_last_hit_ms > COMBO_WINDOW_MS:
		combo_count = 0
	combo_count += 1
	combo_last_hit_ms = now
	# Track max combo for achievements
	var ach_sys = get_node_or_null("/root/AchievementSystem")
	if ach_sys:
		ach_sys.set_stat("max_combo", combo_count)

func get_combo_multiplier() -> float:
	return 1.0 + combo_count * 0.05

func _spawn_floating_damage(damage: int, is_crit: bool = false):
	var fd = Label.new()
	fd.set_script(preload("res://scenes/ui/FloatingDamage.gd"))
	fd.position = Vector2(randf_range(-20, 20), -40)
	add_child(fd)
	fd.setup(damage, is_crit)

func _spawn_floating_text(text: String, color: Color):
	var fd = Label.new()
	fd.set_script(preload("res://scenes/ui/FloatingDamage.gd"))
	fd.position = Vector2(randf_range(-20, 20), -40)
	add_child(fd)
	fd.setup_text(text, color)

func get_weight_capacity() -> float:
	var class_sys = get_node_or_null("/root/ClassSystem")
	if class_sys:
		return class_sys.compute_derived_stats(STR, AGI, INT, _get_equip_stats(), class_id).get("weight_capacity", 500.0)
	return 500.0

func is_overweight() -> bool:
	return current_weight > get_weight_capacity()

func update_weight():
	current_weight = 0.0
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	if equip_sys:
		for slot in equip_sys.equipped:
			var inst = equip_sys.equipped[slot]
			if inst == null:
				continue
			var item_data = ItemDatabase.get_item(inst.get("item_id", ""))
			current_weight += item_data.get("weight", 0.0)

var _glow_sprite: Sprite2D = null

func _update_enhance_glow():
	var equip_sys = get_node_or_null("/root/EquipmentSystem")
	if not equip_sys:
		return
	var glow_color = equip_sys.get_enhance_glow_color()
	if glow_color.a <= 0.01:
		if _glow_sprite:
			_glow_sprite.queue_free()
			_glow_sprite = null
		return
	if not _glow_sprite:
		_glow_sprite = Sprite2D.new()
		_glow_sprite.z_index = -1
		_glow_sprite.modulate = glow_color
		sprite.add_child(_glow_sprite)
		# Create a simple glow texture
		var img = Image.create(80, 80, false, Image.FORMAT_RGBA8)
		for x in 80:
			for y in 80:
				var dist = Vector2(x - 40, y - 40).length()
				if dist < 40:
					var alpha = (1.0 - dist / 40.0) * 0.6
					img.set_pixel(x, y, Color(1, 1, 1, alpha))
		var tex = ImageTexture.create_from_image(img)
		_glow_sprite.texture = tex
	_glow_sprite.modulate = glow_color

func _on_hitbox_area_entered(area: Area2D):
	if area.get_parent().has_method("take_damage"):
		var total_attack = get_total_attack()
		var total_crit_rate = get_total_crit_rate()
		var total_crit_damage = get_total_crit_damage()
		var is_crit = randf() < total_crit_rate
		var dmg = int(total_attack * get_combo_multiplier())
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
