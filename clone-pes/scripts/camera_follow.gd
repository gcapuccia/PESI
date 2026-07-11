extends Camera3D

## Cámara de transmisión: mantiene el ángulo y la altura que pusiste en
## el editor, y solo se desplaza de lado (eje X) siguiendo a la pelota.

## A quién seguir (por defecto, la pelota hermana del jugador).
@export var target_path: NodePath = NodePath("../Ball")
## Desplazamiento fijo respecto de la pelota en X.
@export var offset_x: float = 0.0
## Suavidad del seguimiento (más alto = más rápido).
@export var smooth: float = 4.0
## Límites para que la cámara no muestre fuera de la cancha.
@export var min_x: float = -14.0
@export var max_x: float = 14.0

var _target: Node3D

func _ready() -> void:
	_target = get_node_or_null(target_path)

func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var desired := global_position
	desired.x = clampf(_target.global_position.x + offset_x, min_x, max_x)
	global_position = global_position.lerp(desired, clampf(smooth * delta, 0.0, 1.0))
