extends Node

signal login_success(username: String)
signal login_failed(error: String)
signal register_success(username: String)
signal register_failed(error: String)

var is_logged_in: bool = false
var username: String = ""
var token: String = ""

const AUTH_FILE: String = "user://auth.json"

func _ready():
	_load_token()

func login(user: String, password: String):
	var api = get_node_or_null("/root/APIClient")
	if not api:
		login_failed.emit("no_api_client")
		return
	api.request_completed.connect(_on_login_response.bind(user), CONNECT_ONE_SHOT)
	api.login(user, password)

func register(user: String, password: String):
	var api = get_node_or_null("/root/APIClient")
	if not api:
		register_failed.emit("no_api_client")
		return
	api.request_completed.connect(_on_register_response.bind(user), CONNECT_ONE_SHOT)
	api.register(user, password)

func logout():
	is_logged_in = false
	username = ""
	token = ""
	_save_token()
	var api = get_node_or_null("/root/APIClient")
	if api:
		api.set_auth_token("")

func _on_login_response(endpoint: String, response: Dictionary, user: String):
	if response.has("error"):
		login_failed.emit(response.get("error", "unknown"))
		return
	token = response.get("token", "")
	if token.is_empty():
		login_failed.emit("no_token")
		return
	is_logged_in = true
	username = user
	_save_token()
	var api = get_node_or_null("/root/APIClient")
	if api:
		api.set_auth_token(token)
	login_success.emit(username)

func _on_register_response(endpoint: String, response: Dictionary, user: String):
	if response.has("error"):
		register_failed.emit(response.get("error", "unknown"))
		return
	register_success.emit(user)

func _save_token():
	var data = {"username": username, "token": token}
	var file = FileAccess.open(AUTH_FILE, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func _load_token():
	if not FileAccess.file_exists(AUTH_FILE):
		return
	var file = FileAccess.open(AUTH_FILE, FileAccess.READ)
	if not file:
		return
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		return
	token = json.data.get("token", "")
	username = json.data.get("username", "")
	if not token.is_empty():
		is_logged_in = true
		var api = get_node_or_null("/root/APIClient")
		if api:
			api.set_auth_token(token)
