extends Node3D
## 사나이 강펀치 이펙트
## - 에너지 주먹: models/fist.obj 모양에 "가장자리는 주황, 안쪽은 파랑"으로 빛나는 반투명 셰이더
##   (모델이 없으면 기본 도형 주먹으로 대신함). 주먹 마디가 앞(펀치 방향)을 향함
## - 주먹을 감싸고 휘몰아치는 금색·주황·붉은 빛줄기(꼬리가 흐려지는 호) + 주위 반짝이 가루
## - 주먹 앞쪽에 하얀 나선 소용돌이, 맞는 순간 충격파 + 불꽃
## - 사나이 발밑에 하얀 별 모양 폭발 + 불티
## 사용법: FistFx.spawn(사나이, 펀치 방향, 맞혔는지)

const ORANGE := Color(1.0, 0.5, 0.12)
const BLUE := Color(0.3, 0.55, 1.0)
const GOLD := Color(1.0, 0.68, 0.18)
const CRIMSON := Color(1.0, 0.2, 0.25)

var _mats: Array[StandardMaterial3D] = []
var _shader_mats: Array[ShaderMaterial] = []
var _fade := 1.0

const FIST_MODEL := "res://models/fist.obj"

## 에너지 주먹: 가장자리(옆으로 비스듬한 면)는 주황, 정면은 파랑. 빛이 더해지는 방식이라 반투명하게 빛남
const FIST_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, fog_disabled;
uniform vec3 rim_col = vec3(1.0, 0.5, 0.12);
uniform vec3 core_col = vec3(0.18, 0.42, 1.0);
uniform float fade = 1.0;
void fragment() {
	float f = 1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float rim = smoothstep(0.2, 0.9, f);
	vec3 c = mix(core_col * 0.32, rim_col * 1.1, rim);
	c += rim_col * pow(f, 5.0) * 0.9;
	ALBEDO = c * fade;
}
"""
## 주먹 안쪽 면: 은은한 주황 빛 (속이 차 있는 느낌)
const FIST_INNER_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_front, fog_disabled;
uniform float fade = 1.0;
void fragment() {
	float f = clamp(abs(dot(NORMAL, VIEW)), 0.0, 1.0);
	ALBEDO = vec3(1.0, 0.45, 0.1) * 0.12 * f * fade;
}
"""
## 빛줄기: UV.x 0(꼬리) → 1(머리)로 갈수록 진해지고, 폭 가운데가 가장 밝음
const ARC_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, fog_disabled;
uniform vec3 col = vec3(1.0, 0.72, 0.25);
uniform float fade = 1.0;
void fragment() {
	float edge = 1.0 - abs(UV.y * 2.0 - 1.0);
	float a = pow(UV.x, 1.6) * pow(edge, 1.4);
	ALBEDO = col * a * 1.3 * fade;
}
"""
## 나선 소용돌이 (원판 위에 도는 하얀 나선)
const VORTEX_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, fog_disabled;
uniform float fade = 1.0;
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float a = atan(p.y, p.x);
	float s = sin(a * 3.0 + log(r + 0.001) * 7.0 - TIME * 9.0);
	float band = smoothstep(0.45, 1.0, s);
	float mask = smoothstep(1.0, 0.7, r) * smoothstep(0.06, 0.3, r);
	vec3 c = mix(vec3(1.0, 0.78, 0.4), vec3(1.0, 0.97, 0.9), band);
	ALBEDO = c * band * mask * 0.75 * fade;
}
"""
var _rings: Array[Node3D] = []
var _ring_speed: Array[float] = []
var _fist: Node3D
var _light: OmniLight3D
var _age := 0.0
var _fading := false


static func spawn(who: Node3D, dir: Vector3, hit: bool) -> void:
	var fx := Node3D.new()
	fx.set_script(load("res://scripts/fist_fx.gd"))
	who.get_tree().current_scene.add_child(fx)
	fx.call("setup", who, dir, hit)


