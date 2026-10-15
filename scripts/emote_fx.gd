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
		_:
			_spawn2(who, id)


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
	var tw := orbit.create_tween().set_loops(4)
	tw.tween_property(orbit, "rotation:y", TAU, 0.7).from(0.0)
	# 사라지는 것도 별 자신의 트윈으로 (이모트를 일찍 멈춰서 먼저 지워져도 오류 없음)
	var life := orbit.create_tween()
	life.tween_interval(2.0)
	life.tween_property(orbit, "scale", Vector3.ZERO, 0.2)
	life.tween_callback(orbit.queue_free)


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


# ---------------------------------------------------------------- 추가 이모트 (귀여운 / 저질 / 웃긴)

const PINK := Color(1.0, 0.45, 0.7)
const GOLD := Color(1.0, 0.85, 0.3)
const SKY := Color(0.55, 0.85, 1.0)
const STINK := Color(0.65, 0.85, 0.25)
const DUST := Color(0.75, 0.68, 0.55)

static func _spawn2(who: Node3D, id: String) -> void:
	match id:
		# 귀여운
		"heart_hands":
			_later(who, id, 0.4, func(): _pop_at(who, Vector3(0, 2.0, 0.1), "♥", PINK, 2.6))
			for k in 5:
				_later(who, id, 1.0 + k * 0.4, func(): _pop_at(who, Vector3(randf_range(-0.45, 0.45), 1.5, 0.45), "♥", PINK, 1.2))
		"wave_hi":
			_later(who, id, 0.25, func(): _pop_at(who, Vector3(0.5, 1.95, 0.1), "Hi!", GOLD, 1.5))
			_later(who, id, 1.3, func(): _pop_at(who, Vector3(0.6, 1.8, 0.1), "♪", SKY, 1.2))
		"bunny_hop":
			for k in 6:
				_later(who, id, 0.4 + k * 0.45, func(): _pop_at(who, Vector3(randf_range(-0.4, 0.4), 1.9, 0.1), "♪" if k % 2 == 0 else "♥", PINK if k % 2 else SKY, 1.1))
		"shy":
			_later(who, id, 0.6, func(): _pop_at(who, Vector3(0.35, 1.55, 0.35), "///", Color(1.0, 0.4, 0.5), 1.3))
			_later(who, id, 1.8, func(): _pop_at(who, Vector3(-0.3, 1.8, 0.2), "♥", PINK, 1.2))
		"clap":
			for k in 5:
				_later(who, id, 0.25 + k * 0.5, func(): _pop_at(who, Vector3(randf_range(-0.3, 0.3), 1.0 + randf() * 0.3, 0.6), "★", GOLD, 0.9))
		"aegyo":
			for k in 4:
				_later(who, id, 0.4 + k * 0.75, func(): _pop_at(who, Vector3(0.45 if k % 2 == 0 else -0.45, 1.6, 0.3), "♥", PINK, 1.3))
		"twirl":
			for k in 8:
				_later(who, id, 0.4 + k * 0.33, func():
					var a := randf() * TAU
					_pop_at(who, Vector3(cos(a) * 0.55, 0.9 + randf() * 0.9, sin(a) * 0.55), "★" if k % 3 else "♪", [GOLD, PINK, SKY][k % 3], 0.9))
		"kiss_blow":
			_later(who, id, 0.55, func(): _pop_at(who, Vector3(0.3, 1.5, 0.45), "♥", PINK, 0.8))
			_later(who, id, 1.1, func(): _fly_heart(who))
		"cheer":
			for k in 8:
				_later(who, id, 0.2 + k * 0.425, func(): _pop_at(who, Vector3(randf_range(-0.6, 0.6), 1.7 + randf() * 0.4, 0.1), "★" if k % 2 == 0 else "!", [GOLD, PINK, SKY][k % 3], 1.1))
		"sleepy_nap":
			var zs := [[0.3, "z", 0.8], [0.7, "Z", 1.1], [1.0, "z", 0.8], [1.25, "!", 1.4], [1.7, "z", 0.8], [2.1, "Z", 1.1], [2.65, "!", 1.4], [3.0, "z", 0.8], [3.3, "Z", 1.2]]
			for z in zs:
				var col := Color(1.0, 0.85, 0.3) if z[1] == "!" else SKY
				_later(who, id, z[0], func(): _pop_at(who, Vector3(0.35, 1.75, 0.2), z[1], col, z[2]))
		# 저질
		"nose_pick":
			_later(who, id, 1.8, func(): _pop_at(who, Vector3(0.0, 1.95, 0.2), "?", GOLD, 1.3))
			_later(who, id, 2.56, func(): _booger(who))
		"butt_slap":
			for k in 6:
				_later(who, id, 0.4 + k * 0.4, func(): _pop_text(who, _butt(who) + Vector3.UP * 0.25 + _front(who).cross(Vector3.UP) * (0.4 if k % 2 == 0 else -0.4), "★" if k % 2 == 0 else "♪", GOLD if k % 2 == 0 else PINK, 0.9))
		"burp":
			_later(who, id, 0.72, func():
				var mouth := _local(who, Vector3(0, 1.15, 0.45))
				_puff(who, mouth, _front(who) + Vector3.UP * 0.3, Color(0.7, 0.85, 0.35), 14, 1.4, 0.3)
				_pop_text(who, mouth + Vector3.UP * 0.4, "BURP!", Color(0.75, 1.0, 0.3), 1.5))
		"armpit_fart":
			var times := [0.58, 0.92, 1.25, 1.58, 1.92, 2.25, 2.58]
			for k in times.size():
				_later(who, id, times[k], func():
					var pit := _local(who, Vector3(0.38, 0.8, 0.08))
					_puff(who, pit, (pit - who.global_position - Vector3.UP * 0.8).normalized() + Vector3.UP * 0.3, STINK, 6, 0.8, 0.18)
					if k == 6:
						_pop_text(who, pit + Vector3.UP * 0.5, "뿌웅~", Color(0.75, 1.0, 0.3), 1.3)
					elif k % 2 == 1:
						_pop_text(who, pit + Vector3.UP * 0.35, "뿡", Color(0.75, 1.0, 0.3), 0.8))
		"butt_scoot":
			for k in 8:
				_later(who, id, 0.45 + k * 0.33, func(): _puff(who, who.global_position + Vector3.UP * 0.08 - _front(who) * 0.2, Vector3.UP, DUST, 5, 0.6, 0.15))
			_later(who, id, 1.2, func(): _pop_text(who, who.global_position + Vector3.UP * 1.4, "♪", PINK, 1.1))
		"dog_pee":
			_later(who, id, 1.05, func(): _puddle(who))
			_later(who, id, 1.3, func(): _pop_text(who, who.global_position + Vector3.UP * 1.2, "~♪", SKY, 1.1))
		"tongue":
			_later(who, id, 0.4, func(): _pop_at(who, Vector3(0.4, 1.8, 0.2), ":P", PINK, 1.4))
			_later(who, id, 1.4, func(): _pop_at(who, Vector3(-0.4, 1.8, 0.2), ":P", PINK, 1.1))
		"sniff_pits":
			for k in 3:
				_later(who, id, 0.5 + k * 0.35, func(): _puff(who, _local(who, Vector3(0.42, 0.85, 0.0)), Vector3.UP, STINK, 4, 0.5, 0.15))
			_later(who, id, 1.5, func():
				_puff(who, _local(who, Vector3(0.42, 0.85, 0.0)), Vector3.UP, STINK, 12, 1.0, 0.3)
				_pop_at(who, Vector3(0, 2.0, 0.2), "!!", Color(1.0, 0.5, 0.3), 1.6)
				_pop_at(who, Vector3(0.5, 1.5, 0.0), "~~", STINK, 1.3))
		"rocket_fart":
			_later(who, id, 0.3, func(): _pop_text(who, who.global_position + Vector3.UP * 1.6, "...!", Color(1.0, 0.6, 0.4), 1.0))
			_later(who, id, 0.9, func(): _gas(who, _butt(who), 1.6, "뿌아앙!!"))
			for k in 3:
				_later(who, id, 1.0 + k * 0.12, func(): _puff(who, who.global_position + Vector3.UP * 0.2, Vector3.DOWN, STINK, 8, 1.0, 0.3))
			_later(who, id, 1.9, func(): _puff(who, who.global_position + Vector3.UP * 0.05, Vector3.UP, DUST, 12, 1.4, 0.2))
		"butt_scratch":
			_later(who, id, 1.2, func(): _pop_text(who, _butt(who) + Vector3.UP * 1.3, "♪", GOLD, 1.1))
			_later(who, id, 2.0, func(): _pop_text(who, who.global_position + Vector3.UP * 1.9, "~♪", SKY, 1.2))
		# 웃긴
		"floss":
			for k in 8:
				_later(who, id, 0.2 + k * 0.48, func(): _note(who))
		"worm":
			for k in 5:
				_later(who, id, 0.6 + k * 0.55, func():
					_note(who)
					_puff(who, who.global_position + Vector3.UP * 0.05 + _front(who) * 0.2, Vector3.UP, DUST, 4, 0.5, 0.15))
		"flex":
			for k in 3:
				for j in 3:
					_later(who, id, 0.12 + k * 1.0 + j * 0.08, func(): _pop_at(who, Vector3(randf_range(-0.7, 0.7), 0.9 + randf() * 0.8, 0.4), "★", GOLD, 0.9 + randf() * 0.5))
		"slip":
			_banana(who)
			_later(who, id, 0.4, func(): _pop_text(who, who.global_position + Vector3.UP * 2.0, "!?", Color(1.0, 0.85, 0.3), 1.5))
			_later(who, id, 0.85, func(): _stars_at(who, 0.85, -1.25))
		"headbang":
			for k in 3:
				_later(who, id, 0.3 + k * 1.2, func(): _pop_at(who, Vector3(randf_range(-0.5, 0.5), 2.0, 0.1), "\\m/", Color(1.0, 0.35, 0.3), 1.4))
			for k in 6:
				_later(who, id, 0.6 + k * 0.5, func(): _note(who))
		"moonwalk":
			for k in 5:
				_later(who, id, 0.3 + k * 0.6, func(): _note(who))
			_later(who, id, 3.1, func(): _pop_at(who, Vector3(0.4, 2.0, 0.1), "Hee-hee!", GOLD, 1.4))
		"sneeze":
			_later(who, id, 0.2, func(): _pop_at(who, Vector3(0.3, 1.8, 0.2), "a...", Color(1, 1, 1), 0.8))
			_later(who, id, 0.65, func(): _pop_at(who, Vector3(-0.3, 1.9, 0.2), "a..!", Color(1, 1, 1), 1.0))
			_later(who, id, 1.0, func(): _pop_at(who, Vector3(0.2, 2.0, 0.2), "A...!!", Color(1, 1, 1), 1.2))
			_later(who, id, 1.25, func():
				var nose := _local(who, Vector3(0, 1.1, 0.6))
				_puff(who, nose, _front(who) + Vector3.DOWN * 0.15, Color(0.9, 0.95, 1.0), 26, 3.0, 0.12, 0.9)
				_pop_text(who, nose + Vector3.UP * 0.5, "ACHOO!", Color(1.0, 1.0, 1.0), 1.8))
		"facepalm":
			_later(who, id, 0.5, func(): _pop_at(who, Vector3(0.35, 1.9, 0.1), "...", Color(0.8, 0.8, 0.85), 1.4))
			_later(who, id, 1.8, func(): _pop_at(who, Vector3(-0.35, 1.8, 0.1), "-_-;", Color(0.8, 0.8, 0.85), 1.2))
		"tantrum":
			var angry := ["#@!", "!!", "#!", "@#$!", "!!"]
			for k in angry.size():
				_later(who, id, 0.5 + k * 0.6, func():
					_pop_text(who, who.global_position + Vector3(randf_range(-0.5, 0.5), 1.0, 0) - _front(who) * 0.6, angry[k], Color(1.0, 0.35, 0.3), 1.2)
					_puff(who, who.global_position + Vector3.UP * 0.05, Vector3.UP, DUST, 5, 0.8, 0.15))
		"air_guitar":
			for k in 8:
				_later(who, id, 0.3 + k * 0.4, func(): _note(who))
			_later(who, id, 3.1, func(): _pop_at(who, Vector3(0, 2.1, 0.1), "\\m/", Color(1.0, 0.35, 0.3), 1.8))
			_later(who, id, 3.6, func(): _pop_at(who, Vector3(0.5, 1.8, 0.1), "★", GOLD, 1.6))


