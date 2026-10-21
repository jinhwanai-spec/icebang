class_name Generator
extends StaticBody3D
## 미션: 봉인석
## 근처에서 E를 누르고 있으면(봇은 도착하면 자동) 가동 게이지가 찹니다.
## 가동하는 동안 주기적으로 소리가 나서 술래가 찾아올 수 있어요!
## 봉인석을 정해진 개수만큼 가동하면 술래가 봉인되고 스테이지 클리어.

signal mission_completed(generator: Generator)

var progress := 0.0   # 0.0 ~ 1.0
var completed := false

var _noise_timer := 0.0

@onready var crystal: MeshInstance3D = $Crystal
@onready var progress_label: Label3D = $ProgressLabel
@onready var light: OmniLight3D = $Light

const SFX_COMPLETE := preload("res://audio/seal_complete.wav")
const SFX_STAGE_OK := preload("res://audio/ability.wav")
const SFX_STAGE_FAIL := preload("res://audio/mg_fail.wav")


var _pillar_mat: StandardMaterial3D
var _beam_mat: ShaderMaterial
var _rune_mat: StandardMaterial3D
var _small_crystals: Array[MeshInstance3D] = []

## 빛기둥: 가운데는 밝고 가장자리는 부드럽게 사라짐, 위로 갈수록 옅어지고 빛 줄무늬가 위로 흐름
const BEAM_SHADER := """
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_back, fog_disabled, shadows_disabled;
uniform vec3 col = vec3(0.55, 0.42, 1.0);
uniform float strength = 0.35;
varying float h;
void vertex() { h = VERTEX.y; }
void fragment() {
	float facing = clamp(dot(NORMAL, VIEW), 0.0, 1.0);
	float core = pow(facing, 2.5);
	float up = clamp(1.0 - (h + 30.0) / 60.0, 0.0, 1.0);
	float streak = 0.6 + 0.4 * sin(UV.x * 40.0 + sin(UV.x * 7.0) * 3.0) * sin(UV.y * 6.0 - TIME * 1.5);
	ALBEDO = col * core * (0.25 + up * up * 1.6) * streak * strength;
}
"""


func _ready() -> void:
	add_to_group("generator")
	light.omni_range = 7.0
	_build_rune_stone()
	_make_beam()
	_make_motes()
	_update_visual()
	_apply_reveal(0.0)


# ---------------------------------------------------------------- 가까이 가야 깨어나는 봉인석
# 멀리서는 어두운 돌비석일 뿐이라 안 보임. 가까이 가면(내 화면 기준) 룬·크리스탈·빛이 서서히 켜짐.
# 가동이 끝나면 초록 빛기둥이 솟고 주변이 환해짐 (완료한 곳은 멀리서도 보임)

## 깨어나기 시작하는 거리, 완전히 빛나는 거리 (balance.cfg [generator])
var _reveal := -1.0
var _motes: CPUParticles3D
var _beam: MeshInstance3D

func _process(delta: float) -> void:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var far := GameConfig.num("generator", "reveal_start", 16.0)
	var near := GameConfig.num("generator", "reveal_full", 7.0)
	var d := Vector2(cam.global_position.x - global_position.x, cam.global_position.z - global_position.z).length()
	var want := 1.0 if completed else clampf((far - d) / maxf(0.1, far - near), 0.0, 1.0)
	var r := move_toward(maxf(_reveal, 0.0), want, delta * 1.5)
	if absf(r - _reveal) > 0.002:
		_apply_reveal(r)


func _apply_reveal(r: float) -> void:
	_reveal = r
	var k := r * r * (3.0 - 2.0 * r)  # 부드럽게
	progress_label.visible = r > 0.35
	progress_label.modulate.a = clampf((r - 0.35) / 0.4, 0.0, 1.0)
	progress_label.outline_modulate.a = progress_label.modulate.a
	if _motes:
		_motes.emitting = r > 0.2
	if _beam:
		_beam.visible = completed
	light.visible = r > 0.01
	if completed:
		return
	light.light_energy = (1.0 + progress * 1.5) * k
	if _rune_mat:
		_rune_mat.emission_energy_multiplier = (0.8 + progress * 2.5) * k
	var cm := crystal.material_override as StandardMaterial3D
	if cm:
		cm.emission_energy_multiplier = 0.05 + 0.95 * k
		for c in _small_crystals:
			c.material_override = cm


