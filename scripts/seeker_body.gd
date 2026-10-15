class_name SeekerBody
extends Node3D
## 술래(괴물) 외형 — 어두운 공포 게임 스타일 절차적 모델
## - 텍스처 없이 셰이더 노이즈로 피부 얼룩·때·핏자국·갈라짐을 그림 (assets/seekers/creature*.gdshader)
## - 뼈대(Node3D 계층: 골반 → 척추 → 가슴 → 목 → 머리, 어깨 → 팔꿈치 → 손, 엉덩이 → 무릎 → 발)를 만들고
##   animate()가 걷기·숨쉬기·고개 꺾기(경련)·공격 동작을 움직입니다.
## - 눈은 어둠 속에서도 보이게 빛남 (발광 재질 + 작은 빛 번짐 + 눈 주변만 비추는 작은 조명 1개)
## 앞쪽은 -Z 방향입니다 (술래 스크립트가 -Z 방향을 앞으로 씀). 오른쪽은 +X.
## type: ghost(유령) / butcher(도살자) / rat(역병의 쥐) / spider(거미 여왕) / mannequin(마네킹)
##       hound(케르베로스) / puppeteer(인형사) / witch(안개 마녀) / psycho(사이코)
##       executioner(처형인) / diet(하마)

const SH_SOLID := preload("res://assets/seekers/creature.gdshader")
const SH_CLOTH := preload("res://assets/seekers/creature_cloth.gdshader")
const SH_FADE := preload("res://assets/seekers/creature_fade.gdshader")

var type := "ghost"
var axe_in_hand: Node3D   # 도살자가 던지면 잠깐 숨김
## 하마 아래턱 (블랙홀 때 벌어짐)
var mouth_jaw: Node3D

# ---- 재질
var _smats: Array[ShaderMaterial] = []
var _eye_mats: Array[StandardMaterial3D] = []
var _halo_mats: Array[StandardMaterial3D] = []
var _glow_mats: Array[StandardMaterial3D] = []
var _halos: Array[MeshInstance3D] = []
var _eye_m: StandardMaterial3D
var _eye_light: OmniLight3D
var _eye_color := Color(1.0, 0.8, 0.2)
var _eye_energy := 4.0
var _light_energy := 0.35
var _tinted := false
var _halo_z := -0.05
var _rng := RandomNumberGenerator.new()
static var _noise: FastNoiseLite
static var _halo_tex: GradientTexture2D
## 종류별로 처음 만든 메시를 저장해 두고 다음부터는 재사용 (분신 등 게임 중 생성할 때 끊김 방지)
static var _mesh_cache := {}
var _use_cache := false
var _mesh_list: Array = []
var _mi_count := 0
## 전체 크기 배율: 모든 부위는 _root 아래에 붙고 _root.scale 로 한꺼번에 키움 (충돌 캡슐은 그대로)
var _root: Node3D
var _S := 1.0
var _cross_y := 2.92

# ---- 뼈대
var _rig := "biped"   # biped / float / hound / spider
var _hips: Node3D
var _spine: Node3D
var _chest: Node3D
var _neck: Node3D
var _head: Node3D
var _jaw: Node3D
var _abd: Node3D
var _cross: Node3D
var _arm: Array[Node3D] = [null, null]     # 어깨 [왼, 오른]
var _elbow: Array[Node3D] = [null, null]
var _hand: Array[Node3D] = [null, null]
var _leg: Array[Node3D] = [null, null]     # 엉덩이 관절
var _knee: Array[Node3D] = [null, null]
var _foot: Array[Node3D] = [null, null]
var _tail: Array[Node3D] = []
var _legs4: Array = []          # 케르베로스 다리 [엉덩이, 무릎, 발목] × 4 (앞왼, 앞오, 뒤왼, 뒤오)
var _sp_legs: Array = []        # 거미 다리 [엉덩이, 무릎] × 8
var _heads: Array[Node3D] = []  # 케르베로스 목 3개
var _jaws: Array[Node3D] = []
var _danglers: Array[Node3D] = []   # 쇠사슬·랜턴: 항상 아래로 늘어짐
var _strings: Array = []        # 인형사 실 [메시, 시작 노드, 시작점, 끝 노드, 끝점]
var _rest := {}
var _hip_y := 1.0

# ---- 움직임 성격
var _step := 1.3        # 한 걸음 길이(m)
var _stride := 0.5      # 다리 휘두름(라디안)
var _knee_amt := 0.9
var _arm_amt := 0.45
var _bob := 0.05
var _lean := -0.25      # 뛸 때 앞으로 숙임
var _twitch_rate := 0.3
var _twitch_amp := 0.5
var _jitter := 0.0
var _jerk_fps := 0.0    # 0보다 크면 스톱모션처럼 뚝뚝 끊겨 움직임 (마네킹)
var _limp := 0.0
var _hold_right := false  # 오른손에 무기 (공격 때 오른팔만 크게 휘두름)

# ---- 상태
var _phase := 0.0
var _time := 0.0
var _jerk_acc := 0.0
var _blink := 2.0
var _attack_t := 0.0
var _attack_dur := 0.3
var _mouth_t := 0.0
var _twitch_cd := 1.0
var _twitch_hold := 0.0
var _twitch_v := Vector3.ZERO
var _twitch_target := Vector3.ZERO


func build(seeker_type: String) -> void:
	type = seeker_type
	_rng.seed = hash(type) + 7
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_noise.frequency = 1.0
		_noise.seed = 1234
	_use_cache = _mesh_cache.has(type)
	_root = Node3D.new()
	_root.name = "Root"
	add_child(_root)
	match type:
		"ghost": _build_ghost()
		"butcher": _build_butcher()
		"rat": _build_rat()
		"spider": _build_spider()
		"mannequin": _build_mannequin()
		"hound": _build_hound()
		"puppeteer": _build_puppeteer()
		"witch": _build_witch()
		"psycho": _build_psycho()
		"executioner": _build_executioner()
		"diet": _build_diet()
		_: _build_ghost()
	if not _use_cache:
		_mesh_cache[type] = _mesh_list
	_root.scale = Vector3.ONE * _S
	if _eye_light:
		_eye_light.omni_range *= _S
	for n in find_children("*", "Node3D", true, false):
		if n.get_class() == "Node3D":
			_rest[n] = (n as Node3D).rotation
	if _hips:
		_hip_y = _hips.position.y
	_twitch_cd = randf_range(0.5, 2.0)
	_phase = randf() * TAU


# ================================================================ 유령
## 키 크고 말라비틀어진 창백한 여자. 찢어진 수의, 얼굴을 덮은 긴 검은 머리, 머리카락 사이로 빛나는 눈,
## 비정상적으로 긴 팔과 손가락. 다리 없이 떠다니고 옷자락 끝은 투명하게 흩어짐
func _build_ghost() -> void:
	_rig = "float"
	_S = 1.38
	_eye_color = Color(0.55, 0.9, 1.0)
	_twitch_rate = 0.35
	_twitch_amp = 0.85
	_skel(1.12, 0.36, 0.42, 0.16, 0.19, 0.92, 0.12, 0.56, 0.5, 0.0, 0.0)
	var skin := _m(Color(0.5, 0.54, 0.56), {"albedo2": Color(0.34, 0.37, 0.44), "mottle": 0.6, "mottle_scale": 7.0, "grime": 0.35,
		"roughness_v": 0.5, "backlight_v": 0.35, "rim": 0.3, "rim_color": Color(0.45, 0.7, 0.95), "bump": 0.35,
		"veins": 0.35, "vein_color": Color(0.08, 0.2, 0.35)})
	var shroud := _m(Color(0.42, 0.42, 0.4), {"albedo2": Color(0.28, 0.28, 0.25), "mottle": 0.6, "mottle_scale": 3.0, "grime": 0.7,
		"grime_color": Color(0.1, 0.09, 0.07), "blood": 0.2, "blood_scale": 3.0, "roughness_v": 0.95, "backlight_v": 0.45,
		"rim": 0.22, "rim_color": Color(0.5, 0.68, 0.9), "kind": "cloth", "sway": 0.03, "bump": 0.7, "bump_scale": 22.0})
	var hem := _m(Color(0.42, 0.44, 0.43, 0.7), {"albedo2": Color(0.3, 0.31, 0.3), "mottle": 0.5, "grime": 0.5,
		"roughness_v": 0.95, "backlight_v": 0.5, "rim": 0.35, "rim_color": Color(0.5, 0.75, 1.0), "kind": "fade",
		"sway": 0.1, "sway_speed": 1.3, "fade_start": 0.15})
	var hair := _hair_mat(Color(0.015, 0.015, 0.02))
	var nail := _m(Color(0.05, 0.04, 0.04), {"roughness_v": 0.35, "grime": 0.0})
	var dark := _dark_mat()

	# 수의 상체 (가슴)
	var g := Geo.new()
	_lathe(g, _p([[0.15, -0.42], [0.14, -0.25], [0.155, 0.0], [0.175, 0.2], [0.17, 0.31], [0.13, 0.36]]),
		{"sides": 18, "sx": 1.25, "sz": 0.72, "jit": 0.025, "nf": 6.0})
	_ell(g, Vector3(-0.19, 0.37, 0.0), Vector3(0.06, 0.05, 0.06))
	_ell(g, Vector3(0.19, 0.37, 0.0), Vector3(0.06, 0.05, 0.06))
	_mi(_chest, g, shroud)
	# 드러난 앙상한 가슴·쇄골·목
	g = Geo.new()
	_lathe(g, _p([[0.1, 0.18], [0.13, 0.3], [0.1, 0.39], [0.045, 0.45]]), {"sides": 14, "sx": 1.35, "sz": 0.72})
	for sg: float in [-1.0, 1.0]:
		_tube(g, _bez3(Vector3(sg * 0.02, 0.405, -0.075), Vector3(sg * 0.08, 0.4, -0.085), Vector3(sg * 0.14, 0.4, -0.06), Vector3(sg * 0.18, 0.39, -0.02), 5),
			PackedFloat32Array([0.008, 0.012, 0.011, 0.01, 0.006]), {"sides": 6})
		for k in 3:  # 갈비뼈 윤곽
			var y := 0.27 - k * 0.045
			_tube(g, _bez3(Vector3(sg * 0.02, y, -0.098), Vector3(sg * 0.07, y - 0.01, -0.1), Vector3(sg * 0.12, y - 0.025, -0.08), Vector3(sg * 0.15, y - 0.04, -0.04), 5),
				PackedFloat32Array([0.004, 0.007, 0.007, 0.005, 0.003]), {"sides": 5})
	_mi(_chest, g, skin)
	# 목 (가늘고 길게, 힘줄)
	g = Geo.new()
	_tube(g, _line(Vector3(0, -0.04, 0.0), Vector3(0, 0.17, -0.02), 5), PackedFloat32Array([0.04, 0.034, 0.03, 0.03, 0.033]), {"sides": 10})
	for sg: float in [-1.0, 1.0]:
		_tube(g, _line(Vector3(sg * 0.03, -0.02, -0.035), Vector3(sg * 0.012, 0.15, -0.035), 3), PackedFloat32Array([0.011, 0.008, 0.006]), {"sides": 5})
	_mi(_neck, g, skin)
	_neck.rotation.x = -0.4
	# 머리: 길쭉하고 움푹 꺼진 얼굴
	g = Geo.new()
	_ell(g, Vector3(0, 0.11, 0.0), Vector3(0.088, 0.125, 0.105))
	_ell(g, Vector3(0, 0.03, -0.035), Vector3(0.062, 0.06, 0.07))
	_ell(g, Vector3(0, 0.155, -0.07), Vector3(0.07, 0.025, 0.04))
	_mi(_head, g, skin)
	_head.rotation = Vector3(0.25, 0, 0.18)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.036, 0.118, -0.088), Vector3(0.026, 0.021, 0.02))
	_ell(g, Vector3(0.004, 0.02, -0.09), Vector3(0.02, 0.042, 0.02), {"rot": Basis(Vector3.FORWARD, 0.12)})  # 벌어진 입
	_mi(_head, g, dark)
	_halo_z = -0.06
	_eyes_at(_head, [Vector3(-0.036, 0.118, -0.1), Vector3(0.036, 0.118, -0.1)], 0.012, 0.13)
	# 얼굴을 덮는 긴 검은 머리 (오른쪽 눈 앞은 갈라져서 눈빛이 보임)
	g = Geo.new()
	_hair(g, Vector3(0, 0.11, 0.0), Vector3(0.09, 0.13, 0.108), 120, 0.85, 1.3, 0.03, 0.14, 0.6, 0.07)
	var hang := func(p: Vector3) -> Vector3:
		if p.y < -0.2:
			p.y += _noise.get_noise_2d(atan2(p.x, p.z) * 7.0, 6.0) * 0.14
		return p
	_lathe(g, _p([[0.05, 0.24], [0.1, 0.18], [0.112, 0.06], [0.12, -0.15], [0.16, -0.5], [0.2, -0.95]]),
		{"sides": 22, "sz": 1.05, "a0": PI * 0.5 + 1.1, "a1": PI * 2.5 - 1.1, "jit": 0.2, "nf": 7.0, "deform": hang})
	_mi(_head, g, hair)

	# 팔: 뼈만 남은 긴 팔, 찢어진 소매
	for i in 2:
		var sg := -1.0 if i == 0 else 1.0
		g = Geo.new()
		_limb(g, Vector3(0, 0.02, 0), Vector3(0, -0.56, 0), 0.042, 0.036, 0.028, 8)
		_ell(g, Vector3(0, -0.56, 0.005), Vector3(0.034, 0.04, 0.034))
		_mi(_arm[i], g, skin)
		g = Geo.new()
		_tube(g, _line(Vector3(0, 0.05, 0), Vector3(0, -0.4, 0.02), 5), PackedFloat32Array([0.07, 0.085, 0.105, 0.13, 0.155]),
			{"sides": 12, "jit": 0.35, "nf": 9.0, "cap": false})
		_tatters_line(g, Vector3(0, -0.38, 0.02), 0.14, 6, 0.2, 0.5, 0.04)
		_mi(_arm[i], g, shroud)
		g = Geo.new()
		_limb(g, Vector3(0, 0.01, 0), Vector3(0, -0.5, 0), 0.032, 0.03, 0.019, 8)
		_mi(_elbow[i], g, skin)
		g = Geo.new()
		var gn := Geo.new()
		_hand_geo(g, gn, sg, 0.085, 0.065, 0.21, 0.0085, 4, 0.28, 0.045)
		_mi(_hand[i], g, skin)
		_mi(_hand[i], gn, nail)
	_arm[0].rotation = Vector3(1.15, 0, -0.12)
	_arm[1].rotation = Vector3(0.7, 0, 0.2)
	_elbow[0].rotation.x = 0.3
	_elbow[1].rotation.x = 0.65
	_hand[0].rotation.x = 0.35
	_hand[1].rotation.x = 0.2

	# 아래로 퍼지는 수의 치마 + 투명하게 흩어지는 옷자락
	g = Geo.new()
	var ragged := func(p: Vector3) -> Vector3:
		if p.y < -0.8:
			p.y += _noise.get_noise_2d(atan2(p.x, p.z) * 3.0, 5.0) * 0.12
		return p
	var folds := func(p: Vector3) -> Vector3:
		var a := atan2(p.x, p.z)
		var k := 1.0 + (0.07 * sin(a * 8.0) + 0.03 * sin(a * 19.0 + 2.0)) * clampf(-p.y, 0.0, 1.0)
		p.x *= k
		p.z *= k
		return ragged.call(p)
	_lathe(g, _p([[0.14, 0.06], [0.2, -0.2], [0.29, -0.5], [0.4, -0.8], [0.5, -0.98]]),
		{"sides": 28, "sx": 1.0, "sz": 0.88, "jit": 0.05, "nf": 7.0, "deform": folds})
	_mi(_hips, g, shroud)
	g = Geo.new()  # 겉에 걸친 찢어진 수의 자락 (앞이 트임)
	_lathe(g, _p([[0.16, 0.08], [0.23, -0.2], [0.33, -0.5], [0.44, -0.78]]),
		{"sides": 22, "sz": 0.9, "a0": PI * 0.5 + 0.55, "a1": PI * 2.5 - 0.55, "jit": 0.08, "nf": 6.0, "deform": folds})
	_tatters(g, -0.74, 0.44, 0.44 * 0.9, 14, 0.12, 0.35, 0.05, PI * 0.5 + 0.6, PI * 2.5 - 0.6, 0.05)
	_mi(_hips, g, shroud)
	g = Geo.new()
	_tatters(g, -0.94, 0.5, 0.44, 32, 0.15, 0.6, 0.05, 0.0, TAU, 0.08)
	_mi(_hips, g, hem)
	g = Geo.new()  # 어깨를 덮은 수의 베일 (등 뒤로 길게 늘어짐)
	var veil := func(p: Vector3) -> Vector3:
		var a := atan2(p.x, p.z)
		var depth := clampf((0.3 - p.y) / 1.2, 0.0, 1.0)
		var k := 1.0 + (0.14 * sin(a * 6.0 + 0.7) + 0.05 * sin(a * 15.0)) * depth
		p.x *= k
		p.z *= k
		if p.y < -0.6:
			p.y += _noise.get_noise_2d(a * 5.0, 9.0) * 0.15
		return p
	_lathe(g, _p([[0.08, 0.47], [0.17, 0.44], [0.235, 0.35], [0.255, 0.15], [0.29, -0.3], [0.35, -0.75]]),
		{"sides": 26, "sx": 1.12, "sz": 1.0, "a0": PI * 0.5 + 0.75, "a1": PI * 2.5 - 0.75, "jit": 0.1, "nf": 5.0, "deform": veil})
	_tatters(g, -0.72, 0.35 * 1.12, 0.35, 12, 0.15, 0.45, 0.055, PI * 0.5 + 0.85, PI * 2.5 - 0.85, 0.04)
	_mi(_chest, g, shroud)


# ================================================================ 도살자
## 산처럼 큰 도살자: 피 묻은 두꺼운 가죽 앞치마(쇠 버클 멜빵, 허리띠에 매단 고기 갈고리·칼집), 꿰맨 돼지 가죽 가면,
## 굽은 등과 거대한 승모근·어깨, 꿰맨 흉터, 왼팔에 감은 쇠사슬과 갈고리, 오른손엔 거대한 고기 써는 칼
func _build_butcher() -> void:
	_S = 1.35
	_eye_color = Color(1.0, 0.42, 0.08)
	_hold_right = true
	_stride = 0.42
	_bob = 0.07
	_limp = 0.35
	_step = 1.1
	_twitch_rate = 0.15
	_skel(1.05, 0.32, 0.55, 0.1, 0.5, 0.8, 0.19, 0.5, 0.46, 0.5, 0.47)
	var skin := _m(Color(0.27, 0.19, 0.165), {"albedo2": Color(0.2, 0.1, 0.11), "mottle": 0.7, "mottle_scale": 4.0,
		"grime": 0.55, "grime_color": Color(0.1, 0.07, 0.05), "blood": 0.4, "blood_scale": 3.2, "roughness_v": 0.75, "bump": 0.4, "rim": 0.1, "rim_color": Color(0.7, 0.5, 0.4), "backlight_v": 0.1})
	var mask := _m(Color(0.4, 0.29, 0.25), {"albedo2": Color(0.28, 0.18, 0.15), "mottle": 0.6, "mottle_scale": 6.0,
		"grime": 0.7, "blood": 0.5, "blood_scale": 3.5, "roughness_v": 0.8, "bump": 0.5, "cracks": 0.35,
		"crack_color": Color(0.25, 0.08, 0.07), "crack_scale": 4.0, "rim": 0.1})
	var leather := _m(Color(0.16, 0.1, 0.07), {"albedo2": Color(0.09, 0.055, 0.035), "mottle": 0.5, "mottle_scale": 3.0, "grime": 0.35, "blood": 0.8, "blood_scale": 2.0,
		"roughness_v": 0.78, "bump": 0.4, "kind": "cloth", "rim": 0.08})
	var strap := _m(Color(0.11, 0.07, 0.045), {"albedo2": Color(0.07, 0.04, 0.03), "roughness_v": 0.78, "grime": 0.4, "blood": 0.3})
	var pants := _m(Color(0.17, 0.16, 0.15), {"albedo2": Color(0.1, 0.09, 0.08), "mottle": 0.4, "grime": 0.55, "blood": 0.35, "roughness_v": 0.9, "bump": 0.4})
	var boot := _m(Color(0.07, 0.05, 0.04), {"albedo2": Color(0.12, 0.09, 0.06), "mottle": 0.4, "grime": 0.55, "roughness_v": 0.75, "blood": 0.25})
	var steel := _metal(Color(0.5, 0.5, 0.52), 0.72)
	var iron := _metal(Color(0.25, 0.24, 0.23), 0.8)
	var wood := _m(Color(0.25, 0.15, 0.08), {"mottle_scale": 18.0, "grime": 0.4, "roughness_v": 0.8, "blood": 0.3})
	var thread := _m(Color(0.06, 0.04, 0.03), {"roughness_v": 0.9, "grime": 0.0})
	var meat := _m(Color(0.38, 0.05, 0.05), {"albedo2": Color(0.55, 0.2, 0.18), "mottle": 0.7, "mottle_scale": 9.0, "grime": 0.2, "blood": 0.6, "roughness_v": 0.72})
	var bone := _m(Color(0.75, 0.7, 0.58), {"albedo2": Color(0.5, 0.44, 0.33), "mottle": 0.5, "grime": 0.5, "roughness_v": 0.78, "blood": 0.4})
	var hairm := _hair_mat(Color(0.03, 0.025, 0.02))
	var dark := _dark_mat()
	var nail := _m(Color(0.25, 0.2, 0.14), {"roughness_v": 0.75})
	_spine.rotation.x = -0.25
	_chest.rotation.x = -0.12
	_neck.rotation.x = 0.12
	_head.rotation.x = 0.18

	var belly := func(p: Vector3) -> Vector3:
		if p.z < 0.0 and p.y < 0.15:
			p.z -= 0.1 * smoothstep(0.15, -0.2, p.y) * clampf(-p.z / 0.35, 0.0, 1.0)
		if p.z > 0.0 and p.y > 0.3:
			p.y += 0.05 * clampf(p.z / 0.3, 0.0, 1.0)
			p.z += 0.05
		return p
	# ---- 거대한 상체: 가슴·배·승모근·어깨·등 근육
	var g := Geo.new()
	_lathe(g, _p([[0.33, -0.38], [0.4, -0.2], [0.44, 0.0], [0.46, 0.2], [0.44, 0.38], [0.33, 0.52], [0.17, 0.6], [0.0, 0.64]]),
		{"sides": 22, "sx": 1.22, "sz": 0.95, "jit": 0.025, "deform": belly})
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.18, 0.27, -0.3), Vector3(0.17, 0.13, 0.08))
		_ell(g, Vector3(sg * 0.22, 0.55, 0.04), Vector3(0.2, 0.13, 0.17), {"jit": 0.03})
		_ell(g, Vector3(sg * 0.49, 0.44, 0.0), Vector3(0.19, 0.18, 0.19), {"jit": 0.03})
		_ell(g, Vector3(sg * 0.3, 0.2, 0.25), Vector3(0.18, 0.24, 0.12))
	_ell(g, Vector3(0, 0.4, 0.22), Vector3(0.36, 0.24, 0.17), {"jit": 0.04})
	_mi(_chest, g, skin)
	g = Geo.new()
	_ell(g, Vector3(0, 0.14, -0.06), Vector3(0.47, 0.38, 0.44), {"jit": 0.03})
	_mi(_spine, g, skin)
	g = Geo.new()
	_tube(g, _line(Vector3(0, -0.06, 0.02), Vector3(0, 0.14, -0.03), 3), PackedFloat32Array([0.2, 0.18, 0.165]), {"sides": 14})
	_mi(_neck, g, skin)
	# 꿰맨 흉터 (등·어깨·팔)
	g = Geo.new()
	_stitches(g, _bez3(Vector3(-0.42, 0.5, 0.18), Vector3(-0.2, 0.42, 0.36), Vector3(0.05, 0.3, 0.38), Vector3(0.25, 0.08, 0.33), 10), 11, 0.05)
	_stitches(g, _bez2(Vector3(0.38, 0.58, -0.05), Vector3(0.5, 0.5, -0.17), Vector3(0.62, 0.36, -0.12), 6), 6, 0.045)
	_mi(_chest, g, thread)
	# ---- 앞치마: 가슴판 + 쇠 버클 멜빵(등에서 X자) + 아랫단, 허리띠
	g = Geo.new()
	_lathe(g, _p([[0.385, -0.38], [0.455, -0.2], [0.495, 0.0], [0.51, 0.2], [0.485, 0.42]]),
		{"sides": 16, "sx": 1.22, "sz": 0.95, "a0": 0.5, "a1": PI - 0.5, "jit": 0.02, "deform": belly})
	_mi(_chest, g, leather)
	g = Geo.new()
	var gb := Geo.new()
	for sg: float in [-1.0, 1.0]:
		var top := Vector3(sg * 0.27, 0.42, -0.42)
		_tube(g, _bez3(top, Vector3(sg * 0.3, 0.64, -0.24), Vector3(sg * 0.24, 0.72, 0.1), Vector3(-sg * 0.05, 0.55, 0.4), 9),
			PackedFloat32Array([0.012]), {"sides": 4, "flat": 3.2, "up": Vector3(0, 0, -1)})
		_tube(g, _bez2(Vector3(-sg * 0.05, 0.55, 0.4), Vector3(-sg * 0.3, 0.2, 0.46), Vector3(-sg * 0.45, -0.2, 0.36), 6), PackedFloat32Array([0.012]), {"sides": 4, "flat": 3.2, "up": Vector3(0, 0, 1)})
		_tube(gb, _ellipse(0.035, 0.03, 0.0, 8, Vector3(top.x, top.y + 0.05, top.z - 0.012)), PackedFloat32Array([0.008]), {"sides": 4, "cap": false,
			"xf": Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3.ZERO).translated_local(Vector3.ZERO)})
	_mi(_chest, g, strap)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		var bp := Vector3(sg * 0.27, 0.46, -0.445)
		_extrude(g, PackedVector2Array([Vector2(-0.04, -0.035), Vector2(0.04, -0.035), Vector2(0.04, 0.035), Vector2(-0.04, 0.035)]), PackedFloat32Array([0.009, 0.009, 0.009, 0.009]),
			Transform3D(Basis(Vector3.RIGHT, -0.15), bp))
		var sp := _bez3(Vector3(sg * 0.27, 0.42, -0.42), Vector3(sg * 0.3, 0.64, -0.24), Vector3(sg * 0.24, 0.72, 0.1), Vector3(-sg * 0.05, 0.55, 0.4), 9)
		for k in range(2, 7):  # 멜빵의 쇠 징
			var nrm := (sp[k] - Vector3(0, 0.3, 0)).normalized()
			_ell(g, sp[k] + nrm * 0.012, Vector3(0.016, 0.016, 0.016), {"sides": 6, "rings": 4})
	_mi(_chest, g, iron)
	g = Geo.new()
	_lathe(g, _p([[0.53, 0.3], [0.56, 0.08], [0.57, -0.25], [0.61, -0.62]]),
		{"sides": 16, "sz": 0.9, "a0": 0.48, "a1": PI - 0.48, "jit": 0.03})
	_tube(g, _ellipse(0.53, 0.47, 0.26, 24), PackedFloat32Array([0.025]), {"sides": 6, "cap": false})
	_mi(_hips, g, leather)
	g = Geo.new()  # 허리띠 + 칼집
	var belt := PackedVector3Array()
	for k in 29:
		var a := TAU * k / 28.0
		var fr := smoothstep(-0.1, 0.5, sin(a))   # 앞(-Z)은 앞치마 위, 뒤는 몸에 붙음
		belt.append(Vector3(cos(a) * lerpf(0.47, 0.565, fr), 0.17, -sin(a) * lerpf(0.4, 0.505, fr)))
	_tube(g, belt, PackedFloat32Array([0.05]), {"sides": 4, "flat": 0.3, "up": Vector3.UP, "cap": false})
	_extrude(g, PackedVector2Array([Vector2(-0.05, 0.0), Vector2(0.05, 0.0), Vector2(0.06, -0.34), Vector2(-0.02, -0.3)]), PackedFloat32Array([0.025, 0.025, 0.02, 0.02]),
		Transform3D(Basis(Vector3.UP, -1.2), Vector3(-0.5, 0.17, -0.22)))
	_mi(_hips, g, strap)
	g = Geo.new()
	_tube(g, _ellipse(0.06, 0.05, 0.0, 10), PackedFloat32Array([0.012]), {"sides": 4, "cap": false, "xf": Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.17, -0.505))})
	_mi(_hips, g, iron)
	g = Geo.new()  # 칼집의 칼자루 2개
	for k in 2:
		_tube(g, _line(Vector3(-0.49 + k * 0.05, 0.16, -0.22 - k * 0.04), Vector3(-0.5 + k * 0.05, 0.32, -0.24 - k * 0.04), 3), PackedFloat32Array([0.022, 0.022, 0.026]), {"sides": 6})
	_mi(_hips, g, wood)
	# 허리의 고기 갈고리 + 매달린 고깃덩어리
	g = Geo.new()
	for k in 2:
		var hx := 0.42 + k * 0.1
		var hz := -0.3 + k * 0.17
		_tube(g, _bez3(Vector3(hx, 0.22, hz), Vector3(hx + 0.05, 0.02, hz - 0.03), Vector3(hx + 0.07, -0.16, hz + 0.05), Vector3(hx + 0.01, -0.12, hz + 0.08), 9),
			PackedFloat32Array([0.018, 0.017, 0.015, 0.012, 0.01, 0.008, 0.005, 0.003, 0.0]), {"sides": 6})
	_mi(_hips, g, steel)
	g = Geo.new()
	_ell(g, Vector3(0.56, -0.24, -0.05), Vector3(0.1, 0.17, 0.08), {"jit": 0.25, "nf": 6.0, "rot": Basis(Vector3.FORWARD, 0.2)})
	_mi(_hips, g, meat)
	g = Geo.new()
	_tube(g, _line(Vector3(0.53, -0.1, -0.05), Vector3(0.6, -0.42, -0.06), 3), PackedFloat32Array([0.022, 0.016, 0.02]), {"sides": 6})
	_ell(g, Vector3(0.6, -0.43, -0.06), Vector3(0.03, 0.025, 0.03))
	_mi(_hips, g, bone)
	g = Geo.new()
	_ell(g, Vector3(0, -0.04, 0.04), Vector3(0.43, 0.26, 0.36))
	_mi(_hips, g, pants)
	# ---- 다리 + 끈 달린 장화
	for i in 2:
		g = Geo.new()
		_limb(g, Vector3(0, 0.05, 0), Vector3(0, -0.5, 0), 0.22, 0.21, 0.155, 12, 0.03)
		_mi(_leg[i], g, pants)
		g = Geo.new()
		_limb(g, Vector3(0, 0.0, 0), Vector3(0, -0.3, 0), 0.16, 0.15, 0.13, 12)
		_mi(_knee[i], g, pants)
		g = Geo.new()
		_tube(g, _line(Vector3(0, -0.18, 0), Vector3(0, -0.45, 0), 4), PackedFloat32Array([0.155, 0.14, 0.135, 0.13]), {"sides": 12, "jit": 0.04})
		_tube(g, _ellipse(0.16, 0.16, -0.17, 14), PackedFloat32Array([0.022]), {"sides": 5, "cap": false})
		_mi(_knee[i], g, boot)
		g = Geo.new()
		for k in 2:
			_tube(g, _ellipse(0.142, 0.142, -0.25 - k * 0.11, 14), PackedFloat32Array([0.012]), {"sides": 4, "flat": 0.4, "up": Vector3.UP, "cap": false})
		_mi(_knee[i], g, strap)
		g = Geo.new()
		_ell(g, Vector3(0, -0.03, -0.075), Vector3(0.13, 0.075, 0.21))
		_ell(g, Vector3(0, -0.055, -0.08), Vector3(0.135, 0.03, 0.22))
		_mi(_foot[i], g, boot)
	# ---- 굵은 팔
	for i in 2:
		var sg := -1.0 if i == 0 else 1.0
		g = Geo.new()
		_limb(g, Vector3(0, 0.03, 0), Vector3(0, -0.5, 0), 0.2, 0.2, 0.15, 14, 0.04)
		_ell(g, Vector3(0, -0.18, -0.09), Vector3(0.12, 0.16, 0.1))
		_mi(_arm[i], g, skin)
		g = Geo.new()
		_limb(g, Vector3(0, 0.02, 0), Vector3(0, -0.46, 0), 0.165, 0.165, 0.11, 14, 0.04)
		_mi(_elbow[i], g, skin)
		g = Geo.new()
		var gn := Geo.new()
		_hand_geo(g, gn, sg, 0.13, 0.13, 0.145, 0.031, 4, 0.75, 0.016)
		_mi(_hand[i], g, skin)
		_mi(_hand[i], gn, nail)
		_arm[i].rotation = Vector3(0.12, 0, sg * 0.22)
		_elbow[i].rotation.x = 0.3
	_arm[1].rotation.x = 0.35
	_elbow[1].rotation.x = 0.55
	g = Geo.new()  # 오른팔 흉터
	_stitches(g, _bez2(Vector3(0.17, -0.05, -0.08), Vector3(0.2, -0.22, -0.02), Vector3(0.16, -0.38, 0.06), 6), 7, 0.045)
	_mi(_arm[1], g, thread)
	g = Geo.new()  # 왼팔에 감은 쇠사슬
	var wrap := PackedVector3Array()
	for k in 30:
		var t := k / 29.0
		var a := t * TAU * 3.0
		wrap.append(Vector3(cos(a) * 0.17, lerpf(-0.08, -0.38, t), sin(a) * 0.17))
	_chain(g, wrap, 0.075, 0.011)
	_mi(_elbow[0], g, steel)
	# ---- 돼지 가죽 가면 (+ 엄니, 뒤통수의 뻣뻣한 머리털, 입 틈의 이빨)
	g = Geo.new()
	_ell(g, Vector3(0, 0.13, 0.0), Vector3(0.16, 0.17, 0.165), {"jit": 0.02})
	_ell(g, Vector3(0, 0.06, -0.06), Vector3(0.14, 0.11, 0.12))
	_tube(g, _line(Vector3(0, 0.09, -0.12), Vector3(0, 0.08, -0.25), 4), PackedFloat32Array([0.09, 0.085, 0.08, 0.076]), {"sides": 14, "flat": 0.8, "up": Vector3.RIGHT})
	_ell(g, Vector3(0, 0.08, -0.252), Vector3(0.078, 0.064, 0.022))
	for sg: float in [-1.0, 1.0]:
		var ear := PackedVector2Array([Vector2(0, -0.04), Vector2(0.15, -0.09), Vector2(0.07, 0.05), Vector2(0, 0.04)])
		var eb := Basis(Vector3.UP, -sg * 0.3) * Basis(Vector3.FORWARD, sg * 0.9 if sg > 0 else PI - 0.9)
		_extrude(g, ear, PackedFloat32Array([0.008, 0.004, 0.008, 0.01]), Transform3D(eb, Vector3(sg * 0.12, 0.25, 0.02)))
	_mi(_head, g, mask)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.026, 0.08, -0.272), Vector3(0.013, 0.02, 0.008))
		_ell(g, Vector3(sg * 0.062, 0.165, -0.142), Vector3(0.026, 0.022, 0.018), {"jit": 0.2})
	_ell(g, Vector3(0, -0.005, -0.16), Vector3(0.08, 0.014, 0.022))
	_mi(_head, g, dark)
	_eyes_at(_head, [Vector3(-0.062, 0.165, -0.15), Vector3(0.062, 0.165, -0.15)], 0.014, 0.12)
	g = Geo.new()
	_teeth(g, Vector3(0, 0.005, -0.15), 0.07, 0.02, 9, 0.022, 0.007, true)
	for sg: float in [-1.0, 1.0]:
		_tube(g, _bez3(Vector3(sg * 0.08, 0.0, -0.15), Vector3(sg * 0.11, 0.0, -0.19), Vector3(sg * 0.12, 0.06, -0.21), Vector3(sg * 0.1, 0.1, -0.2), 7),
			PackedFloat32Array([0.018, 0.017, 0.015, 0.012, 0.009, 0.005, 0.0]), {"sides": 7})
	_mi(_head, g, bone)
	g = Geo.new()
	for k in 26:
		var a := _rng.randf_range(-1.6, 1.6)
		var b := _rng.randf_range(0.1, 1.2)
		var n := Vector3(sin(a) * cos(b), sin(b), cos(a) * cos(b))
		var p := Vector3(0, 0.13, 0) + Vector3(n.x * 0.16, n.y * 0.17, n.z * 0.165)
		var d := (n + Vector3(0, -0.4, 0.4)).normalized()
		_tube(g, _bez2(p - n * 0.01, p + d * 0.06, p + d * 0.12 + Vector3(0, -0.04, 0), 3), PackedFloat32Array([0.016, 0.01, 0.0]), {"sides": 4})
	_mi(_head, g, hairm)
	_head.scale = Vector3.ONE * 1.32
	g = Geo.new()  # 바느질 자국
	_stitches(g, _bez3(Vector3(0, 0.3, -0.06), Vector3(0, 0.27, -0.13), Vector3(0, 0.22, -0.16), Vector3(0, 0.15, -0.165), 8), 6, 0.025)
	for sg: float in [-1.0, 1.0]:
		_stitches(g, _bez3(Vector3(sg * 0.02, 0.3, -0.08), Vector3(sg * 0.15, 0.24, -0.09), Vector3(sg * 0.17, 0.08, -0.08), Vector3(sg * 0.07, -0.04, -0.12), 10), 7, 0.025)
	_stitches(g, _line(Vector3(-0.06, -0.005, -0.172), Vector3(0.06, -0.005, -0.172), 4), 5, 0.035)
	_tube(g, _ellipse(0.165, 0.17, 0.12, 20, Vector3(0, 0, 0.0)), PackedFloat32Array([0.01]), {"sides": 4, "cap": false})
	_mi(_head, g, thread)
	# ---- 거대한 고기 써는 칼 (던지기 능력 때 숨김)
	axe_in_hand = _node(_hand[1], Vector3(0, -0.12, 0))
	g = Geo.new()
	_tube(g, _line(Vector3(0, -0.02, 0.09), Vector3(0, -0.02, -0.16), 4), PackedFloat32Array([0.028, 0.032, 0.032, 0.028]), {"sides": 8})
	_mi(axe_in_hand, g, wood)
	g = Geo.new()
	var blade := PackedVector2Array([Vector2(0, -0.32), Vector2(0.58, -0.34), Vector2(0.57, 0.03), Vector2(0, 0.035)])
	_extrude(g, blade, PackedFloat32Array([0.003, 0.003, 0.014, 0.014]), Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3.RIGHT), Vector3(0, 0.0, -0.15)))
	_mi(axe_in_hand, g, steel)
	g = Geo.new()
	_tube(g, _ellipse(0.028, 0.028, 0.0, 8, Vector3.ZERO), PackedFloat32Array([0.008]), {"sides": 4, "cap": false, "xf": Transform3D(Basis(Vector3.FORWARD, PI * 0.5), Vector3(0, -0.02, -0.6))})
	for k in 3:
		_ell(g, Vector3(0, -0.02, 0.04 - k * 0.07), Vector3(0.034, 0.008, 0.008))
	_mi(axe_in_hand, g, iron)
	# ---- 왼손의 쇠사슬 + 갈고리 (늘 아래로 늘어짐)
	var dang := _node(_hand[0], Vector3(0, -0.12, 0))
	_danglers.append(dang)
	g = Geo.new()
	_chain(g, _line(Vector3(0, 0, 0), Vector3(0, -0.6, 0), 2), 0.085, 0.012)
	_tube(g, _bez3(Vector3(0, -0.6, 0), Vector3(0, -0.8, 0), Vector3(0, -0.88, -0.15), Vector3(0, -0.74, -0.19), 9),
		PackedFloat32Array([0.022, 0.022, 0.019, 0.014, 0.0]), {"sides": 6})
	_mi(dang, g, steel)


