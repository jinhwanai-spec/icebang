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
		_clear_props()
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
		_left_arm.scale = Vector3.ONE
		_right_arm.scale = Vector3.ONE
		_clear_props()
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
		_clear_props()
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
	_left_arm.scale = Vector3.ONE
	_right_arm.scale = Vector3.ONE
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
		_:
			_emote_anim2(t)

	if _hips and emote != "fart":
		_hips.position += _torso.position  # 엉덩이가 몸통을 따라감 (쪼그려 앉기 등)


## 이모트 도우미 ------------------------------------------------------------
## 팔·다리가 그냥 서 있을 때 가리키는 방향 (관절 기준, +Z 앞)
const _REST_L := Vector3(-0.25, -0.97, 0.0)
const _REST_R := Vector3(0.25, -0.97, 0.0)

## 팔/다리를 방향 d 로 뻗기 (팔은 몸통 기준, 다리는 몸 기준 방향)
func _aim(limb: Node3D, d: Vector3) -> void:
	if d.length_squared() < 0.0001:
		return
	d = d.normalized()
	limb.rotation = Vector3(atan2(-d.z, -d.y), 0.0, asin(clampf(d.x, -1.0, 1.0)))


## 양팔을 좌우 대칭으로 (d 는 왼팔 기준: x 가 - 이면 바깥쪽)
func _both(d: Vector3) -> void:
	_aim(_left_arm, d)
	_aim(_right_arm, Vector3(-d.x, d.y, d.z))


## 몸이 보는 방향(앞)으로 거리만큼
func _fwd(dist: float) -> Vector3:
	return Vector3(sin(rotation.y), 0.0, cos(rotation.y)) * dist


## 이모트 중에만 붙는 소품 (폼폼, 혀, 볼터치). 이모트가 바뀌거나 끝나면 사라짐
var _props: Array[Node3D] = []

func _clear_props() -> void:
	for p in _props:
		if is_instance_valid(p):
			p.queue_free()
	_props.clear()


