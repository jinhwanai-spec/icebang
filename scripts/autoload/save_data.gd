extends Node
## [자동 로드] 저장 데이터 담당 (성장 시스템)
## - 코인, 현재 스테이지, 해금한 얼음 상태 능력을 기억합니다.
## - user://save.cfg 파일에 저장됩니다.
##   (Windows 기준: %APPDATA%/Godot/app_userdata/얼음땡 프로토타입/save.cfg)
## - 나중에 Steam 클라우드 저장은 이 파일 하나만 동기화하면 됩니다.

const SAVE_PATH := "user://save.cfg"
## 저장 규칙 버전 (2 = 11스테이지 + 게임 클리어 방식)
const RULES_VERSION := 2

var coins := 0
var stage := 1
var best_stage := 1
## 게임 클리어(마지막 스테이지까지) 횟수
var clears := 0
## 마지막으로 고른 캐릭터 id (characters.gd 참고)
var selected_character := "chameleon"
## 그래픽 품질: "high" (안개 속 빛줄기 등 고급 효과) / "low" (사양 낮은 PC용)
var graphics := "high"
## 능력 이름 → 해금 여부
var unlocked := {
	"noise": false,  # 소리 내기
	"emote": false,  # 이모티콘
}


func _ready() -> void:
	load_game()


func load_game() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return  # 처음 실행하면 저장 파일이 없으니 기본값 그대로
	coins = int(cfg.get_value("progress", "coins", 0))
	stage = int(cfg.get_value("progress", "stage", 1))
	best_stage = int(cfg.get_value("progress", "best_stage", 1))
	clears = int(cfg.get_value("progress", "clears", 0))
	# 규칙이 바뀐 예전 저장 파일(스테이지가 끝없이 올라가던 때)은 스테이지 1부터 다시
	if int(cfg.get_value("progress", "rules", 1)) < RULES_VERSION:
		stage = 1
		best_stage = mini(best_stage, 11)
	selected_character = str(cfg.get_value("progress", "character", "chameleon"))
	graphics = str(cfg.get_value("settings", "graphics", "high"))
	for id in unlocked.keys():
		unlocked[id] = bool(cfg.get_value("unlocked", id, false))


func save_game() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "coins", coins)
	cfg.set_value("progress", "stage", stage)
	cfg.set_value("progress", "best_stage", best_stage)
	cfg.set_value("progress", "clears", clears)
	cfg.set_value("progress", "rules", RULES_VERSION)
	cfg.set_value("progress", "character", selected_character)
	cfg.set_value("settings", "graphics", graphics)
	for id in unlocked.keys():
		cfg.set_value("unlocked", id, unlocked[id])
	cfg.save(SAVE_PATH)


func high_graphics() -> bool:
	return graphics != "low"


func add_coins(amount: int) -> void:
	coins += amount


func has_ability(id: String) -> bool:
	return bool(unlocked.get(id, false))


func price_of(id: String) -> int:
	return int(GameConfig.num("shop", id + "_price", 100))


## 상점에서 능력 구매. 성공하면 true
func buy(id: String) -> bool:
	if has_ability(id) or coins < price_of(id):
		return false
	coins -= price_of(id)
	unlocked[id] = true
	save_game()
	return true


func advance_stage() -> void:
	stage += 1
	best_stage = max(best_stage, stage)


## 기록 초기화 (메뉴의 "기록 초기화" 버튼)
func reset() -> void:
	coins = 0
	stage = 1
	best_stage = 1
	for id in unlocked.keys():
		unlocked[id] = false
	save_game()
