class_name Cosmetics
extends RefCounted
## 치장 아이템 (상점에서 사서 착용). 4종류: 눈 / 머리 / 옷 / 장신구
## 모든 아이템은 점토 인형 몸(clay_body.gd)에 도형을 붙여서 만듭니다.
## ITEMS 표에 한 줄 추가하고, 모양이 새 종류면 _build_* 의 match 에 한 줄 추가하면 됩니다.
##
## 몸 좌표 (clay_body.gd, 앞쪽 +Z):
##   머리 중심 (0, 1.28, 0) 반지름 0.4  /  몸통 중심 (0, 0.66, 0) 반지름 0.32 (세로 1.25배)
##   팔 관절 (±0.31, 0.86) 에서 아래로 0.4  /  손끝은 팔 노드 기준 (0, -0.42, 0)

const SLOTS := ["eyes", "hair", "outfit", "acc"]
const SLOT_NAMES := {"eyes": "눈", "hair": "머리", "outfit": "옷", "acc": "장신구"}

## [아이디, 이름, 칸, 가격, 모양 종류, 색1, 색2]
const ITEMS := [
	# ---------------------------------------------------------------- 눈 (26)
	["eyes_basic", "기본 눈", "eyes", 0, "basic", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_sparkle", "반짝 눈", "eyes", 150, "sparkle", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_sleepy", "졸린 눈", "eyes", 150, "sleepy", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_angry", "화난 눈", "eyes", 150, "angry", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_sad", "시무룩 눈", "eyes", 150, "sad", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_happy", "웃는 눈 ^^", "eyes", 150, "happy", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_dot", "점 눈", "eyes", 100, "dot", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_star", "별 눈", "eyes", 400, "star", Color(1.0, 0.82, 0.15), Color.WHITE],
	["eyes_heart", "하트 눈", "eyes", 400, "heart", Color(1.0, 0.3, 0.45), Color.WHITE],
	["eyes_cross", "X X 눈", "eyes", 250, "cross", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_spiral", "어질어질 눈", "eyes", 300, "spiral", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_cat", "고양이 눈", "eyes", 300, "cat", Color(0.95, 0.8, 0.2), Color(0.05, 0.05, 0.05)],
	["eyes_glow_blue", "푸른 빛 눈", "eyes", 600, "glow", Color(0.3, 0.75, 1.0), Color.WHITE],
	["eyes_glow_red", "붉은 빛 눈", "eyes", 600, "glow", Color(1.0, 0.2, 0.15), Color.WHITE],
	["eyes_glow_green", "초록 빛 눈", "eyes", 600, "glow", Color(0.3, 1.0, 0.4), Color.WHITE],
	["eyes_wink", "윙크", "eyes", 250, "wink", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_teary", "글썽 눈", "eyes", 250, "teary", Color(0.07, 0.05, 0.09), Color(0.5, 0.8, 1.0)],
	["eyes_cyclops", "외눈", "eyes", 500, "cyclops", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_button", "단추 눈", "eyes", 350, "button", Color(0.35, 0.2, 0.12), Color(0.15, 0.08, 0.05)],
	["eyes_robot", "로봇 눈", "eyes", 500, "robot", Color(0.2, 1.0, 0.9), Color(0.08, 0.08, 0.1)],
	["eyes_anime_blue", "초롱 눈 (파랑)", "eyes", 400, "anime", Color(0.2, 0.45, 0.95), Color.WHITE],
	["eyes_anime_purple", "초롱 눈 (보라)", "eyes", 400, "anime", Color(0.6, 0.3, 0.9), Color.WHITE],
	["eyes_tiny", "콩알 눈", "eyes", 100, "tiny", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_derp", "엉뚱한 눈", "eyes", 300, "derp", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_lashes", "속눈썹 눈", "eyes", 250, "lashes", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_shades", "선글라스 눈", "eyes", 350, "shades", Color(0.05, 0.05, 0.06), Color(0.4, 0.5, 0.6)],
	# ---------------------------------------------------------------- 머리 (37)
	["hair_none", "없음", "hair", 0, "none", Color.WHITE, Color.WHITE],
	["hair_spiky_black", "뾰족 머리 (검정)", "hair", 200, "spiky", Color(0.12, 0.1, 0.1), Color.WHITE],
	["hair_spiky_blonde", "뾰족 머리 (금발)", "hair", 200, "spiky", Color(0.95, 0.78, 0.35), Color.WHITE],
	["hair_bowl_brown", "바가지 머리 (갈색)", "hair", 150, "bowl", Color(0.4, 0.24, 0.12), Color.WHITE],
	["hair_bowl_black", "바가지 머리 (검정)", "hair", 150, "bowl", Color(0.12, 0.1, 0.1), Color.WHITE],
	["hair_curly_brown", "곱슬 머리 (갈색)", "hair", 250, "curly", Color(0.45, 0.28, 0.15), Color.WHITE],
	["hair_curly_pink", "곱슬 머리 (분홍)", "hair", 250, "curly", Color(1.0, 0.55, 0.75), Color.WHITE],
	["hair_afro", "아프로", "hair", 350, "afro", Color(0.15, 0.1, 0.08), Color.WHITE],
	["hair_mohawk", "닭벼슬 머리", "hair", 300, "mohawk", Color(0.3, 0.9, 0.3), Color.WHITE],
	["hair_ponytail", "포니테일", "hair", 250, "ponytail", Color(0.55, 0.32, 0.15), Color(1.0, 0.4, 0.5)],
	["hair_twintail", "양갈래", "hair", 300, "twintail", Color(0.95, 0.85, 0.5), Color(0.4, 0.6, 1.0)],
	["hair_bun", "똥머리", "hair", 250, "bun", Color(0.15, 0.1, 0.08), Color(1.0, 0.85, 0.2)],
	["hair_long", "긴 생머리", "hair", 300, "long", Color(0.2, 0.12, 0.08), Color.WHITE],
	["hat_cap_red", "야구 모자 (빨강)", "hair", 200, "cap", Color(0.85, 0.15, 0.15), Color.WHITE],
	["hat_cap_blue", "야구 모자 (파랑)", "hair", 200, "cap", Color(0.15, 0.35, 0.85), Color.WHITE],
	["hat_beanie_yellow", "털모자 (노랑)", "hair", 200, "beanie", Color(1.0, 0.8, 0.2), Color.WHITE],
	["hat_beanie_green", "털모자 (초록)", "hair", 200, "beanie", Color(0.25, 0.6, 0.35), Color(0.95, 0.95, 0.9)],
	["hat_top", "실크햇", "hair", 450, "tophat", Color(0.08, 0.08, 0.1), Color(0.75, 0.1, 0.15)],
	["hat_witch", "마녀 모자", "hair", 450, "witch", Color(0.25, 0.1, 0.35), Color(0.9, 0.7, 0.2)],
	["hat_crown", "왕관", "hair", 900, "crown", Color(1.0, 0.78, 0.2), Color(0.9, 0.15, 0.3)],
	["ears_bunny", "토끼 귀", "hair", 350, "bunny", Color(0.98, 0.95, 0.95), Color(1.0, 0.6, 0.7)],
	["ears_cat", "고양이 귀", "hair", 350, "catears", Color(0.2, 0.18, 0.2), Color(1.0, 0.6, 0.7)],
	["ears_bear", "곰 귀", "hair", 350, "bearears", Color(0.5, 0.32, 0.18), Color(0.85, 0.65, 0.45)],
	["horns_devil", "악마 뿔", "hair", 500, "horns", Color(0.85, 0.12, 0.12), Color.WHITE],
	["halo", "천사 링", "hair", 600, "halo", Color(1.0, 0.9, 0.4), Color.WHITE],
	["hat_chef", "요리사 모자", "hair", 300, "chef", Color(0.97, 0.97, 0.97), Color.WHITE],
	["hat_party", "파티 모자", "hair", 250, "party", Color(0.3, 0.7, 1.0), Color(1.0, 0.4, 0.6)],
	["hat_propeller", "프로펠러 모자", "hair", 500, "propeller", Color(1.0, 0.85, 0.2), Color(0.2, 0.5, 1.0)],
	["hat_viking", "바이킹 투구", "hair", 550, "viking", Color(0.6, 0.6, 0.62), Color(0.95, 0.92, 0.8)],
	["hat_flower", "꽃 화관", "hair", 400, "flowercrown", Color(1.0, 0.55, 0.7), Color(0.3, 0.7, 0.35)],
	["hat_antenna", "외계인 더듬이", "hair", 350, "antenna", Color(0.3, 1.0, 0.4), Color(0.2, 0.2, 0.22)],
	["hat_sprout", "새싹", "hair", 150, "sprout", Color(0.35, 0.8, 0.3), Color.WHITE],
	["hat_pirate", "해적 모자", "hair", 450, "pirate", Color(0.1, 0.08, 0.08), Color(0.95, 0.95, 0.9)],
	["hat_santa", "산타 모자", "hair", 400, "santa", Color(0.85, 0.1, 0.12), Color(0.98, 0.98, 0.98)],
	["hat_frog", "개구리 모자", "hair", 450, "frog", Color(0.35, 0.8, 0.3), Color.WHITE],
	["hat_mushroom", "버섯 모자", "hair", 400, "mushroom", Color(0.9, 0.15, 0.15), Color(0.98, 0.98, 0.95)],
	["hat_grad", "학사모", "hair", 350, "grad", Color(0.1, 0.1, 0.12), Color(1.0, 0.8, 0.2)],
	# ---------------------------------------------------------------- 옷 (37)
	["outfit_none", "없음", "outfit", 0, "none", Color.WHITE, Color.WHITE],
	["tee_white", "티셔츠 (하양)", "outfit", 100, "tee", Color(0.95, 0.95, 0.93), Color(0.25, 0.3, 0.45)],
	["tee_red", "티셔츠 (빨강)", "outfit", 100, "tee", Color(0.85, 0.2, 0.2), Color(0.2, 0.22, 0.3)],
	["tee_blue", "티셔츠 (파랑)", "outfit", 100, "tee", Color(0.2, 0.4, 0.85), Color(0.2, 0.2, 0.25)],
	["tee_yellow", "티셔츠 (노랑)", "outfit", 100, "tee", Color(1.0, 0.82, 0.25), Color(0.3, 0.3, 0.35)],
	["tee_black", "티셔츠 (검정)", "outfit", 100, "tee", Color(0.12, 0.12, 0.14), Color(0.35, 0.35, 0.4)],
	["sweater_stripe", "줄무늬 스웨터", "outfit", 250, "stripes", Color(0.9, 0.25, 0.25), Color(0.95, 0.92, 0.85)],
	["sweater_navy", "줄무늬 스웨터 (남색)", "outfit", 250, "stripes", Color(0.15, 0.2, 0.45), Color(0.95, 0.95, 0.95)],
	["hoodie_gray", "후드티 (회색)", "outfit", 300, "hoodie", Color(0.55, 0.56, 0.6), Color(0.2, 0.2, 0.25)],
	["hoodie_pink", "후드티 (분홍)", "outfit", 300, "hoodie", Color(1.0, 0.6, 0.75), Color(0.3, 0.25, 0.35)],
	["overalls_denim", "멜빵바지 (청)", "outfit", 300, "overalls", Color(0.25, 0.4, 0.7), Color(0.95, 0.85, 0.3)],
	["overalls_red", "멜빵바지 (빨강)", "outfit", 300, "overalls", Color(0.8, 0.2, 0.2), Color(0.95, 0.95, 0.9)],
	["uniform_school", "교복", "outfit", 400, "school", Color(0.95, 0.95, 0.95), Color(0.15, 0.2, 0.4)],
	["uniform_sailor", "세일러복", "outfit", 400, "sailor", Color(0.97, 0.97, 0.97), Color(0.15, 0.2, 0.45)],
	["tuxedo", "턱시도", "outfit", 600, "tuxedo", Color(0.08, 0.08, 0.1), Color(0.97, 0.97, 0.97)],
	["raincoat", "노란 우비", "outfit", 350, "raincoat", Color(1.0, 0.85, 0.15), Color(0.2, 0.2, 0.2)],
	["gown_hospital", "환자복", "outfit", 250, "gown", Color(0.65, 0.8, 0.9), Color(0.4, 0.55, 0.7)],
	["coat_doctor", "의사 가운", "outfit", 450, "labcoat", Color(0.97, 0.97, 0.97), Color(0.3, 0.6, 0.85)],
	["vest_police", "경찰 조끼", "outfit", 450, "police", Color(0.12, 0.15, 0.3), Color(1.0, 0.8, 0.2)],
	["suit_astro", "우주복", "outfit", 700, "astro", Color(0.95, 0.95, 0.97), Color(0.9, 0.35, 0.2)],
	["suit_ninja", "닌자복", "outfit", 600, "ninja", Color(0.08, 0.08, 0.1), Color(0.85, 0.12, 0.12)],
	["hero_red", "히어로 (빨강 망토)", "outfit", 700, "hero", Color(0.2, 0.35, 0.85), Color(0.9, 0.15, 0.15)],
	["hero_blue", "히어로 (파랑 망토)", "outfit", 700, "hero", Color(0.15, 0.15, 0.18), Color(0.2, 0.4, 0.95)],
	["kimono", "기모노", "outfit", 500, "kimono", Color(0.85, 0.2, 0.3), Color(0.98, 0.85, 0.4)],
	["jersey", "농구 저지", "outfit", 350, "jersey", Color(0.95, 0.5, 0.1), Color(0.98, 0.98, 0.98)],
	["apron", "앞치마", "outfit", 200, "apron", Color(0.95, 0.75, 0.8), Color(0.98, 0.98, 0.98)],
	["armor_knight", "기사 갑옷", "outfit", 900, "armor", Color(0.75, 0.77, 0.8), Color(0.85, 0.7, 0.2)],
	["pajamas", "별무늬 잠옷", "outfit", 300, "pajamas", Color(0.35, 0.45, 0.85), Color(1.0, 0.9, 0.4)],
	["tutu", "발레 튜튜", "outfit", 350, "tutu", Color(1.0, 0.7, 0.85), Color(1.0, 0.9, 0.95)],
	["costume_bee", "꿀벌 옷", "outfit", 550, "bee", Color(1.0, 0.82, 0.15), Color(0.1, 0.08, 0.06)],
	["costume_pumpkin", "호박 옷", "outfit", 550, "pumpkin", Color(1.0, 0.5, 0.1), Color(0.25, 0.5, 0.2)],
	["costume_dino", "공룡 옷", "outfit", 650, "dino", Color(0.35, 0.7, 0.35), Color(0.95, 0.85, 0.3)],
	["costume_penguin", "펭귄 옷", "outfit", 550, "penguin", Color(0.1, 0.1, 0.13), Color(0.97, 0.97, 0.97)],
	["scarf_red", "목도리 (빨강)", "outfit", 150, "scarf", Color(0.85, 0.15, 0.15), Color(0.95, 0.9, 0.8)],
	["scarf_blue", "목도리 (파랑)", "outfit", 150, "scarf", Color(0.2, 0.4, 0.85), Color(0.95, 0.95, 0.95)],
	["cape_vampire", "뱀파이어 망토", "outfit", 600, "vampire", Color(0.08, 0.06, 0.08), Color(0.7, 0.05, 0.1)],
	["bib_baby", "아기 턱받이", "outfit", 150, "bib", Color(0.6, 0.85, 1.0), Color(1.0, 1.0, 1.0)],
	# ---------------------------------------------------------------- 장신구 (30)
	["acc_none", "없음", "acc", 0, "none", Color.WHITE, Color.WHITE],
	["glasses_round", "동그란 안경", "acc", 200, "glasses", Color(0.15, 0.12, 0.1), Color(0.8, 0.9, 1.0)],
	["glasses_sun", "선글라스", "acc", 300, "sunglasses", Color(0.05, 0.05, 0.06), Color(0.2, 0.25, 0.3)],
	["glasses_heart", "하트 안경", "acc", 350, "heartglasses", Color(1.0, 0.3, 0.5), Color(1.0, 0.6, 0.7)],
	["glasses_star", "별 안경", "acc", 350, "starglasses", Color(1.0, 0.8, 0.2), Color(1.0, 0.95, 0.6)],
	["monocle", "외알 안경", "acc", 400, "monocle", Color(1.0, 0.8, 0.3), Color(0.8, 0.9, 1.0)],
	["mustache", "콧수염", "acc", 250, "mustache", Color(0.12, 0.08, 0.06), Color.WHITE],
	["beard", "산타 수염", "acc", 300, "beard", Color(0.97, 0.97, 0.97), Color.WHITE],
	["bandage", "반창고", "acc", 100, "bandage", Color(0.95, 0.8, 0.6), Color(0.8, 0.6, 0.45)],
	["blush", "볼터치", "acc", 100, "blush", Color(1.0, 0.45, 0.52), Color.WHITE],
	["mask_surgical", "마스크", "acc", 150, "mask", Color(0.8, 0.92, 1.0), Color(0.95, 0.95, 0.95)],
	["eyepatch", "안대", "acc", 300, "eyepatch", Color(0.06, 0.06, 0.07), Color.WHITE],
	["headphones", "헤드폰", "acc", 400, "headphones", Color(0.15, 0.15, 0.18), Color(1.0, 0.3, 0.5)],
	["backpack", "가방", "acc", 250, "backpack", Color(0.9, 0.4, 0.2), Color(0.3, 0.25, 0.2)],
	["wings_angel", "천사 날개", "acc", 800, "wings", Color(0.98, 0.98, 1.0), Color(0.9, 0.95, 1.0)],
	["wings_devil", "악마 날개", "acc", 800, "batwings", Color(0.5, 0.05, 0.08), Color(0.2, 0.02, 0.04)],
	["wings_bat", "박쥐 날개", "acc", 700, "batwings", Color(0.15, 0.12, 0.18), Color(0.05, 0.04, 0.06)],
	["wings_butterfly", "나비 날개", "acc", 800, "butterfly", Color(0.4, 0.7, 1.0), Color(1.0, 0.6, 0.85)],
	["tail_cat", "고양이 꼬리", "acc", 350, "cattail", Color(0.2, 0.18, 0.2), Color.WHITE],
	["tail_dino", "공룡 꼬리", "acc", 450, "dinotail", Color(0.35, 0.7, 0.35), Color(0.95, 0.85, 0.3)],
	["balloon", "풍선", "acc", 300, "balloon", Color(1.0, 0.25, 0.35), Color(0.95, 0.95, 0.95)],
	["lollipop", "막대사탕", "acc", 200, "lollipop", Color(1.0, 0.4, 0.7), Color(0.98, 0.98, 0.98)],
	["teddy", "곰인형", "acc", 450, "teddy", Color(0.65, 0.42, 0.25), Color(0.9, 0.75, 0.55)],
	["flower_hand", "꽃 한 송이", "acc", 200, "flower", Color(1.0, 0.85, 0.2), Color(0.3, 0.7, 0.3)],
	["umbrella", "우산", "acc", 400, "umbrella", Color(0.3, 0.6, 1.0), Color(0.95, 0.95, 0.95)],
	["guitar", "기타", "acc", 600, "guitar", Color(0.75, 0.4, 0.15), Color(0.15, 0.1, 0.08)],
	["necklace", "금 목걸이", "acc", 500, "necklace", Color(1.0, 0.8, 0.25), Color(0.3, 0.8, 1.0)],
	["earrings", "귀걸이", "acc", 250, "earrings", Color(1.0, 0.8, 0.3), Color(1.0, 0.4, 0.6)],
	["bowtie", "나비넥타이", "acc", 200, "bowtie", Color(0.85, 0.15, 0.2), Color(0.6, 0.08, 0.12)],
	["cheese_pizza", "피자 한 조각", "acc", 250, "pizza", Color(1.0, 0.82, 0.35), Color(0.85, 0.25, 0.15)],
]

const DEFAULTS := {"eyes": "eyes_basic", "hair": "hair_none", "outfit": "outfit_none", "acc": "acc_none"}


static func info(id: String) -> Array:
	for it in ITEMS:
		if it[0] == id:
			return it
	return []


static func items_in(slot: String) -> Array:
	var out := []
	for it in ITEMS:
		if it[2] == slot:
			out.append(it)
	return out


## 몸에 치장 입히기 (equip = {"eyes": id, "hair": id, ...}). 비어 있는 칸은 기본값
static func apply(body: Node3D, equip: Dictionary) -> void:
	var b := Builder.new()
	b.body = body
	for slot in SLOTS:
		var id: String = equip.get(slot, DEFAULTS[slot])
		var it := info(id)
		if it.is_empty():
			it = info(DEFAULTS[slot])
		b.build(it)


# ================================================================ 모양 만들기

class Builder:
	var body: Node3D
	var torso: Node3D
	var c1: Color
	var c2: Color
	var _mats := {}

	func build(it: Array) -> void:
		torso = body.get("_torso")
		c1 = it[5]
		c2 = it[6]
		var kind: String = it[4]
		match it[2]:
			"eyes": _eyes(kind)
			"hair": _hair(kind)
			"outfit": _outfit(kind)
			"acc": _acc(kind)

	# ---------------------------------------------------------------- 재질·도형 도우미

	func clay(c: Color) -> StandardMaterial3D:
		var key := c.to_html()
		if not _mats.has(key):
			_mats[key] = body.call("_clay", c)
		return _mats[key]

	func flat(c: Color, unshaded := false) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.35
		if unshaded:
			m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		return m

	func glow(c: Color, e := 2.0) -> StandardMaterial3D:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = e
		return m

	func add(parent: Node3D, mesh: Mesh, mat: Material, pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> MeshInstance3D:
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.position = pos
		mi.rotation = rot
		mi.scale = scl
		mi.layers = 2  # 손전등이 내 몸을 비추지 않게 (player.gd light_cull_mask)
		parent.add_child(mi)
		mi.add_to_group("cosmetic")
		return mi

	func sph(parent: Node3D, pos: Vector3, r: float, mat: Material, scl := Vector3.ONE, hemi := false) -> MeshInstance3D:
		var s := SphereMesh.new()
		s.radius = r
		s.height = r * (1.0 if hemi else 2.0)
		s.is_hemisphere = hemi
		s.radial_segments = 24
		s.rings = 12
		return add(parent, s, mat, pos, Vector3.ZERO, scl)

	func box(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
		var b := BoxMesh.new()
		b.size = size
		return add(parent, b, mat, pos, rot)

	func cyl(parent: Node3D, pos: Vector3, rt: float, rb: float, h: float, mat: Material, rot := Vector3.ZERO, seg := 20) -> MeshInstance3D:
		var c := CylinderMesh.new()
		c.top_radius = rt
		c.bottom_radius = rb
		c.height = h
		c.radial_segments = seg
		return add(parent, c, mat, pos, rot)

	func torus(parent: Node3D, pos: Vector3, inner: float, outer: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
		var t := TorusMesh.new()
		t.inner_radius = inner
		t.outer_radius = outer
		t.rings = 24
		t.ring_segments = 10
		return add(parent, t, mat, pos, rot)

	func cap(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
		var c := CapsuleMesh.new()
		c.radius = r
		c.height = h
		return add(parent, c, mat, pos, rot)

	func prism(parent: Node3D, pos: Vector3, size: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
		var p := PrismMesh.new()
		p.size = size
		return add(parent, p, mat, pos, rot)

	func cone(parent: Node3D, pos: Vector3, r: float, h: float, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
		return cyl(parent, pos, 0.001, r, h, mat, rot)

	## 머리 표면의 점 (yaw: 좌우 각도, pitch: 위아래 각도, 앞이 0)
	func head_pt(yaw: float, pitch: float, out := 0.0) -> Vector3:
		var r := 0.4 + out
		return Vector3(sin(yaw) * cos(pitch) * r, 1.28 + sin(pitch) * r, cos(yaw) * cos(pitch) * r)

	func arm(right: bool) -> Node3D:
		return body.get("_right_arm" if right else "_left_arm")

	func spin(node: Node3D, kind: String) -> void:
		var list: Array = body.get("_cos_anim")
		list.append([node, kind])

	# ---------------------------------------------------------------- 눈

	func _eye_pair(r: float, scl: Vector3, mat: Material, x := 0.135, y := 1.27, z := 0.35) -> Array:
		var out := []
		for s in [-1.0, 1.0]:
			out.append(sph(torso, Vector3(x * s, y, z), r, mat, scl))
		return out

	func _shine(x := 0.135, y := 1.27, big := 1.0) -> void:
		var w := flat(Color.WHITE, true)
		for s in [-1.0, 1.0]:
			sph(torso, Vector3(x * s + 0.026, y + 0.04, 0.386), 0.023 * big, w, Vector3(1, 1, 0.5))
			sph(torso, Vector3(x * s - 0.02, y - 0.025, 0.39), 0.011 * big, w, Vector3(1, 1, 0.5))

	func _brows(tilt: float, y := 1.39) -> void:
		var m := clay(Color(0.1, 0.07, 0.08))
		for s in [-1.0, 1.0]:
			cap(torso, Vector3(0.13 * s, y, 0.36), 0.016, 0.11, m, Vector3(0.0, 0.0, PI / 2.0 + tilt * s))

	func _eyes(kind: String) -> void:
		var dark := flat(c1)
		match kind:
			"basic":
				_eye_pair(0.08, Vector3(0.85, 1.15, 0.45), dark)
				_shine()
			"sparkle":
				_eye_pair(0.1, Vector3(0.85, 1.15, 0.45), dark)
				_shine(0.135, 1.27, 1.6)
				var w := flat(Color.WHITE, true)
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s - 0.03, 1.32, 0.395), 0.012, w, Vector3(1, 1, 0.5))
			"sleepy":
				_eye_pair(0.08, Vector3(0.85, 1.15, 0.45), dark)
				var lid := clay(body.get("_mat").albedo_color)
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.29, 0.356), 0.085, lid, Vector3(1.05, 0.65, 0.5))
			"angry":
				_eye_pair(0.08, Vector3(0.9, 1.0, 0.45), dark)
				_shine()
				_brows(-0.45, 1.37)
			"sad":
				_eye_pair(0.08, Vector3(0.85, 1.15, 0.45), dark)
				_shine()
				_brows(0.4, 1.385)
			"happy":
				for s in [-1.0, 1.0]:
					for k in [-1.0, 1.0]:
						cap(torso, Vector3(0.135 * s + 0.03 * k, 1.28, 0.375), 0.016, 0.085, dark, Vector3(0, 0, -0.75 * k))
			"dot":
				_eye_pair(0.04, Vector3(1, 1, 0.5), dark, 0.12, 1.28, 0.385)
			"tiny":
				_eye_pair(0.028, Vector3(1, 1, 0.5), dark, 0.17, 1.27, 0.37)
			"star":
				var star := StarMesh.make()
				for s in [-1.0, 1.0]:
					add(torso, star, glow(c1, 0.8), Vector3(0.135 * s, 1.27, 0.392), Vector3(0, 0, 0), Vector3.ONE * 0.075)
			"heart":
				for s in [-1.0, 1.0]:
					var h := Node3D.new()
					h.position = Vector3(0.135 * s, 1.27, 0.38)
					torso.add_child(h)
					sph(h, Vector3(-0.03, 0.02, 0), 0.04, glow(c1, 0.5), Vector3(1, 1, 0.5))
					sph(h, Vector3(0.03, 0.02, 0), 0.04, glow(c1, 0.5), Vector3(1, 1, 0.5))
					prism(h, Vector3(0, -0.035, 0), Vector3(0.12, 0.08, 0.03), glow(c1, 0.5), Vector3(0, 0, PI))
			"cross":
				for s in [-1.0, 1.0]:
					for k in [-1.0, 1.0]:
						cap(torso, Vector3(0.135 * s, 1.27, 0.38), 0.015, 0.13, dark, Vector3(0, 0, 0.78 * k))
			"spiral":
				for s in [-1.0, 1.0]:
					for r in [0.025, 0.05, 0.075]:
						torus(torso, Vector3(0.135 * s, 1.27, 0.375), r - 0.008, r, dark, Vector3(PI / 2.0, 0, 0))
			"cat":
				_eye_pair(0.085, Vector3(0.9, 1.1, 0.45), flat(c1))
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.27, 0.392), 0.07, flat(c2), Vector3(0.22, 1.0, 0.3))
			"glow":
				_eye_pair(0.08, Vector3(0.85, 1.15, 0.45), glow(c1, 3.0))
				var l := OmniLight3D.new()
				l.light_color = c1
				l.omni_range = 0.9
				l.light_energy = 0.6
				l.position = Vector3(0, 1.27, 0.5)
				torso.add_child(l)
			"wink":
				sph(torso, Vector3(-0.135, 1.27, 0.35), 0.08, dark, Vector3(0.85, 1.15, 0.45))
				sph(torso, Vector3(-0.109, 1.31, 0.386), 0.023, flat(Color.WHITE, true), Vector3(1, 1, 0.5))
				for k in [-1.0, 1.0]:
					cap(torso, Vector3(0.135 + 0.03 * k, 1.27, 0.375), 0.016, 0.085, dark, Vector3(0, 0, 0.75 * k))
			"teary":
				_eye_pair(0.085, Vector3(0.85, 1.15, 0.45), dark)
				_shine(0.135, 1.27, 1.4)
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.15 * s, 1.17, 0.37), 0.025, glow(c2, 0.6), Vector3(0.8, 1.3, 0.6))
			"cyclops":
				sph(torso, Vector3(0, 1.29, 0.33), 0.15, flat(Color.WHITE), Vector3(1, 1, 0.5))
				sph(torso, Vector3(0, 1.29, 0.39), 0.08, dark, Vector3(1, 1, 0.4))
				sph(torso, Vector3(0.03, 1.32, 0.42), 0.022, flat(Color.WHITE, true), Vector3(1, 1, 0.5))
			"button":
				for s in [-1.0, 1.0]:
					cyl(torso, Vector3(0.135 * s, 1.27, 0.38), 0.075, 0.075, 0.03, clay(c1), Vector3(PI / 2.0 - 0.35, 0, 0))
					for hx in [-0.02, 0.02]:
						for hy in [-0.02, 0.02]:
							sph(torso, Vector3(0.135 * s + hx, 1.27 + hy, 0.398), 0.011, flat(c2))
			"robot":
				box(torso, Vector3(0, 1.28, 0.36), Vector3(0.44, 0.12, 0.08), flat(c2), Vector3(-0.1, 0, 0))
				box(torso, Vector3(0, 1.28, 0.401), Vector3(0.38, 0.04, 0.01), glow(c1, 3.0), Vector3(-0.1, 0, 0))
			"anime":
				_eye_pair(0.1, Vector3(0.8, 1.3, 0.45), flat(Color(0.05, 0.04, 0.07)))
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.25, 0.385), 0.06, glow(c1, 0.4), Vector3(0.9, 1.2, 0.4))
				_shine(0.135, 1.29, 1.4)
			"derp":
				sph(torso, Vector3(-0.13, 1.29, 0.35), 0.1, flat(Color.WHITE), Vector3(1, 1, 0.45))
				sph(torso, Vector3(-0.1, 1.31, 0.395), 0.035, dark, Vector3(1, 1, 0.5))
				sph(torso, Vector3(0.14, 1.25, 0.355), 0.065, flat(Color.WHITE), Vector3(1, 1, 0.45))
				sph(torso, Vector3(0.155, 1.23, 0.39), 0.028, dark, Vector3(1, 1, 0.5))
			"lashes":
				_eye_pair(0.08, Vector3(0.85, 1.15, 0.45), dark)
				_shine()
				for s in [-1.0, 1.0]:
					for k in 3:
						cap(torso, Vector3(0.135 * s + (0.03 + k * 0.025) * s, 1.36 - k * 0.012, 0.36), 0.007, 0.05, dark, Vector3(0, 0, -s * (0.4 + k * 0.35)))
			"shades":
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.28, 0.36), 0.095, flat(c1), Vector3(1.1, 0.75, 0.45))
					sph(torso, Vector3(0.135 * s + 0.03, 1.31, 0.395), 0.018, flat(c2, true), Vector3(1.6, 0.6, 0.4))
				box(torso, Vector3(0, 1.3, 0.385), Vector3(0.1, 0.025, 0.02), flat(c1))

	# ---------------------------------------------------------------- 머리

	## 머리카락 덮개: 정수리를 덮고 이마는 비움
	func _hair_cap(m: Material, tilt := -0.42, r := 0.425) -> MeshInstance3D:
		var c := sph(torso, Vector3(0, 1.28, -0.01), r, m, Vector3.ONE, true)
		c.rotation.x = tilt
		return c

	func _hat_brim(y: float, r: float, m: Material) -> void:
		cyl(torso, Vector3(0, y, 0), r, r, 0.035, m)

	func _hair(kind: String) -> void:
		var m := clay(c1)
		var m2 := clay(c2)
		match kind:
			"none":
				pass
			"spiky":
				_hair_cap(m)
				for i in 9:
					var a := (i / 9.0) * TAU
					var pitch := 0.75 + 0.2 * sin(a * 2.0)
					var p := head_pt(a, pitch, -0.02)
					var up := (p - Vector3(0, 1.28, 0)).normalized()
					var spike := cone(torso, p + up * 0.08, 0.07, 0.2, m)
					spike.basis = Basis(Quaternion(Vector3.UP, up))
				cone(torso, Vector3(0, 1.74, 0), 0.08, 0.22, m)
			"bowl":
				var c := _hair_cap(m, -0.18, 0.43)
				c.scale = Vector3(1.05, 1.0, 1.05)
				box(torso, Vector3(0, 1.43, 0.36), Vector3(0.5, 0.08, 0.08), m, Vector3(-0.3, 0, 0))
			"curly":
				_hair_cap(m)
				for i in 16:
					var a := (i / 16.0) * TAU
					var pitch := 0.35 + 0.6 * float(i % 3) / 2.0
					if cos(a) > 0.55 and pitch < 0.6:
						continue  # 이마 쪽은 비움
					sph(torso, head_pt(a, pitch, 0.02), 0.11, m)
				sph(torso, Vector3(0, 1.72, -0.02), 0.13, m)
			"afro":
				sph(torso, Vector3(0, 1.5, -0.06), 0.47, m, Vector3(1.15, 0.95, 1.05))
			"mohawk":
				for i in 7:
					var a := -0.4 + i * 0.32
					var p := Vector3(0, 1.28 + cos(a) * 0.41, sin(a) * 0.41 * -1.0 + 0.05)
					prism(torso, p + Vector3(0, 0.06, 0), Vector3(0.06, 0.22, 0.14), m, Vector3(-a, PI / 2.0, 0))
			"ponytail":
				_hair_cap(m)
				var tail := cap(torso, Vector3(0, 1.32, -0.5), 0.1, 0.45, m, Vector3(0.55, 0, 0))
				spin(tail, "sway")
				torus(torso, Vector3(0, 1.52, -0.42), 0.04, 0.07, m2, Vector3(0.9, 0, 0))
			"twintail":
				_hair_cap(m)
				for s in [-1.0, 1.0]:
					var t := cap(torso, Vector3(0.44 * s, 1.25, -0.08), 0.1, 0.5, m, Vector3(0, 0, 0.25 * s))
					spin(t, "sway")
					sph(torso, Vector3(0.38 * s, 1.5, -0.06), 0.05, m2)
			"bun":
				_hair_cap(m)
				sph(torso, Vector3(0, 1.78, -0.08), 0.15, m)
				torus(torso, Vector3(0, 1.69, -0.07), 0.08, 0.12, m2)
			"long":
				_hair_cap(m, -0.3, 0.43)
				box(torso, Vector3(0, 1.0, -0.3), Vector3(0.7, 0.75, 0.16), m, Vector3(0.12, 0, 0))
				for s in [-1.0, 1.0]:
					box(torso, Vector3(0.36 * s, 1.08, 0.04), Vector3(0.1, 0.55, 0.3), m)
			"cap":
				var dome := sph(torso, Vector3(0, 1.38, 0), 0.41, m, Vector3(1.0, 0.85, 1.0), true)
				dome.rotation.x = -0.1
				var bill := cyl(torso, Vector3(0, 1.43, 0.42), 0.24, 0.24, 0.03, m, Vector3(0.12, 0, 0))
				bill.scale = Vector3(1.0, 1.0, 0.75)
				sph(torso, Vector3(0, 1.76, 0), 0.035, m2)
			"beanie":
				var dome := sph(torso, Vector3(0, 1.36, -0.01), 0.425, m, Vector3(1.0, 1.08, 1.0), true)
				dome.rotation.x = -0.15
				torus(torso, Vector3(0, 1.4, 0.02), 0.36, 0.44, m, Vector3(-0.15, 0, 0))
				sph(torso, Vector3(0, 1.86, -0.06), 0.1, clay(c2 if c2 != Color.WHITE else c1.lightened(0.4)))
			"tophat":
				_hat_brim(1.62, 0.42, m)
				cyl(torso, Vector3(0, 1.85, 0), 0.26, 0.26, 0.45, m)
				cyl(torso, Vector3(0, 1.7, 0), 0.265, 0.265, 0.08, m2)
			"witch":
				_hat_brim(1.6, 0.55, m)
				var cn := cone(torso, Vector3(0, 1.95, -0.05), 0.3, 0.7, m, Vector3(-0.25, 0, 0.15))
				cn.position = Vector3(0, 1.93, -0.06)
				torus(torso, Vector3(0, 1.66, 0), 0.26, 0.31, m2)
			"crown":
				var gold := flat(c1)
				gold.metallic = 0.8
				gold.roughness = 0.25
				cyl(torso, Vector3(0, 1.66, 0), 0.24, 0.24, 0.14, gold)
				for i in 6:
					var a := i * TAU / 6.0
					cone(torso, Vector3(sin(a) * 0.22, 1.79, cos(a) * 0.22), 0.06, 0.14, gold)
					sph(torso, Vector3(sin(a) * 0.24, 1.66, cos(a) * 0.24), 0.028, glow(c2, 0.6))
			"bunny":
				for s in [-1.0, 1.0]:
					var ear := cap(torso, Vector3(0.14 * s, 1.85, -0.04), 0.07, 0.48, m, Vector3(-0.1, 0, -0.18 * s))
					cap(ear, Vector3(0, 0, 0.045), 0.04, 0.36, m2)
			"catears":
				for s in [-1.0, 1.0]:
					var ear := prism(torso, Vector3(0.22 * s, 1.66, 0.0), Vector3(0.2, 0.2, 0.08), m, Vector3(0, 0, -0.35 * s))
					prism(ear, Vector3(0, -0.01, 0.03), Vector3(0.12, 0.12, 0.04), m2)
			"bearears":
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.27 * s, 1.6, -0.02), 0.1, m, Vector3(1, 1, 0.6))
					sph(torso, Vector3(0.27 * s, 1.6, 0.03), 0.055, m2, Vector3(1, 1, 0.5))
			"horns":
				for s in [-1.0, 1.0]:
					cone(torso, Vector3(0.18 * s, 1.68, 0.06), 0.06, 0.2, m, Vector3(0.2, 0, -0.45 * s))
			"halo":
				var h := torus(torso, Vector3(0, 1.82, 0), 0.2, 0.25, glow(c1, 2.5))
				spin(h, "bob")
			"chef":
				cyl(torso, Vector3(0, 1.66, 0), 0.3, 0.3, 0.18, m)
				for i in 5:
					var a := i * TAU / 5.0
					sph(torso, Vector3(sin(a) * 0.14, 1.85, cos(a) * 0.14), 0.17, m)
				sph(torso, Vector3(0, 1.9, 0), 0.18, m)
			"party":
				var cn := cone(torso, Vector3(0, 1.85, 0), 0.22, 0.5, m, Vector3(0, 0, 0.12))
				for k in 3:
					torus(cn, Vector3(0, -0.15 + k * 0.13, 0), 0.19 - k * 0.055, 0.205 - k * 0.055, m2)
				sph(cn, Vector3(0, 0.27, 0), 0.06, clay(c2))
			"propeller":
				var dome := sph(torso, Vector3(0, 1.38, 0), 0.41, m, Vector3(1.0, 0.85, 1.0), true)
				dome.rotation.x = -0.1
				cyl(torso, Vector3(0, 1.75, 0), 0.015, 0.015, 0.1, flat(Color(0.3, 0.3, 0.3)))
				var rotor := Node3D.new()
				rotor.position = Vector3(0, 1.8, 0)
				torso.add_child(rotor)
				for k in 2:
					box(rotor, Vector3(0, 0, 0), Vector3(0.5, 0.02, 0.07), clay(c2), Vector3(0.15 if k == 0 else -0.15, k * PI / 2.0, 0))
				spin(rotor, "spin")
			"viking":
				var dome := sph(torso, Vector3(0, 1.36, 0), 0.43, flat(c1), Vector3(1, 1, 1), true)
				dome.material_override.metallic = 0.7
				torus(torso, Vector3(0, 1.38, 0), 0.4, 0.45, clay(Color(0.45, 0.3, 0.15)))
				for s in [-1.0, 1.0]:
					var horn := cone(torso, Vector3(0.45 * s, 1.62, 0), 0.08, 0.32, m2, Vector3(0, 0, -0.9 * s))
					horn.rotation.z = -0.7 * s
			"flowercrown":
				torus(torso, Vector3(0, 1.6, 0), 0.24, 0.28, clay(c2), Vector3(-0.15, 0, 0))
				var petals := [c1, Color(1.0, 0.9, 0.3), Color(0.7, 0.6, 1.0), Color(1, 1, 1)]
				for i in 8:
					var a := i * TAU / 8.0
					var p := Vector3(sin(a) * 0.27, 1.6 + cos(a) * 0.04, cos(a) * 0.27)
					sph(torso, p, 0.06, clay(petals[i % petals.size()]), Vector3(1, 0.6, 1))
					sph(torso, p + Vector3(0, 0.03, 0), 0.025, clay(Color(1.0, 0.85, 0.2)))
			"antenna":
				for s in [-1.0, 1.0]:
					var st := cyl(torso, Vector3(0.12 * s, 1.8, 0), 0.012, 0.012, 0.3, flat(c2), Vector3(0, 0, -0.3 * s))
					var ball := sph(torso, Vector3(0.21 * s, 1.95, 0), 0.06, glow(c1, 1.5))
					spin(ball, "bob")
					st.name = "stalk"
			"sprout":
				cyl(torso, Vector3(0, 1.75, 0), 0.012, 0.015, 0.14, clay(c1.darkened(0.3)))
				for s in [-1.0, 1.0]:
					var leaf := sph(torso, Vector3(0.07 * s, 1.83, 0), 0.07, clay(c1), Vector3(1.2, 0.35, 0.7))
					leaf.rotation.z = 0.5 * s
					spin(leaf, "sway")
			"pirate":
				_hat_brim(1.6, 0.4, m)
				var top := box(torso, Vector3(0, 1.75, 0), Vector3(0.75, 0.25, 0.3), m)
				top.scale = Vector3(1, 1, 1)
				prism(torso, Vector3(0, 1.88, 0), Vector3(0.75, 0.15, 0.3), m)
				sph(torso, Vector3(0, 1.76, 0.16), 0.05, clay(c2))
				for k in [-1.0, 1.0]:
					cap(torso, Vector3(0, 1.69, 0.165), 0.01, 0.12, clay(c2), Vector3(0, 0, 0.8 * k))
			"santa":
				torus(torso, Vector3(0, 1.48, 0), 0.34, 0.44, m2, Vector3(-0.12, 0, 0))
				var cn := cone(torso, Vector3(0, 1.75, -0.08), 0.36, 0.55, m, Vector3(-0.5, 0, 0.3))
				sph(cn, Vector3(0, 0.3, 0), 0.08, m2)
			"frog":
				var dome := sph(torso, Vector3(0, 1.36, -0.01), 0.43, m, Vector3(1, 1.05, 1), true)
				dome.rotation.x = -0.25
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.18 * s, 1.75, 0.12), 0.11, m)
					sph(torso, Vector3(0.18 * s, 1.77, 0.22), 0.07, clay(Color.WHITE))
					sph(torso, Vector3(0.18 * s, 1.77, 0.28), 0.035, flat(Color(0.05, 0.05, 0.05)))
			"mushroom":
				var capm := sph(torso, Vector3(0, 1.5, 0), 0.55, m, Vector3(1, 0.75, 1), true)
				capm.position.y = 1.52
				for i in 7:
					var a := i * TAU / 7.0
					var r := 0.3 if i % 2 == 0 else 0.18
					sph(torso, Vector3(sin(a) * r, 1.84 - r * 0.45, cos(a) * r), 0.06, m2, Vector3(1, 0.4, 1))
			"grad":
				cyl(torso, Vector3(0, 1.64, 0), 0.27, 0.29, 0.14, m)
				box(torso, Vector3(0, 1.73, 0), Vector3(0.65, 0.03, 0.65), m, Vector3(0, PI / 4.0, 0))
				var tassel := cap(torso, Vector3(0.24, 1.62, 0.24), 0.015, 0.2, clay(c2))
				spin(tassel, "sway")

	# ---------------------------------------------------------------- 옷

	## 옷은 몸에 바로 칠함 (clay_body.dress): 상의 색 / 하의 색 / 소매 / 바지
	var _top_c := Color(0, 0, 0, 0)
	var _bot_c := Color(0, 0, 0, 0)
	var _split := -0.05
	var _stripes := Color(0, 0, 0, 0)
	var _front := Color(0, 0, 0, 0)
	var _belly := Color(0, 0, 0, 0)
	var _arm_c := Color(0, 0, 0, 0)
	var _leg_c := Color(0, 0, 0, 0)

	func _col(m: Material) -> Color:
		return (m as StandardMaterial3D).albedo_color if m is StandardMaterial3D else Color.WHITE

	func _top(m: Material, sleeves := true, long := false) -> void:
		_top_c = _col(m)
		if long:
			_split = -0.2
		if sleeves:
			_arm_c = _col(m)

	func _bottom(m: Material, legs := true) -> void:
		_bot_c = _col(m)
		if legs:
			_leg_c = _col(m)

	func _suit(m: Material) -> void:
		_top(m)
		_bottom(m)

	func _finish_dress() -> void:
		if _top_c.a > 0.0 or _bot_c.a > 0.0 or _belly.a > 0.0:
			body.call("dress", _top_c, _bot_c, _split, _stripes, _front, _belly)
		body.call("dress_limbs", _arm_c, _leg_c)

	func _hood(m: Material) -> void:
		var h := sph(torso, Vector3(0, 1.3, -0.12), 0.43, m, Vector3(1.05, 1.0, 0.85), true)
		h.rotation.x = -1.2

	func _outfit(kind: String) -> void:
		_outfit_parts(kind)
		_finish_dress()

	func _outfit_parts(kind: String) -> void:
		var m := clay(c1)
		var m2 := clay(c2)
		match kind:
			"none":
				pass
			"tee":
				_top(m)
				_bottom(m2)
			"stripes":
				_top(m2)
				_stripes = Color(c1.r, c1.g, c1.b, 1.0)
				_bottom(clay(Color(0.2, 0.22, 0.3)))
			"hoodie":
				_top(m)
				_hood(m)
				box(torso, Vector3(0, 0.6, 0.29), Vector3(0.3, 0.13, 0.04), clay(c1.darkened(0.15)))
				for s in [-1.0, 1.0]:
					cyl(torso, Vector3(0.06 * s, 0.9, 0.31), 0.008, 0.008, 0.16, m2)
				_bottom(m2)
			"overalls":
				_bottom(m)
				box(torso, Vector3(0, 0.74, 0.27), Vector3(0.3, 0.26, 0.05), m)
				for s in [-1.0, 1.0]:
					var strap := box(torso, Vector3(0.12 * s, 0.9, 0.0), Vector3(0.06, 0.03, 0.62), m, Vector3(0.45, 0, 0))
					strap.rotation.x = 0.0
					sph(torso, Vector3(0.12 * s, 0.85, 0.295), 0.025, clay(c2))
				_top(clay(Color(0.95, 0.95, 0.93)), true)
			"school":
				_top(m)
				_bottom(m2)
				box(torso, Vector3(0, 0.82, 0.3), Vector3(0.07, 0.25, 0.03), clay(Color(0.75, 0.12, 0.15)), Vector3(0.25, 0, 0))
				prism(torso, Vector3(0, 0.98, 0.27), Vector3(0.3, 0.12, 0.05), m, Vector3(0, 0, PI))
			"sailor":
				_top(m)
				_bottom(m2)
				box(torso, Vector3(0, 0.98, -0.18), Vector3(0.5, 0.3, 0.04), m2, Vector3(-0.5, 0, 0))
				prism(torso, Vector3(0, 0.88, 0.29), Vector3(0.18, 0.15, 0.04), clay(Color(0.85, 0.15, 0.2)), Vector3(0, 0, PI))
			"tuxedo":
				_top(m)
				_bottom(m)
				_front = Color(c2.r, c2.g, c2.b, 1.0)
				_bowtie(Vector3(0, 0.96, 0.3), clay(Color(0.05, 0.05, 0.05)))
				for y in [0.7, 0.62]:
					sph(torso, Vector3(0, y, 0.32), 0.018, m2)
			"raincoat":
				_suit(m)
				_leg_c = Color(0, 0, 0, 0)
				_hood(m)
				for y in [0.8, 0.68, 0.56]:
					sph(torso, Vector3(0, y, 0.33), 0.02, m2)
			"gown":
				_suit(m)
				for y in [0.85, 0.6]:
					box(torso, Vector3(0.1, y, 0.3), Vector3(0.12, 0.02, 0.03), m2, Vector3(0, 0, 0.4))
			"labcoat":
				_top(m, true, true)
				_bottom(clay(Color(0.3, 0.35, 0.45)))
				box(torso, Vector3(-0.13, 0.8, 0.29), Vector3(0.1, 0.1, 0.03), m)
				box(torso, Vector3(-0.13, 0.86, 0.3), Vector3(0.02, 0.07, 0.02), clay(c2))
				prism(torso, Vector3(0, 0.88, 0.28), Vector3(0.16, 0.2, 0.03), clay(Color(0.5, 0.7, 0.85)), Vector3(0, 0, PI))
			"police":
				_top(m)
				_arm_c = Color(0.55, 0.65, 0.8)
				_bottom(clay(Color(0.15, 0.17, 0.25)))
				var badge := StarMesh.make()
				add(torso, badge, glow(c2, 0.3), Vector3(-0.12, 0.84, 0.31), Vector3(-0.3, 0, 0), Vector3.ONE * 0.06)
			"astro":
				_suit(m)
				box(torso, Vector3(0, 0.76, 0.3), Vector3(0.2, 0.14, 0.05), clay(Color(0.3, 0.32, 0.38)))
				for k in 3:
					sph(torso, Vector3(-0.05 + k * 0.05, 0.77, 0.33), 0.017, glow([Color(1, 0.2, 0.2), Color(0.2, 1, 0.3), Color(0.3, 0.6, 1)][k], 1.5))
				torus(torso, Vector3(0, 0.98, 0), 0.25, 0.32, m2)
			"ninja":
				_suit(m)
				torus(torso, Vector3(0, 0.6, 0), 0.31, 0.36, m2, Vector3.ZERO)
				box(torso, Vector3(0, 1.17, 0.28), Vector3(0.7, 0.16, 0.25), m)
				var tie := box(torso, Vector3(0, 1.38, -0.4), Vector3(0.05, 0.3, 0.03), m2, Vector3(0.6, 0, 0.3))
				spin(tie, "sway")
			"hero":
				_suit(m)
				var cape := box(torso, Vector3(0, 0.62, -0.32), Vector3(0.62, 0.85, 0.03), m2, Vector3(0.18, 0, 0))
				spin(cape, "cape")
				var emblem := StarMesh.make()
				add(torso, emblem, glow(Color(1.0, 0.85, 0.2), 0.4), Vector3(0, 0.8, 0.31), Vector3(-0.25, 0, 0), Vector3.ONE * 0.1)
			"kimono":
				_top(m, true, true)
				_bottom(m)
				torus(torso, Vector3(0, 0.62, 0), 0.31, 0.37, m2).scale = Vector3(1, 2.2, 0.95)
				for s in [-1.0, 1.0]:
					box(torso, Vector3(0.05 * s, 0.86, 0.3), Vector3(0.04, 0.25, 0.02), clay(Color(0.98, 0.95, 0.9)), Vector3(0, 0, 0.5 * s))
				for right in [false, true]:
					var sl := box(arm(right), Vector3(0, -0.2, 0.0), Vector3(0.24, 0.3, 0.16), m)
			"jersey":
				_top(m, false)
				_bottom(m)
				var lbl := Label3D.new()
				lbl.text = str(randi_range(1, 99))
				lbl.font_size = 80
				lbl.modulate = c2
				lbl.outline_size = 0
				lbl.pixel_size = 0.002
				lbl.position = Vector3(0, 0.78, 0.33)
				lbl.rotation.x = -0.3
				lbl.add_to_group("cosmetic")
				torso.add_child(lbl)
				torus(torso, Vector3(0, 0.98, 0), 0.22, 0.27, m2)
			"apron":
				box(torso, Vector3(0, 0.66, 0.3), Vector3(0.38, 0.55, 0.03), m, Vector3(-0.05, 0, 0))
				box(torso, Vector3(0, 0.6, 0.32), Vector3(0.2, 0.12, 0.02), m2)
				torus(torso, Vector3(0, 0.7, 0), 0.32, 0.345, m)
			"armor":
				var steel := flat(c1)
				steel.metallic = 0.75
				steel.roughness = 0.3
				_suit(steel)
				box(torso, Vector3(0, 0.78, 0.29), Vector3(0.05, 0.3, 0.04), flat(c2))
				box(torso, Vector3(0, 0.82, 0.29), Vector3(0.2, 0.05, 0.04), flat(c2))
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.33 * s, 0.9, 0), 0.13, steel, Vector3(1, 0.8, 1))
			"pajamas":
				_suit(m)
				var star := StarMesh.make()
				for p in [Vector3(-0.12, 0.85, 0.3), Vector3(0.14, 0.65, 0.31), Vector3(-0.06, 0.5, 0.29), Vector3(0.18, 0.92, 0.25)]:
					add(torso, star, glow(c2, 0.3), p, Vector3(-0.2, 0, randf()), Vector3.ONE * 0.05)
				var nc := cone(torso, Vector3(0.1, 1.75, -0.1), 0.25, 0.45, m, Vector3(-0.7, 0, -0.4))
				sph(nc, Vector3(0, 0.25, 0), 0.06, clay(c2))
			"tutu":
				_top(clay(c2), false)
				for k in 3:
					torus(torso, Vector3(0, 0.5 - k * 0.025, 0), 0.25, 0.48 - k * 0.05, clay(c1.lightened(k * 0.1))).scale = Vector3(1, 0.3, 1)
			"bee":
				_suit(m)
				_split = -0.32
				_stripes = Color(c2.r, c2.g, c2.b, 1.0)
				_arm_c = c2
				_leg_c = c2
				for s in [-1.0, 1.0]:
					var w := sph(torso, Vector3(0.18 * s, 0.85, -0.35), 0.16, glow(Color(0.85, 0.95, 1.0, 0.6), 0.2), Vector3(1.2, 0.8, 0.15))
					w.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
					w.rotation.z = 0.5 * s
					spin(w, "flap")
			"pumpkin":
				var p := sph(torso, Vector3(0, 0.66, 0), 0.36, m, Vector3(1.1, 1.15, 1.0))
				for i in 6:
					var a := i * TAU / 6.0
					var rib := sph(torso, Vector3(sin(a) * 0.2, 0.66, cos(a) * 0.2), 0.2, m, Vector3(0.6, 1.95, 0.6))
					rib.material_override = clay(c1.darkened(0.08))
				cyl(torso, Vector3(0, 1.05, 0), 0.05, 0.07, 0.1, m2)
				for k in [-1.0, 1.0]:
					prism(torso, Vector3(0.1 * k, 0.75, 0.39), Vector3(0.1, 0.08, 0.02), flat(Color(0.15, 0.08, 0.02)))
			"dino":
				_suit(m)
				for i in 6:
					var y := 1.6 - i * 0.18
					prism(torso, Vector3(0, y, -0.38 + (0.0 if y > 1.0 else 0.06)), Vector3(0.04, 0.14, 0.12), m2, Vector3(0, PI / 2.0, 0))
				_belly = Color(0.85, 0.9, 0.6, 1.0)
			"penguin":
				_suit(m)
				_belly = Color(c2.r, c2.g, c2.b, 1.0)
				for leg in ["_left_leg", "_right_leg"]:
					sph(body.get(leg), Vector3(0, -0.4, 0.08), 0.1, clay(Color(1.0, 0.6, 0.1)), Vector3(1.2, 0.4, 1.6))
			"scarf":
				torus(torso, Vector3(0, 1.0, 0), 0.2, 0.32, m)
				for k in 3:
					box(torso, Vector3(0.12, 0.88 - k * 0.0, 0.3), Vector3(0.11, 0.28, 0.05), m, Vector3(0.1, 0, 0.15))
				torus(torso, Vector3(0, 1.0, 0), 0.31, 0.325, m2)
			"vampire":
				_top(m)
				_bottom(m)
				var cape := box(torso, Vector3(0, 0.6, -0.33), Vector3(0.7, 0.95, 0.03), m, Vector3(0.15, 0, 0))
				spin(cape, "cape")
				box(cape, Vector3(0, 0, 0.02), Vector3(0.62, 0.88, 0.01), m2)
				for s in [-1.0, 1.0]:
					prism(torso, Vector3(0.24 * s, 1.08, -0.12), Vector3(0.2, 0.32, 0.03), m, Vector3(0.3, 0.8 * s, 0.4 * s))
			"bib":
				var bib := sph(torso, Vector3(0, 0.88, 0.25), 0.18, m, Vector3(1.0, 1.0, 0.2))
				bib.rotation.x = -0.4
				torus(torso, Vector3(0, 0.88, 0.25), 0.16, 0.18, m2, Vector3(PI / 2.0 - 0.4, 0, 0)).scale = Vector3(1, 1, 1)

	func _bowtie(at: Vector3, m: Material) -> void:
		for s in [-1.0, 1.0]:
			prism(torso, at + Vector3(0.05 * s, 0, 0), Vector3(0.09, 0.09, 0.04), m, Vector3(0, 0, -PI / 2.0 * s))
		sph(torso, at + Vector3(0, 0, 0.01), 0.025, m)

	# ---------------------------------------------------------------- 장신구

	func _acc(kind: String) -> void:
		var m := clay(c1)
		var m2 := clay(c2)
		match kind:
			"none":
				pass
			"glasses", "monocle":
				var frame := flat(c1)
				frame.metallic = 0.5 if kind == "monocle" else 0.0
				var lens := flat(Color(c2.r, c2.g, c2.b, 0.25))
				lens.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				for s in ([-1.0, 1.0] if kind == "glasses" else [1.0]):
					torus(torso, Vector3(0.135 * s, 1.27, 0.405), 0.085, 0.105, frame, Vector3(PI / 2.0, 0, 0))
					sph(torso, Vector3(0.135 * s, 1.27, 0.4), 0.088, lens, Vector3(1, 1, 0.1))
				if kind == "glasses":
					box(torso, Vector3(0, 1.29, 0.41), Vector3(0.06, 0.015, 0.015), frame)
				else:
					var chain := cyl(torso, Vector3(0.24, 1.08, 0.33), 0.006, 0.006, 0.35, frame, Vector3(0, 0, -0.3))
			"sunglasses":
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.28, 0.395), 0.1, flat(c1), Vector3(1.15, 0.75, 0.2))
				box(torso, Vector3(0, 1.31, 0.41), Vector3(0.45, 0.025, 0.02), flat(c1))
				sph(torso, Vector3(0.1, 1.31, 0.42), 0.02, flat(Color(1, 1, 1, 0.8), true), Vector3(2.0, 0.6, 0.3))
			"heartglasses":
				for s in [-1.0, 1.0]:
					var h := Node3D.new()
					h.position = Vector3(0.14 * s, 1.27, 0.405)
					torso.add_child(h)
					sph(h, Vector3(-0.04, 0.025, 0), 0.055, glow(c1, 0.4), Vector3(1, 1, 0.25))
					sph(h, Vector3(0.04, 0.025, 0), 0.055, glow(c1, 0.4), Vector3(1, 1, 0.25))
					prism(h, Vector3(0, -0.045, 0), Vector3(0.17, 0.1, 0.02), glow(c1, 0.4), Vector3(0, 0, PI))
				box(torso, Vector3(0, 1.3, 0.41), Vector3(0.08, 0.015, 0.015), flat(c1))
			"starglasses":
				var star := StarMesh.make()
				for s in [-1.0, 1.0]:
					add(torso, star, glow(c1, 0.6), Vector3(0.14 * s, 1.27, 0.41), Vector3.ZERO, Vector3.ONE * 0.12)
				box(torso, Vector3(0, 1.3, 0.415), Vector3(0.06, 0.015, 0.015), flat(c1))
			"mustache":
				for s in [-1.0, 1.0]:
					var half := cap(torso, Vector3(0.06 * s, 1.15, 0.385), 0.035, 0.14, m, Vector3(0, 0, PI / 2.0 + 0.35 * s))
					sph(torso, Vector3(0.125 * s, 1.165, 0.37), 0.03, m)
			"beard":
				sph(torso, Vector3(0, 1.05, 0.22), 0.27, m, Vector3(1.0, 1.0, 0.6))
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.07 * s, 1.16, 0.37), 0.06, m, Vector3(1.4, 0.6, 0.7))
			"bandage":
				var b := box(torso, Vector3(0.2, 1.18, 0.345), Vector3(0.14, 0.05, 0.02), m, Vector3(0, 0.5, 0.5))
				box(torso, Vector3(0.2, 1.18, 0.352), Vector3(0.05, 0.045, 0.01), m2, Vector3(0, 0.5, 0.5))
			"blush":
				var bl := StandardMaterial3D.new()
				bl.albedo_color = Color(c1.r, c1.g, c1.b, 0.6)
				bl.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.235 * s, 1.17, 0.3), 0.06, bl, Vector3(1.25, 0.7, 0.35))
			"mask":
				var mk := sph(torso, Vector3(0, 1.14, 0.3), 0.2, m, Vector3(1.0, 0.6, 0.5))
				for s in [-1.0, 1.0]:
					cyl(torso, Vector3(0.25 * s, 1.2, 0.18), 0.006, 0.006, 0.3, clay(c2), Vector3(PI / 2.0, 0.6 * s, 0))
			"eyepatch":
				cyl(torso, Vector3(0.135, 1.28, 0.385), 0.1, 0.1, 0.02, flat(c1), Vector3(PI / 2.0 - 0.35, 0, 0))
				torus(torso, Vector3(0, 1.34, 0), 0.4, 0.415, flat(c1), Vector3(-0.2, 0, -0.3))
			"headphones":
				torus(torso, Vector3(0, 1.32, 0), 0.43, 0.47, m, Vector3(PI / 2.0, 0, 0))
				for s in [-1.0, 1.0]:
					cyl(torso, Vector3(0.43 * s, 1.27, 0), 0.12, 0.12, 0.1, m, Vector3(0, 0, PI / 2.0))
					cyl(torso, Vector3(0.49 * s, 1.27, 0), 0.08, 0.08, 0.02, glow(c2, 1.2), Vector3(0, 0, PI / 2.0))
			"backpack":
				var bp := box(torso, Vector3(0, 0.72, -0.36), Vector3(0.4, 0.45, 0.2), m)
				box(bp, Vector3(0, -0.06, -0.11), Vector3(0.3, 0.2, 0.06), m2)
				for s in [-1.0, 1.0]:
					box(torso, Vector3(0.14 * s, 0.84, 0.0), Vector3(0.05, 0.04, 0.62), m2)
			"wings":
				for s in [-1.0, 1.0]:
					var root := Node3D.new()
					root.position = Vector3(0.1 * s, 0.85, -0.3)
					torso.add_child(root)
					for k in 3:
						var f := sph(root, Vector3(0.18 * s + 0.08 * k * s, 0.1 - k * 0.1, -0.02), 0.16 - k * 0.025, m, Vector3(1.4, 0.55, 0.18))
						f.rotation.z = (0.5 + k * 0.25) * s
					spin(root, "flap" if s > 0 else "flapl")
			"batwings":
				for s in [-1.0, 1.0]:
					var root := Node3D.new()
					root.position = Vector3(0.12 * s, 0.85, -0.3)
					torso.add_child(root)
					prism(root, Vector3(0.25 * s, 0.05, 0), Vector3(0.5, 0.35, 0.02), m, Vector3(0, 0, PI + 0.3 * s))
					for k in 3:
						cyl(root, Vector3((0.12 + k * 0.13) * s, 0.12 - k * 0.07, 0.0), 0.012, 0.012, 0.3, m2, Vector3(0, 0, (0.9 - k * 0.4) * s))
					spin(root, "flap" if s > 0 else "flapl")
			"butterfly":
				for s in [-1.0, 1.0]:
					var root := Node3D.new()
					root.position = Vector3(0.08 * s, 0.85, -0.32)
					torso.add_child(root)
					var up := sph(root, Vector3(0.2 * s, 0.12, 0), 0.18, glow(c1, 0.3), Vector3(1.0, 1.2, 0.08))
					up.rotation.z = 0.5 * s
					var lo := sph(root, Vector3(0.15 * s, -0.12, 0), 0.12, glow(c2, 0.3), Vector3(1.0, 1.1, 0.08))
					lo.rotation.z = -0.4 * s
					spin(root, "flap" if s > 0 else "flapl")
			"cattail":
				var root := Node3D.new()
				root.position = Vector3(0, 0.45, -0.28)
				body.add_child(root)
				for k in 5:
					var seg := cap(root, Vector3(0, 0.05 + k * 0.09, -0.08 - k * 0.025 + (k * k) * 0.006), 0.045, 0.13, m, Vector3(-0.6 + k * 0.25, 0, 0))
					seg.add_to_group("cosmetic")
				spin(root, "wag")
			"dinotail":
				var root := Node3D.new()
				root.position = Vector3(0, 0.45, -0.25)
				body.add_child(root)
				for k in 4:
					cap(root, Vector3(0, -0.05 * k, -0.08 - k * 0.12), 0.12 - k * 0.025, 0.25, m, Vector3(PI / 2.0 - 0.3, 0, 0))
					prism(root, Vector3(0, 0.1 - 0.06 * k, -0.08 - k * 0.12), Vector3(0.03, 0.1, 0.08), m2, Vector3(0, PI / 2.0, 0))
				spin(root, "wag")
			"balloon":
				var root := Node3D.new()
				root.position = Vector3(0, -0.42, 0)
				arm(true).add_child(root)
				cyl(root, Vector3(0, 0.5, 0), 0.004, 0.004, 1.0, flat(c2))
				sph(root, Vector3(0, 1.12, 0), 0.2, glow(c1, 0.25), Vector3(0.9, 1.1, 0.9))
				cone(root, Vector3(0, 0.9, 0), 0.03, 0.05, glow(c1, 0.25))
				spin(root, "balloon")
			"lollipop":
				var h := arm(true)
				cyl(h, Vector3(0, -0.5, 0.06), 0.012, 0.012, 0.3, clay(c2), Vector3(-0.3, 0, 0))
				var candy := cyl(h, Vector3(0, -0.66, 0.1), 0.1, 0.1, 0.035, clay(c1), Vector3(PI / 2.0 - 0.3, 0, 0))
				torus(candy, Vector3(0, 0.02, 0), 0.04, 0.06, clay(c2))
			"teddy":
				var h := arm(false)
				var t := Node3D.new()
				t.position = Vector3(0, -0.5, 0.12)
				h.add_child(t)
				sph(t, Vector3(0, 0, 0), 0.1, m, Vector3(1, 1.1, 0.9))
				sph(t, Vector3(0, 0.15, 0), 0.08, m)
				for s in [-1.0, 1.0]:
					sph(t, Vector3(0.06 * s, 0.22, 0), 0.03, m)
					sph(t, Vector3(0.03 * s, 0.17, 0.07), 0.012, flat(Color(0.05, 0.05, 0.05)))
				sph(t, Vector3(0, 0.13, 0.07), 0.03, m2)
			"flower":
				var h := arm(true)
				cyl(h, Vector3(0, -0.55, 0.05), 0.012, 0.012, 0.35, clay(c2))
				for i in 6:
					var a := i * TAU / 6.0
					sph(h, Vector3(cos(a) * 0.05, -0.75, 0.05 + sin(a) * 0.05), 0.04, clay(c1), Vector3(1, 0.5, 1))
				sph(h, Vector3(0, -0.74, 0.05), 0.03, clay(Color(0.5, 0.3, 0.1)))
			"umbrella":
				var root := Node3D.new()
				root.position = Vector3(0, -0.42, 0)
				arm(true).add_child(root)
				cyl(root, Vector3(0, 0.55, 0), 0.012, 0.012, 1.2, flat(Color(0.2, 0.2, 0.2)))
				var canopy := sph(root, Vector3(0, 1.1, 0), 0.55, m, Vector3(1, 0.55, 1), true)
				for i in 4:
					var a := i * TAU / 4.0
					sph(root, Vector3(sin(a) * 0.38, 1.17, cos(a) * 0.38), 0.12, m2, Vector3(1, 0.3, 1))
				spin(root, "upright")
			"guitar":
				var g := Node3D.new()
				g.position = Vector3(0, 0.72, -0.36)
				g.rotation = Vector3(0, 0, 0.6)
				torso.add_child(g)
				sph(g, Vector3(0, -0.12, 0), 0.17, m, Vector3(1, 1, 0.35))
				sph(g, Vector3(0, 0.08, 0), 0.13, m, Vector3(1, 1, 0.35))
				cyl(g, Vector3(0, -0.04, 0.06), 0.045, 0.045, 0.01, flat(Color(0.05, 0.05, 0.05)), Vector3(PI / 2.0, 0, 0))
				box(g, Vector3(0, 0.38, 0), Vector3(0.05, 0.45, 0.03), m2)
				box(g, Vector3(0, 0.63, 0), Vector3(0.08, 0.1, 0.03), m2)
				box(torso, Vector3(0, 0.8, 0.05), Vector3(0.05, 0.03, 0.66), clay(Color(0.3, 0.2, 0.15)), Vector3(0.6, 0, 0.55))
			"necklace":
				var gold := flat(c1)
				gold.metallic = 0.85
				gold.roughness = 0.2
				torus(torso, Vector3(0, 0.98, 0.05), 0.24, 0.26, gold, Vector3(0.35, 0, 0))
				sph(torso, Vector3(0, 0.86, 0.3), 0.04, glow(c2, 0.8))
			"earrings":
				for s in [-1.0, 1.0]:
					torus(torso, Vector3(0.39 * s, 1.15, 0.0), 0.025, 0.035, flat(c1), Vector3(0, 0, PI / 2.0))
					sph(torso, Vector3(0.4 * s, 1.09, 0.0), 0.025, glow(c2, 0.6))
			"bowtie":
				_bowtie(Vector3(0, 0.98, 0.3), m)
			"pizza":
				var h := arm(true)
				var slice := prism(h, Vector3(0, -0.6, 0.1), Vector3(0.22, 0.28, 0.03), m, Vector3(-0.5, 0, PI))
				box(slice, Vector3(0, 0.15, 0), Vector3(0.24, 0.05, 0.05), clay(Color(0.85, 0.6, 0.3)))
				for p in [Vector3(-0.03, 0.03, 0.02), Vector3(0.04, -0.03, 0.02), Vector3(0.0, 0.08, 0.02)]:
					sph(slice, p, 0.025, m2, Vector3(1, 1, 0.3))


## 별 모양 납작한 메시 (별 눈, 별 안경, 경찰 배지)
class StarMesh:
	static var _m: ArrayMesh
	static func make() -> ArrayMesh:
		if _m:
			return _m
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var pts: Array[Vector3] = []
		for i in 10:
			var a := i * TAU / 10.0 - PI / 2.0
			var r := 1.0 if i % 2 == 0 else 0.45
			pts.append(Vector3(cos(a) * r, -sin(a) * r, 0.0))
		for face in [1.0, -1.0]:
			for i in 10:
				st.set_normal(Vector3(0, 0, face))
				var a: Vector3 = pts[i]
				var b: Vector3 = pts[(i + 1) % 10]
				var c := Vector3(0, 0, 0.12 * face)
				if face > 0:
					st.add_vertex(c)
					st.add_vertex(b)
					st.add_vertex(a)
				else:
					st.add_vertex(c)
					st.add_vertex(a)
					st.add_vertex(b)
		st.generate_normals()
		_m = st.commit()
		return _m