func _prop_ball(parent: Node3D, pos: Vector3, radius: float, sc: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 16
	s.rings = 8
	mi.mesh = s
	mi.material_override = mat
	mi.position = pos
	mi.scale = sc
	mi.set_meta("emote_fx", true)
	parent.add_child(mi)
	_props.append(mi)
	return mi


## 응원 폼폼: 손끝에 복슬복슬한 공 뭉치
func _pompom(arm: Node3D, c1: Color, c2: Color) -> void:
	var root := Node3D.new()
	root.position = Vector3(0, -0.42, 0)
	root.set_meta("emote_fx", true)
	arm.add_child(root)
	_props.append(root)
	var m1 := _clay(c1)
	var m2 := _clay(c2)
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.1
	s.height = 0.2
	mi.mesh = s
	mi.material_override = m1
	root.add_child(mi)
	for i in 14:
		# 공 표면에 고르게 (피보나치 구)
		var yy := 1.0 - (i + 0.5) / 14.0 * 2.0
		var rr := sqrt(1.0 - yy * yy)
		var a := i * 2.4
		var b := MeshInstance3D.new()
		var bs := SphereMesh.new()
		bs.radius = 0.06
		bs.height = 0.12
		bs.radial_segments = 8
		bs.rings = 4
		b.mesh = bs
		b.material_override = m2 if i % 2 == 0 else m1
		b.position = Vector3(cos(a) * rr, yy, sin(a) * rr) * 0.1
		root.add_child(b)


func _emote_anim2(t: float) -> void:
	match emote:
		# ---------------------------------------------------------------- 귀여운
		"heart_hands":
			# 머리 위로 큰 하트 → 가슴 앞 작은 손하트, 살랑살랑
			var up := smoothstep(0.0, 0.35, t)
			var sw := sin(t * 3.4)
			_torso.rotation.z = sw * 0.1 * up
			_torso.position.x = sw * 0.03 * up
			_torso.position.y = absf(sw) * 0.02
			var small := smoothstep(1.5, 1.8, t)
			_both(_REST_L.lerp(Vector3(-0.3, 0.93, 0.2), up).lerp(Vector3(0.55, 0.05, 0.83), small))
			_torso.rotation.x = 0.06 * small
			_left_leg.rotation.z = -sw * 0.05
			_right_leg.rotation.z = -sw * 0.05
		"wave_hi":
			# 한 팔을 번쩍 들어 크게 흔들기 + 통통
			var up := smoothstep(0.0, 0.25, t) * (1.0 - smoothstep(2.3, 2.6, t))
			var wv := sin(t * 13.0)
			_aim(_right_arm, _REST_R.lerp(Vector3(0.38 + wv * 0.32, 0.92, 0.2), up))
			_left_arm.rotation = Vector3(0.0, 0.0, -0.4 * up - 0.25 * (1.0 - up))
			_torso.rotation.z = 0.1 * up + wv * 0.03 * up
			_torso.position.y = absf(sin(t * 6.5)) * 0.04 * up
			_left_leg.rotation.x = -absf(sin(t * 6.5)) * 0.1 * up
		"bunny_hop":
			# 두 손을 머리 위로 토끼 귀처럼 + 제자리 깡총깡총
			var up := smoothstep(0.0, 0.3, t)
			var hop := absf(sin(t * PI * 2.2)) * smoothstep(0.3, 0.5, t) * (1.0 - smoothstep(2.9, 3.2, t))
			position.y = hop * 0.16
			var ear := sin(t * 14.0) * 0.08
			_aim(_left_arm, _REST_L.lerp(Vector3(-0.2, 1.0, 0.02 + ear), up))
			_aim(_right_arm, _REST_R.lerp(Vector3(0.2, 1.0, 0.02 - ear), up))
			_left_leg.rotation = Vector3(0.45 * hop, 0, 0.06)
			_right_leg.rotation = Vector3(0.45 * hop, 0, -0.06)
			_torso.position.y = -pow(1.0 - hop, 6.0) * 0.04 * up
			_torso.rotation.z = sin(t * PI * 1.1) * 0.08
		"shy":
			# 두 손 모으고 고개 갸웃, 몸을 배배 꼼 + 발그레 볼
			var k := smoothstep(0.0, 0.4, t)
			var tw := sin(t * 4.2)
			_torso.rotation.y = tw * 0.35 * k
			_torso.rotation.z = 0.14 * k + sin(t * 2.1) * 0.04
			_torso.rotation.x = 0.1 * k
			_both(_REST_L.lerp(Vector3(0.45, -0.6, 0.8), k))
			_right_leg.rotation = Vector3(-0.15 * k, 0, -0.08 * k + tw * 0.06)
			if _props.is_empty():
				var m := _glow(Color(1.0, 0.35, 0.5))
				m.emission_energy_multiplier = 0.5
				for x in [-0.2, 0.2]:
					_prop_ball(_torso, Vector3(x, 1.16, 0.33), 0.075, Vector3.ZERO, m)
			var bl := smoothstep(0.3, 0.8, t) * (1.0 - smoothstep(2.7, 3.0, t)) * (1.0 + sin(t * 6.0) * 0.08)
			for p in _props:
				p.scale = Vector3(1.0, 0.6, 0.35) * bl
		"clap":
			# 팔을 앞으로 뻗고 짝짝짝 + 통통
			var k := smoothstep(0.0, 0.25, t)
			var c := pow(absf(cos(t * PI * 4.0)), 6.0)  # 1 = 짝!
			_both(_REST_L.lerp(Vector3(-0.45, 0.1, 0.85).lerp(Vector3(0.62, 0.08, 0.78), c), k))
			_torso.position.y = c * 0.03 * k
			position.y = absf(sin(t * PI * 2.0)) * 0.05 * k
			_left_leg.rotation.x = -0.1 * k
			_right_leg.rotation.x = -0.1 * k
			_torso.rotation.z = sin(t * PI) * 0.06
		"aegyo":
			# 검지로 볼 콕 + 고개 좌우로 갸웃갸웃
			var k := smoothstep(0.0, 0.35, t)
			var tilt := sin(t * TAU / 1.5)
			_torso.rotation.z = tilt * 0.2 * k
			_torso.position.y = absf(tilt) * 0.03
			var poke := sin(t * 16.0) * 0.03
			_aim(_left_arm, _REST_L.lerp(Vector3(0.11, 0.3, 0.36 + poke), k))
			_aim(_right_arm, _REST_R.lerp(Vector3(-0.11, 0.3, 0.36 - poke), k))
			_left_leg.rotation.x = maxf(0.0, tilt) * 0.5 * k
			_right_leg.rotation.x = maxf(0.0, -tilt) * 0.5 * k
		"twirl":
			# 발레: 두 팔을 머리 위로 둥글게, 발끝으로 서서 빙그르르 두 바퀴
			var k := smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(3.0, 3.4, t))
			_both(_REST_L.lerp(Vector3(-0.28, 0.95, 0.2), k))
			var sp := smoothstep(0.3, 3.0, t)
			_torso.rotation.y = sp * TAU * 2.0
			_hips.rotation.y = _torso.rotation.y
			_torso.rotation.z = sin(sp * TAU * 2.0) * 0.05
			position.y = 0.05 * k
			_left_leg.rotation.z = 0.08 * k
			_right_leg.rotation.z = -0.08 * k
		"kiss_blow":
			# 손을 입에 쪽 → 앞으로 휙 날리기
			var a := smoothstep(0.1, 0.5, t)
			var th := smoothstep(1.0, 1.25, t)
			var back := smoothstep(2.1, 2.6, t)
			_aim(_right_arm, _REST_R.lerp(Vector3(-0.27, 0.27, 0.45), a).lerp(Vector3(0.55, 0.45, 0.75), th).lerp(_REST_R, back))
			_aim(_left_arm, _REST_L.lerp(Vector3(0.5, -0.35, 0.75), a * (1.0 - back)))
			_torso.rotation.x = -0.08 * a * (1.0 - th) + 0.15 * th * (1.0 - back)
			_torso.rotation.z = -0.1 * a * (1.0 - back)
			_torso.rotation.y = sin(t * 10.0) * 0.05 * (a - th)
			_right_leg.rotation.x = 0.5 * th * (1.0 - back)
		"cheer":
			# 치어리더: 폼폼 들고 박자마다 동작 바꾸며 점프
			if _props.is_empty():
				_pompom(_left_arm, Color(1.0, 0.3, 0.6), Color(1.0, 0.85, 0.25))
				_pompom(_right_arm, Color(0.3, 0.75, 1.0), Color(1.0, 0.85, 0.25))
			var poses := [
				[Vector3(-0.6, 0.8, 0.1), Vector3(0.6, 0.8, 0.1)],    # V
				[Vector3(0.2, -0.5, 0.85), Vector3(-0.2, -0.5, 0.85)],  # 앞으로 모음
				[Vector3(-0.9, -0.3, 0.2), Vector3(0.15, 1.0, 0.1)],  # 오른손 위
				[Vector3(-0.15, 1.0, 0.1), Vector3(0.9, -0.3, 0.2)],  # 왼손 위
				[Vector3(-1.0, 0.1, 0.15), Vector3(1.0, 0.1, 0.15)],  # T
			]
			var order := [0, 1, 2, 3, 0, 4, 2, 3]
			var beat := t / 0.425
			var i := int(beat)
			var f := fmod(beat, 1.0)
			var snap := smoothstep(0.0, 0.3, f)
			var cur: Array = poses[order[i % order.size()]]
			var prev: Array = [_REST_L, _REST_R] if i == 0 else poses[order[(i - 1) % order.size()]]
			if t > 3.1:
				cur = [_REST_L, _REST_R]
				snap = smoothstep(3.1, 3.4, t)
				prev = poses[order[7]]
			_aim(_left_arm, (prev[0] as Vector3).lerp(cur[0], snap))
			_aim(_right_arm, (prev[1] as Vector3).lerp(cur[1], snap))
			var jump := sin(f * PI) if (order[i % order.size()] == 0 and t < 3.1) else 0.0
			position.y = jump * 0.15 + absf(sin(f * PI)) * 0.02
			_left_leg.rotation = Vector3(0.5 * jump, 0, -0.15 * jump)
			_right_leg.rotation = Vector3(0.5 * jump, 0, 0.15 * jump)
			_torso.rotation.z = sin(beat * PI) * 0.06
		"sleepy_nap":
			# 꾸벅... 화들짝! 꾸벅... 화들짝! 꾸벅...
			var drop := 0.0
			var jerk := 0.0
			if t < 1.25:
				drop = smoothstep(0.1, 1.25, t)
			elif t < 1.4:
				jerk = sin((t - 1.25) / 0.15 * PI)
				drop = 1.0 - (t - 1.25) / 0.15
			elif t < 2.65:
				drop = smoothstep(1.4, 2.65, t)
			elif t < 2.8:
				jerk = sin((t - 2.65) / 0.15 * PI)
				drop = 1.0 - (t - 2.65) / 0.15
			else:
				drop = smoothstep(2.8, 3.6, t)
			drop = drop * drop
			var side := 1.0 if t < 1.4 or t > 2.8 else -1.0
			_torso.rotation.x = drop * 0.38 - jerk * 0.12
			_torso.rotation.z = drop * 0.12 * side
			_torso.rotation.y = sin(t * 1.3) * 0.06
			_torso.position.y = -drop * 0.03 + jerk * 0.04
			_both(_REST_L.lerp(Vector3(-0.1, -0.95, 0.3), drop) + Vector3(-0.8, 0.4, 0.0) * jerk)
			_left_leg.rotation.x = -0.12 * drop
			_right_leg.rotation.x = -0.12 * drop
		# ---------------------------------------------------------------- 저질
		"nose_pick":
			# 코 후비적 → 손가락 관찰 → 튕기기!
			var to := smoothstep(0.1, 0.45, t)
			var look := smoothstep(1.6, 1.9, t)
			var flick := smoothstep(2.5, 2.62, t)
			var rel := smoothstep(3.0, 3.4, t)
			var dig := sin(t * 22.0) * 0.05 * (to - look)
			var nose_d := Vector3(-0.25 + dig, 0.32 + dig * 0.5, 0.5)
			_aim(_right_arm, _REST_R.lerp(nose_d, to).lerp(Vector3(-0.2, 0.15, 0.95), look).lerp(Vector3(0.35, 0.35, 0.9), flick).lerp(_REST_R, rel))
			_right_arm.scale = Vector3(1.0, 1.0 + 0.15 * to * (1.0 - rel), 1.0)
			_left_arm.rotation = Vector3(-0.2, 0.0, -0.6)
			_torso.rotation.x = -0.06 * to * (1.0 - look) + 0.15 * look * (1.0 - flick)
			_torso.rotation.z = sin(t * 3.0) * 0.08 * look * (1.0 - flick) + dig * 0.5
			_torso.rotation.y = -0.2 * flick * (1.0 - rel)
		"butt_slap":
			# 엉덩이 내밀고 박자에 맞춰 찰싹! 엉덩이가 출렁
			var lean := smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(2.55, 2.8, t))
			_torso.rotation.x = 0.32 * lean
			_torso.position.z = -0.04 * lean
			_left_leg.rotation = Vector3(-0.15 * lean, 0, -0.08 * lean)
			_right_leg.rotation = Vector3(-0.15 * lean, 0, 0.08 * lean)
			var beat := t * 2.5
			var f := fmod(beat, 1.0)
			var away := smoothstep(0.0, 0.5, f) * (1.0 - smoothstep(0.75, 1.0, f))
			if t < 0.4:
				away = smoothstep(0.0, 0.4, t)
			_aim(_right_arm, _REST_R.lerp(Vector3(-0.05, -0.8, -0.6).lerp(Vector3(0.8, -0.1, -0.5), away), lean))
			_aim(_left_arm, _REST_L.lerp(Vector3(-0.1, -0.8, 0.6), lean))  # 무릎 짚기
			var e := exp(-f * 6.0) * lean if t >= 0.4 else 0.0
			var jig := sin(f * 32.0) * e
			_hips.scale = Vector3(1.0 + jig * 0.12, 1.0 - jig * 0.1, 1.0 + jig * 0.08)
			_hips.rotation.z = jig * 0.15
			_hips.position.z = HIPS_BASE.z - 0.04 * lean
			_torso.position.y = e * 0.02
		"burp":
			# 배 내밀고 뒤로 젖힘 → 꺼억! → 배 토닥토닥
			var lb := smoothstep(0.0, 0.55, t)
			var k := smoothstep(0.65, 0.75, t) * (1.0 - smoothstep(1.1, 1.5, t))
			var after := smoothstep(1.3, 1.6, t) * (1.0 - smoothstep(2.1, 2.4, t))
			_torso.rotation.x = -0.22 * lb * (1.0 - k) + 0.12 * k - 0.05 * after
			_torso.position.x = sin(t * 45.0) * 0.012 * k
			_torso.position.y = 0.03 * k
			_aim(_left_arm, _REST_L.lerp(Vector3(0.45, -0.55, 0.75), lb * (1.0 - smoothstep(2.1, 2.4, t))))
			var pat := absf(sin(t * 9.0)) * 0.15 * after
			_aim(_right_arm, _REST_R.lerp(Vector3(-0.3, 0.2 * (1.0 - k), 0.6), lb * (1.0 - after) * (1.0 - smoothstep(2.0, 2.3, t))).lerp(Vector3(-0.45, -0.55 + pat, 0.75), after))
			_torso.rotation.z = sin(t * 3.0) * 0.06 * after
		"armpit_fart":
			# 왼손을 오른쪽 겨드랑이에 끼고 오른팔을 펌프질 → 뿌웅 뿌웅
			var k := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(2.7, 3.0, t))
			var on := smoothstep(0.35, 0.5, t) * (1.0 - smoothstep(2.6, 2.75, t))
			var pump := (1.0 - sin(t * TAU * 3.0)) * 0.5 * on
			_aim(_right_arm, _REST_R.lerp(Vector3(0.85, 0.55, 0.1).lerp(Vector3(0.6, -0.8, 0.15), pump), k))
			_aim(_left_arm, _REST_L.lerp(Vector3(0.53, -0.08, 0.3), k))
			_torso.rotation.y = 0.2 * k
			_torso.rotation.z = -0.08 * k + pump * 0.05
			_torso.position.y = -pump * 0.025
			_left_leg.rotation.x = -pump * 0.1
			_right_leg.rotation.x = -pump * 0.1
		"butt_scoot":
			# 바닥에 털썩 앉아 강아지처럼 엉덩이로 앞뒤로 썰매
			var s := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(3.05, 3.4, t))
			var sc := sin(t * 9.0) * s * smoothstep(0.35, 0.5, t)
			position = Vector3(0, -0.27 * s + absf(sc) * 0.03, 0) + _fwd(sc * 0.07)
			rotation.z = sc * 0.08
			_torso.rotation.x = -0.18 * s
			_left_leg.rotation = Vector3(-1.45 * s - absf(sc) * 0.15, 0, -0.15 * s)
			_right_leg.rotation = Vector3(-1.45 * s - absf(sc) * 0.15, 0, 0.15 * s)
			_both(_REST_L.lerp(Vector3(-0.35, -0.75, -0.55), s))
			_hips.rotation.z = -sc * 0.1
		"dog_pee":
			# 네 발로 엎드려 한쪽 뒷다리를 번쩍 (강아지 쉬야)
			var s := smoothstep(0.0, 0.45, t) * (1.0 - smoothstep(2.8, 3.2, t))
			var p := 1.35 * s
			rotation.x = p
			position = Vector3(0, 0.167 * s, 0) + _fwd(-0.6 * s)  # 몸 가운데가 제자리에 오도록 뒤로
			_both(Vector3(-0.1 * s, -cos(p), sin(p)))  # 팔은 땅을 짚음 (세로로)
			var lift := smoothstep(0.7, 1.0, t) * (1.0 - smoothstep(2.4, 2.7, t))
			_left_leg.rotation = Vector3(-p + 0.785 * s, 0, -0.05 * s)
			_right_leg.rotation = Vector3(-p + 0.785 * s, 0, 0.05 * s + 1.4 * lift)
			_hips.rotation.y = sin(t * 10.0) * 0.2 * s * (1.0 - lift)
			_torso.rotation.z = sin(t * 2.0) * 0.04 * s
		"tongue":
			# 엄지를 귀에 대고 손가락 팔랑팔랑 + 혀 낼름 (메롱)
			var k := smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(2.3, 2.6, t))
			var wig := sin(t * 18.0)
			_aim(_left_arm, _REST_L.lerp(Vector3(-0.11, 0.44, 0.05 + wig * 0.12), k))
			_aim(_right_arm, _REST_R.lerp(Vector3(0.11, 0.44, 0.05 - wig * 0.12), k))
			_torso.rotation.z = sin(t * 7.0) * 0.12 * k
			_torso.rotation.x = 0.08 * k
			_torso.position.y = absf(sin(t * 7.0)) * 0.02
			if _props.is_empty():
				_prop_ball(_torso, Vector3(0, 1.07, 0.36), 0.08, Vector3.ZERO, _clay(Color(1.0, 0.42, 0.55)))
			var tg := smoothstep(0.25, 0.45, t) * (1.0 - smoothstep(2.2, 2.45, t))
			_props[0].scale = Vector3(0.8, 0.4, 1.1) * tg
			_props[0].position.x = sin(t * 12.0) * 0.02
		"sniff_pits":
			# 팔 들고 겨드랑이 킁킁 → 으엑! 하고 뒤로 질겁 → 코 앞 부채질
			var up := smoothstep(0.0, 0.4, t)
			var rec := smoothstep(1.45, 1.6, t)
			var calm := smoothstep(2.4, 2.9, t)
			var sniff := up * (1.0 - rec)
			_aim(_right_arm, _REST_R.lerp(Vector3(0.55, 0.85, -0.05), up).lerp(Vector3(0.95, 0.1, 0.3), rec).lerp(_REST_R, calm))
			var fan := sin(t * 16.0) * 0.25 * calm
			_aim(_left_arm, _REST_L.lerp(Vector3(-0.9, 0.0, 0.3), rec).lerp(Vector3(0.3 + fan, 0.3, 0.9), calm))
			_torso.rotation.z = -0.28 * sniff + 0.25 * rec * (1.0 - calm)
			_torso.rotation.y = 0.25 * sniff
			_torso.rotation.x = 0.06 * sin(t * 16.0) * sniff - 0.3 * rec * (1.0 - calm) + 0.05 * calm
			_torso.position.x = sin(t * 40.0) * 0.015 * rec * (1.0 - calm)
			_left_leg.rotation.x = 0.25 * rec * (1.0 - calm)
		"rocket_fart":
			# 쪼그려 힘주기 → 뿌아앙! 방귀 힘으로 위로 솟구침 → 착지 → 뿌듯
			var crouch := smoothstep(0.0, 0.6, t) * (1.0 - smoothstep(0.85, 0.95, t))
			var u := clampf((t - 0.9) / 1.0, 0.0, 1.0)
			var h := 4.0 * u * (1.0 - u) * 1.1
			var fly := 1.0 if (t > 0.9 and t < 1.9) else 0.0
			var land := sin(clampf((t - 1.9) / 0.4, 0.0, 1.0) * PI)
			var proud := smoothstep(2.3, 2.6, t)
			position.y = h
			_torso.position.y = -0.15 * crouch - 0.12 * land
			_torso.rotation.x = 0.35 * crouch + 0.2 * fly - 0.1 * proud
			if t < 0.85:
				_torso.position.x = sin(t * 70.0) * 0.015 * crouch
			_left_leg.rotation = Vector3(-0.7 * crouch - 0.6 * land, 0, -0.3 * fly)
			_right_leg.rotation = Vector3(-0.7 * crouch - 0.6 * land, 0, 0.3 * fly)
			if fly > 0.0:
				var fl := sin(t * 20.0) * 0.3
				_aim(_left_arm, Vector3(-0.5 + fl, 0.85, 0.0))
				_aim(_right_arm, Vector3(0.5 + fl, 0.85, 0.0))
				rotation.x = sin(t * 9.0) * 0.12
			else:
				_both(_REST_L.lerp(Vector3(0.1, -0.6, 0.8), crouch).lerp(Vector3(-0.75, -0.6, -0.2), proud))
		"butt_scratch":
			# 엉덩이를 벅벅 긁으며 시원~ 하게 살랑
			var k := smoothstep(0.0, 0.4, t) * (1.0 - smoothstep(2.7, 3.0, t))
			var sc := sin(t * 20.0)
			_aim(_right_arm, _REST_R.lerp(Vector3(-0.15 + sc * 0.12, -0.7, -0.7), k))
			_aim(_left_arm, Vector3(-0.25 + sin(t * 2.0) * 0.05, -0.97, sin(t * 2.0) * 0.1))
			var sw := sin(t * 2.0)
			_torso.rotation.x = 0.1 * k - 0.15 * smoothstep(1.2, 1.6, t) * k
			_torso.rotation.z = sw * 0.08 * k
			_hips.rotation.z = sw * 0.15 * k + sc * 0.03 * k
			_hips.position.x = sw * 0.03 * k
			_left_leg.rotation.x = -maxf(0.0, sw) * 0.15 * k
			_right_leg.rotation.x = -maxf(0.0, -sw) * 0.15 * k
		# ---------------------------------------------------------------- 웃긴
		"floss":
			# 플로스: 엉덩이는 한쪽, 쭉 편 팔은 반대쪽으로 (앞·뒤 번갈아)
			var k := smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(3.7, 4.0, t))
			var ph := t * TAU * 1.5
			var s := sin(ph)
			var c := cos(ph)
			_torso.position.x = s * 0.05 * k
			_torso.rotation.z = s * 0.1 * k
			_torso.position.y = absf(c) * 0.02 * k
			var dx := -s * 0.45
			_aim(_left_arm, _REST_L.lerp(Vector3(dx - 0.15, -0.85, c * 0.8), k))
			_aim(_right_arm, _REST_R.lerp(Vector3(dx + 0.15, -0.85, -c * 0.8), k))
			_left_leg.rotation = Vector3((-0.08 - maxf(0.0, s) * 0.15) * k, 0, s * 0.08 * k)
			_right_leg.rotation = Vector3((-0.08 - maxf(0.0, -s) * 0.15) * k, 0, s * 0.08 * k)
		"worm":
			# 바닥에 엎드려 웨이브 (애벌레 춤)
			var dn := smoothstep(0.0, 0.4, t) * (1.0 - smoothstep(3.2, 3.6, t))
			var w := t * TAU * 1.3
			var on := smoothstep(0.5, 0.8, t) * (1.0 - smoothstep(3.0, 3.2, t))
			rotation.x = 1.45 * dn - sin(w) * 0.12 * on
			position = Vector3(0, 0.3 * dn + maxf(0.0, sin(w)) * 0.12 * on, 0) + _fwd(-0.65 * dn)
			_torso.rotation.x = -maxf(0.0, sin(w + 1.5)) * 0.2 * on
			_left_leg.rotation.x = maxf(0.0, sin(w - 1.5)) * 0.6 * on
			_right_leg.rotation.x = maxf(0.0, sin(w - 1.5)) * 0.6 * on
			_both(_REST_L.lerp(Vector3(-0.25, -0.4 + sin(w) * 0.2 * on, 0.88), dn))
		"flex":
			# 보디빌더 포즈 3종: 더블 바이셉스 → 크랩 → 사이드 체스트 (팔이 빵빵)
			var poses := [
				[Vector3(-0.85, 0.55, 0.05), Vector3(0.85, 0.55, 0.05), 0.0, -0.05],
				[Vector3(0.45, -0.55, 0.75), Vector3(-0.45, -0.55, 0.75), 0.0, 0.18],
				[Vector3(0.6, -0.4, 0.75), Vector3(0.1, -0.6, 0.8), 0.6, 0.0],
			]
			var i := mini(2, int(t))
			var lt := t - float(i)
			var hit := smoothstep(0.0, 0.18, lt)
			var cur: Array = poses[i]
			var prev: Array = [_REST_L, _REST_R, 0.0, 0.0] if i == 0 else poses[i - 1]
			var trem := sin(t * 40.0) * 0.012 * hit
			_aim(_left_arm, (prev[0] as Vector3).lerp(cur[0], hit))
			_aim(_right_arm, (prev[1] as Vector3).lerp(cur[1], hit))
			_torso.rotation.y = lerpf(prev[2], cur[2], hit)
			_torso.rotation.x = lerpf(prev[3], cur[3], hit)
			_torso.position.x = trem
			var pw := 1.0 + 0.4 * hit * (1.0 - smoothstep(2.75, 3.0, t)) + sin(lt * 25.0) * 0.03 * hit
			_left_arm.scale = Vector3(pw, 1.0, pw)
			_right_arm.scale = Vector3(pw, 1.0, pw)
			_left_leg.rotation = Vector3(-0.3 if i == 2 else 0.0, 0, -0.15 if i == 0 else 0.0)
			_right_leg.rotation.z = 0.15 if i == 0 else 0.0
			_torso.position.y = -0.03 * hit if i == 1 else 0.0
		"slip":
			# 바나나 밟고 미끄덩 → 다리가 하늘로 → 벌러덩 → 어질어질 → 일어남
			var fl := smoothstep(0.35, 0.8, t)
			var air := sin(clampf((t - 0.35) / 0.45, 0.0, 1.0) * PI)
			var up := smoothstep(2.75, 3.2, t)
			var lie := fl * (1.0 - up)
			rotation.x = -1.45 * lie
			position.y = 0.32 * lie + air * 0.35
			if t < 0.35:
				_right_leg.rotation.x = -0.35 * sin(t / 0.35 * PI)
				_left_leg.rotation.x = 0.2 * sin(t / 0.35 * PI)
			else:
				var tw := sin(t * 40.0) * 0.12 if fmod(t, 1.0) < 0.2 else 0.0
				_left_leg.rotation.x = (-1.2 * air - 0.3 * lie + tw) * (1.0 - up)
				_right_leg.rotation.x = (-1.0 * air - 0.2 * lie - tw) * (1.0 - up)
			var arm_air := Vector3(-0.6 + sin(t * 25.0) * 0.3, 0.8, 0.0)
			_both(_REST_L.lerp(arm_air, air).lerp(Vector3(-0.96, -0.27, 0.0), lie * (1.0 - air)))
			_torso.rotation.z = sin(t * 3.0) * 0.06 * lie
		"headbang":
			# 헤드뱅잉 + 락 손가락 (뿔)
			var k := smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(3.3, 3.6, t))
			var bt := t * 2.6
			var hb := pow(absf(sin(bt * PI)), 0.6)
			_torso.rotation.x = (0.1 + hb * 0.38) * k
			_torso.position.y = -0.06 * k
			_left_leg.rotation = Vector3(-0.15 * k, 0, -0.22 * k)
			_right_leg.rotation = Vector3(-0.15 * k, 0, 0.22 * k)
			_aim(_right_arm, _REST_R.lerp(Vector3(0.35, 0.95, 0.1 + hb * 0.4), k))
			_aim(_left_arm, _REST_L.lerp(Vector3(-0.4, 0.4 - hb * 0.3, 0.8), k))
		"moonwalk":
			# 문워크: 한 발씩 뒤로 쭉 미끄러짐 → 마지막에 모자 터치
			var k := smoothstep(0.0, 0.3, t)
			var mw := 1.0 - smoothstep(2.9, 3.05, t)
			var ph := t / 0.6
			var f := fmod(ph, 1.0)
			var slide := lerpf(-0.1, 0.45, f)
			var back := lerpf(0.45, -0.1, smoothstep(0.0, 0.3, f))
			var a_left := int(ph) % 2 == 0
			_left_leg.rotation.x = (slide if a_left else back) * k * mw
			_right_leg.rotation.x = (back if a_left else slide) * k * mw
			_torso.rotation.x = 0.12 * k * mw
			_torso.position.y = (-0.03 + absf(sin(ph * PI)) * 0.02) * k * mw
			_torso.rotation.z = sin(ph * PI) * 0.05 * mw
			_left_arm.rotation = Vector3(sin(ph * PI) * 0.3 * mw, 0, -0.3)
			_right_arm.rotation = Vector3(-sin(ph * PI) * 0.3 * mw, 0, 0.3)
			var tip := smoothstep(2.95, 3.15, t)
			if tip > 0.0:
				_aim(_right_arm, _REST_R.lerp(Vector3(0.25, 0.95, 0.3), tip))
				_aim(_left_arm, _REST_L.lerp(Vector3(-0.9, -0.2, 0.2), tip))
				_torso.rotation.x = 0.18 * tip
				_right_leg.rotation = Vector3(-0.1 * tip, 0, -0.2 * tip)
		"sneeze":
			# 아... 아... (고개 뒤로) → 에취!! (앞으로 확) → 코 쓱쓱
			var build := smoothstep(0.0, 1.2, t)
			var ach := smoothstep(1.2, 1.32, t)
			var rec := smoothstep(1.5, 2.2, t)
			var rub := smoothstep(1.7, 1.95, t) * (1.0 - smoothstep(2.35, 2.6, t))
			_torso.rotation.x = -0.32 * build * (1.0 - ach) + 0.5 * ach * (1.0 - rec) + 0.05 * rec
			_torso.position.x = sin(t * 30.0) * 0.01 * build * (1.0 - ach)
			position = _fwd(0.08 * ach * (1.0 - rec))
			_both(_REST_L.lerp(Vector3(-0.5, -0.5, 0.3), build * (1.0 - ach)).lerp(Vector3(-0.6, -0.3, -0.6), ach * (1.0 - rec)))
			if rub > 0.0:
				var wig := sin(t * 20.0) * 0.06
				_aim(_right_arm, _REST_R.lerp(Vector3(-0.25 + wig, 0.32, 0.5), rub))
			_left_leg.rotation.x = -0.2 * ach * (1.0 - rec)
			_right_leg.rotation.x = 0.15 * ach * (1.0 - rec)
		"facepalm":
			# 손바닥으로 이마 탁 + 고개 절레절레
			var k := smoothstep(0.0, 0.4, t) * (1.0 - smoothstep(2.5, 2.8, t))
			_aim(_right_arm, _REST_R.lerp(Vector3(-0.15, 0.44, 0.38), k))
			_right_arm.scale = Vector3(1.0, 1.0 + 0.3 * k, 1.0)  # 짧은 팔이 눈까지 닿도록 살짝 늘림
			_aim(_left_arm, _REST_L.lerp(Vector3(-0.1, -0.95, 0.15), k))
			var shake := sin((t - 0.5) * 5.0) * 0.28 * smoothstep(0.5, 0.8, t)
			_torso.rotation.y = shake * k
			_torso.rotation.x = 0.15 * k
			_torso.rotation.z = 0.05 * k
			_torso.position.y = -0.02 * k
		"tantrum":
			# 바닥에 드러누워 팔다리 버둥버둥 떼쓰기
			var dn := smoothstep(0.0, 0.35, t) * (1.0 - smoothstep(3.25, 3.6, t))
			rotation.x = -1.45 * dn
			position.y = 0.32 * dn
			var kick := sin(t * 20.0)
			_left_leg.rotation.x = (-0.7 + kick * 0.55) * dn
			_right_leg.rotation.x = (-0.7 - kick * 0.55) * dn
			_left_leg.rotation.z = -0.2 * dn
			_right_leg.rotation.z = 0.2 * dn
			_aim(_left_arm, _REST_L.lerp(Vector3(-0.7, 0.3 * sin(t * 17.0), 0.6 + 0.3 * cos(t * 17.0)), dn))
			_aim(_right_arm, _REST_R.lerp(Vector3(0.7, 0.3 * cos(t * 15.0), 0.6 + 0.3 * sin(t * 15.0)), dn))
			_torso.rotation.y = sin(t * 6.0) * 0.25 * dn
		"air_guitar":
			# 에어 기타: 왼손 기타 넥, 오른손 스트럼 + 무릎 굽혀 락 → 풍차 스트럼 피날레
			var k := smoothstep(0.0, 0.3, t) * (1.0 - smoothstep(3.75, 4.0, t))
			var st := sin(t * TAU * 4.0)
			_aim(_left_arm, _REST_L.lerp(Vector3(-0.75 + sin(t * 1.7) * 0.08, -0.05, 0.62), k))
			var strum := Vector3(-0.5, -0.65 + st * 0.25, 0.75)
			var wm := smoothstep(2.95, 3.05, t) * (1.0 - smoothstep(3.55, 3.65, t))
			if wm > 0.0:
				var a := (t - 3.0) / 0.6 * TAU
				strum = strum.lerp(Vector3(0.35, -cos(a), sin(a)), wm)
			elif t >= 3.55:
				strum = strum.lerp(Vector3(0.4, 0.9, 0.1), smoothstep(3.55, 3.65, t))
			_aim(_right_arm, _REST_R.lerp(strum, k))
			_torso.rotation.x = (-0.12 + sin(t * PI * 2.0) * 0.05) * k
			_torso.rotation.z = sin(t * PI) * 0.08 * k
			_torso.position.y = (-0.05 - absf(sin(t * PI * 2.0)) * 0.03) * k
			_left_leg.rotation = Vector3(-0.15 * k, 0, -0.2 * k)
			_right_leg.rotation = Vector3(-0.15 * k, 0, 0.2 * k)


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
