extends Node3D
## 중력술사 붕괴: 날아가는 지름 12m 보라색 구체
## - 정면으로 날아가며, 닿는 건물·나무·차·봉인석을 차례로 부숨 (바닥과 바깥 울타리는 제외)
## - 지나간 바닥에 휩쓸린 자국을 남김 (판 끝까지 유지)
## - 닿은 술래와 생존자는 모두 죽음 (쓴 본인과 얼음 상태는 제외)
## - 맵 끝에 닿으면 터지면서 사라지고, 길 정보를 다시 계산

const PURPLE := Color(0.7, 0.25, 1.0)

var caster: Node3D = null
var direction := Vector3.FORWARD
var radius := 6.0
var speed := 40.0

var _game: Node = null
var _travelled := 0.0
var _max_distance := 0.0
var _mark_timer := 0.0
var _broke_any := false
var _killed_seekers := 0
var _killed_allies := 0
var _broken := 0
var _core: MeshInstance3D
var _shell: MeshInstance3D
var _light: OmniLight3D
var _mark_mat: StandardMaterial3D


func launch(by: Node3D, from: Vector3, dir: Vector3) -> void:
	caster = by
	_game = get_tree().get_first_node_in_group("game")
	direction = Vector3(dir.x, 0, dir.z).normalized()
	radius = GameConfig.num("gravity", "collapse_diameter", 12.0) / 2.0
	speed = GameConfig.num("gravity", "collapse_speed", 40.0)
	global_position = from
	_max_distance = _game._distance_to_edge(from, direction) + radius
	_build_look()


func _build_look() -> void:
	# 안쪽 밝은 핵 + 바깥 반투명 껍질 + 강한 보라빛
	_core = _sphere(1.0, PURPLE.lightened(0.5), 1.0, 6.0)
	_shell = _sphere(1.0, PURPLE, 0.45, 3.0)
	_light = OmniLight3D.new()
	_light.light_color = PURPLE
	_light.light_energy = 6.0
	_light.omni_range = 30.0
	add_child(_light)
	_mark_mat = StandardMaterial3D.new()
	_mark_mat.albedo_color = Color(0.12, 0.03, 0.16)
	_mark_mat.roughness = 1.0
	_mark_mat.emission_enabled = true
	_mark_mat.emission = Color(0.35, 0.05, 0.5)
	_mark_mat.emission_energy_multiplier = 0.4
	# 처음 0.25초 동안 손 앞의 작은 구슬에서 12m 크기로 부풀어 오름
	scale = Vector3.ONE * 0.1
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _sphere(r: float, c: Color, alpha: float, energy: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius * r * (0.55 if alpha >= 1.0 else 1.0)
	sm.height = sm.radius * 2.0
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	mi.material_override = m
	add_child(mi)
	return mi


func _physics_process(delta: float) -> void:
	var step := speed * delta
	global_position += direction * step
	_travelled += step
	var t := Time.get_ticks_msec() / 1000.0
	_core.rotation = Vector3(t * 3.0, t * 2.0, 0)
	_shell.scale = Vector3.ONE * (1.0 + sin(t * 25.0) * 0.04)  # 일렁임
	var r := radius * scale.x

	# 닿은 지형 파괴 (봉인석 포함)
	var broken: Array[Vector3] = _game.destroy_sphere(global_position, r)
	if not broken.is_empty():
		_broke_any = true
		_broken += broken.size()
		for pos in broken:
			if caster and is_instance_valid(caster):
				caster.call("_debris", pos)

	# 닿은 술래·생존자는 죽음 (쓴 본인, 얼음 상태는 제외)
	for node in get_tree().get_nodes_in_group("seeker"):
		var sk := node as Seeker
		if sk and _touching(sk.global_position, r):
			sk.kill()
			_killed_seekers += 1
	for node in get_tree().get_nodes_in_group("survivor"):
		var s := node as Survivor
		if s and s != caster and not s.is_dead and not s.is_frozen and _touching(s.global_position, r):
			s.die()
			_killed_allies += 1

	# 바닥에 휩쓸린 자국 (2m마다)
	_mark_timer -= step
	if _mark_timer <= 0.0:
		_mark_timer = 2.0
		_leave_mark()

	# 가까운 플레이어 화면 흔들기
	var cam := get_viewport().get_camera_3d()
	if cam:
		var d := cam.global_position.distance_to(global_position)
		var amount := clampf(1.0 - (d - r) / 30.0, 0.0, 1.0) * 0.3
		cam.h_offset = randf_range(-amount, amount)
		cam.v_offset = randf_range(-amount, amount)

	if _travelled >= _max_distance:
		_finish()


func _touching(p: Vector3, r: float) -> bool:
	return Vector2(p.x, p.z).distance_to(Vector2(global_position.x, global_position.z)) <= r + 0.5


## 지나간 자리 바닥에 검보라색으로 그을린 원 (겹쳐서 띠처럼 보임)
func _leave_mark() -> void:
	var mi := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = radius * 0.95
	disc.bottom_radius = radius * 0.95
	disc.height = 0.02
	disc.radial_segments = 24
	mi.mesh = disc
	mi.material_override = _mark_mat
	get_tree().current_scene.add_child(mi)
	mi.global_position = Vector3(global_position.x, 0.06 + randf() * 0.01, global_position.z)


func _finish() -> void:
	set_physics_process(false)
	var cam := get_viewport().get_camera_3d()
	if cam:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	if _broke_any:
		_game.rebake_navigation()
	if caster and is_instance_valid(caster) and caster.has_signal("notice"):
		var text := "붕괴!! 지형 %d개 파괴" % _broken
		if _killed_seekers > 0:
			text += ", 술래 %d마리 처치" % _killed_seekers
		if _killed_allies > 0:
			text += ", 동료 %d명 휘말림" % _killed_allies
		caster.emit_signal("notice", text)
	# 맵 끝에서 터지며 사라짐
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "scale", Vector3.ONE * 1.6, 0.35)
	tw.tween_property(_light, "light_energy", 0.0, 0.35)
	tw.tween_property(_shell.material_override, "albedo_color:a", 0.0, 0.35)
	tw.tween_property(_core.material_override, "albedo_color:a", 0.0, 0.35)
	(_core.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tw.chain().tween_callback(queue_free)
