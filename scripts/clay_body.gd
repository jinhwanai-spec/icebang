class_name ClayBody
extends Node3D
## 유저 캐릭터 외형: 매끈한 점토 인형 스타일
## 앞쪽은 +Z 방향입니다.
## 큰 둥근 머리 + 통통한 몸 + 짧은 팔다리를 도형(구, 캡슐)으로 만들고,
## 캐릭터마다 색과 액세서리를 붙입니다. 걷기/달리기/얼음 포즈도 여기서 움직여요.
## 나중에 진짜 3D 모델을 구하면 이 노드만 모델로 바꾸면 됩니다.

var _mat: StandardMaterial3D
var _accent: StandardMaterial3D
var _parts: Array[MeshInstance3D] = []
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _torso: Node3D
var _phase := 0.0
## 이모트: 엉덩이 춤 추는 중
var dancing := false
var _dance_t := 0.0
## 춤출 때만 보이는 엉덩이
var _hips: Node3D
## 펀치 모션 (사나이 강펀치): 남은 시간, 전체 시간
var _punch_t := 0.0
var _punch_dur := 0.45
## 중력술사: 몸 주위를 도는 파랑·빨강 구슬
var _orbit: Node3D


## character_id 에 맞는 색과 액세서리로 만들기
func build(character_id: String) -> void:
	var color: Color = CharacterDB.get_info(character_id)["color"]
	_mat = _clay(color)
	_accent = _clay(color.darkened(0.35))

	_torso = Node3D.new()
	add_child(_torso)
	# 몸통 (위아래로 살짝 긴 구)
	_sphere(_torso, Vector3(0, 0.66, 0), 0.32, Vector3(1.0, 1.25, 0.9), _mat)
	# 머리 (크고 둥글게)
	_sphere(_torso, Vector3(0, 1.28, 0), 0.4, Vector3.ONE, _mat)
	# 다리
	_left_leg = _limb(self, Vector3(-0.14, 0.4, 0), 0.115, 0.42, _mat)
	_right_leg = _limb(self, Vector3(0.14, 0.4, 0), 0.115, 0.42, _mat)
	# 팔 (어깨에서 아래로, 살짝 벌어짐)
	_left_arm = _limb(_torso, Vector3(-0.31, 0.86, 0), 0.09, 0.4, _mat)
	_right_arm = _limb(_torso, Vector3(0.31, 0.86, 0), 0.09, 0.4, _mat)
	_left_arm.rotation.z = -0.25
	_right_arm.rotation.z = 0.25
	# 엉덩이 (춤출 때만 보임). 뒤쪽은 -Z
	_hips = Node3D.new()
	_hips.position = Vector3(0, 0.42, -0.12)
	add_child(_hips)
	for x in [-0.11, 0.11]:
		_sphere(_hips, Vector3(x, 0, -0.06), 0.15, Vector3(1.0, 0.95, 1.0), _mat)
	_hips.visible = false

	_face(character_id)

	match character_id:
		"chameleon":
			# 볏 달린 후드
			_sphere(_torso, Vector3(0, 1.32, -0.04), 0.43, Vector3(1.0, 0.95, 1.0), _accent)
			for i in 3:
				var crest := PrismMesh.new()
				crest.size = Vector3(0.05, 0.16 - i * 0.03, 0.14)
				_part(_torso, Vector3(0, 1.74 - i * 0.07, -0.05 - i * 0.12), crest, _accent).rotation.x = -0.3 - i * 0.35
		"space":
			# 망토 + 손목의 빛나는 링
			var cape := _box(_torso, Vector3(0, 0.62, -0.3), Vector3(0.62, 0.8, 0.04), _accent)
			cape.rotation.x = 0.18
			var glow := _glow(Color(0.8, 0.5, 1.0))
			for arm in [_left_arm, _right_arm]:
				var ring := TorusMesh.new()
				ring.inner_radius = 0.09
				ring.outer_radius = 0.13
				_part(arm, Vector3(0, -0.3, 0), ring, glow)
		"cameraman":
			# 가슴의 카메라 + 이마의 헤드램프
			var dark := _clay(Color(0.15, 0.15, 0.17))
			_box(_torso, Vector3(0, 0.78, 0.3), Vector3(0.3, 0.2, 0.14), dark)
			var lens := CylinderMesh.new()
			lens.top_radius = 0.07
			lens.bottom_radius = 0.07
			lens.height = 0.1
			_part(_torso, Vector3(0, 0.78, 0.4), lens, dark).rotation.x = PI / 2.0
			var band := TorusMesh.new()
			band.inner_radius = 0.38
			band.outer_radius = 0.42
			_part(_torso, Vector3(0, 1.36, 0), band, dark)
			var lamp := CylinderMesh.new()
			lamp.top_radius = 0.06
			lamp.bottom_radius = 0.06
			lamp.height = 0.06
			_part(_torso, Vector3(0, 1.38, 0.4), lamp, _glow(Color(1, 0.95, 0.7))).rotation.x = PI / 2.0
		"medic":
			# 가슴의 빨간 십자 + 간호 모자
			var red := _clay(Color(0.9, 0.15, 0.15))
			_box(_torso, Vector3(0, 0.75, 0.29), Vector3(0.18, 0.06, 0.04), red)
			_box(_torso, Vector3(0, 0.75, 0.29), Vector3(0.06, 0.18, 0.04), red)
			_box(_torso, Vector3(0, 1.7, 0.05), Vector3(0.36, 0.14, 0.28), _clay(Color(1, 1, 1)))
			_box(_torso, Vector3(0, 1.72, 0.2), Vector3(0.08, 0.03, 0.02), red)
		"shadow":
			# 깊게 눌러쓴 후드 + 빛나는 눈 + 목도리
			_sphere(_torso, Vector3(0, 1.33, -0.05), 0.44, Vector3(1.0, 0.98, 1.0), _accent)
			for x in [-0.12, 0.12]:
				_box(_torso, Vector3(x, 1.3, 0.38), Vector3(0.1, 0.03, 0.02), _glow(Color(0.7, 0.85, 1.0)))
			var scarf := TorusMesh.new()
			scarf.inner_radius = 0.2
			scarf.outer_radius = 0.3
			_part(_torso, Vector3(0, 0.95, 0), scarf, _clay(Color(0.5, 0.1, 0.12)))
		"hunter":
			# 챙 넓은 모자 + 등의 배낭
			var brim := CylinderMesh.new()
			brim.top_radius = 0.58
			brim.bottom_radius = 0.58
			brim.height = 0.04
			_part(_torso, Vector3(0, 1.58, 0), brim, _accent)
			var crown := CylinderMesh.new()
			crown.top_radius = 0.26
			crown.bottom_radius = 0.32
			crown.height = 0.26
			_part(_torso, Vector3(0, 1.72, 0), crown, _accent)
			_box(_torso, Vector3(0, 0.75, -0.33), Vector3(0.4, 0.45, 0.2), _clay(Color(0.4, 0.28, 0.15)))
		"bard":
			# 배에 멘 북 + 깃털 모자
			var drum := CylinderMesh.new()
			drum.top_radius = 0.2
			drum.bottom_radius = 0.2
			drum.height = 0.2
			_part(_torso, Vector3(0, 0.62, 0.32), drum, _clay(Color(0.8, 0.2, 0.2))).rotation.x = PI / 2.0
			_box(_torso, Vector3(0, 1.66, 0), Vector3(0.5, 0.12, 0.4), _accent)
			var feather := PrismMesh.new()
			feather.size = Vector3(0.05, 0.4, 0.12)
			_part(_torso, Vector3(0.18, 1.85, -0.05), feather, _clay(Color(0.3, 0.8, 0.9))).rotation.z = -0.4
		"mechanic":
			# 이마의 고글 + 손에 든 렌치
			var dark := _clay(Color(0.2, 0.2, 0.22))
			for x in [-0.14, 0.14]:
				var lens := CylinderMesh.new()
				lens.top_radius = 0.1
				lens.bottom_radius = 0.1
				lens.height = 0.06
				_part(_torso, Vector3(x, 1.48, 0.33), lens, _glow(Color(0.5, 0.9, 1.0))).rotation.x = PI / 2.0 - 0.4
			var strap := TorusMesh.new()
			strap.inner_radius = 0.38
			strap.outer_radius = 0.42
			_part(_torso, Vector3(0, 1.45, 0), strap, dark)
			_box(_right_arm, Vector3(0, -0.45, 0.08), Vector3(0.06, 0.06, 0.36), _clay(Color(0.7, 0.7, 0.75)))
		"keeper":
			# 손에 든 등불 (진짜 빛이 남) + 두건
			var lantern := _sphere(_right_arm, Vector3(0, -0.5, 0.05), 0.12, Vector3(1, 1.2, 1), _glow(Color(1.0, 0.8, 0.4)))
			var lamp_light := OmniLight3D.new()
			lamp_light.light_color = Color(1.0, 0.75, 0.4)
			lamp_light.omni_range = 3.5
			lamp_light.light_energy = 1.2
			lantern.add_child(lamp_light)
			_sphere(_torso, Vector3(0, 1.36, -0.06), 0.42, Vector3(1.0, 0.9, 1.0), _accent)
		"gravity":
			# 우주비행사: 투명 헬멧 + 남색 바이저 + 등의 산소통 + 주위를 도는 빨강·파랑 구슬
			var glass := StandardMaterial3D.new()
			glass.albedo_color = Color(0.7, 0.85, 1.0, 0.22)
			glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			glass.roughness = 0.05
			glass.metallic = 0.5
			glass.rim_enabled = true
			_sphere(_torso, Vector3(0, 1.3, 0), 0.5, Vector3.ONE, glass)
			_sphere(_torso, Vector3(0, 1.32, 0.18), 0.34, Vector3(1.0, 0.7, 0.6), _glow(Color(0.15, 0.25, 0.7)))
			var tank := CapsuleMesh.new()
			tank.radius = 0.13
			tank.height = 0.55
			for x in [-0.12, 0.12]:
				_part(_torso, Vector3(x, 0.78, -0.33), tank, _clay(Color(0.75, 0.75, 0.8)))
			_orbit = Node3D.new()
			_orbit.position = Vector3(0, 1.0, 0)
			add_child(_orbit)
			for pair in [[Color(0.25, 0.55, 1.0), 1.0], [Color(1.0, 0.2, 0.2), -1.0]]:
				var orb := _sphere(_orbit, Vector3(0.6 * pair[1], 0, 0), 0.1, Vector3.ONE, _glow(pair[0]))
				var light := OmniLight3D.new()
				light.light_color = pair[0]
				light.omni_range = 1.5
				orb.add_child(light)
		"brute":
			# 큰 장갑 + 머리띠
			for arm in [_left_arm, _right_arm]:
				_sphere(arm, Vector3(0, -0.42, 0), 0.15, Vector3.ONE, _accent)
			var band := TorusMesh.new()
			band.inner_radius = 0.38
			band.outer_radius = 0.43
			_part(_torso, Vector3(0, 1.4, 0), band, _clay(Color(0.95, 0.95, 0.95)))