# ================================================================ 역병의 쥐
## 등이 산처럼 굽은 거대한 쥐 인간: 엉겨 붙은 털 뭉치와 털 빠진 맨살의 종기, 너덜너덜한 망토,
## 길쭉한 주둥이와 누런 앞니, 붉게 빛나는 눈, 찢어진 큰 귀, 녹슨 쇠 목줄, 붕대 감은 앙상한 팔과 긴 갈고리 발톱,
## 굵고 비늘진 긴 꼬리, 가슴에 초록빛 플라스크 띠
func _build_rat() -> void:
	_S = 1.42
	_eye_color = Color(1.0, 0.1, 0.06)
	_step = 0.95
	_stride = 0.45
	_bob = 0.04
	_twitch_rate = 0.9
	_twitch_amp = 0.35
	_jitter = 0.06
	_arm_amt = 0.25
	_lean = -0.2
	_skel(1.0, 0.36, 0.42, 0.2, 0.3, 0.82, 0.15, 0.42, 0.4, 0.46, 0.42)
	_head.scale = Vector3.ONE * 1.2
	var fur := _m(Color(0.17, 0.145, 0.125), {"albedo2": Color(0.3, 0.26, 0.21), "mottle": 0.7, "mottle_scale": 7.0, "grime": 0.5,
		"roughness_v": 0.95, "bump": 0.6, "rim": 0.2, "rim_color": Color(0.55, 0.5, 0.45), "blood": 0.15})
	var pink := _m(Color(0.5, 0.33, 0.32), {"albedo2": Color(0.34, 0.2, 0.21), "mottle": 0.65, "mottle_scale": 10.0, "grime": 0.5,
		"roughness_v": 0.75, "bump": 0.4, "blood": 0.3, "backlight_v": 0.25, "rim": 0.1, "veins": 0.15, "vein_color": Color(0.3, 0.05, 0.08)})
	var ear := _m(Color(0.4, 0.25, 0.25), {"albedo2": Color(0.22, 0.12, 0.12), "mottle": 0.5, "roughness_v": 0.75, "backlight_v": 0.9,
		"grime": 0.3, "veins": 0.25, "vein_color": Color(0.35, 0.02, 0.02), "kind": "cloth"})
	var cloak := _m(Color(0.12, 0.13, 0.08), {"albedo2": Color(0.06, 0.065, 0.035), "mottle": 0.55, "mottle_scale": 3.0, "grime": 0.6, "roughness_v": 0.95,
		"bump": 0.5, "kind": "cloth", "sway": 0.025, "blood": 0.2})
	var bandage := _m(Color(0.42, 0.38, 0.3), {"albedo2": Color(0.28, 0.24, 0.17), "mottle": 0.6, "grime": 0.7, "blood": 0.45, "blood_scale": 4.0, "roughness_v": 0.95})
	var tooth := _m(Color(0.72, 0.55, 0.22), {"albedo2": Color(0.45, 0.3, 0.1), "mottle": 0.5, "roughness_v": 0.72, "grime": 0.3})
	var strap := _m(Color(0.15, 0.1, 0.06), {"roughness_v": 0.8, "grime": 0.4})
	var rust := _metal(Color(0.3, 0.2, 0.13), 0.85)
	var nail := _m(Color(0.13, 0.11, 0.08), {"albedo2": Color(0.3, 0.26, 0.18), "mottle": 0.5, "roughness_v": 0.72})
	var glow := _glow_mat(Color(0.45, 1.0, 0.25), 2.5)
	var dark := _dark_mat()
	_spine.rotation.x = -0.62
	_chest.rotation.x = -0.28
	_neck.rotation.x = 0.66
	_head.rotation.x = 0.68
	# ---- 거대한 굽은 등: 몸통 + 혹 + 털 뭉치
	var g := Geo.new()
	_lathe(g, _p([[0.3, -0.38], [0.36, -0.18], [0.39, 0.05], [0.37, 0.25], [0.28, 0.4], [0.14, 0.47], [0.0, 0.5]]),
		{"sides": 18, "sx": 1.18, "sz": 1.0, "jit": 0.08, "nf": 6.0})
	_ell(g, Vector3(0, 0.18, 0.2), Vector3(0.36, 0.34, 0.26), {"jit": 0.1, "nf": 5.0})
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.31, 0.36, 0.0), Vector3(0.16, 0.15, 0.16), {"jit": 0.1})
	var ft := Geo.new()
	for k in 120:
		var a := _rng.randf_range(-PI, PI)
		var y := _rng.randf_range(-0.3, 0.48)
		var rr := 0.38 * (1.0 - maxf(0.0, y - 0.25) * 2.2)
		var base := Vector3(sin(a) * rr * 1.18, y, cos(a) * rr)
		if base.z < -0.12 and y < 0.3:
			continue
		var dir := (Vector3(sin(a), 0.3, cos(a) + 0.8)).normalized()
		var L := _rng.randf_range(0.08, 0.2)
		var w := _rng.randf_range(0.03, 0.05)
		_tube(ft, _bez2(base - dir * 0.03, base + dir * L * 0.5 + Vector3(0, 0.01, 0), base + dir * L + Vector3(0, -0.04, 0.03), 3),
			PackedFloat32Array([w, w * 0.6, 0.0]), {"sides": 4})
	_mi(_chest, g, fur)
	_mi(_chest, ft, fur)
	g = Geo.new()
	_ell(g, Vector3(0, 0.15, 0.04), Vector3(0.33, 0.33, 0.3), {"jit": 0.07})
	_mi(_spine, g, fur)
	g = Geo.new()
	_ell(g, Vector3(0, -0.02, 0.03), Vector3(0.3, 0.22, 0.27), {"jit": 0.06})
	_mi(_hips, g, fur)
	# ---- 너덜너덜한 망토 (등)
	g = Geo.new()
	_lathe(g, _p([[0.25, 0.5], [0.4, 0.38], [0.45, 0.1], [0.5, -0.35], [0.56, -0.75]]),
		{"sides": 16, "sx": 1.1, "sz": 1.0, "a0": PI + 0.2, "a1": TAU - 0.2, "jit": 0.1, "nf": 6.0})
	_tatters(g, -0.72, 0.56 * 1.1, 0.56, 12, 0.15, 0.4, 0.06, PI + 0.25, TAU - 0.25, 0.05)
	_mi(_chest, g, cloak)
	# ---- 플라스크 띠 + 빛나는 플라스크·종기
	g = Geo.new()
	_tube(g, _bez3(Vector3(-0.36, 0.38, -0.12), Vector3(-0.16, 0.2, -0.42), Vector3(0.12, -0.05, -0.42), Vector3(0.36, -0.3, -0.18), 9),
		PackedFloat32Array([0.01]), {"sides": 4, "flat": 2.8, "up": Vector3(0, 0, -1)})
	_mi(_chest, g, strap)
	g = Geo.new()
	for k in 3:
		var fp := Vector3(-0.17 + k * 0.15, 0.22 - k * 0.15, -0.45)
		_ell(g, fp, Vector3(0.05, 0.06, 0.042))
	for bp: Vector3 in [Vector3(0.3, 0.36, 0.08), Vector3(-0.26, 0.4, 0.18), Vector3(0.12, 0.47, 0.16), Vector3(-0.05, 0.3, 0.38), Vector3(0.2, 0.15, 0.4)]:
		_ell(g, bp, Vector3(0.03, 0.025, 0.03))
	_mi(_chest, g, glow)
	g = Geo.new()
	for k in 3:
		var fp := Vector3(-0.17 + k * 0.15, 0.22 - k * 0.15, -0.45)
		_tube(g, _line(fp + Vector3(0, 0.05, 0), fp + Vector3(0, 0.11, 0), 2), PackedFloat32Array([0.017, 0.015]), {"sides": 6})
	_mi(_chest, g, strap)
	# ---- 목: 털 목도리 + 녹슨 쇠 목줄과 끊어진 사슬
	g = Geo.new()
	_tube(g, _line(Vector3(0, -0.08, 0.0), Vector3(0, 0.2, -0.02), 4), PackedFloat32Array([0.17, 0.15, 0.13, 0.12]), {"sides": 12, "jit": 0.12, "nf": 9.0})
	_mi(_neck, g, fur)
	g = Geo.new()
	_tube(g, _ellipse(0.155, 0.15, 0.04, 16), PackedFloat32Array([0.022]), {"sides": 4, "flat": 0.6, "up": Vector3.UP, "cap": false})
	for k in 6:
		var a := k * TAU / 6.0
		_tube(g, _line(Vector3(cos(a) * 0.16, 0.04, -sin(a) * 0.15), Vector3(cos(a) * 0.21, 0.05, -sin(a) * 0.2), 2), PackedFloat32Array([0.014, 0.0]), {"sides": 4})
	_chain(g, _bez2(Vector3(0, 0.0, -0.16), Vector3(0.02, -0.15, -0.2), Vector3(0.0, -0.3, -0.16), 5), 0.06, 0.009)
	_mi(_neck, g, rust)
	# ---- 머리: 길쭉한 주둥이
	g = Geo.new()
	_tube(g, PackedVector3Array([Vector3(0, 0.03, 0.15), Vector3(0, 0.05, 0.06), Vector3(0, 0.04, -0.07), Vector3(0, 0.0, -0.21), Vector3(0, -0.035, -0.35), Vector3(0, -0.05, -0.43), Vector3(0, -0.055, -0.46)]),
		PackedFloat32Array([0.0, 0.15, 0.16, 0.115, 0.072, 0.042, 0.0]), {"sides": 16, "flat": 1.2, "up": Vector3.UP, "jit": 0.06, "nf": 9.0})
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.085, 0.07, -0.1), Vector3(0.045, 0.035, 0.05))
	_mi(_head, g, fur)
	g = Geo.new()
	_ell(g, Vector3(0, -0.05, -0.452), Vector3(0.036, 0.028, 0.026))
	_mi(_head, g, pink)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.014, -0.045, -0.474), Vector3(0.008, 0.007, 0.005))
		_ell(g, Vector3(sg * 0.124, 0.102, -0.128), Vector3(0.03, 0.026, 0.024))
	_mi(_head, g, dark)
	_jaw = _node(_head, Vector3(0, -0.07, -0.04))
	g = Geo.new()
	_tube(g, _line(Vector3(0, 0, 0.07), Vector3(0, -0.025, -0.33), 5), PackedFloat32Array([0.0, 0.085, 0.066, 0.042, 0.0]), {"sides": 12, "jit": 0.05})
	_mi(_jaw, g, fur)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_tube(g, _bez2(Vector3(sg * 0.013, -0.06, -0.42), Vector3(sg * 0.015, -0.1, -0.432), Vector3(sg * 0.012, -0.135, -0.418), 4), PackedFloat32Array([0.015, 0.014, 0.011, 0.004]), {"sides": 5, "flat": 0.5})
	for k in 5:
		for sg: float in [-1.0, 1.0]:
			var tp := Vector3(sg * (0.05 - k * 0.004), -0.06, -0.12 - k * 0.05)
			_tube(g, _line(tp, tp + Vector3(0, -0.025, -0.004), 2), PackedFloat32Array([0.007, 0.0]), {"sides": 4})
	_mi(_head, g, tooth)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_tube(g, _bez2(Vector3(sg * 0.01, -0.025, -0.3), Vector3(sg * 0.011, 0.025, -0.315), Vector3(sg * 0.009, 0.055, -0.305), 3), PackedFloat32Array([0.01, 0.008, 0.004]), {"sides": 5})
	_mi(_jaw, g, tooth)
	g = Geo.new()  # 수염
	for sg: float in [-1.0, 1.0]:
		for k in 6:
			var w0 := Vector3(sg * 0.035, -0.04 + k * 0.007, -0.39)
			_tube(g, _bez2(w0, w0 + Vector3(sg * 0.15, 0.01 - k * 0.012, 0.03), w0 + Vector3(sg * 0.3, -0.05 - k * 0.03, 0.08), 4),
				PackedFloat32Array([0.0035, 0.0025, 0.0012]), {"sides": 3, "cap": false})
	_mi(_head, g, nail)
	g = Geo.new()  # 크고 얇은 귀 (찢어짐)
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.14, 0.15, 0.08), Vector3(0.095, 0.11, 0.016), {"rot": Basis(Vector3.UP, sg * 0.9) * Basis(Vector3.FORWARD, -sg * 0.7) * Basis(Vector3.RIGHT, -0.5), "jit": 0.5, "nf": 9.0})
	_mi(_head, g, ear)
	_eyes_at(_head, [Vector3(-0.13, 0.106, -0.138), Vector3(0.13, 0.106, -0.138)], 0.022, 0.18)
	# ---- 팔: 털 덮인 굵은 위팔 + 붕대 감은 앙상한 아래팔, 긴 갈고리 발톱
	for i in 2:
		var sg := -1.0 if i == 0 else 1.0
		g = Geo.new()
		_limb(g, Vector3(0, 0.04, 0), Vector3(0, -0.42, 0), 0.12, 0.11, 0.075, 10, 0.15)
		_mi(_arm[i], g, fur)
		g = Geo.new()
		_limb(g, Vector3(0, 0.01, 0), Vector3(0, -0.4, 0), 0.07, 0.062, 0.042, 9)
		_mi(_elbow[i], g, pink)
		g = Geo.new()
		var wr := PackedVector3Array()
		for k in 22:
			var t := k / 21.0
			var a := t * TAU * 3.5
			wr.append(Vector3(cos(a) * 0.066 * (1.0 - t * 0.3), lerpf(-0.08, -0.34, t) + sin(a) * 0.01, sin(a) * 0.066 * (1.0 - t * 0.3)))
		_tube(g, wr, PackedFloat32Array([0.016]), {"sides": 4, "flat": 0.35})
		_tatters_line(g, Vector3(0, -0.3, 0.04), 0.03, 2, 0.08, 0.16, 0.014)
		_mi(_elbow[i], g, bandage)
		g = Geo.new()
		var gn := Geo.new()
		_hand_geo(g, gn, sg, 0.09, 0.09, 0.17, 0.016, 4, 0.55, 0.075)
		_mi(_hand[i], g, pink)
		_mi(_hand[i], gn, nail)
		_arm[i].rotation = Vector3(0.6, 0, sg * 0.22)
		_elbow[i].rotation.x = 0.85
		_hand[i].rotation.x = 0.3
	# ---- 뒤로 꺾인 짐승 다리
	for i in 2:
		g = Geo.new()
		_limb(g, Vector3(0, 0.06, 0), Vector3(0, -0.46, 0), 0.21, 0.19, 0.12, 12, 0.12)
		_mi(_leg[i], g, fur)
		g = Geo.new()
		_limb(g, Vector3(0, 0.0, 0), Vector3(0, -0.42, 0), 0.115, 0.1, 0.065, 10, 0.1)
		_mi(_knee[i], g, fur)
		g = Geo.new()
		var gn := Geo.new()
		_limb(g, Vector3(0, 0.0, 0), Vector3(0, -0.2, 0), 0.05, 0.048, 0.04, 8)
		for k in 3:
			var x := (k - 1) * 0.04
			_tube(g, _bez2(Vector3(x, -0.2, 0), Vector3(x * 1.4, -0.22, -0.08), Vector3(x * 1.6, -0.21, -0.15), 4), PackedFloat32Array([0.022, 0.019, 0.016, 0.013]), {"sides": 6})
			_tube(gn, _bez2(Vector3(x * 1.6, -0.21, -0.145), Vector3(x * 1.7, -0.215, -0.19), Vector3(x * 1.7, -0.235, -0.215), 3), PackedFloat32Array([0.013, 0.008, 0.0]), {"sides": 5})
		_mi(_foot[i], g, pink)
		_mi(_foot[i], gn, nail)
		_leg[i].rotation.x = 0.5
		_knee[i].rotation.x = -1.1
		_foot[i].rotation.x = 0.6
	# ---- 굵고 비늘진 긴 꼬리 (마디마다 흔들림)
	var parent: Node3D = _hips
	var pos := Vector3(0, -0.05, 0.26)
	for k in 8:
		var seg := _node(parent, pos)
		seg.rotation.x = 0.55 if k == 0 else (0.2 if k < 3 else -0.08)
		var r0 := lerpf(0.085, 0.014, float(k) / 8.0)
		var r1 := lerpf(0.085, 0.014, float(k + 1) / 8.0)
		g = Geo.new()
		_tube(g, _line(Vector3.ZERO, Vector3(0, 0, 0.24), 4), PackedFloat32Array([r0, (r0 + r1) * 0.5 * 1.06, (r0 + r1) * 0.5, r1]), {"sides": 8, "jit": 0.05, "nf": 30.0})
		_mi(seg, g, pink)
		_tail.append(seg)
		parent = seg
		pos = Vector3(0, 0, 0.23)


