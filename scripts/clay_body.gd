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
## 이모트: 지금 하는 이모트 아이디 ("" = 안 함). 목록은 survivor.gd EMOTES
var emote := ""
var _dance_t := 0.0
## 춤출 때만 보이는 엉덩이
var _hips: Node3D
## 펀치 모션 (사나이 강펀치): 남은 시간, 전체 시간
var _punch_t := 0.0
var _punch_dur := 0.45
## 중력술사: 몸 주위를 도는 파랑·빨강 구슬
var _orbit: Node3D


## character_id 의 몸 색으로 기본 점토 인형을 만들고, 치장(눈·머리·옷·장신구)을 입힘
## cos = {"eyes": 아이디, "hair": ..., "outfit": ..., "acc": ...} (cosmetics.gd). 비우면 기본 눈만
func build(character_id: String, cos := {}) -> void:
	var color: Color = CharacterDB.get_info(character_id)["color"] if CharacterDB.ORDER.has(character_id) else Color(0.8, 0.8, 0.8)
	_mat = _clay(color)
	_accent = _clay(color.darkened(0.35))

	_torso = Node3D.new()
	add_child(_torso)
	# 몸통 (위아래로 살짝 긴 구). 옷 색은 셰이더로 몸에 바로 칠함 (dress)
	_body_mi = _sphere(_torso, Vector3(0, 0.66, 0), 0.32, Vector3(1.0, 1.25, 0.9), _mat)
	_body_color = color
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
	# 엉덩이: 몸통 뒤 아래쪽이 살짝 동그랗게 나온 모양 (항상 몸의 일부, 춤출 때 실룩실룩)
	_hips = Node3D.new()
	_hips.position = Vector3(0, 0.47, -0.06)
	add_child(_hips)
	_sphere(_hips, Vector3(0, 0, 0), 0.27, Vector3(1.12, 0.78, 0.88), _mat)
	Cosmetics.apply(self, cos)


var _body_mi: MeshInstance3D
var _body_color: Color
var _dress_mat: ShaderMaterial

const DRESS_SHADER := """
shader_type spatial;
render_mode diffuse_burley;
uniform vec3 top_col = vec3(1.0);
uniform vec3 bottom_col = vec3(1.0);
uniform float split = -0.05;      // 몸통 구(반지름 0.32) 안의 높이: 이보다 위는 상의
uniform vec4 stripe_col = vec4(0.0);
uniform float stripe_freq = 22.0;
uniform vec4 belly_col = vec4(0.0);
uniform vec4 front_col = vec4(0.0);  // 앞판 (조끼 앞, 턱시도 셔츠 등): 가운데 세로 V
uniform sampler2D grain : hint_normal;
varying vec3 lp;
void vertex() { lp = VERTEX; }
void fragment() {
	float k = smoothstep(split - 0.006, split + 0.006, lp.y);
	vec3 c = mix(bottom_col, top_col, k);
	if (stripe_col.a > 0.0 && lp.y > split + 0.02) {
		float st = smoothstep(0.45, 0.55, fract(lp.y * stripe_freq));
		c = mix(c, stripe_col.rgb, st * stripe_col.a);
	}
	if (front_col.a > 0.0 && lp.z > 0.0 && lp.y > split) {
		float w = 0.03 + (0.32 - lp.y) * 0.22;
		float f = 1.0 - smoothstep(w - 0.006, w + 0.006, abs(lp.x));
		c = mix(c, front_col.rgb, f * front_col.a);
	}
	if (belly_col.a > 0.0 && lp.z > 0.0) {
		float d = length(vec2(lp.x / 0.2, (lp.y + 0.02) / 0.25));
		c = mix(c, belly_col.rgb, belly_col.a * (1.0 - smoothstep(0.95, 1.02, d)));
	}
	ALBEDO = c;
	ROUGHNESS = 0.72;
	RIM = 0.3;
	RIM_TINT = 0.5;
	NORMAL_MAP = texture(grain, UV * vec2(6.0, 3.0)).rgb;
	NORMAL_MAP_DEPTH = 0.18;
}
"""

