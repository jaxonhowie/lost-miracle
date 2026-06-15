extends RefCounted

## 服务端雪花 ID 超过 JSON 浮点精度，统一按字符串处理。

static func from_value(value) -> String:
	if value == null:
		return ""
	var text := str(value).strip_edges()
	if text.ends_with(".0"):
		text = text.substr(0, text.length() - 2)
	return text

static func is_valid(value) -> bool:
	return not from_value(value).is_empty()
