extends Seeker
## 술래: 역병의 쥐
## - 쥐 소환: 부하 쥐 1마리를 풀어 수색 (쿨 50초, 한 번에 1마리)
##   쥐에게 물리면 15초 동안 피를 흘려 위치가 드러남. 쥐는 E로 잡을 수 있고, 잡히면 술래가 그 위치를 앎
## - 플라스크: 던지면 좁은 감속 구역(40% 느려짐, 8초). 최대 3개, 15초마다 1개 충전

const RatMinionScript := preload("res://scripts/rat_minion.gd")
const SlowZoneScript := preload("res://scripts/slow_zone.gd")

var flask_count := 3
var _flask_recharge := 0.0
var _flask_gap := 0.0
var _summon_cd := 0.0
var _minion: Node3D = null


func _ready() -> void:
	super._ready()
	flask_count = int(GameConfig.num("rat", "flask_max", 3))
	_summon_cd = 3.0  # 시작하자마자 곧 첫 쥐를 풂


func _ability_update(delta: float) -> void:
	_summon_cd = max(0.0, _summon_cd - delta)
	_flask_gap = max(0.0, _flask_gap - delta)
	# 플라스크 충전
	var max_f := int(GameConfig.num("rat", "flask_max", 3))
	if flask_count < max_f:
		_flask_recharge += delta
		if _flask_recharge >= GameConfig.num("rat", "flask_recharge", 15.0):
			_flask_recharge = 0.0
			flask_count += 1

	# 쥐 소환 (한 번에 1마리)
	if _summon_cd <= 0.0 and (_minion == null or not is_instance_valid(_minion)):
		_summon_minion()
		_summon_cd = GameConfig.num("rat", "summon_cooldown", 50.0)

	# 플라스크: 쫓는 중인 생존자 발밑에
	if flask_count > 0 and _flask_gap <= 0.0 and _lock_left <= 0.0:
		var target := _best_target_in_view(GameConfig.num("rat", "flask_range", 12.0))
		if target and global_position.distance_to(target.global_position) >= 3.0:
			_throw_flask(target.global_position)


func _summon_minion() -> void:
	var rat := CharacterBody3D.new()
	rat.set_script(RatMinionScript)
	get_tree().current_scene.add_child(rat)
	var spot := global_position - global_basis.z * 1.5
	rat.global_position = NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), spot) + Vector3.UP * 0.1
	rat.call("setup", self)
	_minion = rat


func _throw_flask(target_pos: Vector3) -> void:
	flask_count -= 1
	_flask_gap = GameConfig.num("rat", "flask_throw_gap", 4.0)
	_lock_left = 0.35
	var dir := target_pos - global_position
	rotation.y = atan2(-dir.x, -dir.z)

	# 포물선으로 날아가는 플라스크
	var flask := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.15
	sphere.height = 0.3
	flask.mesh = sphere
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.4, 1.0, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.9, 0.2)
	flask.material_override = mat
	get_tree().current_scene.add_child(flask)
	var start := global_position + Vector3.UP * 1.6
	var land := NavigationServer3D.map_get_closest_point(agent.get_navigation_map(), target_pos)
	flask.global_position = start
	var arc := func(p: float) -> void: flask.global_position = start.lerp(land, p) + Vector3.UP * sin(p * PI) * 2.5
	var tw := flask.create_tween()
	tw.tween_method(arc, 0.0, 1.0, GameConfig.num("rat", "flask_flight_time", 0.4))
	tw.tween_callback(_spawn_slow_zone.bind(land))
	tw.tween_callback(flask.queue_free)


func _spawn_slow_zone(pos: Vector3) -> void:
	var zone := Area3D.new()
	zone.set_script(SlowZoneScript)
	get_tree().current_scene.add_child(zone)
	zone.global_position = pos
	zone.call("setup")
