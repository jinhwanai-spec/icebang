extends RefCounted
## 얼음 연출: 울퉁불퉁한 얼음 덩어리 + 서리 낀 얼음 셰이더(땡 받는 동안 금이 점점 감)
## 얼 때: 얼음이 뿅 하고 차오르며 서리 가루가 퍼짐
## 땡 받을 때: 금이 쩍 가다가 와장창 깨지며 조각이 튀고, 물방울·김이 남음

const ICE_SHADER := """
shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, diffuse_burley, specular_schlick_ggx;
uniform float crack = 0.0;       // 0 = 멀쩡, 1 = 곧 깨짐
uniform float melt = 0.0;        // 녹는 정도 (투명해짐)
uniform sampler2D noise_tex;
varying vec3 lp;
void vertex() { lp = VERTEX; }
float cracks(vec3 p) {
	// 보로노이 비슷한 날카로운 금 무늬
	vec2 uv = p.xy * 2.3 + p.z * 1.7;
	float n1 = texture(noise_tex, uv * 0.5).r;
	float n2 = texture(noise_tex, uv * 0.5 + vec2(0.37, 0.71)).r;
	float l1 = 1.0 - smoothstep(0.0, 0.05, abs(n1 - 0.5));
	float l2 = 1.0 - smoothstep(0.0, 0.04, abs(n2 - 0.5));
	return max(l1, l2 * step(0.45, crack));
}
void fragment() {
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float inner = texture(noise_tex, lp.xy * 0.9 + lp.z * 0.6).r;
	vec3 deep = vec3(0.32, 0.62, 0.9);
	vec3 frost = vec3(0.86, 0.95, 1.0);
	vec3 c = mix(deep, frost, fres * 0.8 + inner * 0.25);
	float cr = cracks(lp) * smoothstep(0.02, 0.25, crack);
	c = mix(c, vec3(1.0), cr * 0.9);
	ALBEDO = c;
	ALPHA = clamp(0.38 + fres * 0.45 + cr * 0.4 - melt * 0.3, 0.0, 0.95);
	ROUGHNESS = 0.05 + inner * 0.12;
	METALLIC = 0.0;
	SPECULAR = 0.9;
	EMISSION = frost * (fres * 0.18 + cr * 0.5);
	RIM = 0.6;
	RIM_TINT = 0.2;
}
"""

static var _shader: Shader
static var _noise: NoiseTexture2D
static var _chunk: ArrayMesh
static var _shard: ArrayMesh


static func material() -> ShaderMaterial:
	if _shader == null:
		_shader = Shader.new()
		_shader.code = ICE_SHADER
		var n := FastNoiseLite.new()
		n.noise_type = FastNoiseLite.TYPE_CELLULAR
		n.cellular_return_type = FastNoiseLite.RETURN_DISTANCE2_SUB
		n.frequency = 0.03
		_noise = NoiseTexture2D.new()
		_noise.width = 256
		_noise.height = 256
		_noise.seamless = true
		_noise.noise = n
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("noise_tex", _noise)
	return m


## 각진 얼음 덩어리 (구를 울퉁불퉁하게 깎아 면이 보이게)
static func chunk_mesh() -> ArrayMesh:
	if _chunk:
		return _chunk
	var base := SphereMesh.new()
	base.radius = 0.74
	base.height = 1.95
	base.radial_segments = 11
	base.rings = 7
	var arrays := base.get_mesh_arrays()
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var n := FastNoiseLite.new()
	n.seed = 7
	n.frequency = 1.6
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var moved := PackedVector3Array()
	for v in verts:
		var k := 1.0 + n.get_noise_3dv(v) * 0.22
		moved.append(Vector3(v.x * k, v.y * (0.96 + n.get_noise_3dv(v * 1.7) * 0.08), v.z * k))
	for i in range(0, idx.size(), 3):
		var a := moved[idx[i]]
		var b := moved[idx[i + 1]]
		var c := moved[idx[i + 2]]
		var nrm := (b - a).cross(c - a).normalized() * -1.0
		for p in [a, b, c]:
			st.set_normal(nrm)  # 면마다 같은 방향 → 깎은 얼음처럼 반짝
			st.add_vertex(p)
	_chunk = st.commit()
	return _chunk


static func _shard_mesh() -> ArrayMesh:
	if _shard:
		return _shard
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tip := Vector3(0, 0.5, 0)
	var bot := Vector3(0, -0.35, 0)
	var ring := [Vector3(0.22, 0, 0.05), Vector3(-0.08, 0.05, 0.2), Vector3(-0.18, -0.02, -0.12), Vector3(0.1, 0.03, -0.18)]
	for i in 4:
		var a: Vector3 = ring[i]
		var b: Vector3 = ring[(i + 1) % 4]
		for tri in [[tip, b, a], [bot, a, b]]:
			var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
			for p in tri:
				st.set_normal(nrm)
				st.add_vertex(p)
	_shard = st.commit()
	return _shard