# ================================================================ 거미 여왕
## 거대한 거미 몸통에 붙은 앙상한 여왕의 상체: 머리 위로 솟은 8개의 굵은 마디 다리(가시·털),
## 얼굴 가득 붉은 눈 8개, 휘어진 독니, 사마귀 같은 거대한 낫 팔, 가시 왕관과 등까지 늘어진 검은 머리,
## 마디진 큰 배에 붉게 빛나는 모래시계 무늬와 털
func _build_spider() -> void:
	_rig = "spider"
	_S = 1.3
	_eye_color = Color(1.0, 0.06, 0.08)
	_step = 1.2
	_twitch_rate = 0.6
	_twitch_amp = 0.5
	var chitin := _m(Color(0.065, 0.05, 0.065), {"albedo2": Color(0.17, 0.1, 0.15), "mottle": 0.65, "mottle_scale": 5.0, "grime": 0.25,
		"roughness_v": 0.72, "bump": 0.3, "rim": 0.3, "rim_color": Color(0.55, 0.25, 0.5), "metallic_v": 0.05})
	var chitin2 := _m(Color(0.13, 0.05, 0.06), {"albedo2": Color(0.06, 0.03, 0.04), "mottle": 0.6, "mottle_scale": 4.0, "grime": 0.25,
		"roughness_v": 0.72, "bump": 0.3, "rim": 0.3, "rim_color": Color(0.6, 0.2, 0.3)})
	var skin := _m(Color(0.22, 0.23, 0.24), {"albedo2": Color(0.13, 0.13, 0.15), "mottle": 0.65, "mottle_scale": 7.0, "grime": 0.45,
		"roughness_v": 0.75, "bump": 0.35, "rim": 0.18, "rim_color": Color(0.5, 0.4, 0.6), "veins": 0.3, "vein_color": Color(0.3, 0.0, 0.06), "backlight_v": 0.1})
	var hairm := _m(Color(0.08, 0.06, 0.06), {"roughness_v": 0.9, "grime": 0.0, "kind": "cloth"})
	var hair := _hair_mat(Color(0.02, 0.018, 0.02))
	var mark := _glow_mat(Color(1.0, 0.08, 0.05), 2.2)
	_hips = _node(self, Vector3(0, 0.95, 0.05))
	var g := Geo.new()
	_ell(g, Vector3(0, 0, 0), Vector3(0.4, 0.26, 0.48), {"jit": 0.03})
	_ell(g, Vector3(0, 0.12, 0.05), Vector3(0.3, 0.12, 0.36), {"jit": 0.04})
	_mi(_hips, g, chitin)
	# ---- 배: 마디진 큰 몸통 + 모래시계 무늬 + 털 + 실젖
	_abd = _node(_hips, Vector3(0, 0.1, 0.38))
	_abd.rotation.x = -0.35
	g = Geo.new()
	_ell(g, Vector3(0, 0.08, 0.62), Vector3(0.62, 0.52, 0.78), {"sides": 22, "rings": 14, "jit": 0.025})
	var fz := Geo.new()
	for k in 110:
		var a := _rng.randf_range(0.0, TAU)
		var b := _rng.randf_range(-0.4, 1.3)
		var n := Vector3(cos(a) * cos(b), sin(b), sin(a) * cos(b))
		if n.y < -0.2:
			continue
		var p := Vector3(0, 0.08, 0.62) + Vector3(n.x * 0.62, n.y * 0.52, n.z * 0.78)
		_tube(fz, _line(p - n * 0.01, p + (n + Vector3(0, 0, 0.5)).normalized() * _rng.randf_range(0.06, 0.14), 2), PackedFloat32Array([0.012, 0.0]), {"sides": 3})
	_mi(_abd, g, chitin)
	_mi(_abd, fz, hairm)
	g = Geo.new()
	for k in 4:  # 배 마디
		var z := 0.18 + k * 0.24
		var rr := sqrt(maxf(0.0, 1.0 - pow((z - 0.62) / 0.78, 2.0)))
		_tube(g, _ellipse(0.625 * rr, 0.525 * rr, 0.0, 22, Vector3.ZERO), PackedFloat32Array([0.022]), {"sides": 4, "cap": false,
			"xf": Transform3D(Basis(Vector3.RIGHT, PI * 0.5), Vector3(0, 0.08, z))})
	for sg: float in [-1.0, 1.0]:
		_tube(g, _bez2(Vector3(sg * 0.05, 0.0, 1.36), Vector3(sg * 0.07, -0.04, 1.44), Vector3(sg * 0.06, -0.1, 1.48), 4), PackedFloat32Array([0.04, 0.03, 0.015, 0.0]), {"sides": 6})
	_mi(_abd, g, chitin2)
	g = Geo.new()
	_ell(g, Vector3(0, 0.6, 0.42), Vector3(0.13, 0.03, 0.17), {"rot": Basis(Vector3.RIGHT, 0.3)})
	_ell(g, Vector3(0, 0.58, 0.8), Vector3(0.15, 0.03, 0.14), {"rot": Basis(Vector3.RIGHT, -0.4)})
	_ell(g, Vector3(0, 0.6, 0.61), Vector3(0.035, 0.025, 0.06))
	_ell(g, Vector3(0, 0.06, 1.4), Vector3(0.05, 0.05, 0.03))
	_mi(_abd, g, mark)
	# ---- 사람 상체 (넓은 어깨, 갈비뼈, 등의 키틴 판)
	_spine = _node(_hips, Vector3(0, 0.18, -0.36))
	_spine.rotation.x = -0.1
	_chest = _node(_spine, Vector3(0, 0.34, 0))
	_neck = _node(_chest, Vector3(0, 0.44, 0))
	_head = _node(_neck, Vector3(0, 0.11, 0))
	g = Geo.new()
	_lathe(g, _p([[0.0, -0.1], [0.2, -0.05], [0.16, 0.12], [0.175, 0.34]]), {"sides": 16, "sx": 1.4, "sz": 0.9})
	_mi(_spine, g, skin)
	g = Geo.new()
	for k in 4:
		_ell(g, Vector3(0, 0.04 + k * 0.1, 0.13), Vector3(0.08, 0.05, 0.06))
	_mi(_spine, g, chitin)
	g = Geo.new()
	_lathe(g, _p([[0.17, -0.04], [0.21, 0.1], [0.235, 0.26], [0.2, 0.38], [0.08, 0.45], [0.0, 0.46]]), {"sides": 18, "sx": 1.42, "sz": 0.85})
	for sg: float in [-1.0, 1.0]:
		for k in 4:
			var y := 0.29 - k * 0.06
			_tube(g, _bez3(Vector3(sg * 0.025, y, -0.19), Vector3(sg * 0.12, y - 0.01, -0.196), Vector3(sg * 0.23, y - 0.03, -0.15), Vector3(sg * 0.3, y - 0.05, -0.04), 5),
				PackedFloat32Array([0.006, 0.011, 0.011, 0.009, 0.005]), {"sides": 5})
		_tube(g, _bez3(Vector3(sg * 0.02, 0.43, -0.1), Vector3(sg * 0.12, 0.42, -0.11), Vector3(sg * 0.21, 0.42, -0.08), Vector3(sg * 0.28, 0.41, -0.02), 5),
			PackedFloat32Array([0.01, 0.014, 0.013, 0.012, 0.008]), {"sides": 6})
	_mi(_chest, g, skin)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.31, 0.38, 0.0), Vector3(0.15, 0.09, 0.15), {"rot": Basis(Vector3.FORWARD, sg * 0.4)})
		for k in 3:
			var b0 := Vector3(sg * (0.29 + k * 0.03), 0.43, -0.04 + k * 0.05)
			_tube(g, _bez2(b0, b0 + Vector3(sg * 0.08, 0.12, 0.03), b0 + Vector3(sg * 0.1, 0.24 - k * 0.04, 0.1), 4), PackedFloat32Array([0.03, 0.018, 0.008, 0.0]), {"sides": 5})
	_ell(g, Vector3(0, 0.25, 0.14), Vector3(0.16, 0.16, 0.07))
	_mi(_chest, g, chitin)
	g = Geo.new()
	_tube(g, _line(Vector3(0, -0.04, 0), Vector3(0, 0.13, -0.01), 3), PackedFloat32Array([0.055, 0.046, 0.044]), {"sides": 9})
	_mi(_neck, g, skin)
	# ---- 머리: 길쭉한 민머리, 눈 8개, 독니, 가시 왕관, 등까지 늘어진 검은 머리
	g = Geo.new()
	_ell(g, Vector3(0, 0.12, 0.01), Vector3(0.082, 0.12, 0.1))
	_ell(g, Vector3(0, 0.05, -0.04), Vector3(0.06, 0.055, 0.065))
	_mi(_head, g, skin)
	g = Geo.new()
	for k in 7:
		var a := -1.0 + k * 0.333
		var hk := 1.0 + 0.5 * (1.0 - absf(a))
		_tube(g, _bez3(Vector3(sin(a) * 0.065, 0.2, cos(a) * 0.05), Vector3(sin(a) * 0.1, 0.28, cos(a) * 0.07 + 0.03), Vector3(sin(a) * 0.12, 0.33 + 0.06 * hk, cos(a) * 0.06 + 0.08), Vector3(sin(a) * 0.12, 0.36 + 0.1 * hk, cos(a) * 0.04 + 0.14), 6),
			PackedFloat32Array([0.02, 0.016, 0.012, 0.008, 0.004, 0.0]), {"sides": 5})
	for sg: float in [-1.0, 1.0]:
		_tube(g, _bez3(Vector3(sg * 0.026, 0.035, -0.085), Vector3(sg * 0.04, -0.03, -0.13), Vector3(sg * 0.022, -0.09, -0.14), Vector3(sg * 0.004, -0.12, -0.11), 7),
			PackedFloat32Array([0.026, 0.022, 0.018, 0.013, 0.008, 0.004, 0.0]), {"sides": 6})
	_mi(_head, g, chitin2)
	g = Geo.new()
	_ell(g, Vector3(0, 0.035, -0.098), Vector3(0.022, 0.03, 0.012))
	_mi(_head, g, _dark_mat())
	g = Geo.new()
	for k in 6:
		var tx := -0.015 + k * 0.006
		_tube(g, _line(Vector3(tx, 0.06, -0.104), Vector3(tx * 0.8, 0.04 - (k % 2) * 0.01, -0.106), 2), PackedFloat32Array([0.0035, 0.0]), {"sides": 4})
		_tube(g, _line(Vector3(tx, 0.008, -0.104), Vector3(tx * 0.8, 0.026 + (k % 2) * 0.008, -0.106), 2), PackedFloat32Array([0.0035, 0.0]), {"sides": 4})
	_mi(_head, g, _m(Color(0.7, 0.62, 0.48), {"roughness_v": 0.72, "grime": 0.4}))
	_eyes_at(_head, [Vector3(-0.034, 0.13, -0.094), Vector3(0.034, 0.13, -0.094), Vector3(-0.02, 0.168, -0.088), Vector3(0.02, 0.168, -0.088),
		Vector3(-0.062, 0.152, -0.072), Vector3(0.062, 0.152, -0.072), Vector3(-0.066, 0.105, -0.068), Vector3(0.066, 0.105, -0.068)], 0.015, 0.16)
	g = Geo.new()
	_hair(g, Vector3(0, 0.12, 0.01), Vector3(0.082, 0.12, 0.1), 50, 0.4, 0.75, 0.024, -1.5, 1.5, 0.05)
	_mi(_head, g, hair)
	_head.scale = Vector3.ONE * 1.25
	# ---- 거대한 낫 팔
	for i in 2:
		var sg := -1.0 if i == 0 else 1.0
		_arm[i] = _node(_chest, Vector3(sg * 0.32, 0.35, 0))
		_elbow[i] = _node(_arm[i], Vector3(0, -0.4, 0))
		_hand[i] = _node(_elbow[i], Vector3(0, -0.38, 0))
		g = Geo.new()
		_limb(g, Vector3(0, 0.02, 0), Vector3(0, -0.4, 0), 0.075, 0.068, 0.048, 10)
		_mi(_arm[i], g, skin)
		g = Geo.new()
		_limb(g, Vector3(0, 0.01, 0), Vector3(0, -0.38, 0), 0.05, 0.048, 0.042, 9)
		_ell(g, Vector3(0, 0.0, 0), Vector3(0.06, 0.06, 0.06))
		for k in 4:
			_tube(g, _line(Vector3(0, -0.06 - k * 0.08, 0.035), Vector3(sg * 0.012, -0.09 - k * 0.08, 0.1), 2), PackedFloat32Array([0.016, 0.0]), {"sides": 4})
		_mi(_elbow[i], g, chitin)
		g = Geo.new()
		_tube(g, _bez3(Vector3(0, 0.02, 0), Vector3(0, -0.2, -0.08), Vector3(0, -0.44, -0.05), Vector3(0, -0.6, 0.11), 10),
			PackedFloat32Array([0.042, 0.045, 0.043, 0.038, 0.032, 0.026, 0.02, 0.013, 0.007, 0.0]), {"sides": 7, "flat": 0.33, "up": Vector3(0, 0, -1)})
		for k in 3:
			var cz := lerpf(0.05, -0.05, k / 2.0)
			_tube(g, _bez2(Vector3(0, -0.02, cz * 0.5), Vector3(sg * 0.025, -0.14, cz), Vector3(sg * 0.025, -0.22, cz * 2.0 + 0.04), 5), PackedFloat32Array([0.018, 0.013, 0.008, 0.004, 0.0]), {"sides": 5})
		for k in 5:  # 낫 안쪽 톱니
			var tp := _bez3(Vector3(0, 0.02, 0), Vector3(0, -0.2, -0.08), Vector3(0, -0.44, -0.05), Vector3(0, -0.6, 0.11), 10)[2 + k]
			_tube(g, _line(tp, tp + Vector3(0, -0.01, 0.05), 2), PackedFloat32Array([0.01, 0.0]), {"sides": 4})
		_mi(_hand[i], g, chitin2)
		_arm[i].rotation = Vector3(0.55, 0, sg * 0.3)
		_elbow[i].rotation.x = 1.2
		_hand[i].rotation.x = 0.4
	# ---- 다리 8개 (무릎이 몸보다 높이 솟음), 굵은 마디·가시·털
	for i in 8:
		var side := -1.0 if i < 4 else 1.0
		var j := i % 4
		var hip := _node(_hips, Vector3(side * 0.28, 0.02, -0.28 + j * 0.19))
		hip.rotation.y = side * (0.85 - j * 0.52)
		var front := j == 0
		var kx := 0.48 if not front else 0.44
		var ky := 0.74 if not front else 0.84
		var knee := _node(hip, Vector3(side * kx, ky, 0))
		g = Geo.new()
		var up_pts := _bez3(Vector3(0, 0, 0), Vector3(side * 0.13, 0.4, 0), Vector3(side * 0.31, 0.7, 0), Vector3(side * kx, ky, 0), 8)
		_tube(g, up_pts, PackedFloat32Array([0.11, 0.1, 0.092, 0.085, 0.08, 0.075, 0.07, 0.066]), {"sides": 9})
		_ell(g, Vector3(side * kx, ky, 0), Vector3(0.08, 0.08, 0.08))
		_ell(g, up_pts[3], Vector3(0.095, 0.095, 0.095))
		for k in 3:
			var p0 := up_pts[2 + k * 2]
			_tube(g, _line(p0, p0 + Vector3(side * 0.03, 0.09, 0.03 * (k % 2 * 2 - 1)), 2), PackedFloat32Array([0.016, 0.0]), {"sides": 4})
		_mi(hip, g, chitin)
		g = Geo.new()
		var fx := 1.28 if not front else 1.34
		var foot := Vector3(side * fx, -0.95, 0) - Vector3(side * kx, ky, 0)
		var pts := _bez3(Vector3.ZERO, Vector3(side * 0.25, -0.05, 0), foot + Vector3(-side * 0.05, 0.8, 0), foot, 11)
		_tube(g, pts, PackedFloat32Array([0.068, 0.064, 0.06, 0.055, 0.05, 0.044, 0.038, 0.031, 0.022, 0.013, 0.0]), {"sides": 8})
		_ell(g, pts[5], Vector3(0.056, 0.056, 0.056))
		for k in 5:  # 다리 가시
			var p0 := pts[2 + k * 2 - (1 if k == 4 else 0)]
			_tube(g, _line(p0, p0 + Vector3(side * 0.05, 0.08, 0.025 * (k % 2 * 2 - 1)), 2), PackedFloat32Array([0.013, 0.0]), {"sides": 4})
		for k in 8:  # 다리 털
			var p0 := pts[1 + k]
			_tube(g, _line(p0, p0 + Vector3(_rng.randf_range(-0.04, 0.04), -0.06, _rng.randf_range(-0.05, 0.05)), 2), PackedFloat32Array([0.006, 0.0]), {"sides": 3})
		_mi(knee, g, chitin)
		_sp_legs.append([hip, knee])


# ================================================================ 마네킹
## 거대한 남자 마네킹: 조각 같은 근육질 플라스틱 몸통(금 가고 깨져 속이 빈 구멍), 드러난 볼 관절과 볼트,
## 찢어진 정장 재킷과 늘어진 넥타이, 깨진 오른팔 끝과 삐져나온 철사, 손목의 가격표,
## 얼굴 없는 달걀 머리의 움푹 패인 눈구멍 속 작은 흰 빛. 고개를 옆으로 꺾고 서서 미동도 없음. 움직일 땐 뚝뚝 끊김
func _build_mannequin() -> void:
	_S = 1.3
	_eye_color = Color(0.9, 0.95, 1.0)
	_jerk_fps = 7.0
	_stride = 0.55
	_arm_amt = 0.15
	_twitch_rate = 0.5
	_twitch_amp = 0.9
	_bob = 0.03
	_skel(1.08, 0.3, 0.5, 0.13, 0.35, 0.86, 0.13, 0.4, 0.37, 0.52, 0.49)
	var plastic := _m(Color(0.5, 0.47, 0.42), {"albedo2": Color(0.36, 0.32, 0.28), "mottle": 0.4, "mottle_scale": 3.0, "grime": 0.55,
		"grime_color": Color(0.16, 0.12, 0.09), "roughness_v": 0.72, "cracks": 1.0, "crack_scale": 3.2, "bump": 0.1, "blood": 0.2,
		"blood_scale": 2.0, "rim": 0.14, "rim_color": Color(0.6, 0.65, 0.8)})
	var joint := _m(Color(0.3, 0.27, 0.25), {"metallic_v": 0.35, "roughness_v": 0.72, "grime": 0.5})
	var wire := _metal(Color(0.4, 0.36, 0.3), 0.75)
	var suit := _m(Color(0.09, 0.095, 0.11), {"albedo2": Color(0.05, 0.05, 0.06), "mottle": 0.5, "mottle_scale": 3.0, "grime": 0.55,
		"grime_color": Color(0.16, 0.14, 0.1), "blood": 0.3, "roughness_v": 0.92, "bump": 0.4, "kind": "cloth", "sway": 0.02, "rim": 0.15, "rim_color": Color(0.5, 0.55, 0.7)})
	var shirt := _m(Color(0.45, 0.43, 0.38), {"albedo2": Color(0.3, 0.28, 0.24), "mottle": 0.5, "grime": 0.7, "blood": 0.45, "roughness_v": 0.95, "kind": "cloth", "sway": 0.02})
	var tie := _m(Color(0.32, 0.03, 0.04), {"albedo2": Color(0.18, 0.01, 0.02), "mottle": 0.4, "grime": 0.4, "roughness_v": 0.9, "kind": "cloth", "sway": 0.03})
	var paper := _m(Color(0.6, 0.56, 0.45), {"grime": 0.5, "roughness_v": 0.95, "kind": "cloth", "sway": 0.04})
	var dark := _dark_mat()
	# ---- 조각 같은 몸통 (가슴·복근·어깨 근육)
	var g := Geo.new()
	_lathe(g, _p([[0.0, -0.03], [0.18, -0.02], [0.22, 0.08], [0.255, 0.22], [0.27, 0.33], [0.235, 0.44], [0.09, 0.5], [0.0, 0.51]]), {"sides": 22, "sx": 1.28, "sz": 0.72})
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.13, 0.3, -0.14), Vector3(0.13, 0.09, 0.058))
		_ell(g, Vector3(sg * 0.18, 0.46, 0.0), Vector3(0.15, 0.06, 0.12))
		_ell(g, Vector3(sg * 0.17, 0.25, 0.1), Vector3(0.12, 0.17, 0.07))
	_mi(_chest, g, plastic)
	g = Geo.new()
	_lathe(g, _p([[0.0, 0.0], [0.18, 0.02], [0.175, 0.15], [0.19, 0.29], [0.0, 0.31]]), {"sides": 18, "sx": 1.18, "sz": 0.74})
	for r in 3:
		for sg: float in [-1.0, 1.0]:
			_ell(g, Vector3(sg * 0.05, 0.06 + r * 0.08, -0.12), Vector3(0.045, 0.035, 0.026))
	_mi(_spine, g, plastic)
	g = Geo.new()
	_lathe(g, _p([[0.0, -0.15], [0.15, -0.13], [0.21, -0.03], [0.2, 0.05], [0.17, 0.1], [0.0, 0.11]]), {"sides": 20, "sx": 1.18, "sz": 0.8})
	_mi(_hips, g, plastic)
	g = Geo.new()  # 허리 이음매 + 목 볼트
	_tube(g, _ellipse(0.18, 0.13, 0.015, 18), PackedFloat32Array([0.014]), {"sides": 5, "cap": false})
	_ell(g, Vector3(0, 0.0, 0), Vector3(0.05, 0.05, 0.05))
	_mi(_spine, g, joint)
	g = Geo.new()  # 깨진 구멍들 (속이 빔)
	for hp: Vector3 in [Vector3(0.14, 0.18, -0.15), Vector3(-0.09, 0.08, -0.17), Vector3(0.2, 0.34, -0.07), Vector3(-0.16, 0.32, 0.13), Vector3(0.05, 0.42, -0.13)]:
		_ell(g, hp, Vector3(0.045, 0.038, 0.03), {"jit": 0.4, "nf": 22.0})
	_mi(_chest, g, dark)
	g = Geo.new()
	for k in 4:
		var a := k * 1.7
		var w0 := Vector3(0.14 + cos(a) * 0.01, 0.18 + sin(a) * 0.01, -0.15)
		_tube(g, _bez2(w0, w0 + Vector3(cos(a) * 0.03, sin(a) * 0.03, -0.04), w0 + Vector3(cos(a) * 0.06, sin(a) * 0.05 - 0.03, -0.05), 4), PackedFloat32Array([0.0035]), {"sides": 4})
	_mi(_chest, g, wire)
	# ---- 찢어진 정장 재킷 (앞이 열림) + 셔츠 깃 + 넥타이
	var rag := func(p: Vector3) -> Vector3:
		if p.y < -0.25:
			p.y += _noise.get_noise_2d(atan2(p.x, p.z) * 6.0, 2.0) * 0.08
		return p
	g = Geo.new()
	_lathe(g, _p([[0.1, 0.58], [0.18, 0.56], [0.27, 0.51], [0.305, 0.4], [0.3, 0.26], [0.28, 0.08], [0.265, -0.1], [0.28, -0.35], [0.3, -0.62]]),
		{"sides": 24, "sx": 1.3, "sz": 0.8, "a0": PI * 0.5 + 0.42, "a1": PI * 2.5 - 0.42, "jit": 0.03, "deform": rag})
	_tatters(g, -0.58, 0.3 * 1.3, 0.3 * 0.8, 11, 0.08, 0.24, 0.05, PI + 0.3, TAU - 0.3, 0.02)
	for sg: float in [-1.0, 1.0]:  # 접힌 옷깃
		var lap := PackedVector2Array([Vector2(0.0, 0.0), Vector2(0.07, 0.03), Vector2(0.06, 0.24), Vector2(0.0, 0.2)])
		_extrude(g, lap, PackedFloat32Array([0.008, 0.008, 0.008, 0.008]), Transform3D(Basis(Vector3.UP, sg * 0.5) * Basis(Vector3.FORWARD, -sg * 0.25), Vector3(sg * 0.1, 0.24, -0.19)))
	_mi(_chest, g, suit)
	g = Geo.new()
	_lathe(g, _p([[0.075, 0.45], [0.09, 0.53], [0.075, 0.6]]), {"sides": 14, "a0": PI * 0.5 + 0.35, "a1": PI * 2.5 - 0.35})
	_mi(_chest, g, shirt)
	g = Geo.new()
	_ell(g, Vector3(0, 0.5, -0.085), Vector3(0.02, 0.02, 0.012))
	_tube(g, _bez3(Vector3(0, 0.49, -0.09), Vector3(0.01, 0.38, -0.19), Vector3(0.03, 0.22, -0.2), Vector3(0.06, 0.08, -0.17), 7), PackedFloat32Array([0.0035, 0.0045, 0.005, 0.0055, 0.0055, 0.004, 0.0]), {"sides": 4, "flat": 7.0, "up": Vector3(0, 0, -1)})
	_mi(_chest, g, tie)
	g = Geo.new()  # 목
	_tube(g, _line(Vector3(0, -0.02, 0), Vector3(0, 0.13, 0), 3), PackedFloat32Array([0.055, 0.05, 0.05]), {"sides": 12})
	_mi(_neck, g, plastic)
	_mi(_neck, _ell_geo(Vector3(0, 0.0, 0), Vector3(0.065, 0.045, 0.065)), joint)
	# ---- 얼굴 없는 달걀 머리
	g = Geo.new()
	_ell(g, Vector3(0, 0.135, 0), Vector3(0.098, 0.135, 0.114), {"sides": 20, "rings": 12})
	_ell(g, Vector3(0, 0.115, -0.108), Vector3(0.015, 0.033, 0.015))
	_ell(g, Vector3(0, 0.17, -0.086), Vector3(0.075, 0.018, 0.03))
	_mi(_head, g, plastic)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.037, 0.143, -0.1), Vector3(0.021, 0.011, 0.012), {"rot": Basis(Vector3.FORWARD, sg * 0.18)})
	_ell(g, Vector3(-0.055, 0.17, -0.062), Vector3(0.05, 0.06, 0.04), {"jit": 0.5, "nf": 18.0})
	_ell(g, Vector3(0.0, 0.06, -0.106), Vector3(0.018, 0.0035, 0.005))
	_mi(_head, g, dark)
	g = Geo.new()  # 깨진 얼굴 가장자리 조각
	for k in 7:
		var a := k * TAU / 7.0
		var e0 := Vector3(-0.055 + cos(a) * 0.048, 0.17 + sin(a) * 0.058, -0.09)
		_tube(g, _line(e0, e0 + Vector3(cos(a) * 0.012, sin(a) * 0.012, -0.004), 2), PackedFloat32Array([0.008, 0.0]), {"sides": 3})
	_mi(_head, g, plastic)
	_head.scale = Vector3.ONE * 1.15
	# ---- 몸에 엉겨 붙은 다른 마네킹 조각: 등에서 돋아난 세 번째 팔 + 오른 어깨의 반쪽 얼굴
	g = Geo.new()
	var xa := PackedVector3Array([Vector3(-0.2, 0.4, 0.14), Vector3(-0.34, 0.36, 0.2), Vector3(-0.46, 0.22, 0.2)])
	_tube(g, xa, PackedFloat32Array([0.07, 0.068, 0.062]), {"sides": 12})
	var fa := _bez2(Vector3(-0.46, 0.22, 0.2), Vector3(-0.56, 0.0, 0.12), Vector3(-0.52, -0.22, -0.02), 6)
	_tube(g, fa, PackedFloat32Array([0.055, 0.052, 0.048, 0.045, 0.042, 0.04]), {"sides": 12})
	var gx := Geo.new()
	var gxn := Geo.new()
	_hand_geo(gx, gxn, -1.0, 0.1, 0.085, 0.15, 0.016, 4, 0.35, 0.0)
	var hx := Transform3D(Basis(Vector3.RIGHT, -0.4) * Basis(Vector3.FORWARD, -0.15), fa[5] + Vector3(0, -0.02, 0))
	for k in gx.v.size():
		gx.v[k] = hx * gx.v[k]
	for k in gx.v.size():
		g.add(gx.v[k], gx.uv[k], gx.col[k])
	var off := g.v.size() - gx.v.size()
	for k in range(0, gx.idx.size(), 3):
		g.idx.append(gx.idx[k] + off)
		g.idx.append(gx.idx[k + 1] + off)
		g.idx.append(gx.idx[k + 2] + off)
	var fp := Vector3(0.33, 0.6, 0.06)
	_ell(g, fp, Vector3(0.08, 0.1, 0.09), {"rot": Basis(Vector3.FORWARD, -0.7) * Basis(Vector3.RIGHT, 0.3)})
	_mi(_chest, g, plastic)
	g = Geo.new()
	_ell(g, Vector3(-0.46, 0.22, 0.2), Vector3(0.068, 0.068, 0.068))
	_mi(_chest, g, joint)
	g = Geo.new()
	_ell(g, fp + Vector3(0.0, 0.01, -0.082), Vector3(0.02, 0.012, 0.012), {"rot": Basis(Vector3.FORWARD, -0.7)})
	_ell(g, fp + Vector3(0.05, 0.05, -0.04), Vector3(0.04, 0.03, 0.04), {"jit": 0.5, "nf": 20.0})
	_mi(_chest, g, dark)
	g = Geo.new()
	_ell(g, fp + Vector3(0.0, 0.01, -0.088), Vector3(0.006, 0.006, 0.005))
	_mi(_chest, g, _eye_mat_get()).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_eyes_at(_head, [Vector3(-0.037, 0.143, -0.106), Vector3(0.037, 0.143, -0.106)], 0.009, 0.13)
	_head.rotation.z = 0.5
	_head.rotation.x = 0.08
	# ---- 팔 (볼 관절), 오른팔은 아래팔이 깨져 철사가 삐져나옴. 위팔엔 찢어진 재킷 소매
	for i in 2:
		var sg := -1.0 if i == 0 else 1.0
		g = Geo.new()
		_limb(g, Vector3(0, -0.02, 0), Vector3(0, -0.37, 0), 0.085, 0.08, 0.06, 14)
		_mi(_arm[i], g, plastic)
		g = Geo.new()
		_ell(g, Vector3.ZERO, Vector3(0.088, 0.088, 0.088))
		_ell(g, Vector3(0, -0.39, 0), Vector3(0.062, 0.062, 0.062))
		_mi(_arm[i], g, joint)
		g = Geo.new()
		_tube(g, _line(Vector3(0, 0.06, 0), Vector3(0, -0.26, 0.01), 4), PackedFloat32Array([0.112, 0.105, 0.1, 0.104]), {"sides": 12, "jit": 0.2, "nf": 8.0, "cap": false})
		_tatters_line(g, Vector3(0, -0.24, 0.01), 0.1, 4, 0.08, 0.2, 0.035)
		_mi(_arm[i], g, suit)
		g = Geo.new()
		if i == 0:
			_limb(g, Vector3(0, -0.02, 0), Vector3(0, -0.34, 0), 0.064, 0.06, 0.042, 14)
			_mi(_elbow[i], g, plastic)
			g = Geo.new()
			_ell(g, Vector3(0, 0.0, 0), Vector3(0.034, 0.034, 0.034))
			_mi(_hand[i], g, joint)
			g = Geo.new()
			var gn := Geo.new()
			_hand_geo(g, gn, sg, 0.11, 0.095, 0.14, 0.018, 4, 0.08, 0.0)
			_mi(_hand[i], g, plastic)
			g = Geo.new()  # 손목에 매달린 가격표
			_tube(g, _line(Vector3(0, -0.02, 0.04), Vector3(0.0, -0.1, 0.07), 2), PackedFloat32Array([0.002]), {"sides": 3})
			_extrude(g, PackedVector2Array([Vector2(-0.03, 0), Vector2(0.03, 0), Vector2(0.03, -0.05), Vector2(-0.03, -0.05)]), PackedFloat32Array([0.002, 0.002, 0.002, 0.002]),
				Transform3D(Basis(Vector3.UP, 0.4), Vector3(0, -0.1, 0.07)))
			_mi(_elbow[i], g, paper)
		else:
			_tube(g, PackedVector3Array([Vector3(0, -0.02, 0), Vector3(0, -0.1, 0), Vector3(0, -0.16, 0), Vector3(0, -0.2, 0)]),
				PackedFloat32Array([0.064, 0.062, 0.06, 0.058]), {"sides": 14, "cap": false})
			for k in 7:  # 깨진 조각
				var a := k * TAU / 7.0 + 0.3
				_tube(g, _line(Vector3(cos(a) * 0.052, -0.19, sin(a) * 0.052), Vector3(cos(a) * 0.045, -0.23 - (k % 3) * 0.03, sin(a) * 0.045), 2), PackedFloat32Array([0.02, 0.0]), {"sides": 3})
			_mi(_elbow[i], g, plastic)
			g = Geo.new()
			_ell(g, Vector3(0, -0.2, 0), Vector3(0.052, 0.01, 0.052))
			_mi(_elbow[i], g, dark)
			g = Geo.new()
			for k in 4:
				var a := k * 1.6
				var w0 := Vector3(cos(a) * 0.015, -0.18, sin(a) * 0.015)
				_tube(g, _bez3(w0, w0 + Vector3(cos(a) * 0.025, -0.12, 0.0), w0 + Vector3(cos(a) * 0.07, -0.19, sin(a) * 0.05), w0 + Vector3(cos(a) * 0.05, -0.31, sin(a) * 0.09), 6),
					PackedFloat32Array([0.005]), {"sides": 4})
			_mi(_elbow[i], g, wire)
		_arm[i].rotation = Vector3(0.05, 0, sg * 0.12)
		_elbow[i].rotation.x = 0.1
	# ---- 다리 (볼 관절) + 매끈한 발, 찢어진 바지
	for i in 2:
		g = Geo.new()
		_limb(g, Vector3(0, -0.03, 0), Vector3(0, -0.52, 0), 0.15, 0.14, 0.085, 14)
		_mi(_leg[i], g, plastic)
		g = Geo.new()
		_limb(g, Vector3(0, -0.02, 0), Vector3(0, -0.49, 0), 0.08, 0.092, 0.052, 14)
		_mi(_knee[i], g, plastic)
		g = Geo.new()
		_ell(g, Vector3(0, 0.0, 0), Vector3(0.1, 0.1, 0.1))
		_mi(_leg[i], g, joint)
		_mi(_knee[i], _ell_geo(Vector3.ZERO, Vector3(0.082, 0.082, 0.082)), joint)
		_mi(_foot[i], _ell_geo(Vector3(0, -0.03, -0.075), Vector3(0.07, 0.048, 0.155)), plastic)


