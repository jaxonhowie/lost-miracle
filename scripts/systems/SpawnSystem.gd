extends Node

const SPAWN_DATA_PATH = "res://data/spawns_dungeon_1.json"
const PLAYER_DISTANCE_MIN = 300.0
const MAX_PER_ZONE = 6

var monster_scenes: Dictionary = {
	"skeleton_soldier": "res://scenes/monsters/SkeletonSoldier.tscn",
	"zombie": "res://scenes/monsters/Zombie.tscn",
	"ghost": "res://scenes/monsters/Ghost.tscn",
	"elite_skeleton_knight": "res://scenes/monsters/EliteSkeletonKnight.tscn",
	"elite_necromancer": "res://scenes/monsters/EliteNecromancer.tscn",
	"grave_keeper_boss": "res://scenes/monsters/GraveKeeperBoss.tscn",
}

# spawn_id -> {config, monster_node, death_time, scene}
var spawn_points: Dictionary = {}

# zone -> count of alive monsters
var zone_alive: Dictionary = {}

# Preloaded scenes cache
var _scene_cache: Dictionary = {}

func _ready():
	_preload_scenes()
	_load_spawn_data()

func _preload_scenes():
	for monster_id in monster_scenes:
		_scene_cache[monster_id] = load(monster_scenes[monster_id])

func _load_spawn_data():
	var file = FileAccess.open(SPAWN_DATA_PATH, FileAccess.READ)
	if not file:
		push_error("SpawnSystem: cannot open " + SPAWN_DATA_PATH)
		return
	var json = JSON.new()
	var err = json.parse(file.get_as_text())
	if err != OK:
		push_error("SpawnSystem: JSON parse error")
		return
	var data = json.data
	if not data is Array:
		push_error("SpawnSystem: expected Array")
		return
	for entry in data:
		register_spawn_point(entry)

func register_spawn_point(data: Dictionary):
	var spawn_id = data["spawn_id"]
	var zone = data.get("zone", "default")
	spawn_points[spawn_id] = {
		"config": data,
		"monster_node": null,
		"death_time": 0.0,
		"zone": zone,
	}
	if not zone_alive.has(zone):
		zone_alive[zone] = 0
	# Spawn immediately on load
	_try_spawn(spawn_id)

func _process(delta):
	for spawn_id in spawn_points:
		var sp = spawn_points[spawn_id]
		if sp["monster_node"] != null and is_instance_valid(sp["monster_node"]):
			continue
		sp["monster_node"] = null
		if sp["death_time"] <= 0:
			_try_spawn(spawn_id)
			continue
		var elapsed = Time.get_unix_time_from_system() - sp["death_time"]
		if elapsed >= sp["config"]["respawn_seconds"]:
			_try_spawn(spawn_id)

func _try_spawn(spawn_id: String):
	var sp = spawn_points[spawn_id]
	if sp["monster_node"] != null and is_instance_valid(sp["monster_node"]):
		return

	var zone = sp["zone"]
	if zone_alive.get(zone, 0) >= MAX_PER_ZONE:
		return

	var pos = Vector2(sp["config"]["position"][0], sp["config"]["position"][1])
	if _player_too_close(pos):
		return

	var monster_id = sp["config"]["monster_id"]
	if not _scene_cache.has(monster_id):
		push_error("SpawnSystem: unknown monster_id " + monster_id)
		return

	var monster = _scene_cache[monster_id].instantiate()
	monster.global_position = pos
	get_tree().current_scene.add_child(monster)

	monster.died.connect(_on_monster_died.bind(spawn_id))
	sp["monster_node"] = monster
	sp["death_time"] = 0.0
	zone_alive[zone] = zone_alive.get(zone, 0) + 1

func _on_monster_died(monster, spawn_id: String):
	if not spawn_points.has(spawn_id):
		return
	var sp = spawn_points[spawn_id]
	sp["monster_node"] = null
	sp["death_time"] = Time.get_unix_time_from_system()
	var zone = sp["zone"]
	zone_alive[zone] = maxi(0, zone_alive.get(zone, 0) - 1)

func _player_too_close(pos: Vector2) -> bool:
	var players = get_tree().get_nodes_in_group("player")
	if players.is_empty():
		return false
	return pos.distance_to(players[0].global_position) < PLAYER_DISTANCE_MIN

func get_respawn_state() -> Dictionary:
	var state = {}
	for spawn_id in spawn_points:
		var sp = spawn_points[spawn_id]
		if sp["death_time"] > 0:
			state[spawn_id] = sp["death_time"]
	return state

func load_respawn_state(state: Dictionary):
	for spawn_id in state:
		if spawn_points.has(spawn_id):
			spawn_points[spawn_id]["death_time"] = state[spawn_id]