## 몸 기준 위치에 글자 팝업
static func _pop_at(who: Node3D, p: Vector3, text: String, col: Color, k: float) -> void:
	_pop_text(who, _local(who, p), text, col, k)


## 뭉게뭉게 퍼지는 작은 구름 (트림, 재채기, 먼지, 냄새)
static func _puff(who: Node3D, at: Vector3, dir: Vector3, col: Color, amount: int, speed: float, size: float, life := 1.4) -> void:
	var p := CPUParticles3D.new()
	_world(who).add_child(p)
	p.global_position = at
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = maxi(2, amount)
	p.lifetime = life
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.05
	p.direction = dir.normalized() if dir.length() > 0.01 else Vector3.UP
	p.spread = 30.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.damping_min = speed * 0.8
	p.damping_max = speed * 1.4
	p.gravity = Vector3(0, 0.2, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(0.3, 1.0))
	curve.add_point(Vector2(1, 1.3))
	p.scale_amount_curve = curve
	p.scale_amount_min = size * 0.7
	p.scale_amount_max = size
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
	p.material_override = m
	var grad := Gradient.new()
	grad.set_color(0, Color(col.r, col.g, col.b, 0.75))
	grad.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = grad
	p.emitting = true
	who.get_tree().create_timer(life + 0.6).timeout.connect(p.queue_free)