## 가동 완료 순간: 빛이 확 퍼지면서 주변이 환해짐 + 바닥에 빛 고리 + 빛 가루 폭발
func _burst() -> void:
	var flash := OmniLight3D.new()
	flash.light_color = Color(0.45, 1.0, 0.7)
	flash.omni_range = 4.0
	flash.light_energy = 0.0
	flash.shadow_enabled = false
	flash.position.y = 2.0
	add_child(flash)
	var tw := flash.create_tween()
	tw.tween_property(flash, "light_energy", 9.0, 0.15)
	tw.parallel().tween_property(flash, "omni_range", 22.0, 0.5).set_ease(Tween.EASE_OUT)
	tw.tween_property(flash, "light_energy", 2.2, 1.6)
	tw.parallel().tween_property(flash, "omni_range", 13.0, 1.6)
	# 바닥으로 퍼지는 빛 고리
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.9
	tm.outer_radius = 1.0
	tm.rings = 48
	ring.mesh = tm
	var rm := StandardMaterial3D.new()
	rm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	rm.albedo_color = Color(0.5, 1.0, 0.75, 0.9)
	rm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	rm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	rm.disable_fog = true
	ring.material_override = rm
	ring.position.y = 0.1
	ring.scale = Vector3(1, 0.05, 1)
	add_child(ring)
	var rt := ring.create_tween()
	rt.tween_property(ring, "scale", Vector3(14, 0.05, 14), 1.2).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	rt.parallel().tween_property(rm, "albedo_color:a", 0.0, 1.2)
	rt.tween_callback(ring.queue_free)
	# 빛 가루 폭발
	var p := CPUParticles3D.new()
	add_child(p)
	p.position.y = 2.2
	p.one_shot = true
	p.explosiveness = 0.95
	p.amount = 70
	p.lifetime = 2.2
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	p.damping_min = 2.0
	p.damping_max = 3.0
	p.gravity = Vector3(0, -0.6, 0)
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.09
	var dot := SphereMesh.new()
	dot.radius = 1.0
	dot.height = 2.0
	dot.radial_segments = 6
	dot.rings = 3
	p.mesh = dot
	var pm := StandardMaterial3D.new()
	pm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pm.albedo_color = Color(0.6, 1.0, 0.75)
	pm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	pm.disable_fog = true
	p.material_override = pm
	p.emitting = true
	get_tree().create_timer(3.0).timeout.connect(p.queue_free)