# ================================================================ 케르베로스
## 말만 한 크기의, 가죽이 벗겨진 머리 셋 달린 사냥개: 드러난 붉은 근육과 힘줄, 툭 튀어나온 갈비뼈와 등뼈 가시,
## 어깨를 덮은 엉겨 붙은 검은 갈기, 목마다 가시 박힌 쇠 목줄, 이빨 가득한 긴 턱, 주황빛 눈, 굵은 다리와 갈고리 발톱, 뼈 꼬리
func _build_hound() -> void:
	_rig = "hound"
	_S = 1.42
	_eye_color = Color(1.0, 0.5, 0.04)
	_step = 1.6
	_twitch_rate = 0.5
	var muscle := _m(Color(0.17, 0.035, 0.03), {"albedo2": Color(0.3, 0.08, 0.06), "mottle": 0.7, "mottle_scale": 9.0, "grime": 0.35,
		"grime_color": Color(0.08, 0.01, 0.01), "roughness_v": 0.72, "bump": 0.5, "blood": 0.4,
		"blood_color": Color(0.06, 0.0, 0.0), "rim": 0.14, "rim_color": Color(0.7, 0.3, 0.25), "backlight_v": 0.15})
	var sinew := _m(Color(0.45, 0.32, 0.26), {"albedo2": Color(0.3, 0.15, 0.12), "mottle": 0.6, "mottle_scale": 14.0, "grime": 0.3, "roughness_v": 0.72, "blood": 0.3})
	var bone := _m(Color(0.5, 0.44, 0.34), {"albedo2": Color(0.34, 0.26, 0.18), "mottle": 0.6, "grime": 0.6, "roughness_v": 0.75,
		"blood": 0.5, "cracks": 0.3, "bump": 0.3})
	var fur := _m(Color(0.05, 0.04, 0.035), {"albedo2": Color(0.12, 0.09, 0.07), "mottle": 0.5, "grime": 0.2, "roughness_v": 0.95,
		"bump": 0.5, "rim": 0.18, "rim_color": Color(0.4, 0.35, 0.3)})
	var gum := _m(Color(0.4, 0.06, 0.08), {"roughness_v": 0.72, "grime": 0.2, "mottle": 0.3})
	var tooth := _m(Color(0.8, 0.74, 0.58), {"roughness_v": 0.72, "grime": 0.35})
	var iron := _metal(Color(0.26, 0.24, 0.22), 0.78)
	var dark := _dark_mat()
	_hips = _node(self, Vector3(0, 1.0, 0.0))
	var lz := Basis(Vector3(1, 0, 0), Vector3(0, 0, -1), Vector3(0, 1, 0))
	var deep := func(p: Vector3) -> Vector3:
		if p.y < 0.0 and p.z < -0.1:
			p.y -= 0.12 * smoothstep(-0.1, -0.55, p.z) * clampf(-p.y / 0.3, 0.0, 1.0)
		return p
	# ---- 몸통: 깊은 가슴, 잘록한 허리, 굵은 엉덩이
	var g := Geo.new()
	_lathe(g, _p([[0.0, -0.9], [0.22, -0.84], [0.33, -0.62], [0.31, -0.4], [0.24, -0.2], [0.22, 0.05], [0.27, 0.3], [0.31, 0.5], [0.27, 0.66], [0.13, 0.77], [0.0, 0.79]]),
		{"sides": 20, "sz": 1.12, "jit": 0.05, "nf": 6.0, "xf": Transform3D(lz, Vector3.ZERO), "deform": deep})
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.2, 0.03, -0.55), Vector3(0.15, 0.26, 0.24), {"jit": 0.06})
		_ell(g, Vector3(sg * 0.2, 0.02, 0.5), Vector3(0.15, 0.26, 0.25), {"jit": 0.06})
	_mi(_hips, g, muscle)
	g = Geo.new()  # 힘줄 (옆구리·어깨)
	for sg: float in [-1.0, 1.0]:
		for k in 3:
			_tube(g, _bez2(Vector3(sg * 0.3, 0.18 - k * 0.1, -0.7 + k * 0.05), Vector3(sg * 0.34, 0.05 - k * 0.1, -0.5), Vector3(sg * 0.28, -0.1 - k * 0.08, -0.3), 5), PackedFloat32Array([0.008, 0.014, 0.014, 0.012, 0.006]), {"sides": 5})
	_mi(_hips, g, sinew)
	g = Geo.new()  # 갈비뼈 + 등뼈 가시
	for k in 7:
		var z := -0.46 + k * 0.1
		for sg: float in [-1.0, 1.0]:
			if (k + int(sg)) % 3 == 0:
				continue   # 군데군데는 근육에 덮여 안 보임
			var bulge := 0.3 + 0.025 * sin(k * 1.7 + sg)
			var cut := 1.0 if (k * 7 + int(sg * 3.0)) % 4 != 0 else 0.6   # 부러진 갈비뼈
			var rib := _bez3(Vector3(sg * 0.05, 0.26, z), Vector3(sg * bulge, 0.23, z + 0.02), Vector3(sg * bulge, -0.2, z - 0.02), Vector3(sg * 0.1, -0.36, z - 0.06), 8)
			var n := int(8 * cut)
			_tube(g, rib.slice(0, n), PackedFloat32Array([0.022, 0.02, 0.019, 0.018, 0.017, 0.015, 0.013, 0.01]), {"sides": 6})
	for k in 15:
		var z := -0.72 + k * 0.105
		var y := 0.3 + 0.04 * sin(k * 0.45)
		var hk := 1.0 + 0.6 * (1.0 - absf(k - 4.0) / 7.0)
		_tube(g, _line(Vector3(0, y - 0.05, z), Vector3(0, y + (0.08 + 0.05 * float(k % 2)) * hk, z + 0.07), 3), PackedFloat32Array([0.04, 0.02, 0.0]), {"sides": 5})
	_mi(_hips, g, bone)
	g = Geo.new()  # 어깨를 덮은 엉겨 붙은 갈기 + 듬성듬성한 털
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.18, 0.18, -0.58), Vector3(0.2, 0.22, 0.26), {"jit": 0.45, "nf": 7.0})
		_ell(g, Vector3(sg * 0.17, 0.08, 0.6), Vector3(0.19, 0.22, 0.24), {"jit": 0.45, "nf": 7.0})
	for k in 70:
		var z := _rng.randf_range(-0.92, -0.32)
		var a := _rng.randf_range(-1.4, 1.4)
		var b := Vector3(sin(a) * 0.3, 0.16 + cos(a) * 0.22, z)
		var L := _rng.randf_range(0.1, 0.2)
		_tube(g, _bez2(b, b + Vector3(sin(a) * 0.05, 0.06, 0.08), b + Vector3(sin(a) * 0.08, 0.04 - L * 0.3, L), 3), PackedFloat32Array([0.035, 0.02, 0.0]), {"sides": 4})
	_mi(_hips, g, fur)
	# ---- 머리 셋 (가운데가 가장 큼) + 가시 쇠 목줄
	for h in 3:
		var sg := float(h - 1)
		var nk := _node(_hips, Vector3(sg * 0.2, 0.2 - absf(sg) * 0.05, -0.7))
		nk.rotation = Vector3(-0.1 + absf(sg) * 0.15, -sg * 0.5, -sg * 0.15)
		var sc := 1.18 if h == 1 else 1.0
		nk.scale = Vector3.ONE * sc
		g = Geo.new()
		_tube(g, _bez2(Vector3(0, -0.05, 0.14), Vector3(0, 0.08, -0.12), Vector3(0, 0.22, -0.3), 5), PackedFloat32Array([0.19, 0.15, 0.125, 0.11, 0.1]), {"sides": 14, "jit": 0.07})
		_mi(nk, g, muscle)
		g = Geo.new()
		var cp := _bez2(Vector3(0, -0.05, 0.14), Vector3(0, 0.08, -0.12), Vector3(0, 0.22, -0.3), 5)[2]
		var cb := Basis(Vector3.RIGHT, -0.75)
		_tube(g, _ellipse(0.135, 0.135, 0.0, 14), PackedFloat32Array([0.022]), {"sides": 4, "flat": 0.5, "cap": false, "xf": Transform3D(cb, cp)})
		for k in 7:
			var a := k * TAU / 7.0
			var d := Vector3(cos(a), 0, -sin(a))
			_tube(g, _line(d * 0.14, d * 0.21, 2), PackedFloat32Array([0.016, 0.0]), {"sides": 4, "xf": Transform3D(cb, cp)})
		_mi(nk, g, iron)
		var hd := _node(nk, Vector3(0, 0.22, -0.3))
		hd.rotation.x = 0.35
		g = Geo.new()
		_tube(g, PackedVector3Array([Vector3(0, 0.02, 0.11), Vector3(0, 0.045, 0.04), Vector3(0, 0.035, -0.07), Vector3(0, 0.005, -0.2), Vector3(0, -0.01, -0.32), Vector3(0, -0.012, -0.4), Vector3(0, -0.018, -0.43)]),
			PackedFloat32Array([0.0, 0.125, 0.12, 0.08, 0.062, 0.048, 0.0]), {"sides": 14, "flat": 1.12, "up": Vector3.UP, "jit": 0.05})
		for e in 2:  # 주둥이 옆 힘줄
			var es := -1.0 if e == 0 else 1.0
			_tube(g, _bez2(Vector3(es * 0.1, 0.02, -0.02), Vector3(es * 0.085, 0.01, -0.18), Vector3(es * 0.052, -0.01, -0.34), 5), PackedFloat32Array([0.012, 0.014, 0.012, 0.009, 0.005]), {"sides": 5})
		_mi(hd, g, muscle)
		g = Geo.new()
		_ell(g, Vector3(0, 0.085, -0.06), Vector3(0.11, 0.065, 0.22), {"jit": 0.1})
		for e in 2:
			var es := -1.0 if e == 0 else 1.0
			_tube(g, _bez2(Vector3(es * 0.07, 0.09, 0.05), Vector3(es * 0.12, 0.2, 0.1), Vector3(es * 0.1, 0.29, 0.19), 4), PackedFloat32Array([0.035, 0.024, 0.01, 0.0]), {"sides": 5, "flat": 0.4, "up": Vector3(0, 0, 1)})
			_ell(g, Vector3(es * 0.105, 0.115, -0.1), Vector3(0.04, 0.024, 0.05))
		_mi(hd, g, bone)
		g = Geo.new()
		for e in 2:
			var es := -1.0 if e == 0 else 1.0
			_ell(g, Vector3(es * 0.11, 0.08, -0.1), Vector3(0.03, 0.024, 0.022))
			_ell(g, Vector3(es * 0.02, 0.012, -0.43), Vector3(0.013, 0.011, 0.008))
		_mi(hd, g, dark)
		_eyes_at(hd, [Vector3(-0.13, 0.085, -0.126), Vector3(0.13, 0.085, -0.126)], 0.018, 0.11)
		g = Geo.new()
		_ell(g, Vector3(0, -0.045, -0.18), Vector3(0.062, 0.022, 0.19))
		_mi(hd, g, gum)
		g = Geo.new()
		_teeth(g, Vector3(0, -0.04, -0.18), 0.062, 0.19, 13, 0.055, 0.009, true)
		for e in 2:
			var es := -1.0 if e == 0 else 1.0
			_tube(g, _bez2(Vector3(es * 0.05, -0.03, -0.3), Vector3(es * 0.055, -0.08, -0.31), Vector3(es * 0.048, -0.12, -0.29), 4), PackedFloat32Array([0.014, 0.012, 0.008, 0.0]), {"sides": 6})
		_mi(hd, g, tooth)
		var jw := _node(hd, Vector3(0, -0.045, 0.05))
		g = Geo.new()
		_tube(g, _line(Vector3(0, -0.01, 0.05), Vector3(0, -0.04, -0.38), 5), PackedFloat32Array([0.0, 0.075, 0.058, 0.04, 0.0]), {"sides": 12, "flat": 1.2, "up": Vector3.UP})
		_mi(jw, g, muscle)
		g = Geo.new()
		_teeth(g, Vector3(0, -0.005, -0.21), 0.05, 0.15, 11, 0.045, 0.008, false)
		_mi(jw, g, tooth)
		_heads.append(nk)
		_jaws.append(jw)
	# ---- 다리 4개 (굵은 근육, 뼈가 드러난 아래다리, 큰 발과 발톱)
	for i in 4:
		var sg := -1.0 if i % 2 == 0 else 1.0
		var front := i < 2
		var hp := _node(_hips, Vector3(sg * 0.21, -0.08 if front else -0.03, -0.52 if front else 0.54))
		var kn: Node3D
		var an: Node3D
		g = Geo.new()
		if front:
			_limb(g, Vector3(0, 0.1, 0), Vector3(0, -0.4, 0.03), 0.15, 0.125, 0.07, 12, 0.06)
			_mi(hp, g, muscle)
			kn = _node(hp, Vector3(0, -0.4, 0.03))
			g = Geo.new()
			_limb(g, Vector3(0, 0.01, 0), Vector3(0, -0.38, 0), 0.05, 0.04, 0.036, 9)
			_mi(kn, g, bone)
			g = Geo.new()
			_tube(g, _line(Vector3(0, 0.04, 0.012), Vector3(0, -0.3, 0.02), 4), PackedFloat32Array([0.078, 0.07, 0.055, 0.035]), {"sides": 9, "jit": 0.12})
			_mi(kn, g, muscle)
			an = _node(kn, Vector3(0, -0.38, 0))
		else:
			_limb(g, Vector3(0, 0.1, 0), Vector3(0, -0.42, 0), 0.19, 0.15, 0.08, 12, 0.06)
			_mi(hp, g, muscle)
			kn = _node(hp, Vector3(0, -0.42, 0))
			g = Geo.new()
			_limb(g, Vector3(0, 0.01, 0), Vector3(0, -0.42, 0), 0.08, 0.058, 0.042, 9)
			_mi(kn, g, muscle)
			an = _node(kn, Vector3(0, -0.42, 0))
			hp.rotation.x = 0.5
			kn.rotation.x = -1.2
			an.rotation.x = 0.7
		g = Geo.new()
		var gn := Geo.new()
		var mlen := 0.14 if front else 0.24
		_limb(g, Vector3(0, 0.0, 0), Vector3(0, -mlen, -0.02), 0.045, 0.04, 0.038, 8)
		for k in 4:
			var x := (k - 1.5) * 0.032
			_tube(g, _bez2(Vector3(x, -mlen, -0.02), Vector3(x * 1.3, -mlen - 0.02, -0.07), Vector3(x * 1.4, -mlen - 0.015, -0.12), 3), PackedFloat32Array([0.024, 0.021, 0.017]), {"sides": 6})
			_tube(gn, _bez2(Vector3(x * 1.4, -mlen - 0.015, -0.115), Vector3(x * 1.45, -mlen - 0.02, -0.155), Vector3(x * 1.45, -mlen - 0.045, -0.175), 3), PackedFloat32Array([0.013, 0.007, 0.0]), {"sides": 5})
		_mi(an, g, bone)
		_mi(an, gn, dark)
		_legs4.append([hp, kn, an])
	# ---- 뼈 꼬리
	var parent: Node3D = _hips
	var pos := Vector3(0, 0.18, 0.78)
	for k in 7:
		var seg := _node(parent, pos)
		seg.rotation.x = 0.5 if k == 0 else 0.16
		g = Geo.new()
		var r0 := lerpf(0.055, 0.015, float(k) / 7.0)
		_tube(g, _line(Vector3.ZERO, Vector3(0, 0, 0.18), 3), PackedFloat32Array([r0, r0 * 0.7, r0 * 0.9]), {"sides": 6})
		_ell(g, Vector3(0, 0, 0.18), Vector3(r0 * 1.3, r0 * 1.3, r0 * 1.1))
		_tube(g, _line(Vector3(0, r0, 0.12), Vector3(0, r0 + 0.04, 0.17), 2), PackedFloat32Array([r0 * 0.5, 0.0]), {"sides": 4})
		_mi(seg, g, bone)
		_tail.append(seg)
		parent = seg
		pos = Vector3(0, 0, 0.18)


# ================================================================ 인형사
## 스스로가 꼭두각시인 장신의 인형사: 머리 위에 떠 있는 나무 조종 십자대에서 내려온 실이 머리·손목·무릎을 매닮.
## 금 간 도자기 얼굴, 복화술 인형 턱, 귀까지 찢어진 붉은 미소, 헝클어진 인형 가발,
## 어깨 망토가 겹친 긴 프록코트(넓은 어깨, 높은 깃, 놋쇠 단추), 지나치게 긴 팔다리와 손가락,
## 왼손 실 끝에 매달린 망가진 작은 인형
func _build_puppeteer() -> void:
	_S = 1.25
	_cross_y = 2.58
	_eye_color = Color(0.75, 0.3, 1.0)
	_stride = 0.55
	_knee_amt = 1.3
	_bob = 0.09
	_arm_amt = 0.3
	_twitch_rate = 0.5
	_twitch_amp = 0.7
	_step = 1.2
	_skel(1.16, 0.34, 0.5, 0.15, 0.26, 0.9, 0.11, 0.55, 0.52, 0.58, 0.5)
	var coat := _m(Color(0.09, 0.05, 0.1), {"albedo2": Color(0.18, 0.1, 0.19), "mottle": 0.5, "mottle_scale": 3.0, "grime": 0.45, "roughness_v": 0.9,
		"bump": 0.4, "blood": 0.12, "rim": 0.2, "rim_color": Color(0.55, 0.35, 0.75), "kind": "cloth", "sway": 0.02})
	var vest := _m(Color(0.26, 0.05, 0.07), {"albedo2": Color(0.14, 0.02, 0.04), "mottle": 0.5, "grime": 0.45, "roughness_v": 0.88, "kind": "cloth"})
	var shirt := _m(Color(0.62, 0.58, 0.5), {"albedo2": Color(0.42, 0.38, 0.3), "mottle": 0.5, "grime": 0.6, "roughness_v": 0.92, "kind": "cloth", "bump": 0.3})
	var porcelain := _m(Color(0.66, 0.64, 0.6), {"albedo2": Color(0.52, 0.49, 0.44), "mottle": 0.3, "grime": 0.45, "roughness_v": 0.72,
		"cracks": 0.95, "crack_scale": 5.0, "bump": 0.05, "rim": 0.14, "rim_color": Color(0.7, 0.6, 0.9)})
	var wood := _m(Color(0.28, 0.17, 0.09), {"albedo2": Color(0.18, 0.1, 0.05), "mottle": 0.6, "mottle_scale": 22.0, "roughness_v": 0.78, "grime": 0.35, "cracks": 0.3})
	var paint_red := _m(Color(0.45, 0.02, 0.03), {"roughness_v": 0.72, "grime": 0.2, "mottle": 0.2})
	var cheek := _m(Color(0.72, 0.42, 0.44), {"roughness_v": 0.72, "grime": 0.3, "cracks": 0.6, "crack_scale": 5.0})
	var black := _m(Color(0.02, 0.02, 0.025), {"roughness_v": 0.72, "grime": 0.0, "rim": 0.12, "rim_color": Color(0.5, 0.4, 0.7)})
	var wig := _hair_mat(Color(0.03, 0.025, 0.03))
	var brass := _metal(Color(0.55, 0.42, 0.2), 0.72)
	var dark := _dark_mat()
	var string_mat := _glow_mat(Color(0.7, 0.55, 1.0), 0.9)
	_spine.rotation.x = -0.12
	_neck.rotation.x = -0.15
	_head.rotation = Vector3(0.1, 0.0, 0.3)
	# ---- 몸통 + 조끼 + 프록코트 (넓은 어깨, 높이 선 깃)
	var g := Geo.new()
	_lathe(g, _p([[0.15, -0.36], [0.16, -0.15], [0.19, 0.1], [0.22, 0.3], [0.21, 0.42], [0.1, 0.5], [0.0, 0.52]]), {"sides": 18, "sx": 1.3, "sz": 0.75})
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.27, 0.44, 0.0), Vector3(0.1, 0.07, 0.1))
	_mi(_chest, g, coat)
	g = Geo.new()
	_lathe(g, _p([[0.152, -0.36], [0.163, -0.15], [0.193, 0.1], [0.212, 0.3]]), {"sides": 10, "sx": 1.3, "sz": 0.76, "a0": PI * 0.5 - 0.42, "a1": PI * 0.5 + 0.42})
	_mi(_chest, g, vest)
	g = Geo.new()
	var ruff := func(p: Vector3) -> Vector3:
		var a := atan2(-p.z, p.x)
		var k := 1.0 + 0.22 * sin(a * 14.0) * clampf((p.y - 0.42) / 0.05, 0.0, 1.0)
		return Vector3(p.x * k, p.y, p.z * k)
	_lathe(g, _p([[0.0, 0.42], [0.07, 0.43], [0.15, 0.47], [0.12, 0.52], [0.07, 0.53]]), {"sides": 32, "deform": ruff})
	_tube(g, _bez3(Vector3(0, 0.44, -0.12), Vector3(0.0, 0.35, -0.17), Vector3(0.02, 0.25, -0.175), Vector3(0.0, 0.18, -0.17), 6), PackedFloat32Array([0.035, 0.04, 0.035, 0.02, 0.0]), {"sides": 8, "jit": 0.3, "nf": 30.0})
	_mi(_chest, g, shirt)
	g = Geo.new()
	for k in 5:
		_ell(g, Vector3(0, -0.25 + k * 0.1, -0.168), Vector3(0.016, 0.016, 0.01))
	for sg: float in [-1.0, 1.0]:
		for k in 5:
			_tube(g, _line(Vector3(sg * (0.26 + k * 0.03), 0.46, -0.06), Vector3(sg * (0.27 + k * 0.035), 0.37, -0.07), 2), PackedFloat32Array([0.006]), {"sides": 3})
	_mi(_chest, g, brass)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.32, 0.47, 0.0), Vector3(0.1, 0.028, 0.085))
	_mi(_chest, g, vest)
	g = Geo.new()  # 높이 선 깃 + 어깨 망토 (찢어짐)
	_lathe(g, _p([[0.12, 0.46], [0.13, 0.56], [0.19, 0.7]]), {"sides": 20, "sx": 1.1, "sz": 1.0, "a0": PI * 0.5 + 0.55, "a1": PI * 2.5 - 0.55, "jit": 0.05})
	var cape := func(p: Vector3) -> Vector3:
		var a := atan2(p.x, p.z)
		var k := 1.0 + 0.07 * sin(a * 8.0) * clampf((0.45 - p.y) / 0.4, 0.0, 1.0)
		return Vector3(p.x * k, p.y, p.z * k)
	_lathe(g, _p([[0.1, 0.52], [0.24, 0.5], [0.36, 0.42], [0.4, 0.26], [0.42, 0.1]]), {"sides": 26, "sx": 1.15, "sz": 0.9, "jit": 0.06, "deform": cape})
	_tatters(g, 0.12, 0.42 * 1.15, 0.42 * 0.9, 18, 0.08, 0.24, 0.06, 0.0, TAU, 0.04)
	_mi(_chest, g, coat)
	g = Geo.new()
	_lathe(g, _p([[0.15, 0.0], [0.155, 0.36]]), {"sides": 16, "sx": 1.28, "sz": 0.78})
	_mi(_spine, g, coat)
	g = Geo.new()  # 프록코트 아랫단 (앞은 벌어짐) + 찢어진 자락
	var ragged := func(p: Vector3) -> Vector3:
		var a := atan2(p.x, p.z)
		var k := 1.0 + 0.08 * sin(a * 7.0) * clampf(-p.y, 0.0, 1.0)
		p.x *= k
		p.z *= k
		if p.y < -0.7:
			p.y += _noise.get_noise_2d(a * 4.0, 2.0) * 0.12
		return p
	_lathe(g, _p([[0.19, 0.08], [0.22, -0.2], [0.3, -0.6], [0.36, -0.95]]), {"sides": 24, "sx": 1.2, "sz": 0.95, "a0": PI * 0.5 + 0.4, "a1": PI * 2.5 - 0.4, "jit": 0.04, "deform": ragged})
	_tatters(g, -0.9, 0.36 * 1.2, 0.36 * 0.95, 12, 0.1, 0.3, 0.05, PI * 0.5 + 0.5, PI * 2.5 - 0.5, 0.03)
	_mi(_hips, g, coat)
	g = Geo.new()
	_tube(g, _ellipse(0.2 * 1.2, 0.2 * 0.92, 0.05, 22), PackedFloat32Array([0.022]), {"sides": 4, "flat": 0.4, "up": Vector3.UP, "cap": false})
	_mi(_hips, g, black)
	_mi(_hips, _ell_geo(Vector3(0, 0.05, -0.19), Vector3(0.04, 0.03, 0.012)), brass)
	g = Geo.new()
	_tube(g, _line(Vector3(0, -0.02, 0), Vector3(0, 0.16, -0.01), 3), PackedFloat32Array([0.04, 0.036, 0.036]), {"sides": 9})
	_mi(_neck, g, porcelain)
	# ---- 도자기 얼굴 + 헝클어진 인형 가발
	g = Geo.new()
	_ell(g, Vector3(0, 0.125, 0), Vector3(0.093, 0.125, 0.108), {"sides": 18, "rings": 12})
	_ell(g, Vector3(0, 0.12, -0.098), Vector3(0.012, 0.022, 0.014))
	_mi(_head, g, porcelain)
	_jaw = _node(_head, Vector3(0, 0.06, -0.02))
	g = Geo.new()
	_ell(g, Vector3(0, -0.02, -0.055), Vector3(0.05, 0.035, 0.05))
	_mi(_jaw, g, porcelain)
	g = Geo.new()
	_ell(g, Vector3(0, 0.165, 0.015), Vector3(0.098, 0.088, 0.112))
	for sg: float in [-1.0, 1.0]:
		_tube(g, _bez2(Vector3(sg * 0.018, 0.168, -0.095), Vector3(sg * 0.045, 0.19, -0.098), Vector3(sg * 0.07, 0.172, -0.082), 5), PackedFloat32Array([0.003, 0.004, 0.002]), {"sides": 4})
	_mi(_head, g, black)
	g = Geo.new()
	_hair(g, Vector3(0, 0.13, 0.01), Vector3(0.096, 0.12, 0.11), 44, 0.06, 0.17, 0.024, -0.85, 0.85, 0.05)
	_mi(_head, g, wig)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.04, 0.132, -0.094), Vector3(0.027, 0.023, 0.014))
		_tube(g, _line(Vector3(sg * 0.036, 0.062, -0.098), Vector3(sg * 0.032, 0.0, -0.085), 3), PackedFloat32Array([0.0025]), {"sides": 4})
	_ell(g, Vector3(0.06, 0.2, -0.05), Vector3(0.035, 0.03, 0.03), {"jit": 0.4, "nf": 25.0})
	_mi(_head, g, dark)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.055, 0.085, -0.082), Vector3(0.022, 0.016, 0.008), {"rot": Basis(Vector3.UP, sg * 0.5)})
	_mi(_head, g, cheek)
	g = Geo.new()
	_tube(g, _bez3(Vector3(-0.085, 0.09, -0.06), Vector3(-0.04, 0.05, -0.105), Vector3(0.04, 0.05, -0.105), Vector3(0.085, 0.09, -0.06), 9),
		PackedFloat32Array([0.002, 0.005, 0.006, 0.006, 0.006, 0.006, 0.006, 0.005, 0.002]), {"sides": 5})
	_mi(_head, g, paint_red)
	_eyes_at(_head, [Vector3(-0.04, 0.132, -0.103), Vector3(0.04, 0.132, -0.103)], 0.009, 0.12)
	_head.scale = Vector3.ONE * 1.15
	# ---- 긴 팔 (넓은 소매 + 커프스) + 나무 관절 + 길고 가는 손가락, 손끝의 실
	for i in 2:
		var sg := -1.0 if i == 0 else 1.0
		g = Geo.new()
		_limb(g, Vector3(0, 0.04, 0), Vector3(0, -0.55, 0), 0.085, 0.075, 0.065, 11, 0.06)
		_mi(_arm[i], g, coat)
		g = Geo.new()
		_tube(g, _line(Vector3(0, 0.02, 0), Vector3(0, -0.46, 0), 5), PackedFloat32Array([0.065, 0.065, 0.07, 0.08, 0.095]), {"sides": 11, "cap": false, "jit": 0.15, "nf": 8.0})
		_tube(g, _line(Vector3(0, -0.4, 0), Vector3(0, -0.5, 0), 2), PackedFloat32Array([0.1, 0.105]), {"sides": 11, "cap": false})
		_mi(_elbow[i], g, coat)
		g = Geo.new()
		_tatters_line(g, Vector3(0, -0.48, 0), 0.08, 6, 0.06, 0.14, 0.03)
		_mi(_elbow[i], g, shirt)
		g = Geo.new()
		_ell(g, Vector3(0, -0.5, 0), Vector3(0.03, 0.03, 0.03))
		_ell(g, Vector3.ZERO, Vector3(0.055, 0.055, 0.055))
		_mi(_elbow[i], g, wood)
		g = Geo.new()
		var gn := Geo.new()
		_hand_geo(g, gn, sg, 0.095, 0.075, 0.24, 0.0105, 4, 0.3, 0.014)
		_mi(_hand[i], g, porcelain)
		_mi(_hand[i], gn, black)
		g = Geo.new()
		for k in 4:
			var z := lerpf(-0.03, 0.03, k / 3.0)
			_tube(g, _line(Vector3(-sg * 0.02, -0.31, z), Vector3(-sg * 0.03, -0.62 if i == 0 else -1.0, z * 1.5), 2), PackedFloat32Array([0.0018]), {"sides": 3, "cap": false})
		_mi(_hand[i], g, string_mat)
		_arm[i].rotation = Vector3(0.12, 0, sg * 0.12)
		_elbow[i].rotation.x = 0.3
		_hand[i].rotation.x = 0.25
	# 왼손 실 끝에 매달린 망가진 작은 인형 (늘 아래로 늘어짐)
	var doll := _node(_hand[0], Vector3(0.02, -0.6, 0))
	doll.set_meta("dscale", Vector3.ONE * 1.7)
	_danglers.append(doll)
	g = Geo.new()
	_ell(g, Vector3(0, -0.06, 0), Vector3(0.05, 0.055, 0.05))
	for sg: float in [-1.0, 1.0]:
		_tube(g, _bez2(Vector3(sg * 0.04, -0.15, 0), Vector3(sg * 0.07, -0.22, 0.0), Vector3(sg * 0.06, -0.28, 0.02), 3), PackedFloat32Array([0.012, 0.011, 0.01]), {"sides": 5})
		_tube(g, _line(Vector3(sg * 0.025, -0.3, 0), Vector3(sg * 0.03, -0.42, 0.01), 2), PackedFloat32Array([0.014, 0.012]), {"sides": 5})
	_mi(doll, g, porcelain)
	g = Geo.new()
	_lathe(g, _p([[0.03, -0.11], [0.05, -0.15], [0.07, -0.25], [0.09, -0.32]]), {"sides": 12, "jit": 0.15})
	_mi(doll, g, vest)
	g = Geo.new()
	_ell(g, Vector3(-0.018, -0.055, -0.045), Vector3(0.012, 0.012, 0.008))
	_ell(g, Vector3(0.02, -0.06, -0.044), Vector3(0.008, 0.016, 0.008), {"jit": 0.4, "nf": 40.0})
	_ell(g, Vector3(0.0, -0.085, -0.046), Vector3(0.016, 0.005, 0.006))
	_mi(doll, g, dark)
	g = Geo.new()
	_hair(g, Vector3(0, -0.06, 0), Vector3(0.05, 0.055, 0.05), 18, 0.05, 0.12, 0.012, -0.8, 0.8, 0.02)
	_mi(doll, g, wig)
	# ---- 긴 다리 + 뾰족 구두
	for i in 2:
		g = Geo.new()
		_limb(g, Vector3(0, 0.03, 0), Vector3(0, -0.58, 0), 0.09, 0.082, 0.062, 11)
		_mi(_leg[i], g, coat)
		g = Geo.new()
		_limb(g, Vector3(0, 0.0, 0), Vector3(0, -0.5, 0), 0.062, 0.058, 0.046, 11)
		_mi(_knee[i], g, black)
		_mi(_knee[i], _ell_geo(Vector3.ZERO, Vector3(0.06, 0.06, 0.06)), wood)
		g = Geo.new()
		_tube(g, PackedVector3Array([Vector3(0, -0.02, 0.07), Vector3(0, -0.02, 0.0), Vector3(0, -0.045, -0.12), Vector3(0, -0.055, -0.24), Vector3(0, -0.03, -0.32)]),
			PackedFloat32Array([0.0, 0.06, 0.048, 0.026, 0.0]), {"sides": 10, "flat": 0.75, "up": Vector3.UP})
		_mi(_foot[i], g, black)
	# ---- 머리 위 조종 십자대 + 몸을 매단 실
	_cross = _node(self, Vector3(0, _cross_y, -0.05))
	g = Geo.new()
	_tube(g, _line(Vector3(-0.38, 0, 0), Vector3(0.38, 0, 0), 3), PackedFloat32Array([0.026, 0.03, 0.026]), {"sides": 8})
	_tube(g, _line(Vector3(0, 0, 0.3), Vector3(0, 0, -0.32), 3), PackedFloat32Array([0.026, 0.03, 0.026]), {"sides": 8})
	_tube(g, _line(Vector3(0, 0, 0), Vector3(0, 0.12, 0), 2), PackedFloat32Array([0.02, 0.015]), {"sides": 6})
	_ell(g, Vector3.ZERO, Vector3(0.05, 0.042, 0.05))
	for e: Vector3 in [Vector3(-0.38, 0, 0), Vector3(0.38, 0, 0), Vector3(0, 0, 0.3), Vector3(0, 0, -0.32)]:
		_ell(g, e, Vector3(0.034, 0.034, 0.034))
	_mi(_cross, g, wood)
	_add_string(_cross, Vector3(0, 0, -0.3), _head, Vector3(0, 0.24, 0), string_mat)
	_add_string(_cross, Vector3(-0.37, 0, 0), _hand[0], Vector3(0, -0.02, 0), string_mat)
	_add_string(_cross, Vector3(0.37, 0, 0), _hand[1], Vector3(0, -0.02, 0), string_mat)
	_add_string(_cross, Vector3(-0.1, 0, 0.29), _knee[0], Vector3(0, 0, -0.06), string_mat)
	_add_string(_cross, Vector3(0.1, 0, 0.29), _knee[1], Vector3(0, 0, -0.06), string_mat)


