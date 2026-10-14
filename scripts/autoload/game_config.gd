extends Node
## [자동 로드] 게임 설정 담당
## - balance.cfg 파일에서 밸런스 숫자를 읽어옵니다.
## - 키보드 조작(입력 맵)을 등록합니다.
## 어디서든 GameConfig.num("섹션", "이름", 기본값) 으로 숫자를 꺼내 쓸 수 있어요.

const CONFIG_PATH := "res://balance.cfg"

var _cfg := ConfigFile.new()


func _ready() -> void:
	var err := _cfg.load(CONFIG_PATH)
	if err != OK:
		# 파일이 없어도 각 스크립트에 적힌 기본값으로 게임은 돌아갑니다.
		push_warning("balance.cfg를 읽지 못했습니다. 기본값을 사용합니다. (오류 코드 %d)" % err)
	_setup_inputs()


## 숫자 설정값 읽기. 파일에 없으면 default_value를 돌려줍니다.
func num(section: String, key: String, default_value: float) -> float:
	return float(_cfg.get_value(section, key, default_value))


## 켜기/끄기(true/false) 설정값 읽기
func flag(section: String, key: String, default_value: bool) -> bool:
	return bool(_cfg.get_value(section, key, default_value))


## 키 배치. 바꾸고 싶으면 아래 KEY_ 부분만 바꾸면 됩니다.
func _setup_inputs() -> void:
	_bind_key("move_forward", KEY_W)
	_bind_key("move_back", KEY_S)
	_bind_key("move_left", KEY_A)
	_bind_key("move_right", KEY_D)
	_bind_key("run", KEY_SHIFT)
	_bind_key("sneak", KEY_CTRL)
	_bind_key("freeze", KEY_Q)          # 얼음
	_bind_key("interact", KEY_E)        # 봉인석 가동 (누르고 있기)
	_bind_key("ability_1", KEY_R)       # 캐릭터 고유 능력 1
	_bind_key("ability_2", KEY_T)       # 캐릭터 고유 능력 2
	_bind_key("ability_3", KEY_Y)       # 캐릭터 고유 능력 3 (히든 캐릭터)
	_bind_key("ability_noise", KEY_F)   # 상점 공통 능력: 소리 내기 (얼음 상태)
	_bind_key("emote", KEY_G)           # 상점 공통 능력: 이모티콘 (얼음 상태)
	_bind_key("pick_1", KEY_1)          # 소환할 동료 고르기
	_bind_key("pick_2", KEY_2)
	_bind_key("pick_3", KEY_3)
	_bind_key("pause", KEY_ESCAPE)
	_bind_key("roll", KEY_SPACE)        # 구르기


func _bind_key(action: String, key: Key) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = key
	InputMap.action_add_event(action, ev)