func setup(who: Node3D, dir: Vector3, hit: bool) -> void:
	dir.y = 0.0
	dir = dir.normalized()
	var length := GameConfig.num("brute", "punch_range", 3.0)
	var width := GameConfig.num("brute", "punch_width", 5.0)
	var right := Vector3(-dir.z, 0.0, dir.x)
	var hand := who.global_position + Vector3.UP * 1.25 + right * 0.4 + dir * 0.9
	var end := who.global_position + Vector3.UP * 1.4 + dir * (length * 0.5 + 0.9)
	global_position = hand
	look_at(hand + dir, Vector3.UP)  # -Z 가 펀치 방향

	_fist = Node3D.new()
	add_child(_fist)
	var model: Mesh = load(FIST_MODEL) if ResourceLoader.exists(FIST_MODEL) else null
	if model:
		_build_energy_fist(model)
	else:
		_build_fist()
	_build_arcs()
	_build_vortex()
	_build_sparkles()
	_light = OmniLight3D.new()
	_light.light_color = ORANGE
	_light.omni_range = 7.0
	_light.light_energy = 1.2
	_fist.add_child(_light)

	# 주먹이 손에서 앞으로 쭉 뻗어 나가며 커짐
	var visual := width * 0.46 / 1.2  # 주먹 모양 기본 폭 1.2m → 실제 약 2.3m (빛줄기까지 하면 폭 5m 가까이)
	_fist.scale = Vector3.ONE * 0.35
	var local_end := to_local(end)
	var tw := create_tween()
	tw.tween_property(_fist, "position", local_end, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(_fist, "scale", Vector3.ONE * visual, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(_impact.bind(end + dir * (length * 0.5), dir, hit))
	tw.tween_interval(0.3 if hit else 0.15)
	tw.tween_callback(func() -> void: _fading = true)
	tw.parallel().tween_method(_set_fade, 1.0, 0.0, 0.35)
	tw.tween_interval(0.35)
	tw.tween_callback(queue_free)

	_ground_burst(who.global_position + Vector3.UP * 0.05, dir)


func _set_fade(v: float) -> void:
	for m in _shader_mats:
		m.set_shader_parameter("fade", v)


func _shader_mat(code: String, params := {}) -> ShaderMaterial:
	var sh := Shader.new()
	sh.code = code
	var m := ShaderMaterial.new()
	m.shader = sh
	for k in params:
		m.set_shader_parameter(k, params[k])
	_shader_mats.append(m)
	return m


## models/fist.obj 로 만든 에너지 주먹 (바깥 면 + 안쪽 면 두 겹)
func _build_energy_fist(model: Mesh) -> void:
	var outer := _mesh(_fist, model, _shader_mat(FIST_SHADER), Vector3.ZERO)
	outer.material_override.next_pass = _shader_mat(FIST_INNER_SHADER)
	# 주먹 속의 뜨거운 주황 빛 덩어리
	var hot := _glow_mat(Color(1.0, 0.55, 0.15), 0.12, 0.6)
	_mesh(_fist, _sphere(0.28), hot, Vector3(0.05, 0.0, -0.1), Vector3.ZERO, Vector3(1.3, 0.8, 1.0))


## 리본 모양의 호(원의 일부). band = true 면 원통 띠, false 면 납작한 고리
func _arc_mesh(radius: float, width: float, arc: float, band: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := 40
	for i in seg:
		var ta := float(i) / seg
		var tb := float(i + 1) / seg
		var aa := arc * ta
		var ab := arc * tb
		var ca := Vector3(cos(aa), sin(aa), 0.0) * radius
		var cb := Vector3(cos(ab), sin(ab), 0.0) * radius
		var oa := Vector3(0, 0, width * 0.5) if band else Vector3(cos(aa), sin(aa), 0.0) * width * 0.5
		var ob := Vector3(0, 0, width * 0.5) if band else Vector3(cos(ab), sin(ab), 0.0) * width * 0.5
		var quad := [[ca - oa, Vector2(ta, 0)], [cb - ob, Vector2(tb, 0)], [cb + ob, Vector2(tb, 1)],
				[ca - oa, Vector2(ta, 0)], [cb + ob, Vector2(tb, 1)], [ca + oa, Vector2(ta, 1)]]
		for v in quad:
			st.set_uv(v[1])
			st.add_vertex(v[0])
	return st.commit()


## 주먹을 감싸고 휘몰아치는 빛줄기들 (각자 다른 기울기·속도로 돎)
func _build_arcs() -> void:
	var specs := [
		# 색, 반지름, 폭, 호 길이(라디안), 띠?, 도는 속도, 기울기, 앞뒤 위치
		[Color(1.0, 0.72, 0.25), 0.95, 0.07, 4.2, false, 7.0, Vector3(0.2, 0.15, 0), -0.25],
		[Color(1.0, 0.8, 0.4), 1.05, 0.16, 3.6, true, -8.5, Vector3(-0.3, 0.1, 0), -0.05],
		[Color(1.0, 0.55, 0.2), 0.85, 0.05, 5.0, false, 10.0, Vector3(0.1, -0.35, 0), -0.4],
		[Color(1.0, 0.25, 0.25), 1.0, 0.12, 3.0, true, -6.0, Vector3(0.45, -0.1, 0), 0.1],
		[Color(1.0, 0.85, 0.5), 1.18, 0.05, 4.6, false, 5.5, Vector3(-0.15, -0.2, 0), -0.15],
		[Color(1.0, 0.6, 0.25), 0.78, 0.1, 3.4, true, 12.0, Vector3(0.0, 0.4, 0), -0.3],
		[Color(1.0, 0.75, 0.35), 1.28, 0.04, 2.6, false, -9.0, Vector3(0.3, 0.3, 0), 0.0],
	]
	for sp in specs:
		var pivot := Node3D.new()
		pivot.rotation = sp[6]
		pivot.position.z = sp[7]
		_fist.add_child(pivot)
		var holder := Node3D.new()
		holder.rotation.z = randf() * TAU
		pivot.add_child(holder)
		_mesh(holder, _arc_mesh(sp[1], sp[2], sp[3], sp[4]), _shader_mat(ARC_SHADER, {"col": Vector3(sp[0].r, sp[0].g, sp[0].b)}), Vector3.ZERO)
		_rings.append(holder)
		_ring_speed.append(float(sp[5]))


## 주먹 바로 앞의 나선 소용돌이
func _build_vortex() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(2.4, 2.4)
	var v := _mesh(_fist, q, _shader_mat(VORTEX_SHADER), Vector3(0, 0, -0.75))
	_rings.append(v)
	_ring_speed.append(-3.0)


## 주먹 주위로 흩날리는 반짝이 가루
func _build_sparkles() -> void:
	var p := CPUParticles3D.new()
	_fist.add_child(p)
	p.amount = 140
	p.lifetime = 0.45
	p.local_coords = false
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE_SURFACE
	p.emission_sphere_radius = 1.0
	p.direction = Vector3(0, 0, 1)
	p.spread = 180.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 2.5
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.012
	p.scale_amount_max = 0.03
	p.mesh = _sphere(1.0)
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.6, 1.0))
	grad.set_color(1, Color(1.0, 0.4, 0.1, 0.0))
	p.color_ramp = grad
	p.material_override = _particle_mat(Color.WHITE)
	p.emitting = true


func _process(delta: float) -> void:
	_age += delta
	for i in _rings.size():
		_rings[i].rotate_object_local(Vector3.FORWARD, _ring_speed[i] * delta)
	if _fading:
		for m in _mats:
			m.albedo_color.a = maxf(0.0, m.albedo_color.a - delta * 2.8)
			m.emission_energy_multiplier = maxf(0.0, m.emission_energy_multiplier - delta * 8.0)
		_light.light_energy = maxf(0.0, _light.light_energy - delta * 10.0)


# ---------------------------------------------------------------- 주먹 모양 (기본 폭 약 1.2m, 앞 = -Z)

## add = 빛이 겹치면 더 밝아지는 방식 (고리·불꽃용). 주먹은 겹쳐도 하얗게 타지 않도록 일반 반투명
func _glow_mat(c: Color, alpha: float, energy: float, add := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.disable_fog = true  # 안개 색이 더해져서 네모난 자국이 생기지 않게
	if add:
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED if add else BaseMaterial3D.CULL_BACK
	m.no_depth_test = false
	_mats.append(m)
	return m


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = scl
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = 20
	s.rings = 10
	return s


func _capsule(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	return c


func _build_fist() -> void:
	var shell := _glow_mat(ORANGE, 0.55, 0.7, false)
	var core := _glow_mat(BLUE, 0.6, 0.8, false)
	var line := _glow_mat(Color(1.0, 0.8, 0.45), 0.8, 1.0, false)
	# 손등·손바닥 (안쪽 파란 빛 + 바깥 주황 껍질)
	_mesh(_fist, _sphere(0.5), core, Vector3(0, 0, 0.05), Vector3.ZERO, Vector3(0.95, 0.72, 0.8))
	_mesh(_fist, _sphere(0.5), shell, Vector3(0, 0, 0.05), Vector3.ZERO, Vector3(1.08, 0.82, 0.92))
	# 말아 쥔 손가락 4개 (앞쪽에 세로로 나란히) + 마디 혹
	for k in 4:
		var x := -0.36 + k * 0.24
		_mesh(_fist, _capsule(0.13, 0.5), shell, Vector3(x, 0.02, -0.36), Vector3(0.25, 0, 0))
		_mesh(_fist, _sphere(0.12), line, Vector3(x, 0.2, -0.44), Vector3.ZERO, Vector3(1, 0.9, 0.8))
		_mesh(_fist, _sphere(0.1), core, Vector3(x, -0.12, -0.46))
	# 엄지 (아래쪽을 가로질러 감쌈)
	_mesh(_fist, _capsule(0.12, 0.55), shell, Vector3(-0.08, -0.27, -0.3), Vector3(0, 0.3, PI / 2.0))
	# 손목 (뒤쪽, 점점 흐려짐)
	var wrist := CylinderMesh.new()
	wrist.top_radius = 0.24
	wrist.bottom_radius = 0.18
	wrist.height = 0.6
	_mesh(_fist, wrist, _glow_mat(ORANGE, 0.35, 0.6, false), Vector3(0, -0.04, 0.6), Vector3(PI / 2.0, 0, 0))


# ---------------------------------------------------------------- 맞는 순간: 앞쪽 소용돌이 + 불꽃

func _impact(pos: Vector3, dir: Vector3, hit: bool) -> void:
	var root := get_tree().current_scene
	var spot := Node3D.new()
	root.add_child(spot)
	spot.global_position = pos
	spot.look_at(pos + dir, Vector3.UP)
	# 하얀 소용돌이 충격파: 펼쳐지며 도는 고리 3개
	for k in 3:
		var pivot := Node3D.new()
		pivot.rotation.z = k * 0.9
		spot.add_child(pivot)
		var t := TorusMesh.new()
		t.inner_radius = 0.5 + k * 0.25
		t.outer_radius = 0.53 + k * 0.25
		t.rings = 40
		t.ring_segments = 6
		var m := _glow_mat(Color(1.0, 0.92, 0.8), 0.5, 1.2)
		_mesh(pivot, t, m, Vector3(0, 0, -k * 0.25), Vector3(PI / 2.0, 0, 0))
		var tw := pivot.create_tween().set_parallel(true)
		tw.tween_property(pivot, "scale", Vector3.ONE * (2.0 + k * 0.6), 0.45).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
		tw.tween_property(pivot, "rotation:z", pivot.rotation.z + (3.0 if k % 2 == 0 else -3.0), 0.45)
		tw.tween_property(m, "albedo_color:a", 0.0, 0.45)
	# 소용돌이 가루
	var swirl := CPUParticles3D.new()
	spot.add_child(swirl)
	swirl.one_shot = true
	swirl.explosiveness = 0.85
	swirl.amount = 90 if hit else 50
	swirl.lifetime = 0.55
	swirl.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	swirl.emission_ring_axis = Vector3(0, 0, 1)
	swirl.emission_ring_radius = 1.2
	swirl.emission_ring_inner_radius = 0.6
	swirl.emission_ring_height = 0.2
	swirl.direction = Vector3(0, 0, -1)
	swirl.spread = 30.0
	swirl.initial_velocity_min = 2.0
	swirl.initial_velocity_max = 6.0
	swirl.tangential_accel_min = 25.0
	swirl.tangential_accel_max = 40.0
	swirl.radial_accel_min = 4.0
	swirl.radial_accel_max = 8.0
	swirl.gravity = Vector3.ZERO
	swirl.scale_amount_min = 0.03
	swirl.scale_amount_max = 0.08
	swirl.mesh = _sphere(1.0)
	swirl.material_override = _particle_mat(Color(1.0, 0.92, 0.7))
	swirl.emitting = true
	# 앞으로 튀는 불꽃 (길쭉한 불티)
	_sparks(spot, Vector3(0, 0, -1), 80 if hit else 40, 60.0, 6.0, 16.0)
	var cleanup := get_tree().create_timer(1.5)
	cleanup.timeout.connect(spot.queue_free)


func _particle_mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.0
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.vertex_color_use_as_albedo = true
	m.disable_fog = true
	return m


func _sparks(parent: Node3D, direction: Vector3, amount: int, spread: float, vmin: float, vmax: float) -> void:
	var p := CPUParticles3D.new()
	parent.add_child(p)
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = amount
	p.lifetime = 0.6
	p.direction = direction
	p.spread = spread
	p.initial_velocity_min = vmin
	p.initial_velocity_max = vmax
	p.gravity = Vector3(0, -9.0, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	p.particle_flag_align_y = true  # 날아가는 방향으로 길쭉하게
	var streak := BoxMesh.new()
	streak.size = Vector3(0.025, 0.28, 0.025)
	p.mesh = streak
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.95, 0.7, 1.0))
	grad.set_color(1, Color(1.0, 0.45, 0.1, 0.0))
	p.color_ramp = grad
	p.material_override = _particle_mat(Color.WHITE)
	p.emitting = true


# ---------------------------------------------------------------- 발밑: 하얀 별 모양 폭발 + 불티

func _ground_burst(pos: Vector3, dir: Vector3) -> void:
	var root := get_tree().current_scene
	var spot := Node3D.new()
	root.add_child(spot)
	spot.global_position = pos
	spot.look_at(pos + dir, Vector3.UP)
	var m := _glow_mat(Color(0.85, 0.92, 1.0), 0.7, 1.4)
	for k in 7:
		var spike := PrismMesh.new()
		spike.size = Vector3(0.35, randf_range(0.9, 1.6), 0.02)
		var pivot := Node3D.new()
		pivot.rotation.y = TAU * k / 7.0 + randf_range(-0.2, 0.2)
		spot.add_child(pivot)
		# 바닥에 눕힌 뾰족한 삼각형이 바깥쪽을 향함
		_mesh(pivot, spike, m, Vector3(0, 0.02, -0.5), Vector3(-PI / 2.0, 0, 0))
	spot.scale = Vector3.ONE * 0.3
	var tw := spot.create_tween()
	tw.tween_property(spot, "scale", Vector3.ONE * 1.3, 0.18).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.4)
	tw.tween_callback(spot.queue_free)
	_sparks(spot, Vector3.UP, 30, 70.0, 3.0, 7.0)