# ================================================================ 안개 마녀
## 동화 속 마녀 그대로인데 끔찍한 노파: 꼬부라진 등의 거대한 키, 끝이 꺾인 커다란 챙 넓은 검은 고깔모자(찢어지고 기움),
## 가늘고 긴 잿빛 머리, 병든 회녹색 피부, 사마귀 난 긴 매부리코와 뾰족 턱, 누런 이빨 가득한 웃음, 초록 눈.
## 겹겹이 해진 검정·짙은 보라 드레스와 망토, 뼈만 남은 긴 손가락과 갈고리 손톱,
## 오른손엔 해골과 초록 랜턴을 매단 뒤틀린 빗자루, 허리엔 물약병·해골 부적. 치맛자락 끝은 초록 안개로 흩어짐
func _build_witch() -> void:
	_rig = "float"
	_S = 1.21
	_eye_color = Color(0.4, 1.0, 0.25)
	_light_energy = 0.12
	_twitch_rate = 0.35
	_twitch_amp = 0.6
	_hold_right = true
	_skel(1.05, 0.34, 0.44, 0.15, 0.2, 0.9, 0.12, 0.5, 0.47, 0.0, 0.0)
	var dress := _m(Color(0.11, 0.045, 0.14), {"albedo2": Color(0.19, 0.08, 0.23), "mottle": 0.55, "mottle_scale": 3.0, "grime": 0.45,
		"grime_color": Color(0.02, 0.02, 0.015), "roughness_v": 0.95, "bump": 0.5, "rim": 0.22, "rim_color": Color(0.55, 0.3, 0.8), "kind": "cloth", "sway": 0.03})
	var cloak := _m(Color(0.03, 0.028, 0.035), {"albedo2": Color(0.08, 0.05, 0.09), "mottle": 0.5, "mottle_scale": 2.5, "grime": 0.4,
		"roughness_v": 0.95, "bump": 0.5, "rim": 0.25, "rim_color": Color(0.4, 0.75, 0.45), "kind": "cloth", "sway": 0.035})
	var hatm := _m(Color(0.035, 0.03, 0.04), {"albedo2": Color(0.09, 0.07, 0.1), "mottle": 0.6, "mottle_scale": 4.0, "grime": 0.35,
		"grime_color": Color(0.1, 0.09, 0.07), "roughness_v": 0.95, "bump": 0.4, "rim": 0.3, "rim_color": Color(0.45, 0.7, 0.5), "kind": "cloth"})
	var band := _m(Color(0.2, 0.06, 0.24), {"albedo2": Color(0.1, 0.03, 0.12), "mottle": 0.4, "grime": 0.4, "roughness_v": 0.9, "kind": "cloth"})
	var skin := _m(Color(0.29, 0.32, 0.25), {"albedo2": Color(0.19, 0.22, 0.15), "mottle": 0.75, "mottle_scale": 9.0, "grime": 0.5,
		"grime_color": Color(0.1, 0.11, 0.06), "roughness_v": 0.75, "bump": 0.4, "veins": 0.15, "vein_color": Color(0.2, 0.7, 0.25),
		"rim": 0.12, "rim_color": Color(0.4, 0.95, 0.5), "backlight_v": 0.12})
	var wart := _m(Color(0.3, 0.3, 0.2), {"albedo2": Color(0.22, 0.2, 0.12), "mottle": 0.6, "mottle_scale": 30.0, "roughness_v": 0.8, "grime": 0.3})
	var bone := _m(Color(0.72, 0.68, 0.56), {"albedo2": Color(0.46, 0.41, 0.3), "mottle": 0.5, "grime": 0.55, "roughness_v": 0.78, "cracks": 0.5, "crack_scale": 6.0})
	var wood := _m(Color(0.2, 0.13, 0.08), {"albedo2": Color(0.1, 0.07, 0.04), "mottle": 0.7, "mottle_scale": 14.0, "roughness_v": 0.85, "grime": 0.4, "cracks": 0.4, "crack_scale": 5.0})
	var straw := _m(Color(0.36, 0.3, 0.17), {"albedo2": Color(0.2, 0.16, 0.09), "mottle": 0.6, "mottle_scale": 10.0, "roughness_v": 0.95, "grime": 0.5, "kind": "cloth"})
	var leather := _m(Color(0.13, 0.085, 0.055), {"albedo2": Color(0.07, 0.045, 0.03), "mottle": 0.4, "roughness_v": 0.8, "grime": 0.4})
	var iron := _metal(Color(0.3, 0.29, 0.27), 0.75)
	var mist := _m(Color(0.1, 0.22, 0.12, 0.6), {"albedo2": Color(0.05, 0.12, 0.06), "kind": "fade", "sway": 0.16, "sway_speed": 1.0,
		"rim": 0.6, "rim_color": Color(0.25, 0.95, 0.35), "roughness_v": 1.0, "fade_start": 0.0, "grime": 0.2, "under_ao": 0.0})
	var hair := _hair_mat(Color(0.25, 0.25, 0.24))
	var nail := _m(Color(0.07, 0.06, 0.04), {"albedo2": Color(0.18, 0.15, 0.08), "mottle": 0.5, "roughness_v": 0.72})
	var tooth := _m(Color(0.6, 0.52, 0.3), {"albedo2": Color(0.35, 0.28, 0.14), "mottle": 0.6, "mottle_scale": 20.0, "roughness_v": 0.72, "grime": 0.4})
	var dark := _dark_mat()
	var glow := _glow_mat(Color(0.35, 1.0, 0.3), 2.6)
	var glow2 := _glow_mat(Color(0.65, 0.25, 1.0), 2.0)
	_spine.rotation.x = -0.38
	_chest.rotation.x = -0.2
	_neck.rotation.x = 0.45
	_head.rotation = Vector3(0.22, 0, -0.1)
	var hunch := -(_spine.rotation.x + _chest.rotation.x)   # 가슴 좌표에서 '세상 아래'로 늘어뜨리기 위한 보정각

	# ---- 몸통: 앙상한 몸 + 굽은 등의 혹 + 코르셋 끈
	var g := Geo.new()
	_lathe(g, _p([[0.12, -0.36], [0.135, -0.12], [0.15, 0.12], [0.16, 0.3], [0.11, 0.42], [0.05, 0.47]]), {"sides": 18, "sx": 1.18, "sz": 0.82, "jit": 0.04})
	_ell(g, Vector3(0, 0.3, 0.1), Vector3(0.17, 0.15, 0.13), {"jit": 0.08})
	_mi(_chest, g, dress)
	g = Geo.new()
	_lathe(g, _p([[0.115, 0.0], [0.125, 0.36]]), {"sides": 16, "sx": 1.15, "sz": 0.82})
	_mi(_spine, g, dress)
	g = Geo.new()
	var lace := PackedVector3Array()
	for k in 9:
		lace.append(Vector3(0.028 * (1.0 if k % 2 == 0 else -1.0), -0.32 + k * 0.065, -0.128 - 0.006 * sin(k * 0.4)))
	_tube(g, lace, PackedFloat32Array([0.005]), {"sides": 4})
	for sg: float in [-1.0, 1.0]:
		_tube(g, _line(Vector3(sg * 0.032, -0.33, -0.125), Vector3(sg * 0.03, 0.22, -0.13), 4), PackedFloat32Array([0.008]), {"sides": 4})
	_mi(_chest, g, leather)

	# ---- 망토: 어깨에서 바닥까지 (세상 아래로 늘어지게 보정), 뒤쪽은 찢어진 자락
	var drape := Transform3D(Basis(Vector3.RIGHT, hunch), Vector3(0, 0.42, 0.02)) * Transform3D(Basis(), Vector3(0, -0.42, 0))
	var folds := func(p: Vector3) -> Vector3:
		var a := atan2(p.x, p.z)
		var depth := clampf((0.3 - p.y) / 1.6, 0.0, 1.0)
		var k := 1.0 + 0.09 * sin(a * 7.0 + 0.5) * depth + 0.03 * sin(a * 17.0) * depth
		p.x *= k
		p.z *= k
		if p.y < -1.1:
			p.y += _noise.get_noise_2d(a * 5.0, 8.0) * 0.16
		return p
	g = Geo.new()
	_lathe(g, _p([[0.13, 0.47], [0.24, 0.4], [0.3, 0.2], [0.34, -0.2], [0.42, -0.7], [0.52, -1.15], [0.58, -1.38]]),
		{"sides": 22, "sx": 1.25, "sz": 1.0, "a0": PI * 0.5 + 0.75, "a1": PI * 2.5 - 0.75, "jit": 0.05, "nf": 5.0, "deform": folds, "xf": drape})
	_mi(_chest, g, cloak)
	g = Geo.new()
	_tatters(g, -1.36, 0.58 * 1.25, 0.58, 12, 0.12, 0.3, 0.07, PI * 0.5 + 0.8, PI * 2.5 - 0.8, 0.05)
	for k in g.v.size():
		g.v[k] = drape * g.v[k]
	_mi(_chest, g, mist)
	# 어깨 망토(짧은 케이프) + 높은 깃
	g = Geo.new()
	_lathe(g, _p([[0.08, 0.5], [0.16, 0.47], [0.27, 0.38], [0.33, 0.22], [0.35, 0.12]]), {"sides": 22, "sx": 1.2, "sz": 1.0, "jit": 0.08, "nf": 6.0, "deform": folds})
	_tatters(g, 0.1, 0.35 * 1.2, 0.35, 16, 0.1, 0.26, 0.06, 0.0, TAU, 0.05)
	_mi(_chest, g, cloak)
	g = Geo.new()
	_lathe(g, _p([[0.075, 0.44], [0.085, 0.52], [0.13, 0.62]]), {"sides": 16, "sx": 1.1, "sz": 1.0, "a0": PI * 0.5 + 0.9, "a1": PI * 2.5 - 0.9, "jit": 0.1})
	_mi(_chest, g, cloak)

	# ---- 드레스: 허리에서 퍼지는 주름 치마 + 앞이 트인 겉치마 + 바닥의 초록 안개
	var skirt := func(p: Vector3) -> Vector3:
		var a := atan2(p.x, p.z)
		var depth := clampf(-p.y, 0.0, 1.0)
		var k := 1.0 + (0.08 * sin(a * 9.0) + 0.03 * sin(a * 23.0 + 1.0)) * depth
		p.x *= k
		p.z *= k
		if p.y < -0.8:
			p.y += _noise.get_noise_2d(a * 6.0, 3.0) * 0.1
		return p
	g = Geo.new()
	_lathe(g, _p([[0.13, 0.06], [0.16, -0.12], [0.25, -0.42], [0.38, -0.72], [0.5, -0.97]]), {"sides": 28, "sz": 0.92, "jit": 0.04, "deform": skirt})
	_mi(_hips, g, dress)
	g = Geo.new()
	_lathe(g, _p([[0.15, 0.05], [0.19, -0.12], [0.29, -0.4], [0.42, -0.7]]), {"sides": 22, "sz": 0.95, "a0": PI * 0.5 + 0.5, "a1": PI * 2.5 - 0.5, "jit": 0.07, "deform": skirt})
	_tatters(g, -0.68, 0.42, 0.42 * 0.95, 14, 0.1, 0.24, 0.06, PI * 0.5 + 0.55, PI * 2.5 - 0.55, 0.05)
	_mi(_hips, g, cloak)
	g = Geo.new()
	_lathe(g, _p([[0.42, -0.86], [0.56, -0.97], [0.72, -1.06]]), {"sides": 24, "sz": 0.95, "jit": 0.15, "nf": 4.0})
	_tatters(g, -0.95, 0.5, 0.47, 20, 0.1, 0.24, 0.08, 0.0, TAU, 0.14)
	_mi(_hips, g, mist)
	# 허리띠 + 버클 + 물약병 + 해골 부적 + 주머니 + 뼈 장식
	g = Geo.new()
	_tube(g, _ellipse(0.148, 0.128, 0.03, 22), PackedFloat32Array([0.022]), {"sides": 4, "flat": 0.35, "up": Vector3.UP, "cap": false})
	_ell(g, Vector3(-0.17, -0.07, 0.04), Vector3(0.06, 0.07, 0.045), {"jit": 0.15})
	_tube(g, _bez2(Vector3(-0.15, 0.03, 0.02), Vector3(-0.19, -0.01, 0.03), Vector3(-0.17, -0.03, 0.04), 3), PackedFloat32Array([0.008]), {"sides": 4})
	for sg: float in [-1.0, 1.0]:
		var cp := Vector3(sg * 0.1, 0.02, -0.11)
		_tube(g, _line(cp, cp + Vector3(sg * 0.01, -0.07, -0.02), 2), PackedFloat32Array([0.004]), {"sides": 3})
	_mi(_hips, g, leather)
	g = Geo.new()
	_extrude(g, PackedVector2Array([Vector2(-0.024, -0.02), Vector2(0.024, -0.02), Vector2(0.024, 0.02), Vector2(-0.024, 0.02)]), PackedFloat32Array([0.006, 0.006, 0.006, 0.006]),
		Transform3D(Basis(), Vector3(0, 0.03, -0.138)))
	_mi(_hips, g, iron)
	var bottle_at := func(gg: Geo, gc: Geo, pos: Vector3, r: float, h: float) -> void:
		_ell(gg, pos, Vector3(r, h, r), {"sides": 10, "rings": 6})
		_tube(gc, _line(pos + Vector3(0, h * 0.8, 0), pos + Vector3(0, h * 1.45, 0), 2), PackedFloat32Array([r * 0.42]), {"sides": 6})
	g = Geo.new()
	var gcork := Geo.new()
	bottle_at.call(g, gcork, Vector3(-0.09, -0.06, -0.165), 0.032, 0.042)
	bottle_at.call(g, gcork, Vector3(0.17, -0.05, -0.1), 0.026, 0.05)
	_mi(_hips, g, glow)
	g = Geo.new()
	bottle_at.call(g, gcork, Vector3(-0.15, -0.04, -0.11), 0.024, 0.034)
	_mi(_hips, g, glow2)
	_mi(_hips, gcork, wood)
	g = Geo.new()  # 해골 부적 + 늘어진 뼈
	var sk := Vector3(0.06, -0.1, -0.175)
	_ell(g, sk, Vector3(0.03, 0.032, 0.03))
	_ell(g, sk + Vector3(0, -0.028, -0.006), Vector3(0.019, 0.013, 0.018))
	for k in 3:
		var bp := Vector3(0.115 + k * 0.022, -0.02, -0.15 + k * 0.03)
		_tube(g, _line(bp, bp + Vector3(0.0, -0.1 - k * 0.025, -0.005), 3), PackedFloat32Array([0.008, 0.005, 0.008]), {"sides": 5})
	_mi(_hips, g, bone)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_ell(g, sk + Vector3(sg * 0.011, 0.002, -0.025), Vector3(0.008, 0.008, 0.006))
	_mi(_hips, g, dark)

	# ---- 목 (힘줄이 선 가는 목)
	g = Geo.new()
	_tube(g, _line(Vector3(0, -0.05, 0), Vector3(0, 0.15, -0.015), 4), PackedFloat32Array([0.042, 0.036, 0.033, 0.035]), {"sides": 9, "jit": 0.1})
	for sg: float in [-1.0, 1.0]:
		_tube(g, _line(Vector3(sg * 0.026, -0.03, -0.032), Vector3(sg * 0.01, 0.13, -0.035), 3), PackedFloat32Array([0.011, 0.008, 0.006]), {"sides": 5})
	_mi(_neck, g, skin)

	# ---- 얼굴: 길쭉한 해골 같은 얼굴, 툭 튀어나온 이마뼈, 긴 매부리코, 앞으로 휜 뾰족 턱, 귀까지 찢어진 웃음
	g = Geo.new()
	_ell(g, Vector3(0, 0.11, 0.0), Vector3(0.08, 0.115, 0.092), {"jit": 0.035, "nf": 12.0})
	_ell(g, Vector3(0, 0.035, -0.035), Vector3(0.05, 0.062, 0.055))
	_tube(g, _bez3(Vector3(0, 0.02, -0.05), Vector3(0, -0.02, -0.075), Vector3(0, -0.042, -0.1), Vector3(0, -0.032, -0.124), 6),
		PackedFloat32Array([0.032, 0.028, 0.022, 0.016, 0.01, 0.0]), {"sides": 8, "flat": 0.8})
	_ell(g, Vector3(0, 0.146, -0.074), Vector3(0.07, 0.019, 0.032), {"jit": 0.1})
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.058, 0.098, -0.05), Vector3(0.02, 0.014, 0.02))
		# 팔자 주름 · 눈 밑 주름
		_tube(g, _bez2(Vector3(sg * 0.02, 0.08, -0.106), Vector3(sg * 0.046, 0.062, -0.092), Vector3(sg * 0.058, 0.036, -0.07), 5), PackedFloat32Array([0.0035]), {"sides": 4})
		_tube(g, _bez2(Vector3(sg * 0.018, 0.106, -0.098), Vector3(sg * 0.036, 0.098, -0.1), Vector3(sg * 0.054, 0.106, -0.086), 4), PackedFloat32Array([0.003]), {"sides": 4})
		# 뾰족한 귀
		_tube(g, _bez2(Vector3(sg * 0.075, 0.11, 0.005), Vector3(sg * 0.11, 0.14, 0.02), Vector3(sg * 0.14, 0.185, 0.05), 5),
			PackedFloat32Array([0.026, 0.02, 0.013, 0.006, 0.0]), {"sides": 6, "flat": 0.35, "up": Vector3(0, 0, 1)})
	# 매부리코
	var nose := _bez3(Vector3(0, 0.132, -0.09), Vector3(0, 0.12, -0.17), Vector3(0, 0.07, -0.25), Vector3(0, 0.03, -0.215), 10)
	_tube(g, nose, PackedFloat32Array([0.018, 0.019, 0.018, 0.016, 0.014, 0.013, 0.012, 0.011, 0.007, 0.0]), {"sides": 8, "flat": 0.8, "up": Vector3(0, 0, -1)})
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.012, 0.066, -0.13), Vector3(0.01, 0.009, 0.016))
	for k in 2:  # 이마 주름
		var fy := 0.168 + k * 0.016
		_tube(g, _bez3(Vector3(-0.045, fy, -0.066), Vector3(-0.02, fy + 0.004, -0.08), Vector3(0.02, fy - 0.003, -0.08), Vector3(0.045, fy + 0.002, -0.066), 6), PackedFloat32Array([0.003]), {"sides": 4})
	_mi(_head, g, skin)
	g = Geo.new()  # 사마귀
	for wp: Vector3 in [Vector3(0.013, 0.105, -0.19), Vector3(-0.01, 0.07, -0.226), Vector3(-0.014, -0.03, -0.112), Vector3(0.058, 0.07, -0.072), Vector3(-0.045, 0.165, -0.06)]:
		_ell(g, wp, Vector3(0.009, 0.008, 0.008), {"sides": 7, "rings": 5, "jit": 0.3, "nf": 60.0})
	_tube(g, _bez2(Vector3(-0.014, -0.03, -0.12), Vector3(-0.018, -0.045, -0.13), Vector3(-0.013, -0.06, -0.126), 3), PackedFloat32Array([0.0018, 0.0012, 0.0]), {"sides": 3})
	_mi(_head, g, wart)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.034, 0.121, -0.086), Vector3(0.024, 0.016, 0.014), {"rot": Basis(Vector3.FORWARD, sg * 0.25)})
		_ell(g, Vector3(sg * 0.01, 0.06, -0.142), Vector3(0.006, 0.004, 0.006))
	var grin := _bez3(Vector3(-0.058, 0.062, -0.06), Vector3(-0.035, 0.026, -0.098), Vector3(0.035, 0.026, -0.098), Vector3(0.058, 0.062, -0.06), 11)
	_tube(g, grin, PackedFloat32Array([0.003, 0.006, 0.008, 0.01, 0.011, 0.011, 0.011, 0.01, 0.008, 0.006, 0.003]), {"sides": 6, "flat": 0.6, "up": Vector3.UP})
	_mi(_head, g, dark)
	g = Geo.new()  # 비뚤어진 누런 이빨
	for k in 11:
		if k == 3 or k == 8:
			continue
		var mp := grin[k]
		var L := 0.016 + 0.007 * _rng.randf() + (0.012 if k == 2 or k == 7 else 0.0)
		var tz := Vector3(0, 0, -0.006)
		_tube(g, _line(mp + Vector3(0, 0.009, 0) + tz, mp + Vector3(_rng.randf_range(-0.004, 0.004), 0.009 - L, -0.004) + tz, 3), PackedFloat32Array([0.0055, 0.004, 0.0]), {"sides": 5})
		if k % 3 == 1:
			_tube(g, _line(mp + Vector3(0.002, -0.011, 0) + tz, mp + Vector3(0.002, 0.002, -0.003) + tz, 2), PackedFloat32Array([0.0045, 0.0]), {"sides": 4})
	_mi(_head, g, tooth)
	_halo_z = -0.03
	_eyes_at(_head, [Vector3(-0.034, 0.121, -0.095), Vector3(0.034, 0.121, -0.095)], 0.011, 0.17)
	# 잿빛 긴 머리: 모자 밑에서 허리까지 늘어진 가닥 + 어깨에 걸친 뭉치
	g = Geo.new()
	_hair(g, Vector3(0, 0.12, 0.0), Vector3(0.085, 0.11, 0.098), 96, 0.55, 0.95, 0.019, -1.2, 1.2, 0.09)
	var hang := func(p: Vector3) -> Vector3:
		if p.y < -0.1:
			p.y += _noise.get_noise_2d(atan2(p.x, p.z) * 8.0, 4.0) * 0.08
		return p
	_lathe(g, _p([[0.05, 0.225], [0.092, 0.17], [0.1, 0.08], [0.104, -0.05], [0.118, -0.2], [0.14, -0.38]]),
		{"sides": 20, "sz": 1.05, "a0": PI * 0.5 + 0.95, "a1": PI * 2.5 - 0.95, "jit": 0.18, "nf": 9.0, "deform": hang})
	_mi(_head, g, hair)

	# ---- 모자: 넓고 처진 찢어진 챙, 뒤로 꺾인 높은 고깔, 보라 띠와 쇠 버클, 기운 자국
	var hat := _node(_head, Vector3(0, 0.19, 0.01))
	hat.rotation = Vector3(0.2, 0.0, 0.12)
	var brim := func(p: Vector3) -> Vector3:
		var a := atan2(p.x, p.z)
		var r := Vector2(p.x, p.z).length()
		var w := smoothstep(0.12, 0.42, r)
		p.y -= w * (0.05 + 0.04 * cos(a) + 0.02 * sin(a * 3.0 + 0.8) + 0.012 * sin(a * 7.0))
		var tear := _noise.get_noise_2d(a * 9.0, 1.0)
		if r > 0.25 and tear > 0.25:
			var f := 1.0 - (tear - 0.25) * 0.9 * smoothstep(0.25, 0.42, r)
			p.x *= f
			p.z *= f
		return p
	g = Geo.new()
	_lathe(g, _p([[0.1, 0.026], [0.18, 0.014], [0.28, 0.0], [0.38, -0.02], [0.43, -0.035], [0.425, -0.045], [0.36, -0.03], [0.26, -0.01], [0.16, 0.004], [0.1, 0.012]]),
		{"sides": 40, "sz": 0.96, "jit": 0.03, "nf": 7.0, "deform": brim})
	# 고깔: 위로 갈수록 뒤로 휘다가 끝이 꺾여 아래로 처짐
	var cone := _bez3(Vector3(0, 0.0, 0.0), Vector3(0, 0.22, 0.0), Vector3(-0.01, 0.42, 0.06), Vector3(0.02, 0.56, 0.17), 8)
	var tipp := _bez3(Vector3(0.02, 0.56, 0.17), Vector3(0.035, 0.63, 0.25), Vector3(0.07, 0.6, 0.33), Vector3(0.1, 0.5, 0.36), 6)
	for k in range(1, tipp.size()):
		cone.append(tipp[k])
	_tube(g, cone, PackedFloat32Array([0.128, 0.12, 0.108, 0.093, 0.078, 0.064, 0.052, 0.043, 0.036, 0.029, 0.022, 0.016, 0.01, 0.0]),
		{"sides": 16, "jit": 0.09, "nf": 5.0})
	_mi(hat, g, hatm)
	g = Geo.new()
	_tube(g, _ellipse(0.127, 0.123, 0.035, 24), PackedFloat32Array([0.024]), {"sides": 4, "flat": 0.3, "up": Vector3.UP, "cap": false})
	_mi(hat, g, band)
	g = Geo.new()
	_extrude(g, PackedVector2Array([Vector2(-0.032, -0.025), Vector2(0.032, -0.025), Vector2(0.032, 0.025), Vector2(-0.032, 0.025)]), PackedFloat32Array([0.006, 0.006, 0.006, 0.006]),
		Transform3D(Basis(), Vector3(0, 0.035, -0.135)))
	_mi(hat, g, iron)
	g = Geo.new()
	_stitches(g, _line(Vector3(0.09, 0.12, -0.04), Vector3(0.05, 0.3, 0.02), 4), 6, 0.035)
	_mi(hat, g, leather)

	# ---- 팔: 넓게 해진 나팔 소매, 뼈만 남은 팔, 갈고리 손톱의 아주 긴 손가락
	for i in 2:
		var sg := -1.0 if i == 0 else 1.0
		g = Geo.new()
		_limb(g, Vector3(0, 0.02, 0), Vector3(0, -0.5, 0), 0.04, 0.035, 0.03, 8)
		_mi(_arm[i], g, skin)
		g = Geo.new()
		_tube(g, _line(Vector3(0, 0.06, 0), Vector3(0, -0.5, 0.0), 5), PackedFloat32Array([0.085, 0.08, 0.075, 0.075, 0.08]), {"sides": 12, "jit": 0.2, "nf": 7.0, "cap": false})
		_mi(_arm[i], g, dress)
		g = Geo.new()
		_tube(g, PackedVector3Array([Vector3(0, 0.03, 0), Vector3(0, -0.12, 0.01), Vector3(0, -0.26, 0.03), Vector3(0, -0.36, 0.05)]), PackedFloat32Array([0.075, 0.1, 0.14, 0.18]),
			{"sides": 14, "jit": 0.3, "nf": 6.0, "cap": false})
		_tatters_line(g, Vector3(0, -0.34, 0.05), 0.2, 7, 0.12, 0.32, 0.05)
		_mi(_elbow[i], g, cloak)
		g = Geo.new()
		_limb(g, Vector3(0, 0.01, 0), Vector3(0, -0.47, 0), 0.032, 0.03, 0.022, 8)
		_ell(g, Vector3(0, -0.46, 0), Vector3(0.03, 0.026, 0.03))
		_mi(_elbow[i], g, skin)
		g = Geo.new()
		var gn := Geo.new()
		_hand_geo(g, gn, sg, 0.1, 0.075, 0.27, 0.0105, 4, 0.42, 0.07)
		_mi(_hand[i], g, skin)
		_mi(_hand[i], gn, nail)
	_arm[0].rotation = Vector3(1.0, 0, -0.32)
	_elbow[0].rotation.x = 0.55
	_hand[0].rotation = Vector3(-0.35, 0, 0)
	_arm[1].rotation = Vector3(0.38, 0, 0.16)
	_elbow[1].rotation.x = 0.92
	_hand[1].rotation = Vector3(-0.15, 0, 0)

	# ---- 빗자루 지팡이: 뒤틀린 자루, 아래엔 묶은 짚, 위엔 갈퀴처럼 갈라진 가지에 끼운 해골 + 매달린 초록 랜턴
	var broom := _node(_hand[1], Vector3(0.0, -0.07, 0.0))
	broom.rotation = Vector3(-(_spine.rotation.x + _chest.rotation.x + _arm[1].rotation.x + _elbow[1].rotation.x + _hand[1].rotation.x), 0, -0.18)
	g = Geo.new()
	var shaft := PackedVector3Array()
	for k in 14:
		var t := float(k) / 13.0
		var y := lerpf(-0.62, 1.0, t)
		shaft.append(Vector3(sin(t * 9.0) * 0.012 + _rng.randf_range(-0.006, 0.006), y, cos(t * 7.0) * 0.01))
	_tube(g, shaft, PackedFloat32Array([0.028, 0.025, 0.024, 0.026, 0.023, 0.024, 0.022, 0.024, 0.026, 0.023, 0.022, 0.025, 0.028, 0.03]), {"sides": 8, "jit": 0.22, "nf": 14.0})
	for k in 4:  # 옹이
		var kp := shaft[2 + k * 3]
		_ell(g, kp + Vector3(0.018 * (1 if k % 2 == 0 else -1), 0, 0.01), Vector3(0.02, 0.028, 0.018), {"sides": 7, "rings": 5})
	for k in 3:  # 위쪽 갈래 가지 (해골을 움켜쥠)
		var a := k * TAU / 3.0 + 0.4
		var b0 := Vector3(0, 0.98, 0)
		_tube(g, _bez3(b0, b0 + Vector3(cos(a) * 0.07, 0.04, sin(a) * 0.07), b0 + Vector3(cos(a) * 0.09, 0.16, sin(a) * 0.09), b0 + Vector3(cos(a) * 0.035, 0.24, sin(a) * 0.035), 7),
			PackedFloat32Array([0.022, 0.018, 0.015, 0.012, 0.009, 0.006, 0.0]), {"sides": 6, "jit": 0.2})
	_tube(g, _bez2(Vector3(0, 1.0, 0), Vector3(0.1, 1.06, -0.02), Vector3(0.17, 1.02, -0.04), 4), PackedFloat32Array([0.014, 0.01, 0.007, 0.004]), {"sides": 5})
	_mi(broom, g, wood)
	g = Geo.new()  # 짚 다발
	var straw_top := -0.5
	for k in 34:
		var a := TAU * (k + _rng.randf()) / 34.0
		var rr := _rng.randf_range(0.01, 0.035)
		var s0 := Vector3(cos(a) * rr, straw_top, sin(a) * rr)
		var L := _rng.randf_range(0.3, 0.4)
		var spread := _rng.randf_range(0.08, 0.15)
		_tube(g, PackedVector3Array([s0, s0 + Vector3(cos(a) * spread * 0.3, -L * 0.4, sin(a) * spread * 0.3), s0 + Vector3(cos(a) * spread, -L, sin(a) * spread)]),
			PackedFloat32Array([0.009, 0.007, 0.002]), {"sides": 3, "cap": false})
	_mi(broom, g, straw)
	g = Geo.new()
	for k in 3:
		_tube(g, _ellipse(0.043 + k * 0.004, 0.043 + k * 0.004, straw_top - 0.02 - k * 0.035, 10), PackedFloat32Array([0.007]), {"sides": 4, "cap": false})
	_mi(broom, g, leather)
	g = Geo.new()  # 해골
	var skc := Vector3(0, 1.12, 0)
	_ell(g, skc, Vector3(0.062, 0.066, 0.07), {"jit": 0.05})
	_ell(g, skc + Vector3(0, -0.05, -0.03), Vector3(0.04, 0.03, 0.04))
	_teeth(g, skc + Vector3(0, -0.055, -0.03), 0.032, 0.038, 7, 0.016, 0.006, true)
	_mi(broom, g, bone)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_ell(g, skc + Vector3(sg * 0.024, 0.0, -0.058), Vector3(0.017, 0.016, 0.012))
	_ell(g, skc + Vector3(0, -0.028, -0.066), Vector3(0.008, 0.01, 0.008))
	_mi(broom, g, glow)
	var lantern := _node(broom, Vector3(0.17, 1.02, -0.04))
	_danglers.append(lantern)
	g = Geo.new()
	_chain(g, _line(Vector3.ZERO, Vector3(0, -0.1, 0), 2), 0.03, 0.004)
	_tube(g, _ellipse(0.045, 0.045, -0.12, 8), PackedFloat32Array([0.006]), {"sides": 4, "cap": false})
	_tube(g, _ellipse(0.045, 0.045, -0.25, 8), PackedFloat32Array([0.006]), {"sides": 4, "cap": false})
	_tube(g, _bez2(Vector3(-0.03, -0.12, 0), Vector3(0, -0.07, 0), Vector3(0.03, -0.12, 0), 4), PackedFloat32Array([0.004]), {"sides": 3})
	for k in 4:
		var a := k * TAU / 4.0 + 0.4
		_tube(g, _line(Vector3(cos(a) * 0.045, -0.12, sin(a) * 0.045), Vector3(cos(a) * 0.045, -0.25, sin(a) * 0.045), 2), PackedFloat32Array([0.005]), {"sides": 3})
	_mi(lantern, g, iron)
	_mi(lantern, _ell_geo(Vector3(0, -0.185, 0), Vector3(0.032, 0.05, 0.032)), glow)


