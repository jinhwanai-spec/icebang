class_name SeekerBody
extends Node3D
## 술래 외형 (점토 인형 스타일, 유저보다 1.5배 크고 위협적)
## 앞쪽은 -Z 방향입니다 (술래 스크립트가 -Z 방향을 앞으로 씀).
## type: ghost(유령) / butcher(도살자) / rat(역병의 쥐) / spider(거미 여왕) / mannequin(마네킹)
##       hound(사냥개) / puppeteer(인형사) / witch(안개 마녀)

var type := "ghost"
var axe_in_hand: Node3D   # 도살자가 던지면 잠깐 숨김
## 하마 입 (블랙홀 때 벌어짐)
var mouth_jaw: Node3D

var _mats: Array[StandardMaterial3D] = []
var _torso: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _tail: Node3D
var _spider_legs: Array[Node3D] = []
var _phase := 0.0
var _eye_mats: Array[StandardMaterial3D] = []
var _blink := 0.0
var _attack_t := 0.0
var _attack_dur := 0.3
var _arm_rest_x := 0.0


func build(seeker_type: String) -> void:
	type = seeker_type
	_torso = Node3D.new()
	add_child(_torso)
	var eye := _glow(Color(1.0, 0.85, 0.15))
	match type:
		"ghost":
			var white := _clay(Color(0.92, 0.94, 1.0), 0.75)
			# 아래로 퍼지는 천 같은 몸 (다리 없음)
			var robe := CylinderMesh.new()
			robe.top_radius = 0.38
			robe.bottom_radius = 0.75
			robe.height = 1.7
			_part(_torso, Vector3(0, 1.15, 0), robe, white)
			_sphere(_torso, Vector3(0, 2.25, 0), 0.55, Vector3.ONE, white)
			_left_arm = _limb(_torso, Vector3(-0.45, 1.8, 0), 0.09, 1.5, white)
			_right_arm = _limb(_torso, Vector3(0.45, 1.8, 0), 0.09, 1.5, white)
			_left_arm.rotation = Vector3(-0.6, 0, -0.2)
			_right_arm.rotation = Vector3(-0.6, 0, 0.2)
			_eyes(_torso, 2.35, 0.5, eye)
			_mouth(_torso, 2.05, 0.5, 0.42)
		"butcher":
			var skin := _clay(Color(0.55, 0.42, 0.33))
			var sack := _clay(Color(0.45, 0.36, 0.22))
			var apron := _clay(Color(0.7, 0.68, 0.62))
			_sphere(_torso, Vector3(0, 1.35, 0), 0.6, Vector3(1.0, 1.1, 0.85), skin)
			_box(_torso, Vector3(0, 1.2, -0.48), Vector3(0.8, 0.95, 0.06), apron)
			_sphere(_torso, Vector3(0, 2.3, 0), 0.5, Vector3(1.0, 1.15, 1.0), sack)
			_eyes(_torso, 2.38, 0.47, eye)
			_mouth(_torso, 2.12, 0.5, 0.36)
			var chain := TorusMesh.new()
			chain.inner_radius = 0.55
			chain.outer_radius = 0.64
			_part(_torso, Vector3(0, 0.95, 0), chain, _clay(Color(0.4, 0.4, 0.42)))
			_left_leg = _limb(self, Vector3(-0.25, 0.75, 0), 0.17, 0.75, skin)
			_right_leg = _limb(self, Vector3(0.25, 0.75, 0), 0.17, 0.75, skin)
			_left_arm = _limb(_torso, Vector3(-0.62, 1.75, 0), 0.15, 1.05, skin)
			_right_arm = _limb(_torso, Vector3(0.62, 1.75, 0), 0.15, 1.05, skin)
			# 오른손의 도끼
			axe_in_hand = Node3D.new()
			axe_in_hand.position = Vector3(0, -1.0, 0)
			_right_arm.add_child(axe_in_hand)
			var handle := CylinderMesh.new()
			handle.top_radius = 0.04
			handle.bottom_radius = 0.04
			handle.height = 0.9
			_part(axe_in_hand, Vector3.ZERO, handle, _clay(Color(0.4, 0.26, 0.14)))
			_box(axe_in_hand, Vector3(0, 0.35, -0.18), Vector3(0.06, 0.32, 0.36), _clay(Color(0.65, 0.66, 0.7)))
			axe_in_hand.rotation.x = -PI / 2.0
		"rat":
			var fur := _clay(Color(0.45, 0.43, 0.42))
			var pink := _clay(Color(0.85, 0.6, 0.62))
			var cloak := _clay(Color(0.2, 0.28, 0.2))
			_sphere(_torso, Vector3(0, 1.3, 0.05), 0.55, Vector3(1.0, 1.2, 0.95), cloak)
			# 쥐 머리: 앞으로 길쭉한 주둥이
			_sphere(_torso, Vector3(0, 2.15, -0.1), 0.42, Vector3(0.9, 0.9, 1.25), fur)
			_sphere(_torso, Vector3(0, 2.05, -0.55), 0.11, Vector3.ONE, pink)
			for x in [-0.3, 0.3]:
				_sphere(_torso, Vector3(x, 2.55, 0.0), 0.2, Vector3(1.0, 1.0, 0.3), pink)
			_eyes(_torso, 2.25, 0.4, _glow(Color(1.0, 0.2, 0.2)))
			_mouth(_torso, 1.98, 0.58, 0.26)
			# 허리의 플라스크 3개
			var flask_glow := _glow(Color(0.4, 1.0, 0.3))
			for i in 3:
				_sphere(_torso, Vector3(-0.35 + i * 0.35, 0.95, -0.5), 0.1, Vector3.ONE, flask_glow)
			_left_leg = _limb(self, Vector3(-0.22, 0.75, 0), 0.13, 0.75, fur)
			_right_leg = _limb(self, Vector3(0.22, 0.75, 0), 0.13, 0.75, fur)
			_left_arm = _limb(_torso, Vector3(-0.55, 1.75, 0), 0.09, 1.1, fur)
			_right_arm = _limb(_torso, Vector3(0.55, 1.75, 0), 0.09, 1.1, fur)
			# 꼬리
			_tail = Node3D.new()
			_tail.position = Vector3(0, 0.9, 0.5)
			_torso.add_child(_tail)
			var tail_mesh := CylinderMesh.new()
			tail_mesh.top_radius = 0.02
			tail_mesh.bottom_radius = 0.07
			tail_mesh.height = 1.3
			_part(_tail, Vector3(0, 0, 0.6), tail_mesh, pink).rotation.x = PI / 2.0 - 0.3
		"spider":
			var shell := _clay(Color(0.12, 0.1, 0.12))
			var red_eye := _glow(Color(1.0, 0.1, 0.1))
			# 커다란 배 + 머리, 다리 8개
			_sphere(_torso, Vector3(0, 1.25, 0.55), 0.75, Vector3(1.0, 0.85, 1.15), shell)
			_sphere(_torso, Vector3(0, 1.15, -0.35), 0.42, Vector3(1.0, 0.8, 1.0), shell)
			_sphere(_torso, Vector3(0, 1.3, 0.9), 0.22, Vector3(1.0, 0.4, 1.0), _glow(Color(0.7, 0.0, 0.0)))
			for i in 6:
				_sphere(_torso, Vector3(-0.2 + (i % 3) * 0.2, 1.22 + (i / 3) * 0.12, -0.72), 0.055, Vector3.ONE, red_eye)
			_eye_mats.append(red_eye)
			_mouth(_torso, 1.0, 0.68, 0.3)
			for i in 4:
				for side in [-1.0, 1.0]:
					var leg := _limb(_torso, Vector3(side * 0.35, 1.2, -0.3 + i * 0.3), 0.05, 1.5, shell)
					leg.rotation = Vector3(0, (i - 1.5) * 0.35 * side, side * 0.9)  # 바깥쪽 아래로 뻗음
					_spider_legs.append(leg)
			_left_arm = _limb(_torso, Vector3(-0.15, 1.0, -0.65), 0.04, 0.45, shell)
			_right_arm = _limb(_torso, Vector3(0.15, 1.0, -0.65), 0.04, 0.45, shell)
		"mannequin":
			var pale := _clay(Color(0.88, 0.84, 0.78))
			var crack := _clay(Color(0.15, 0.1, 0.1))
			_sphere(_torso, Vector3(0, 1.55, 0), 0.42, Vector3(1.0, 1.5, 0.7), pale)
			_sphere(_torso, Vector3(0, 2.45, 0), 0.34, Vector3(0.85, 1.15, 0.9), pale)  # 얼굴 없는 머리
			for i in 4:
				_box(_torso, Vector3(-0.15 + i * 0.1, 2.4 + (i % 2) * 0.15, -0.3), Vector3(0.02, 0.22, 0.02), crack).rotation.z = 0.5 * (1 - (i % 2) * 2)
			_box(_torso, Vector3(0.1, 1.6, -0.3), Vector3(0.02, 0.5, 0.02), crack).rotation.z = 0.3
			_eyes(_torso, 2.48, 0.28, _glow(Color(0.9, 0.9, 1.0)))
			_left_leg = _limb(self, Vector3(-0.17, 1.0, 0), 0.09, 1.0, pale)
			_right_leg = _limb(self, Vector3(0.17, 1.0, 0), 0.09, 1.0, pale)
			_left_arm = _limb(_torso, Vector3(-0.42, 2.0, 0), 0.07, 1.15, pale)
			_right_arm = _limb(_torso, Vector3(0.42, 2.0, 0), 0.07, 1.15, pale)
		"hound":
			var hide := _clay(Color(0.25, 0.17, 0.14))
			var bone := _clay(Color(0.85, 0.8, 0.7))
			# 네 발 짐승: 몸통은 가로로 길게
			_sphere(_torso, Vector3(0, 1.1, 0.1), 0.5, Vector3(0.9, 0.85, 1.7), hide)
			for i in 4:
				_sphere(_torso, Vector3(0, 1.45, -0.4 + i * 0.3), 0.08, Vector3.ONE, bone)  # 튀어나온 등뼈
			_sphere(_torso, Vector3(0, 1.4, -0.95), 0.36, Vector3(0.9, 0.85, 1.35), hide)
			_sphere(_torso, Vector3(0, 1.3, -1.35), 0.2, Vector3(0.8, 0.7, 1.2), bone)
			_eyes(_torso, 1.55, 1.15, _glow(Color(1.0, 0.45, 0.0)))
			_mouth(_torso, 1.2, 1.4, 0.3)
			_left_arm = _limb(_torso, Vector3(-0.3, 1.0, -0.55), 0.1, 1.0, hide)
			_right_arm = _limb(_torso, Vector3(0.3, 1.0, -0.55), 0.1, 1.0, hide)
			_left_leg = _limb(self, Vector3(-0.3, 1.0, 0.7), 0.11, 1.0, hide)
			_right_leg = _limb(self, Vector3(0.3, 1.0, 0.7), 0.11, 1.0, hide)
			_tail = Node3D.new()
			_tail.position = Vector3(0, 1.25, 0.95)
			_torso.add_child(_tail)
			var t_mesh := CylinderMesh.new()
			t_mesh.top_radius = 0.02
			t_mesh.bottom_radius = 0.06
			t_mesh.height = 0.7
			_part(_tail, Vector3(0, 0.1, 0.3), t_mesh, hide).rotation.x = PI / 2.0 - 0.6
		"puppeteer":
			var coat := _clay(Color(0.18, 0.1, 0.2))
			var mask := _clay(Color(0.96, 0.95, 0.92))
			var string_mat := _glow(Color(0.8, 0.8, 0.9))
			_sphere(_torso, Vector3(0, 1.7, 0), 0.45, Vector3(0.9, 1.9, 0.75), coat)
			_sphere(_torso, Vector3(0, 2.95, 0), 0.33, Vector3(0.9, 1.15, 0.9), coat)
			_sphere(_torso, Vector3(0, 2.95, -0.18), 0.3, Vector3(0.9, 1.1, 0.5), mask)  # 하얀 가면
			_eyes(_torso, 3.02, 0.33, _glow(Color(0.7, 0.2, 1.0)))
			_mouth(_torso, 2.8, 0.33, 0.24)
			_left_leg = _limb(self, Vector3(-0.2, 1.05, 0), 0.1, 1.05, coat)
			_right_leg = _limb(self, Vector3(0.2, 1.05, 0), 0.1, 1.05, coat)
			_left_arm = _limb(_torso, Vector3(-0.45, 2.4, 0), 0.06, 1.8, coat)
			_right_arm = _limb(_torso, Vector3(0.45, 2.4, 0), 0.06, 1.8, coat)
			# 손가락 끝에서 아래로 늘어진 실
			for arm in [_left_arm, _right_arm]:
				for x in [-0.06, 0.06]:
					_box(arm, Vector3(x, -2.4, 0), Vector3(0.01, 1.2, 0.01), string_mat)
		"witch":
			var robe_mat := _clay(Color(0.1, 0.16, 0.12), 0.9)
			var skin := _clay(Color(0.55, 0.62, 0.5))
			var robe := CylinderMesh.new()
			robe.top_radius = 0.32
			robe.bottom_radius = 0.8
			robe.height = 1.8
			_part(_torso, Vector3(0, 1.1, 0), robe, robe_mat)
			_sphere(_torso, Vector3(0, 2.2, 0), 0.36, Vector3(0.9, 1.1, 0.9), skin)
			var hat := CylinderMesh.new()
			hat.top_radius = 0.0
			hat.bottom_radius = 0.38
			hat.height = 0.95
			_part(_torso, Vector3(0, 2.85, 0.05), hat, robe_mat).rotation.x = 0.25
			var brim := CylinderMesh.new()
			brim.top_radius = 0.65
			brim.bottom_radius = 0.65
			brim.height = 0.04
			_part(_torso, Vector3(0, 2.45, 0), brim, robe_mat)
			_eyes(_torso, 2.25, 0.33, _glow(Color(0.3, 1.0, 0.4)))
			_mouth(_torso, 2.05, 0.33, 0.26)
			_left_arm = _limb(_torso, Vector3(-0.38, 1.85, 0), 0.07, 1.3, skin)
			_right_arm = _limb(_torso, Vector3(0.38, 1.85, 0), 0.07, 1.3, skin)
			_left_arm.rotation = Vector3(-0.8, 0, -0.3)
			_right_arm.rotation = Vector3(-0.8, 0, 0.3)
		"psycho":
			var coat := _clay(Color(0.12, 0.11, 0.13))
			var pale := _clay(Color(0.93, 0.9, 0.86))
			var blood := _clay(Color(0.45, 0.02, 0.02))
			_sphere(_torso, Vector3(0, 1.55, 0), 0.4, Vector3(0.85, 1.6, 0.7), coat)
			for i in 4:
				_sphere(_torso, Vector3(-0.2 + i * 0.13, 1.3 + (i % 2) * 0.25, -0.27), 0.06, Vector3(1, 1.6, 0.3), blood)  # 핏자국
			_sphere(_torso, Vector3(0, 2.5, 0), 0.36, Vector3(0.95, 1.15, 0.95), pale)
			# 크게 뜬 하얀 눈 + 작은 빨간 눈동자
			for x in [-0.14, 0.14]:
				_sphere(_torso, Vector3(x, 2.6, -0.33), 0.1, Vector3(1, 1, 0.5), _clay(Color(1, 1, 1)))
			_eyes(_torso, 2.6, 0.39, _glow(Color(1.0, 0.05, 0.05)))
			_mouth(_torso, 2.32, 0.33, 0.5)  # 귀까지 찢어진 웃음
			_left_leg = _limb(self, Vector3(-0.18, 1.0, 0), 0.1, 1.0, coat)
			_right_leg = _limb(self, Vector3(0.18, 1.0, 0), 0.1, 1.0, coat)
			_left_arm = _limb(_torso, Vector3(-0.42, 2.05, 0), 0.08, 1.2, coat)
			_right_arm = _limb(_torso, Vector3(0.42, 2.05, 0), 0.08, 1.2, coat)
			# 오른손의 사슬낫
			var sickle := Node3D.new()
			sickle.position = Vector3(0, -1.15, 0)
			_right_arm.add_child(sickle)
			var handle := CylinderMesh.new()
			handle.top_radius = 0.03
			handle.bottom_radius = 0.03
			handle.height = 0.5
			_part(sickle, Vector3.ZERO, handle, _clay(Color(0.3, 0.2, 0.12)))
			var blade := TorusMesh.new()
			blade.inner_radius = 0.22
			blade.outer_radius = 0.27
			var b := _part(sickle, Vector3(0, -0.25, -0.2), blade, _clay(Color(0.7, 0.7, 0.75)))
			b.scale = Vector3(1, 1, 0.5)
			b.rotation.z = PI / 2.0
			var ring := TorusMesh.new()
			ring.inner_radius = 0.45
			ring.outer_radius = 0.52
			_part(_torso, Vector3(0, 1.05, 0), ring, _clay(Color(0.35, 0.35, 0.38)))  # 허리에 감은 쇠사슬
		"executioner":
			var skin := _clay(Color(0.5, 0.38, 0.3))
			var sack := _clay(Color(0.55, 0.45, 0.28))
			var leather := _clay(Color(0.2, 0.13, 0.08))
			_sphere(_torso, Vector3(0, 1.45, 0), 0.68, Vector3(1.05, 1.15, 0.85), skin)
			_box(_torso, Vector3(0, 1.2, -0.55), Vector3(0.9, 1.1, 0.06), leather)  # 가죽 앞치마
			# 망태기 머리 (꿰맨 자국 + 뚫린 눈구멍)
			_sphere(_torso, Vector3(0, 2.5, 0), 0.5, Vector3(1.0, 1.2, 1.0), sack)
			var stitch := _clay(Color(0.15, 0.1, 0.05))
			for i in 5:
				_box(_torso, Vector3(-0.2 + i * 0.1, 2.85, -0.38), Vector3(0.02, 0.12, 0.02), stitch)
			_box(_torso, Vector3(0, 2.1, -0.35), Vector3(0.6, 0.05, 0.05), stitch)  # 목에 묶은 끈
			_eyes(_torso, 2.55, 0.47, _glow(Color(1.0, 0.4, 0.05)))
			_left_leg = _limb(self, Vector3(-0.28, 0.8, 0), 0.18, 0.8, skin)
			_right_leg = _limb(self, Vector3(0.28, 0.8, 0), 0.18, 0.8, skin)
			_left_arm = _limb(_torso, Vector3(-0.7, 1.9, 0), 0.16, 1.1, skin)
			_right_arm = _limb(_torso, Vector3(0.7, 1.9, 0), 0.16, 1.1, skin)
			# 커다란 처형 도끼
			axe_in_hand = Node3D.new()
			axe_in_hand.position = Vector3(0, -1.05, 0)
			_right_arm.add_child(axe_in_hand)
			var h2 := CylinderMesh.new()
			h2.top_radius = 0.05
			h2.bottom_radius = 0.05
			h2.height = 1.6
			_part(axe_in_hand, Vector3(0, 0.2, 0), h2, _clay(Color(0.3, 0.2, 0.1)))
			var steel := _clay(Color(0.55, 0.56, 0.6))
			_box(axe_in_hand, Vector3(0, 0.85, -0.3), Vector3(0.08, 0.6, 0.6), steel)
			_box(axe_in_hand, Vector3(0, 0.85, -0.62), Vector3(0.06, 0.55, 0.06), _clay(Color(0.5, 0.05, 0.05)))  # 핏자국 날
			axe_in_hand.rotation.x = -PI / 2.0
		"diet":
			var hide := _clay(Color(0.45, 0.4, 0.47))
			var belly := _clay(Color(0.62, 0.52, 0.55))
			var gum := _clay(Color(0.65, 0.2, 0.25))
			# 뒤룩뒤룩 큰 몸
			_sphere(_torso, Vector3(0, 1.35, 0.1), 1.0, Vector3(1.15, 1.0, 1.1), hide)
			_sphere(_torso, Vector3(0, 1.15, -0.45), 0.75, Vector3(1.0, 0.9, 0.6), belly)
			# 하마 머리: 넓적한 주둥이
			_sphere(_torso, Vector3(0, 2.4, -0.3), 0.55, Vector3(1.1, 0.9, 1.0), hide)
			_sphere(_torso, Vector3(0, 2.2, -0.85), 0.5, Vector3(1.25, 0.7, 0.9), hide)
			for x in [-0.18, 0.18]:
				_sphere(_torso, Vector3(x, 2.42, -1.22), 0.06, Vector3.ONE, _clay(Color(0.1, 0.05, 0.05)))  # 콧구멍
				_sphere(_torso, Vector3(x * 1.8, 2.85, -0.2), 0.11, Vector3(1, 1, 0.5), hide)  # 작은 귀
			_eyes(_torso, 2.68, 0.8, _glow(Color(1.0, 0.75, 0.1)))
			# 쩍 벌어지는 입 (블랙홀 때 크게 벌어짐)
			mouth_jaw = Node3D.new()
			mouth_jaw.position = Vector3(0, 2.0, -0.7)
			_torso.add_child(mouth_jaw)
			_sphere(mouth_jaw, Vector3(0, -0.08, -0.25), 0.42, Vector3(1.2, 0.45, 0.9), hide)
			_sphere(mouth_jaw, Vector3(0, 0.02, -0.3), 0.36, Vector3(1.1, 0.25, 0.8), gum)
			var tooth := _clay(Color(0.95, 0.92, 0.8))
			for x in [-0.28, 0.28]:
				var t := PrismMesh.new()
				t.size = Vector3(0.1, 0.25, 0.1)
				_part(mouth_jaw, Vector3(x, 0.18, -0.55), t, tooth)  # 아랫니 송곳니
			_left_leg = _limb(self, Vector3(-0.45, 0.6, 0), 0.25, 0.6, hide)
			_right_leg = _limb(self, Vector3(0.45, 0.6, 0), 0.25, 0.6, hide)
			_left_arm = _limb(_torso, Vector3(-1.05, 1.7, -0.1), 0.2, 0.8, hide)
			_right_arm = _limb(_torso, Vector3(1.05, 1.7, -0.1), 0.2, 0.8, hide)
	_add_claws_to_arms()
	_arm_rest_x = _left_arm.rotation.x