## 매 프레임: speed = 수평 이동 속도
func animate(delta: float, speed: float, frozen: bool) -> void:
	if _orbit:
		_orbit.rotate_y(delta * 2.5)
		_orbit.position.y = 1.0 + sin(Time.get_ticks_msec() / 400.0) * 0.08
	if frozen:
		# 얼음 포즈: 만세 하고 굳음
		_left_arm.rotation = Vector3(0, 0, -2.6)
		_right_arm.rotation = Vector3(0, 0, 2.6)
		_left_leg.rotation.x = 0.0
		_right_leg.rotation.x = 0.0
		return
	if dancing:
		_dance(delta)
		return
	if _hips:
		_hips.visible = false
	_dance_t = 0.0
	_torso.rotation.y = 0.0
	_torso.rotation.z = 0.0
	_torso.position.x = 0.0
	_torso.position.z = 0.0
	_left_leg.rotation.z = 0.0
	_right_leg.rotation.z = 0.0
	var amount := clampf(speed / 4.5, 0.0, 1.6)
	if amount > 0.05:
		_phase += delta * (5.0 + speed * 1.3)
	else:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, 10.0 * delta)
	var swing := sin(_phase) * 0.7 * amount
	_left_leg.rotation.x = swing
	_right_leg.rotation.x = -swing
	_left_arm.rotation = Vector3(-swing * 0.9, 0, -0.25)
	_right_arm.rotation = Vector3(swing * 0.9, 0, 0.25)
	# 통통 튀는 느낌 + 숨쉬기
	var t := Time.get_ticks_msec() / 1000.0
	_torso.position.y = absf(sin(_phase)) * 0.05 * amount + sin(t * 2.0) * 0.008
	_torso.rotation.x = -0.12 * amount  # 달릴수록 앞으로 숙임
	if _punch_t > 0.0:
		_punch_t -= delta
		# 빠르게 쭉 뻗고(처음 25%) 잠깐 유지했다가 천천히 돌아옴
		var p := 1.0 - _punch_t / _punch_dur
		var k := clampf(p / 0.25, 0.0, 1.0) if p < 0.6 else clampf((1.0 - p) / 0.4, 0.0, 1.0)
		_left_arm.rotation = Vector3(-1.65 * k, 0, -0.25 * (1.0 - k))
		_right_arm.rotation = Vector3(0.5 * k, 0, 0.25 + 0.3 * k)
		_torso.rotation.y = -0.45 * k  # 펀치하는 쪽 어깨가 앞으로
		_torso.rotation.x = 0.12 * k
		_left_leg.rotation.x = -0.35 * k
		_right_leg.rotation.x = 0.35 * k