## 옷 입히기: 몸통 위(상의)·아래(하의) 색, 줄무늬, 앞판, 배 무늬. 팔(소매)·다리(바지) 색
## top/bottom 에 Color(0,0,0,0) 을 주면 그 부분은 몸 색 그대로
func dress(top: Color, bottom: Color, split := -0.05, stripes := Color(0, 0, 0, 0), front := Color(0, 0, 0, 0), belly := Color(0, 0, 0, 0)) -> void:
	if _dress_mat == null:
		_dress_mat = ShaderMaterial.new()
		var sh := Shader.new()
		sh.code = DRESS_SHADER
		_dress_mat.shader = sh
		_clay(_body_color)  # 결 텍스처 준비
		_dress_mat.set_shader_parameter("grain", _grain)
	var tc := top if top.a > 0.0 else _body_color
	var bc := bottom if bottom.a > 0.0 else _body_color
	_dress_mat.set_shader_parameter("top_col", Vector3(tc.r, tc.g, tc.b))
	_dress_mat.set_shader_parameter("bottom_col", Vector3(bc.r, bc.g, bc.b))
	_dress_mat.set_shader_parameter("split", split)
	_dress_mat.set_shader_parameter("stripe_col", stripes)
	_dress_mat.set_shader_parameter("front_col", front)
	_dress_mat.set_shader_parameter("belly_col", belly)
	_body_mi.material_override = _dress_mat


func dress_limbs(arm_col: Color, leg_col: Color) -> void:
	if arm_col.a > 0.0:
		var m := _clay(arm_col)
		for a in [_left_arm, _right_arm]:
			(a.get_child(0) as MeshInstance3D).material_override = m
	if leg_col.a > 0.0:
		var m := _clay(leg_col)
		for l in [_left_leg, _right_leg]:
			(l.get_child(0) as MeshInstance3D).material_override = m


## 치장 중 움직이는 것들 (프로펠러, 꼬리, 망토 등): [노드, 종류]
var _cos_anim: Array = []

