extends Control

## Menú principal: banner + botones Iniciar Juego / Salir.

func _ready() -> void:
	$Center/VBox/Play.pressed.connect(_on_play)
	$Center/VBox/Quit.pressed.connect(_on_quit)
	$Center/VBox/Play.grab_focus()

func _on_play() -> void:
	get_tree().change_scene_to_file("res://scenes/team_select.tscn")

func _on_quit() -> void:
	get_tree().quit()
