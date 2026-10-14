class_name GrassPatch
extends Area3D
## 풀숲: 키 큰 풀이 무성한 구역
## 생존자가 안에 들어가면 술래가 아주 가까이 와야만 볼 수 있어요.
## (풀 하나하나를 MultiMesh로 한꺼번에 그려서 수천 개도 가볍게 그립니다)

var grass_mesh: MultiMeshInstance3D


func setup(size: Vector2, rng: RandomNumberGenerator, density := 6.0) -> void:
	collision_layer = 0
	collision_mask = 1
	monitoring = true
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)

	# 들어왔는지 감지하는 영역
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(size.x, 2.0, size.y)
	shape.shape = box
	shape.position.y = 1.0
	add_child(shape)

	# 풀잎 모양: 가늘고 긴 삼각형. 뿌리는 어둡고 끝은 밝으며 바람에 살랑살랑 흔들림
	var blade := PrismMesh.new()
	blade.size = Vector3(0.1, 1.25, 0.02)
	var mat := ShaderMaterial.new()
	mat.shader = _grass_shader()
	blade.material = mat
	density *= 2.4  # 가늘어진 대신 더 빽빽하게

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = blade
	mm.instance_count = int(size.x * size.y * density)
	for i in mm.instance_count:
		var h := rng.randf_range(0.7, 1.35)
		var basis := Basis(Vector3.UP, rng.randf() * TAU)
		basis = basis.rotated(basis.x, rng.randf_range(-0.25, 0.25))  # 살짝 기울어짐
		basis = basis.scaled(Vector3(1.0, h, 1.0))
		var origin := Vector3(rng.randf_range(-size.x, size.x) * 0.5, 0.62 * h, rng.randf_range(-size.y, size.y) * 0.5)
		mm.set_instance_transform(i, Transform3D(basis, origin))
		var g := rng.randf_range(0.28, 0.5)
		mm.set_instance_color(i, Color(g * 0.55, g, g * 0.3))

	grass_mesh = MultiMeshInstance3D.new()
	grass_mesh.multimesh = mm
	add_child(grass_mesh)


static var _shader: Shader
static func _grass_shader() -> Shader:
	if _shader:
		return _shader
	_shader = Shader.new()
	_shader.code = """
shader_type spatial;
render_mode cull_disabled;
varying float h;
varying vec3 tint;
void vertex() {
	h = VERTEX.y + 0.5;  // 0 = 뿌리, 1 = 끝
	tint = COLOR.rgb;
	vec3 wp = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float sway = sin(TIME * 1.7 + wp.x * 0.6 + wp.z * 0.4) * 0.07 + sin(TIME * 3.1 + wp.z) * 0.02;
	VERTEX.x += sway * h * h;
}
void fragment() {
	ALBEDO = tint * mix(0.35, 1.15, h);
	ROUGHNESS = 0.9;
	BACKLIGHT = tint * 0.3;
}
"""
	return _shader


func _on_body_entered(body: Node3D) -> void:
	if body is Survivor:
		(body as Survivor).grass_count += 1


func _on_body_exited(body: Node3D) -> void:
	if body is Survivor:
		(body as Survivor).grass_count = max(0, (body as Survivor).grass_count - 1)