# ================================================================ 사이코
## 덩치 큰 탈주 환자: 피와 때에 전 두툼한 구속복(가죽 끈·쇠 버클), 몸을 감은 쇠사슬, 끌고 다니는 쇠사슬과 큰 낫,
## 귀까지 웃는 금 간 가면(붉은 눈동자에서 피눈물), 헝클어진 검은 머리, 비뚤어진 자세로 경련
func _build_psycho() -> void:
	_S = 1.3
	_eye_color = Color(1.0, 0.08, 0.04)
	_hold_right = true
	_twitch_rate = 1.4
	_twitch_amp = 0.75
	_jitter = 0.1
	_limp = 0.4
	_stride = 0.5
	_skel(1.04, 0.33, 0.52, 0.08, 0.33, 0.86, 0.15, 0.47, 0.44, 0.5, 0.46)
	var canvas := _m(Color(0.42, 0.4, 0.34), {"albedo2": Color(0.28, 0.26, 0.21), "mottle": 0.6, "mottle_scale": 3.5, "grime": 0.7, "grime_color": Color(0.14, 0.11, 0.07),
		"blood": 0.5, "blood_scale": 2.6, "roughness_v": 0.92, "bump": 0.5, "rim": 0.12})
	var strap := _m(Color(0.1, 0.07, 0.05), {"albedo2": Color(0.06, 0.04, 0.03), "roughness_v": 0.78, "grime": 0.35, "blood": 0.25})
	var steel := _metal(Color(0.32, 0.31, 0.33), 0.72)
	var pants := _m(Color(0.27, 0.3, 0.32), {"albedo2": Color(0.17, 0.19, 0.21), "mottle": 0.5, "grime": 0.65, "blood": 0.35, "roughness_v": 0.9, "bump": 0.4})
	var skin := _m(Color(0.55, 0.47, 0.42), {"albedo2": Color(0.4, 0.28, 0.26), "mottle": 0.6, "grime": 0.6, "blood": 0.35, "roughness_v": 0.75, "bump": 0.3, "cracks": 0.25, "crack_color": Color(0.35, 0.06, 0.05), "crack_scale": 3.0})
	var mask := _m(Color(0.5, 0.48, 0.45), {"albedo2": Color(0.36, 0.34, 0.3), "mottle": 0.4, "grime": 0.5, "blood": 0.4, "blood_scale": 4.0,
		"roughness_v": 0.72, "cracks": 0.75, "crack_scale": 5.0, "bump": 0.05, "rim": 0.12, "rim_color": Color(0.8, 0.6, 0.6)})
	var blood := _m(Color(0.25, 0.0, 0.0), {"roughness_v": 0.72, "grime": 0.0, "mottle": 0.3})
	var hair := _hair_mat(Color(0.02, 0.018, 0.016))
	var tooth := _m(Color(0.82, 0.78, 0.66), {"roughness_v": 0.72, "grime": 0.3})
	var wood := _m(Color(0.25, 0.15, 0.08), {"roughness_v": 0.8, "grime": 0.4, "blood": 0.3})
	var tag := _m(Color(0.75, 0.75, 0.72), {"roughness_v": 0.8, "grime": 0.5, "blood": 0.3})
	var dark := _dark_mat()
	_spine.rotation = Vector3(-0.3, 0.0, 0.05)
	_chest.rotation = Vector3(-0.1, 0.1, 0.13)
	_neck.rotation.x = 0.18
	_head.rotation = Vector3(0.15, 0.1, -0.42)
	# ---- 두툼한 구속복 상체 + 가죽 끈과 버클 + 감긴 쇠사슬
	var prof := [[0.25, -0.36], [0.28, -0.1], [0.3, 0.15], [0.3, 0.33], [0.24, 0.46], [0.1, 0.53], [0.0, 0.54]]
	var g := Geo.new()
	_lathe(g, _p(prof), {"sides": 20, "sx": 1.22, "sz": 0.82, "jit": 0.035, "nf": 6.0})
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.32, 0.43, 0.0), Vector3(0.13, 0.1, 0.13))
		_tube(g, _line(Vector3(sg * 0.13, 0.38, -0.235), Vector3(sg * 0.15, -0.3, -0.225), 4), PackedFloat32Array([0.014]), {"sides": 4})   # 누빈 솔기
	_mi(_chest, g, canvas)
	g = Geo.new()
	var gb := Geo.new()
	for y: float in [-0.22, 0.04, 0.28]:
		var r := _prof_r(prof, y)
		_tube(g, _ellipse(r * 1.22 + 0.016, r * 0.82 + 0.016, y, 24), PackedFloat32Array([0.008]), {"sides": 4, "flat": 4.0, "up": Vector3.UP, "cap": false})
		_extrude(gb, PackedVector2Array([Vector2(-0.035, -0.03), Vector2(0.035, -0.03), Vector2(0.035, 0.03), Vector2(-0.035, 0.03)]), PackedFloat32Array([0.008, 0.008, 0.008, 0.008]),
			Transform3D(Basis(), Vector3(0.1, y, -(r * 0.82 + 0.024))))
	for sg: float in [-1.0, 1.0]:  # 가랑이 끈 + 어깨 끈
		_tube(g, _bez2(Vector3(sg * 0.12, -0.36, -0.22), Vector3(sg * 0.1, -0.55, -0.15), Vector3(sg * 0.12, -0.6, 0.1), 5), PackedFloat32Array([0.008]), {"sides": 4, "flat": 4.0})
		_tube(g, _bez3(Vector3(sg * 0.2, 0.3, -0.26), Vector3(sg * 0.24, 0.5, -0.2), Vector3(sg * 0.24, 0.52, 0.12), Vector3(sg * 0.2, 0.3, 0.26), 7), PackedFloat32Array([0.008]), {"sides": 4, "flat": 4.0})
	_mi(_chest, g, strap)
	_mi(_chest, gb, steel)
	g = Geo.new()
	var path := PackedVector3Array()
	for k in 29:
		var t := k / 28.0
		var a := t * TAU * 1.1 + 0.5
		var y := lerpf(0.4, -0.32, t)
		var r := _prof_r(prof, y) + 0.035
		path.append(Vector3(cos(a) * r * 1.22, y, -sin(a) * r * 0.82))
	_chain(g, path, 0.075, 0.011)
	_mi(_chest, g, steel)
	g = Geo.new()
	_lathe(g, _p([[0.24, 0.0], [0.255, 0.35]]), {"sides": 18, "sx": 1.22, "sz": 0.84, "jit": 0.03})
	_mi(_spine, g, canvas)
	g = Geo.new()  # 구속복의 높은 깃
	_lathe(g, _p([[0.12, 0.44], [0.115, 0.56], [0.125, 0.66]]), {"sides": 16, "sx": 1.0, "sz": 1.0, "jit": 0.08})
	_tube(g, _ellipse(0.122, 0.122, 0.6, 16), PackedFloat32Array([0.008]), {"sides": 4, "flat": 3.0, "up": Vector3.UP, "cap": false})
	_mi(_chest, g, canvas)
	g = Geo.new()
	_ell(g, Vector3(0, -0.02, 0), Vector3(0.3, 0.2, 0.25))
	_tatters(g, -0.1, 0.3, 0.25, 9, 0.08, 0.28, 0.05, 0.0, TAU, 0.02)
	_mi(_hips, g, canvas)
	g = Geo.new()
	_tube(g, _line(Vector3(0, -0.06, 0), Vector3(0, 0.1, -0.01), 3), PackedFloat32Array([0.1, 0.085, 0.08]), {"sides": 10})
	_mi(_neck, g, skin)
	# ---- 머리 + 웃는 가면 + 피눈물 + 헝클어진 머리
	g = Geo.new()
	_ell(g, Vector3(0, 0.12, 0.02), Vector3(0.1, 0.127, 0.102))
	_mi(_head, g, skin)
	g = Geo.new()
	_lathe(g, _p([[0.0, -0.11], [0.06, -0.1], [0.1, -0.05], [0.112, 0.02], [0.105, 0.08], [0.08, 0.12]]),
		{"sides": 16, "sx": 0.97, "sz": 0.95, "a0": PI * 0.5 - 1.2, "a1": PI * 0.5 + 1.2, "xf": Transform3D(Basis(), Vector3(0, 0.12, 0.0))})
	for sg: float in [-1.0, 1.0]:  # 가면 끈
		_tube(g, _bez2(Vector3(sg * 0.1, 0.15, -0.03), Vector3(sg * 0.115, 0.16, 0.06), Vector3(sg * 0.07, 0.17, 0.11), 4), PackedFloat32Array([0.006]), {"sides": 4})
	_mi(_head, g, mask)
	g = Geo.new()
	_tube(g, _bez3(Vector3(-0.08, 0.08, -0.08), Vector3(-0.04, 0.02, -0.13), Vector3(0.04, 0.02, -0.13), Vector3(0.08, 0.08, -0.08), 11),
		PackedFloat32Array([0.003, 0.008, 0.012, 0.015, 0.016, 0.016, 0.016, 0.015, 0.012, 0.008, 0.003]), {"sides": 6, "flat": 0.6, "up": Vector3.UP})
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.04, 0.14, -0.106), Vector3(0.025, 0.017, 0.014), {"rot": Basis(Vector3.FORWARD, sg * 0.25)})
	_mi(_head, g, dark)
	g = Geo.new()
	for k in 9:
		var t := k / 8.0
		var mp := _bez3(Vector3(-0.068, 0.076, -0.092), Vector3(-0.035, 0.028, -0.13), Vector3(0.035, 0.028, -0.13), Vector3(0.068, 0.076, -0.092), 9)[k]
		_tube(g, _line(mp + Vector3(0, 0.012, -0.002), mp + Vector3(0, -0.004, -0.004), 2), PackedFloat32Array([0.006 + 0.002 * sin(t * PI), 0.0]), {"sides": 4})
		_tube(g, _line(mp + Vector3(0, -0.016, -0.002), mp + Vector3(0, -0.002, -0.004), 2), PackedFloat32Array([0.005, 0.0]), {"sides": 4})
	_mi(_head, g, tooth)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_tube(g, _bez2(Vector3(sg * 0.038, 0.123, -0.112), Vector3(sg * 0.042, 0.08, -0.117), Vector3(sg * 0.036, 0.03, -0.11), 5), PackedFloat32Array([0.006, 0.004, 0.004, 0.003, 0.005]), {"sides": 4})
	_mi(_head, g, blood)
	_eyes_at(_head, [Vector3(-0.04, 0.14, -0.112), Vector3(0.04, 0.14, -0.112)], 0.009, 0.11)
	g = Geo.new()
	for k in 60:
		var a := _rng.randf_range(0.0, TAU)
		var b := _rng.randf_range(0.15, 1.45)
		var n := Vector3(sin(a) * cos(b), sin(b), cos(a) * cos(b))
		if n.z < -0.25 and n.y < 0.75:
			continue
		var p := Vector3(0, 0.12, 0) + Vector3(n.x * 0.1, n.y * 0.127, n.z * 0.11)
		var d := (n * 0.6 + Vector3(0, -0.9, 0.3) + Vector3(_rng.randf_range(-0.3, 0.3), 0, _rng.randf_range(-0.2, 0.2))).normalized()
		var L := _rng.randf_range(0.12, 0.28)
		_tube(g, _bez2(p - n * 0.01, p + d * L * 0.5, p + d * L + Vector3(0, -0.04, 0), 4), PackedFloat32Array([0.022, 0.017, 0.01, 0.0]), {"sides": 4, "flat": 0.4, "up": Vector3.UP})
	_mi(_head, g, hair)
	_head.scale = Vector3.ONE * 1.25
	# ---- 팔: 왼팔은 끝이 막힌 긴 소매 + 늘어진 끈과 쇠사슬, 오른팔은 소매가 찢겨 맨팔로 낫을 쥠
	for i in 2:
		var sg := -1.0 if i == 0 else 1.0
		g = Geo.new()
		_limb(g, Vector3(0, 0.04, 0), Vector3(0, -0.47, 0), 0.115, 0.11, 0.09, 12, 0.06)
		_mi(_arm[i], g, canvas)
		g = Geo.new()
		_tube(g, _ellipse(0.105, 0.105, -0.25, 12), PackedFloat32Array([0.008]), {"sides": 4, "flat": 4.0, "up": Vector3.UP, "cap": false})
		_mi(_arm[i], g, strap)
		g = Geo.new()
		if i == 0:
			_limb(g, Vector3(0, 0.02, 0), Vector3(0, -0.64, 0), 0.092, 0.088, 0.075, 12, 0.06)
			_tatters_line(g, Vector3(0, -0.6, 0), 0.06, 3, 0.25, 0.45, 0.03)
			_mi(_elbow[i], g, canvas)
			g = Geo.new()
			_tube(g, _ellipse(0.09, 0.09, -0.4, 12), PackedFloat32Array([0.008]), {"sides": 4, "flat": 4.0, "up": Vector3.UP, "cap": false})
			_tube(g, _bez2(Vector3(0.0, -0.4, -0.09), Vector3(0.02, -0.6, -0.12), Vector3(0.0, -0.85, -0.08), 5), PackedFloat32Array([0.008]), {"sides": 4, "flat": 3.0})
			_mi(_elbow[i], g, strap)
			var dang := _node(_elbow[i], Vector3(0, -0.62, 0))
			_danglers.append(dang)
			g = Geo.new()
			_chain(g, PackedVector3Array([Vector3.ZERO, Vector3(0, -0.4, 0), Vector3(0, -0.66, 0.25), Vector3(0, -0.7, 0.75)]), 0.08, 0.011)
			_mi(dang, g, steel)
		else:
			_tube(g, _line(Vector3(0, 0.02, 0), Vector3(0, -0.12, 0), 3), PackedFloat32Array([0.092, 0.095, 0.1]), {"sides": 12, "cap": false, "jit": 0.3, "nf": 10.0})
			_tatters_line(g, Vector3(0, -0.1, 0), 0.08, 4, 0.1, 0.22, 0.035)
			_mi(_elbow[i], g, canvas)
			g = Geo.new()
			_limb(g, Vector3(0, -0.02, 0), Vector3(0, -0.44, 0), 0.075, 0.072, 0.05, 11, 0.04)
			_mi(_elbow[i], g, skin)
			g = Geo.new()  # 환자 팔찌
			_tube(g, _ellipse(0.054, 0.054, -0.4, 10), PackedFloat32Array([0.006]), {"sides": 4, "flat": 2.5, "up": Vector3.UP, "cap": false})
			_mi(_elbow[i], g, tag)
			g = Geo.new()
			var gn := Geo.new()
			_hand_geo(g, gn, sg, 0.11, 0.1, 0.13, 0.019, 4, 0.95, 0.018)
			_mi(_hand[i], g, skin)
			_mi(_hand[i], gn, dark)
			g = Geo.new()
			_tube(g, _line(Vector3(0, -0.05, 0.1), Vector3(0, -0.05, -0.28), 3), PackedFloat32Array([0.022, 0.025, 0.022]), {"sides": 7})
			_mi(_hand[i], g, wood)
			g = Geo.new()
			_tube(g, _bez3(Vector3(0, -0.05, -0.27), Vector3(0, 0.15, -0.46), Vector3(0, 0.44, -0.33), Vector3(0, 0.48, -0.02), 11),
				PackedFloat32Array([0.04, 0.048, 0.05, 0.05, 0.048, 0.044, 0.038, 0.03, 0.022, 0.012, 0.0]), {"sides": 6, "flat": 0.14, "up": Vector3(0, 0, -1)})
			_mi(_hand[i], g, steel)
	_arm[0].rotation = Vector3(0.05, 0, -0.1)
	_arm[1].rotation = Vector3(0.35, 0, 0.17)
	_elbow[0].rotation.x = 0.15
	_elbow[1].rotation.x = 0.8
	_hand[1].rotation.x = -0.3
	# ---- 다리 + 맨발
	for i in 2:
		g = Geo.new()
		_limb(g, Vector3(0, 0.04, 0), Vector3(0, -0.5, 0), 0.155, 0.145, 0.1, 12, 0.05)
		_mi(_leg[i], g, pants)
		g = Geo.new()
		_limb(g, Vector3(0, 0.0, 0), Vector3(0, -0.42, 0), 0.105, 0.1, 0.075, 12, 0.06)
		_tatters_line(g, Vector3(0, -0.36, 0), 0.09, 4, 0.05, 0.12, 0.035)
		_mi(_knee[i], g, pants)
		g = Geo.new()
		_tube(g, _line(Vector3(0, -0.36, 0), Vector3(0, -0.46, 0), 2), PackedFloat32Array([0.064, 0.06]), {"sides": 9})
		_mi(_knee[i], g, skin)
		g = Geo.new()
		_ell(g, Vector3(0, -0.035, -0.07), Vector3(0.072, 0.045, 0.14))
		for k in 5:
			var x := (k - 2) * 0.023
			_ell(g, Vector3(x, -0.05, -0.19 + absf(k - 2) * 0.014), Vector3(0.013, 0.014, 0.02))
		_mi(_foot[i], g, skin)


# ================================================================ 처형인
## 망태기를 뒤집어쓴 거구: 밧줄로 묶은 자루 머리와 가늘게 찢어진 주황빛 눈구멍,
## 흉터투성이 근육질 맨몸, 가죽 멜빵과 쇠 어깨갑, 사슬 갑옷 치마, 바닥에 끌리는 거대한 처형 도끼
func _build_executioner() -> void:
	_S = 1.18
	_eye_color = Color(1.0, 0.33, 0.04)
	_hold_right = true
	_stride = 0.4
	_step = 1.15
	_bob = 0.07
	_twitch_rate = 0.12
	_twitch_amp = 0.3
	_arm_amt = 0.3
	_skel(1.08, 0.36, 0.6, 0.12, 0.53, 0.85, 0.18, 0.5, 0.46, 0.5, 0.5)
	var skin := _m(Color(0.34, 0.25, 0.21), {"albedo2": Color(0.24, 0.15, 0.13), "mottle": 0.65, "mottle_scale": 4.0, "grime": 0.5,
		"blood": 0.22, "blood_scale": 1.6, "roughness_v": 0.5, "bump": 0.6, "cracks": 0.35, "crack_color": Color(0.3, 0.1, 0.08), "crack_scale": 2.6, "rim": 0.1, "rim_color": Color(0.8, 0.5, 0.35)})
	var sack := _m(Color(0.34, 0.26, 0.16), {"albedo2": Color(0.22, 0.16, 0.09), "mottle": 0.65, "mottle_scale": 9.0, "grime": 0.55,
		"roughness_v": 0.98, "bump": 1.4, "bump_scale": 48.0, "blood": 0.35, "blood_scale": 4.0, "rim": 0.1})
	var leather := _m(Color(0.12, 0.075, 0.05), {"albedo2": Color(0.07, 0.045, 0.03), "roughness_v": 0.55, "grime": 0.35, "blood": 0.3, "bump": 0.5})
	var leather_c := _m(Color(0.12, 0.075, 0.05), {"albedo2": Color(0.07, 0.045, 0.03), "roughness_v": 0.55, "grime": 0.35, "blood": 0.3, "kind": "cloth", "sway": 0.015})
	var mail := _m(Color(0.3, 0.3, 0.32), {"metallic_v": 0.8, "roughness_v": 0.5, "bump": 1.6, "bump_scale": 75.0, "grime": 0.55, "grime_color": Color(0.22, 0.1, 0.04), "kind": "cloth"})
	var iron := _metal(Color(0.24, 0.24, 0.26), 0.55)
	var steel := _metal(Color(0.62, 0.62, 0.64), 0.4)
	var rope := _m(Color(0.42, 0.34, 0.2), {"roughness_v": 0.95, "bump": 1.2, "bump_scale": 40.0, "grime": 0.4})
	var wood := _m(Color(0.22, 0.13, 0.07), {"albedo2": Color(0.14, 0.08, 0.04), "mottle_scale": 20.0, "roughness_v": 0.7, "grime": 0.4, "blood": 0.25})
	var thread := _m(Color(0.06, 0.04, 0.03), {"roughness_v": 0.9, "grime": 0.0})
	var dark := _dark_mat()
	var nail := _m(Color(0.2, 0.15, 0.1), {"roughness_v": 0.6})
	_spine.rotation.x = -0.08
	_neck.rotation.x = 0.04
	var g := Geo.new()
	var prof := [[0.32, -0.4], [0.36, -0.15], [0.42, 0.1], [0.46, 0.32], [0.42, 0.48], [0.28, 0.58], [0.12, 0.64], [0.0, 0.66]]
	_lathe(g, _p(prof), {"sides": 22, "sx": 1.25, "sz": 0.8, "jit": 0.02})
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.17, 0.3, -0.29), Vector3(0.17, 0.12, 0.09))
		_ell(g, Vector3(sg * 0.22, 0.57, 0.04), Vector3(0.19, 0.12, 0.16), {"jit": 0.03})
		_ell(g, Vector3(sg * 0.53, 0.5, 0.0), Vector3(0.19, 0.18, 0.19), {"jit": 0.03})
		_ell(g, Vector3(sg * 0.3, 0.25, 0.24), Vector3(0.2, 0.25, 0.12))
	_ell(g, Vector3(0, 0.42, 0.2), Vector3(0.36, 0.22, 0.16), {"jit": 0.04})
	_mi(_chest, g, skin)
	g = Geo.new()  # 흉터
	_stitches(g, _bez3(Vector3(-0.35, 0.45, -0.3), Vector3(-0.15, 0.3, -0.4), Vector3(0.05, 0.15, -0.41), Vector3(0.25, -0.05, -0.36), 10), 12, 0.05)
	_stitches(g, _bez2(Vector3(0.3, 0.5, 0.25), Vector3(0.1, 0.3, 0.36), Vector3(-0.15, 0.15, 0.36), 6), 8, 0.045)
	_mi(_chest, g, thread)
	g = Geo.new()
	_ell(g, Vector3(0, 0.16, 0.0), Vector3(0.36, 0.3, 0.29))
	for k in 3:
		for sg: float in [-1.0, 1.0]:
			_ell(g, Vector3(sg * 0.065, 0.08 + k * 0.1, -0.26), Vector3(0.06, 0.045, 0.04))
	_mi(_spine, g, skin)
	g = Geo.new()  # 가죽 멜빵 X자
	for sg: float in [-1.0, 1.0]:
		_tube(g, _bez3(Vector3(sg * 0.28, 0.6, -0.12), Vector3(sg * 0.24, 0.42, -0.42), Vector3(-sg * 0.1, 0.05, -0.43), Vector3(-sg * 0.38, -0.32, -0.33), 10),
			PackedFloat32Array([0.01]), {"sides": 4, "flat": 3.0, "up": Vector3(0, 0, -1)})
		_tube(g, _bez3(Vector3(sg * 0.28, 0.6, -0.12), Vector3(sg * 0.24, 0.5, 0.38), Vector3(-sg * 0.1, 0.05, 0.4), Vector3(-sg * 0.38, -0.32, 0.3), 10),
			PackedFloat32Array([0.01]), {"sides": 4, "flat": 3.0, "up": Vector3(0, 0, 1)})
	_mi(_chest, g, leather)
	g = Geo.new()
	_tube(g, _ellipse(0.035, 0.035, 0.0, 10, Vector3(0, 0.12, -0.44)), PackedFloat32Array([0.009]), {"sides": 5, "cap": false})
	_mi(_chest, g, iron)
	g = Geo.new()  # 허리띠 + 사슬 치마 + 가죽 조각
	_tube(g, _ellipse(0.4, 0.34, 0.08, 24), PackedFloat32Array([0.04]), {"sides": 5, "flat": 0.4, "up": Vector3.UP, "cap": false})
	_mi(_hips, g, leather)
	_mi(_hips, _ell_geo(Vector3(0, 0.08, -0.35), Vector3(0.06, 0.05, 0.02)), iron)
	g = Geo.new()  # 허리에 매단 해골 전리품
	var gd := Geo.new()
	for k in 3:
		var a := PI * 0.5 + 0.55 + k * 0.32
		var sk := Vector3(cos(a) * 0.45, -0.1 - (k % 2) * 0.06, -sin(a) * 0.39)
		_tube(g, _line(Vector3(cos(a) * 0.41, 0.06, -sin(a) * 0.35), sk + Vector3(0, 0.06, 0), 2), PackedFloat32Array([0.006]), {"sides": 3})
		_ell(g, sk, Vector3(0.055, 0.06, 0.06), {"jit": 0.04})
		_ell(g, sk + Vector3(0, -0.045, -0.025), Vector3(0.035, 0.025, 0.035))
		var fwd := Vector3(cos(a), 0, -sin(a))
		for sg: float in [-1.0, 1.0]:
			_ell(gd, sk + fwd * 0.05 + Vector3(-fwd.z, 0, fwd.x) * sg * 0.022 + Vector3(0, 0.005, 0), Vector3(0.016, 0.016, 0.012))
	_mi(_hips, g, _m(Color(0.66, 0.6, 0.48), {"albedo2": Color(0.42, 0.36, 0.26), "mottle": 0.5, "grime": 0.6, "roughness_v": 0.78, "blood": 0.3, "cracks": 0.3}))
	_mi(_hips, gd, dark)
	g = Geo.new()
	_lathe(g, _p([[0.37, 0.06], [0.4, -0.2], [0.44, -0.5]]), {"sides": 20, "sx": 1.1, "sz": 0.92, "jit": 0.03})
	_mi(_hips, g, mail)
	g = Geo.new()
	for k in 9:
		var a := PI * 0.5 + (k - 4) * 0.33
		var top := Vector3(cos(a) * 0.43, 0.04, -sin(a) * 0.37)
		_tube(g, _line(top, top + Vector3(cos(a) * 0.05, -0.48 - (k % 3) * 0.05, -sin(a) * 0.05), 4), PackedFloat32Array([0.05, 0.05, 0.048, 0.04]),
			{"sides": 4, "flat": 0.15, "up": Vector3(-sin(a), 0, -cos(a)), "cap": false})
	_mi(_hips, g, leather_c)
	# 다리 + 무거운 장화 + 무릎 보호대
	for i in 2:
		g = Geo.new()
		_limb(g, Vector3(0, 0.05, 0), Vector3(0, -0.5, 0), 0.21, 0.2, 0.15, 12)
		_mi(_leg[i], g, leather)
		g = Geo.new()
		_limb(g, Vector3(0, 0.0, 0), Vector3(0, -0.3, 0), 0.15, 0.14, 0.115, 12)
		_mi(_knee[i], g, leather)
		g = Geo.new()
		_tube(g, _line(Vector3(0, -0.2, 0), Vector3(0, -0.46, 0), 3), PackedFloat32Array([0.148, 0.138, 0.13]), {"sides": 12, "jit": 0.05})
		_mi(_knee[i], g, leather)
		_mi(_knee[i], _ell_geo(Vector3(0, 0.0, -0.1), Vector3(0.11, 0.12, 0.07)), iron)
		_mi(_foot[i], _ell_geo(Vector3(0, -0.02, -0.07), Vector3(0.13, 0.075, 0.21)), leather)
	# 팔: 굵은 맨팔 + 가죽 팔목 보호대, 왼쪽 쇠 어깨갑
	for i in 2:
		var sg := -1.0 if i == 0 else 1.0
		g = Geo.new()
		_limb(g, Vector3(0, 0.03, 0), Vector3(0, -0.5, 0), 0.195, 0.195, 0.14, 14, 0.04)
		_ell(g, Vector3(0, -0.2, -0.09), Vector3(0.12, 0.17, 0.1))
		_mi(_arm[i], g, skin)
		g = Geo.new()
		_limb(g, Vector3(0, 0.02, 0), Vector3(0, -0.46, 0), 0.155, 0.155, 0.105, 14, 0.04)
		_mi(_elbow[i], g, skin)
		g = Geo.new()
		_tube(g, _line(Vector3(0, -0.16, 0), Vector3(0, -0.44, 0), 3), PackedFloat32Array([0.162, 0.148, 0.125]), {"sides": 12})
		_mi(_elbow[i], g, leather)
		g = Geo.new()
		for k in 3:
			_ell(g, Vector3(0, -0.2 - k * 0.1, -0.15 + k * 0.012), Vector3(0.022, 0.022, 0.014), {"sides": 6, "rings": 4})
		if i == 0:
			for k in 3:
				_tube(g, _ellipse(0.17 - k * 0.012, 0.17 - k * 0.012, -0.2 - k * 0.1, 14), PackedFloat32Array([0.02]), {"sides": 4, "flat": 2.0, "up": Vector3.UP, "cap": false})
		_mi(_elbow[i], g, iron)
		g = Geo.new()
		var gn := Geo.new()
		_hand_geo(g, gn, sg, 0.135, 0.135, 0.135, 0.031, 4, 0.95, 0.012)
		_mi(_hand[i], g, skin)
		_mi(_hand[i], gn, nail)
	g = Geo.new()  # 왼쪽 쇠 어깨갑: 겹친 판 + 가시 + 리벳
	_ell(g, Vector3(0, 0.05, 0), Vector3(0.25, 0.18, 0.25), {"jit": 0.02})
	for k in 2:
		_lathe(g, _p([[0.2 - k * 0.01, -0.03 - k * 0.09], [0.235 - k * 0.012, -0.1 - k * 0.09]]), {"sides": 16, "a0": PI * 0.5 - 1.8, "a1": PI * 0.5 + 1.8,
			"xf": Transform3D(Basis(Vector3.FORWARD, -0.25), Vector3(-0.02, 0, 0))})
	for k in 4:
		var sp := Vector3(-0.06 - k * 0.045, 0.19 - k * 0.025, -0.11 + k * 0.075)
		_tube(g, _line(sp, sp + Vector3(-0.07, 0.15, 0.0), 3), PackedFloat32Array([0.035, 0.018, 0.0]), {"sides": 6})
	_mi(_arm[0], g, iron)
	_arm[0].rotation = Vector3(0.05, 0, -0.17)
	_arm[1].rotation = Vector3(0.15, 0, 0.12)
	_elbow[0].rotation.x = 0.25
	_elbow[1].rotation.x = 0.2
	# 자루 머리 (밧줄 올가미, 가늘게 찢어진 눈구멍, 꿰맨 입)
	g = Geo.new()
	_lathe(g, _p([[0.13, -0.06], [0.16, 0.02], [0.18, 0.12], [0.175, 0.22], [0.13, 0.3], [0.05, 0.345], [0.0, 0.35]]), {"sides": 18, "jit": 0.07, "nf": 7.0})
	_tube(g, _bez2(Vector3(0, 0.32, 0.02), Vector3(0.03, 0.38, 0.05), Vector3(0.0, 0.45, 0.1), 4), PackedFloat32Array([0.04, 0.05, 0.06, 0.03]), {"sides": 8, "jit": 0.3})
	_mi(_head, g, sack)
	g = Geo.new()
	_tube(g, _ellipse(0.145, 0.145, -0.02, 18), PackedFloat32Array([0.02]), {"sides": 6, "cap": false})
	for k in 4:
		_tube(g, _ellipse(0.03, 0.03, -0.04 - k * 0.032, 10, Vector3(0.13, 0, -0.03)), PackedFloat32Array([0.016]), {"sides": 5, "cap": false})
	_tube(g, _bez2(Vector3(0.13, -0.16, -0.03), Vector3(0.1, -0.35, -0.1), Vector3(0.05, -0.5, -0.17), 5), PackedFloat32Array([0.016, 0.015, 0.012, 0.01, 0.006]), {"sides": 5})
	_mi(_head, g, rope)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.06, 0.15, -0.166), Vector3(0.045, 0.013, 0.02), {"rot": Basis(Vector3.FORWARD, -sg * 0.28), "jit": 0.3})
	_mi(_head, g, dark)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.06, 0.15, -0.17), Vector3(0.04, 0.011, 0.014), {"rot": Basis(Vector3.FORWARD, -sg * 0.28)})
	_mi(_head, g, _eye_mat_get())
	_eyes_at(_head, [], 0.0, 0.0)
	_add_halos(_head, [Vector3(-0.06, 0.15, -0.19), Vector3(0.06, 0.15, -0.19)], 0.15)
	g = Geo.new()
	_stitches(g, _line(Vector3(-0.07, 0.04, -0.168), Vector3(0.07, 0.045, -0.168), 4), 7, 0.03)
	_stitches(g, _bez2(Vector3(0, 0.33, -0.05), Vector3(0, 0.27, -0.16), Vector3(0, 0.2, -0.18), 6), 5, 0.025)
	_mi(_head, g, thread)
	_head.scale = Vector3.ONE * 1.22
	# 거대한 처형 도끼 (바닥에 끌림)
	axe_in_hand = _node(_hand[1], Vector3(0, -0.07, 0))
	axe_in_hand.rotation.x = 0.62
	g = Geo.new()
	_tube(g, _line(Vector3(0, 0.25, 0), Vector3(0, -1.2, 0), 8), PackedFloat32Array([0.03, 0.033, 0.034, 0.034, 0.034, 0.034, 0.036, 0.04]), {"sides": 8})
	_mi(axe_in_hand, g, wood)
	g = Geo.new()
	for k in 3:
		_tube(g, _ellipse(0.04, 0.04, -0.03 - k * 0.045, 10), PackedFloat32Array([0.008]), {"sides": 4, "cap": false})
	_mi(axe_in_hand, g, leather)
	g = Geo.new()
	var blade := PackedVector2Array([Vector2(0.0, -0.14), Vector2(0.16, -0.26), Vector2(0.46, -0.42), Vector2(0.58, 0.0), Vector2(0.46, 0.42), Vector2(0.16, 0.26), Vector2(0.0, 0.14)])
	_extrude(g, blade, PackedFloat32Array([0.032, 0.022, 0.003, 0.002, 0.003, 0.022, 0.032]), Transform3D(Basis(Vector3(0, 0, -1), Vector3.UP, Vector3.RIGHT), Vector3(0, -1.0, -0.02)))
	_tube(g, _line(Vector3(0, -1.0, 0.02), Vector3(0, -0.97, 0.26), 3), PackedFloat32Array([0.042, 0.026, 0.0]), {"sides": 6})
	_tube(g, _line(Vector3(0, -1.14, 0), Vector3(0, -1.3, 0), 2), PackedFloat32Array([0.03, 0.0]), {"sides": 6})
	_mi(axe_in_hand, g, steel)


