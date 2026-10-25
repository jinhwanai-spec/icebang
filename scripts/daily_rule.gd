class_name DailyRule
## 오늘의 규칙: 판마다 하나씩 바뀌는 특별 규칙 (같은 맵도 매번 다르게)
## 규칙은 balance.cfg 숫자를 판 동안만 바꿔 씀 (GameConfig.overrides). 판이 끝나면 원래대로
##   mul = 원래 값에 곱함 / set = 이 값으로 / add = 원래 값에 더함
## 새 규칙을 넣으려면 RULES 에 한 줄 추가 (코드 지원이 필요한 값: blackout/*, seeker/body_scale, freeze_rule/max_freezes)

const RULES := [
	{"id": "short_breath", "name": "숨이 찬 밤", "desc": "스태미나가 절반이에요. 달리기를 아껴요",
		"mul": {"stamina/max": 0.5}},
	{"id": "quick_thaw", "name": "따뜻한 밤", "desc": "땡(해동) 시간이 절반이에요",
		"mul": {"player/thaw_time": 0.5}},
	{"id": "rage_night", "name": "폭주의 밤", "desc": "술래가 처음부터 폭주해요. 대신 봉인석이 1개 적어요",
		"set": {"seeker/rage_time": 4.0}, "add": {"mission/count": -1}},
	{"id": "fog_night", "name": "짙은 안개", "desc": "안개가 두 배로 짙어요. 술래 눈도 흐려져서 소리로 찾아와요",
		"mul": {"view/fog_density": 2.0, "seeker/far_sight_range": 0.7}},
	{"id": "blackout_night", "name": "정전이 잦은 밤", "desc": "정전이 세 번 일어나요",
		"set": {"blackout/count": 3, "blackout/first_min": 35, "blackout/first_max": 70, "blackout/gap_min": 45, "blackout/gap_max": 80}},
	{"id": "tiny_seeker", "name": "꼬마 술래", "desc": "술래가 작아졌지만 15% 빨라요",
		"mul": {"seeker/move_speed": 1.15}, "set": {"seeker/body_scale": 0.7}},
	{"id": "keen_ears", "name": "귀 밝은 술래", "desc": "술래가 코앞(3m)만 보지만 발소리를 두 배 멀리서 들어요. 살금살금(Ctrl)!",
		"mul": {"seeker/far_sight_range": 0.3, "seeker/near_sight_range": 0.5, "seeker/hearing_multiplier": 2.0}, "set": {"seeker/hear_ping": 1}},
	{"id": "loud_steps", "name": "삐걱이는 밤", "desc": "걷는 발소리가 두 배 멀리 퍼져요 (살금살금은 그대로)",
		"mul": {"player/walk_noise": 2.0}},
	{"id": "freeze_limit", "name": "얼음 아끼기", "desc": "얼음은 한 사람당 3번까지만 쓸 수 있어요",
		"set": {"freeze_rule/max_freezes": 3}},
	{"id": "gold_night", "name": "황금의 밤", "desc": "판이 끝나면 코인을 두 배로 받아요",
		"mul": {"reward/clear": 2.0, "reward/per_mission": 2.0, "reward/per_rescue": 2.0}},
]

## balance.cfg 에 없을 때 쓸 원래 값
const BASE := {"stamina/max": 100.0, "player/thaw_time": 10.0, "seeker/rage_time": 600.0, "mission/count": 3.0,
	"view/fog_density": 0.06, "seeker/move_speed": 1.1, "seeker/far_sight_range": 12.0, "seeker/near_sight_range": 4.0,
	"seeker/hearing_multiplier": 1.3, "player/walk_noise": 9.0, "reward/clear": 50.0, "reward/per_mission": 10.0, "reward/per_rescue": 5.0}


static func find(id: String) -> Dictionary:
	for r in RULES:
		if r["id"] == id:
			return r
	return {}


## 설정(SaveData.daily_rule)에 따라 이번 판 규칙: "random" = 무작위 / "" = 없음 / 규칙 id = 그 규칙
static func choose() -> String:
	var pick: String = SaveData.daily_rule
	if pick == "random":
		return RULES[randi() % RULES.size()]["id"]
	return pick if not find(pick).is_empty() else ""


## 판 시작 전에 숫자 바꾸기
static func apply(id: String) -> void:
	GameConfig.overrides.clear()
	var r := find(id)
	if r.is_empty():
		return
	for k in r.get("mul", {}):
		GameConfig.overrides[k] = _base(k) * float(r["mul"][k])
	for k in r.get("add", {}):
		GameConfig.overrides[k] = maxf(2.0, _base(k) + float(r["add"][k]))
	for k in r.get("set", {}):
		GameConfig.overrides[k] = float(r["set"][k])


static func clear() -> void:
	GameConfig.overrides.clear()


static func _base(k: String) -> float:
	var p := k.split("/")
	return GameConfig.base_num(p[0], p[1], float(BASE.get(k, 1.0)))
