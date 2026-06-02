extends CharacterBody2D

signal summon_expired(summon: Node2D)

var summoner: Node2D = null
var attack_power: int = 10
var attack_interval: float = 1.5
var attack_range: float = 100.0
var duration: float = 10.0
var move_speed: float = 120.0
var follow_range: float = 80.0

var _attack_cooldown: float = 0.0
var _duration_timer: float = 0.0
var _target: Node2D = null

@onready var sprite: ColorRect = $SpritePlaceholder
@onready var attack_area: Area2D = $AttackArea

func _ready():
	add_to_group("summons")
	_duration_timer = duration
	# Setup attack area
	var shape = CircleShape2D.new()
	shape.radius = attack_range
	attack_area.get_node("CollisionShape2D").shape = shape

func setup(p_summoner: Node2D, p_attack: int, p_duration: float):
	summoner = p_summoner
	attack_power = p_attack
	duration = p_duration
	_duration_timer = p_duration

func _physics_process(delta):
	_duration_timer -= delta
	if _duration_timer <= 0:
		_expire()
		return

	_attack_cooldown = maxf(0.0, _attack_cooldown - delta)

	if summoner == null or not is_instance_valid(summoner):
		_expire()
		return

	# Find target
	_target = _find_nearest_monster()

	if _target and is_instance_valid(_target):
		var dist = global_position.distance_to(_target.global_position)
		if dist <= attack_range:
			# Attack
			if _attack_cooldown <= 0:
				_perform_attack()
				_attack_cooldown = attack_interval
		else:
			# Move toward target
			var dir = (_target.global_position - global_position).normalized()
			velocity = dir * move_speed
			move_and_slide()
	else:
		# Follow summoner
		var dist_to_summoner = global_position.distance_to(summoner.global_position)
		if dist_to_summoner > follow_range:
			var dir = (summoner.global_position - global_position).normalized()
			velocity = dir * move_speed
			move_and_slide()
		else:
			velocity = Vector2.ZERO

	# Visual feedback
	if _target:
		sprite.modulate = Color(1.0, 0.8, 0.8)
	else:
		sprite.modulate = Color(0.8, 0.9, 1.0)

func _find_nearest_monster() -> Node2D:
	var nearest = null
	var nearest_dist = attack_range + 1.0
	for monster in get_tree().get_nodes_in_group("monsters"):
		if monster.has_method("take_damage") and monster.current_state != 5:
			var dist = global_position.distance_to(monster.global_position)
			if dist < nearest_dist:
				nearest = monster
				nearest_dist = dist
	return nearest

func _perform_attack():
	if _target and is_instance_valid(_target) and _target.has_method("take_damage"):
		_target.take_damage(attack_power, global_position, false)

func _expire():
	summon_expired.emit(self)
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.0, 0.3)
	tween.tween_callback(queue_free)