# ================================================================ 하마 (내일부터 다이어트)
## 뒤룩뒤룩한 거대한 괴물: 축 늘어진 배를 세로로 꿰맨 수술 자국, 튼살, 번들거리는 회보라 피부,
## 쩍 벌어지는 하마 턱 안에 엄니와 이빨이 빼곡하고 침이 늘어짐, 얼룩진 턱받이
func _build_diet() -> void:
	_S = 1.25
	_eye_color = Color(1.0, 0.78, 0.1)
	_stride = 0.35
	_step = 0.9
	_bob = 0.08
	_arm_amt = 0.3
	_twitch_rate = 0.2
	_twitch_amp = 0.35
	_skel(0.66, 0.4, 0.62, 0.12, 0.74, 0.6, 0.42, 0.42, 0.4, 0.3, 0.28)
	var skin := _m(Color(0.29, 0.26, 0.26), {"albedo2": Color(0.2, 0.15, 0.17), "mottle": 0.7, "mottle_scale": 3.5, "grime": 0.4,
		"roughness_v": 0.3, "bump": 0.35, "cracks": 0.45, "crack_color": Color(0.55, 0.32, 0.38), "crack_scale": 2.6, "blood": 0.15,
		"backlight_v": 0.15, "rim": 0.14, "rim_color": Color(0.8, 0.5, 0.65)})
	var gum := _m(Color(0.42, 0.06, 0.09), {"albedo2": Color(0.6, 0.15, 0.18), "mottle": 0.4, "roughness_v": 0.18, "grime": 0.15, "blood": 0.3})
	var tooth := _m(Color(0.78, 0.7, 0.5), {"albedo2": Color(0.55, 0.45, 0.28), "mottle": 0.4, "roughness_v": 0.3, "grime": 0.4})
	var thread := _m(Color(0.1, 0.03, 0.03), {"roughness_v": 0.6, "grime": 0.0})
	var bib := _m(Color(0.4, 0.37, 0.32), {"albedo2": Color(0.28, 0.24, 0.18), "mottle": 0.6, "grime": 0.7, "blood": 0.35, "blood_scale": 3.0, "kind": "cloth", "sway": 0.02, "roughness_v": 0.9, "bump": 0.6, "bump_scale": 24.0})
	var drool := _m(Color(0.7, 0.72, 0.65), {"roughness_v": 0.05, "grime": 0.0, "mottle": 0.0, "rim": 0.3, "rim_color": Color(0.8, 0.9, 0.8), "sway": 0.03})
	var dark := _dark_mat()
	var nail := _m(Color(0.12, 0.1, 0.08), {"roughness_v": 0.5})
	_spine.rotation.x = -0.04
	_neck.rotation.x = 0.1
	var prof := [[0.0, -0.5], [0.45, -0.42], [0.72, -0.2], [0.82, 0.05], [0.8, 0.3], [0.7, 0.5], [0.55, 0.62]]
	var sag := func(p: Vector3) -> Vector3:
		if p.z < 0.0:
			var w := clampf(-p.z / 0.8, 0.0, 1.0)
			p.z -= 0.16 * w * smoothstep(0.5, -0.1, p.y)
			p.y -= 0.08 * w * smoothstep(0.1, -0.4, p.y)
		p *= 1.0 + 0.03 * sin(p.y * 18.0)
		return p
	var g := Geo.new()
	_lathe(g, _p(prof), {"sides": 24, "sx": 1.15, "jit": 0.025, "deform": sag})
	_mi(_spine, g, skin)
	g = Geo.new()  # 꿰맨 수술 자국
	var seam := PackedVector3Array()
	for k in 12:
		var y := lerpf(0.5, -0.3, k / 11.0)
		var p := Vector3(0.0, y, -(_prof_r(prof, y) + 0.004))
		seam.append(sag.call(p))
	_stitches(g, seam, 12, 0.08)
	_tube(g, seam, PackedFloat32Array([0.013]), {"sides": 5})
	_mi(_spine, g, thread)
	g = Geo.new()  # 옆구리·등의 늘어진 살 접힘
	for y: float in [0.28, -0.02, -0.28]:
		var roll := PackedVector3Array()
		for k in 17:
			var a := lerpf(-0.35, PI + 0.35, k / 16.0) + PI   # 뒤쪽 반 바퀴
			var r := _prof_r(prof, y) + 0.01
			roll.append(sag.call(Vector3(cos(a) * r * 1.15, y - 0.03 * sin(k / 16.0 * PI), -sin(a) * r)))
		_tube(g, roll, PackedFloat32Array([0.0, 0.05, 0.075, 0.08, 0.08, 0.075, 0.05, 0.0]), {"sides": 8})
	_mi(_spine, g, skin)
	g = Geo.new()  # 배를 감은 줄자 (다이어트) + 늘어진 끝
	var tape := PackedVector3Array()
	for k in 33:
		var a := TAU * k / 32.0
		var y := 0.12 - 0.05 * cos(a - PI * 0.5)
		var r := _prof_r(prof, y) + 0.012
		tape.append(sag.call(Vector3(cos(a) * r * 1.15, y, -sin(a) * r)))
	_tube(g, tape, PackedFloat32Array([0.006]), {"sides": 4, "flat": 6.0, "cap": false})
	var t0 := tape[8]
	_tube(g, _bez3(t0, t0 + Vector3(0.05, -0.1, -0.06), t0 + Vector3(-0.04, -0.3, -0.05), t0 + Vector3(0.02, -0.5, -0.02), 8), PackedFloat32Array([0.006]), {"sides": 4, "flat": 6.0})
	_mi(_spine, g, _m(Color(0.75, 0.62, 0.12), {"albedo2": Color(0.5, 0.38, 0.06), "mottle": 0.4, "grime": 0.55, "blood": 0.3, "roughness_v": 0.8, "kind": "cloth", "sway": 0.02}))
	g = Geo.new()
	_lathe(g, _p([[0.6, -0.12], [0.68, 0.15], [0.62, 0.4], [0.48, 0.56], [0.34, 0.64]]), {"sides": 22, "sx": 1.2, "sz": 0.95, "jit": 0.02})
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.7, 0.42, 0.0), Vector3(0.24, 0.22, 0.24))
		_ell(g, Vector3(sg * 0.32, 0.22, -0.48), Vector3(0.22, 0.2, 0.14))
	_mi(_chest, g, skin)
	g = Geo.new()
	_lathe(g, _p([[0.52, 0.62], [0.6, 0.45], [0.66, 0.2], [0.7, 0.0]]), {"sides": 14, "sx": 1.18, "sz": 1.0, "a0": 0.6, "a1": PI - 0.6, "jit": 0.04})
	_tube(g, _ellipse(0.42, 0.4, 0.66, 20), PackedFloat32Array([0.015]), {"sides": 4, "cap": false})
	_mi(_chest, g, bib)
	g = Geo.new()
	_ell(g, Vector3(0, -0.02, 0.02), Vector3(0.62, 0.3, 0.55))
	_mi(_hips, g, skin)
	# 하마 머리
	g = Geo.new()
	_ell(g, Vector3(0, 0.2, 0.08), Vector3(0.38, 0.27, 0.34), {"jit": 0.03})
	_ell(g, Vector3(0, 0.12, -0.3), Vector3(0.35, 0.19, 0.3))
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.12, 0.25, -0.5), Vector3(0.08, 0.06, 0.07))
		_ell(g, Vector3(sg * 0.2, 0.38, -0.06), Vector3(0.085, 0.07, 0.085))
		_ell(g, Vector3(sg * 0.29, 0.44, 0.13), Vector3(0.05, 0.075, 0.03), {"rot": Basis(Vector3.UP, sg * 0.4)})
	_mi(_head, g, skin)
	g = Geo.new()
	_ell(g, Vector3(0, -0.04, -0.3), Vector3(0.3, 0.05, 0.27))
	_mi(_head, g, gum)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.12, 0.3, -0.52), Vector3(0.035, 0.008, 0.02), {"rot": Basis(Vector3.UP, sg * 0.5)})
		_ell(g, Vector3(sg * 0.2, 0.39, -0.135), Vector3(0.04, 0.03, 0.02))
	_ell(g, Vector3(0, 0.02, -0.02), Vector3(0.2, 0.12, 0.1))
	_mi(_head, g, dark)
	_eyes_at(_head, [Vector3(-0.2, 0.385, -0.135), Vector3(0.2, 0.385, -0.135)], 0.013, 0.1)
	g = Geo.new()
	for sg: float in [-1.0, 1.0]:
		_ell(g, Vector3(sg * 0.19, 0.43, -0.12), Vector3(0.1, 0.035, 0.06), {"rot": Basis(Vector3.FORWARD, sg * 0.35)})
	_mi(_head, g, skin)
	g = Geo.new()  # 주둥이의 뻣뻣한 털
	for k in 26:
		var a := _rng.randf_range(-1.2, 1.2)
		var bp := Vector3(sin(a) * 0.3, 0.12 + cos(a) * 0.12, -0.42 - cos(a) * 0.1)
		_tube(g, _line(bp, bp + Vector3(sin(a) * 0.03, 0.02, -0.05), 2), PackedFloat32Array([0.004, 0.0]), {"sides": 3})
	_mi(_head, g, nail)
	_head.scale = Vector3.ONE * 1.15
	g = Geo.new()
	_teeth(g, Vector3(0, -0.06, -0.3), 0.29, 0.27, 16, 0.07, 0.016, true)
	for sg: float in [-1.0, 1.0]:
		_tube(g, _bez2(Vector3(sg * 0.25, -0.03, -0.42), Vector3(sg * 0.27, -0.12, -0.45), Vector3(sg * 0.24, -0.2, -0.42), 5), PackedFloat32Array([0.035, 0.03, 0.022, 0.012, 0.0]), {"sides": 7})
	_mi(_head, g, tooth)
	mouth_jaw = _node(_head, Vector3(0, -0.04, 0.05))
	_jaw = mouth_jaw
	g = Geo.new()
	_ell(g, Vector3(0, -0.1, -0.32), Vector3(0.34, 0.13, 0.32), {"jit": 0.03})
	_mi(mouth_jaw, g, skin)
	g = Geo.new()
	_ell(g, Vector3(0, -0.02, -0.33), Vector3(0.29, 0.05, 0.27))
	_ell(g, Vector3(0, 0.0, -0.28), Vector3(0.14, 0.04, 0.2))
	_mi(mouth_jaw, g, gum)
	g = Geo.new()
	_teeth(g, Vector3(0, -0.01, -0.33), 0.28, 0.27, 14, 0.06, 0.015, false)
	for sg: float in [-1.0, 1.0]:
		_tube(g, _bez3(Vector3(sg * 0.2, -0.03, -0.53), Vector3(sg * 0.23, 0.08, -0.56), Vector3(sg * 0.27, 0.18, -0.52), Vector3(sg * 0.24, 0.26, -0.46), 7),
			PackedFloat32Array([0.05, 0.046, 0.04, 0.032, 0.022, 0.011, 0.0]), {"sides": 8})
	_mi(mouth_jaw, g, tooth)
	g = Geo.new()
	for k in 4:
		var x := -0.18 + k * 0.12
		var L := 0.15 + float(k % 2) * 0.22
		_tube(g, _line(Vector3(x, -0.12, -0.5 + absf(x) * 0.3), Vector3(x * 1.05, -0.12 - L, -0.5 + absf(x) * 0.3), 4), PackedFloat32Array([0.008, 0.004, 0.005, 0.009]), {"sides": 4})
	_mi(mouth_jaw, g, drool)
	# 굵은 팔다리
	for i in 2:
		var sg := -1.0 if i == 0 else 1.0
		g = Geo.new()
		_limb(g, Vector3(0, 0.05, 0), Vector3(0, -0.42, 0), 0.2, 0.2, 0.16, 12, 0.03)
		_mi(_arm[i], g, skin)
		g = Geo.new()
		_limb(g, Vector3(0, 0.02, 0), Vector3(0, -0.4, 0), 0.16, 0.16, 0.12, 12, 0.03)
		_mi(_elbow[i], g, skin)
		g = Geo.new()
		var gn := Geo.new()
		_hand_geo(g, gn, sg, 0.1, 0.13, 0.11, 0.035, 4, 0.55, 0.035)
		_mi(_hand[i], g, skin)
		_mi(_hand[i], gn, nail)
		_arm[i].rotation = Vector3(0.12, 0, sg * 0.35)
		_elbow[i].rotation.x = 0.4
		g = Geo.new()
		_limb(g, Vector3(0, 0.05, 0), Vector3(0, -0.3, 0), 0.27, 0.26, 0.22, 12)
		_mi(_leg[i], g, skin)
		g = Geo.new()
		_limb(g, Vector3(0, 0.0, 0), Vector3(0, -0.28, 0), 0.22, 0.21, 0.2, 12)
		_mi(_knee[i], g, skin)
		g = Geo.new()
		_ell(g, Vector3(0, -0.02, -0.04), Vector3(0.21, 0.08, 0.24))
		_mi(_foot[i], g, skin)
		g = Geo.new()
		for k in 4:
			var a := PI * 0.5 + (k - 1.5) * 0.4
			_ell(g, Vector3(cos(a) * 0.2, -0.03, -0.04 - sin(a) * 0.22), Vector3(0.035, 0.03, 0.03))
		_mi(_foot[i], g, nail)


# ================================================================ 공격 · 애니메이션

## 공격 모션: 팔을 머리 위로 치켜들었다가 앞으로 내려침 (짐승은 몸을 날려 물어뜯음)
func attack(windup: float) -> void:
	_attack_dur = maxf(0.15, windup * 1.8)  # 공격 속도에 맞춰 모션 길이도 함께 바뀜
	_attack_t = _attack_dur


func animate(delta: float, speed: float) -> void:
	if _hips == null:
		return
	if _jerk_fps > 0.0:
		if speed < 0.05 and _attack_t <= 0.0:
			return  # 마네킹: 아무도 안 움직일 때는 숨도 안 쉬고 완전히 굳음
		_jerk_acc += delta
		if _jerk_acc < 1.0 / _jerk_fps:
			return
		delta = _jerk_acc
		_jerk_acc = 0.0
	_time += delta
	var amount := clampf(speed / 6.0, 0.0, 1.5)
	var run := clampf((speed - 5.0) / 5.0, 0.0, 1.0)
	_phase += delta * speed / _step * PI
	if _phase > TAU * 64.0:
		_phase -= TAU * 64.0
	_update_twitch(delta)
	match _rig:
		"hound": _pose_hound(amount, run)
		"spider": _pose_spider(amount, run)
		"float": _pose_float(amount, run)
		_: _pose_biped(amount, run)
	if _tail.size() > 0:
		for k in _tail.size():
			_rot(_tail[k], Vector3(sin(_time * 2.2 - k * 0.7) * 0.06, sin(_time * 3.0 - k * 0.6) * (0.18 + 0.1 * amount), 0))
	if _attack_t > 0.0:
		_attack_t -= delta
		_pose_attack(clampf(1.0 - _attack_t / _attack_dur, 0.0, 1.0))
	if _mouth_t > 0.0 and _jaw:
		_jaw.rotation.x -= 0.45 * _mouth_t   # 아래턱은 조금만 (몸에 파묻히지 않게)
		_head.rotation.x += 0.7 * _mouth_t   # 위턱(머리)을 뒤로 크게 젖혀 입을 쩍 벌림
	if _cross:
		_cross.position = Vector3(sin(_time * 0.9) * 0.05, _cross_y + sin(_time * 1.3) * 0.03 - absf(sin(_phase)) * 0.05 * amount, -0.05)
		_cross.rotation = Vector3(sin(_time * 1.1) * 0.12, sin(_time * 0.5) * 0.2, sin(_phase) * 0.15 * amount)
	_update_danglers()
	_update_strings()
	_flicker_eyes(delta)


func _pose_biped(amount: float, run: float) -> void:
	var s := sin(_phase)
	var c := cos(_phase)
	var br := sin(_time * 1.7)
	var dip := absf(s) * _bob * amount + _limp * maxf(0.0, -s) * 0.08 * amount
	_hips.position.y = _hip_y - dip + br * 0.004
	_rot(_hips, Vector3(0, s * 0.1 * amount, s * 0.05 * amount + _limp * maxf(0.0, -s) * 0.1 * amount))
	_rot(_spine, Vector3(_lean * run - 0.05 * amount + br * 0.012, -s * 0.06 * amount, 0))
	_rot(_chest, Vector3(br * 0.02, -s * 0.12 * amount, 0))
	var hv := _head_extra()
	_rot(_neck, Vector3(-_lean * run * 0.5, 0, 0) + hv * 0.35)
	_rot(_head, Vector3(c * 0.04 * amount, 0, 0) + hv * 0.65)
	if _jaw:
		_rot(_jaw, Vector3(-maxf(0.0, sin(_time * 0.7)) * 0.08, 0, 0))
	for i in 2:
		var sg := 1.0 if i == 0 else -1.0
		var sw := s * sg
		var cw := c * sg
		var st := _stride * amount * (1.0 - _limp * 0.6 * float(i))
		if _leg[i]:
			var th := sw * st + 0.12 * run
			var kn := -(maxf(0.0, cw) * _knee_amt * amount + 0.06 * amount + 0.5 * run * maxf(0.0, cw))
			_rot(_leg[i], Vector3(th, 0, 0))
			_rot(_knee[i], Vector3(kn, 0, 0))
			_rot(_foot[i], Vector3(-(th + kn) * 0.7, 0, 0))
		if _arm[i] == null:
			continue
		if i == 1 and _hold_right:
			_rot(_arm[i], Vector3(sw * 0.12 * amount + sin(_time * 0.8) * 0.02, 0, 0))
			_rot(_elbow[i], Vector3(0.1 * run, 0, 0))
		else:
			_rot(_arm[i], Vector3(-sw * _arm_amt * amount + sin(_time * 0.9 + i * 2.0) * 0.03, 0, 0))
			_rot(_elbow[i], Vector3(0.15 * amount + 0.5 * run + maxf(0.0, -sw) * 0.25 * amount, 0, 0))


func _pose_float(amount: float, _run: float) -> void:
	var br := sin(_time * 1.3)
	_hips.position.y = _hip_y + sin(_time * 1.6) * 0.06
	_rot(_hips, Vector3(0, sin(_time * 0.7) * 0.06, sin(_time * 1.1) * 0.035))
	_rot(_spine, Vector3(-0.12 * amount + br * 0.02, 0, 0))
	_rot(_chest, Vector3(br * 0.025, 0, 0))
	var hv := _head_extra()
	_rot(_neck, hv * 0.35)
	_rot(_head, hv * 0.65)
	for i in 2:
		var sg := -1.0 if i == 0 else 1.0
		_rot(_arm[i], Vector3(sin(_time * 1.1 + i * 1.7) * 0.07 + 0.25 * amount, 0, sg * sin(_time * 0.8 + i) * 0.05))
		_rot(_elbow[i], Vector3(sin(_time * 1.4 + i) * 0.1 - 0.15 * amount, 0, 0))
		_rot(_hand[i], Vector3(sin(_time * 2.3 + i * 3.0) * 0.12, 0, 0))


func _pose_hound(amount: float, run: float) -> void:
	var trot := [0.0, PI, PI, 0.0]
	var gallop := [0.0, 0.35, PI, PI + 0.35]
	_hips.position.y = _hip_y - absf(sin(_phase)) * 0.05 * amount + sin(_time * 2.0) * 0.006
	_rot(_hips, Vector3(sin(_phase) * 0.08 * run, sin(_phase * 0.5) * 0.04 * amount, 0))
	for i in 4:
		var legs: Array = _legs4[i]
		var off := lerpf(float(trot[i]), float(gallop[i]), run)
		var ph := _phase + off
		var lift := maxf(0.0, cos(ph)) * amount
		_rot(legs[0], Vector3(sin(ph) * 0.5 * amount, 0, 0))
		if i < 2:
			_rot(legs[1], Vector3(-lift * 0.9, 0, 0))
			_rot(legs[2], Vector3(-lift * 0.5, 0, 0))
		else:
			_rot(legs[1], Vector3(-lift * 0.6, 0, 0))
			_rot(legs[2], Vector3(lift * 0.8, 0, 0))
	for h in _heads.size():
		var n1 := _noise.get_noise_2d(_time * 2.5, h * 37.0)
		var n2 := _noise.get_noise_2d(_time * 2.5, h * 37.0 + 100.0)
		var tw := _twitch_v * (1.0 if h == 1 else -0.7)
		_rot(_heads[h], Vector3(n1 * 0.3 + sin(_phase + h) * 0.08 * amount, n2 * 0.4, n2 * 0.15) + tw * 0.6)
		_rot(_jaws[h], Vector3(-(0.12 + 0.25 * maxf(0.0, sin(_time * 2.3 + h * 2.1)) + 0.2 * run), 0, 0))


func _pose_spider(amount: float, _run: float) -> void:
	_hips.position.y = _hip_y + absf(sin(_phase * 2.0)) * 0.03 * amount + sin(_time * 1.5) * 0.012
	_rot(_hips, Vector3(sin(_time * 1.1) * 0.02, sin(_phase) * 0.04 * amount, 0))
	for i in _sp_legs.size():
		var pair: Array = _sp_legs[i]
		var side := -1.0 if i < 4 else 1.0
		var j := i % 4
		var grp := float((j + (0 if i < 4 else 1)) % 2)
		var ph := _phase * 0.8 + grp * PI
		var lift := maxf(0.0, sin(ph)) * amount
		var fwd := -cos(ph) * amount
		var idle := pow(maxf(0.0, sin(_time * 2.6 + i * 1.9)), 10.0) * 0.22 * (1.0 - minf(amount * 2.0, 1.0))
		_rot(pair[0], Vector3(0, fwd * 0.22 * side, (lift * 0.35 + idle) * side))
		_rot(pair[1], Vector3(0, 0, -lift * 0.15 * side))
	_rot(_abd, Vector3(sin(_time * 1.4) * 0.05, sin(_phase) * 0.06 * amount, 0))
	_rot(_spine, Vector3(sin(_time * 1.2) * 0.04 - 0.12 * amount, sin(_time * 0.7) * 0.1, 0))
	var hv := _head_extra()
	_rot(_neck, hv * 0.4)
	_rot(_head, hv * 0.6)
	for i in 2:
		_rot(_arm[i], Vector3(sin(_time * 2.0 + i * 1.3) * 0.08, 0, 0))
		_rot(_elbow[i], Vector3(sin(_time * 2.6 + i) * 0.1, 0, 0))


func _pose_attack(p: float) -> void:
	var w := smoothstep(0.0, 0.1, p) * (1.0 - smoothstep(0.85, 1.0, p))
	var raise := 0.45
	var slam := clampf((p - raise) / 0.14, 0.0, 1.0)
	var a: float = lerpf(0.4, 2.9, 1.0 - pow(1.0 - p / raise, 2.0)) if p < raise else lerpf(2.9, 0.85, slam)
	var lunge: float = lerpf(0.0, 0.12, p / raise) if p < raise else lerpf(0.12, -0.42, slam)
	if _rig == "hound":
		_hips.rotation.x += w * (0.1 if p < raise else -0.18)
		_hips.position.z = lerpf(0.0, -0.25, w * slam)
		for i in 2:
			var hp: Node3D = _legs4[i][0]
			hp.rotation.x += w * (0.9 if p < raise else 0.35)
		for h in _heads.size():
			_heads[h].rotation.x += w * (0.35 if p < raise else -0.45)
			var open := -1.0 if p < raise + 0.06 else lerpf(-1.0, -0.05, clampf((p - raise - 0.06) / 0.07, 0.0, 1.0))
			_jaws[h].rotation.x = lerpf(_jaws[h].rotation.x, open, w)
		return
	if _rig == "spider":
		for i: int in [0, 4]:
			var side := -1.0 if i == 0 else 1.0
			var hp: Node3D = _sp_legs[i][0]
			hp.rotation.z += w * side * (1.0 if p < raise else 0.15)
			hp.rotation.y += w * side * 0.35
	for i in 2:
		if _arm[i] == null:
			continue
		var r: Vector3 = _arm[i].rotation
		if i == 1 or not _hold_right:
			_arm[i].rotation = Vector3(lerpf(r.x, a, w), r.y, r.z * (1.0 - 0.5 * w))
			_elbow[i].rotation.x = lerpf(_elbow[i].rotation.x, 0.75 if p < raise else 0.12, w)
		else:
			_arm[i].rotation = Vector3(lerpf(r.x, 1.1, w), r.y, r.z)
			_elbow[i].rotation.x = lerpf(_elbow[i].rotation.x, 0.35, w)
	if _spine:
		_spine.rotation.x += w * lunge
	if _head:
		_head.rotation.x += w * (0.15 if p < raise else -0.25)
	if _jaw and _jaw != mouth_jaw:
		_jaw.rotation.x -= w * 0.5


## 하마 입 벌리기 (0 = 다물기, 1 = 쩍 벌림)
func set_mouth_open(t: float) -> void:
	_mouth_t = clampf(t, 0.0, 1.0)
	if mouth_jaw:
		mouth_jaw.scale = Vector3.ONE * (1.0 + 0.2 * _mouth_t)
		if _hips == null or not is_inside_tree():
			mouth_jaw.rotation.x = -0.45 * _mouth_t


## 폭주: 눈이 새빨갛게 더 밝아짐
func set_rage() -> void:
	var red := Color(1.0, 0.05, 0.03)
	for m in _eye_mats:
		m.albedo_color = red
		m.emission = red
	for m in _halo_mats:
		m.albedo_color = Color(1.0, 0.08, 0.04, m.albedo_color.a)
	if _eye_light:
		_eye_light.light_color = red
		_light_energy *= 1.6
	_eye_energy *= 1.35


## 봉인됐을 때 회색으로
func set_tint(color: Color) -> void:
	_tinted = true
	for m in _smats:
		m.set_shader_parameter("tint_color", color)
		m.set_shader_parameter("tint", 1.0)
	for m in _eye_mats:
		m.albedo_color = Color(color.r, color.g, color.b, m.albedo_color.a)
		m.emission_enabled = false
	for m in _glow_mats:
		m.albedo_color = Color(color.r, color.g, color.b, m.albedo_color.a)
		m.emission_enabled = false
	for h in _halos:
		h.visible = false
	if _eye_light:
		_eye_light.visible = false


func _rot(n: Node3D, off: Vector3) -> void:
	if n:
		var r: Vector3 = _rest.get(n, Vector3.ZERO)
		n.rotation = r + off


func _head_extra() -> Vector3:
	var j := Vector3.ZERO
	if _jitter > 0.0:
		j = Vector3(_noise.get_noise_2d(_time * 9.0, 3.0), _noise.get_noise_2d(_time * 9.0, 40.0), _noise.get_noise_2d(_time * 9.0, 90.0)) * _jitter
	return _twitch_v + j


## 가끔 고개를 홱 꺾었다가 천천히 돌아옴
func _update_twitch(delta: float) -> void:
	_twitch_cd -= delta
	if _twitch_cd <= 0.0:
		_twitch_cd = randf_range(0.5, 2.0) / maxf(_twitch_rate, 0.05)
		_twitch_target = Vector3(randf_range(-0.3, 0.35), randf_range(-0.5, 0.5), randf_range(-0.6, 0.6)) * _twitch_amp
		_twitch_hold = randf_range(0.2, 0.9)
	if _twitch_hold > 0.0:
		_twitch_hold -= delta
		_twitch_v = _twitch_v.lerp(_twitch_target, minf(1.0, 28.0 * delta))
	else:
		_twitch_v = _twitch_v.lerp(Vector3.ZERO, minf(1.0, 2.0 * delta))


