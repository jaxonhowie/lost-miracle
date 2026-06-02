extends "res://scenes/summons/BaseSummon.gd"

var heal_amount: int = 5
var heal_interval: float = 1.0
var _heal_cooldown: float = 0.0

func _ready():
	super._ready()
	sprite.color = Color(0.3, 0.6, 1.0, 0.8)
	attack_power = 0  # Water spirit doesn't attack

func _physics_process(delta):
	super._physics_process(delta)
	_heal_cooldown = maxf(0.0, _heal_cooldown - delta)

	# Heal summoner
	if summoner and is_instance_valid(summoner) and _heal_cooldown <= 0:
		var dist = global_position.distance_to(summoner.global_position)
		if dist <= follow_range:
			if summoner.hp < summoner.get_total_max_hp():
				summoner.hp = mini(summoner.hp + heal_amount, summoner.get_total_max_hp())
				_heal_cooldown = heal_interval
				# Visual feedback
				var tween = create_tween()
				tween.tween_property(sprite, "scale", Vector2(1.3, 1.3), 0.1)
				tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.1)

func setup(p_summoner: Node2D, p_attack: int, p_duration: float):
	super.setup(p_summoner, p_attack, p_duration)
	heal_amount = maxi(1, p_summoner.get_total_max_hp() / 50)
