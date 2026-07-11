extends Control

## Selección de equipo: elegís jugar como Local (azul) o Visitante (rojo)
## y arranca el partido. Navegable con teclado o gamepad.

var _selected: int = 0

func _ready() -> void:
	$Center/VBox/Teams/Local.pressed.connect(func(): _select(0))
	$Center/VBox/Teams/Visit.pressed.connect(func(): _select(1))
	$Center/VBox/Play.pressed.connect(_on_play)
	$Center/VBox/Back.pressed.connect(_on_back)
	_select(0)
	$Center/VBox/Play.grab_focus()

func _select(team: int) -> void:
	_selected = team
	$Center/VBox/Teams/Local.modulate = Color(1, 1, 1, 1) if team == 0 else Color(0.45, 0.45, 0.45, 1)
	$Center/VBox/Teams/Visit.modulate = Color(1, 1, 1, 1) if team == 1 else Color(0.45, 0.45, 0.45, 1)

func _on_play() -> void:
	GameConfig.human_team = _selected
	get_tree().change_scene_to_file("res://scenes/main.tscn")

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")
