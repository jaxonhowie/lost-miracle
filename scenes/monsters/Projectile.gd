extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 250.0
var damage: int = 10
var lifetime: float = 4.0
var source_position: Vector2

func setup(dir: Vector2, spd: float, dmg: int, source_pos: Vector2):
	direction = dir.normalized()
	speed = spd
	damage = dmg
	source_position = source_pos
	if direction.x < 0:
		$SpritePlaceholder.scale.x = -1

func _ready():
	body_entered.connect(_on_body_entered)
	area_entered.connect(_on_area_entered)

func _physics_process(delta):
	global_position += direction * speed * delta
	lifetime -= delta
	if lifetime <= 0:
		queue_free()

func _on_body_entered(body):
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage, source_position)
	queue_free()

func _on_area_entered(area):
	var parent = area.get_parent()
	if parent and parent.is_in_group("player") and parent.has_method("take_damage"):
		parent.take_damage(damage, source_position)
		queue_free()
