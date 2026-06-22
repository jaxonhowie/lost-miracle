extends Control

## 登录 / 注册场景

var _mode := "login"
var _busy := false

func _ready() -> void:
	_build_ui()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.05, 0.09, 1)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 0)
	var card_style := StyleBoxFlat.new()
	card_style.bg_color = Color(0.1, 0.09, 0.14, 1)
	card_style.border_color = Color(0.4, 0.35, 0.5, 1)
	card_style.set_border_width_all(2)
	card_style.set_corner_radius_all(8)
	card_style.set_content_margin_all(24)
	card.add_theme_stylebox_override("panel", card_style)
	center.add_child(card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 16)
	card.add_child(vb)

	var title := Label.new()
	title.name = "Title"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 28)
	vb.add_child(title)

	var err_label := Label.new()
	err_label.name = "ErrorLabel"
	err_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	err_label.modulate = Color(1, 0.4, 0.4)
	err_label.add_theme_font_size_override("font_size", 14)
	err_label.visible = false
	err_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(err_label)

	var user_row := HBoxContainer.new()
	user_row.add_theme_constant_override("separation", 8)
	var user_lbl := Label.new()
	user_lbl.text = "用户名"
	user_lbl.custom_minimum_size.x = 60
	user_lbl.add_theme_font_size_override("font_size", 16)
	user_row.add_child(user_lbl)
	var user_edit := LineEdit.new()
	user_edit.name = "UserEdit"
	user_edit.placeholder_text = "3-32 个字符"
	user_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	user_edit.max_length = 32
	user_row.add_child(user_edit)
	vb.add_child(user_row)

	var pass_row := HBoxContainer.new()
	pass_row.add_theme_constant_override("separation", 8)
	var pass_lbl := Label.new()
	pass_lbl.text = "密  码"
	pass_lbl.custom_minimum_size.x = 60
	pass_lbl.add_theme_font_size_override("font_size", 16)
	pass_row.add_child(pass_lbl)
	var pass_edit := LineEdit.new()
	pass_edit.name = "PassEdit"
	pass_edit.secret = true
	pass_edit.placeholder_text = "至少 6 个字符"
	pass_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pass_edit.max_length = 64
	pass_row.add_child(pass_edit)
	vb.add_child(pass_row)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER

	var submit_btn := Button.new()
	submit_btn.name = "SubmitBtn"
	submit_btn.custom_minimum_size = Vector2(120, 40)
	submit_btn.add_theme_font_size_override("font_size", 18)
	submit_btn.pressed.connect(_on_submit)
	btn_row.add_child(submit_btn)

	var back_btn := Button.new()
	back_btn.text = "返回"
	back_btn.custom_minimum_size = Vector2(100, 40)
	back_btn.add_theme_font_size_override("font_size", 18)
	back_btn.pressed.connect(func(): NetworkManager.exit_application())
	btn_row.add_child(back_btn)
	vb.add_child(btn_row)

	var toggle_btn := Button.new()
	toggle_btn.name = "ToggleBtn"
	toggle_btn.flat = true
	toggle_btn.add_theme_font_size_override("font_size", 14)
	toggle_btn.pressed.connect(_on_toggle_mode)
	vb.add_child(toggle_btn)

	_update_labels()
	_update_submit_text()

func _get_node(n: String) -> Node:
	return find_child(n, true, false)

func _update_labels() -> void:
	var title: Label = _get_node("Title")
	if title:
		title.text = "登录" if _mode == "login" else "注册"
	var toggle: Button = _get_node("ToggleBtn")
	if toggle:
		toggle.text = "没有账号？点击注册" if _mode == "login" else "已有账号？点击登录"

func _update_submit_text() -> void:
	var btn: Button = _get_node("SubmitBtn")
	if btn:
		btn.text = "登录" if _mode == "login" else "注册"

func _on_toggle_mode() -> void:
	_hide_error()
	_mode = "register" if _mode == "login" else "login"
	_update_labels()
	_update_submit_text()

func _show_error(msg: String) -> void:
	var lbl: Label = _get_node("ErrorLabel")
	if lbl:
		lbl.text = msg
		lbl.visible = true

func _hide_error() -> void:
	var lbl: Label = _get_node("ErrorLabel")
	if lbl:
		lbl.visible = false

func _set_inputs_enabled(enabled: bool) -> void:
	for n in ["UserEdit", "PassEdit", "SubmitBtn"]:
		var node = _get_node(n)
		if node is LineEdit:
			node.editable = enabled
		elif node is Button:
			node.disabled = !enabled

func _on_submit() -> void:
	if _busy:
		return
	var user_edit: LineEdit = _get_node("UserEdit")
	var pass_edit: LineEdit = _get_node("PassEdit")
	var user := user_edit.text.strip_edges() if user_edit else ""
	var pwd := pass_edit.text if pass_edit else ""

	if user.length() < 3:
		_show_error("用户名至少 3 个字符")
		return
	if pwd.length() < 6:
		_show_error("密码至少 6 个字符")
		return

	_busy = true
	_hide_error()
	_set_inputs_enabled(false)

	var result: Dictionary
	if _mode == "login":
		result = await NetworkManager.login(user, pwd)
	else:
		result = await NetworkManager.register(user, pwd)

	_busy = false
	_set_inputs_enabled(true)

	if result.get("ok", false):
		get_tree().change_scene_to_file(ScenePaths.MAIN)
	else:
		_show_error(_friendly_error(int(result.get("code", -1)), str(result.get("message", ""))))

func _friendly_error(code: int, msg: String) -> String:
	match code:
		40001:
			return "用户名已存在" if msg.contains("already exists") else msg
		40100:
			return "用户名或密码错误"
		40301:
			return "登录已过期，请重新登录"
		50301:
			return msg if not msg.is_empty() else "服务器维护中，请稍后再试"
		-1:
			if msg.contains("登录已过期"):
				return msg
			return "无法连接服务器，请检查网络"
		_:
			return msg if not msg.is_empty() else "请求失败 (%d)" % code
