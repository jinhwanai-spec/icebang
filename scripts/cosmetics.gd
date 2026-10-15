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
	# ---------------------------------------------------------------- 눈 (100)
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
	["eyes_smug", "흐뭇한 눈", "eyes", 200, "smug", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_bored", "심드렁 눈", "eyes", 200, "bored", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_bigpupil", "왕눈동자", "eyes", 250, "bigpupil", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_starpupil", "별빛 눈동자 (파랑)", "eyes", 500, "starpupil", Color(0.2, 0.4, 0.9), Color.WHITE],
	["eyes_shock", "깜짝 놀란 눈", "eyes", 200, "shock", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_tearstream", "펑펑 눈물", "eyes", 350, "tearstream", Color(0.07, 0.05, 0.09), Color(0.55, 0.8, 1.0)],
	["eyes_ghost", "유령 눈", "eyes", 450, "ghost", Color(0.06, 0.06, 0.07), Color(0.4, 1.0, 0.95)],
	["eyes_pixel", "픽셀 선글라스", "eyes", 600, "pixel", Color(0.06, 0.06, 0.07), Color.WHITE],
	["eyes_heartpupil", "하트 눈동자 (분홍)", "eyes", 450, "heartpupil", Color(1.0, 0.3, 0.6), Color.WHITE],
	["eyes_tired", "피곤한 눈", "eyes", 200, "tired", Color(0.07, 0.05, 0.09), Color(0.55, 0.42, 0.6)],
	["eyes_squint", "질끈 눈 > <", "eyes", 200, "squint", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_gem_ruby", "보석 눈 (루비)", "eyes", 700, "gem", Color(0.9, 0.1, 0.25), Color.WHITE],
	["eyes_uu", "만족한 눈 u u", "eyes", 150, "uu", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_dollar", "돈 눈 $ $", "eyes", 500, "dollar", Color(0.15, 0.6, 0.25), Color.WHITE],
	["eyes_goat", "염소 눈", "eyes", 350, "goat", Color(0.95, 0.65, 0.2), Color(0.06, 0.06, 0.07)],
	["eyes_googly", "왕방울 눈", "eyes", 300, "googly", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_calm", "평온한 눈", "eyes", 200, "calm", Color(0.07, 0.05, 0.09), Color.WHITE],
	["eyes_panda", "판다 눈", "eyes", 350, "panda", Color(0.07, 0.05, 0.09), Color(0.06, 0.06, 0.07)],
	["eyes_unibrow", "일자 눈썹", "eyes", 250, "unibrow", Color(0.07, 0.05, 0.09), Color(0.12, 0.1, 0.1)],
	["eyes_galaxy", "은하수 눈", "eyes", 900, "galaxy", Color(0.08, 0.1, 0.35), Color(1.0, 0.95, 0.6)],
	["eyes_puppy", "강아지 눈 (갈색)", "eyes", 450, "puppy", Color(0.4, 0.22, 0.1), Color(0.55, 0.8, 1.0)],
	["eyes_starpupil_pink", "별빛 눈동자 (분홍)", "eyes", 500, "starpupil", Color(1.0, 0.3, 0.6), Color.WHITE],
	["eyes_starpupil_green", "별빛 눈동자 (초록)", "eyes", 500, "starpupil", Color(0.25, 0.65, 0.35), Color.WHITE],
	["eyes_starpupil_purple", "별빛 눈동자 (보라)", "eyes", 500, "starpupil", Color(0.6, 0.35, 0.85), Color.WHITE],
	["eyes_starpupil_gold", "별빛 눈동자 (금색)", "eyes", 550, "starpupil", Color(1.0, 0.8, 0.25), Color.WHITE],
	["eyes_starpupil_red", "별빛 눈동자 (빨강)", "eyes", 500, "starpupil", Color(0.88, 0.2, 0.2), Color.WHITE],
	["eyes_heartpupil_red", "하트 눈동자 (빨강)", "eyes", 450, "heartpupil", Color(0.88, 0.2, 0.2), Color.WHITE],
	["eyes_heartpupil_purple", "하트 눈동자 (보라)", "eyes", 450, "heartpupil", Color(0.6, 0.35, 0.85), Color.WHITE],
	["eyes_heartpupil_sky", "하트 눈동자 (하늘)", "eyes", 450, "heartpupil", Color(0.5, 0.78, 1.0), Color.WHITE],
	["eyes_heartpupil_gold", "하트 눈동자 (금색)", "eyes", 500, "heartpupil", Color(1.0, 0.8, 0.25), Color.WHITE],
	["eyes_gem_sapphire", "보석 눈 (사파이어)", "eyes", 750, "gem", Color(0.15, 0.35, 0.95), Color.WHITE],
	["eyes_gem_emerald", "보석 눈 (에메랄드)", "eyes", 750, "gem", Color(0.1, 0.75, 0.4), Color.WHITE],
	["eyes_gem_amethyst", "보석 눈 (자수정)", "eyes", 800, "gem", Color(0.6, 0.25, 0.9), Color.WHITE],
	["eyes_gem_topaz", "보석 눈 (토파즈)", "eyes", 800, "gem", Color(1.0, 0.7, 0.15), Color.WHITE],
	["eyes_gem_diamond", "보석 눈 (다이아)", "eyes", 1100, "gem", Color(0.75, 0.95, 1.0), Color.WHITE],
	["eyes_galaxy_nebula", "은하수 눈 (보라 성운)", "eyes", 950, "galaxy", Color(0.3, 0.08, 0.4), Color(1.0, 0.6, 0.9)],
	["eyes_galaxy_aurora", "은하수 눈 (초록 오로라)", "eyes", 950, "galaxy", Color(0.04, 0.25, 0.2), Color(0.5, 1.0, 0.8)],
	["eyes_galaxy_sunset", "은하수 눈 (붉은 노을)", "eyes", 1000, "galaxy", Color(0.4, 0.06, 0.12), Color(1.0, 0.8, 0.3)],
	["eyes_glow_yellow", "노란 빛 눈", "eyes", 600, "glow", Color(1.0, 0.85, 0.25), Color.WHITE],
	["eyes_glow_purple", "보라 빛 눈", "eyes", 600, "glow", Color(0.6, 0.35, 0.85), Color.WHITE],
	["eyes_glow_pink", "분홍 빛 눈", "eyes", 600, "glow", Color(1.0, 0.3, 0.6), Color.WHITE],
	["eyes_glow_white", "하얀 빛 눈", "eyes", 650, "glow", Color(0.95, 0.98, 1.0), Color.WHITE],
	["eyes_anime_green", "초롱 눈 (초록)", "eyes", 400, "anime", Color(0.25, 0.65, 0.35), Color.WHITE],
	["eyes_anime_pink", "초롱 눈 (분홍)", "eyes", 400, "anime", Color(1.0, 0.3, 0.6), Color.WHITE],
	["eyes_anime_gold", "초롱 눈 (금색)", "eyes", 450, "anime", Color(1.0, 0.8, 0.25), Color.WHITE],
	["eyes_anime_red", "초롱 눈 (빨강)", "eyes", 400, "anime", Color(0.88, 0.2, 0.2), Color.WHITE],
	["eyes_cat_green", "고양이 눈 (초록)", "eyes", 300, "cat", Color(0.4, 0.85, 0.3), Color(0.05, 0.05, 0.05)],
	["eyes_cat_blue", "고양이 눈 (파랑)", "eyes", 300, "cat", Color(0.35, 0.65, 1.0), Color(0.05, 0.05, 0.05)],
	["eyes_cat_red", "고양이 눈 (빨강)", "eyes", 350, "cat", Color(0.95, 0.25, 0.2), Color(0.05, 0.05, 0.05)],
	["eyes_goat_green", "염소 눈 (초록)", "eyes", 350, "goat", Color(0.5, 0.85, 0.3), Color(0.06, 0.06, 0.07)],
	["eyes_goat_red", "염소 눈 (빨강)", "eyes", 400, "goat", Color(0.9, 0.2, 0.15), Color(0.06, 0.06, 0.07)],
	["eyes_ghost_red", "유령 눈 (빨강)", "eyes", 450, "ghost", Color(0.06, 0.06, 0.07), Color(1.0, 0.25, 0.2)],
	["eyes_ghost_green", "유령 눈 (초록)", "eyes", 450, "ghost", Color(0.06, 0.06, 0.07), Color(0.4, 1.0, 0.4)],
	["eyes_ghost_purple", "유령 눈 (보라)", "eyes", 450, "ghost", Color(0.06, 0.06, 0.07), Color(0.8, 0.5, 1.0)],
	["eyes_dollar_gold", "돈 눈 (금색)", "eyes", 600, "dollar", Color(1.0, 0.75, 0.1), Color.WHITE],
	["eyes_dollar_pink", "돈 눈 (분홍)", "eyes", 500, "dollar", Color(1.0, 0.3, 0.6), Color.WHITE],
	["eyes_puppy_blue", "강아지 눈 (파랑)", "eyes", 450, "puppy", Color(0.2, 0.45, 0.85), Color(0.55, 0.8, 1.0)],
	["eyes_puppy_green", "강아지 눈 (초록)", "eyes", 450, "puppy", Color(0.2, 0.6, 0.35), Color(0.55, 0.8, 1.0)],
	["eyes_puppy_gray", "강아지 눈 (회색)", "eyes", 450, "puppy", Color(0.45, 0.47, 0.52), Color(0.55, 0.8, 1.0)],
	["eyes_robot_red", "로봇 눈 (빨강)", "eyes", 500, "robot", Color(1.0, 0.2, 0.2), Color(0.08, 0.08, 0.1)],
	["eyes_robot_yellow", "로봇 눈 (노랑)", "eyes", 500, "robot", Color(1.0, 0.85, 0.2), Color(0.08, 0.08, 0.1)],
	["eyes_robot_pink", "로봇 눈 (분홍)", "eyes", 500, "robot", Color(1.0, 0.4, 0.8), Color(0.08, 0.08, 0.1)],
	["eyes_star_sky", "별 눈 (하늘)", "eyes", 400, "star", Color(0.45, 0.8, 1.0), Color.WHITE],
	["eyes_star_pink", "별 눈 (분홍)", "eyes", 400, "star", Color(1.0, 0.45, 0.75), Color.WHITE],
	["eyes_heart_purple", "하트 눈 (보라)", "eyes", 400, "heart", Color(0.7, 0.35, 1.0), Color.WHITE],
	["eyes_heart_red", "하트 눈 (빨강)", "eyes", 400, "heart", Color(0.95, 0.1, 0.2), Color.WHITE],
	["eyes_pixel_pink", "픽셀 선글라스 (분홍)", "eyes", 600, "pixel", Color(1.0, 0.3, 0.6), Color.WHITE],
	["eyes_pixel_gold", "픽셀 선글라스 (금색)", "eyes", 700, "pixel", Color(1.0, 0.8, 0.25), Color.WHITE],
	["eyes_shades_red", "선글라스 눈 (빨강)", "eyes", 350, "shades", Color(0.6, 0.05, 0.08), Color(0.95, 0.5, 0.5)],
	["eyes_basic_brown", "기본 눈 (갈색)", "eyes", 100, "basic", Color(0.3, 0.17, 0.08), Color.WHITE],
	["eyes_basic_blue", "기본 눈 (파랑)", "eyes", 100, "basic", Color(0.12, 0.25, 0.6), Color.WHITE],
	["eyes_teary_pink", "글썽 눈 (분홍 눈물)", "eyes", 250, "teary", Color(0.07, 0.05, 0.09), Color(1.0, 0.6, 0.8)],
	["eyes_panda_red", "레서판다 눈", "eyes", 350, "panda", Color(0.07, 0.05, 0.09), Color(0.6, 0.25, 0.1)],
	["eyes_unibrow_blonde", "일자 눈썹 (금발)", "eyes", 250, "unibrow", Color(0.07, 0.05, 0.09), Color(0.95, 0.8, 0.4)],
	# ---------------------------------------------------------------- 머리 (100)
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
	["hat_beret_red", "베레모 (빨강)", "hair", 300, "beret", Color(0.88, 0.2, 0.2), Color.WHITE],
	["hat_cowboy", "카우보이 모자 (갈색)", "hair", 450, "cowboy", Color(0.55, 0.35, 0.18), Color(0.2, 0.12, 0.08)],
	["hat_bucket", "벙거지 (베이지)", "hair", 250, "bucket", Color(0.92, 0.82, 0.65), Color(0.45, 0.32, 0.2)],
	["hat_hard", "안전모 (노랑)", "hair", 350, "hardhat", Color(1.0, 0.8, 0.1), Color(1.0, 0.95, 0.7)],
	["hair_sweatband_red", "운동 머리띠 (빨강)", "hair", 200, "sweatband", Color(0.12, 0.1, 0.1), Color(0.88, 0.2, 0.2)],
	["hair_bow_pink", "리본 머리 (분홍)", "hair", 300, "bow", Color(0.45, 0.28, 0.15), Color(1.0, 0.3, 0.6)],
	["hair_spacebuns", "양쪽 똥머리", "hair", 300, "spacebuns", Color(0.12, 0.1, 0.1), Color(1.0, 0.3, 0.6)],
	["hair_topknot", "상투", "hair", 300, "topknot", Color(0.12, 0.1, 0.1), Color(0.8, 0.15, 0.15)],
	["hair_mullet", "멀릿 머리 (갈색)", "hair", 300, "mullet", Color(0.45, 0.28, 0.15), Color.WHITE],
	["hair_sidepart", "가르마 머리 (검정)", "hair", 250, "sidepart", Color(0.12, 0.1, 0.1), Color(1.0, 0.85, 0.25)],
	["hat_wizard", "마법사 모자 (남색)", "hair", 650, "wizard", Color(0.15, 0.18, 0.45), Color(1.0, 0.85, 0.3)],
	["hat_jester", "광대 모자", "hair", 550, "jester", Color(0.85, 0.15, 0.2), Color(1.0, 0.85, 0.2)],
	["ears_fox", "여우 귀", "hair", 400, "foxears", Color(0.95, 0.5, 0.15), Color(1.0, 0.95, 0.9)],
	["horns_antler", "사슴뿔", "hair", 550, "antlers", Color(0.55, 0.38, 0.22), Color(0.8, 0.6, 0.4)],
	["horn_unicorn", "유니콘 뿔", "hair", 900, "unicorn", Color(0.98, 0.95, 1.0), Color(1.0, 0.8, 0.3)],
	["hair_flowerpin", "꽃핀 머리", "hair", 300, "flowerpin", Color(0.45, 0.28, 0.15), Color(1.0, 0.3, 0.6)],
	["hat_bandana_red", "두건 (빨강)", "hair", 250, "bandana", Color(0.88, 0.2, 0.2), Color.WHITE],
	["hat_laurel", "월계관", "hair", 600, "laurel", Color(0.35, 0.62, 0.3), Color(0.85, 0.15, 0.2)],
	["hat_space", "우주 헬멧", "hair", 1000, "helmet", Color(0.95, 0.95, 0.97), Color(0.6, 0.9, 1.0)],
	["hat_tiara", "티아라 (금)", "hair", 800, "tiara", Color(1.0, 0.8, 0.3), Color(1.0, 0.35, 0.6)],
	["hair_bob_black", "단발머리 (검정)", "hair", 250, "bob", Color(0.12, 0.1, 0.1), Color.WHITE],
	["hair_braids_blonde", "땋은 머리 (금발)", "hair", 300, "braids", Color(0.95, 0.8, 0.4), Color(0.88, 0.2, 0.2)],
	["hat_duck", "머리 위 오리", "hair", 450, "duck", Color(1.0, 0.85, 0.2), Color(1.0, 0.5, 0.1)],
	["hat_beret_black", "베레모 (검정)", "hair", 300, "beret", Color(0.1, 0.1, 0.12), Color.WHITE],
	["hat_beret_navy", "베레모 (남색)", "hair", 300, "beret", Color(0.15, 0.2, 0.45), Color.WHITE],
	["hat_beret_pink", "베레모 (분홍)", "hair", 300, "beret", Color(1.0, 0.6, 0.75), Color.WHITE],
	["hat_cowboy_black", "카우보이 모자 (검정)", "hair", 500, "cowboy", Color(0.1, 0.1, 0.12), Color(0.75, 0.6, 0.3)],
	["hat_cowboy_white", "카우보이 모자 (하양)", "hair", 500, "cowboy", Color(0.96, 0.96, 0.94), Color(0.3, 0.2, 0.12)],
	["hat_bucket_khaki", "벙거지 (카키)", "hair", 250, "bucket", Color(0.5, 0.52, 0.3), Color(0.3, 0.3, 0.2)],
	["hat_bucket_pink", "벙거지 (분홍)", "hair", 250, "bucket", Color(1.0, 0.6, 0.75), Color.WHITE],
	["hat_bucket_sky", "벙거지 (하늘)", "hair", 250, "bucket", Color(0.5, 0.78, 1.0), Color.WHITE],
	["hat_hard_orange", "안전모 (주황)", "hair", 350, "hardhat", Color(1.0, 0.55, 0.15), Color(1.0, 0.95, 0.7)],
	["hat_hard_white", "안전모 (하양)", "hair", 350, "hardhat", Color(0.96, 0.96, 0.94), Color(0.6, 0.9, 1.0)],
	["hair_sweatband_blue", "운동 머리띠 (파랑)", "hair", 200, "sweatband", Color(0.45, 0.28, 0.15), Color(0.2, 0.4, 0.9)],
	["hair_sweatband_green", "운동 머리띠 (초록)", "hair", 200, "sweatband", Color(0.95, 0.8, 0.4), Color(0.25, 0.65, 0.35)],
	["hair_bow_red", "리본 머리 (빨강)", "hair", 300, "bow", Color(0.12, 0.1, 0.1), Color(0.88, 0.2, 0.2)],
	["hair_bow_sky", "리본 머리 (하늘)", "hair", 300, "bow", Color(0.95, 0.8, 0.4), Color(0.5, 0.78, 1.0)],
	["hair_spacebuns_pink", "양쪽 똥머리 (분홍)", "hair", 350, "spacebuns", Color(1.0, 0.6, 0.75), Color.WHITE],
	["hair_spacebuns_blonde", "양쪽 똥머리 (금발)", "hair", 300, "spacebuns", Color(0.95, 0.8, 0.4), Color(0.5, 0.78, 1.0)],
	["hair_mullet_blonde", "멀릿 머리 (금발)", "hair", 300, "mullet", Color(0.95, 0.8, 0.4), Color.WHITE],
	["hair_mullet_black", "멀릿 머리 (검정)", "hair", 300, "mullet", Color(0.12, 0.1, 0.1), Color.WHITE],
	["hair_sidepart_blonde", "가르마 머리 (금발)", "hair", 250, "sidepart", Color(0.95, 0.8, 0.4), Color(0.88, 0.2, 0.2)],
	["hair_sidepart_brown", "가르마 머리 (갈색)", "hair", 250, "sidepart", Color(0.45, 0.28, 0.15), Color(0.5, 0.78, 1.0)],
	["hat_wizard_purple", "마법사 모자 (보라)", "hair", 650, "wizard", Color(0.6, 0.35, 0.85), Color(1.0, 0.85, 0.3)],
	["hat_wizard_green", "마법사 모자 (초록)", "hair", 650, "wizard", Color(0.15, 0.45, 0.3), Color(0.8, 0.95, 1.0)],
	["hat_jester_blue", "광대 모자 (파랑)", "hair", 550, "jester", Color(0.2, 0.4, 0.9), Color(1.0, 0.85, 0.2)],
	["hat_jester_purple", "광대 모자 (보라)", "hair", 550, "jester", Color(0.6, 0.35, 0.85), Color(0.6, 0.88, 0.3)],
	["ears_fox_white", "흰 여우 귀", "hair", 450, "foxears", Color(0.96, 0.96, 0.98), Color(1.0, 0.7, 0.8)],
	["ears_fox_black", "검은 여우 귀", "hair", 450, "foxears", Color(0.15, 0.14, 0.16), Color(0.85, 0.85, 0.9)],
	["hair_bob_brown", "단발머리 (갈색)", "hair", 250, "bob", Color(0.45, 0.28, 0.15), Color.WHITE],
	["hair_bob_pink", "단발머리 (분홍)", "hair", 300, "bob", Color(1.0, 0.6, 0.75), Color.WHITE],
	["hair_bob_silver", "단발머리 (은발)", "hair", 350, "bob", Color(0.82, 0.84, 0.9), Color.WHITE],
	["hair_braids_brown", "땋은 머리 (갈색)", "hair", 300, "braids", Color(0.45, 0.28, 0.15), Color(1.0, 0.85, 0.25)],
	["hair_braids_black", "땋은 머리 (검정)", "hair", 300, "braids", Color(0.12, 0.1, 0.1), Color(1.0, 0.3, 0.6)],
	["hat_bandana_blue", "두건 (파랑)", "hair", 250, "bandana", Color(0.2, 0.4, 0.9), Color.WHITE],
	["hat_bandana_black", "두건 (검정)", "hair", 250, "bandana", Color(0.1, 0.1, 0.12), Color.WHITE],
	["hat_tiara_silver", "티아라 (은)", "hair", 800, "tiara", Color(0.78, 0.8, 0.85), Color(0.4, 0.75, 1.0)],
	["hat_duck_white", "머리 위 오리 (하양)", "hair", 450, "duck", Color(0.97, 0.97, 0.97), Color(1.0, 0.6, 0.1)],
	["hat_cap_green", "야구 모자 (초록)", "hair", 200, "cap", Color(0.25, 0.65, 0.35), Color.WHITE],
	["hat_cap_black", "야구 모자 (검정)", "hair", 200, "cap", Color(0.1, 0.1, 0.12), Color.WHITE],
	["hair_spiky_red", "뾰족 머리 (빨강)", "hair", 200, "spiky", Color(0.88, 0.2, 0.2), Color.WHITE],
	["hair_long_blonde", "긴 생머리 (금발)", "hair", 300, "long", Color(0.95, 0.8, 0.4), Color.WHITE],
	["horns_black", "검은 뿔", "hair", 500, "horns", Color(0.15, 0.13, 0.16), Color.WHITE],
	# ---------------------------------------------------------------- 옷 (100)
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
	["vest_brown", "조끼 (갈색)", "outfit", 300, "vest", Color(0.5, 0.3, 0.15), Color(0.96, 0.96, 0.94)],
	["cardigan_beige", "가디건 (베이지)", "outfit", 300, "cardigan", Color(0.92, 0.82, 0.65), Color(0.96, 0.96, 0.94)],
	["hanbok", "한복 (노랑·빨강)", "outfit", 800, "hanbok", Color(1.0, 0.85, 0.3), Color(0.85, 0.15, 0.22)],
	["poncho", "판초", "outfit", 400, "poncho", Color(0.9, 0.45, 0.2), Color(0.15, 0.55, 0.6)],
	["life_jacket", "구명조끼 (주황)", "outfit", 400, "lifejacket", Color(1.0, 0.45, 0.1), Color(0.15, 0.15, 0.17)],
	["firefighter", "소방관 옷", "outfit", 700, "firefighter", Color(0.3, 0.3, 0.26), Color(0.85, 1.0, 0.3)],
	["chef_coat", "요리사 옷", "outfit", 400, "chefcoat", Color(0.97, 0.97, 0.97), Color(0.85, 0.15, 0.2)],
	["costume_mummy", "미라 옷", "outfit", 600, "mummy", Color(0.9, 0.86, 0.74), Color.WHITE],
	["sweater_heart", "하트 스웨터 (하양)", "outfit", 350, "heartsweater", Color(0.97, 0.95, 0.9), Color(0.9, 0.15, 0.25)],
	["tanktop_white", "민소매 (하양)", "outfit", 150, "tanktop", Color(0.96, 0.96, 0.94), Color(0.2, 0.4, 0.85)],
	["dobok", "도복", "outfit", 450, "karate", Color(0.97, 0.97, 0.97), Color(0.08, 0.08, 0.1)],
	["cheer_red", "치어리더 (빨강)", "outfit", 450, "cheer", Color(0.88, 0.15, 0.2), Color(0.97, 0.97, 0.97)],
	["suit_scuba", "잠수복", "outfit", 650, "scuba", Color(0.1, 0.1, 0.12), Color(1.0, 0.82, 0.15)],
	["costume_cactus", "선인장 옷", "outfit", 650, "cactus", Color(0.3, 0.65, 0.3), Color(1.0, 0.45, 0.7)],
	["costume_shark", "상어 옷", "outfit", 750, "shark", Color(0.45, 0.55, 0.68), Color(0.97, 0.97, 0.97)],
	["costume_banana", "바나나 옷", "outfit", 600, "banana", Color(1.0, 0.85, 0.2), Color(0.98, 0.95, 0.8)],
	["puffer_black", "패딩 (검정)", "outfit", 450, "puffer", Color(0.12, 0.12, 0.14), Color(0.6, 0.6, 0.62)],
	["tracksuit_green", "트레이닝복 (초록)", "outfit", 350, "tracksuit", Color(0.15, 0.5, 0.3), Color(0.97, 0.97, 0.97)],
	["costume_robot", "상자 로봇 옷", "outfit", 700, "robotbox", Color(0.72, 0.74, 0.8), Color(0.9, 0.2, 0.2)],
	["costume_strawberry", "딸기 옷", "outfit", 650, "strawberry", Color(0.92, 0.15, 0.22), Color(0.3, 0.7, 0.3)],
	["dress_sky", "원피스 (하늘)", "outfit", 400, "dress", Color(0.55, 0.8, 1.0), Color(0.97, 0.97, 0.97)],
	["vest_black", "조끼 (검정)", "outfit", 300, "vest", Color(0.1, 0.1, 0.12), Color(0.96, 0.96, 0.94)],
	["vest_navy", "조끼 (남색)", "outfit", 300, "vest", Color(0.15, 0.2, 0.45), Color(0.75, 0.88, 1.0)],
	["vest_red", "조끼 (빨강)", "outfit", 300, "vest", Color(0.75, 0.08, 0.2), Color(0.96, 0.96, 0.94)],
	["cardigan_green", "가디건 (초록)", "outfit", 300, "cardigan", Color(0.25, 0.65, 0.35), Color(0.96, 0.96, 0.94)],
	["cardigan_pink", "가디건 (분홍)", "outfit", 300, "cardigan", Color(1.0, 0.6, 0.75), Color(0.96, 0.96, 0.94)],
	["cardigan_gray", "가디건 (회색)", "outfit", 300, "cardigan", Color(0.55, 0.56, 0.6), Color(0.15, 0.2, 0.45)],
	["hanbok_pink", "한복 (연두·분홍)", "outfit", 800, "hanbok", Color(0.65, 0.88, 0.45), Color(1.0, 0.45, 0.65)],
	["hanbok_navy", "한복 (하양·남색)", "outfit", 800, "hanbok", Color(0.97, 0.96, 0.92), Color(0.15, 0.2, 0.5)],
	["poncho_red", "판초 (빨강)", "outfit", 400, "poncho", Color(0.8, 0.15, 0.2), Color(1.0, 0.85, 0.3)],
	["life_jacket_yellow", "구명조끼 (노랑)", "outfit", 400, "lifejacket", Color(1.0, 0.85, 0.15), Color(0.15, 0.15, 0.17)],
	["chef_coat_black", "요리사 옷 (검정)", "outfit", 450, "chefcoat", Color(0.12, 0.12, 0.14), Color(0.97, 0.97, 0.97)],
	["sweater_heart_pink", "하트 스웨터 (분홍)", "outfit", 350, "heartsweater", Color(1.0, 0.6, 0.75), Color(0.85, 0.1, 0.2)],
	["sweater_heart_navy", "하트 스웨터 (남색)", "outfit", 350, "heartsweater", Color(0.15, 0.2, 0.45), Color(1.0, 0.6, 0.75)],
	["sweater_heart_green", "하트 스웨터 (초록)", "outfit", 350, "heartsweater", Color(0.25, 0.65, 0.35), Color(0.97, 0.95, 0.9)],
	["tanktop_black", "민소매 (검정)", "outfit", 150, "tanktop", Color(0.1, 0.1, 0.12), Color(0.5, 0.5, 0.55)],
	["tanktop_red", "민소매 (빨강)", "outfit", 150, "tanktop", Color(0.88, 0.2, 0.2), Color(0.97, 0.97, 0.97)],
	["tanktop_yellow", "민소매 (노랑)", "outfit", 150, "tanktop", Color(1.0, 0.85, 0.25), Color(0.2, 0.6, 0.35)],
	["dobok_blue", "도복 (파란 띠)", "outfit", 450, "karate", Color(0.97, 0.97, 0.97), Color(0.15, 0.35, 0.85)],
	["dobok_black", "도복 (검정)", "outfit", 550, "karate", Color(0.1, 0.1, 0.12), Color(0.85, 0.12, 0.15)],
	["cheer_blue", "치어리더 (파랑)", "outfit", 450, "cheer", Color(0.15, 0.35, 0.85), Color(1.0, 0.85, 0.2)],
	["cheer_pink", "치어리더 (분홍)", "outfit", 450, "cheer", Color(1.0, 0.45, 0.7), Color(0.97, 0.97, 0.97)],
	["suit_scuba_blue", "잠수복 (파랑)", "outfit", 650, "scuba", Color(0.12, 0.25, 0.6), Color(1.0, 0.5, 0.1)],
	["suit_scuba_red", "잠수복 (빨강)", "outfit", 650, "scuba", Color(0.6, 0.08, 0.1), Color(0.75, 0.78, 0.82)],
	["costume_shark_pink", "상어 옷 (분홍)", "outfit", 750, "shark", Color(1.0, 0.6, 0.75), Color(0.97, 0.97, 0.97)],
	["puffer_red", "패딩 (빨강)", "outfit", 450, "puffer", Color(0.88, 0.2, 0.2), Color(0.97, 0.97, 0.97)],
	["puffer_white", "패딩 (하양)", "outfit", 450, "puffer", Color(0.96, 0.96, 0.94), Color(0.55, 0.45, 0.35)],
	["puffer_yellow", "패딩 (노랑)", "outfit", 450, "puffer", Color(1.0, 0.85, 0.25), Color(0.3, 0.3, 0.32)],
	["tracksuit_red", "트레이닝복 (빨강)", "outfit", 350, "tracksuit", Color(0.88, 0.2, 0.2), Color(0.97, 0.97, 0.97)],
	["tracksuit_navy", "트레이닝복 (남색)", "outfit", 350, "tracksuit", Color(0.15, 0.2, 0.45), Color(1.0, 0.85, 0.2)],
	["tracksuit_pink", "트레이닝복 (분홍)", "outfit", 350, "tracksuit", Color(1.0, 0.6, 0.75), Color(0.97, 0.97, 0.97)],
	["dress_pink", "원피스 (분홍)", "outfit", 400, "dress", Color(1.0, 0.6, 0.75), Color(0.97, 0.97, 0.97)],
	["dress_yellow", "원피스 (노랑)", "outfit", 400, "dress", Color(1.0, 0.85, 0.25), Color(0.97, 0.97, 0.97)],
	["dress_purple", "원피스 (보라)", "outfit", 400, "dress", Color(0.75, 0.65, 0.95), Color(0.6, 0.35, 0.85)],
	["dress_red", "원피스 (빨강)", "outfit", 450, "dress", Color(0.75, 0.08, 0.2), Color(1.0, 0.85, 0.3)],
	["hoodie_green", "후드티 (초록)", "outfit", 300, "hoodie", Color(0.35, 0.65, 0.4), Color(0.2, 0.2, 0.25)],
	["hoodie_yellow", "후드티 (노랑)", "outfit", 300, "hoodie", Color(1.0, 0.82, 0.3), Color(0.25, 0.3, 0.45)],
	["hoodie_black", "후드티 (검정)", "outfit", 300, "hoodie", Color(0.12, 0.12, 0.14), Color(0.35, 0.35, 0.4)],
	["tee_green", "티셔츠 (초록)", "outfit", 100, "tee", Color(0.3, 0.7, 0.4), Color(0.2, 0.22, 0.3)],
	["tee_purple", "티셔츠 (보라)", "outfit", 100, "tee", Color(0.6, 0.4, 0.85), Color(0.2, 0.2, 0.25)],
	["overalls_pink", "멜빵바지 (분홍)", "outfit", 300, "overalls", Color(1.0, 0.6, 0.75), Color(0.97, 0.97, 0.97)],
	["raincoat_pink", "분홍 우비", "outfit", 350, "raincoat", Color(1.0, 0.55, 0.7), Color(0.97, 0.97, 0.97)],
	["sweater_green", "줄무늬 스웨터 (초록)", "outfit", 250, "stripes", Color(0.2, 0.55, 0.3), Color(0.95, 0.92, 0.85)],
	# ---------------------------------------------------------------- 장신구 (100)
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
	["wand_star", "별 요술봉", "acc", 500, "wand", Color(1.0, 0.85, 0.25), Color(1.0, 0.55, 0.75)],
	["foam_sword", "스펀지 칼 (파랑)", "acc", 350, "foamsword", Color(0.3, 0.55, 1.0), Color(1.0, 0.85, 0.2)],
	["toy_shield", "장난감 방패 (빨강)", "acc", 400, "shield", Color(0.88, 0.2, 0.2), Color(0.97, 0.97, 0.97)],
	["lantern", "등불", "acc", 450, "lantern", Color(0.25, 0.22, 0.2), Color(1.0, 0.7, 0.25)],
	["camera", "카메라", "acc", 450, "camera", Color(0.12, 0.12, 0.14), Color(0.85, 0.15, 0.2)],
	["book", "그림책 (파랑)", "acc", 250, "book", Color(0.2, 0.4, 0.85), Color(0.98, 0.96, 0.9)],
	["coffee", "커피 컵", "acc", 200, "coffee", Color(0.97, 0.97, 0.95), Color(0.55, 0.35, 0.2)],
	["icecream", "아이스크림 (딸기·민트)", "acc", 250, "icecream", Color(1.0, 0.6, 0.75), Color(0.6, 0.95, 0.8)],
	["fish", "생선", "acc", 300, "fish", Color(0.55, 0.65, 0.8), Color(0.95, 0.95, 0.97)],
	["shoulder_duck", "어깨 오리", "acc", 450, "duck", Color(1.0, 0.85, 0.2), Color(1.0, 0.5, 0.1)],
	["kite", "연 (빨강)", "acc", 400, "kite", Color(0.9, 0.2, 0.2), Color(1.0, 0.85, 0.25)],
	["maracas", "마라카스", "acc", 350, "maracas", Color(0.3, 0.75, 0.35), Color(1.0, 0.85, 0.2)],
	["bubble_wand", "비눗방울", "acc", 400, "bubblewand", Color(0.6, 0.85, 1.0), Color(1.0, 0.5, 0.75)],
	["jetpack", "제트팩", "acc", 1000, "jetpack", Color(0.78, 0.8, 0.85), Color(0.88, 0.15, 0.2)],
	["medal_gold", "금메달", "acc", 600, "medal", Color(1.0, 0.8, 0.25), Color(0.85, 0.15, 0.2)],
	["fanny_pack", "힙색 (검정)", "acc", 250, "fannypack", Color(0.12, 0.12, 0.14), Color(0.9, 0.2, 0.2)],
	["wristwatch", "손목시계", "acc", 300, "watch", Color(0.78, 0.8, 0.85), Color(0.12, 0.12, 0.14)],
	["bell_collar", "방울 목걸이", "acc", 300, "bell", Color(1.0, 0.8, 0.25), Color(0.85, 0.15, 0.2)],
	["magnifier", "돋보기", "acc", 300, "magnifier", Color(1.0, 0.8, 0.3), Color(0.5, 0.3, 0.15)],
	["microphone", "마이크", "acc", 400, "mic", Color(0.12, 0.12, 0.14), Color(0.78, 0.8, 0.85)],
	["boba_tea", "버블티 (밀크티)", "acc", 250, "bobatea", Color(0.85, 0.7, 0.55), Color(1.0, 0.5, 0.7)],
	["donut", "도넛 (분홍)", "acc", 200, "donut", Color(1.0, 0.6, 0.75), Color.WHITE],
	["carrot", "당근", "acc", 150, "carrot", Color(1.0, 0.5, 0.1), Color(0.3, 0.7, 0.3)],
	["lightstick", "응원봉 (분홍)", "acc", 450, "lightstick", Color(1.0, 0.45, 0.75), Color(0.97, 0.97, 0.97)],
	["hand_fan", "태극 부채", "acc", 350, "fan", Color(0.15, 0.3, 0.75), Color(0.85, 0.12, 0.2)],
	["wand_silver", "은빛 요술봉", "acc", 500, "wand", Color(0.8, 0.9, 1.0), Color(0.4, 0.55, 0.95)],
	["wand_pink", "분홍 요술봉", "acc", 500, "wand", Color(1.0, 0.5, 0.8), Color(0.97, 0.97, 0.97)],
	["foam_sword_red", "스펀지 칼 (빨강)", "acc", 350, "foamsword", Color(0.95, 0.3, 0.3), Color(0.25, 0.25, 0.3)],
	["foam_sword_green", "스펀지 칼 (초록)", "acc", 350, "foamsword", Color(0.4, 0.85, 0.35), Color(0.6, 0.35, 0.85)],
	["foam_sword_purple", "스펀지 칼 (보라)", "acc", 350, "foamsword", Color(0.65, 0.4, 0.95), Color(1.0, 0.85, 0.2)],
	["toy_shield_blue", "장난감 방패 (파랑)", "acc", 400, "shield", Color(0.2, 0.4, 0.9), Color(1.0, 0.85, 0.25)],
	["toy_shield_green", "장난감 방패 (초록)", "acc", 400, "shield", Color(0.25, 0.65, 0.35), Color(0.97, 0.97, 0.97)],
	["lantern_blue", "푸른 등불", "acc", 500, "lantern", Color(0.25, 0.22, 0.2), Color(0.4, 0.75, 1.0)],
	["lantern_green", "도깨비불 등불", "acc", 500, "lantern", Color(0.2, 0.22, 0.2), Color(0.4, 1.0, 0.5)],
	["camera_white", "카메라 (하양)", "acc", 450, "camera", Color(0.95, 0.95, 0.93), Color(0.5, 0.78, 1.0)],
	["book_red", "그림책 (빨강)", "acc", 250, "book", Color(0.85, 0.2, 0.2), Color(0.98, 0.96, 0.9)],
	["book_green", "그림책 (초록)", "acc", 250, "book", Color(0.25, 0.6, 0.35), Color(0.98, 0.96, 0.9)],
	["coffee_green", "커피 컵 (초록)", "acc", 200, "coffee", Color(0.97, 0.97, 0.95), Color(0.2, 0.5, 0.3)],
	["icecream_choco", "아이스크림 (초코·바닐라)", "acc", 250, "icecream", Color(0.45, 0.28, 0.16), Color(0.98, 0.95, 0.82)],
	["icecream_mint", "아이스크림 (민트·초코)", "acc", 250, "icecream", Color(0.6, 0.95, 0.8), Color(0.45, 0.28, 0.16)],
	["goldfish", "금붕어", "acc", 350, "fish", Color(1.0, 0.5, 0.15), Color(1.0, 0.95, 0.85)],
	["shoulder_duck_white", "어깨 오리 (하양)", "acc", 450, "duck", Color(0.97, 0.97, 0.97), Color(1.0, 0.6, 0.1)],
	["kite_blue", "연 (파랑)", "acc", 400, "kite", Color(0.2, 0.45, 0.9), Color(0.97, 0.97, 0.97)],
	["kite_green", "연 (초록)", "acc", 400, "kite", Color(0.3, 0.7, 0.35), Color(1.0, 0.5, 0.2)],
	["maracas_pink", "마라카스 (분홍)", "acc", 350, "maracas", Color(1.0, 0.5, 0.75), Color(0.5, 0.85, 1.0)],
	["maracas_blue", "마라카스 (파랑)", "acc", 350, "maracas", Color(0.25, 0.45, 0.95), Color(1.0, 0.5, 0.2)],
	["bubble_wand_pink", "비눗방울 (분홍)", "acc", 400, "bubblewand", Color(1.0, 0.7, 0.9), Color(0.4, 0.7, 1.0)],
	["jetpack_gold", "황금 제트팩", "acc", 1200, "jetpack", Color(1.0, 0.8, 0.25), Color(0.12, 0.12, 0.14)],
	["medal_silver", "은메달", "acc", 450, "medal", Color(0.8, 0.82, 0.87), Color(0.2, 0.4, 0.85)],
	["medal_bronze", "동메달", "acc", 350, "medal", Color(0.8, 0.5, 0.3), Color(0.25, 0.6, 0.35)],
	["fanny_pack_pink", "힙색 (분홍)", "acc", 250, "fannypack", Color(1.0, 0.6, 0.75), Color(0.97, 0.97, 0.97)],
	["fanny_pack_khaki", "힙색 (카키)", "acc", 250, "fannypack", Color(0.5, 0.52, 0.3), Color(1.0, 0.55, 0.15)],
	["wristwatch_gold", "금 손목시계", "acc", 500, "watch", Color(1.0, 0.8, 0.3), Color(0.45, 0.28, 0.15)],
	["bell_collar_silver", "방울 목걸이 (은)", "acc", 300, "bell", Color(0.8, 0.82, 0.87), Color(0.2, 0.45, 0.9)],
	["microphone_gold", "황금 마이크", "acc", 700, "mic", Color(1.0, 0.8, 0.25), Color(0.12, 0.12, 0.14)],
	["microphone_pink", "마이크 (분홍)", "acc", 400, "mic", Color(1.0, 0.5, 0.75), Color(0.97, 0.97, 0.97)],
	["boba_tea_matcha", "버블티 (말차)", "acc", 250, "bobatea", Color(0.55, 0.78, 0.4), Color(0.25, 0.6, 0.35)],
	["boba_tea_strawberry", "버블티 (딸기)", "acc", 250, "bobatea", Color(1.0, 0.6, 0.7), Color(0.85, 0.15, 0.25)],
	["boba_tea_taro", "버블티 (타로)", "acc", 250, "bobatea", Color(0.75, 0.6, 0.9), Color(0.5, 0.3, 0.75)],
	["donut_choco", "도넛 (초코)", "acc", 200, "donut", Color(0.4, 0.24, 0.14), Color(1.0, 0.85, 0.3)],
	["donut_white", "도넛 (하양)", "acc", 200, "donut", Color(0.97, 0.96, 0.92), Color(1.0, 0.5, 0.7)],
	["lightstick_sky", "응원봉 (하늘)", "acc", 450, "lightstick", Color(0.4, 0.8, 1.0), Color(0.97, 0.97, 0.97)],
	["lightstick_yellow", "응원봉 (노랑)", "acc", 450, "lightstick", Color(1.0, 0.88, 0.25), Color(0.15, 0.15, 0.17)],
	["lightstick_purple", "응원봉 (보라)", "acc", 450, "lightstick", Color(0.7, 0.4, 1.0), Color(0.97, 0.97, 0.97)],
	["hand_fan_pink", "둥근 부채 (분홍·보라)", "acc", 350, "fan", Color(0.7, 0.45, 0.9), Color(1.0, 0.55, 0.75)],
	["balloon_blue", "풍선 (파랑)", "acc", 300, "balloon", Color(0.3, 0.55, 1.0), Color(0.95, 0.95, 0.95)],
	["balloon_yellow", "풍선 (노랑)", "acc", 300, "balloon", Color(1.0, 0.85, 0.2), Color(0.95, 0.95, 0.95)],
	["lollipop_green", "막대사탕 (초록)", "acc", 200, "lollipop", Color(0.45, 0.9, 0.4), Color(0.98, 0.98, 0.98)],
	["umbrella_pink", "우산 (분홍)", "acc", 400, "umbrella", Color(1.0, 0.55, 0.75), Color(0.95, 0.95, 0.95)],
	["umbrella_yellow", "우산 (노랑)", "acc", 400, "umbrella", Color(1.0, 0.82, 0.2), Color(0.3, 0.6, 1.0)],
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

	func _node(parent: Node3D, pos: Vector3, rot := Vector3.ZERO) -> Node3D:
		var n := Node3D.new()
		n.position = pos
		n.rotation = rot
		parent.add_child(n)
		return n

	## 손에 든 물건의 기준점 (팔 노드 안, 손끝 근처). 기준점의 +Y 가 물건이 뻗는 방향
	func _hand(right: bool, pos := Vector3(0, -0.38, 0.06), rot := Vector3.ZERO) -> Node3D:
		return _node(arm(right), pos, rot)

	func _metal(c: Color, mt := 0.8) -> StandardMaterial3D:
		var g := flat(c)
		g.metallic = mt
		g.roughness = 0.25
		return g

	func _glass(c: Color, a := 0.3) -> StandardMaterial3D:
		var g := flat(Color(c.r, c.g, c.b, a))
		g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		g.roughness = 0.05
		g.metallic = 0.2
		return g

	func _skin() -> StandardMaterial3D:
		var sm: StandardMaterial3D = body.get("_mat")
		return clay(sm.albedo_color)

	## 몸통 앞면 위의 점 (x, y 를 주면 z 를 몸통 표면에 맞춤)
	func _torso_pt(x: float, y: float, out := 0.01) -> Vector3:
		var k: float = 1.0 - pow(x / 0.32, 2.0) - pow((y - 0.66) / 0.4, 2.0)
		return Vector3(x, y, 0.288 * sqrt(maxf(k, 0.0)) + out)

	## 높이 y 에서 몸통 가로 반지름
	func _torso_r(y: float) -> float:
		return 0.32 * sqrt(maxf(0.0, 1.0 - pow((y - 0.66) / 0.4, 2.0)))

	func _heart(parent: Node3D, pos: Vector3, k: float, mat: Material) -> Node3D:
		var h := _node(parent, pos)
		h.scale = Vector3.ONE * k
		sph(h, Vector3(-0.03, 0.02, 0), 0.04, mat, Vector3(1, 1, 0.5))
		sph(h, Vector3(0.03, 0.02, 0), 0.04, mat, Vector3(1, 1, 0.5))
		prism(h, Vector3(0, -0.035, 0), Vector3(0.12, 0.08, 0.03), mat, Vector3(0, 0, PI))
		return h

	func _label(parent: Node3D, text: String, pos: Vector3, col: Color, size := 80, rot := Vector3.ZERO) -> Label3D:
		var lbl := Label3D.new()
		lbl.text = text
		lbl.font_size = size
		lbl.modulate = col
		lbl.outline_size = 0
		lbl.pixel_size = 0.002
		lbl.position = pos
		lbl.rotation = rot
		lbl.layers = 2
		parent.add_child(lbl)
		lbl.add_to_group("cosmetic")
		return lbl

	## 머리 표면에서 바깥쪽을 향하는 원뿔 (뾰족 머리카락, 가시)
	func _spike(parent: Node3D, at: Vector3, dir: Vector3, r: float, h: float, mat: Material) -> MeshInstance3D:
		var d := dir.normalized()
		var c := cone(parent, at + d * h * 0.4, r, h, mat)
		c.basis = Basis(Quaternion(Vector3.UP, d))
		return c

	# ---------------------------------------------------------------- 눈

	func _eye_pair(r: float, scl: Vector3, mat: Material, x := 0.135, y := 1.27, z := 0.35) -> Array:
		var out := []
		for s in [-1.0, 1.0]:
			out.append(sph(torso, Vector3(x * s, y, z), r, mat, scl))
		return out

	func _shine(x := 0.135, y := 1.27, big := 1.0, z := 0.386) -> void:
		var w := flat(Color.WHITE, true)
		for s in [-1.0, 1.0]:
			sph(torso, Vector3(x * s + 0.026, y + 0.04, z), 0.023 * big, w, Vector3(1, 1, 0.5))
			sph(torso, Vector3(x * s - 0.02, y - 0.025, z + 0.004), 0.011 * big, w, Vector3(1, 1, 0.5))

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
				_brows(0.45, 1.37)  # 바깥쪽이 올라가고 안쪽이 내려감 = 화남
			"sad":
				_eye_pair(0.08, Vector3(0.85, 1.15, 0.45), dark)
				_shine()
				_brows(-0.4, 1.385)  # 안쪽이 올라감 = 시무룩
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
			"smug":
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.245, 0.352), 0.085, dark, Vector3(0.95, 0.85, 0.45), true)
					sph(torso, Vector3(0.135 * s + 0.025, 1.275, 0.39), 0.016, flat(Color.WHITE, true), Vector3(1, 1, 0.5))
			"bored":
				for s in [-1.0, 1.0]:
					var e := sph(torso, Vector3(0.135 * s, 1.3, 0.352), 0.085, dark, Vector3(0.95, 0.8, 0.45), true)
					e.rotation.z = PI
					cap(torso, Vector3(0.135 * s, 1.302, 0.37), 0.014, 0.18, dark, Vector3(0, 0.3 * s, PI / 2.0))
					sph(torso, Vector3(0.135 * s + 0.02, 1.27, 0.388), 0.012, flat(Color.WHITE, true), Vector3(1, 1, 0.5))
			"bigpupil":
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.27, 0.345), 0.1, flat(Color.WHITE), Vector3(0.9, 1.1, 0.45))
					sph(torso, Vector3(0.135 * s, 1.26, 0.378), 0.075, dark, Vector3(0.95, 1.05, 0.45))
				_shine(0.135, 1.27, 1.5, 0.41)
			"starpupil":
				var star := StarMesh.make()
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.27, 0.345), 0.095, flat(Color.WHITE), Vector3(0.9, 1.1, 0.45))
					sph(torso, Vector3(0.135 * s, 1.265, 0.37), 0.072, flat(c1), Vector3(0.95, 1.1, 0.45))
					add(torso, star, glow(c2, 1.2), Vector3(0.135 * s, 1.265, 0.402), Vector3(0, 0.3 * s, 0), Vector3.ONE * 0.042)
			"shock":
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.28, 0.34), 0.11, flat(Color.WHITE), Vector3(1, 1.05, 0.45))
					sph(torso, Vector3(0.135 * s, 1.28, 0.388), 0.024, dark, Vector3(1, 1, 0.5))
				_brows(-0.15, 1.43)
			"tearstream":
				var tear := glow(c2, 0.5)
				for s in [-1.0, 1.0]:
					cap(torso, Vector3(0.135 * s, 1.275, 0.378), 0.016, 0.12, dark, Vector3(0, 0.3 * s, PI / 2.0 - 0.3 * s))
					cap(torso, Vector3(0.15 * s, 1.12, 0.325), 0.024, 0.24, tear, Vector3(0.6, 0, 0))
					sph(torso, Vector3(0.16 * s, 0.97, 0.25), 0.032, tear, Vector3(1.0, 1.3, 1.0))
				_brows(-0.4, 1.385)
			"ghost":
				var pin := glow(c2, 1.5)
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.27, 0.345), 0.095, dark, Vector3(0.8, 1.35, 0.45))
					sph(torso, Vector3(0.135 * s, 1.25, 0.389), 0.018, pin, Vector3(1, 1, 0.5))
			"pixel":
				var bk := flat(c1)
				var hl := flat(c2, true)
				box(torso, Vector3(0, 1.315, 0.392), Vector3(0.1, 0.03, 0.03), bk)
				for s in [-1.0, 1.0]:
					var g := _node(torso, Vector3(0.14 * s, 1.27, 0.384), Vector3(0, 0.33 * s, 0))
					box(g, Vector3(0, 0.045, 0), Vector3(0.2, 0.03, 0.035), bk)
					box(g, Vector3(0, 0.015, 0), Vector3(0.2, 0.03, 0.035), bk)
					box(g, Vector3(0, -0.015, 0), Vector3(0.14, 0.03, 0.035), bk)
					box(g, Vector3(0, -0.045, 0), Vector3(0.08, 0.03, 0.035), bk)
					box(g, Vector3(-0.05, 0.015, 0.012), Vector3(0.03, 0.03, 0.02), hl)
					box(g, Vector3(-0.02, -0.015, 0.012), Vector3(0.03, 0.03, 0.02), hl)
			"heartpupil":
				var hm := glow(c1, 0.5)
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.27, 0.345), 0.095, flat(Color.WHITE), Vector3(0.9, 1.1, 0.45))
					_heart(torso, Vector3(0.135 * s, 1.27, 0.388), 0.6, hm)
			"tired":
				_eye_pair(0.075, Vector3(0.85, 1.05, 0.45), dark)
				var lid := _skin()
				var bag := flat(c2)
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.3, 0.351), 0.085, lid, Vector3(1.05, 0.55, 0.45))
					cap(torso, Vector3(0.135 * s, 1.2, 0.37), 0.013, 0.13, bag, Vector3(0, 0.3 * s, PI / 2.0))
					cap(torso, Vector3(0.135 * s, 1.177, 0.362), 0.011, 0.09, bag, Vector3(0, 0.3 * s, PI / 2.0))
			"squint":
				for s in [-1.0, 1.0]:
					cap(torso, Vector3(0.14 * s, 1.288, 0.378), 0.016, 0.085, dark, Vector3(0, 0.3 * s, -1.107 * s))
					cap(torso, Vector3(0.14 * s, 1.252, 0.378), 0.016, 0.085, dark, Vector3(0, 0.3 * s, 1.107 * s))
			"gem":
				var g := flat(c1)
				g.metallic = 0.4
				g.roughness = 0.08
				var rim := flat(c1.darkened(0.55))
				var facet := glow(c1.lightened(0.5), 0.6)
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.27, 0.35), 0.088, rim, Vector3(0.88, 1.2, 0.45))
					sph(torso, Vector3(0.135 * s, 1.255, 0.372), 0.065, g, Vector3(0.9, 1.15, 0.4))
					prism(torso, Vector3(0.135 * s, 1.235, 0.4), Vector3(0.05, 0.05, 0.01), facet, Vector3(0, 0, PI))
				_shine(0.135, 1.28, 1.3, 0.398)
			"uu":
				for s in [-1.0, 1.0]:
					var x: float = 0.135 * s
					cap(torso, Vector3(x, 1.252, 0.381), 0.015, 0.07, dark, Vector3(0, 0.3 * s, PI / 2.0))
					cap(torso, Vector3(x - 0.04, 1.275, 0.378), 0.015, 0.06, dark, Vector3(0, 0.3 * s, 0.45))
					cap(torso, Vector3(x + 0.04, 1.275, 0.378), 0.015, 0.06, dark, Vector3(0, 0.3 * s, -0.45))
			"dollar":
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.27, 0.345), 0.095, flat(c2), Vector3(0.9, 1.1, 0.45))
					_label(torso, "$", Vector3(0.135 * s, 1.27, 0.394), c1, 80, Vector3(0, 0.33 * s, 0))
			"goat":
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.27, 0.35), 0.088, flat(c1), Vector3(0.95, 1.0, 0.45))
					sph(torso, Vector3(0.135 * s, 1.27, 0.385), 0.065, flat(c2), Vector3(1.0, 0.25, 0.3))
				_shine(0.135, 1.27, 0.9, 0.392)
			"googly":
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.28, 0.34), 0.1, flat(Color.WHITE), Vector3(1, 1, 0.8))
				sph(torso, Vector3(-0.115, 1.25, 0.415), 0.045, dark, Vector3(1, 1, 0.5))
				sph(torso, Vector3(0.165, 1.31, 0.41), 0.045, dark, Vector3(1, 1, 0.5))
			"calm":
				for s in [-1.0, 1.0]:
					var x: float = 0.135 * s
					cap(torso, Vector3(x, 1.26, 0.38), 0.015, 0.12, dark, Vector3(0, 0.3 * s, PI / 2.0))
					for k in 3:
						cap(torso, Vector3(x + k * 0.03 * s, 1.24, 0.372 - k * 0.008), 0.007, 0.04, dark, Vector3(0, 0, s * (0.2 + k * 0.3)))
			"panda":
				var patch := flat(c2)
				for s in [-1.0, 1.0]:
					var p := sph(torso, Vector3(0.14 * s, 1.255, 0.345), 0.115, patch, Vector3(0.85, 1.1, 0.4))
					p.rotation.z = 0.45 * s
					sph(torso, Vector3(0.135 * s, 1.27, 0.384), 0.062, flat(Color.WHITE), Vector3(1, 1, 0.45))
					sph(torso, Vector3(0.135 * s, 1.265, 0.405), 0.036, dark, Vector3(1, 1, 0.45))
				_shine(0.135, 1.27, 0.7, 0.423)
			"unibrow":
				_eye_pair(0.08, Vector3(0.85, 1.15, 0.45), dark)
				_shine()
				var bm := clay(c2)
				cap(torso, Vector3(0, 1.385, 0.375), 0.032, 0.16, bm, Vector3(0, 0, PI / 2.0))
				for s in [-1.0, 1.0]:
					cap(torso, Vector3(0.14 * s, 1.39, 0.355), 0.03, 0.14, bm, Vector3(0, 0.35 * s, PI / 2.0 + 0.2 * s))
			"galaxy":
				var dotm := glow(c2, 2.0)
				var dots := [Vector3(-0.03, 0.02, 0), Vector3(0.025, -0.03, 0), Vector3(0.0, -0.06, 0), Vector3(-0.035, -0.035, 0), Vector3(0.035, 0.045, 0)]
				for s in [-1.0, 1.0]:
					var x: float = 0.135 * s
					sph(torso, Vector3(x, 1.27, 0.35), 0.095, flat(c1), Vector3(0.88, 1.15, 0.45))
					for i in dots.size():
						var d: Vector3 = dots[i]
						sph(torso, Vector3(x, 1.27, 0.388) + d, 0.008 + 0.004 * (i % 2), dotm, Vector3(1, 1, 0.5))
				_shine(0.135, 1.27, 1.2, 0.392)
			"puppy":
				var wet := _glass(c2, 0.55)
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.135 * s, 1.265, 0.345), 0.105, flat(Color(0.05, 0.04, 0.06)), Vector3(0.9, 1.1, 0.45))
					sph(torso, Vector3(0.135 * s, 1.25, 0.37), 0.075, flat(c1), Vector3(0.95, 1.05, 0.45))
					sph(torso, Vector3(0.135 * s, 1.18, 0.382), 0.05, wet, Vector3(1.6, 0.5, 0.5))
				_shine(0.135, 1.28, 1.8, 0.4)
				_brows(-0.35, 1.41)

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
			"beret":
				var b := sph(torso, Vector3(0.04, 1.6, -0.02), 0.36, m, Vector3(1.25, 0.38, 1.22))
				b.rotation.z = -0.22
				cyl(torso, Vector3(0, 1.5, -0.01), 0.36, 0.37, 0.05, clay(c1.darkened(0.25)))
				cyl(torso, Vector3(0.03, 1.74, -0.02), 0.012, 0.022, 0.07, m, Vector3(0, 0, -0.22))
			"cowboy":
				var brim := cyl(torso, Vector3(0, 1.56, 0), 0.46, 0.46, 0.035, m)
				brim.scale = Vector3(1.0, 1.0, 0.85)
				for s in [-1.0, 1.0]:
					var flap := sph(torso, Vector3(0.47 * s, 1.6, 0), 0.2, m, Vector3(0.55, 0.12, 1.2))
					flap.rotation.z = 0.6 * s
				cyl(torso, Vector3(0, 1.72, 0), 0.24, 0.3, 0.32, m)
				sph(torso, Vector3(0, 1.88, 0), 0.24, m, Vector3(1, 0.3, 0.9))
				box(torso, Vector3(0, 1.9, 0), Vector3(0.04, 0.03, 0.3), clay(c1.darkened(0.3)))
				cyl(torso, Vector3(0, 1.61, 0), 0.305, 0.305, 0.06, m2)
			"bucket":
				cyl(torso, Vector3(0, 1.5, 0), 0.4, 0.54, 0.1, m)
				cyl(torso, Vector3(0, 1.66, 0), 0.3, 0.38, 0.26, m)
				sph(torso, Vector3(0, 1.79, 0), 0.3, m, Vector3(1, 0.3, 1))
				cyl(torso, Vector3(0, 1.58, 0), 0.385, 0.385, 0.06, m2)
			"hardhat":
				var dome := sph(torso, Vector3(0, 1.4, 0), 0.43, m, Vector3(1.0, 0.95, 1.05), true)
				dome.rotation.x = -0.08
				var brim := cyl(torso, Vector3(0, 1.41, 0.04), 0.5, 0.5, 0.03, m, Vector3(-0.08, 0, 0))
				brim.scale = Vector3(0.95, 1.0, 1.05)
				sph(torso, Vector3(0, 1.7, 0), 0.1, m, Vector3(0.45, 1.1, 3.0))
				cyl(torso, Vector3(0, 1.55, 0.43), 0.06, 0.06, 0.04, flat(Color(0.3, 0.3, 0.32)), Vector3(PI / 2.0 - 0.5, 0, 0))
				cyl(torso, Vector3(0, 1.56, 0.45), 0.045, 0.045, 0.01, glow(c2, 2.0), Vector3(PI / 2.0 - 0.5, 0, 0))
			"sweatband":
				_hair_cap(m)
				for i in 4:
					var a: float = -0.5 + i * 0.33
					var p := head_pt(a, 1.05, -0.02)
					_spike(torso, p, p - Vector3(0, 1.28, 0), 0.07, 0.17, m)
				torus(torso, Vector3(0, 1.44, 0), 0.355, 0.405, m2, Vector3(-0.05, 0, 0))
				torus(torso, Vector3(0, 1.44, 0), 0.4, 0.41, clay(Color.WHITE), Vector3(-0.05, 0, 0))
			"bow":
				_hair_cap(m)
				var bw := _node(torso, Vector3(0.2, 1.66, 0.08), Vector3(-0.3, 0, -0.45))
				for s in [-1.0, 1.0]:
					prism(bw, Vector3(0.09 * s, 0, 0), Vector3(0.15, 0.17, 0.06), m2, Vector3(0, 0, -PI / 2.0 * s))
					box(bw, Vector3(0.04 * s, -0.1, 0), Vector3(0.05, 0.14, 0.03), m2, Vector3(0, 0, 0.35 * s))
				sph(bw, Vector3.ZERO, 0.045, m2)
			"spacebuns":
				_hair_cap(m)
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.24 * s, 1.66, -0.04), 0.13, m)
					torus(torso, Vector3(0.198 * s, 1.593, -0.035), 0.08, 0.11, m2, Vector3(0, 0, -0.56 * s))
			"topknot":
				_hair_cap(m, -0.3)
				cap(torso, Vector3(0, 1.76, -0.14), 0.075, 0.24, m, Vector3(-0.35, 0, 0))
				torus(torso, Vector3(0, 1.69, -0.115), 0.05, 0.085, m2, Vector3(-0.35, 0, 0))
				for s in [-1.0, 1.0]:
					box(torso, Vector3(0.375 * s, 1.2, 0.05), Vector3(0.05, 0.16, 0.08), m)
			"mullet":
				_hair_cap(m, -0.35)
				for i in 3:
					var a: float = -0.35 + i * 0.35
					var p := head_pt(a, 0.85, 0.0)
					_spike(torso, p, p - Vector3(0, 1.28, 0), 0.07, 0.16, m)
				box(torso, Vector3(0, 1.05, -0.36), Vector3(0.5, 0.42, 0.14), m, Vector3(0.25, 0, 0))
				for s in [-1.0, 0.0, 1.0]:
					prism(torso, Vector3(0.15 * s, 0.8, -0.41), Vector3(0.16, 0.1, 0.12), m, Vector3(0.25, 0, PI))
			"sidepart":
				_hair_cap(m, -0.3, 0.43)
				var sw := sph(torso, Vector3(-0.1, 1.56, 0.22), 0.22, m, Vector3(1.45, 0.55, 0.85))
				sw.rotation = Vector3(-0.5, 0.0, 0.3)
				sph(torso, Vector3(0.24, 1.5, 0.24), 0.1, m, Vector3(1.0, 0.7, 0.7))
				box(torso, Vector3(0.2, 1.52, 0.29), Vector3(0.09, 0.022, 0.02), clay(c2), Vector3(0, 0.6, 0.4))
			"wizard":
				torus(torso, Vector3(0, 1.56, 0), 0.32, 0.42, m2, Vector3(-0.12, 0, 0))
				var body_c := cyl(torso, Vector3(0, 1.74, -0.03), 0.08, 0.36, 0.42, m, Vector3(-0.12, 0, 0))
				var pivot := _node(body_c, Vector3(0, 0.2, 0), Vector3(0, 0, -0.9))
				var tip := cone(pivot, Vector3(0, 0.16, 0), 0.08, 0.34, m)
				sph(tip, Vector3(0, 0.17, 0), 0.035, glow(c2, 1.0))
				var star := StarMesh.make()
				var sm := glow(c2, 0.8)
				for e in [[0.4, 1.62], [-0.7, 1.72], [1.5, 1.82], [-1.6, 1.62]]:
					var a: float = e[0]
					var y: float = e[1]
					var r: float = 0.36 - (y - 1.53) * 0.667 + 0.012
					add(torso, star, sm, Vector3(sin(a) * r, y, cos(a) * r - 0.03), Vector3(-0.55, a, 0), Vector3.ONE * 0.05)
			"jester":
				var dome := sph(torso, Vector3(0, 1.36, -0.01), 0.425, m, Vector3.ONE, true)
				dome.rotation.x = -0.15
				torus(torso, Vector3(0, 1.4, 0.02), 0.38, 0.44, m2, Vector3(-0.15, 0, 0))
				var gold := _metal(Color(1.0, 0.8, 0.25))
				for i in 3:
					var dir: float = -1.0 + i
					var root := _node(torso, Vector3(0.12 * dir, 1.7, -0.06), Vector3(-0.5 * (1.0 - absf(dir)), 0, -1.0 * dir))
					var mat: Material = m2 if i == 1 else m
					cone(root, Vector3(0, 0.17, 0), 0.1, 0.36, mat)
					var bell := sph(root, Vector3(0, 0.37, 0), 0.045, gold)
					spin(bell, "bob")
			"foxears":
				var tipm := clay(c1.darkened(0.5))
				for s in [-1.0, 1.0]:
					var ear := prism(torso, Vector3(0.21 * s, 1.72, -0.02), Vector3(0.24, 0.34, 0.09), m, Vector3(-0.1, 0, -0.38 * s))
					prism(ear, Vector3(0, -0.03, 0.035), Vector3(0.14, 0.22, 0.04), m2)
					prism(ear, Vector3(0, 0.12, 0.0), Vector3(0.085, 0.1, 0.095), tipm)
			"antlers":
				for s in [-1.0, 1.0]:
					var root := _node(torso, Vector3(0.18 * s, 1.62, -0.02), Vector3(0, 0, -0.45 * s))
					cyl(root, Vector3(0, 0.16, 0), 0.025, 0.035, 0.32, m)
					cyl(root, Vector3(0.063 * s, 0.21, 0), 0.018, 0.025, 0.16, m, Vector3(0, 0, -0.9 * s))
					cyl(root, Vector3(-0.05 * s, 0.31, 0), 0.016, 0.022, 0.14, m, Vector3(0, 0, 0.8 * s))
					sph(root, Vector3(0, 0.32, 0), 0.026, m)
					var ear := sph(torso, Vector3(0.38 * s, 1.48, -0.02), 0.08, m2, Vector3(1.5, 0.55, 0.6))
					ear.rotation.z = 0.3 * s
			"unicorn":
				var horn := cone(torso, Vector3(0, 1.74, 0.31), 0.075, 0.38, glow(c1, 0.25), Vector3(0.35, 0, 0))
				for k in 4:
					var y: float = -0.12 + k * 0.07
					var r: float = 0.075 * (0.19 - y) / 0.38
					torus(horn, Vector3(0, y, 0), r - 0.006, r + 0.008, m2, Vector3(0, 0, 0.3))
				var mane := [Color(1.0, 0.6, 0.75), Color(1.0, 0.9, 0.45), Color(0.55, 0.95, 0.8), Color(0.55, 0.78, 1.0), Color(0.78, 0.65, 1.0)]
				for i in 5:
					sph(torso, head_pt(PI, 1.3 - i * 0.32, 0.02), 0.1, clay(mane[i]), Vector3(1.1, 0.9, 0.8))
				for s in [-1.0, 1.0]:
					prism(torso, Vector3(0.24 * s, 1.62, -0.04), Vector3(0.12, 0.16, 0.06), m, Vector3(0, 0, -0.4 * s))
			"flowerpin":
				_hair_cap(m)
				var fl := _node(torso, head_pt(0.75, 0.55, 0.05), Vector3(-0.55, 0.75, 0))
				for i in 5:
					var a: float = i * TAU / 5.0
					sph(fl, Vector3(cos(a) * 0.065, sin(a) * 0.065, 0), 0.055, m2, Vector3(1, 1, 0.4))
				sph(fl, Vector3(0, 0, 0.02), 0.035, clay(Color(1.0, 0.85, 0.2)))
				for s in [-1.0, 1.0]:
					var leaf := sph(fl, Vector3(0.1 * s, -0.08, -0.01), 0.05, clay(Color(0.3, 0.65, 0.3)), Vector3(1.4, 0.6, 0.3))
					leaf.rotation.z = 0.5 * s
			"bandana":
				var d := sph(torso, Vector3(0, 1.3, -0.02), 0.43, m, Vector3.ONE, true)
				d.rotation.x = -0.5
				var dot := clay(c2)
				for i in 7:
					var a: float = -1.2 + i * 0.4
					sph(torso, head_pt(a, 0.78 + 0.25 * float(i % 2), 0.03), 0.025, dot)
				sph(torso, Vector3(0, 1.3, -0.44), 0.06, m)
				for s in [-1.0, 1.0]:
					var t := box(torso, Vector3(0.06 * s, 1.18, -0.45), Vector3(0.07, 0.2, 0.02), m, Vector3(0.2, 0, 0.35 * s))
					spin(t, "sway")
			"laurel":
				torus(torso, Vector3(0, 1.5, 0), 0.34, 0.355, clay(c1.darkened(0.3)))
				for s in [-1.0, 1.0]:
					for i in 6:
						var a: float = (0.35 + i * 0.42) * s
						var leaf := sph(torso, Vector3(sin(a) * 0.36, 1.52, cos(a) * 0.36), 0.06, m, Vector3(0.45, 1.0, 0.25))
						leaf.rotation = Vector3(0, a, -0.9 * s)
					sph(torso, Vector3(0.05 * s, 1.5, 0.345), 0.025, m2)
			"helmet":
				var gl := _glass(c2, 0.22)
				sph(torso, Vector3(0, 1.3, 0), 0.52, gl)
				torus(torso, Vector3(0, 0.92, 0), 0.24, 0.38, m)
				var hi := flat(Color(1, 1, 1, 0.8), true)
				hi.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				sph(torso, Vector3(-0.2, 1.55, 0.42), 0.06, hi, Vector3(1.6, 0.6, 0.3))
				cyl(torso, Vector3(0.3, 1.86, 0), 0.01, 0.01, 0.2, m, Vector3(0, 0, -0.3))
				var tipb := sph(torso, Vector3(0.335, 1.96, 0), 0.035, glow(Color(1.0, 0.3, 0.25), 2.0))
				spin(tipb, "bob")
			"tiara":
				var gold := _metal(c1)
				torus(torso, Vector3(0, 1.5, 0), 0.335, 0.355, gold)
				for i in 5:
					var a: float = -0.6 + i * 0.3
					var h: float = 0.1 + 0.1 * (1.0 - absf(a) / 0.6)
					cone(torso, Vector3(sin(a) * 0.345, 1.5 + h * 0.5, cos(a) * 0.345), 0.035, h, gold)
				sph(torso, Vector3(0, 1.57, 0.36), 0.045, glow(c2, 0.8), Vector3(1, 1.2, 0.7))
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(sin(0.45 * s) * 0.35, 1.52, cos(0.45) * 0.35), 0.02, glow(c2, 0.8))
			"bob":
				var c := _hair_cap(m, -0.2, 0.44)
				c.scale = Vector3(1.05, 1.0, 1.05)
				var bang := sph(torso, Vector3(0, 1.5, 0.27), 0.27, m, Vector3(1.15, 0.38, 0.5))
				bang.rotation.x = 0.55
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.34 * s, 1.16, -0.02), 0.18, m, Vector3(0.6, 1.25, 1.35))
				sph(torso, Vector3(0, 1.14, -0.25), 0.25, m, Vector3(1.35, 0.95, 0.65))
			"braids":
				_hair_cap(m)
				for s in [-1.0, 1.0]:
					for k in 4:
						sph(torso, Vector3((0.36 + 0.01 * k) * s, 1.12 - k * 0.1, 0.05 + k * 0.045), 0.065 - k * 0.004, m, Vector3(1, 1.15, 1))
					sph(torso, Vector3(0.4 * s, 0.73, 0.23), 0.035, m2)
					cone(torso, Vector3(0.4 * s, 0.67, 0.245), 0.05, 0.1, m)
			"duck":
				var dk := _node(torso, Vector3(0, 1.68, 0))
				sph(dk, Vector3(0, 0.07, -0.02), 0.12, m, Vector3(1.0, 0.8, 1.2))
				sph(dk, Vector3(0, 0.19, 0.07), 0.08, m)
				sph(dk, Vector3(0, 0.18, 0.15), 0.04, m2, Vector3(1.2, 0.5, 1.2))
				for s in [-1.0, 1.0]:
					sph(dk, Vector3(0.035 * s, 0.215, 0.13), 0.013, flat(Color(0.05, 0.05, 0.05)))
					sph(dk, Vector3(0.11 * s, 0.08, -0.03), 0.05, m, Vector3(0.4, 0.7, 1.3))
				cone(dk, Vector3(0, 0.12, -0.15), 0.04, 0.08, m, Vector3(-1.0, 0, 0))

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
			"vest":
				_top(m, false)
				_arm_c = Color(c2.r, c2.g, c2.b, 1.0)
				_front = Color(c2.r, c2.g, c2.b, 1.0)
				_bottom(clay(Color(0.22, 0.24, 0.3)))
				var btn := clay(c1.darkened(0.4))
				for ly in [0.1, 0.0, -0.1]:
					var y: float = 0.66 + ly * 1.25
					var x: float = 0.03 + (0.32 - ly) * 0.22 + 0.02
					sph(torso, _torso_pt(x, y, 0.0), 0.016, btn)
				for s in [-1.0, 1.0]:
					box(torso, _torso_pt(0.17 * s, 0.56, 0.0), Vector3(0.08, 0.014, 0.02), btn, Vector3(0, 0.5 * s, 0))
				box(torso, _torso_pt(0.0, 0.84, 0.0), Vector3(0.04, 0.16, 0.015), clay(Color(0.75, 0.15, 0.2)), Vector3(-0.3, 0, 0))
			"cardigan":
				_top(m)
				_front = Color(c2.r, c2.g, c2.b, 1.0)
				_bottom(clay(Color(0.3, 0.32, 0.4)))
				var btn := clay(c1.darkened(0.35))
				for ly in [0.15, 0.05, -0.05, -0.15]:
					var y: float = 0.66 + ly * 1.25
					var x: float = 0.03 + (0.32 - ly) * 0.22 + 0.015
					sph(torso, _torso_pt(x, y, 0.0), 0.017, btn)
				var dk := clay(c1.darkened(0.12))
				for s in [-1.0, 1.0]:
					box(torso, _torso_pt(0.19 * s, 0.5, -0.01), Vector3(0.1, 0.09, 0.03), dk, Vector3(0.2, 0.55 * s, 0))
				for right in [false, true]:
					torus(arm(right), Vector3(0, -0.28, 0), 0.084, 0.108, dk)
			"hanbok":
				_top(m)
				_split = 0.1
				_bottom(m2, false)
				cyl(torso, Vector3(0, 0.36, 0), 0.31, 0.44, 0.5, m2)
				var red := clay(Color(0.75, 0.1, 0.3))
				box(torso, _torso_pt(0.05, 0.8, 0.0), Vector3(0.04, 0.2, 0.015), red, Vector3(-0.2, 0, 0.25))
				box(torso, _torso_pt(0.09, 0.79, 0.0), Vector3(0.035, 0.16, 0.015), red, Vector3(-0.2, 0, 0.5))
				sph(torso, _torso_pt(0.04, 0.88, 0.005), 0.025, red)
				var collar := clay(Color(0.98, 0.97, 0.94))
				for s in [-1.0, 1.0]:
					box(torso, _torso_pt(0.05 * s, 0.9, 0.0), Vector3(0.03, 0.14, 0.012), collar, Vector3(-0.4, 0, -0.6 * s))
				var bands := [Color(0.95, 0.3, 0.35), Color(1.0, 0.85, 0.3), Color(0.35, 0.7, 0.95), Color(0.4, 0.8, 0.45)]
				for right in [false, true]:
					for k in 4:
						torus(arm(right), Vector3(0, -0.08 - k * 0.06, 0), 0.084, 0.102, clay(bands[k]))
			"poncho":
				_bottom(clay(Color(0.3, 0.3, 0.38)))
				sph(torso, Vector3(0, 0.72, 0), 0.42, m, Vector3(1.0, 0.85, 0.9), true)
				var skirt := cyl(torso, Vector3(0, 0.62, 0), 0.42, 0.46, 0.2, m)
				skirt.scale = Vector3(1, 1, 0.9)
				var band := torus(torso, Vector3(0, 0.82, 0), 0.392, 0.425, m2)
				band.scale = Vector3(1, 1, 0.9)
				var band2 := cyl(torso, Vector3(0, 0.6, 0), 0.447, 0.451, 0.05, m2)
				band2.scale = Vector3(1, 1, 0.9)
				for i in 12:
					var a: float = i * TAU / 12.0
					cap(torso, Vector3(sin(a) * 0.455, 0.5, cos(a) * 0.41), 0.012, 0.07, m2)
			"lifejacket":
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.13 * s, 0.72, 0.2), 0.17, m, Vector3(0.75, 1.45, 0.55))
				sph(torso, Vector3(0, 0.72, -0.2), 0.27, m, Vector3(1.05, 1.3, 0.5))
				torus(torso, Vector3(0, 0.98, -0.02), 0.2, 0.3, m, Vector3(-0.2, 0, 0))
				var buckle := flat(Color(0.75, 0.75, 0.78))
				for y in [0.62, 0.8]:
					var t := torus(torso, Vector3(0, y, 0), 0.3, 0.33, m2)
					t.scale = Vector3(1, 1, 0.98)
					box(torso, Vector3(0, y, 0.325), Vector3(0.07, 0.045, 0.02), buckle)
				var refl := glow(Color(0.9, 0.95, 1.0), 0.6)
				for s in [-1.0, 1.0]:
					box(torso, Vector3(0.13 * s, 0.9, 0.262), Vector3(0.1, 0.03, 0.02), refl, Vector3(-0.6, 0, 0))
			"firefighter":
				_suit(m)
				var refl := glow(c2, 0.5)
				for y in [0.5, 0.8]:
					var r: float = _torso_r(y)
					var t := torus(torso, Vector3(0, y, 0), r - 0.012, r + 0.018, refl)
					t.scale = Vector3(1, 1, 0.9)
				for right in [false, true]:
					torus(arm(right), Vector3(0, -0.22, 0), 0.084, 0.104, refl)
				for leg in ["_left_leg", "_right_leg"]:
					var lg: Node3D = body.get(leg)
					torus(lg, Vector3(0, -0.24, 0), 0.11, 0.132, refl)
				torus(torso, Vector3(0, 0.97, 0), 0.2, 0.31, m)
				var clip := flat(Color(0.15, 0.15, 0.15))
				for y in [0.85, 0.72, 0.6]:
					box(torso, _torso_pt(0.0, y, 0.0), Vector3(0.06, 0.025, 0.02), clip)
			"chefcoat":
				_top(m)
				_bottom(clay(Color(0.2, 0.2, 0.22)))
				var btn := _metal(Color(0.75, 0.76, 0.8))
				for s in [-1.0, 1.0]:
					for k in 3:
						sph(torso, _torso_pt(0.075 * s, 0.86 - k * 0.12, 0.0), 0.018, btn)
				torus(torso, Vector3(0, 0.97, 0), 0.2, 0.3, m2)
				prism(torso, _torso_pt(0.0, 0.88, 0.02), Vector3(0.12, 0.1, 0.03), m2, Vector3(-0.3, 0, PI))
				var dk := clay(c1.darkened(0.1))
				for right in [false, true]:
					torus(arm(right), Vector3(0, -0.28, 0), 0.084, 0.108, dk)
			"mummy":
				_suit(m)
				var w := clay(c1.darkened(0.12))
				for i in 7:
					var y: float = 0.36 + i * 0.09
					var r: float = _torso_r(y)
					var tilt: float = 0.15 if i % 2 == 0 else -0.15
					var t := torus(torso, Vector3(0, y, 0), r - 0.012, r + 0.016, w if i % 2 == 0 else m, Vector3(tilt, 0, 0.08))
					t.scale = Vector3(1, 1, 0.9)
				for right in [false, true]:
					torus(arm(right), Vector3(0, -0.08, 0), 0.084, 0.104, w, Vector3(0, 0, 0.25))
					torus(arm(right), Vector3(0, -0.25, 0), 0.084, 0.104, w, Vector3(0, 0, -0.2))
				for leg in ["_left_leg", "_right_leg"]:
					var lg: Node3D = body.get(leg)
					torus(lg, Vector3(0, -0.08, 0), 0.11, 0.13, w, Vector3(0, 0, 0.2))
					torus(lg, Vector3(0, -0.25, 0), 0.11, 0.13, w, Vector3(0, 0, -0.25))
				var strip := box(torso, Vector3(0.12, 0.42, 0.25), Vector3(0.05, 0.18, 0.012), w, Vector3(0, 0, 0.2))
				spin(strip, "sway")
			"heartsweater":
				_top(m)
				_bottom(clay(Color(0.25, 0.3, 0.45)))
				_heart(torso, Vector3(0, 0.74, 0.292), 1.6, clay(c2))
				var dk := clay(c1.darkened(0.12))
				torus(torso, Vector3(0, 0.97, 0), 0.19, 0.28, dk)
				for right in [false, true]:
					torus(arm(right), Vector3(0, -0.28, 0), 0.084, 0.108, dk)
				var r: float = _torso_r(0.6)
				var hem := torus(torso, Vector3(0, 0.6, 0), r - 0.01, r + 0.02, dk)
				hem.scale = Vector3(1, 1, 0.9)
			"tanktop":
				_top(m, false)
				_bottom(m2, false)
				for leg in ["_left_leg", "_right_leg"]:
					var lg: Node3D = body.get(leg)
					cyl(lg, Vector3(0, -0.06, 0), 0.125, 0.135, 0.14, m2)
				for right in [false, true]:
					torus(arm(right), Vector3(0, -0.27, 0), 0.084, 0.11, m2)
				var trim := clay(c1.darkened(0.15))
				for y in [0.6, 0.8]:
					var r: float = _torso_r(y)
					var t := torus(torso, Vector3(0, y, 0), r - 0.01, r + 0.015, trim if y < 0.7 else m2)
					t.scale = Vector3(1, 1, 0.9)
			"karate":
				_suit(m)
				var lapel := clay(c1.darkened(0.12))
				for s in [-1.0, 1.0]:
					box(torso, _torso_pt(0.07 * s, 0.84, 0.0), Vector3(0.06, 0.3, 0.02), lapel, Vector3(-0.3, 0, -0.45 * s))
				var belt := torus(torso, Vector3(0, 0.56, 0), 0.29, 0.33, m2)
				belt.scale = Vector3(1, 1, 0.92)
				sph(torso, _torso_pt(0.06, 0.56, 0.035), 0.035, m2)
				box(torso, _torso_pt(0.05, 0.47, 0.035), Vector3(0.035, 0.15, 0.02), m2, Vector3(0, 0, 0.25))
				box(torso, _torso_pt(0.1, 0.47, 0.03), Vector3(0.035, 0.14, 0.02), m2, Vector3(0, 0, -0.2))
			"cheer":
				_top(m, false)
				_bottom(m2, false)
				var r: float = _torso_r(0.86)
				var band := torus(torso, Vector3(0, 0.86, 0), r - 0.01, r + 0.02, m2)
				band.scale = Vector3(1, 1, 0.9)
				add(torso, StarMesh.make(), glow(c2, 0.3), _torso_pt(0.0, 0.72, 0.01), Vector3(-0.2, 0, 0), Vector3.ONE * 0.08)
				cyl(torso, Vector3(0, 0.44, 0), 0.31, 0.4, 0.16, m)
				cyl(torso, Vector3(0, 0.375, 0), 0.396, 0.403, 0.03, m2)
				for right in [false, true]:
					var h := _hand(right, Vector3(0, -0.4, 0.02))
					for i in 8:
						var a: float = i * TAU / 8.0
						sph(h, Vector3(cos(a) * 0.06, sin(a) * 0.05, sin(a + 1.0) * 0.05), 0.055, m2 if i % 2 == 0 else m)
					sph(h, Vector3.ZERO, 0.06, m2)
			"scuba":
				_suit(m)
				_front = Color(c2.r, c2.g, c2.b, 1.0)
				var tank := clay(c2)
				var dark2 := flat(Color(0.15, 0.15, 0.17))
				for s in [-1.0, 1.0]:
					cyl(torso, Vector3(0.09 * s, 0.72, -0.36), 0.075, 0.075, 0.38, tank)
					sph(torso, Vector3(0.09 * s, 0.91, -0.36), 0.075, tank)
					cyl(torso, Vector3(0.09 * s, 1.0, -0.36), 0.02, 0.02, 0.06, dark2)
					box(torso, Vector3(0.14 * s, 0.84, -0.15), Vector3(0.05, 0.04, 0.3), dark2)
				cap(torso, Vector3(0.2, 1.0, -0.17), 0.018, 0.3, dark2, Vector3(0.9, 0, 0.3))
				var r: float = _torso_r(0.52)
				var belt := torus(torso, Vector3(0, 0.52, 0), r - 0.01, r + 0.02, dark2)
				belt.scale = Vector3(1, 1, 0.9)
				sph(torso, _torso_pt(0.0, 0.52, 0.02), 0.035, _metal(Color(0.8, 0.8, 0.85)), Vector3(1.3, 1, 0.6))
			"cactus":
				_suit(m)
				var spine := clay(Color(0.98, 0.95, 0.85))
				for row in 3:
					var y: float = 0.5 + row * 0.16
					var r: float = _torso_r(y)
					for k in 4:
						var a: float = -1.2 + k * 0.8 + (0.4 if row == 1 else 0.0)
						_spike(torso, Vector3(sin(a) * r, y, cos(a) * r * 0.9), Vector3(sin(a), 0.15, cos(a)), 0.012, 0.06, spine)
				for s in [-1.0, 1.0]:
					var y0: float = 0.62 if s < 0.0 else 0.72
					cap(torso, Vector3(0.35 * s, y0, -0.18), 0.065, 0.24, m, Vector3(0, 0, PI / 2.0))
					cap(torso, Vector3(0.45 * s, y0 + 0.12, -0.18), 0.065, 0.28, m)
				var fl := _node(torso, Vector3(0.45, 0.99, -0.18))
				for i in 5:
					var a: float = i * TAU / 5.0
					sph(fl, Vector3(cos(a) * 0.04, 0.0, sin(a) * 0.04), 0.035, m2, Vector3(1, 0.5, 1))
				sph(fl, Vector3(0, 0.015, 0), 0.022, clay(Color(1.0, 0.85, 0.2)))
			"shark":
				_suit(m)
				_belly = Color(c2.r, c2.g, c2.b, 1.0)
				var hood := sph(torso, Vector3(0, 1.3, -0.05), 0.45, m, Vector3(1.03, 1.0, 1.0), true)
				hood.rotation.x = -0.6
				prism(torso, Vector3(0, 1.86, -0.08), Vector3(0.3, 0.26, 0.05), m, Vector3(0, PI / 2.0, 0))
				var tooth := clay(c2)
				for i in 7:
					var ph: float = 0.5 + i * 0.36
					var p := Vector3(0, 1.3, -0.05) + Vector3(cos(ph) * 0.46, sin(ph) * 0.46 * 0.565, sin(ph) * 0.46 * 0.825)
					prism(torso, p, Vector3(0.055, 0.07, 0.02), tooth, Vector3(-0.6, atan2(p.x, p.z + 0.05), PI))
				prism(torso, Vector3(0, 0.45, -0.41), Vector3(0.3, 0.22, 0.05), m, Vector3(0, -PI / 2.0, PI / 2.0))
			"banana":
				_top(m2)
				_bottom(m)
				for i in 4:
					var a: float = PI / 4.0 + i * PI / 2.0
					var root := _node(torso, Vector3(sin(a) * 0.28, 0.66, cos(a) * 0.26), Vector3(0, a, 0))
					var f := sph(root, Vector3(0, -0.17, 0.08), 0.13, m, Vector3(0.85, 1.75, 0.22))
					f.rotation.x = -0.55
					sph(f, Vector3(0, -0.11, 0), 0.03, clay(Color(0.35, 0.22, 0.1)), Vector3(1.2, 0.5, 1.2))
				sph(torso, Vector3(0, 0.27, 0.0), 0.05, clay(Color(0.35, 0.22, 0.1)))
				var spot := clay(Color(0.45, 0.3, 0.12))
				for p in [Vector3(-0.12, 0.45, 0.24), Vector3(0.15, 0.38, 0.2)]:
					sph(torso, p, 0.02, spot, Vector3(1.4, 1, 0.5))
			"puffer":
				_top(m)
				_bottom(clay(Color(0.2, 0.22, 0.3)))
				for i in 5:
					var y: float = 0.47 + i * 0.11
					var r: float = _torso_r(y)
					var t := torus(torso, Vector3(0, y, -0.005), r - 0.03, r + 0.045, m)
					t.scale = Vector3(1, 1.05, 0.92)
				torus(torso, Vector3(0, 0.97, 0), 0.2, 0.31, m2)
				for right in [false, true]:
					for k in 3:
						torus(arm(right), Vector3(0, -0.04 - k * 0.1, 0), 0.08, 0.125, m)
				box(torso, _torso_pt(0.0, 0.72, 0.045), Vector3(0.018, 0.3, 0.012), m2, Vector3(-0.15, 0, 0))
			"tracksuit":
				_suit(m)
				var st := clay(c2)
				for right in [false, true]:
					var sx: float = 1.0 if right else -1.0
					for dz in [-0.02, 0.02]:
						box(arm(right), Vector3(0.085 * sx, -0.15, dz), Vector3(0.02, 0.36, 0.014), st)
				for leg in ["_left_leg", "_right_leg"]:
					var lg: Node3D = body.get(leg)
					var sx: float = 1.0 if leg == "_right_leg" else -1.0
					for dz in [-0.025, 0.025]:
						box(lg, Vector3(0.11 * sx, -0.15, dz), Vector3(0.02, 0.38, 0.016), st)
				box(torso, _torso_pt(0.0, 0.72, 0.0), Vector3(0.02, 0.24, 0.015), st, Vector3(-0.15, 0, 0))
				torus(torso, Vector3(0, 0.97, 0), 0.19, 0.28, m)
				var r: float = _torso_r(0.86)
				var band := torus(torso, Vector3(0, 0.86, 0), r - 0.008, r + 0.016, st)
				band.scale = Vector3(1, 1, 0.9)
			"robotbox":
				_bottom(clay(Color(0.35, 0.36, 0.4)))
				box(torso, Vector3(0, 0.68, 0), Vector3(0.64, 0.62, 0.6), m)
				var dk := clay(c1.darkened(0.3))
				box(torso, Vector3(0, 0.74, 0.302), Vector3(0.4, 0.26, 0.01), dk)
				var lamps := [Color(1, 0.25, 0.25), Color(0.3, 1, 0.4), Color(0.35, 0.65, 1)]
				for k in 3:
					sph(torso, Vector3(-0.11 + k * 0.11, 0.8, 0.31), 0.03, glow(lamps[k], 1.6), Vector3(1, 1, 0.5))
				for k in 3:
					box(torso, Vector3(0, 0.56 - k * 0.04, 0.302), Vector3(0.24, 0.015, 0.01), dk)
				var steel := _metal(Color(0.6, 0.62, 0.66))
				for s in [-1.0, 1.0]:
					cyl(torso, Vector3(0.12 * s, 0.68, 0.305), 0.03, 0.03, 0.02, m2, Vector3(PI / 2.0, 0, 0))
					sph(torso, Vector3(0.28 * s, 0.95, 0.305), 0.022, steel, Vector3(1, 1, 0.5))
				for right in [false, true]:
					for k in 3:
						torus(arm(right), Vector3(0, -0.12 - k * 0.08, 0), 0.084, 0.11, steel)
			"strawberry":
				sph(torso, Vector3(0, 0.64, 0), 0.37, m, Vector3(1.0, 1.15, 0.95))
				var seed_m := clay(Color(1.0, 0.9, 0.45))
				for row in 3:
					for col in 5:
						var a: float = -1.4 + col * 0.7 + (0.35 if row % 2 == 1 else 0.0)
						var ph: float = -0.55 + row * 0.42
						var d := Vector3(sin(a) * cos(ph), sin(ph), cos(a) * cos(ph))
						sph(torso, Vector3(d.x * 0.375, 0.64 + d.y * 0.43, d.z * 0.355), 0.016, seed_m, Vector3(1, 1.4, 1))
				for i in 6:
					var a: float = i * TAU / 6.0
					prism(torso, Vector3(sin(a) * 0.25, 0.98, cos(a) * 0.23), Vector3(0.13, 0.18, 0.03), m2, Vector3(-0.9, a, PI))
			"dress":
				_top(m, false)
				_split = -0.02
				_bottom(m, false)
				cyl(torso, Vector3(0, 0.42, 0), 0.3, 0.46, 0.3, m)
				torus(torso, Vector3(0, 0.275, 0), 0.43, 0.48, m2)
				_bowtie(_torso_pt(0.0, 0.6, 0.02), m2)
				for s in [-1.0, 1.0]:
					sph(torso, Vector3(0.32 * s, 0.88, 0), 0.11, m)
				torus(torso, Vector3(0, 0.97, 0), 0.2, 0.27, m2)

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
			"wand":
				var h := _hand(true, Vector3(0, -0.36, 0.08), Vector3(0.9, 0, 0))
				cyl(h, Vector3(0, 0.12, 0), 0.012, 0.016, 0.36, m2)
				var star := add(h, StarMesh.make(), glow(c1, 1.0), Vector3(0, 0.34, 0), Vector3.ZERO, Vector3.ONE * 0.09)
				spin(star, "spin")
				var sp := glow(Color(1.0, 1.0, 0.85), 2.0)
				for p in [Vector3(0.09, 0.42, 0.02), Vector3(-0.08, 0.38, -0.03), Vector3(0.05, 0.27, 0.04)]:
					sph(h, p, 0.012, sp)
			"foamsword":
				var h := _hand(true, Vector3(0, -0.36, 0.06), Vector3(1.1, 0, 0))
				cyl(h, Vector3(0, -0.02, 0), 0.025, 0.025, 0.14, m2)
				box(h, Vector3(0, 0.06, 0), Vector3(0.18, 0.035, 0.05), m2)
				var blade := cap(h, Vector3(0, 0.33, 0), 0.045, 0.52, m)
				blade.scale = Vector3(1.0, 1.0, 0.45)
				sph(h, Vector3(0, -0.1, 0), 0.032, m2)
			"shield":
				var sh := _node(arm(false), Vector3(-0.1, -0.22, 0.02), Vector3(0, 0, PI / 2.0))
				cyl(sh, Vector3.ZERO, 0.2, 0.2, 0.035, m)
				torus(sh, Vector3.ZERO, 0.19, 0.215, m2)
				cyl(sh, Vector3(0, 0.02, 0), 0.14, 0.14, 0.02, m2)
				cyl(sh, Vector3(0, 0.03, 0), 0.085, 0.085, 0.02, m)
				add(sh, StarMesh.make(), glow(c2, 0.4), Vector3(0, 0.045, 0), Vector3(-PI / 2.0, 0, 0), Vector3.ONE * 0.065)
			"lantern":
				var root := _hand(false, Vector3(0, -0.38, 0.05))
				spin(root, "upright")
				var fr := clay(c1)
				torus(root, Vector3.ZERO, 0.02, 0.03, fr, Vector3(PI / 2.0, 0, 0))
				cone(root, Vector3(0, -0.07, 0), 0.06, 0.06, fr)
				cyl(root, Vector3(0, -0.11, 0), 0.075, 0.075, 0.025, fr)
				cyl(root, Vector3(0, -0.2, 0), 0.062, 0.062, 0.15, glow(c2, 1.6))
				cyl(root, Vector3(0, -0.29, 0), 0.08, 0.08, 0.03, fr)
				for k in 4:
					var a: float = k * TAU / 4.0 + PI / 4.0
					cyl(root, Vector3(sin(a) * 0.068, -0.2, cos(a) * 0.068), 0.008, 0.008, 0.16, fr)
			"camera":
				torus(torso, Vector3(0, 0.98, 0.04), 0.255, 0.27, m2, Vector3(0.45, 0, 0))
				for s in [-1.0, 1.0]:
					cap(torso, Vector3(0.1 * s, 0.83, 0.3), 0.007, 0.1, m2, Vector3(-0.56, 0, 0))
				var cam := box(torso, _torso_pt(0.0, 0.72, 0.05), Vector3(0.22, 0.14, 0.09), m)
				var lensm := flat(Color(0.12, 0.12, 0.14))
				cyl(cam, Vector3(0, -0.005, 0.07), 0.045, 0.05, 0.07, lensm, Vector3(PI / 2.0, 0, 0))
				cyl(cam, Vector3(0, -0.005, 0.106), 0.032, 0.032, 0.005, glow(Color(0.4, 0.6, 0.9), 0.4), Vector3(PI / 2.0, 0, 0))
				box(cam, Vector3(-0.07, 0.04, 0.046), Vector3(0.05, 0.025, 0.01), glow(Color(1, 1, 0.95), 0.5))
				cyl(cam, Vector3(0.07, 0.08, 0), 0.015, 0.015, 0.02, m2)
			"book":
				var bk := _hand(false, Vector3(0.04, -0.36, 0.12))
				var page := clay(c2)
				var ink := flat(Color(0.3, 0.3, 0.35))
				for s in [-1.0, 1.0]:
					var half := _node(bk, Vector3.ZERO, Vector3(0, -0.35 * s, 0))
					box(half, Vector3(0.075 * s, 0, 0), Vector3(0.15, 0.2, 0.012), m)
					box(half, Vector3(0.07 * s, 0, 0.012), Vector3(0.135, 0.185, 0.015), page)
					for k in 3:
						box(half, Vector3(0.07 * s, 0.05 - k * 0.04, 0.021), Vector3(0.1, 0.008, 0.002), ink)
			"coffee":
				var h := _hand(true, Vector3(0, -0.4, 0.08))
				spin(h, "upright")
				var lid := clay(Color(0.95, 0.95, 0.93) if c1.get_luminance() < 0.8 else Color(0.25, 0.2, 0.18))
				cyl(h, Vector3.ZERO, 0.06, 0.045, 0.16, m)
				cyl(h, Vector3.ZERO, 0.061, 0.054, 0.06, m2)
				cyl(h, Vector3(0, 0.09, 0), 0.064, 0.064, 0.02, lid)
				cyl(h, Vector3(0, 0.107, 0), 0.045, 0.06, 0.015, lid)
				var steam := _glass(Color.WHITE, 0.45)
				for k in 2:
					var st := cap(h, Vector3(-0.02 + k * 0.04, 0.18 + k * 0.03, 0), 0.01, 0.07, steam, Vector3(0, 0, 0.3 - k * 0.6))
					spin(st, "bob")
			"icecream":
				var h := _hand(true, Vector3(0, -0.4, 0.08))
				spin(h, "upright")
				cone(h, Vector3.ZERO, 0.06, 0.18, clay(Color(0.85, 0.6, 0.3)), Vector3(PI, 0, 0))
				torus(h, Vector3(0, 0.07, 0), 0.05, 0.066, clay(Color(0.75, 0.5, 0.25)))
				sph(h, Vector3(0, 0.12, 0), 0.07, m)
				sph(h, Vector3(0, 0.22, 0), 0.06, m2)
				sph(h, Vector3(0, 0.29, 0), 0.022, clay(Color(0.85, 0.1, 0.15)))
				sph(h, Vector3(0.05, 0.09, 0.03), 0.025, m, Vector3(0.6, 1.2, 0.6))
			"fish":
				var root := _hand(false, Vector3(0, -0.38, 0.04))
				spin(root, "sway")
				prism(root, Vector3(0, -0.04, 0), Vector3(0.12, 0.09, 0.025), m)
				sph(root, Vector3(0, -0.2, 0), 0.07, m, Vector3(0.75, 1.9, 0.5))
				sph(root, Vector3(0, -0.22, 0.012), 0.06, m2, Vector3(0.6, 1.6, 0.45))
				var eye := flat(Color(0.05, 0.05, 0.05))
				for s in [-1.0, 1.0]:
					sph(root, Vector3(0.045 * s, -0.29, 0.0), 0.014, eye)
					prism(root, Vector3(0.05 * s, -0.2, 0), Vector3(0.05, 0.06, 0.015), m, Vector3(0, 0, -PI / 2.0 * s))
				torus(root, Vector3(0, -0.33, 0), 0.01, 0.02, clay(c1.darkened(0.3)))
			"duck":
				var d := _node(torso, Vector3(0.37, 0.95, 0.0))
				sph(d, Vector3.ZERO, 0.085, m, Vector3(1.0, 0.8, 1.25))
				sph(d, Vector3(0, 0.1, 0.06), 0.06, m)
				sph(d, Vector3(0, 0.09, 0.12), 0.03, m2, Vector3(1.3, 0.5, 1.2))
				var eye := flat(Color(0.05, 0.05, 0.05))
				for s in [-1.0, 1.0]:
					sph(d, Vector3(0.03 * s, 0.12, 0.105), 0.01, eye)
					sph(d, Vector3(0.07 * s, 0.0, -0.01), 0.04, m, Vector3(0.4, 0.8, 1.3))
				cone(d, Vector3(0, 0.04, -0.11), 0.03, 0.06, m, Vector3(-1.0, 0, 0))
			"kite":
				var root := _hand(true, Vector3(0, -0.38, 0))
				cyl(root, Vector3(0, 0.8, -0.3), 0.004, 0.004, 1.71, flat(Color(0.95, 0.95, 0.95)), Vector3(-0.359, 0, 0))
				var k := _node(root, Vector3(0, 1.6, -0.6))
				k.scale = Vector3(0.8, 1.2, 1.0)
				box(k, Vector3.ZERO, Vector3(0.3, 0.3, 0.015), m, Vector3(0, 0, PI / 4.0))
				box(k, Vector3(0, 0, 0.012), Vector3(0.018, 0.42, 0.01), m2)
				box(k, Vector3(0, 0.03, 0.012), Vector3(0.4, 0.018, 0.01), m2)
				for i in 3:
					var x: float = 0.02 if i % 2 == 0 else -0.02
					prism(k, Vector3(x, -0.27 - i * 0.08, 0), Vector3(0.06, 0.04, 0.01), m2, Vector3(0, 0, PI / 2.0))
				spin(root, "balloon")
			"maracas":
				for right in [false, true]:
					var h := _hand(right, Vector3(0, -0.38, 0.06), Vector3(0.6, 0, 0))
					cyl(h, Vector3(0, 0.02, 0), 0.016, 0.02, 0.14, m2)
					sph(h, Vector3(0, 0.15, 0), 0.075, m, Vector3(1, 1.15, 1))
					torus(h, Vector3(0, 0.15, 0), 0.07, 0.085, m2)
					torus(h, Vector3(0, 0.205, 0), 0.05, 0.062, m2)
			"bubblewand":
				var h := _hand(true, Vector3(0, -0.38, 0.06), Vector3(0.8, 0, 0))
				cyl(h, Vector3(0, 0.12, 0), 0.01, 0.01, 0.28, m2)
				torus(h, Vector3(0, 0.31, 0), 0.04, 0.055, m2, Vector3(PI / 2.0, 0, 0))
				var bub := _glass(c1, 0.3)
				bub.rim_enabled = true
				bub.rim = 1.0
				sph(h, Vector3(0, 0.31, 0), 0.045, bub, Vector3(1, 1, 0.08))
				for e in [[Vector3(0.5, 0.95, 0.3), 0.05], [Vector3(0.58, 1.12, 0.18), 0.07], [Vector3(0.5, 1.3, 0.1), 0.04], [Vector3(0.64, 1.35, -0.02), 0.06]]:
					var p: Vector3 = e[0]
					var r: float = e[1]
					var b := sph(torso, p, r, bub)
					spin(b, "bob")
			"jetpack":
				var jp := _node(torso, Vector3(0, 0.72, -0.36))
				box(jp, Vector3(0, 0, 0.04), Vector3(0.22, 0.3, 0.08), m2)
				var noz := flat(Color(0.25, 0.25, 0.28))
				var flame := glow(Color(1.0, 0.6, 0.15), 2.5)
				var strap := flat(Color(0.15, 0.15, 0.17))
				for s in [-1.0, 1.0]:
					var tank := _metal(c1, 0.6)
					cyl(jp, Vector3(0.1 * s, 0.02, -0.04), 0.08, 0.08, 0.36, tank)
					cone(jp, Vector3(0.1 * s, 0.26, -0.04), 0.08, 0.12, m2)
					cyl(jp, Vector3(0.1 * s, -0.19, -0.04), 0.05, 0.065, 0.06, noz)
					cone(jp, Vector3(0.1 * s, -0.3, -0.04), 0.05, 0.16, flame, Vector3(PI, 0, 0))
					prism(jp, Vector3(0.19 * s, -0.12, -0.04), Vector3(0.08, 0.12, 0.02), m2)
					box(torso, Vector3(0.14 * s, 0.84, -0.15), Vector3(0.05, 0.04, 0.3), strap)
			"medal":
				for s in [-1.0, 1.0]:
					box(torso, _torso_pt(0.06 * s, 0.865, 0.0), Vector3(0.05, 0.24, 0.012), m2, Vector3(-0.4, 0, -0.5 * s))
				var gold := _metal(c1)
				cyl(torso, _torso_pt(0.0, 0.72, 0.02), 0.07, 0.07, 0.02, gold, Vector3(PI / 2.0 - 0.15, 0, 0))
				add(torso, StarMesh.make(), glow(c1.lightened(0.3), 0.4), _torso_pt(0.0, 0.72, 0.035), Vector3(-0.15, 0, 0), Vector3.ONE * 0.045)
			"fannypack":
				var belt := torus(torso, Vector3(0, 0.5, -0.01), 0.282, 0.31, m2)
				belt.scale = Vector3(1, 1, 0.92)
				sph(torso, Vector3(0.06, 0.5, 0.288), 0.1, m, Vector3(1.4, 0.75, 0.6))
				cap(torso, Vector3(0.06, 0.53, 0.343), 0.008, 0.2, m2, Vector3(0, 0, PI / 2.0))
				box(torso, Vector3(-0.2, 0.5, 0.215), Vector3(0.05, 0.04, 0.02), flat(Color(0.15, 0.15, 0.17)), Vector3(0, -0.7, 0))
			"watch":
				var w := _hand(false, Vector3(0, -0.27, 0))
				torus(w, Vector3.ZERO, 0.085, 0.105, m2)
				cyl(w, Vector3(0, 0, 0.1), 0.05, 0.05, 0.025, _metal(c1), Vector3(PI / 2.0, 0, 0))
				cyl(w, Vector3(0, 0, 0.114), 0.04, 0.04, 0.005, glow(Color(0.85, 0.95, 1.0), 0.5), Vector3(PI / 2.0, 0, 0))
				var hand_m := flat(Color(0.05, 0.05, 0.05))
				box(w, Vector3(0, 0.012, 0.118), Vector3(0.006, 0.026, 0.003), hand_m)
				box(w, Vector3(0.01, 0, 0.118), Vector3(0.02, 0.005, 0.003), hand_m)
			"bell":
				torus(torso, Vector3(0, 0.98, 0.02), 0.23, 0.29, m2, Vector3(0.3, 0, 0))
				var gold := _metal(c1)
				sph(torso, Vector3(0, 0.84, 0.29), 0.055, gold)
				torus(torso, Vector3(0, 0.84, 0.29), 0.05, 0.058, gold)
				box(torso, Vector3(0, 0.82, 0.343), Vector3(0.05, 0.008, 0.008), flat(Color(0.1, 0.08, 0.05)))
				sph(torso, Vector3(0, 0.805, 0.335), 0.012, flat(Color(0.1, 0.08, 0.05)))
			"magnifier":
				var h := _hand(true, Vector3(0, -0.38, 0.06), Vector3(1.0, 0, 0))
				cyl(h, Vector3(0, 0.05, 0), 0.018, 0.022, 0.16, m2)
				torus(h, Vector3(0, 0.22, 0), 0.07, 0.09, _metal(c1), Vector3(PI / 2.0, 0, 0))
				cyl(h, Vector3(0, 0.22, 0), 0.072, 0.072, 0.01, _glass(Color(0.75, 0.9, 1.0), 0.3), Vector3(PI / 2.0, 0, 0))
				sph(h, Vector3(-0.03, 0.25, 0.008), 0.015, flat(Color.WHITE, true), Vector3(1.5, 1, 0.3))
			"mic":
				var h := _hand(true, Vector3(0, -0.38, 0.07), Vector3(0.7, 0, 0))
				cyl(h, Vector3(0, 0.04, 0), 0.032, 0.022, 0.2, m)
				torus(h, Vector3(0, 0.14, 0), 0.03, 0.045, m)
				sph(h, Vector3(0, 0.18, 0), 0.055, _metal(c2, 0.6))
				cyl(h, Vector3(0, -0.04, 0), 0.024, 0.024, 0.012, glow(Color(0.3, 1.0, 0.4), 1.2))
			"bobatea":
				var h := _hand(true, Vector3(0, -0.4, 0.08))
				spin(h, "upright")
				cyl(h, Vector3.ZERO, 0.06, 0.05, 0.18, _glass(c1, 0.75))
				var pearl := flat(Color(0.15, 0.08, 0.05))
				for i in 6:
					var a: float = i * TAU / 6.0
					sph(h, Vector3(cos(a) * 0.028, -0.065 + (i % 2) * 0.02, sin(a) * 0.028), 0.017, pearl)
				sph(h, Vector3(0, 0.09, 0), 0.06, _glass(Color.WHITE, 0.5), Vector3(1, 0.5, 1), true)
				cyl(h, Vector3(0.015, 0.15, 0), 0.012, 0.012, 0.22, m2, Vector3(0, 0, -0.15))
			"donut":
				var h := _hand(true, Vector3(0, -0.42, 0.1), Vector3(PI / 2.0 - 0.3, 0, 0))
				torus(h, Vector3.ZERO, 0.03, 0.1, clay(Color(0.85, 0.6, 0.3)))
				var ic := torus(h, Vector3(0, 0.012, 0), 0.035, 0.098, m)
				ic.scale = Vector3(1, 0.8, 1)
				var sprinkle := [Color(1, 0.3, 0.3), Color(1, 0.9, 0.3), Color(0.4, 0.8, 1), Color(0.97, 0.97, 0.97)]
				for i in 8:
					var a: float = i * TAU / 8.0 + 0.3
					var sc: Color = sprinkle[i % 4]
					if c2 != Color.WHITE and i % 2 == 0:
						sc = c2
					cap(h, Vector3(cos(a) * 0.066, 0.04, sin(a) * 0.066), 0.006, 0.025, clay(sc), Vector3(PI / 2.0, a * 1.7, 0))
			"carrot":
				var h := _hand(true, Vector3(0, -0.38, 0.08), Vector3(1.2, 0, 0))
				cone(h, Vector3(0, 0.14, 0), 0.05, 0.28, m)
				var ridge := clay(c1.darkened(0.2))
				torus(h, Vector3(0, 0.06, 0), 0.036, 0.046, ridge)
				torus(h, Vector3(0, 0.14, 0), 0.022, 0.031, ridge)
				for k in 3:
					cap(h, Vector3((k - 1) * 0.03, -0.06, 0), 0.015, 0.1, m2, Vector3(0, 0, (k - 1) * 0.4))
			"lightstick":
				var h := _hand(true, Vector3(0, -0.38, 0.06), Vector3(0.5, 0, 0))
				cyl(h, Vector3(0, 0.06, 0), 0.025, 0.03, 0.22, m2)
				torus(h, Vector3(0, 0.18, 0), 0.03, 0.05, m2)
				sph(h, Vector3(0, 0.27, 0), 0.09, _glass(c1.lightened(0.4), 0.35))
				_heart(h, Vector3(0, 0.27, 0), 1.0, glow(c1, 2.0))
			"fan":
				var h := _hand(true, Vector3(0, -0.38, 0.08), Vector3(0.9, 0, 0))
				cyl(h, Vector3(0, 0.05, 0), 0.012, 0.012, 0.14, clay(Color(0.45, 0.3, 0.15)))
				sph(h, Vector3(0, 0.19, 0), 0.14, m, Vector3(1.0, 1.0, 0.08))
				sph(h, Vector3(0, 0.19, 0.008), 0.13, m2, Vector3(1.0, 1.0, 0.06), true)
				sph(h, Vector3(-0.065, 0.19, 0.012), 0.065, m2, Vector3(1, 1, 0.06))
				sph(h, Vector3(0.065, 0.19, 0.012), 0.065, m, Vector3(1, 1, 0.06))


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
