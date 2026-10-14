extends Node3D
## 캐릭터 능력이 맵에 남기는 것들을 한 파일에서 처리합니다.
##   "smoke"     그림자 연막탄: 안에 있으면 술래가 아무도 못 봄
##   "ward"      등불지기 결계: 안에 들어온 술래가 느려짐
##   "trap"      사냥꾼 덫: 밟은 술래가 묶임 (스턴)
##   "decoy"     등불지기 미끼 인형: 소리를 내서 술래를 유인
##   "barricade" 정비공 바리케이드: 술래를 막는 벽 (유령은 통과)
##   "orb"       중력술사 무중력 구슬: 날아가다 맞은 술래를 느리게
##   "arrow"     사냥꾼 핏빛 화살: 맞은 술래가 계속 피를 흘림
##   "guide"     등불지기 길잡이 등불: 플레이어가 가까이 있으면 봉인석으로 길 안내
##   "wisp"      등불지기 붉은 탐색광: 술래를 찾아가 20초 동안 환하게 빛남
##   "web_trap"  거미 여왕 거미줄 덫: 밟은 생존자가 묶이고 거미가 알아챔
##   "curse_doll" 인형사 저주 인형: 봉인석 근처에 생존자가 오면 인형사가 알아챔
## 사용법: effect.setup("smoke", 시작위치, 방향, 만든 사람)

const SFX_TRAP := preload("res://audio/punch.wav")
const SFX_LURE := preload("res://audio/lure.wav")

var kind := ""
var owner_node: Node3D = null
var direction := Vector3.FORWARD
var _life := 10.0
var _timer := 0.0
var _travelled := 0.0
var _audio: AudioStreamPlayer3D
var _wisp_light: OmniLight3D
var _found: Node3D = null
var _found_left := 0.0