## 얼음이 차오르는 연출
static func form(who: Node3D, ice: MeshInstance3D) -> void:
	ice.scale = Vector3(0.4, 0.15, 0.4)
	var tw := ice.create_tween()
	tw.tween_property(ice, "scale", Vector3(1.1, 1.08, 1.1), 0.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(ice, "scale", Vector3.ONE, 0.12)
	_puff(who, who.global_position + Vector3.UP * 0.9, Color(0.85, 0.95, 1.0, 0.8), 18, 1.6)
	_flash(who, Color(0.6, 0.85, 1.0), 2.5)


## 와장창! 깨지는 연출 (조각 + 물방울 + 김)
static func shatter(who: Node3D, at: Vector3) -> void:
	var world := who.get_parent() if who.get_parent() else who
	var mat := material()
	mat.set_shader_parameter("crack", 1.0)
	var mesh := _shard_mesh()
	for i in 16:
		var s := MeshInstance3D.new()
		s.mesh = mesh
		s.material_override = mat
		world.add_child(s)
		var dir := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)).normalized()
		var start := at + Vector3(dir.x * 0.3, randf_range(0.1, 1.7), dir.z * 0.3)
		s.global_position = start
		s.scale = Vector3.ONE * randf_range(0.18, 0.42)
		s.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		var dist := randf_range(0.8, 2.2)
		var up := randf_range(0.6, 1.6)
		var land := Vector3(start.x + dir.x * dist, at.y + 0.05, start.z + dir.z * dist)
		var spin := Vector3(randf_range(-9, 9), randf_range(-9, 9), randf_range(-9, 9))
		var r0 := s.rotation
		var dur := randf_range(0.45, 0.7)
		var arc := func(k: float) -> void:
			if is_instance_valid(s):
				s.global_position = start.lerp(land, k) + Vector3.UP * sin(k * PI) * up * (1.0 - k * 0.3)
				s.rotation = r0 + spin * k * dur
		var tw := s.create_tween()
		tw.tween_method(arc, 0.0, 1.0, dur)
		tw.tween_interval(randf_range(0.6, 1.2))
		tw.tween_property(s, "scale", Vector3.ZERO, 0.5)  # 녹아 없어짐
		tw.tween_callback(s.queue_free)
	_puff(who, at + Vector3.UP * 0.9, Color(0.9, 0.97, 1.0, 0.6), 22, 2.4)
	_drops(who, at + Vector3.UP * 1.0)
	_flash(who, Color(0.75, 0.92, 1.0), 4.0)


static func _flash(who: Node3D, col: Color, energy: float) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.omni_range = 4.0
	l.light_energy = energy
	l.position = Vector3(0, 1.0, 0)
	who.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "light_energy", 0.0, 0.5)
	tw.tween_callback(l.queue_free)


static func _puff(who: Node3D, at: Vector3, col: Color, amount: int, speed: float) -> void:
	var world := who.get_parent() if who.get_parent() else who
	var p := CPUParticles3D.new()
	world.add_child(p)
	p.global_position = at
	p.one_shot = true
	p.explosiveness = 0.9
	p.amount = amount
	p.lifetime = 1.3
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.gravity = Vector3(0, 0.3, 0)
	var curve := Curve.new()
	curve.add_point(Vector2(0, 0.4))
	curve.add_point(Vector2(1, 1.4))
	p.scale_amount_curve = curve
	p.scale_amount_min = 0.12
	p.scale_amount_max = 0.25
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 8
	sm.rings = 4
	p.mesh = sm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	p.material_override = m
	var g := Gradient.new()
	g.set_color(0, col)
	g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	p.color_ramp = g
	p.emitting = true
	who.get_tree().create_timer(1.6).timeout.connect(p.queue_free)


static func _drops(who: Node3D, at: Vector3) -> void:
	var world := who.get_parent() if who.get_parent() else who
	var p := CPUParticles3D.new()
	world.add_child(p)
	p.global_position = at
	p.one_shot = true
	p.explosiveness = 0.8
	p.amount = 26
	p.lifetime = 0.9
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.0
	p.gravity = Vector3(0, -12, 0)
	p.scale_amount_min = 0.025
	p.scale_amount_max = 0.05
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 6
	sm.rings = 3
	p.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.9, 1.0, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.05
	p.material_override = m
	p.emitting = true
	who.get_tree().create_timer(1.2).timeout.connect(p.queue_free)