## 엉덩이 춤: 상체를 숙이고 엉덩이를 좌우로 실룩실룩
func _dance(delta: float) -> void:
	_dance_t += delta
	var w := _dance_t * 13.0
	var wig := sin(w)
	if _hips:
		_hips.visible = true
		_hips.position.x = wig * 0.12
		_hips.position.y = 0.42 + absf(wig) * 0.04
		_hips.rotation.z = wig * 0.5
	_torso.rotation.x = 0.42
	_torso.position.z = -0.16
	_torso.position.y = absf(wig) * 0.05
	_torso.rotation.z = wig * 0.32
	_torso.rotation.y = wig * 0.22
	_torso.position.x = wig * 0.07
	_left_leg.rotation = Vector3(-0.2 + wig * 0.18, 0, -0.08 + wig * 0.12)
	_right_leg.rotation = Vector3(-0.2 - wig * 0.18, 0, 0.08 + wig * 0.12)
	var flap := absf(sin(w * 0.5))
	_left_arm.rotation = Vector3(0.35, 0, -0.55 - flap * 0.5)
	_right_arm.rotation = Vector3(0.35, 0, 0.55 + flap * 0.5)


## 사나이 강펀치: 왼팔(뒤에서 보면 화면 오른쪽)을 앞으로 쭉 내지름
func punch(seconds: float) -> void:
	_punch_dur = seconds
	_punch_t = seconds


