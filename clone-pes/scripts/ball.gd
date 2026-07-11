extends RigidBody3D

## Pelota. Puede estar SUELTA (física normal, rueda y rebota) o
## CONDUCIDA por un jugador (el administrador la congela y la reposiciona
## pegada al jugador). Acá solo configuramos capas y el reset.

func _ready() -> void:
	add_to_group("ball")
	# La pelota está en la capa 2 y solo choca con el mundo (capa 1):
	# rueda por el piso y rebota en las vallas, pero atraviesa a los
	# jugadores (la posesión se maneja por cercanía, no por choque).
	collision_layer = 2
	collision_mask = 1
	# Al "congelarla" para conducirla, se comporta como cuerpo cinemático.
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC

## Frena la pelota, la descongela y la reubica (por ejemplo, tras un gol).
func reset(to_position: Vector3) -> void:
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = to_position
