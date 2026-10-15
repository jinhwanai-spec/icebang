extends Node3D
## 이모트 미리 그려 보기용 대역 (main.gd _warmup_emotes).
## 이모트를 처음 쓸 때 효과·소리를 처음 만들고 그리느라 0.2~0.8초 멈칫하던 것을,
## 판 시작 때 검은 화면 뒤에서 모든 이모트를 한 번씩 미리 해 둬서 없앰.
var emote_id := ""
var dance_left := 99.0
var body: Node3D


func show_emote(_text: String) -> void:
	pass
