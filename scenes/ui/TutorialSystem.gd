extends CanvasLayer

const SHADER_CODE = """
shader_type canvas_item;

uniform vec2 spotlight_center = vec2(0.0, 0.0);
uniform vec2 spotlight_size = vec2(0.0, 0.0);
uniform float spotlight_radius = 0.0;
uniform float dim_alpha = 0.7;
uniform float corner_radius = 8.0;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 screen_pos = uv * vec2(1280.0, 720.0);

	bool inside = false;
	if (spotlight_radius > 0.0) {
		float dist = distance(screen_pos, spotlight_center);
		inside = dist < spotlight_radius;
	} else if (spotlight_size.x > 0.0 && spotlight_size.y > 0.0) {
		vec2 d = abs(screen_pos - spotlight_center) - spotlight_size;
		float dist = length(max(d, vec2(0.0))) - corner_radius;
		inside = dist < 0.0;
	}

	if (inside) {
		COLOR = vec4(0.0, 0.0, 0.0, 0.0);
	} else {
		COLOR = vec4(0.0, 0.0, 0.0, dim_alpha);
	}
}
"""

const STEPS: Array[Dictionary] = [
	{
		"id": "move",
		"text": "使用 A / D 键左右移动",
		"type": "action",
		"spotlight": "none",
		"spotlight_target": "",
		"spotlight_size": Vector2.ZERO,
	},
	{
		"id": "jump",
		"text": "按 Space 跳跃",
		"type": "action",
		"spotlight": "none",
		"spotlight_target": "",
		"spotlight_size": Vector2.ZERO,
	},
	{
		"id": "attack",
		"text": "按鼠标左键攻击",
		"type": "action",
		"spotlight": "none",
		"spotlight_target": "",
		"spotlight_size": Vector2.ZERO,
	},
	{
		"id": "kill",
		"text": "向右前进，击败前方的怪物!",
		"type": "action",
		"spotlight": "world_pos",
		"spotlight_target": Vector2(700, 550),
		"spotlight_size": Vector2(150, 120),
	},
	{
		"id": "pickup",
		"text": "靠近掉落物自动拾取",
		"type": "action",
		"spotlight": "none",
		"spotlight_target": "",
		"spotlight_size": Vector2.ZERO,
	},
	{
		"id": "inventory",
		"text": "按 Tab 打开背包查看物品",
		"type": "action",
		"spotlight": "ui_rect",
		"spotlight_target": "/root/DungeonFloor1/UILayer/InventoryPanel",
		"spotlight_size": Vector2.ZERO,
	},
	{
		"id": "equipment",
		"text": "按 E 打开装备面板",
		"type": "action",
		"spotlight": "ui_rect",
		"spotlight_target": "/root/DungeonFloor1/UILayer/EquipmentPanel",
		"spotlight_size": Vector2.ZERO,
	},
	{
		"id": "skill",
		"text": "按 1 / 2 / 3 使用技能",
		"type": "action",
		"spotlight": "ui_rect",
		"spotlight_target": "/root/DungeonFloor1/UILayer/PlayerHUD/SkillRow",
		"spotlight_size": Vector2.ZERO,
	},
	{
		"id": "quest",
		"text": "与任务NPC对话 (按 Q)",
		"type": "action",
		"spotlight": "world_pos",
		"spotlight_target": Vector2(350, 580),
		"spotlight_size": Vector2(80, 80),
	},
	{
		"id": "complete",
		"text": "教程完成! 祝你好运!",
		"type": "acknowledge",
		"spotlight": "none",
		"spotlight_target": "",
		"spotlight_size": Vector2.ZERO,
	},
]

var is_completed: bool = false
var _active: bool = false
var _current_step_index: int = 0
var _move_start_x: float = 0.0

var _overlay: ColorRect
var _text_label: Label
var _step_label: Label
var _skip_btn: Button
var _shader_mat: ShaderMaterial

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 97
	_create_overlay()
	_create_text_label()
	_create_step_counter()
	_create_skip_button()
	_connect_signals()
	await get_tree().process_frame
	if not is_completed:
		_start_tutorial()

func _create_overlay():
	_overlay = ColorRect.new()
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP

	var shader = Shader.new()
	shader.code = SHADER_CODE
	_shader_mat = ShaderMaterial.new()
	_shader_mat.shader = shader
	_overlay.material = _shader_mat
	_shader_mat.set_shader_parameter("spotlight_size", Vector2.ZERO)
	_shader_mat.set_shader_parameter("spotlight_radius", 0.0)

	add_child(_overlay)

func _create_text_label():
	_text_label = Label.new()
	_text_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_text_label.position = Vector2(-300, 200)
	_text_label.size = Vector2(600, 80)
	_text_label.add_theme_font_size_override("font_size", 24)
	_text_label.add_theme_color_override("font_color", Color(1, 1, 1))
	_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text_label.visible = false
	add_child(_text_label)

func _create_step_counter():
	_step_label = Label.new()
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_step_label.position = Vector2(-50, 280)
	_step_label.size = Vector2(100, 30)
	_step_label.add_theme_font_size_override("font_size", 16)
	_step_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	_step_label.visible = false
	add_child(_step_label)

func _create_skip_button():
	_skip_btn = Button.new()
	_skip_btn.text = "跳过教程"
	_skip_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_skip_btn.offset_left = -150
	_skip_btn.offset_top = -50
	_skip_btn.offset_right = -20
	_skip_btn.offset_bottom = -15
	_skip_btn.pressed.connect(_skip_tutorial)
	_skip_btn.visible = false
	add_child(_skip_btn)

