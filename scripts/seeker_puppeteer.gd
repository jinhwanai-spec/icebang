extends Seeker
## 술래: 인형사
## - 조종: 앞쪽 12m 안에 보이는 생존자를 실로 묶어 2초 동안 인형사 쪽으로 걸어오게 만듦 (쿨 30초)
## - 저주 인형: 봉인석 근처에 인형을 둠. 생존자가 다가가면 비명을 지르고 인형사가 알아챔 (최대 2개, 쿨 35초)

var _control_cd := 0.0
var _doll_cd := 0.0
var _dolls: Array = []
var _string: MeshInstance3D
var _string_target: Node3D = null
var _string_left := 0.0


func _ready() -> void:
	super._ready()
	_control_cd = GameConfig.num("puppeteer", "control_cooldown", 30.0) * 0.4
	_doll_cd = 5.0
	_string = MeshInstance3D.new()
	var line := BoxMesh.new()
	line.size = Vector3(0.03, 0.03, 1.0)
	_string.mesh = line
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.85, 0.75, 1.0)
	m.emission_enabled = true
	m.emission = Color(0.6, 0.3, 1.0)
	m.emission_energy_multiplier = 2.0
	_string.material_override = m
	_string.top_level = true
	_string.visible = false
	add_child(_string)


func _process(delta: float) -> void:
	super._process(delta)
	_string_left = maxf(0.0, _string_left - delta)
	_update_string()


func _ability_update(delta: float) -> void:
	_control_cd = max(0.0, _control_cd - delta)
	_doll_cd = max(0.0, _doll_cd - delta)
	if _lock_left > 0.0 or possessed_by:
		return

	if _control_cd <= 0.0:
		var range_m := GameConfig.num("puppeteer", "control_range", 12.0)
		for node in get_tree().get_nodes_in_group("survivor"):
			var s := node as Survivor
			if not _is_targetable(s) or global_position.distance_to(s.global_position) > range_m:
				continue
			var to_s := s.global_position - global_position
			to_s.y = 0.0
			var fwd := -global_basis.z
			fwd.y = 0.0
			if fwd.normalized().angle_to(to_s.normalized()) < deg_to_rad(45.0) and _clear_line(s):
				_control(s)
				return

	_dolls = _dolls.filter(func(d): return is_instance_valid(d))
	if _doll_cd <= 0.0 and state != State.CHASE and _dolls.size() < int(GameConfig.num("puppeteer", "doll_max", 2)):
		for g in _unfinished_generators():
			var d := global_position.distance_to((g as Node3D).global_position)
			if d < 8.0 and d > 2.5:
				_dolls.append(_spawn_effect("curse_doll", global_position))
				_doll_cd = GameConfig.num("puppeteer", "doll_cooldown", 35.0)
				_lock_left = 0.6
				return


func _control(s: Survivor) -> void:
	var t := GameConfig.num("puppeteer", "control_time", 2.0)
	s.set_controlled(t, self)
	_string_target = s
	_string_left = t
	var game := get_tree().get_first_node_in_group("game")
	if game:
		_fx("string", Vector3.ZERO, Vector3.ZERO, [(game.get("survivors") as Array).find(s), t])
	_control_cd = GameConfig.num("puppeteer", "control_cooldown", 30.0)
	_lock_left = t  # 실을 당기는 동안은 제자리
	if s is Survivor:
		_notify(s as Survivor, "인형사의 실에 조종당하고 있어요!")
	if state != State.CHASE and not possessed_by:
		_start_chase(s)


## 손에서 조종당하는 생존자까지 이어지는 실
func _update_string() -> void:
	if _string_target == null or not is_instance_valid(_string_target) or _string_left <= 0.0:
		_string.visible = false
		_string_target = null
		return
	var a := global_position + Vector3.UP * 2.3
	var b := _string_target.global_position + Vector3.UP * 1.0
	_string.visible = true
	_string.global_position = (a + b) / 2.0
	if a.distance_to(b) > 0.05:
		_string.look_at(b, Vector3.UP)
	_string.scale = Vector3(1, 1, a.distance_to(b))


func _on_stunned() -> void:
	_lock_left = 0.0
	_string_left = 0.0
	if _string_target and is_instance_valid(_string_target):
		(_string_target as Survivor).set_controlled(0.0, null)


func fx_mirror(kind: String, a: Vector3, b: Vector3, extra) -> void:
	if kind == "string":
		var e: Array = extra
		var game := get_tree().get_first_node_in_group("game")
		var sv: Array = game.get("survivors") if game else []
		var i := int(e[0])
		if i >= 0 and i < sv.size():
			_string_target = sv[i]
			_string_left = float(e[1])
		return
	super.fx_mirror(kind, a, b, extra)


# ---------------------------------------------------------------- 사람이 조종할 때 ([R] 조종 / [T] 저주 인형)

func poss_skills() -> Array:
	return [["실 조종", "조준한 생존자(12m)를 실로 묶어 2초 동안 내 쪽으로 걸어오게 해요"],
			["저주 인형", "발밑에 인형 (최대 %d개). 생존자가 다가가면 비명 → 위치가 보여요" % int(GameConfig.num("puppeteer", "doll_max", 2))]]


func poss_note(n: int) -> String:
	if n == 1:
		_dolls = _dolls.filter(func(d): return is_instance_valid(d))
		return "인형 %d개" % _dolls.size()
	return ""


func _poss_do(n: int, aim: Vector3):
	if n == 0:
		var s := _aim_target(aim, GameConfig.num("puppeteer", "control_range", 12.0), 25.0)
		if s == null:
			return "조준한 쪽 12m 안에 보이는 생존자가 없어요"
		_face_aim((s.global_position - global_position).normalized())
		_control(s)
		return GameConfig.num("puppeteer", "control_cooldown", 30.0) * 0.6
	_dolls = _dolls.filter(func(d): return is_instance_valid(d))
	if _dolls.size() >= int(GameConfig.num("puppeteer", "doll_max", 2)):
		var old: Node = _dolls.pop_front()  # 가장 오래된 인형을 치우고 새로
		old.queue_free()
	_dolls.append(_spawn_effect("curse_doll", global_position))
	_lock_left = 0.6
	return 12.0