func setup(effect_kind: String, pos: Vector3, dir: Vector3, by: Node3D) -> void:
	kind = effect_kind
	owner_node = by
	direction = Vector3(dir.x, 0, dir.z).normalized()
	global_position = pos
	match kind:
		"smoke":
			_life = GameConfig.num("shadow", "smoke_time", 8.0)
			var r := GameConfig.num("shadow", "smoke_radius", 6.0)
			set_meta("radius", r)
			add_to_group("smoke")
			for i in 14:  # 뭉게뭉게 연기 덩어리
				var p := Vector3(randf_range(-r, r) * 0.8, randf_range(0.3, 2.2), randf_range(-r, r) * 0.8)
				_puff(p, randf_range(1.2, 2.2), Color(0.55, 0.55, 0.6, 0.55))
		"ward":
			_life = GameConfig.num("keeper", "ward_time", 10.0)
			var r := GameConfig.num("keeper", "ward_radius", 7.0)
			set_meta("radius", r)
			set_meta("slow", GameConfig.num("keeper", "ward_slow", 0.5))
			add_to_group("ward")
			_ring(r, Color(1.0, 0.85, 0.4))
			var light := OmniLight3D.new()
			light.light_color = Color(1.0, 0.8, 0.4)
			light.omni_range = r + 2.0
			light.light_energy = 2.0
			light.position.y = 2.0
			add_child(light)
		"trap":
			_life = GameConfig.num("hunter", "trap_life", 90.0)
			var jaw := MeshInstance3D.new()
			var tm := TorusMesh.new()
			tm.inner_radius = 0.3
			tm.outer_radius = 0.42
			jaw.mesh = tm
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.25, 0.22, 0.2)  # 어두워서 잘 안 보임
			m.metallic = 0.6
			jaw.material_override = m
			jaw.position.y = 0.03
			add_child(jaw)
		"decoy":
			_life = GameConfig.num("keeper", "decoy_time", 12.0)
			var body := ClayBody.new()
			add_child(body)
			body.build(by.character_id if by and "character_id" in by else "keeper")
			body.rotation.y = randf() * TAU
			_audio = AudioStreamPlayer3D.new()
			_audio.stream = SFX_LURE
			_audio.max_distance = 30.0
			_audio.position.y = 1.0
			add_child(_audio)
		"barricade":
			_life = GameConfig.num("mechanic", "barricade_time", 8.0)
			var wall := StaticBody3D.new()
			wall.collision_layer = 1
			var shape := CollisionShape3D.new()
			var box := BoxShape3D.new()
			box.size = Vector3(4.0, 2.6, 0.4)
			shape.shape = box
			shape.position.y = 1.3
			wall.add_child(shape)
			var mesh := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = box.size
			mesh.mesh = bm
			mesh.position.y = 1.3
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.55, 0.42, 0.25)
			mesh.material_override = m
			wall.add_child(mesh)
			add_child(wall)
			look_at(global_position + direction, Vector3.UP)
			scale = Vector3(1, 0.05, 1)
			create_tween().tween_property(self, "scale", Vector3.ONE, 0.25)
		"arrow":
			_life = 3.0
			var shaft := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.02
			cm.bottom_radius = 0.02
			cm.height = 0.9
			shaft.mesh = cm
			shaft.rotation.x = PI / 2.0
			var am := StandardMaterial3D.new()
			am.albedo_color = Color(0.5, 0.35, 0.2)
			shaft.material_override = am
			add_child(shaft)
			look_at(global_position + direction, Vector3.UP)
		"guide":
			_life = 9999.0
			for k in 3:
				_puff(Vector3(randf_range(-0.4, 0.4), randf_range(-0.2, 0.3), randf_range(-0.4, 0.4)), 0.12, Color(1.0, 0.85, 0.4, 0.95))
			var gl := OmniLight3D.new()
			gl.light_color = Color(1.0, 0.8, 0.4)
			gl.omni_range = 5.0
			gl.light_energy = 1.5
			add_child(gl)
		"wisp":
			_life = 40.0  # 찾지 못해도 40초 뒤에는 사라짐
			for k in 3:
				_puff(Vector3(randf_range(-0.3, 0.3), randf_range(-0.2, 0.2), randf_range(-0.3, 0.3)), 0.1, Color(1.0, 0.15, 0.1, 0.95))
			_wisp_light = OmniLight3D.new()
			_wisp_light.light_color = Color(1.0, 0.15, 0.1)
			_wisp_light.omni_range = 3.0
			_wisp_light.light_energy = 1.0
			add_child(_wisp_light)
		"web_trap":
			_life = GameConfig.num("spider", "web_trap_life", 60.0)
			add_to_group("web_trap")
			_ring(0.9, Color(0.85, 0.85, 0.9))
		"curse_doll":
			_life = GameConfig.num("puppeteer", "doll_life", 90.0)
			_puff(Vector3(0, 0.35, 0), 0.22, Color(0.6, 0.45, 0.4, 1.0))
			_puff(Vector3(0, 0.7, 0), 0.16, Color(0.75, 0.6, 0.55, 1.0))
		"orb":
			_life = 5.0
			_puff(Vector3.ZERO, 0.35, Color(0.6, 0.8, 1.0, 0.85))
			var light := OmniLight3D.new()
			light.light_color = Color(0.6, 0.8, 1.0)
			light.omni_range = 3.0
			add_child(light)


