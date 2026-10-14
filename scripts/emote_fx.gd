extends RefCounted
## 이모트 효과 (방귀 구름, 코딱지, 응가, 어지러운 별, 머리 위 글자)
## survivor.gd 의 start_emote() 가 spawn() 을 부릅니다. 멀티에서는 모든 컴퓨터에서 각자 그림.
## 효과는 이모트 동작에 맞춰 조금 늦게 나오며, 그 사이 이모트를 멈추면 나오지 않아요.


static func spawn(who: Node3D, id: String) -> void:
	match id:
		"fart":
			_later(who, id, 0.6, func(): _gas(who, _butt(who), 1.0, "뿡!"))
		"poop":
			_say(who, "끄응...")
			_later(who, id, 1.6, func(): _poop(who))
		"dead":
			_later(who, id, 0.4, func(): _say(who, "X_X"))
		"robot":
			_say(who, "삐-빅- 로봇 모드")
		"dizzy":
			_later(who, id, 1.2, func():
				_stars(who)
				_say(who, "@_@ 어질어질"))
		"disco":
			_disco(who, id)
		"trot":
			_say(who, "얼쑤~ 좋다!")
			for k in 10:
				_later(who, id, 0.2 + k * 0.6, func(): _note(who))
		"chicken":
			for k in 4:
				_later(who, id, 0.3 + k * 0.5, func(): _feathers(who))
			_later(who, id, 2.4, func(): _pop_text(who, who.global_position + Vector3.UP * 2.0, "꼬끼오~!!", Color(1.0, 0.9, 0.3), 1.6))
		"gaedari":
			_say(who, "개다리~ 후들후들")
			for k in 3:
				_later(who, id, 0.5 + k * 1.0, func(): _pop_text(who, who.global_position + Vector3(randf_range(-0.4, 0.4), 1.6, 0), "♬", Color(0.6, 0.9, 1.0), 1.2))


## 붙어 있는 효과(별 등) 없애기
static func clear(who: Node3D) -> void:
	for c in who.get_children():
		if c.has_meta("emote_fx"):
			c.queue_free()


# ---------------------------------------------------------------- 도우미

static func _later(who: Node3D, id: String, delay: float, fn: Callable) -> void:
	who.get_tree().create_timer(delay).timeout.connect(func():
		if is_instance_valid(who) and who.get("emote_id") == id and float(who.get("dance_left")) > 0.0:
			fn.call())


static func _say(who: Node3D, text: String) -> void:
	if who.has_method("show_emote"):
		who.call("show_emote", text)


static func _front(who: Node3D) -> Vector3:
	var body := who.get("body") as Node3D
	var f := body.global_basis.z if body else who.global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD


static func _local(who: Node3D, p: Vector3) -> Vector3:
	var body := who.get("body") as Node3D
	return body.global_transform * p if body else who.global_position + p


static func _butt(who: Node3D) -> Vector3:
	return who.global_position + Vector3.UP * 0.45 - _front(who) * 0.35


static func _world(who: Node3D) -> Node:
	return who.get_parent() if who.get_parent() else who


## 방귀 구름: 초록빛 뭉게뭉게 + 글자 팝업
static func _gas(who: Node3D, at: Vector3, size: float, text: String) -> void:
	var p := CPUParticles3D.new()
	_world(who).add_child(p)
	p.global_position = at
	p.one_shot = true
	p.explosiveness = 0.85
	p.amount = int(22 * size) + 4
	p.lifetime = 2.2
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.12 * size
	var away := -_front(who) if size > 0.8 else (at - who.global_position).normalized()
	p.direction = (away + Vector3.UP * 0.4).normalized()
	p.spread = 45.0
	p.initial_velocity_min = 0.4 * size
	p.initial_velocity_max = 1.3 * size
	p.damping_min = 1.0
	p.damping_max = 1.6
	p.gravity = Vector3(0, 0.25, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.35))
	curve.add_point(Vector2(0.4, 1.0))
	curve.add_point(Vector2(1, 1.3))
	p.scale_amount_curve = curve
	p.scale_amount_min = 0.28 * size
	p.scale_amount_max = 0.45 * size
	var puff := SphereMesh.new()
	puff.radius = 0.5
	puff.height = 1.0
	puff.radial_segments = 10
	puff.rings = 6
	p.mesh = puff
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(0.35, 0.5, 0.1)
	m.emission_energy_multiplier = 0.4
	p.material_override = m
	var grad := Gradient.new()
	grad.set_color(0, Color(0.72, 0.85, 0.25, 0.7))
	grad.set_color(1, Color(0.55, 0.65, 0.2, 0.0))
	p.color_ramp = grad
	p.emitting = true
	who.get_tree().create_timer(3.0).timeout.connect(p.queue_free)
	_pop_text(who, at + Vector3.UP * 0.3, text, Color(0.75, 1.0, 0.3), 0.9 + size * 0.5)


