extends Area3D

## Arco. Es una zona (Area3D) que detecta cuándo la pelota la cruza
## y avisa (señal) para que el administrador del juego cuente el gol.

## Nombre del equipo que ANOTA cuando la pelota entra en este arco.
@export var team_name: String = "Equipo"

## Se emite cuando la pelota entra. Pasa este arco como dato.
signal ball_scored(goal: Node)

func _ready() -> void:
	add_to_group("goal")
	# Detectar la capa 2 (la pelota).
	collision_mask = 2
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("ball"):
		ball_scored.emit(self)