## 손 키스: 큰 하트가 앞으로 둥실 날아감
static func _fly_heart(who: Node3D) -> void:
	var l := Label3D.new()
	l.text = "♥"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 64
	l.outline_size = 14
	l.modulate = PINK
	l.no_depth_test = true
	l.pixel_size = 0.0075
	_world(who).add_child(l)
	var from := _local(who, Vector3(0.25, 1.3, 0.5))
	var to := from + _front(who) * 2.6 + Vector3.UP * 0.6
	l.global_position = from
	l.scale = Vector3.ONE * 0.3
	var tw := l.create_tween()
	tw.tween_property(l, "scale", Vector3.ONE * 1.2, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "global_position", to, 1.2).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "scale", Vector3.ONE * 1.8, 0.2)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.2)
	tw.tween_callback(l.queue_free)


## 코딱지: 초록 공이 포물선으로 날아가 바닥에 철퍽
static func _booger(who: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.045
	s.height = 0.09
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.75, 0.15)
	m.roughness = 0.2
	m.emission_enabled = true
	m.emission = Color(0.3, 0.55, 0.05)
	m.emission_energy_multiplier = 0.4
	mi.material_override = m
	_world(who).add_child(mi)
	var from := _local(who, Vector3(0.25, 1.15, 0.55))
	var vel := _front(who) * 2.2 + Vector3.UP * 2.0
	var ground := who.global_position.y + 0.03
	# 바닥에 닿는 시간 (y = from.y + vy*t - 4.9 t^2 = ground)
	var dy := from.y - ground
	var tland := (vel.y + sqrt(vel.y * vel.y + 2.0 * 9.8 * maxf(0.0, dy))) / 9.8
	mi.global_position = from
	var tw := mi.create_tween()
	tw.tween_method(func(tt: float):
		mi.global_position = from + vel * tt + Vector3.DOWN * 4.9 * tt * tt, 0.0, tland, tland)
	tw.tween_property(mi, "scale", Vector3(1.8, 0.3, 1.8), 0.08)
	tw.tween_interval(1.5)
	tw.tween_property(mi, "scale", Vector3.ZERO, 0.4)
	tw.tween_callback(mi.queue_free)
	_pop_text(who, from + Vector3.UP * 0.2, "!", Color(0.6, 1.0, 0.3), 1.0)