static func _pop_text(who: Node3D, at: Vector3, text: String, col: Color, scale_k: float) -> void:
	var l := Label3D.new()
	l.text = text
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 64
	l.outline_size = 14
	l.modulate = col
	l.no_depth_test = true
	l.fixed_size = false
	l.pixel_size = 0.004 * scale_k
	_world(who).add_child(l)
	l.global_position = at
	l.scale = Vector3.ONE * 0.2
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * 1.15, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector3.ONE, 0.08)
	tw.parallel().tween_property(l, "global_position", at + Vector3.UP * 0.7, 1.1)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)


## 응가: 귀여운 똥 (눈 달림) + 주위를 도는 파리 두 마리. 10초 뒤 사라짐
static func _poop(who: Node3D) -> void:
	var root := Node3D.new()
	_world(who).add_child(root)
	root.global_position = who.global_position - _front(who) * 0.45
	root.look_at(root.global_position + _front(who), Vector3.UP)
	root.rotate_y(PI)  # 눈이 앞(카메라 쪽)을 보도록
	var brown := StandardMaterial3D.new()
	brown.albedo_color = Color(0.45, 0.27, 0.13)
	brown.roughness = 0.35
	var layers := [[0.0, 0.17, 0.13], [0.12, 0.13, 0.11], [0.22, 0.09, 0.09], [0.3, 0.045, 0.08]]
	for L in layers:
		var mi := MeshInstance3D.new()
		var sp := SphereMesh.new()
		sp.radius = L[1]
		sp.height = L[2] * 2.0
		mi.mesh = sp
		mi.material_override = brown
		mi.position = Vector3(0, 0.08 + L[0], 0)
		root.add_child(mi)
	var white := StandardMaterial3D.new()
	white.albedo_color = Color(1, 1, 1)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.05, 0.03, 0.05)
	for x in [-0.045, 0.045]:
		for pair in [[white, 0.028, 0.0], [black, 0.015, 0.012]]:
			var e := MeshInstance3D.new()
			var es := SphereMesh.new()
			es.radius = pair[1]
			es.height = pair[1] * 2.0
			e.mesh = es
			e.material_override = pair[0]
			e.position = Vector3(x, 0.24, -0.1 - pair[2])
			root.add_child(e)
	# 파리
	var orbit := Node3D.new()
	orbit.position.y = 0.45
	root.add_child(orbit)
	for k in 2:
		var fly := MeshInstance3D.new()
		var fs := SphereMesh.new()
		fs.radius = 0.018
		fs.height = 0.03
		fly.mesh = fs
		fly.material_override = black
		fly.position = Vector3(0.22 if k == 0 else -0.16, k * 0.08, 0.0)
		orbit.add_child(fly)
	var spin := orbit.create_tween().set_loops(25)
	spin.tween_property(orbit, "rotation:y", TAU, 0.45).from(0.0)
	root.scale = Vector3.ZERO
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3(1.25, 0.8, 1.25), 0.12)
	tw.tween_property(root, "scale", Vector3(0.9, 1.15, 0.9), 0.1)
	tw.tween_property(root, "scale", Vector3.ONE, 0.1)
	tw.tween_interval(10.0)
	tw.tween_property(root, "scale", Vector3.ZERO, 0.4)
	tw.tween_callback(root.queue_free)
	_pop_text(who, root.global_position + Vector3.UP * 0.5, "뿌직!", Color(0.9, 0.7, 0.4), 1.1)


