extends RigidBody3D

## Pelota. Puede estar SUELTA (física normal, rueda y rebota) o
## CONDUCIDA por un jugador (el administrador la congela y la reposiciona
## pegada al jugador). Acá configuramos capas, física, el modelo 3D y el reset.

const MODEL_PATH := "res://assets/models/iqiniso-fifa-5200.glb"
## Escala del modelo (se ajusta desde el Inspector). Con ~0.35 queda del
## tamaño de la esfera de colisión (radio ~0.16), acorde al personaje.
@export var model_scale: float = 0.35
@export var model_y: float = 0.0

func _ready() -> void:
	add_to_group("ball")
	# La pelota está en la capa 2 y solo choca con el mundo (capa 1):
	# rueda por el piso y rebota en las vallas, pero atraviesa a los
	# jugadores (la posesión se maneja por cercanía, no por choque).
	collision_layer = 2
	collision_mask = 1
	# Al "congelarla" para conducirla, se comporta como cuerpo cinemático.
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	# Rebote: pica contra el piso y las vallas.
	var pm := PhysicsMaterial.new()
	pm.bounce = 0.5
	pm.friction = 0.6
	physics_material_override = pm
	# Menos rozamiento para que viaje y pique mejor (antes 0.8 la frenaba mucho).
	linear_damp = 0.4
	_setup_model()

## Carga el modelo 3D de la pelota; si el .glb no está importado, deja la esfera.
func _setup_model() -> void:
	if not ResourceLoader.exists(MODEL_PATH):
		return
	var res = load(MODEL_PATH)
	if res == null:
		return
	var model: Node3D = res.instantiate()
	model.name = "Model"
	model.scale = Vector3.ONE * model_scale
	model.position = Vector3(0, model_y, 0)
	add_child(model)
	var sphere = get_node_or_null("Mesh")
	if sphere:
		sphere.visible = false

## Frena la pelota, la descongela y la reubica (por ejemplo, tras un gol).
func reset(to_position: Vector3) -> void:
	freeze = false
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	global_position = to_position
