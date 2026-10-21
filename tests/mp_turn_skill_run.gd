extends Node
## 장면이 바뀌어도 살아 있게 루트에 붙여서 실행 (tests/mp_turn_skill.gd)
func _ready() -> void:
	var w := Node.new()
	w.set_script(load("res://tests/mp_turn_skill.gd"))
	get_tree().root.add_child.call_deferred(w)