## 디스코: 머리 위에 돌아가는 미러볼 + 색이 바뀌는 조명 (이모트가 끝나면 사라짐)
static func _disco(who: Node3D, id: String) -> void:
	var root := Node3D.new()
	root.set_meta("emote_fx", true)
	who.add_child(root)
	root.position = Vector3(0, 2.3, 0)
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.16
	sm.height = 0.32
	sm.radial_segments = 12
	sm.rings = 6
	ball.mesh = sm
	var mm := StandardMaterial3D.new()
	mm.albedo_color = Color(0.85, 0.85, 0.9)
	mm.metallic = 1.0
	mm.roughness = 0.05
	mm.emission_enabled = true
	mm.emission = Color(0.5, 0.5, 0.6)
	ball.material_override = mm
	root.add_child(ball)
	var string := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.005
	cm.bottom_radius = 0.005
	cm.height = 0.4
	string.mesh = cm
	string.position.y = 0.35
	root.add_child(string)
	var light := OmniLight3D.new()
	light.omni_range = 5.0
	light.light_energy = 1.6
	light.position.y = -0.3
	root.add_child(light)
	var cols := [Color(1, 0.2, 0.5), Color(0.2, 0.6, 1), Color(0.3, 1, 0.4), Color(1, 0.85, 0.2), Color(0.7, 0.3, 1)]
	var tw := root.create_tween().set_loops(26)
	for c in cols:
		tw.tween_callback(func(): light.light_color = c)
		tw.parallel().tween_property(root, "rotation:y", root.rotation.y + TAU / cols.size(), 0.25)
		tw.tween_interval(0.0)
	_say(who, "Let's dance!")
	who.get_tree().create_timer(6.4).timeout.connect(func():
		if is_instance_valid(root):
			root.queue_free())


## 트로트: 음표가 뿅뿅 떠오름
static func _note(who: Node3D) -> void:
	var cols := [Color(1.0, 0.5, 0.7), Color(1.0, 0.85, 0.3), Color(0.5, 0.9, 1.0)]
	_pop_text(who, who.global_position + Vector3(randf_range(-0.5, 0.5), 1.7, randf_range(-0.2, 0.2)), ["♪", "♫", "♬"][randi() % 3], cols[randi() % 3], 1.3)


## 닭 흉내: 하얀 깃털이 날림
static func _feathers(who: Node3D) -> void:
	var p := CPUParticles3D.new()
	_world(who).add_child(p)
	p.global_position = who.global_position + Vector3.UP * 0.9
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = 6
	p.lifetime = 1.6
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 1.0
	p.initial_velocity_max = 2.0
	p.gravity = Vector3(0, -1.2, 0)
	p.angular_velocity_min = -200
	p.angular_velocity_max = 200
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.14)
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.98, 0.97, 0.92)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	p.material_override = m
	p.emitting = true
	who.get_tree().create_timer(2.0).timeout.connect(p.queue_free)


## 머리 위를 도는 노란 별 4개 (이모트가 끝나면 사라짐)
static func _stars(who: Node3D) -> void:
	var orbit := Node3D.new()
	orbit.set_meta("emote_fx", true)
	who.add_child(orbit)
	orbit.position = Vector3(0, 1.85, 0)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.2)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.15)
	m.emission_energy_multiplier = 1.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	var star := _star_mesh()
	for k in 4:
		var a := k * TAU / 4.0
		var mi := MeshInstance3D.new()
		mi.mesh = star
		mi.material_override = m
		mi.position = Vector3(cos(a) * 0.38, sin(a * 2.0) * 0.04, sin(a) * 0.38)
		mi.scale = Vector3.ONE * 0.13
		orbit.add_child(mi)
	var tw := orbit.create_tween().set_loops(6)
	tw.tween_property(orbit, "rotation:y", TAU, 0.7).from(0.0)
	who.get_tree().create_timer(2.2).timeout.connect(func():
		if is_instance_valid(orbit):
			orbit.queue_free())


static var _star: ArrayMesh
static func _star_mesh() -> ArrayMesh:
	if _star:
		return _star
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts: Array[Vector3] = []
	for i in 10:
		var a := i * TAU / 10.0 - PI / 2.0
		var r := 1.0 if i % 2 == 0 else 0.45
		pts.append(Vector3(cos(a) * r, -sin(a) * r, 0))
	for i in 10:
		st.set_normal(Vector3.BACK)
		st.add_vertex(Vector3.ZERO)
		st.add_vertex(pts[i])
		st.add_vertex(pts[(i + 1) % 10])
	_star = st.commit()
	return _star