## 바나나 껍질: 발 앞에 놓였다가 몇 초 뒤 사라짐
static func _banana(who: Node3D) -> void:
	var root := Node3D.new()
	_world(who).add_child(root)
	root.global_position = who.global_position + _front(who) * 0.28 + Vector3.UP * 0.04
	root.look_at(root.global_position + _front(who), Vector3.UP)
	var yellow := StandardMaterial3D.new()
	yellow.albedo_color = Color(1.0, 0.86, 0.2)
	yellow.roughness = 0.45
	var brown := StandardMaterial3D.new()
	brown.albedo_color = Color(0.35, 0.22, 0.08)
	# 가운데 + 벌어진 껍질 3장
	for k in 4:
		var mi := MeshInstance3D.new()
		var c := CapsuleMesh.new()
		c.radius = 0.035 if k == 0 else 0.028
		c.height = 0.2 if k == 0 else 0.16
		mi.mesh = c
		mi.material_override = yellow
		if k == 0:
			mi.rotation = Vector3(PI / 2.0, 0.0, 0.0)
		else:
			var a := k * TAU / 3.0
			mi.position = Vector3(cos(a) * 0.07, -0.01, sin(a) * 0.07)
			mi.rotation = Vector3(0.0, -a, PI / 2.0 - 0.25)
		root.add_child(mi)
	var tip := MeshInstance3D.new()
	var ts := SphereMesh.new()
	ts.radius = 0.02
	ts.height = 0.04
	tip.mesh = ts
	tip.material_override = brown
	tip.position = Vector3(0, 0, -0.11)
	root.add_child(tip)
	root.scale = Vector3.ZERO
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE * 1.4, 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.3)
	# 밟히면 뒤로 쭉 미끄러짐
	tw.tween_property(root, "global_position", root.global_position + _front(who) * 0.25, 0.25)
	tw.tween_interval(2.4)
	tw.tween_property(root, "scale", Vector3.ZERO, 0.3)
	tw.tween_callback(root.queue_free)