## 봉인석 모양: 금빛 룬 문자가 새겨진 돌비석 + 꼭대기의 보라 크리스탈 + 발밑 돌무더기
func _build_rune_stone() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(global_position.x * 73.0 + global_position.z * 131.0)
	$Base.visible = false
	var stone := _rock_mat(Color(0.3, 0.3, 0.34), rng.randi())
	var mossy := _rock_mat(Color(0.2, 0.26, 0.17), rng.randi())
	var holder := Node3D.new()
	holder.rotation.y = rng.randf_range(-0.5, 0.5)
	add_child(holder)
	# 비석 몸통 (위로 갈수록 살짝 좁아짐) + 뾰족한 머리
	var slab := CylinderMesh.new()
	slab.top_radius = 0.42
	slab.bottom_radius = 0.55
	slab.height = 2.2
	slab.radial_segments = 4
	slab.rings = 1
	var body := _mesh(holder, slab, stone, Vector3(0, 1.1, 0))
	body.rotation.y = PI / 4.0
	body.scale = Vector3(1.0, 1.0, 0.75)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.05
	cap.bottom_radius = 0.42
	cap.height = 0.45
	cap.radial_segments = 4
	cap.rings = 1
	var head := _mesh(holder, cap, stone, Vector3(0, 2.42, 0))
	head.rotation.y = PI / 4.0
	head.scale = Vector3(1.0, 1.0, 0.75)
	# 이끼 낀 받침돌
	var plinth := CylinderMesh.new()
	plinth.top_radius = 0.75
	plinth.bottom_radius = 0.9
	plinth.height = 0.3
	plinth.radial_segments = 7
	_mesh(holder, plinth, mossy, Vector3(0, 0.15, 0))
	# 룬 문자 (앞뒤 4글자씩, 진행할수록 더 밝게)
	_rune_mat = StandardMaterial3D.new()
	_rune_mat.albedo_color = Color(1.0, 0.75, 0.35)
	_rune_mat.emission_enabled = true
	_rune_mat.emission = Color(1.0, 0.62, 0.2)
	_rune_mat.emission_energy_multiplier = 1.0
	# 네 면 모두에 룬 (비석이 위로 갈수록 좁아지므로 그 높이의 겉면에 붙임)
	for face in 4:
		var deep := 0.75 if face < 2 else 1.0  # 앞뒤 면은 납작하게 눌린 쪽
		for k in 4:
			var y := 0.55 + k * 0.42
			var r := lerpf(0.55, 0.42, y / 2.2) * 0.7071 * deep + 0.012
			var pivot := Node3D.new()
			pivot.rotation.y = [0.0, PI, PI / 2.0, -PI / 2.0][face]
			holder.add_child(pivot)
			_rune(pivot, Vector3(0, y, r), 1.0, rng)
	# 꼭대기 크리스탈 (원래 Crystal 노드를 옮김) + 작은 크리스탈 2개
	crystal.position = Vector3(0, 2.95, 0)
	crystal.scale = Vector3(0.55, 0.9, 0.55)
	crystal.rotation = Vector3(0, rng.randf() * TAU, 0.08)
	for k in 2:
		var c := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(0.18, 0.4, 0.18)
		c.mesh = pm
		c.position = Vector3(0.22 * (1 - k * 2), 2.62, 0.05)
		c.rotation.z = 0.5 * (1 - k * 2)
		holder.add_child(c)
		_small_crystals.append(c)
	# 발밑 돌무더기
	for k in 6:
		var a := TAU * k / 6.0 + rng.randf_range(-0.3, 0.3)
		var r := SphereMesh.new()
		r.radius = rng.randf_range(0.12, 0.26)
		r.height = r.radius * 1.4
		_mesh(holder, r, stone if k % 2 == 0 else mossy, Vector3(cos(a) * 0.95, 0.06, sin(a) * 0.95))
	# 충돌 크기도 비석에 맞게
	var shape := ($Collision as CollisionShape3D)
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.1, 2.6, 0.9)
	shape.shape = bs
	shape.position.y = 1.3
	progress_label.position.y = 3.6
	light.position.y = 1.6


## 룬 한 글자: 짧은 금빛 획 2~4개를 무작위 모양으로
func _rune(parent: Node3D, center: Vector3, side: float, rng: RandomNumberGenerator) -> void:
	var glyph := Node3D.new()
	glyph.position = center
	glyph.rotation.y = 0.0 if side > 0 else PI
	parent.add_child(glyph)
	var strokes := [
		[Vector2(0, 0), 0.0, 0.28], [Vector2(0.07, 0.06), 0.8, 0.14], [Vector2(-0.07, -0.06), -0.8, 0.14],
		[Vector2(0.06, 0), 0.0, 0.2], [Vector2(0, 0.08), 1.57, 0.14], [Vector2(-0.06, -0.08), 0.6, 0.12],
	]
	var main_stroke: Array = strokes[0] if rng.randf() < 0.6 else strokes[3]
	var chosen := [main_stroke]
	for k in rng.randi_range(1, 3):
		chosen.append(strokes[rng.randi_range(1, strokes.size() - 1)])
	for st in chosen:
		var b := BoxMesh.new()
		b.size = Vector3(0.035, st[2], 0.01)
		var mi := _mesh(glyph, b, _rune_mat, Vector3(st[0].x * (1 if rng.randf() < 0.5 else -1), st[0].y, 0))
		mi.rotation.z = st[1]