func _puff(pos: Vector3, r: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if kind == "orb":
		m.emission_enabled = true
		m.emission = Color(c.r, c.g, c.b)
		m.emission_energy_multiplier = 3.0
	mi.material_override = m
	mi.position = pos
	add_child(mi)


func _ring(r: float, c: Color) -> void:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = r - 0.15
	tm.outer_radius = r
	mi.mesh = tm
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.0
	mi.material_override = m
	mi.position.y = 0.05
	add_child(mi)


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		_fade_out()
		return
	match kind:
		"trap":
			for node in get_tree().get_nodes_in_group("seeker"):
				var sk := node as Seeker
				if sk and sk.is_active() and sk.global_position.distance_to(global_position) < 1.0:
					sk.stun(GameConfig.num("hunter", "trap_stun", 3.0))
					sk.reveal(GameConfig.num("hunter", "trap_stun", 3.0))
					var p := AudioStreamPlayer3D.new()
					p.stream = SFX_TRAP
					p.max_distance = 40.0
					get_tree().current_scene.add_child(p)
					p.global_position = global_position
					p.play()
					if owner_node and is_instance_valid(owner_node) and owner_node.has_signal("notice"):
						owner_node.emit_signal("notice", "덫에 술래가 걸렸어요!")
					queue_free()
					return
		"decoy":
			_timer -= delta
			if _timer <= 0.0:
				_timer = 2.0
				NoiseBus.make_noise(global_position, 20.0, null)
				_audio.play()
		"arrow":
			var step := GameConfig.num("hunter", "arrow_speed", 45.0) * delta
			global_position += direction * step
			_travelled += step
			for node in get_tree().get_nodes_in_group("seeker"):
				var sk := node as Seeker
				if sk and sk.is_active() and Vector2(sk.global_position.x, sk.global_position.z).distance_to(Vector2(global_position.x, global_position.z)) < 1.1:
					sk.start_bleeding()
					_notify("화살 명중! 술래가 피를 흘려요")
					queue_free()
					return
			if _hit_wall(direction) or _travelled > GameConfig.num("hunter", "arrow_range", 45.0):
				_notify("화살이 빗나갔어요")
				queue_free()
		"guide":
			_update_guide(delta)
		"wisp":
			_update_wisp(delta)
		"web_trap":
			for node in get_tree().get_nodes_in_group("survivor"):
				var s := node as Survivor
				if s and not s.is_dead and not s.is_frozen and s.global_position.distance_to(global_position) < 1.0:
					s.pulled_time_left = GameConfig.num("spider", "web_root", 2.0)
					if owner_node and is_instance_valid(owner_node):
						owner_node.call("alert_to", global_position)
					_notify_to(s, "거미줄에 걸렸어요! 거미가 알아챘어요")
					queue_free()
					return
		"curse_doll":
			for node in get_tree().get_nodes_in_group("survivor"):
				var s := node as Survivor
				if s and not s.is_dead and s.global_position.distance_to(global_position) < 3.0:
					if owner_node and is_instance_valid(owner_node):
						owner_node.call("alert_to", global_position)
					var p := AudioStreamPlayer3D.new()
					p.stream = preload("res://audio/whisper.wav")
					p.max_distance = 30.0
					get_tree().current_scene.add_child(p)
					p.global_position = global_position
					p.play()
					_notify_to(s, "저주 인형이 비명을 질렀어요! 인형사가 알아챘어요")
					queue_free()
					return
		"orb":
			var step := GameConfig.num("gravity", "orb_speed", 18.0) * delta
			global_position += direction * step
			_travelled += step
			for node in get_tree().get_nodes_in_group("seeker"):
				var sk := node as Seeker
				if sk and sk.is_active() and Vector2(sk.global_position.x, sk.global_position.z).distance_to(Vector2(global_position.x, global_position.z)) < 1.3:
					sk.slow(GameConfig.num("gravity", "orb_slow_time", 3.0), GameConfig.num("gravity", "orb_slow", 0.6))
					if owner_node and is_instance_valid(owner_node) and owner_node.has_signal("notice"):
						owner_node.emit_signal("notice", "무중력 구슬 명중! 술래가 느려졌어요")
					queue_free()
					return
			var q := PhysicsRayQueryParameters3D.create(global_position, global_position + direction * 0.5)
			q.collision_mask = 1
			var hit := get_world_3d().direct_space_state.intersect_ray(q)
			if (not hit.is_empty() and hit["collider"] is StaticBody3D) or _travelled > GameConfig.num("gravity", "orb_range", 30.0):
				queue_free()


func _notify(text: String) -> void:
	if owner_node and is_instance_valid(owner_node) and owner_node.has_signal("notice"):
		owner_node.emit_signal("notice", text)


## 생존자가 E로 거미줄 덫을 걷어냄
func clear_web() -> void:
	remove_from_group("web_trap")
	queue_free()


func _notify_to(s: Node, text: String) -> void:
	if s.has_signal("notice"):
		s.emit_signal("notice", text)


func _hit_wall(dir: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + dir * 0.6)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	return not hit.is_empty() and hit["collider"] is StaticBody3D


## 길잡이 등불: 가장 가까운 안 끝난 봉인석까지 길을 따라감. 플레이어가 멀면 기다림
var _path: PackedVector3Array = []
var _path_i := 0
var _repath := 0.0
func _update_guide(delta: float) -> void:
	if owner_node == null or not is_instance_valid(owner_node):
		queue_free()
		return
	_repath -= delta
	if _repath <= 0.0:
		_repath = 2.0
		var gens := get_tree().get_nodes_in_group("generator").filter(func(g): return not g.completed)
		if gens.is_empty():
			return
		gens.sort_custom(func(a, b): return a.global_position.distance_to(global_position) < b.global_position.distance_to(global_position))
		var map := get_world_3d().navigation_map
		var from := NavigationServer3D.map_get_closest_point(map, global_position)
		_path = NavigationServer3D.map_get_path(map, from, gens[0].global_position, true)
		_path_i = 0
	# 플레이어가 5m 안에 있어야 움직임
	if owner_node.global_position.distance_to(global_position) > GameConfig.num("keeper", "guide_wait_distance", 5.0):
		position.y = lerpf(position.y, 1.5 + sin(Time.get_ticks_msec() / 300.0) * 0.15, 0.1)
		return
	while _path_i < _path.size() and Vector2(_path[_path_i].x, _path[_path_i].z).distance_to(Vector2(global_position.x, global_position.z)) < 0.6:
		_path_i += 1
	if _path_i >= _path.size():
		return
	var target := _path[_path_i] + Vector3.UP * 1.5
	var dir := target - global_position
	var step := GameConfig.num("keeper", "guide_speed", 3.8) * delta
	global_position += dir.normalized() * minf(step, dir.length())


## 붉은 탐색광: 맡은 술래에게 날아가서, 닿으면 20초 동안 환하게 빛나며 위치를 알림
func _update_wisp(delta: float) -> void:
	var target = get_meta("target", null)  # 타입 없이 받음 (분신처럼 사라진 대상일 수 있음)
	if _found:
		_found_left -= delta
		if is_instance_valid(_found):
			global_position = _found.global_position + Vector3.UP * 3.2
			(_found as Seeker).reveal(0.5)
		_wisp_light.light_energy = 6.0 + sin(Time.get_ticks_msec() / 120.0) * 2.0
		if _found_left <= 0.0 or not is_instance_valid(_found):
			_life = 0.0
		return
	if target == null or not is_instance_valid(target) or not (target as Seeker).is_active():
		_life = 0.0
		return
	var dir: Vector3 = target.global_position + Vector3.UP * 3.0 - global_position
	if dir.length() < 2.5:
		_found = target
		_found_left = GameConfig.num("keeper", "wisp_glow_time", 20.0)
		_wisp_light.omni_range = 12.0
		scale = Vector3.ONE * 2.5
		_notify("탐색광이 술래를 찾았어요!")
		return
	global_position += dir.normalized() * GameConfig.num("keeper", "wisp_speed", 12.0) * delta


func _fade_out() -> void:
	if kind == "wisp" and owner_node and is_instance_valid(owner_node) and owner_node.has_method("on_wisp_done"):
		owner_node.call("on_wisp_done")
	set_physics_process(false)
	remove_from_group("smoke")
	remove_from_group("ward")
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(1, 0.01, 1) if kind == "barricade" else Vector3.ONE * 0.01, 0.3)
	tw.tween_callback(queue_free)
