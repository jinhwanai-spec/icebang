extends RefCounted
## 맵 조명 도우미 (도시·학교·병원·숲 빌더가 같이 씀)
## - practical(): 실내등·가로등 기본 설정 (멀면 사라짐, 가까우면 그림자 후보)
## - flicker(): 깜빡임/불꽃/경광등 + 형광등 웅웅 소리
## - 회전 경광등, 나방·불티 입자, 창틀 그림자(빛 무늬) 텍스처
## 모양·부딪힘은 건드리지 않고 "빛"만 더합니다.

const FLICKER := preload("res://scripts/flicker_light.gd")
const HUM := preload("res://audio/light_hum.wav")
## 맵 하나에 웅웅 소리 내는 형광등 최대 수 (소리 채널 아끼기)
const MAX_HUMS := 10
## 나방·불티 입자 최대 수
const MAX_PARTICLES := 10

static var hums := 0
## 맵을 만드는 동안 생긴 빛나는 재질 (정전 때 같이 끔). main.gd 가 recording 을 켜고 끔
static var recording := false
static var power_mats: Array = []
static var particles := 0
static var _cookie: Texture2D
static var _hum_ready := false


## 새 맵을 만들기 시작할 때 (개수 제한 초기화)
static func reset() -> void:
	hums = 0
	particles = 0


static func high() -> bool:
	return SaveData.high_graphics()


## 맵에 놓인 불빛 기본 설정. shadow_ok = 가까이 가면 그림자를 켜도 되는 불빛 (light_lod.gd 가 관리)
static func practical(l: Light3D, fade_begin := 30.0, shadow_ok := true) -> void:
	l.set_meta("lit_design", true)  # main.gd 의 무작위 깜빡임 대상에서 뺌
	l.light_specular = 0.35
	l.shadow_enabled = false
	l.shadow_bias = 0.08
	l.shadow_normal_bias = 1.5
	l.shadow_blur = 1.5
	l.distance_fade_enabled = true
	l.distance_fade_begin = fade_begin
	l.distance_fade_length = 8.0
	l.distance_fade_shadow = 18.0
	if shadow_ok and high():
		l.add_to_group("shadow_light")


## 깜빡임 붙이기. mode = "fluorescent" / "dying" / "fire" / "strobe" / "beacon"
static func flicker(l: Light3D, mode := "fluorescent", mats: Array = [], hum := false) -> void:
	l.set_script(FLICKER)
	l.set("mode", mode)
	l.set("mats", mats)
	l.set_meta("lit_design", true)
	if hum and hums < MAX_HUMS:
		hums += 1
		var a := AudioStreamPlayer3D.new()
		a.stream = hum_stream()
		a.volume_db = -14.0
		a.unit_size = 1.6
		a.max_distance = 9.0
		a.autoplay = true
		l.add_child(a)
		l.set("hum", a)
	l.set_process(true)


static func hum_stream() -> AudioStreamWAV:
	var w := HUM as AudioStreamWAV
	if not _hum_ready and w:
		_hum_ready = true
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		w.loop_end = int(w.get_length() * w.mix_rate)
	return w