func _connect_signals():
	var spawn_sys = get_node_or_null("/root/SpawnSystem")
	if spawn_sys:
		spawn_sys.monster_died.connect(_on_monster_died)

	var inv = get_node_or_null("/root/InventorySystem")
	if inv:
		inv.item_added.connect(_on_item_added)

func _process(_delta):
	if not _active or is_completed:
		return
	_check_step_completion()
	_update_spotlight_position()

func _input(event):
	if _active and event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()

func _start_tutorial():
	_active = true
	_current_step_index = 0
	_show_step(0)

func _show_step(index: int):
	_current_step_index = index
	var step = STEPS[index]
	_text_label.text = step["text"]
	_text_label.visible = true
	# Step counter (exclude "complete" step)
	var total = STEPS.size() - 1
	if index < total:
		_step_label.text = "%d / %d" % [index + 1, total]
	else:
		_step_label.text = ""
	_step_label.visible = true
	_skip_btn.visible = true
	_overlay.visible = true
	_update_spotlight(step)

	# Record player X for move step
	if step["id"] == "move":
		var player = get_tree().get_first_node_in_group("player")
		if player:
			_move_start_x = player.global_position.x

	# Auto-dismiss for acknowledge steps
	if step["type"] == "acknowledge":
		await get_tree().create_timer(2.0).timeout
		_complete_tutorial()

func _advance_step():
	_current_step_index += 1
	if _current_step_index >= STEPS.size():
		_complete_tutorial()
	else:
		_show_step(_current_step_index)

func _check_step_completion():
	var step = STEPS[_current_step_index]
	match step["id"]:
		"move":
			var player = get_tree().get_first_node_in_group("player")
			if player and abs(player.global_position.x - _move_start_x) > 50:
				_advance_step()
		"jump":
			if Input.is_action_just_pressed("ui_accept"):
				_advance_step()
		"attack":
			if Input.is_action_just_pressed("attack"):
				_advance_step()
		"inventory":
			var panel = get_node_or_null("/root/DungeonFloor1/UILayer/InventoryPanel")
			if panel and panel.is_open:
				_advance_step()
		"equipment":
			var panel = get_node_or_null("/root/DungeonFloor1/UILayer/EquipmentPanel")
			if panel and panel.is_open:
				_advance_step()
		"skill":
			if Input.is_action_just_pressed("skill_1") or Input.is_action_just_pressed("skill_2") or Input.is_action_just_pressed("skill_3"):
				_advance_step()
		"quest":
			var panel = get_node_or_null("/root/DungeonFloor1/UILayer/QuestPanel")
			if panel and panel.is_open:
				_advance_step()

func _on_monster_died(_monster_id: String):
	if _active and _current_step_id() == "kill":
		_advance_step()

func _on_item_added(item_id: String, _count: int):
	if _active and _current_step_id() == "pickup" and item_id != "gold":
		_advance_step()

func _update_spotlight_position():
	var step = STEPS[_current_step_index]
	if step["spotlight"] == "world_pos":
		var screen_pos = _world_to_screen(step["spotlight_target"])
		_shader_mat.set_shader_parameter("spotlight_center", screen_pos)

func _update_spotlight(step: Dictionary):
	match step["spotlight"]:
		"none":
			_shader_mat.set_shader_parameter("spotlight_size", Vector2.ZERO)
			_shader_mat.set_shader_parameter("spotlight_radius", 0.0)
		"world_pos":
			var screen_pos = _world_to_screen(step["spotlight_target"])
			_shader_mat.set_shader_parameter("spotlight_center", screen_pos)
			_shader_mat.set_shader_parameter("spotlight_size", step["spotlight_size"])
		"ui_rect":
			var target_node = get_node_or_null(step["spotlight_target"])
			if target_node and target_node is Control:
				var rect = target_node.get_global_rect()
				var center = rect.position + rect.size / 2.0
				_shader_mat.set_shader_parameter("spotlight_center", center)
				var size = step["spotlight_size"]
				if size == Vector2.ZERO:
					size = rect.size / 2.0
				_shader_mat.set_shader_parameter("spotlight_size", size)
			else:
				_shader_mat.set_shader_parameter("spotlight_size", Vector2.ZERO)

func _world_to_screen(world_pos: Vector2) -> Vector2:
	var cam = get_viewport().get_camera_2d()
	if not cam:
		return world_pos
	var screen_center = Vector2(640, 360)
	var cam_pos = cam.global_position
	var zoom = cam.zoom
	return screen_center + (world_pos - cam_pos) * zoom

func _complete_tutorial():
	is_completed = true
	_active = false
	_overlay.visible = false
	_text_label.visible = false
	_step_label.visible = false
	_skip_btn.visible = false
	var save_sys = get_node_or_null("/root/SaveSystem")
	if save_sys:
		save_sys._mark_dirty()

func _skip_tutorial():
	_complete_tutorial()

func skip_and_hide():
	is_completed = true
	_active = false
	visible = false

func resume_from_step(step_index: int):
	if step_index >= STEPS.size() - 1:
		skip_and_hide()
	else:
		_start_tutorial()
		_show_step(step_index)

func _current_step_id() -> String:
	return STEPS[_current_step_index]["id"]