func _update_danglers() -> void:
	for d in _danglers:
		if d.is_inside_tree():
			var sw := Vector3(sin(_time * 2.1 + d.position.x * 5.0) * 0.08, 0, cos(_time * 1.7) * 0.06)
			d.global_basis = _root.global_basis * Basis.from_euler(sw) * Basis.from_scale(d.get_meta("dscale", Vector3.ONE))


func _update_strings() -> void:
	for s in _strings:
		var mi: MeshInstance3D = s[0]
		var na: Node3D = s[1]
		var nb: Node3D = s[3]
		if not mi.is_inside_tree():
			continue
		var a: Vector3 = na.global_transform * (s[2] as Vector3)
		var b: Vector3 = nb.global_transform * (s[4] as Vector3)
		var d := b - a
		var l := d.length()
		if l < 0.01:
			continue
		var y := d / l
		var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
		var z := x.cross(y)
		mi.global_transform = Transform3D(Basis(x, y * l, z), (a + b) * 0.5)


## 눈이 지직거리며 깜빡임 (가끔 완전히 꺼졌다 켜짐)
func _flicker_eyes(delta: float) -> void:
	if _tinted:
		return
	_blink -= delta
	var e := 1.0 + randf_range(-0.15, 0.15)
	if _blink <= 0.0:
		_blink = randf_range(1.8, 4.5)
	elif _blink < 0.1:
		e = 0.0
	for m in _eye_mats:
		m.emission_energy_multiplier = _eye_energy * e
	for m in _halo_mats:
		m.albedo_color = Color(m.albedo_color.r, m.albedo_color.g, m.albedo_color.b, 0.8 * e)
	if _eye_light:
		_eye_light.light_energy = _light_energy * e


# ================================================================ 뼈대 · 재질 도우미

func _node(parent: Node3D, pos: Vector3) -> Node3D:
	if parent == self:
		parent = _root
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	return n


func _skel(hip_y: float, spine_len: float, chest_len: float, neck_len: float, sh_w: float, sh_y: float, hip_w: float,
		upper: float, fore: float, thigh: float, shin: float) -> void:
	_hips = _node(self, Vector3(0, hip_y, 0))
	_spine = _node(_hips, Vector3(0, 0.02, 0))
	_chest = _node(_spine, Vector3(0, spine_len, 0))
	_neck = _node(_chest, Vector3(0, chest_len, 0))
	_head = _node(_neck, Vector3(0, neck_len, 0))
	for i in 2:
		var sg := -1.0 if i == 0 else 1.0
		_arm[i] = _node(_chest, Vector3(sg * sh_w, chest_len * sh_y, 0))
		_elbow[i] = _node(_arm[i], Vector3(0, -upper, 0))
		_hand[i] = _node(_elbow[i], Vector3(0, -fore, 0))
		if thigh > 0.0:
			_leg[i] = _node(_hips, Vector3(sg * hip_w, 0, 0))
			_knee[i] = _node(_leg[i], Vector3(0, -thigh, 0))
			_foot[i] = _node(_knee[i], Vector3(0, -shin, 0))


func _m(base: Color, o: Dictionary = {}) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	var kind: String = o.get("kind", "solid")
	m.shader = SH_CLOTH if kind == "cloth" else (SH_FADE if kind == "fade" else SH_SOLID)
	m.set_shader_parameter("albedo", base)
	if not o.has("albedo2"):
		m.set_shader_parameter("albedo2", base.darkened(0.35))
	for k: String in o:
		if k != "kind":
			m.set_shader_parameter(k, o[k])
	_smats.append(m)
	return m


func _metal(c: Color, rough: float) -> ShaderMaterial:
	return _m(c, {"metallic_v": 0.8, "roughness_v": rough, "grime": 0.5, "grime_color": Color(0.2, 0.09, 0.04), "blood": 0.35,
		"bump": 0.15, "mottle": 0.3, "rim": 0.08})


func _hair_mat(c: Color) -> ShaderMaterial:
	return _m(c, {"albedo2": c.lightened(0.15), "roughness_v": 0.5, "rim": 0.14, "rim_color": Color(0.35, 0.4, 0.5), "kind": "cloth",
		"sway": 0.025, "sway_speed": 1.8, "under_ao": 0.0, "bump": 0.3, "bump_scale": 60.0, "mottle": 0.3, "grime": 0.0})


func _dark_mat() -> ShaderMaterial:
	return _m(Color(0.0, 0.0, 0.0), {"albedo2": Color(0.02, 0.0, 0.0), "roughness_v": 1.0, "rim": 0.0, "grime": 0.0, "under_ao": 0.0, "bump": 0.0})


func _glow_mat(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c * 0.4
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	m.roughness = 0.3
	_glow_mats.append(m)
	return m


func _eye_mat_get() -> StandardMaterial3D:
	if _eye_m == null:
		_eye_m = StandardMaterial3D.new()
		_eye_m.albedo_color = _eye_color
		_eye_m.emission_enabled = true
		_eye_m.emission = _eye_color
		_eye_m.emission_energy_multiplier = _eye_energy
		_eye_m.roughness = 0.15
		_eye_mats.append(_eye_m)
	return _eye_m


## 빛나는 눈 + (앞의 두 눈에) 빛 번짐 + 눈 주변만 비추는 작은 조명
func _eyes_at(parent: Node3D, pts: Array, r: float, halo: float) -> void:
	var mat := _eye_mat_get()
	if pts.size() > 0:
		var g := Geo.new()
		for p: Vector3 in pts:
			_ell(g, p, Vector3(r, r * 0.8, r * 0.7), {"sides": 10, "rings": 6})
		_mi(parent, g, mat).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if halo > 0.0:
			_add_halos(parent, [pts[0], pts[1]] if pts.size() > 1 else [pts[0]], halo)
	if _eye_light == null and pts.size() > 0:
		var c := Vector3.ZERO
		for p: Vector3 in pts:
			c += p
		c /= float(pts.size())
		_eye_light = OmniLight3D.new()
		_eye_light.light_color = _eye_color
		_eye_light.omni_range = 1.3
		_eye_light.omni_attenuation = 2.0
		_eye_light.light_energy = _light_energy
		_eye_light.shadow_enabled = false
		_eye_light.light_specular = 0.2
		_eye_light.position = c + Vector3(0, -0.05, -0.3)
		parent.add_child(_eye_light)
	elif _eye_light == null and type == "executioner":
		_eye_light = OmniLight3D.new()
		_eye_light.light_color = _eye_color
		_eye_light.omni_range = 1.6
		_eye_light.omni_attenuation = 1.6
		_eye_light.shadow_enabled = false
		_eye_light.light_specular = 0.3
		_eye_light.position = Vector3(0, 0.15, -0.3)
		parent.add_child(_eye_light)


func _add_halos(parent: Node3D, pts: Array, size: float) -> void:
	if _halo_tex == null:
		_halo_tex = GradientTexture2D.new()
		_halo_tex.fill = GradientTexture2D.FILL_RADIAL
		_halo_tex.fill_from = Vector2(0.5, 0.5)
		_halo_tex.fill_to = Vector2(0.5, 0.0)
		_halo_tex.width = 64
		_halo_tex.height = 64
		var gr := Gradient.new()
		gr.offsets = PackedFloat32Array([0.0, 0.18, 0.5, 1.0])
		gr.colors = PackedColorArray([Color(1, 1, 1, 1), Color(0.5, 0.5, 0.5, 1), Color(0.1, 0.1, 0.1, 1), Color(0, 0, 0, 1)])
		_halo_tex.gradient = gr
	var hm := StandardMaterial3D.new()
	hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	hm.fixed_size = true  # 멀리서도 같은 크기로 보여서 어둠 속에서 눈빛이 잘 보임
	hm.albedo_texture = _halo_tex
	hm.albedo_color = Color(_eye_color.r, _eye_color.g, _eye_color.b, 0.55)
	_halo_mats.append(hm)
	var q := QuadMesh.new()
	q.size = Vector2(size, size) * 0.2
	for p: Vector3 in pts:
		var mi := MeshInstance3D.new()
		mi.mesh = q
		mi.material_override = hm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = p + Vector3(0, 0, _halo_z)
		parent.add_child(mi)
		_halos.append(mi)


func _add_string(from: Node3D, a: Vector3, to: Node3D, b: Vector3, mat: Material) -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = 0.0025
	cm.bottom_radius = 0.0025
	cm.height = 1.0
	cm.radial_segments = 4
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	mi.position = Vector3(0, 2.5, 0)
	_strings.append([mi, from, a, to, b])


func _mi(parent: Node3D, g: Geo, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	if _use_cache:
		var cached: Array = _mesh_cache[type]
		mi.mesh = cached[_mi_count] if _mi_count < cached.size() else null
	elif g.idx.size() > 0:
		mi.mesh = g.mesh()
	if not _use_cache:
		_mesh_list.append(mi.mesh)
	_mi_count += 1
	mi.material_override = mat
	parent.add_child(mi)
	return mi


func _ell_geo(c: Vector3, r: Vector3) -> Geo:
	var g := Geo.new()
	_ell(g, c, r)
	return g


# ================================================================ 메시 만들기 도우미

## 삼각형 모음. tri()는 바깥에서 봤을 때 반시계 방향으로 넣으면 됨
class Geo:
	var v := PackedVector3Array()
	var uv := PackedVector2Array()
	var col := PackedColorArray()
	var idx := PackedInt32Array()

	func add(p: Vector3, t: Vector2, c: Color) -> int:
		v.append(p)
		uv.append(t)
		col.append(c)
		return v.size() - 1

	func tri(a: int, b: int, c: int) -> void:
		idx.append(a)
		idx.append(c)
		idx.append(b)

	func quad(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, c)
		tri(a, c, d)

	func mesh() -> ArrayMesh:
		var nr := PackedVector3Array()
		nr.resize(v.size())
		for i in range(0, idx.size(), 3):
			var i0 := idx[i]
			var i1 := idx[i + 1]
			var i2 := idx[i + 2]
			var fn := (v[i2] - v[i0]).cross(v[i1] - v[i0])
			nr[i0] += fn
			nr[i1] += fn
			nr[i2] += fn
		for i in nr.size():
			nr[i] = nr[i].normalized() if nr[i].length_squared() > 1e-16 else Vector3.UP
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = nr
		arr[Mesh.ARRAY_TEX_UV] = uv
		arr[Mesh.ARRAY_COLOR] = col
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


func _p(arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for e: Array in arr:
		out.append(Vector2(float(e[0]), float(e[1])))
	return out


## 단면 반지름표(prof)에서 높이 y의 반지름
func _prof_r(prof: Array, y: float) -> float:
	for k in prof.size() - 1:
		var a: Array = prof[k]
		var b: Array = prof[k + 1]
		if (y >= float(a[1]) and y <= float(b[1])) or (y <= float(a[1]) and y >= float(b[1])):
			var t := (y - float(a[1])) / maxf(0.0001, float(b[1]) - float(a[1]))
			return lerpf(float(a[0]), float(b[0]), t)
	return float((prof[0] as Array)[0])


func _sample(keys: PackedFloat32Array, t: float) -> float:
	if keys.size() == 1:
		return keys[0]
	var f := clampf(t, 0.0, 1.0) * (keys.size() - 1)
	var i := mini(int(f), keys.size() - 2)
	return lerpf(keys[i], keys[i + 1], f - i)


func _line(a: Vector3, b: Vector3, n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in n:
		out.append(a.lerp(b, float(k) / maxf(1.0, n - 1)))
	return out


func _bez2(a: Vector3, b: Vector3, c: Vector3, n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in n:
		var t := float(k) / maxf(1.0, n - 1)
		out.append(a.lerp(b, t).lerp(b.lerp(c, t), t))
	return out


func _bez3(a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: int) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in n:
		var t := float(k) / maxf(1.0, n - 1)
		out.append(a.bezier_interpolate(b, c, d, t))
	return out


func _ellipse(rx: float, rz: float, y: float, n: int, center := Vector3.ZERO) -> PackedVector3Array:
	var out := PackedVector3Array()
	for k in n + 1:
		var a := TAU * float(k) / n
		out.append(center + Vector3(cos(a) * rx, y, -sin(a) * rz))
	return out


## 관(튜브): 점들을 따라 굵기가 변하는 원통. 팔다리·손가락·뿔·머리카락·이빨 등
## o: sides, flat(단면 납작함), up(납작한 방향 기준), jit(울퉁불퉁), nf(울퉁불퉁 크기), cap, xf, c0/c1(색)
func _tube(g: Geo, pts: PackedVector3Array, radii: PackedFloat32Array, o: Dictionary = {}) -> void:
	var n := pts.size()
	if n < 2 or _use_cache:
		return
	var sides: int = o.get("sides", 8)
	var flat: float = o.get("flat", 1.0)
	var jit: float = o.get("jit", 0.0)
	var nf: float = o.get("nf", 8.0)
	var cap: bool = o.get("cap", true)
	var xf: Transform3D = o.get("xf", Transform3D.IDENTITY)
	var c0: Color = o.get("c0", Color.WHITE)
	var c1: Color = o.get("c1", c0)
	var up: Vector3 = o.get("up", Vector3.ZERO)
	var lens := PackedFloat32Array()
	lens.resize(n)
	for k in range(1, n):
		lens[k] = lens[k - 1] + pts[k].distance_to(pts[k - 1])
	var total := maxf(lens[n - 1], 0.0001)
	var t0 := (pts[1] - pts[0]).normalized()
	if up == Vector3.ZERO or absf(up.normalized().dot(t0)) > 0.97:
		up = Vector3.UP if absf(t0.y) < 0.9 else Vector3.FORWARD
	var nrm := (up - t0 * up.dot(t0)).normalized()
	var seedv := Vector3(_rng.randf() * 50.0, _rng.randf() * 50.0, 0)
	var base := g.v.size()
	var same := radii.size() == n
	for k in n:
		var tk: Vector3
		if k == 0:
			tk = pts[1] - pts[0]
		elif k == n - 1:
			tk = pts[k] - pts[k - 1]
		else:
			tk = pts[k + 1] - pts[k - 1]
		tk = tk.normalized()
		nrm = (nrm - tk * nrm.dot(tk)).normalized()
		var bn := tk.cross(nrm)
		var r: float = radii[k] if same else _sample(radii, float(k) / (n - 1))
		var tt := lens[k] / total
		var cc := c0.lerp(c1, tt)
		for j in sides:
			var a := TAU * j / sides
			var off := nrm * cos(a) + bn * sin(a) * flat
			var rr := r
			if jit > 0.0:
				rr *= 1.0 + jit * _noise.get_noise_3dv((pts[k] + off * r) * nf + seedv)
			g.add(xf * (pts[k] + off * rr), Vector2(float(j) / sides, tt), cc)
	for k in n - 1:
		for j in sides:
			var j2 := (j + 1) % sides
			g.quad(base + k * sides + j, base + k * sides + j2, base + (k + 1) * sides + j2, base + (k + 1) * sides + j)
	if cap:
		var r0: float = radii[0] if same else _sample(radii, 0.0)
		var r1: float = radii[n - 1] if same else _sample(radii, 1.0)
		if r0 > 0.002:
			var c := g.add(xf * pts[0], Vector2(0.5, 0.0), c0)
			for j in sides:
				g.tri(c, base + (j + 1) % sides, base + j)
		if r1 > 0.002:
			var last := base + (n - 1) * sides
			var c := g.add(xf * pts[n - 1], Vector2(0.5, 1.0), c1)
			for j in sides:
				g.tri(c, last + j, last + (j + 1) % sides)


## 회전체: 단면 [반지름, 높이] 를 Y축으로 돌림. 몸통·머리·치마·로브 등
## o: sides, sx/sz(가로·앞뒤 비율), jit, nf, deform(Callable), a0/a1(일부만 감싸기), xf
func _lathe(g: Geo, prof: PackedVector2Array, o: Dictionary = {}) -> void:
	if _use_cache:
		return
	var sides: int = o.get("sides", 16)
	var sx: float = o.get("sx", 1.0)
	var sz: float = o.get("sz", 1.0)
	var jit: float = o.get("jit", 0.0)
	var nf: float = o.get("nf", 5.0)
	var a0: float = o.get("a0", 0.0)
	var a1: float = o.get("a1", TAU)
	var xf: Transform3D = o.get("xf", Transform3D.IDENTITY)
	var deform: Callable = o.get("deform", Callable())
	if prof[0].y > prof[prof.size() - 1].y:
		prof.reverse()
	var full := absf(a1 - a0) >= TAU - 0.001
	var cols := sides if full else sides + 1
	var ybot := prof[0].y
	var ytop := prof[prof.size() - 1].y
	var seedv := Vector3(_rng.randf() * 50.0, _rng.randf() * 50.0, _rng.randf() * 50.0)
	var base := g.v.size()
	for k in prof.size():
		for j in cols:
			var a := a0 + (a1 - a0) * float(j) / sides
			var dir := Vector3(cos(a), 0, -sin(a))
			var r := prof[k].x
			var p := Vector3(dir.x * r * sx, prof[k].y, dir.z * r * sz)
			if jit > 0.0 and r > 0.001:
				p += Vector3(dir.x * sx, 0.0, dir.z * sz) * jit * r * _noise.get_noise_3dv(p * nf + seedv) * 2.0
			if deform.is_valid():
				p = deform.call(p)
			g.add(xf * p, Vector2(float(j) / sides, (ytop - prof[k].y) / maxf(0.0001, ytop - ybot)), Color.WHITE)
	for k in prof.size() - 1:
		for j in sides:
			var j2 := (j + 1) % cols if full else j + 1
			g.quad(base + k * cols + j, base + k * cols + j2, base + (k + 1) * cols + j2, base + (k + 1) * cols + j)
	if full:
		if prof[0].x > 0.002:
			var c := g.add(xf * Vector3(0, prof[0].y, 0), Vector2(0.5, 1.0), Color.WHITE)
			for j in sides:
				g.tri(c, base + (j + 1) % cols, base + j)
		var lk := prof.size() - 1
		if prof[lk].x > 0.002:
			var c := g.add(xf * Vector3(0, prof[lk].y, 0), Vector2(0.5, 0.0), Color.WHITE)
			for j in sides:
				g.tri(c, base + lk * cols + j, base + lk * cols + (j + 1) % cols)


## 타원체. o: sides, rings, rot(Basis), jit, nf, xf
func _ell(g: Geo, c: Vector3, r: Vector3, o: Dictionary = {}) -> void:
	var rings: int = o.get("rings", 8)
	var prof := PackedVector2Array()
	for i in rings + 1:
		var ang := -PI * 0.5 + PI * float(i) / rings
		prof.append(Vector2(cos(ang), sin(ang) * r.y))
	var rot: Basis = o.get("rot", Basis())
	var xf: Transform3D = o.get("xf", Transform3D.IDENTITY)
	var o2 := {"sides": o.get("sides", 12), "sx": r.x, "sz": r.z, "jit": o.get("jit", 0.0), "nf": o.get("nf", 5.0),
		"xf": xf * Transform3D(rot, c)}
	_lathe(g, prof, o2)


## 납작한 판(칼날·귀 등): 반시계 방향 외곽선을 두께만큼 밀어냄. 날 쪽은 두께를 얇게
func _extrude(g: Geo, outline: PackedVector2Array, thick: PackedFloat32Array, xf: Transform3D) -> void:
	if _use_cache:
		return
	var n := outline.size()
	var c2 := Vector2.ZERO
	var ct := 0.0
	for i in n:
		c2 += outline[i]
		ct += thick[i]
	c2 /= n
	ct /= n
	var fc := g.add(xf * Vector3(c2.x, c2.y, ct), Vector2(0.5, 0.5), Color.WHITE)
	var f0 := g.v.size()
	for i in n:
		g.add(xf * Vector3(outline[i].x, outline[i].y, thick[i]), Vector2(0, 0), Color.WHITE)
	for i in n:
		g.tri(fc, f0 + i, f0 + (i + 1) % n)
	var bc := g.add(xf * Vector3(c2.x, c2.y, -ct), Vector2(0.5, 0.5), Color.WHITE)
	var b0 := g.v.size()
	for i in n:
		g.add(xf * Vector3(outline[i].x, outline[i].y, -thick[i]), Vector2(0, 0), Color.WHITE)
	for i in n:
		g.tri(bc, b0 + (i + 1) % n, b0 + i)
	for i in n:
		var i2 := (i + 1) % n
		var a := g.add(xf * Vector3(outline[i].x, outline[i].y, -thick[i]), Vector2(0, 1), Color.WHITE)
		var b := g.add(xf * Vector3(outline[i2].x, outline[i2].y, -thick[i2]), Vector2(1, 1), Color.WHITE)
		var c := g.add(xf * Vector3(outline[i2].x, outline[i2].y, thick[i2]), Vector2(1, 0), Color.WHITE)
		var d := g.add(xf * Vector3(outline[i].x, outline[i].y, thick[i]), Vector2(0, 0), Color.WHITE)
		g.quad(a, b, c, d)


## 팔다리 한 마디: a→b, 근육처럼 위쪽이 불룩하고 끝은 둥글게
func _limb(g: Geo, a: Vector3, b: Vector3, ra: float, rm: float, rb: float, sides := 10, jit := 0.0) -> void:
	var d := (b - a).normalized()
	var pts := PackedVector3Array([a - d * ra * 0.6, a - d * ra * 0.42, a, a.lerp(b, 0.3), a.lerp(b, 0.55), a.lerp(b, 0.8), b, b + d * rb * 0.42, b + d * rb * 0.6])
	var rad := PackedFloat32Array([0.0, ra * 0.72, ra, rm, (rm + rb) * 0.5 + (rm - rb) * 0.15, rb * 1.04, rb, rb * 0.72, 0.0])
	_tube(g, pts, rad, {"sides": sides, "jit": jit, "nf": 7.0})


## 손: 손목(원점)에서 아래(-Y)로 손가락. 손바닥은 몸 안쪽을 봄. 손톱(발톱)은 gn에
func _hand_geo(gs: Geo, gn: Geo, sg: float, palm_len: float, palm_w: float, flen: float, fr: float, nfing: int, curl: float, nail: float) -> void:
	var inward := Vector3(-sg, 0, 0)
	_ell(gs, Vector3(0, -palm_len * 0.5, 0), Vector3(fr * 1.5 + 0.012, palm_len * 0.62, palm_w * 0.55), {"sides": 10, "rings": 6})
	var lens := [0.92, 1.0, 0.95, 0.8]
	var segs := [0.45, 0.32, 0.23]
	for f in nfing:
		var t := 0.5 if nfing == 1 else float(f) / (nfing - 1)
		var z := lerpf(-palm_w * 0.42, palm_w * 0.42, t)
		var spread := (t - 0.5) * 0.3
		var L: float = flen * float(lens[f % 4])
		var p := Vector3(0, -palm_len * 0.92, z)
		var pts := PackedVector3Array([p + Vector3(0, 0.015, 0)])
		var rad := PackedFloat32Array([fr * 1.05])
		var dir := Vector3.DOWN
		for k in 3:
			var ang := curl * (k + 0.4)
			dir = (inward * sin(ang) + Vector3(0, -cos(ang), spread)).normalized()
			var sl: float = L * float(segs[k])
			var taper := 1.0 - 0.13 * k
			pts.append(p + dir * sl * 0.5)
			rad.append(fr * 0.82 * taper)
			p += dir * sl
			pts.append(p)
			rad.append(fr * (0.95 if k < 2 else 0.62) * taper)
		_tube(gs, pts, rad, {"sides": 6})
		if nail > 0.0:
			var d2 := (inward * sin(curl * 3.6) + Vector3(0, -cos(curl * 3.6), spread)).normalized()
			_tube(gn, PackedVector3Array([p - dir * fr * 0.8, p + d2 * nail * 0.5, p + d2 * nail]), PackedFloat32Array([fr * 0.7, fr * 0.5, 0.0]), {"sides": 5})
	var tb := Vector3(inward.x * fr * 1.2, -palm_len * 0.35, -palm_w * 0.55)
	var td := (inward * 0.45 + Vector3(0, -0.6, -0.55)).normalized()
	var td2 := (inward * 0.8 + Vector3(0, -0.7, -0.3)).normalized()
	var tp := PackedVector3Array([tb, tb + td * flen * 0.3, tb + td * flen * 0.3 + td2 * flen * 0.25])
	_tube(gs, tp, PackedFloat32Array([fr * 1.2, fr * 1.0, fr * 0.7]), {"sides": 6})
	if nail > 0.0:
		var te := tp[2]
		_tube(gn, PackedVector3Array([te - td2 * fr * 0.6, te + td2 * nail * 0.4, te + (td2 + inward * 0.3).normalized() * nail * 0.8]), PackedFloat32Array([fr * 0.65, fr * 0.45, 0.0]), {"sides": 5})


## 긴 머리카락 다발: 정수리에서 머리 둘레를 따라 내려와 아래로 늘어짐. gap_a~gap_b 각도는 비워 둠 (앞=0, 오른쪽=+)
func _hair(g: Geo, c: Vector3, rad: Vector3, count: int, len_front: float, len_back: float, w: float, gap_a: float, gap_b: float, wave: float) -> void:
	for i in count:
		var phi := -PI + TAU * (i + _rng.randf_range(0.0, 0.8)) / count
		if phi > gap_a and phi < gap_b:
			continue
		var dh := Vector3(sin(phi), 0, -cos(phi))
		var front := clampf(cos(phi), 0.0, 1.0)
		var L := lerpf(len_back, len_front, front) * _rng.randf_range(0.85, 1.1)
		var s := c + Vector3(dh.x * rad.x * 0.45, rad.y * 0.98, dh.z * rad.z * 0.45)
		var p1 := c + Vector3(dh.x * (rad.x + 0.012), rad.y * 0.55, dh.z * (rad.z + 0.012))
		var p2 := c + Vector3(dh.x * (rad.x + 0.022), -rad.y * 0.05, dh.z * (rad.z + 0.022))
		var pts := PackedVector3Array([s, p1, p2])
		var tan := Vector3(cos(phi), 0, sin(phi))
		var ph := _rng.randf() * TAU
		var wamp := wave * _rng.randf_range(0.5, 1.3)
		for k in range(1, 7):
			var t := k / 6.0
			var wv := tan * sin(ph + t * 5.0) * wamp * t + dh * (0.02 * k + absf(sin(ph * 1.7 + t * 4.0)) * wamp * 0.4 * t)
			pts.append(p2 + Vector3(0, -L * t, 0) + wv)
		var ww := w * _rng.randf_range(0.6, 1.25)
		_tube(g, pts, PackedFloat32Array([ww * 0.4, ww * 0.8, ww, ww * 1.05, ww, ww * 0.9, ww * 0.75, ww * 0.5, ww * 0.15]), {"sides": 4, "flat": 0.22, "up": tan, "cap": false})


## 옷자락 끝에 매달린 찢어진 천 조각들 (둘레를 따라)
func _tatters(g: Geo, ring_y: float, rx: float, rz: float, count: int, len_min: float, len_max: float, width: float, a0: float, a1: float, flare: float) -> void:
	for i in count:
		var a := lerpf(a0, a1, (i + _rng.randf_range(0.1, 0.9)) / count)
		var dir := Vector3(cos(a), 0, -sin(a))
		var top := Vector3(dir.x * rx, ring_y + 0.05, dir.z * rz)
		var L := _rng.randf_range(len_min, len_max)
		var pts := PackedVector3Array([top, top + dir * flare * 0.3 + Vector3(0, -L * 0.35, 0), top + dir * flare * 0.7 + Vector3(0, -L * 0.7, 0), top + dir * flare + Vector3(0, -L, 0)])
		_tube(g, pts, PackedFloat32Array([width, width * 0.95, width * 0.7, width * 0.25]),
			{"sides": 4, "flat": 0.12, "up": Vector3(-sin(a), 0, -cos(a)), "cap": false})


## 한 점에서 아래로 늘어진 천 조각들
func _tatters_line(g: Geo, at: Vector3, spread: float, count: int, len_min: float, len_max: float, width: float, up := Vector3.RIGHT) -> void:
	for i in count:
		var a := TAU * (i + _rng.randf_range(0.0, 0.7)) / count
		var top := at + Vector3(cos(a) * spread * 0.7, 0.02, sin(a) * spread * 0.7)
		var L := _rng.randf_range(len_min, len_max)
		var pts := PackedVector3Array([top, top + Vector3(cos(a) * 0.01, -L * 0.5, sin(a) * 0.01), top + Vector3(cos(a) * 0.02, -L, sin(a) * 0.02)])
		_tube(g, pts, PackedFloat32Array([width, width * 0.8, width * 0.2]), {"sides": 4, "flat": 0.15, "up": up if up != Vector3.RIGHT else Vector3(-sin(a), 0, cos(a)), "cap": false})


## 꿰맨 자국: 선을 따라 가로지르는 실땀
func _stitches(g: Geo, path: PackedVector3Array, count: int, w: float) -> void:
	for k in count:
		var t := (k + 0.5) / count
		var f := t * (path.size() - 1)
		var i := mini(int(f), path.size() - 2)
		var p := path[i].lerp(path[i + 1], f - i)
		var d := (path[i + 1] - path[i]).normalized()
		var outward := Vector3(p.x, 0, p.z).normalized() if Vector3(p.x, 0, p.z).length() > 0.001 else Vector3.FORWARD
		var side := d.cross(outward).normalized()
		_tube(g, _line(p - side * w * 0.5, p + side * w * 0.5, 2), PackedFloat32Array([0.0045]), {"sides": 4})


## 이빨 줄 (U자 모양으로 늘어선 원뿔)
func _teeth(g: Geo, c: Vector3, rx: float, rz: float, count: int, L: float, r: float, down: bool) -> void:
	for k in count:
		var t := float(k) / maxf(1.0, count - 1)
		var a := lerpf(0.15, PI - 0.15, t)
		var p := c + Vector3(cos(a) * rx, 0, -sin(a) * rz)
		var ln := L * (0.7 + 0.5 * _rng.randf()) * (1.3 if k == 1 or k == count - 2 else 1.0)
		var tip := p + Vector3(0, -ln if down else ln, 0) + Vector3(_rng.randf_range(-0.008, 0.008), 0, _rng.randf_range(-0.01, 0.0))
		_tube(g, _line(p, tip, 3), PackedFloat32Array([r, r * 0.6, 0.0]), {"sides": 5})


## 쇠사슬: 경로를 따라 고리를 90도씩 번갈아 놓음
func _chain(g: Geo, path: PackedVector3Array, link: float, r: float) -> void:
	var lens := PackedFloat32Array([0.0])
	for k in range(1, path.size()):
		lens.append(lens[k - 1] + path[k].distance_to(path[k - 1]))
	var total := lens[lens.size() - 1]
	var step := link * 0.72
	var d := 0.0
	var n := 0
	while d <= total:
		var i := 0
		while i < path.size() - 2 and lens[i + 1] < d:
			i += 1
		var seg := maxf(0.0001, lens[i + 1] - lens[i])
		var p := path[i].lerp(path[i + 1], (d - lens[i]) / seg)
		var t := (path[i + 1] - path[i]).normalized()
		var ref := Vector3.RIGHT if absf(t.x) < 0.9 else Vector3.FORWARD
		var x := t.cross(ref).normalized()
		if n % 2 == 1:
			x = x.cross(t).normalized()
		var z := x.cross(t)
		var ring := PackedVector3Array()
		for k in 11:
			var a := TAU * k / 10.0
			ring.append(Vector3(cos(a) * link * 0.32, sin(a) * link * 0.5, 0))
		_tube(g, ring, PackedFloat32Array([r]), {"sides": 4, "cap": false, "xf": Transform3D(Basis(x, t, z), p)})
		d += step
		n += 1
