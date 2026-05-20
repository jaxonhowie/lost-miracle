extends Area2D

var damage: int = 25
var fall_speed: float = 400.0
var _triggered: bool = false
var _falling: bool = false

func _ready():
	body_entered.connect(_on_trigger_entered)

func _on_trigger_entered(body):
	if _triggered:
		return
	if body.is_in_group("player"):
		_triggered = true
		_start_fall()

func _start_fall():
	# Spawn the actual falling rock
	var rock = Area2D.new()
	var shape = CollisionShape2D.new()
	var rect = RectangleShape2D.new()
	rect.size = Vector2(40, 30)
	shape.shape = rect
	rock.add_child(shape)

	# Visual
	var visual = ColorRect.new()
	visual.size = Vector2(40, 30)
	visual.position = Vector2(-20, -15)
	visual.color = Color(0.5, 0.4, 0.3)
	rock.add_child(visual)

	rock.position = Vector2(randf_range(-30, 30), -200)
	rock.collision_layer = 0
	rock.collision_mask = 1  # player layer
	add_child(rock)

	rock.body_entered.connect(_on_rock_hit.bind(rock))

	# Animate falling to ground level (y=620 is ground)
	var fall_target = 620.0 - global_position.y
	var tween = create_tween()
	tween.tween_property(rock, "position:y", fall_target, 0.6).set_ease(Tween.EASE_IN)
	tween.tween_callback(_on_rock_landed.bind(rock))

func _on_rock_hit(body: Node2D, rock: Area2D):
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, global_position)

func _on_rock_landed(rock: Area2D):
	# Remove rock after a brief pause
	var tween = create_tween()
	tween.tween_interval(0.3)
	tween.tween_property(rock, "modulate:a", 0.0, 0.3)
	tween.tween_callback(rock.queue_free)