func _animate_cosmetics(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for e in _cos_anim:
		var n: Node3D = e[0]
		if not is_instance_valid(n):
			continue
		match e[1]:
			"spin":
				n.rotate_y(delta * 14.0)
			"bob":
				n.position.y += sin(t * 3.0) * 0.0015
			"sway":
				n.rotation.z = sin(t * 2.4 + n.position.x * 5.0) * 0.12 + (0.25 * signf(n.position.x) if absf(n.position.x) > 0.3 else 0.0)
			"wag":
				n.rotation.y = sin(t * 5.0) * 0.45
			"flap":
				n.rotation.y = -0.25 + sin(t * 6.0) * 0.25
			"flapl":
				n.rotation.y = 0.25 - sin(t * 6.0) * 0.25
			"cape":
				n.rotation.x = 0.18 + absf(sin(t * 2.0)) * 0.06 + clampf(_last_speed / 6.0, 0.0, 1.0) * 0.6
			"balloon":
				n.rotation.z = sin(t * 1.3) * 0.12
				n.rotation.x = cos(t * 1.1) * 0.08
			"upright":
				n.global_rotation = Vector3(0, n.global_rotation.y, 0)


## 매 프레임: speed = 수평 이동 속도
var _last_speed := 0.0

func animate(delta: float, speed: float, frozen: bool) -> void:
	_last_speed = speed
	_animate_cosmetics(delta)
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
	if emote != "":
		_emote_anim(delta)
		return
	_last_emote = ""
	if _dance_t > 0.0:
		# 이모트가 끝나면 자세를 원래대로
		rotation.x = 0.0
		rotation.z = 0.0
		position = Vector3.ZERO
		_torso.rotation = Vector3.ZERO
		_left_arm.rotation.y = 0.0
		_right_arm.rotation.y = 0.0
		_left_leg.rotation.y = 0.0
		_right_leg.rotation.y = 0.0
		if _hips:
			_hips.position = HIPS_BASE
			_hips.rotation = Vector3.ZERO
			_hips.scale = Vector3.ONE
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


const HIPS_BASE := Vector3(0, 0.47, -0.06)

## 엉덩이 춤: 무릎을 살짝 굽히고 상체를 숙여서 엉덩이를 박자에 맞춰 좌우로 실룩실룩
## (노래 150BPM: 한 박자에 한쪽씩. 엉덩이는 몸의 일부라 튀어나오지 않고 자연스럽게 흔들림)
func _dance(delta: float) -> void:
	_dance_t += delta
	var ph := _dance_t * TAU * 1.25
	var raw := sin(ph)
	var wig := signf(raw) * pow(absf(raw), 0.65)  # 끝에서 살짝 멈칫하는 리듬감
	var bounce := absf(cos(ph))
	var lean := minf(1.0, _dance_t * 4.0)  # 처음에 부드럽게 숙임
	_torso.rotation.x = 0.38 * lean
	_torso.position.z = -0.05 * lean
	_torso.position.y = -0.05 * lean + bounce * 0.025
	_torso.rotation.z = -wig * 0.1
	_torso.rotation.y = wig * 0.12
	_torso.position.x = -wig * 0.02
	if _hips:
		_hips.position = HIPS_BASE + Vector3(wig * 0.07, -0.04 * lean + bounce * 0.02, -0.05 * lean)
		_hips.rotation = Vector3(0.0, -wig * 0.35, wig * 0.28)
		_hips.scale = Vector3(1.0 + bounce * 0.05, 1.0 - bounce * 0.04, 1.0)
	_left_leg.rotation = Vector3(-0.28 * lean + wig * 0.1, 0, -0.06 + wig * 0.08)
	_right_leg.rotation = Vector3(-0.28 * lean - wig * 0.1, 0, 0.06 + wig * 0.08)
	# 손은 무릎 위에 얹고 박자에 맞춰 톡톡
	_left_arm.rotation = Vector3(-0.55 * lean - bounce * 0.12, 0, -0.18)
	_right_arm.rotation = Vector3(-0.55 * lean - bounce * 0.12, 0, 0.18)


## 이모트 동작 (점토 인형이라 팔·다리·몸통 관절만 돌려서 표현)
var _last_emote := ""

func _emote_anim(delta: float) -> void:
	if emote != _last_emote:
		_last_emote = emote
		_dance_t = 0.0
		if _hips:
			_hips.position = HIPS_BASE
			_hips.rotation = Vector3.ZERO
			_hips.scale = Vector3.ONE
	if emote == "butt_dance":
		_dance(delta)
		return
	_dance_t += delta
	var t := _dance_t

	# 기본 자세로 시작해서 이모트마다 덮어씀
	_torso.position = Vector3.ZERO
	_torso.rotation = Vector3.ZERO
	position = Vector3.ZERO
	rotation.x = 0.0
	rotation.z = 0.0
	_left_leg.rotation = Vector3.ZERO
	_right_leg.rotation = Vector3.ZERO
	_left_arm.rotation = Vector3(0, 0, -0.25)
	_right_arm.rotation = Vector3(0, 0, 0.25)
	if _hips:
		_hips.position = HIPS_BASE
		_hips.rotation = Vector3.ZERO
		_hips.scale = Vector3.ONE
	match emote:
		"fart":
			# 엉덩이를 쭉 빼고 힘주다가 뿡! 하고 시원해함
			var push := clampf(t / 0.5, 0.0, 1.0)
			_torso.rotation.x = 0.45 * push
			_torso.position.z = -0.12 * push
			_left_arm.rotation = Vector3(0.6 * push, 0, -0.2)
			_right_arm.rotation = Vector3(0.6 * push, 0, 0.2)
			_left_leg.rotation.x = -0.25 * push
			_right_leg.rotation.x = -0.25 * push
			if t < 0.6:
				_torso.position.x = sin(t * 60.0) * 0.012 * push  # 힘주며 부들부들
			elif t < 1.0:
				var k := (t - 0.6) / 0.4
				_hips.position.z = HIPS_BASE.z - 0.06 * sin(k * PI)  # 뿡 반동
				_torso.position.y = 0.06 * sin(k * PI)
			else:
				_torso.rotation.z = sin(t * 3.0) * 0.12  # 후련하게 살랑
				_hips.position = HIPS_BASE
		"poop":
			# 쪼그려 앉아 끙끙 → 뿌직! → 개운
			var sq := clampf(t / 0.35, 0.0, 1.0)
			_torso.position.y = -0.26 * sq
			_left_leg.rotation = Vector3(-1.1 * sq, 0, -0.35 * sq)
			_right_leg.rotation = Vector3(-1.1 * sq, 0, 0.35 * sq)
			_left_arm.rotation = Vector3(-0.9 * sq, 0, -0.1)
			_right_arm.rotation = Vector3(-0.9 * sq, 0, 0.1)
			if t < 1.6:
				var strain := clampf((t - 0.35) / 1.2, 0.0, 1.0)
				_torso.position.x = sin(t * 70.0) * 0.015 * strain
				_torso.rotation.x = 0.12 * strain
			elif t < 2.0:
				_torso.position.y += 0.05 * sin((t - 1.6) / 0.4 * PI)
			else:
				_torso.rotation.z = sin(t * 4.0) * 0.06
		"dead":
			# 뒤로 벌러덩 → 팔다리 쭉 → 가끔 다리 파르르
			var fall := clampf(t / 0.35, 0.0, 1.0)
			fall = fall * fall
			rotation.x = -1.45 * fall
			position.y = 0.32 * fall
			_left_arm.rotation = Vector3(0, 0, -1.3 * fall)
			_right_arm.rotation = Vector3(0, 0, 1.3 * fall)
			if t > 0.5:
				var tw := sin(t * 40.0) * 0.15 if fmod(t, 1.2) < 0.25 else 0.0
				_left_leg.rotation.x = -0.3 + tw
				_right_leg.rotation.x = -0.2 - tw
		"robot":
			# 딱딱 끊기는 로봇 춤 (0.25초마다 자세가 바뀜)
			var step := int(t / 0.25)
			var poses := [
				[Vector3(-1.57, 0, -0.1), Vector3(0, 0, 1.57), 0.0],
				[Vector3(0, 0, -1.57), Vector3(-1.57, 0, 0.1), 0.35],
				[Vector3(-1.57, 0, -0.1), Vector3(-1.57, 0, 0.1), 0.0],
				[Vector3(0, 0, -1.57), Vector3(0, 0, 1.57), -0.35],
			]
			var pz: Array = poses[step % poses.size()]
			_left_arm.rotation = pz[0]
			_right_arm.rotation = pz[1]
			_torso.rotation.y = pz[2]
			_torso.position.y = 0.03 if step % 2 == 0 else 0.0
			_left_leg.rotation.z = -0.12 if step % 2 == 0 else 0.0
			_right_leg.rotation.z = 0.0 if step % 2 == 0 else 0.12
		"disco":
			# 디스코: 한 박자마다 오른손을 하늘로 콕 → 반대쪽 아래로 콕, 옆으로 스텝 (120BPM)
			var beat := t * 2.0
			var k := fmod(beat, 2.0)
			var up := k < 1.0
			var snap := clampf(fmod(beat, 1.0) / 0.18, 0.0, 1.0)
			var step := sin(beat * PI) 
			_torso.position.x = step * 0.07
			_torso.rotation.z = -step * 0.12
			_torso.position.y = absf(sin(beat * PI)) * 0.03
			if up:
				_right_arm.rotation = Vector3(0.0, 0.0, lerpf(0.6, 2.75, snap))
				_left_arm.rotation = Vector3(-0.3, 0.0, -0.35)
				_torso.rotation.y = -0.2
			else:
				_right_arm.rotation = Vector3(-0.2, 0.0, lerpf(2.75, -0.55, snap))
				_left_arm.rotation = Vector3(-0.3, 0.0, -0.35)
				_torso.rotation.y = 0.25
			_left_leg.rotation = Vector3(0, 0, -0.12 - maxf(0.0, step) * 0.18)
			_right_leg.rotation = Vector3(0, 0, 0.12 - minf(0.0, step) * 0.18)
		"trot":
			# 트로트 어깨춤: 팔 벌리고 어깨를 번갈아 들썩들썩, 몸은 좌우로 살랑 (뽕짝 135BPM)
			var b := t * 2.25
			var sh := sin(b * PI)
			_left_arm.rotation = Vector3(-0.35, 0.0, -1.15 - maxf(0.0, sh) * 0.35)
			_right_arm.rotation = Vector3(-0.35, 0.0, 1.15 + maxf(0.0, -sh) * 0.35)
			_torso.rotation.z = sh * 0.14
			_torso.position.x = sh * 0.04
			_torso.position.y = absf(sin(b * PI * 2.0)) * 0.025
			_torso.rotation.y = sin(b * PI * 0.5) * 0.25
			_left_leg.rotation.x = -absf(sin(b * PI * 2.0)) * 0.15
			_right_leg.rotation.x = -absf(sin(b * PI * 2.0)) * 0.15
		"chicken":
			# 닭 흉내: 팔꿈치 날개 파닥파닥 + 고개 콕콕 + 종종걸음
			var flap := sin(t * 22.0)
			_left_arm.rotation = Vector3(0.5, 0.0, -0.9 - flap * 0.35)
			_right_arm.rotation = Vector3(0.5, 0.0, 0.9 + flap * 0.35)
			var peck := fmod(t * 2.6, 1.0)
			_torso.rotation.x = (0.45 if peck < 0.12 else 0.05) if t < 2.4 else -0.25  # 마지막엔 가슴 펴고 꼬끼오
			_torso.position.z = 0.08 if peck < 0.12 else 0.0
			var strut := sin(t * 10.0)
			_left_leg.rotation.x = maxf(0.0, strut) * -0.6
			_right_leg.rotation.x = maxf(0.0, -strut) * -0.6
			_torso.position.y = absf(strut) * 0.03
		"gaedari":
			# 개다리 춤: 무릎을 안팎으로 후들후들 + 팔 흐느적 + 몸 들썩
			var w := sin(t * 16.0)
			_left_leg.rotation = Vector3(-0.2, 0.0, -0.15 + w * 0.45)
			_right_leg.rotation = Vector3(-0.2, 0.0, 0.15 + w * 0.45)
			_torso.position.y = -0.06 + absf(sin(t * 8.0)) * 0.05
			_torso.position.x = w * 0.03
			_torso.rotation.z = -w * 0.08
			_left_arm.rotation = Vector3(sin(t * 5.0) * 0.6, 0.0, -0.9 + sin(t * 7.0) * 0.5)
			_right_arm.rotation = Vector3(-sin(t * 5.0) * 0.6, 0.0, 0.9 + cos(t * 7.0) * 0.5)
			_torso.rotation.y = sin(t * 4.0) * 0.3
		"dizzy":
			# 팽이처럼 빙글빙글 돌다가 어질어질 비틀
			if t < 1.3:
				var sp := t / 1.3
				_torso.rotation.y = t * t * 14.0
				_left_arm.rotation = Vector3(0, 0, -1.45 * minf(1.0, sp * 3.0))
				_right_arm.rotation = Vector3(0, 0, 1.45 * minf(1.0, sp * 3.0))
				_torso.position.y = 0.04 * minf(1.0, sp * 3.0)
			else:
				var w := t - 1.3
				_torso.rotation.z = sin(w * 5.0) * 0.32
				_torso.rotation.x = cos(w * 3.7) * 0.15
				_torso.position.x = sin(w * 5.0) * 0.06
				_left_arm.rotation = Vector3(sin(w * 6.0) * 0.4, 0, -0.9)
				_right_arm.rotation = Vector3(-sin(w * 6.0) * 0.4, 0, 0.9)
				_left_leg.rotation.z = -0.15 + sin(w * 5.0) * 0.1
				_right_leg.rotation.z = 0.15 + sin(w * 5.0) * 0.1

	if _hips and emote != "fart":
		_hips.position += _torso.position  # 엉덩이가 몸통을 따라감 (쪼그려 앉기 등)


## 사나이 강펀치: 왼팔(뒤에서 보면 화면 오른쪽)을 앞으로 쭉 내지름
func punch(seconds: float) -> void:
	_punch_dur = seconds
	_punch_t = seconds


## 반투명 (카멜레온 동화 등). alpha 1 = 원래대로
func set_alpha(alpha: float) -> void:
	if _dress_mat and _body_mi:
		_body_mi.material_override = _mat if alpha < 1.0 else _dress_mat
	for mi in find_children("*", "MeshInstance3D", true, false):
		var m := (mi as MeshInstance3D).material_override as StandardMaterial3D
		if m == null:
			continue
		if not m.has_meta("base_alpha"):
			m.set_meta("base_alpha", m.albedo_color.a)
			m.set_meta("base_transp", m.transparency)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA if alpha < 1.0 else int(m.get_meta("base_transp"))
		m.albedo_color.a = float(m.get_meta("base_alpha")) * alpha


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