func _mesh(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _rock_mat(base: Color, seed_value: int) -> StandardMaterial3D:
	# 진짜 바위 질감이 있으면 그걸 씀 (assets/textures/rock_moss_set_01, Poly Haven CC0)
	const ROCK := "res://assets/textures/rock_moss_set_01/rock_moss_set_01_%s.%s"
	if ResourceLoader.exists(ROCK % ["diff", "jpg"]):
		var t := StandardMaterial3D.new()
		t.albedo_texture = load(ROCK % ["diff", "jpg"])
		t.albedo_color = Color(1.25, 1.25, 1.3) if base.g < 0.25 else Color(0.85, 0.85, 0.9)
		if ResourceLoader.exists(ROCK % ["nor", "png"]):
			t.normal_enabled = true
			t.normal_texture = load(ROCK % ["nor", "png"])
		if ResourceLoader.exists(ROCK % ["rough", "png"]):
			t.roughness_texture = load(ROCK % ["rough", "png"])
		t.uv1_triplanar = true
		t.uv1_scale = Vector3.ONE * 0.9
		return t
	var noise := FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.03
	noise.fractal_octaves = 5
	var grad := Gradient.new()
	grad.set_color(0, base.darkened(0.45))
	grad.set_color(1, base.lightened(0.25))
	var tex := NoiseTexture2D.new()
	tex.width = 256
	tex.height = 256
	tex.seamless = true
	tex.noise = noise
	tex.color_ramp = grad
	var ntex := NoiseTexture2D.new()
	ntex.width = 256
	ntex.height = 256
	ntex.seamless = true
	ntex.noise = noise
	ntex.as_normal_map = true
	ntex.bump_strength = 6.0
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.normal_enabled = true
	m.normal_texture = ntex
	m.normal_scale = 1.3
	m.roughness = 0.92
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 1.2
	return m


## 넓고 부드러운 빛기둥 (그림처럼 안개 속에 서 있는 빛)
func _make_beam() -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 1.2
	cyl.bottom_radius = 0.55
	cyl.height = 60.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	cyl.radial_segments = 32
	mi.mesh = cyl
	var sh := Shader.new()
	sh.code = BEAM_SHADER
	_beam_mat = ShaderMaterial.new()
	_beam_mat.shader = sh
	mi.material_override = _beam_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 30.0 + 2.9  # 비석 꼭대기(크리스탈)부터 위로
	add_child(mi)
	_beam = mi
	mi.visible = false


## 봉인석 주위로 천천히 떠오르는 빛 가루 (금빛 + 보라빛)
func _make_motes() -> void:
	var p := CPUParticles3D.new()
	add_child(p)
	_motes = p
	p.position.y = 1.2
	p.amount = 46 if SaveData.high_graphics() else 18
	p.lifetime = 3.5
	p.preprocess = 3.5
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 1.6
	p.direction = Vector3.UP
	p.spread = 25.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.6
	p.gravity = Vector3(0, 0.05, 0)
	p.tangential_accel_min = 0.2
	p.tangential_accel_max = 0.6
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.05
	var dot := SphereMesh.new()
	dot.radius = 1.0
	dot.height = 2.0
	dot.radial_segments = 6
	dot.rings = 3
	p.mesh = dot
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.disable_fog = true
	p.material_override = m
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.8, 0.45, 0.0))
	grad.add_point(0.25, Color(1.0, 0.8, 0.45, 1.0))
	grad.add_point(0.7, Color(0.7, 0.55, 1.0, 0.8))
	grad.set_color(grad.get_point_count() - 1, Color(0.6, 0.5, 1.0, 0.0))
	p.color_ramp = grad
	p.emitting = true


## 봉인석 위로 솟는 희미한 빛기둥 (멀리서도 위치를 알 수 있게, 안개를 뚫고 보임)
func _make_pillar() -> void:
	var mi := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.25
	cyl.bottom_radius = 0.35
	cyl.height = 60.0
	cyl.cap_top = false
	cyl.cap_bottom = false
	mi.mesh = cyl
	_pillar_mat = StandardMaterial3D.new()
	_pillar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_pillar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_pillar_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_pillar_mat.set("disable_fog", true)
	mi.material_override = _pillar_mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position.y = 31.0
	add_child(mi)


## 봉인석을 가동하려면 미니게임을 stages 번 클리어해야 함 (플레이어는 minigame.gd, 봇은 repair)
func stage_count() -> int:
	return int(GameConfig.num("minigame", "stages", 3))


## 지금까지 클리어한 단계 수
func stages_done() -> int:
	return int(round(progress * stage_count()))


## 플레이어가 미니게임을 클리어했을 때
func clear_stage(who: Node) -> void:
	if completed:
		return
	# 정비공 패시브: 미니게임 한 단계를 깨면 두 단계가 진행
	var step := 2 if who and who.get("character_id") == "mechanic" else 1
	progress = min(1.0, float(stages_done() + step) / stage_count())
	if who is Survivor:
		(who as Survivor).stat_stages += step
	NoiseBus.make_noise(global_position, GameConfig.num("mission", "repair_noise", 11.0), who)
	_play(SFX_STAGE_OK)
	_check_complete(who)


