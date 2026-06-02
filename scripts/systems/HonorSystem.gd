extends Node

signal honor_changed(new_value: int, change: int)

# Honor range: -1000 (evil) to +1000 (righteous)
var honor: int = 0
const MIN_HONOR: int = -1000
const MAX_HONOR: int = 1000

# History of recent honor changes
var history: Array = []  # [{ "value": int, "reason": String, "time": int }]
const MAX_HISTORY: int = 20

func add_honor(amount: int, reason: String = ""):
	var old_honor = honor
	honor = clampi(honor + amount, MIN_HONOR, MAX_HONOR)
	var actual_change = honor - old_honor
	if actual_change == 0:
		return
	# Record history
	history.push_front({
		"value": actual_change,
		"reason": reason,
		"time": Time.get_unix_time_from_system(),
	})
	if history.size() > MAX_HISTORY:
		history.resize(MAX_HISTORY)
	honor_changed.emit(honor, actual_change)

func get_honor_rank() -> String:
	if honor >= 800:
		return "圣光守护者"
	elif honor >= 500:
		return "荣誉骑士"
	elif honor >= 200:
		return "正义之士"
	elif honor >= -200:
		return "普通冒险者"
	elif honor >= -500:
		return "灰暗行者"
	elif honor >= -800:
		return "暗影刺客"
	else:
		return "堕落恶魔"

func get_shop_discount() -> float:
	if honor >= 500:
		return 0.10  # 10% discount
	return 0.0

func can_trade() -> bool:
	return honor >= -500

func is_bounty_target() -> bool:
	return honor <= -800

func get_save_data() -> Dictionary:
	return {
		"honor": honor,
		"history": history,
	}

func load_save_data(data: Dictionary):
	honor = data.get("honor", 0)
	history = data.get("history", [])