## build() 마지막에 불러서 모든 술래에게 발톱을 달아 줌
func _add_claws_to_arms() -> void:
	var claw_mat := _clay(Color(0.12, 0.1, 0.1))
	var lengths := {"ghost": 1.5, "butcher": 1.05, "rat": 1.1, "spider": 0.45, "mannequin": 1.15, "hound": 1.0, "puppeteer": 1.8, "witch": 1.3, "psycho": 1.2, "executioner": 1.1, "diet": 0.8}
	for arm in [_left_arm, _right_arm]:
		if arm:
			_claws(arm, lengths.get(type, 1.0) - 0.1, claw_mat)


## 공격 모션: 팔을 머리 위로 치켜들었다가 앞으로 내려침
func attack(windup: float) -> void:
	_attack_dur = windup * 1.8  # 공격 속도에 맞춰 모션 길이도 함께 바뀜
	_attack_t = _attack_dur


func animate(delta: float, speed: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	if _attack_t > 0.0:
		_attack_t -= delta
		var p := 1.0 - _attack_t / _attack_dur
		var raise := 0.55  # 앞 55%는 치켜들기, 나머지는 내려치기
		var ang := lerpf(_arm_rest_x, -2.8, p / raise) if p < raise else lerpf(-2.8, -0.8, minf(1.0, (p - raise) / 0.25))
		_left_arm.rotation.x = ang
		_right_arm.rotation.x = ang
		_torso.rotation.x = -0.05 if p < raise else -0.45
		_flicker_eyes(delta)
		if _attack_t <= 0.0:
			_left_arm.rotation.x = _arm_rest_x
			_right_arm.rotation.x = _arm_rest_x
		return
	var amount := clampf(speed / 5.0, 0.0, 1.6)
	_phase += delta * (4.0 + speed * 1.1)
	var swing := sin(_phase) * 0.6 * amount
	if type == "ghost" or type == "witch":
		_torso.position.y = 0.15 + sin(t * 2.2) * 0.12  # 둥둥 떠다님
		_torso.rotation.x = -0.15 - 0.2 * amount
		_flicker_eyes(delta)
		return
	if type == "spider":
		for i in _spider_legs.size():
			var leg := _spider_legs[i]
			leg.rotation.x = sin(_phase * 1.5 + i * 1.3) * 0.5 * amount
		_left_arm.rotation.x = -0.6 + sin(t * 6.0) * 0.2
		_right_arm.rotation.x = -0.6 - sin(t * 6.0) * 0.2
		_torso.position.y = absf(sin(_phase * 1.5)) * 0.05 * amount
		_flicker_eyes(delta)
		return
	if _left_leg:
		_left_leg.rotation.x = swing
		_right_leg.rotation.x = -swing
	_left_arm.rotation.x = -swing * 0.8
	_right_arm.rotation.x = swing * 0.8 if type != "butcher" and type != "executioner" else -0.3 + swing * 0.3
	_torso.position.y = absf(sin(_phase)) * 0.06 * amount
	_torso.rotation.x = 0.0 if type == "hound" else -0.28  # 구부정하게 앞으로 숙임
	_flicker_eyes(delta)
	if _tail:
		_tail.rotation.y = sin(t * 4.0) * 0.4


## 하마 입 벌리기 (0 = 다물기, 1 = 쩍 벌림)
func set_mouth_open(t: float) -> void:
	if mouth_jaw:
		mouth_jaw.rotation.x = 0.9 * t
		mouth_jaw.scale = Vector3.ONE * (1.0 + 0.5 * t)


## 폭주: 눈이 새빨갛게 더 밝아짐
func set_rage() -> void:
	for m in _eye_mats:
		m.albedo_color = Color(1.0, 0.05, 0.05)
		m.emission = Color(1.0, 0.0, 0.0)


## 봉인됐을 때 회색으로
func set_tint(color: Color) -> void:
	for m in _mats:
		m.albedo_color = Color(color.r, color.g, color.b, m.albedo_color.a)
		m.emission_enabled = false


# ---------------------------------------------------------------- 도형 도우미

func _clay(c: Color, alpha := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.8
	m.rim_enabled = true
	m.rim = 0.3
	_mats.append(m)
	return m


func _glow(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 3.0
	_mats.append(m)
	return m


## 눈이 지직거리며 깜빡임 (가끔 완전히 꺼졌다 켜짐)
func _flicker_eyes(delta: float) -> void:
	_blink -= delta
	var energy := 3.0 + randf_range(-0.8, 0.8)
	if _blink <= 0.0:
		_blink = randf_range(1.5, 4.0)
	elif _blink < 0.12:
		energy = 0.0
	for m in _eye_mats:
		m.emission_energy_multiplier = energy


## 찢어진 입 + 뾰족한 이빨 (얼굴 앞쪽 -Z)
func _mouth(parent: Node3D, height: float, front: float, width: float) -> void:
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.05, 0.0, 0.0)
	dark.emission_enabled = true
	dark.emission = Color(0.25, 0.0, 0.0)
	_mats.append(dark)
	_sphere(parent, Vector3(0, height, -front), width * 0.5, Vector3(1.0, 0.32, 0.3), dark)
	var tooth_mat := _clay(Color(0.95, 0.93, 0.85))
	var count := 7
	for i in count:
		var x := lerpf(-width * 0.42, width * 0.42, float(i) / (count - 1))
		var tooth := PrismMesh.new()
		tooth.size = Vector3(0.045, 0.07, 0.03)
		var top := _part(parent, Vector3(x, height + 0.035, -front - 0.07), tooth, tooth_mat)
		top.rotation.z = PI  # 윗니는 아래를 향함
		_part(parent, Vector3(x + width * 0.03, height - 0.035, -front - 0.07), tooth, tooth_mat)


## 팔 끝의 긴 발톱
func _claws(arm: Node3D, length: float, mat: Material) -> void:
	for x in [-0.05, 0.0, 0.05]:
		var claw := PrismMesh.new()
		claw.size = Vector3(0.03, 0.22, 0.03)
		var c := _part(arm, Vector3(x, -length - 0.02, -0.02), claw, mat)
		c.rotation.z = PI


func _eyes(parent: Node3D, height: float, front: float, mat: Material) -> void:
	if mat is StandardMaterial3D and not _eye_mats.has(mat):
		_eye_mats.append(mat)
	for x in [-0.17, 0.17]:
		_sphere(parent, Vector3(x, height, -front), 0.08, Vector3(1.0, 0.7, 0.5), mat)


func _part(parent: Node3D, pos: Vector3, mesh: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
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


func _limb(parent: Node3D, joint: Vector3, radius: float, length: float, mat: Material) -> Node3D:
	var pivot := Node3D.new()
	pivot.position = joint
	parent.add_child(pivot)
	var c := CapsuleMesh.new()
	c.radius = radius
	c.height = length
	_part(pivot, Vector3(0, -length / 2.0 + radius * 0.5, 0), c, mat)
	return pivot
