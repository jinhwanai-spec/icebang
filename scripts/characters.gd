class_name CharacterDB
extends RefCounted
## 캐릭터 목록 (선택 창과 능력 설명에 사용)
## 쿨타임 숫자는 balance.cfg 에서 바꿉니다.
## 새 캐릭터를 만들려면: 여기에 한 칸 추가 → player.gd 의 _use_ability_1/2 에 능력 코드 추가

const ORDER := ["chameleon", "space", "cameraman", "brute", "medic", "shadow", "hunter", "bard", "mechanic", "keeper", "gravity"]

const DATA := {
	"chameleon": {
		"name": "카멜레온",
		"color": Color(0.35, 0.8, 0.35),
		"ability_1": "동화",
		"ability_1_desc": "7.5초 동안 그 자리에서 주변에 녹아들어 술래가 전혀 감지하지 못해요. 움직일 수 없고, 술래가 부딪히면 잡혀요. R을 다시 누르면 취소.",
		"ability_1_cd": ["chameleon", "blend_cooldown", 25.0],
		"ability_2": "맵 물들이기",
		"ability_2_desc": "15초 동안 맵 전체를 내 몸 색으로 바꾸고, 그동안 나는 술래에게 감지되지 않아요. 움직일 수 있지만 봉인석·땡 같은 상호작용은 못 해요.",
		"ability_2_cd": ["chameleon", "paint_cooldown", 62.5],
	},
	"space": {
		"name": "공간술사",
		"color": Color(0.6, 0.4, 1.0),
		"ability_1": "순간이동",
		"ability_1_desc": "맵의 랜덤한 곳으로 순간이동해요. 어디로 갈지는 몰라요!",
		"ability_1_cd": ["space", "teleport_cooldown", 60.0],
		"ability_2": "소환",
		"ability_2_desc": "고른 동료를 내 앞으로 불러와요. 얼음 상태 동료도 가능 (얼음은 유지).",
		"ability_2_cd": ["space", "summon_cooldown", 75.0],
	},
	"cameraman": {
		"name": "카메라맨",
		"color": Color(1.0, 0.75, 0.2),
		"ability_1": "플래시 촬영",
		"ability_1_desc": "정면의 술래를 찍으면 1.5초 동안 스턴! 움직이지도 보지도 못해요.",
		"ability_1_cd": ["cameraman", "photo_cooldown", 15.0],
		"ability_2": "카메라 설치",
		"ability_2_desc": "바닥에 카메라를 설치(20초). 카메라 앞을 술래가 지나가면 모두에게 위치가 표시돼요. 최대 3개, 25초마다 1개 충전.",
		"ability_2_cd": ["cameraman", "camera_recharge", 50.0],
		"ability_2_charges": ["cameraman", "camera_max_charges", 3],
	},
	"brute": {
		"name": "파이터",
		"color": Color(0.9, 0.35, 0.3),
		"ability_1": "괴력 해동 (패시브)",
		"ability_1_desc": "얼음 동료를 기다림 없이 한 번에 깨요.",
		"ability_1_cd": [],
		"ability_2": "강펀치",
		"ability_2_desc": "커다란 주먹을 앞으로 날려요(3m). 맞은 술래는 맵 끝까지 날아가고 잠깐 기절해요.",
		"ability_2_cd": ["brute", "punch_cooldown", 75.0],
	},
	"medic": {
		"name": "의사",
		"color": Color(0.85, 0.95, 0.95),
		"ability_1": "치료",
		"ability_1_desc": "R을 누르고 숫자로 동료를 골라요. 얼음 상태면 바로 해동, 아니면 8초 동안 이동속도 +20% (중첩 안 됨). 거리 상관없음.",
		"ability_1_cd": ["medic", "remote_thaw_cooldown", 80.0],
		"ability_2": "붕대 당기기",
		"ability_2_desc": "조준한 동료를 붕대로 묶어 내 앞으로 당겨와요(15m). 얼음 상태 동료도 당길 수 있어요.",
		"ability_2_cd": ["medic", "bandage_cooldown", 20.0],
	},

	"shadow": {
		"name": "그림자",
		"color": Color(0.18, 0.18, 0.22),
		"ability_1": "그림자 속으로",
		"ability_1_desc": "그림자 속에 20초 동안 숨어요(R 다시 누르면 나옴). 옆에 동료나 술래가 있으면 그 그림자에 붙어 따라다녀요. 숨어 있는 동안은 감지도, 잡히지도 않아요. (패시브: 발소리 절반)",
		"ability_1_cd": ["shadow", "shadow_cooldown", 30.0],
		"ability_2": "그림자 건너가기",
		"ability_2_desc": "그림자 속에 있을 때 다른 동료의 그림자로 순간이동해요. 누를 때마다 다음 동료로 (거리 상관없음, 얼음 동료도 가능).",
		"ability_2_cd": ["shadow", "hop_cooldown", 10.0],
	},

	"hunter": {
		"name": "사냥꾼",
		"color": Color(0.45, 0.5, 0.25),
		"ability_1": "덫 설치",
		"ability_1_desc": "발밑에 덫을 숨겨요(1분 30초 유지). 밟은 술래는 3초 동안 묶여요. 최대 3개, 30초마다 1개 충전.",
		"ability_1_cd": ["hunter", "trap_recharge", 30.0],
		"ability_1_charges": ["hunter", "trap_max", 3],
		"ability_2": "추적 화살",
		"ability_2_desc": "화살에 맞은 술래는 계속 피를 흘리고, 핏자국이 30초 동안 남아요. 화살은 술래 수만큼만 있어요.",
		"ability_2_cd": ["hunter", "arrow_delay", 1.0],
		"ability_2_ammo": true,
	},

	"bard": {
		"name": "악사",
		"color": Color(1.0, 0.55, 0.2),
		"ability_1": "메탈 연주 (켜기/끄기)",
		"ability_1_desc": "헤비메탈을 연주해요. 술래가 내 위치를 알게 되지만, 모두가 술래 위치를 볼 수 있어요. 노래는 모두에게 들려요.",
		"ability_1_cd": ["bard", "toggle_delay", 0.5],
		"ability_2": "빠른 비트 (켜기/끄기)",
		"ability_2_desc": "신나는 비트로 나는 이동속도 +30%, 우리 팀은 +15%. 대신 술래가 내 위치를 알아요. 노래는 모두에게 들려요.",
		"ability_2_cd": ["bard", "toggle_delay", 0.5],
	},

	"mechanic": {
		"name": "정비공",
		"color": Color(0.75, 0.6, 0.3),
		"ability_1": "봉인 가속 (패시브)",
		"ability_1_desc": "봉인석 미니게임을 한 단계 깨면 두 단계가 진행돼요.",
		"ability_1_cd": [],
		"ability_2": "보급품",
		"ability_2_desc": "신발(이속 +10%) / 갑옷(술래 공격 1회 막음) / 헬멧(공격 1회 + 마녀 안개 막음) 중 랜덤 1개를 착용해요. 1개만 착용, 깨지면 다시 쓸 수 있어요. 신발은 얼음하면 사라져요.",
		"ability_2_cd": ["mechanic", "item_delay", 1.0],
	},
	"keeper": {
		"name": "등불지기",
		"color": Color(1.0, 0.85, 0.4),
		"ability_1": "길잡이 등불",
		"ability_1_desc": "등불들이 가장 가까운 봉인석으로 길을 안내해요. 내가 근처에 있어야 움직이고, 다시 쓰면 새로 불러와요.",
		"ability_1_cd": ["keeper", "guide_delay", 1.0],
		"ability_2": "붉은 탐색광",
		"ability_2_desc": "빨간 빛들이 술래를 찾아가요. 찾으면 환하게 빛나 20초 동안 위치를 알려줘요. 빛이 사라진 뒤 20초 쿨타임.",
		"ability_2_cd": ["keeper", "wisp_cooldown", 20.0],
	},

	"gravity": {
		"name": "중력술사",
		"color": Color(0.92, 0.93, 0.97),
		"ability_1": "무중력",
		"ability_1_desc": "정면의 술래를 3초 동안 공중에 띄워요. 내려오지 못하고 아무도 잡을 수 없어요.",
		"ability_1_cd": ["gravity", "float_cooldown", 15.0],
		"ability_2": "무중력 구슬",
		"ability_2_desc": "구슬을 던져 맞은 술래를 3초 동안 60% 느리게 만들어요.",
		"ability_2_cd": ["gravity", "orb_cooldown", 15.0],
	},
}


static func get_info(id: String) -> Dictionary:
	return DATA.get(id, DATA["chameleon"])


## 능력 쿨타임(초). 패시브면 0
static func cooldown(id: String, slot: int) -> float:
	var cd: Array = get_info(id)["ability_%d_cd" % slot]
	if cd.is_empty():
		return 0.0
	return GameConfig.num(cd[0], cd[1], cd[2])


## 충전식 능력이면 최대 충전 수, 아니면 0 (카메라맨 카메라처럼)
static func max_charges(id: String, slot: int) -> int:
	var c = get_info(id).get("ability_%d_charges" % slot, [])
	if (c as Array).is_empty():
		return 0
	return int(GameConfig.num(c[0], c[1], c[2]))


static func is_passive(id: String, slot: int) -> bool:
	return (get_info(id).get("ability_%d_cd" % slot, []) as Array).is_empty()


## 고유 능력 개수 (보통 2개, 히든 캐릭터는 3개)
static func slot_count(id: String) -> int:
	return 3 if get_info(id).has("ability_3") else 2


## 히든 캐릭터인지
static func is_hidden(id: String) -> bool:
	return bool(get_info(id).get("hidden", false))
