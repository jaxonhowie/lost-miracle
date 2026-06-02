extends Node

signal request_completed(endpoint: String, response: Dictionary)

const DEFAULT_BASE_URL: String = "http://localhost:8080"

var base_url: String = DEFAULT_BASE_URL
var auth_token: String = ""
var _http: HTTPRequest

func _ready():
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)

func set_base_url(url: String):
	base_url = url

func set_auth_token(token: String):
	auth_token = token

func get_player(player_id: String):
	_send_request("/api/player/" + player_id, HTTPClient.METHOD_GET)

func update_player(player_id: String, data: Dictionary):
	_send_request("/api/player/" + player_id, HTTPClient.METHOD_PUT, data)

func login(username: String, password: String):
	_send_request("/api/auth/login", HTTPClient.METHOD_POST, {
		"username": username,
		"password": password,
	})

func register(username: String, password: String):
	_send_request("/api/auth/register", HTTPClient.METHOD_POST, {
		"username": username,
		"password": password,
	})

func find_match(player_id: String):
	_send_request("/api/arena/match", HTTPClient.METHOD_GET)

func submit_result(player_id: String, result: Dictionary):
	_send_request("/api/arena/result", HTTPClient.METHOD_POST, result)

func _send_request(endpoint: String, method: int, body: Dictionary = {}):
	var url = base_url + endpoint
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if not auth_token.is_empty():
		headers.append("Authorization: Bearer " + auth_token)

	var json_body = ""
	if not body.is_empty():
		json_body = JSON.stringify(body)

	var err = _http.request(url, headers, method, json_body)
	if err != OK:
		push_warning("APIClient: request failed for " + endpoint)

func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray):
	if result != HTTPRequest.RESULT_SUCCESS:
		request_completed.emit("", {"error": "connection_failed", "code": result})
		return

	var json = JSON.new()
	var text = body.get_string_from_utf8()
	if json.parse(text) != OK:
		request_completed.emit("", {"error": "parse_error", "code": response_code})
		return

	var response = json.data
	if response_code >= 400:
		response["error"] = "http_error"
		response["code"] = response_code

	request_completed.emit("", response)