## 반투명 (카멜레온 동화 등). alpha 1 = 원래대로
func set_alpha(alpha: float) -> void:
	for m in [_mat, _accent]:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 else BaseMaterial3D.TRANSPARENCY_DISABLED
		m.albedo_color.a = alpha


# ---------------------------------------------------------------- 도형 도우미

## 말랑한 점토 재질: 반질반질하지 않은 무광 + 아주 고운 표면 결 + (높음 품질) 살짝 비치는 부드러움
static var _grain: NoiseTexture2D
func _clay(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.72
	m.rim_enabled = true
	m.rim = 0.3
	m.rim_tint = 0.5
	if _grain == null:
		var n := FastNoiseLite.new()
		n.frequency = 0.12
		n.fractal_octaves = 2
		_grain = NoiseTexture2D.new()
		_grain.width = 128
		_grain.height = 128
		_grain.seamless = true
		_grain.noise = n
		_grain.as_normal_map = true
		_grain.bump_strength = 1.2
	m.normal_enabled = true
	m.normal_texture = _grain
	m.normal_scale = 0.18
	m.uv1_triplanar = true
	m.uv1_scale = Vector3.ONE * 3.0
	if SaveData.high_graphics():
		m.subsurf_scatter_enabled = true
		m.subsurf_scatter_strength = 0.3
	return m


## 귀여운 얼굴: 반짝이는 큰 눈 + 발그레한 볼 + 작은 웃는 입 (얼굴이 가려지는 캐릭터는 제외)
func _face(character_id: String) -> void:
	if character_id in ["shadow", "gravity"]:
		return
	var z := 0.035 if character_id in ["chameleon", "keeper"] else 0.0  # 후드를 쓴 캐릭터는 조금 앞으로
	var eye := StandardMaterial3D.new()
	eye.albedo_color = Color(0.07, 0.05, 0.09)
	eye.roughness = 0.2
	var shine := StandardMaterial3D.new()
	shine.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	shine.albedo_color = Color(1, 1, 1)
	var blush := StandardMaterial3D.new()
	blush.albedo_color = Color(1.0, 0.45, 0.52, 0.6)
	blush.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	blush.roughness = 0.9
	var mouth := StandardMaterial3D.new()
	mouth.albedo_color = Color(0.25, 0.08, 0.1)
	for side in [-1.0, 1.0]:
		_sphere(_torso, Vector3(0.135 * side, 1.27, 0.35 + z), 0.08, Vector3(0.85, 1.15, 0.45), eye)
		_sphere(_torso, Vector3(0.135 * side + 0.026, 1.31, 0.386 + z), 0.023, Vector3(1, 1, 0.5), shine)
		_sphere(_torso, Vector3(0.135 * side - 0.02, 1.245, 0.39 + z), 0.011, Vector3(1, 1, 0.5), shine)
		_sphere(_torso, Vector3(0.235 * side, 1.17, 0.3 + z), 0.06, Vector3(1.25, 0.7, 0.35), blush)
	# 작은 웃는 입 (짧은 선 3개로 만든 곡선)
	for k in 3:
		var t := (k - 1) * 0.026
		var seg := CapsuleMesh.new()
		seg.radius = 0.009
		seg.height = 0.04
		var mi := _part(_torso, Vector3(t, 1.155 + absf(t) * 0.5, 0.378 + z), seg, mouth)
		mi.rotation = Vector3(0, 0, PI / 2.0 + (k - 1) * -0.55)


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.0
	return m


func _part(parent: Node3D, pos: Vector3, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	_parts.append(mi)
	return mi


func _sphere(parent: Node3D, pos: Vector3, radius: float, scale_v: Vector3, mat: Material) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	var mi := _part(parent, pos, s, mat)
	mi.scale = scale_v
	return mi


func _box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return _part(parent, pos, b, mat)


## 팔/다리: 관절(pivot)에서 아래로 매달린 캡슐. 관절 노드를 돌리면 흔들림
func _limb(parent: Node3D, joint: Vector3, radius: float, length: float, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = joint
	parent.add_child(pivot)
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = length
	_part(pivot, Vector3(0, -length / 2.0 + radius * 0.5, 0), c, mat)
	return pivot