## 강아지 쉬야: 노란 물웅덩이가 번졌다가 사라짐 (만화풍)
static func _puddle(who: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var c := CylinderMesh.new()
	c.top_radius = 0.22
	c.bottom_radius = 0.22
	c.height = 0.01
	c.radial_segments = 20
	mi.mesh = c
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.92, 0.3, 0.75)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	m.metallic_specular = 1.0
	mi.material_override = m
	_world(who).add_child(mi)
	var right := _front(who).cross(Vector3.UP)
	mi.global_position = who.global_position + Vector3.UP * 0.012 - right * 0.3 - _front(who) * 0.3
	mi.scale = Vector3(0.1, 1.0, 0.1)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(1.0, 1.0, 0.8), 1.2)
	tw.tween_interval(1.5)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.0)
	tw.tween_callback(mi.queue_free)


## 별 4개를 원하는 곳(누운 머리 위 등)에 띄움: 높이 up, 몸 앞쪽으로 ahead 만큼
## (이모트가 끝나 clear 로 먼저 지워져도 괜찮도록 타이머 대신 트윈으로 사라짐)
static func _stars_at(who: Node3D, up: float, ahead: float) -> void:
	var orbit := Node3D.new()
	orbit.set_meta("emote_fx", true)
	who.add_child(orbit)
	orbit.global_position = who.global_position + Vector3.UP * up + _front(who) * ahead
	orbit.scale = Vector3.ONE * 0.8
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.85, 0.2)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.8, 0.15)
	m.emission_energy_multiplier = 1.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in 4:
		var a := k * TAU / 4.0
		var mi := MeshInstance3D.new()
		mi.mesh = _star_mesh()
		mi.material_override = m
		mi.position = Vector3(cos(a) * 0.38, sin(a * 2.0) * 0.04, sin(a) * 0.38)
		mi.scale = Vector3.ONE * 0.13
		orbit.add_child(mi)
	var spin := orbit.create_tween().set_loops(3)
	spin.tween_property(orbit, "rotation:y", TAU, 0.7).from(0.0)
	var life := orbit.create_tween()
	life.tween_interval(1.9)
	life.tween_property(orbit, "scale", Vector3.ZERO, 0.2)
	life.tween_callback(orbit.queue_free)
