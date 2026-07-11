extends CharacterBody3D

## Un jugador. Solo se encarga de MOVERSE:
##   MODE_HUMAN -> lo movés vos con el teclado
##   MODE_AI    -> camina hacia el objetivo (ai_target) que le fija el
##                 administrador del partido (main.gd)
## Toda la lógica de la pelota (conducir, tirar, robar) vive en main.gd.

const MODE_HUMAN := 0
const MODE_AI := 1

## Velocidad de carrera en metros por segundo.
@export var speed: float = 6.0
## Equipo: 0 = Local (azul), 1 = Visitante (rojo).
@export var team: int = 0

var mode: int = MODE_AI
var ai_target: Vector3 = Vector3.ZERO
var is_controlled: bool = false
## Hacia dónde mira (última dirección de movimiento). Sirve para tirar.
var facing: Vector3 = Vector3.FORWARD

## --- Modelo 3D opcional (UAL2). Si el .glb no está importado en Godot,
## el jugador queda como cápsula (fallback). Ajustables desde el Inspector. ---
const MODEL_PATH := "res://assets/models/UAL2_Standard.glb"
@export var model_scale: float = 1.0
@export var model_y: float = 0.0
@export var model_yaw_deg: float = 0.0   ## girar si el modelo mira al revés
@export var idle_anim: String = "Idle_No_Loop"
@export var move_anim: String = "Walk_Carry_Loop"
@export var stumble_anim: String = "Hit_Knockback"

var _anim: AnimationPlayer = null
var _cur_anim: String = ""
var _idle_resolved: String = ""
var _move_resolved: String = ""
var _stumble_resolved: String = ""
var _stun: float = 0.0
static var _debug_printed: bool = false

@onready var _selector = get_node_or_null("Selector")

func _ready() -> void:
	add_to_group("player")
	# Capas de colisión: los jugadores están en la capa 3 y solo chocan
	# con el mundo (capa 1). Así NO chocan entre ellos ni con la pelota.
	collision_layer = 4
	collision_mask = 1

	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.15, 0.35, 0.85) if team == 0 else Color(0.85, 0.2, 0.2)
	var mesh = get_node_or_null("Mesh")
	if mesh:
		mesh.material_override = mat
	if _selector:
		_selector.visible = false

	_setup_model()

## El administrador marca a este jugador como el que controla el humano.
func set_controlled(value: bool) -> void:
	is_controlled = value
	if _selector:
		_selector.visible = value

func _physics_process(delta: float) -> void:
	# Trastabilla: si le sacaron la pelota, se queda quieto un instante.
	if _stun > 0.0:
		_stun -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		if _anim and _stumble_resolved != "":
			_play(_stumble_resolved)
		return

	var direction := Vector3.ZERO

	if mode == MODE_HUMAN:
		var input_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
		direction = Vector3(input_dir.x, 0.0, input_dir.y)
	else:
		var to_target := ai_target - global_position
		to_target.y = 0.0
		if to_target.length() > 0.4:
			direction = to_target.normalized()

	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	move_and_slide()

	if direction.length() > 0.1:
		facing = direction.normalized()
		var target_angle := atan2(direction.x, direction.z)
		rotation.y = lerp_angle(rotation.y, target_angle, 12.0 * delta)

	# Animación: caminar si se mueve, idle si está quieto.
	if _anim:
		var planar_speed := Vector2(velocity.x, velocity.z).length()
		_play(_move_resolved if planar_speed > 0.5 else _idle_resolved)

## Carga el modelo 3D y lo prepara; si el .glb no está importado, no hace nada
## (el jugador queda como cápsula).
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
	model.rotation.y = deg_to_rad(model_yaw_deg)
	add_child(model)

	# Ocultar cápsula y nariz: el modelo ya muestra cuerpo y orientación.
	var capsule = get_node_or_null("Mesh")
	if capsule:
		capsule.visible = false
	var nose = get_node_or_null("Nose")
	if nose:
		nose.visible = false

	# Pintar el modelo del color del equipo.
	var col: Color = Color(0.15, 0.35, 0.85) if team == 0 else Color(0.85, 0.2, 0.2)
	var team_mat := StandardMaterial3D.new()
	team_mat.albedo_color = col
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		mi.material_override = team_mat

	# Animador del modelo.
	var players: Array = model.find_children("*", "AnimationPlayer", true, false)
	if not _debug_printed:
		_debug_printed = true
		var meshes_found: int = model.find_children("*", "MeshInstance3D", true, false).size()
		print("[UAL2] MeshInstance3D=", meshes_found, "  AnimationPlayer=", players.size())
		if players.size() > 0:
			print("[UAL2] animaciones: ", (players[0] as AnimationPlayer).get_animation_list())
	if players.size() > 0:
		_anim = players[0] as AnimationPlayer
		# Resolver nombres exactos; si fallan, buscar por palabra clave.
		_idle_resolved = _resolve_anim(idle_anim)
		if _idle_resolved == "":
			_idle_resolved = _first_matching("idle")
		_move_resolved = _resolve_anim(move_anim)
		if _move_resolved == "":
			_move_resolved = _first_matching("walk")
		if _move_resolved == "":
			_move_resolved = _first_matching("run")
		_stumble_resolved = _resolve_anim(stumble_anim)
		# Que idle y caminar se repitan.
		for n in [_idle_resolved, _move_resolved]:
			if n != "" and _anim.has_animation(n):
				_anim.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		_play(_idle_resolved)

## Reproduce una animación (sin reiniciarla si ya está sonando).
func _play(anim_name: String) -> void:
	if _anim == null or anim_name == "" or anim_name == _cur_anim:
		return
	if _anim.has_animation(anim_name):
		_anim.play(anim_name)
		_cur_anim = anim_name

## Lo llama el administrador cuando a este jugador le sacan la pelota:
## se queda quieto (trastabilla) por unos instantes.
func stumble(duration: float) -> void:
	_stun = max(_stun, duration)

## Encuentra el nombre real de una animación (tolera prefijos de librería).
func _resolve_anim(wanted: String) -> String:
	if _anim == null or wanted == "":
		return ""
	var list := _anim.get_animation_list()
	for a in list:
		if a == wanted:
			return a
	for a in list:
		if a.ends_with("/" + wanted):
			return a
	for a in list:
		if wanted.to_lower() in a.to_lower():
			return a
	return ""

## Primera animación cuyo nombre contiene la palabra clave (ej. "idle", "walk").
func _first_matching(keyword: String) -> String:
	if _anim == null:
		return ""
	for a in _anim.get_animation_list():
		if keyword.to_lower() in a.to_lower():
			return a
	return ""
