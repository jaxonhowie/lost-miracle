class_name ApiClient
extends RefCounted

const METHODS := {
	"GET": HTTPClient.METHOD_GET,
	"POST": HTTPClient.METHOD_POST,
	"PUT": HTTPClient.METHOD_PUT,
	"PATCH": HTTPClient.METHOD_PATCH,
	"DELETE": HTTPClient.METHOD_DELETE,
}

func make_request(method: String, path: String, body: Dictionary = {}, token: String = "") -> Dictionary:
	var http: HTTPRequest = await _spawn_http()
	if http == null:
		return {"ok": false, "code": -1, "message": "HTTP node unavailable", "data": {}}

	var headers: PackedStringArray = ["Content-Type: application/json"]
	if not token.is_empty():
		headers.append("Authorization: Bearer %s" % token)

	var url := "%s%s" % [ApiConfig.BASE_URL, path]
	var http_method: int = METHODS.get(method, HTTPClient.METHOD_GET)
	var body_str := ""
	if not body.is_empty():
		body_str = JSON.stringify(body)

	var err := http.request(url, headers, http_method, body_str)
	if err != OK:
		http.queue_free()
		return {"ok": false, "code": -1, "message": "HTTP request failed: %d" % err, "data": {}}

	var result: Array = await http.request_completed
	http.queue_free()

	var result_code: int = result[0]
	var status: int = result[1]
	var response_body: PackedByteArray = result[3]

	# http_status 用于上层识别鉴权失败（服务端未认证返回 401 + ApiResponse）。
	if result_code != HTTPRequest.RESULT_SUCCESS:
		return {
			"ok": false, "code": -1, "http_status": 0,
			"message": "Connection failed (error %d)" % result_code, "data": {}
		}

	if _is_auth_failure(status):
		return _auth_failure_response(status)

	var json := JSON.new()
	var body_text := ApiIds.quote_snowflake_ids(response_body.get_string_from_utf8())
	var parse_err := json.parse(body_text)
	if parse_err != OK:
		return {
			"ok": false, "code": -1, "http_status": status,
			"message": "Invalid JSON response (status %d)" % status, "data": {}
		}

	var resp: Dictionary = json.data
	var resp_code: int = int(resp.get("code", -1))
	return {
		"ok": resp_code == 0,
		"code": resp_code,
		"http_status": status,
		"message": str(resp.get("message", "")),
		"data": resp.get("data", {}),
	}

func _is_auth_failure(status: int) -> bool:
	return status == ApiConfig.HTTP_UNAUTHORIZED

func _auth_failure_response(status: int) -> Dictionary:
	return {
		"ok": false,
		"code": ApiConfig.CLIENT_AUTH_EXPIRED_CODE,
		"http_status": status,
		"message": ApiConfig.AUTH_FAILURE_MESSAGE,
		"data": {},
	}

func _spawn_http() -> HTTPRequest:
	var host: Node = Engine.get_main_loop().root.get_node_or_null("/root/NetworkManager")
	if host and host.has_method("create_http_request"):
		return host.create_http_request()

	if host and host.is_inside_tree():
		var http := HTTPRequest.new()
		http.timeout = int(ApiConfig.TIMEOUT)
		host.add_child(http)
		await host.get_tree().process_frame
		if http.is_inside_tree():
			return http
		http.queue_free()

	return null
