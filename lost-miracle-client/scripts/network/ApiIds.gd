extends Node

## 服务端雪花 ID 超过 JSON 浮点精度，统一按字符串处理。
## 若 ApiClient 未正确引号化大整数，float 精度丢失后无法恢复。

const _ID_FIELD_RE := "\"(?:id|userId|characterId)\"\\s*:\\s*(\\d{15,})"


static func from_value(value) -> String:
	if value == null:
		return ""
	if value is String:
		return value.strip_edges()
	var text := str(value).strip_edges()
	if text.ends_with(".0"):
		text = text.substr(0, text.length() - 2)
	return text


static func is_valid(value) -> bool:
	return not from_value(value).is_empty()


## 将响应 JSON 中雪花 ID 字段的大整数改为字符串，避免 Godot JSON 解析为 float 丢精度。
static func quote_snowflake_ids(json_text: String) -> String:
	var re := RegEx.new()
	if re.compile(_ID_FIELD_RE) != OK:
		return json_text
	var out := json_text
	var offset := 0
	while true:
		var m := re.search(out, offset)
		if m == null:
			break
		var num_start := m.get_start(1)
		var num_end := m.get_end(1)
		var num := out.substr(num_start, num_end - num_start)
		out = out.substr(0, num_start) + '"' + num + '"' + out.substr(num_end)
		offset = num_start + num.length() + 2
	return out
