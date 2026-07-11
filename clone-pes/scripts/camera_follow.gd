extends Camera3D

## Cámara de transmisión: mantiene el ángulo y la altura que pusiste en el
## editor, y se desplaza siguiendo a la pelota en X (costados) y en Z
## (adelante/atrás), para que la jugada nunca quede fuera de cuadro.

## A quién seguir (por defecto, la pelota).
@export var target_path: NodePath = NodePath("../Ball")
## Suavidad del seguimiento (más alto = más rápido).
@export var smooth: float = 5.0
## Cuánto sigue en cada eje (0 = nada, 1 = 1:1 con la pelota).
@export var follow_x: float = 1.0
@export var follow_z: float = 0.9
## Desplazamiento máximo respecto del centro, para no salirse de la cancha.
@export var limit_x: float = 22.0
@export var limit_z: float = 16.0

var _target: Node3D
var _base: Vector3   # posición inicial de la cámara (define ángulo/altura/encuadre)

func _ready() -> void:
	_target = get_node_or_null(target_path)
	_base = global_position

func _physics_process(delta: float) -> void:
	if _target == null:
		return
	var tp: Vector3 = _target.global_position
	var desired := _base
	desired.x = _base.x + clampf(tp.x * follow_x, -limit_x, limit_x)
	desired.z = _base.z + clampf(tp.z * follow_z, -limit_z, limit_z)
	global_position = global_position.lerp(desired, clampf(smooth * delta, 0.0, 1.0))
