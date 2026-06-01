extends PanelContainer

signal class_selected(class_id: String)

var _selected_class: String = ""

func _ready():
	visible = false
	_setup_buttons()

func _setup_buttons():
	var class_sys = get_node_or_null("/root/ClassSystem")
	if not class_sys:
		return
	var classes = class_sys.get_class_list()
	for class_id in classes:
		var btn = $VBox.get_node_or_null("Btn_" + class_id)
		if btn:
			var data = class_sys.get_class_data(class_id)
			btn.text = "%s - %s" % [data["name"], data["description"]]
			btn.pressed.connect(_on_class_pressed.bind(class_id))

func show_panel():
	visible = true

func _on_class_pressed(class_id: String):
	_selected_class = class_id
	var class_sys = get_node_or_null("/root/ClassSystem")
	if class_sys:
		class_sys.selected_class = class_id
	class_selected.emit(class_id)
	visible = false