## 발광 재질 (색·세기)
static func glow_mat(col: Color, energy := 2.0, albedo_k := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col * albedo_k
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	m.roughness = 0.4
	if recording:
		power_mats.append(m)
	return m


static func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, yaw := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos
	mi.rotation.y = yaw
	parent.add_child(mi)
	return mi


## 회전하는 붉은 경광등 (지하 비상등). 바닥 위 높이 pos 에 달림
static func beacon(parent: Node3D, pos: Vector3) -> void:
	_box(parent, pos + Vector3.UP * 0.12, Vector3(0.22, 0.06, 0.22), _dark())
	var dome := glow_mat(Color(1.0, 0.12, 0.06), 2.5)
	var dm := MeshInstance3D.new()
	var sph := SphereMesh.new()
	sph.radius = 0.09
	sph.height = 0.14
	dm.mesh = sph
	dm.material_override = dome
	dm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dm.position = pos + Vector3.UP * 0.04
	parent.add_child(dm)
	var sl := SpotLight3D.new()
	sl.light_color = Color(1.0, 0.1, 0.05)
	sl.light_energy = 5.0
	sl.spot_range = 13.0
	sl.spot_angle = 22.0
	sl.spot_attenuation = 0.8
	sl.light_volumetric_fog_energy = 2.5
	sl.position = pos
	sl.rotation = Vector3(-0.35, 0, 0)
	parent.add_child(sl)
	practical(sl, 32.0, false)
	flicker(sl, "beacon")
	var gl := OmniLight3D.new()
	gl.light_color = Color(1.0, 0.12, 0.06)
	gl.light_energy = 0.5
	gl.omni_range = 3.0
	gl.position = pos
	parent.add_child(gl)
	practical(gl, 26.0, false)


static var _dark_mat: StandardMaterial3D
static func _dark() -> StandardMaterial3D:
	if _dark_mat == null:
		_dark_mat = StandardMaterial3D.new()
		_dark_mat.albedo_color = Color(0.12, 0.12, 0.13)
		_dark_mat.roughness = 0.6
	return _dark_mat


## 가로등 아래를 맴도는 나방·먼지 (그래픽 높음만)
static func moths(parent: Node3D, pos: Vector3) -> void:
	if not high() or particles >= MAX_PARTICLES:
		return
	particles += 1
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 14
	p.lifetime = 3.0
	p.preprocess = 3.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.6
	p.direction = Vector3.UP
	p.spread = 180.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.4
	p.initial_velocity_max = 1.2
	p.orbit_velocity_min = 0.4
	p.orbit_velocity_max = 0.9
	p.radial_accel_min = -1.2
	p.radial_accel_max = -0.6
	p.scale_amount_min = 0.02
	p.scale_amount_max = 0.035
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_color = Color(1.0, 0.85, 0.6)
	m.disable_fog = true
	p.material_override = m
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)


## 모닥불 불티 (위로 날아오르는 주황 점)
static func embers(parent: Node3D, pos: Vector3) -> void:
	if not high() or particles >= MAX_PARTICLES:
		return
	particles += 1
	var p := CPUParticles3D.new()
	p.position = pos
	p.amount = 24
	p.lifetime = 2.2
	p.preprocess = 2.0
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.25
	p.direction = Vector3.UP
	p.spread = 25.0
	p.gravity = Vector3(0, 0.6, 0)
	p.initial_velocity_min = 0.6
	p.initial_velocity_max = 1.6
	p.scale_amount_min = 0.015
	p.scale_amount_max = 0.03
	var q := QuadMesh.new()
	q.size = Vector2.ONE
	p.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(1.0, 0.5, 0.15) * 3.0
	m.disable_fog = true
	p.material_override = m
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.7, 0.3, 1.0))
	grad.set_color(1, Color(1.0, 0.2, 0.05, 0.0))
	p.color_ramp = grad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(p)


## 창틀 모양 빛 무늬 (달빛이 창살 그림자를 바닥에 드리움): 2x2 유리칸 + 두꺼운 틀
static func window_cookie() -> Texture2D:
	if _cookie:
		return _cookie
	var n := 64
	var img := Image.create(n, n, false, Image.FORMAT_RGB8)
	img.fill(Color.BLACK)
	var frame := 5
	var bar := 3
	for y in range(frame, n - frame):
		for x in range(frame, n - frame):
			if absi(x - n / 2) <= bar / 2 + 1 or absi(y - int(n * 0.38)) <= bar / 2:
				continue
			# 가장자리는 살짝 부드럽게
			var e := minf(minf(x - frame, n - frame - 1 - x), minf(y - frame, n - frame - 1 - y))
			var v := clampf(0.55 + e * 0.15, 0.0, 1.0)
			img.set_pixel(x, y, Color(v, v, v))
	_cookie = ImageTexture.create_from_image(img)
	return _cookie