## 플레이어가 미니게임에 실패했을 때: 큰 소리 → 술래가 옴
func fail_stage(who: Node) -> void:
	NoiseBus.make_noise(global_position, GameConfig.num("minigame", "fail_noise", 30.0), who)
	_play(SFX_STAGE_FAIL)


## 플레이어가 미니게임을 중간에 그만뒀을 때: 술래들이 이 위치를 알아챔
func cancel_stage() -> void:
	for node in get_tree().get_nodes_in_group("seeker"):
		(node as Seeker).alert_to(global_position)
	_play(SFX_STAGE_FAIL)


## 동료 봇: 미니게임 대신 시간이 지나면 자동으로 진행 (한 단계당 bot_stage_time 초)
## who: 가동 중인 생존자. 여러 명이 동시에 하면 그만큼 빨리 찹니다.
func repair(delta: float, who: Node) -> void:
	if completed:
		return
	var rate := 2.0 if who and who.get("character_id") == "mechanic" else 1.0  # 정비공 봇은 2배 빠르게
	progress = min(1.0, progress + rate * delta / (GameConfig.num("minigame", "bot_stage_time", 6.0) * stage_count()))
	if who is Survivor:
		(who as Survivor).stat_stages += rate * delta / GameConfig.num("minigame", "bot_stage_time", 6.0)

	_noise_timer -= delta
	if _noise_timer <= 0.0:
		_noise_timer = GameConfig.num("mission", "repair_noise_interval", 2.0)
		NoiseBus.make_noise(global_position, GameConfig.num("mission", "repair_noise", 11.0), who)

	_check_complete(who)


func _check_complete(who: Node = null) -> void:
	if progress >= 0.999 and not completed:
		progress = 1.0
		completed = true
		_play_complete_sound()
		_burst()
		if _beam:
			_beam.visible = true
		mission_completed.emit(self)
	_update_visual()


func _update_visual() -> void:
	var mat := StandardMaterial3D.new()
	mat.emission_enabled = true
	if completed:
		mat.albedo_color = Color(0.3, 1.0, 0.6)
		mat.emission = Color(0.2, 1.0, 0.5)
		progress_label.text = "봉인석 가동 완료!"
		light.light_color = Color(0.3, 1.0, 0.6)
		light.light_energy = 2.5
		if _rune_mat:
			_rune_mat.emission = Color(0.4, 1.0, 0.6)
			_rune_mat.emission_energy_multiplier = 3.0
		if _beam_mat:
			_beam_mat.set_shader_parameter("col", Vector3(0.35, 1.0, 0.6))
		if _pillar_mat:
			_pillar_mat.albedo_color = Color(0.25, 1.0, 0.5, 0.2)
	else:
		mat.albedo_color = Color(0.5, 0.35, 0.95)
		mat.emission = Color(0.6, 0.3, 1.0) * (0.9 + progress * 1.2)
		mat.roughness = 0.2
		mat.metallic = 0.3
		progress_label.text = "가동 %d / %d 단계" % [stages_done(), stage_count()]
		light.light_color = Color(0.5, 0.4, 1.0)
		light.light_energy = 1.0 + progress * 1.5
		if _rune_mat:
			_rune_mat.emission_energy_multiplier = 0.8 + progress * 2.5
		if _beam_mat:
			_beam_mat.set_shader_parameter("strength", 0.3 + progress * 0.4)
		if _pillar_mat:
			_pillar_mat.albedo_color = Color(0.55, 0.4, 1.0, 0.14 + progress * 0.08)
	crystal.material_override = mat
	for c in _small_crystals:
		c.material_override = mat
	if _reveal >= 0.0:
		_apply_reveal(_reveal)


## 가동 완료 소리 (멀리 있는 동료도 들을 수 있게 넓게)
func _play_complete_sound() -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = SFX_COMPLETE
	p.max_distance = 60.0
	p.unit_size = 12.0
	add_child(p)
	p.play()


func _play(stream: AudioStream) -> void:
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.max_distance = 40.0
	p.unit_size = 8.0
	add_child(p)
	p.play()
	p.finished.connect(p.queue_free)
