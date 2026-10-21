extends Seeker
## 술래: 케르베로스 (사냥개)
## - 분열: 생존자를 발견하거나 소리를 들으면 바로 3마리로 나뉨 (30초 유지 후 합체, 합체 후 쿨 30초)
##   분신 2마리도 생존자를 잡을 수 있음. 분신은 양옆으로 퍼져서 앞질러 막음
## - 울부짖음: 추격 중에 울부짖어 25m 안의 생존자를 4초 동안 30% 느리게 만듦 (쿨 35초, 본체만)

const SFX_HOWL := preload("res://audio/howl.wav")
const SeekerSceneRef := "res://scenes/seeker.tscn"

## 분신이면 true (본체가 만들 때 넣어 줌)
var is_clone := false
var _clones: Array = []
var _split_left := 0.0
var _split_cd := 0.0
var _howl_cd := 0.0
var _howl_audio: AudioStreamPlayer3D


func _ready() -> void:
	super._ready()
	if is_clone:
		body.scale = Vector3.ONE * 0.8
		return
	_howl_cd = GameConfig.num("hound", "howl_cooldown", 35.0) * 0.4
	_howl_audio = AudioStreamPlayer3D.new()
	_howl_audio.stream = SFX_HOWL
	_howl_audio.max_distance = 60.0
	_howl_audio.unit_size = 8.0
	add_child(_howl_audio)


func _ability_update(delta: float) -> void:
	if is_clone:
		return
	_howl_cd = max(0.0, _howl_cd - delta)
	if _split_left > 0.0:
		_split_left -= delta
		_clones = _clones.filter(func(c): return is_instance_valid(c))
		if _split_left <= 0.0:
			_merge()
	else:
		_split_cd = max(0.0, _split_cd - delta)
	if _lock_left > 0.0 or possessed_by:
		return

	# 발견(추격) 또는 소리 확인(조사) 시작하면 무조건 분열
	if _split_cd <= 0.0 and _split_left <= 0.0 and (state == State.CHASE or state == State.INVESTIGATE):
		_split()
		return

	if _howl_cd <= 0.0 and state == State.CHASE:
		_howl()


func _split(goal_override := Vector3.INF) -> void:
	_split_left = GameConfig.num("hound", "split_time", 30.0)
	var goal: Vector3 = chase_target.global_position if chase_target else agent.target_position
	if goal_override != Vector3.INF:
		goal = goal_override
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var c := (load(SeekerSceneRef) as PackedScene).instantiate()
		c.set_script(load("res://scripts/seeker_hound.gd"))
		c.set("is_clone", true)
		var sk := c as Seeker
		sk.seeker_type = "hound"
		sk.map_half_size = map_half_size
		get_parent().add_child(sk)
		if enraged:
			sk.enrage()
		sk.global_position = _floor_point(global_position + global_basis.x * side * 1.6) + Vector3.UP * 0.1
		# 양옆으로 퍼져서 목표를 감싸듯 다가감
		var flank := goal + global_basis.x * side * 6.0
		if chase_target and is_instance_valid(chase_target):
			sk._start_chase(chase_target)
		else:
			sk._investigate(flank)
		_clones.append(sk)
		_puff(sk.global_position)
	_puff(global_position)
	if _howl_audio:
		_howl_audio.pitch_scale = 1.3
		_howl_audio.play()


func _merge() -> void:
	for c in _clones:
		if is_instance_valid(c):
			_puff((c as Node3D).global_position)
			c.queue_free()
	_clones.clear()
	_split_left = 0.0
	_split_cd = GameConfig.num("hound", "split_cooldown", 30.0)


## 나뉘거나 합칠 때 검은 연기
func _puff(pos: Vector3) -> void:
	_fx("puff", pos)
	var m := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.9
	s.height = 1.8
	m.mesh = s
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.05, 0.02, 0.02, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.material_override = mat
	get_tree().current_scene.add_child(m)
	m.global_position = pos + Vector3.UP
	var tw := m.create_tween()
	tw.tween_property(m, "scale", Vector3.ONE * 2.2, 0.6)
	tw.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.6)
	tw.tween_callback(m.queue_free)


func _howl() -> void:
	_howl_cd = GameConfig.num("hound", "howl_cooldown", 35.0)
	_lock_left = 0.9
	_howl_audio.pitch_scale = 1.0
	_howl_audio.play()
	_fx("howl", global_position)
	body.attack(0.5)
	_roar_ring(global_position)
	var r := GameConfig.num("hound", "howl_radius", 25.0)
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if s and not s.is_dead and global_position.distance_to(s.global_position) <= r:
			s.apply_slow(GameConfig.num("hound", "howl_slow", 0.3), GameConfig.num("hound", "howl_slow_time", 4.0))
			if s is Survivor:
				_notify(s as Survivor, "울부짖음에 다리가 굳었어요! (느려짐)")


func disable() -> void:
	super.disable()
	if not is_clone:
		_merge()
	else:
		queue_free()


func kill() -> void:
	if not is_clone:
		_merge()
	super.kill()


func fx_mirror(kind: String, a: Vector3, b: Vector3, extra) -> void:
	match kind:
		"puff":
			_puff(a)
		"howl":
			if _howl_audio:
				_howl_audio.pitch_scale = 1.0
				_howl_audio.play()
			body.attack(0.5)
			_roar_ring(a)
		_:
			super.fx_mirror(kind, a, b, extra)


# ---------------------------------------------------------------- 사람이 조종할 때 ([R] 울부짖음 / [T] 분열)

func poss_skills() -> Array:
	return [["울부짖음", "25m 안 생존자가 4초 동안 30% 느려져요"],
			["분열", "분신 2마리가 조준한 쪽 양옆으로 퍼져 생존자를 몰아요 (%d초)" % int(GameConfig.num("hound", "split_time", 30.0))]]


func poss_note(n: int) -> String:
	if n == 1 and _split_left > 0.0:
		return "분열 중 %d초" % ceili(_split_left)
	return ""


func _poss_do(n: int, aim: Vector3):
	if n == 0:
		_howl()
		return GameConfig.num("hound", "howl_cooldown", 35.0) * 0.6
	if _split_left > 0.0:
		return "이미 나뉘어 있어요 (%d초 남음)" % ceili(_split_left)
	_face_aim(aim)
	_split(global_position + aim * 14.0)
	return _split_left + GameConfig.num("hound", "split_cooldown", 30.0) * 0.5
