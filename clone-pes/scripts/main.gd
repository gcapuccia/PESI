extends Node3D

## Administrador del partido con modelo de POSESIÓN (estilo Winning Eleven):
##  - un jugador "tiene" la pelota y la conduce pegada (no la empuja)
##  - con Espacio, el que tiene la pelota tira/pasa hacia donde mira
##  - un rival cercano roba (la IA roba con algo de suerte; vos con la tecla E)
##  - el equipo con la pelota ACOMPAÑA la jugada; el otro defiende
##  - cuando tu equipo gana la pelota, pasás a controlar a ese jugador

## Ruta a la pelota.
@export var ball_path: NodePath = NodePath("Ball")
## Dónde reaparece la pelota tras un gol.
@export var reset_position: Vector3 = Vector3(0, 1, 0)

const GOAL_X := 28.0           ## X (absoluto) de la línea de gol
const CAPTURE_RADIUS := 1.1    ## a qué distancia se agarra una pelota suelta
const TACKLE_RADIUS := 1.1     ## a qué distancia se puede robar
const PROTECT_TIME := 1.1      ## segundos sin poder ser robado tras ganar la pelota
const LOOSE_LOCK := 0.25       ## tras un tiro, instante sin poder recapturar
const DRIBBLE_OFFSET := 0.9    ## qué tan adelante se lleva la pelota
const BALL_Y := 0.16           ## altura de la pelota en el piso (= radio de la pelota)
const SHOOT_RANGE := 13.0      ## distancia al arco desde la que la IA remata
const LIFT_THRESHOLD := 16.0   ## potencia mínima para que el tiro se eleve
const LIFT_FACTOR := 0.55      ## cuánto se eleva por potencia por encima del umbral
const MAX_LIFT := 8.0          ## elevación (velocidad vertical) máxima
const OUT_X := 33.0            ## la pelota está afuera si pasa esta X
const OUT_Z := 20.0            ## la pelota está afuera si pasa esta Z
const GK_RANGE_Z := 4.5        ## rango lateral (palo a palo) del arquero
const SHOOT_SPEED := 20.0      ## velocidad del disparo de la IA
const PASS_SPEED := 14.0       ## velocidad del pase
const CHARGE_TIME := 0.9       ## segundos para cargar tiro/pase al máximo
const MIN_SHOT_SPEED := 12.0   ## potencia del tiro con carga mínima
const MAX_SHOT_SPEED := 28.0   ## potencia del tiro con carga máxima
const MIN_PASS_SPEED := 10.0   ## potencia del pase con carga mínima (toque)
const MAX_PASS_SPEED := 24.0   ## potencia del pase con carga máxima
const SWITCH_LOCK_TIME := 2.0  ## segundos que el auto-cambio respeta tu cambio manual
const STEAL_CHANCE := 0.02     ## probabilidad por frame de que la IA robe estando en rango
const PASS_PRESSURE := 2.6     ## si un rival está más cerca que esto, la IA piensa en pasar
const PASS_CHANCE := 0.015     ## probabilidad por frame de pasar estando presionado
const AUTO_SWITCH_MARGIN := 2.5 ## cuánto más cerca debe estar otro para auto-cambiar en defensa

const STATE_KICKOFF := 0       ## esperando el saque del medio (nadie se mueve)
const STATE_PLAYING := 1       ## partido en juego normal

## Formación base para un equipo que ataca hacia +X (se refleja para el otro).
## Orden: arquero, defensor, defensor, delantero, delantero.
const FORMATION := [
	Vector3(-25, 0, 0),    # arquero (usa su propia lógica, ver _goalkeeper_point)
	Vector3(-16, 0, -8),
	Vector3(-16, 0, 8),
	Vector3(-6, 0, -11),
	Vector3(-6, 0, 11),
]

var _ball = null
var _team0: Array = []   # Local (azul), ataca +X
var _team1: Array = []   # Visitante (rojo), ataca -X
var _human_team: int = 0        # equipo que controla el humano (de GameConfig)
var _hteam: Array = []          # jugadores del equipo humano
var _hteam_field: Array = []    # equipo humano sin el arquero (para los cambios)
var _own_goal_dir: float = -1.0 # dirección hacia el arco propio del humano
var _controlled = null   # jugador que controla el humano
var _holder = null       # jugador que tiene la pelota (o null si está suelta)
var _protect: float = 0.0
var _loose_lock: float = 0.0
var _score: Dictionary = {}
var _state: int = STATE_KICKOFF
var _kicker = null            # jugador que va a sacar del medio
var _kickoff_timer: float = 0.0
var _charging: bool = false   # cargando un tiro o pase
var _charge: float = 0.0      # nivel de carga 0..1
var _charge_action: String = ""  # "kick" (tiro) o "pass" (pase)
var _switch_lock: float = 0.0    # tiempo que el auto-cambio respeta tu cambio manual

@onready var _hud = get_node_or_null("HUD")

func _ready() -> void:
	_ball = get_node_or_null(ball_path)

	for g in get_tree().get_nodes_in_group("goal"):
		g.ball_scored.connect(_on_goal_scored)

	for p in get_tree().get_nodes_in_group("player"):
		if p.team == 0:
			_team0.append(p)
		else:
			_team1.append(p)

	_team0.sort_custom(func(a, b): return str(a.name) < str(b.name))
	_team1.sort_custom(func(a, b): return str(a.name) < str(b.name))

	# Equipo que controla el humano (elegido en el menú) y su versión sin arquero.
	_human_team = GameConfig.human_team
	_hteam = _team0 if _human_team == 0 else _team1
	_hteam_field = _hteam.duplicate()
	if _hteam_field.size() > 0:
		_hteam_field.remove_at(0)
	# El equipo 0 ataca +X (arco propio en -X); el equipo 1 al revés.
	_own_goal_dir = -1.0 if _human_team == 0 else 1.0

	_update_score_ui()
	# Arranca con saque del medio de tu equipo.
	_kickoff(_human_team)

func _physics_process(delta: float) -> void:
	if _ball == null:
		return

	_protect = max(0.0, _protect - delta)
	_loose_lock = max(0.0, _loose_lock - delta)
	_switch_lock = max(0.0, _switch_lock - delta)

	# Durante el saque del medio nadie se mueve hasta el primer pase.
	if _state == STATE_KICKOFF:
		_freeze_players_in_place()
		_update_kickoff(delta)
		return

	# Pelota fuera de la cancha (o por debajo del piso) → reponerla en el centro.
	if _holder == null:
		var bp: Vector3 = _ball.global_position
		if bp.y < -2.0 or absf(bp.x) > OUT_X or absf(bp.z) > OUT_Z:
			_ball.reset(Vector3(0, BALL_Y, 0))
			_loose_lock = LOOSE_LOCK

	if Input.is_action_just_pressed("switch"):
		_switch_to_nearest()
		_switch_lock = SWITCH_LOCK_TIME

	_update_possession()
	# No auto-cambiamos si mantenés I (perseguís) o si recién cambiaste a mano.
	if not Input.is_action_pressed("tackle") and _switch_lock <= 0.0:
		_auto_switch(_ball.global_position)
	_update_roles()
	_handle_tackle_pursuit()

# ---------------------------------------------------------------------------
# SAQUE DEL MEDIO (kickoff)
# ---------------------------------------------------------------------------

## Prepara el saque: ubica a todos en su mitad y le da la pelota al pateador.
func _kickoff(kick_team_id: int) -> void:
	_state = STATE_KICKOFF
	_holder = null
	_reset_positions()

	var kteam: Array = _team0 if kick_team_id == 0 else _team1
	var kicker = kteam[3] if kteam.size() > 3 else kteam[0]
	kicker.facing = Vector3.FORWARD
	kicker.global_position = Vector3(0, 0, 0.9)
	_kicker = kicker
	_kickoff_timer = 0.9

	_ball.reset(Vector3(0, BALL_Y, 0))
	_give_possession(kicker)

	# Si saca tu equipo, controlás al pateador.
	if kick_team_id == _human_team:
		_select(kicker)

## Durante el saque nadie se mueve; el humano (o la IA) da el primer pase.
func _update_kickoff(delta: float) -> void:
	if _holder:
		var hp: Vector3 = _holder.global_position + _holder.facing * DRIBBLE_OFFSET
		hp.y = BALL_Y
		_ball.global_position = hp

	if _kicker == _controlled:
		# Vos sacás con K (pase) o L (tiro).
		if Input.is_action_just_pressed("pass") or Input.is_action_just_pressed("kick"):
			_do_kickoff_pass()
	else:
		# La IA saca sola tras un instante.
		_kickoff_timer -= delta
		if _kickoff_timer <= 0.0:
			_do_kickoff_pass()

## El primer pase: obligatoriamente a un compañero por detrás de la línea.
func _do_kickoff_pass() -> void:
	var mate = _nearest_teammate_behind_line(_kicker)
	if mate:
		var to_mate: Vector3 = mate.global_position - _kicker.global_position
		_shoot(to_mate, PASS_SPEED)
	else:
		# Sin nadie detrás: tirar hacia la propia mitad.
		var attack_dir := 1.0 if _kicker.team == 0 else -1.0
		_shoot(Vector3(-attack_dir, 0, 0), PASS_SPEED)
	_state = STATE_PLAYING

## Deja a todos quietos en su lugar (para el saque).
func _freeze_players_in_place() -> void:
	for p in _team0 + _team1:
		p.mode = p.MODE_AI
		p.ai_target = p.global_position

## Reubica a cada equipo en su formación (propia mitad).
func _reset_positions() -> void:
	for i in _team0.size():
		var p = _team0[i]
		p.global_position = _formation_point(i, 1.0, Vector3.ZERO)
		p.velocity = Vector3.ZERO
	for i in _team1.size():
		var q = _team1[i]
		q.global_position = _formation_point(i, -1.0, Vector3.ZERO)
		q.velocity = Vector3.ZERO

## Compañero más cercano al pateador que esté detrás de la línea (propia mitad).
func _nearest_teammate_behind_line(kicker):
	var attack_dir := 1.0 if kicker.team == 0 else -1.0
	var mates: Array = _team0 if kicker.team == 0 else _team1
	var kp: Vector3 = kicker.global_position
	var best = null
	var best_d := INF
	for m in mates:
		if m == kicker:
			continue
		var mp: Vector3 = m.global_position
		if attack_dir * mp.x < -0.5:   # está en su propia mitad
			var d: float = kp.distance_to(mp)
			if d < best_d:
				best_d = d
				best = m
	return best

# ---------------------------------------------------------------------------
# POSESIÓN: captura, conducción, tiro y robo
# ---------------------------------------------------------------------------

func _update_possession() -> void:
	# Si estabas cargando un tiro y ya no tenés la pelota, cancelá la carga.
	if _charging and _holder != _controlled:
		_cancel_charge()

	if _holder == null:
		# Pelota suelta: el más cercano la agarra (salvo instante tras un tiro).
		if _loose_lock <= 0.0:
			var ball_pos: Vector3 = _ball.global_position
			var nearest = _nearest_player_to(ball_pos, _team0 + _team1)
			if nearest and nearest.global_position.distance_to(ball_pos) < CAPTURE_RADIUS:
				_give_possession(nearest)
		return

	# Hay dueño: la pelota va pegada, adelante de él.
	var hold_pos: Vector3 = _holder.global_position + _holder.facing * DRIBBLE_OFFSET
	hold_pos.y = BALL_Y
	_ball.global_position = hold_pos
	_ball.linear_velocity = Vector3.ZERO
	_ball.angular_velocity = Vector3.ZERO

	# El humano con la pelota: mantené K (pase) o L (tiro) para cargar la
	# potencia, y soltá para ejecutar. Un toque rápido = suave; mantenido = fuerte.
	if _holder == _controlled:
		if not _charging and Input.is_action_just_pressed("pass"):
			_charging = true
			_charge = 0.0
			_charge_action = "pass"
		elif not _charging and Input.is_action_just_pressed("kick"):
			_charging = true
			_charge = 0.0
			_charge_action = "kick"

		if _charging and Input.is_action_pressed(_charge_action):
			_charge = minf(1.0, _charge + get_physics_process_delta_time() / CHARGE_TIME)
			if _hud:
				_hud.set_power(_charge)

		if _charging and Input.is_action_just_released(_charge_action):
			var c: float = _charge
			var act: String = _charge_action
			_cancel_charge()
			if act == "kick":
				_shoot(_holder.facing, lerpf(MIN_SHOT_SPEED, MAX_SHOT_SPEED, c))
			else:
				_human_pass(lerpf(MIN_PASS_SPEED, MAX_PASS_SPEED, c))
			return

	# La IA con la pelota: remata, o pasa si está presionada.
	if _holder != _controlled:
		var attack_dir := 1.0 if _holder.team == 0 else -1.0
		var goal_pos := Vector3(GOAL_X * attack_dir, 0, 0)
		# 1) Remate si está cerca del arco rival.
		if _holder.global_position.distance_to(goal_pos) < SHOOT_RANGE:
			_shoot((goal_pos - _holder.global_position).normalized(), SHOOT_SPEED)
			return
		# 2) Pase ocasional si un rival lo presiona y hay compañero adelantado.
		var def_team: Array = _team1 if _holder.team == 0 else _team0
		var presser = _nearest_player_to(_holder.global_position, def_team)
		if presser:
			var pd: float = presser.global_position.distance_to(_holder.global_position)
			if pd < PASS_PRESSURE and randf() < PASS_CHANCE:
				var mate = _best_pass_target(_holder, attack_dir)
				if mate:
					var to_mate: Vector3 = mate.global_position - _holder.global_position
					_shoot(to_mate, PASS_SPEED)
					return

	# Robo: solo si pasó la protección del que la tiene.
	if _protect <= 0.0:
		var defenders: Array = _team1 if _holder.team == 0 else _team0
		# Vos, defendiendo, robás apretando la tecla de robar (E).
		if _controlled in defenders and _controlled != _holder:
			var dist: float = _controlled.global_position.distance_to(_holder.global_position)
			if dist < TACKLE_RADIUS and Input.is_action_pressed("tackle"):
				_give_possession(_controlled)
				return
		# La IA defensora roba con algo de suerte (no instantáneo).
		var stealer = _nearest_player_to(_holder.global_position, defenders)
		if stealer and stealer != _controlled:
			var d: float = stealer.global_position.distance_to(_holder.global_position)
			if d < TACKLE_RADIUS and randf() < STEAL_CHANCE:
				_give_possession(stealer)

func _give_possession(p) -> void:
	var prev = _holder
	_holder = p
	_protect = PROTECT_TIME
	_ball.freeze = true
	# El que perdió la pelota (si se la robaron) trastabilla medio segundo.
	if prev != null and prev != p:
		prev.stumble(0.5)
	# Si tu equipo gana la pelota, pasás a controlar a ese jugador.
	if p.team == _human_team:
		_select(p)

## Suelta la pelota y la lanza en una dirección con cierta potencia.
func _shoot(dir: Vector3, power: float) -> void:
	_ball.freeze = false
	var d := dir
	d.y = 0.0
	if d.length() < 0.01:
		d = Vector3.FORWARD
	d = d.normalized()
	_ball.global_position = _holder.global_position + _holder.facing * DRIBBLE_OFFSET + Vector3(0, BALL_Y, 0)
	# Si el tiro es fuerte, la pelota se eleva (para clavarla arriba o mandarla afuera).
	var lift: float = clampf((power - LIFT_THRESHOLD) * LIFT_FACTOR, 0.0, MAX_LIFT)
	_ball.linear_velocity = d * power + Vector3.UP * lift
	_holder = null
	_loose_lock = LOOSE_LOCK

## Elige el mejor compañero para pasar: uno adelantado hacia el arco rival.
func _best_pass_target(holder, attack_dir: float):
	var mates: Array = _team0 if holder.team == 0 else _team1
	var hp: Vector3 = holder.global_position
	var best = null
	var best_score := -INF
	for m in mates:
		if m == holder:
			continue
		var mp: Vector3 = m.global_position
		var progress: float = attack_dir * (mp.x - hp.x)   # cuánto más adelante está
		var dist: float = hp.distance_to(mp)
		if progress > 1.0 and dist < 16.0:
			var score: float = progress - dist * 0.1
			if score > best_score:
				best_score = score
				best = m
	return best

## Pase del humano: va al compañero más cercano en la dirección hacia la que
## mirás, aunque no esté justo adelante. Si no hay ninguno razonable, sale recto.
func _human_pass(power: float) -> void:
	var mate = _best_human_pass_target()
	if mate:
		var to_mate: Vector3 = mate.global_position - _holder.global_position
		_shoot(to_mate, power)
	else:
		_shoot(_holder.facing, power)

## Prioriza: (1) el compañero más cercano dentro de un cono ancho (~80°) de donde
## mirás, (2) el más cercano del lado hacia el que mirás, (3) el más cercano en general.
func _best_human_pass_target():
	var mates: Array = _team0 if _holder.team == 0 else _team1
	var hp: Vector3 = _holder.global_position
	var facing: Vector3 = _holder.facing
	facing.y = 0.0
	var has_facing: bool = facing.length() > 0.01
	if has_facing:
		facing = facing.normalized()

	var cone = null
	var cone_d := INF
	var front = null
	var front_d := INF
	var any = null
	var any_d := INF
	for m in mates:
		if m == _holder:
			continue
		var to_m: Vector3 = m.global_position - hp
		to_m.y = 0.0
		var dist: float = to_m.length()
		if dist < 0.5:
			continue
		if dist < any_d:
			any_d = dist
			any = m
		if has_facing:
			var dir_m := to_m.normalized()
			if facing.angle_to(dir_m) <= deg_to_rad(80.0) and dist < cone_d:
				cone_d = dist
				cone = m
			if facing.dot(dir_m) > 0.0 and dist < front_d:
				front_d = dist
				front = m
	if cone:
		return cone
	if front:
		return front
	return any

## Auto-cambio en defensa: si no tenés la pelota, controlás al más cercano a ella.
func _auto_switch(ball_pos: Vector3) -> void:
	# Si tu equipo tiene la pelota, ya controlás al que la lleva.
	if _holder != null and _holder.team == _human_team:
		return
	var nearest = _nearest_player_to(ball_pos, _hteam_field)
	if nearest == null or nearest == _controlled:
		return
	var np: Vector3 = nearest.global_position
	var new_d: float = np.distance_to(ball_pos)
	var cur_d: float = INF
	if _controlled:
		var cp: Vector3 = _controlled.global_position
		cur_d = cp.distance_to(ball_pos)
	# Solo cambiamos si el nuevo está bastante más cerca (evita parpadeo).
	if cur_d - new_d > AUTO_SWITCH_MARGIN:
		_select(nearest)

# ---------------------------------------------------------------------------
# ROLES: qué objetivo persigue cada jugador de la IA
# ---------------------------------------------------------------------------

func _update_roles() -> void:
	var ball_pos: Vector3 = _ball.global_position
	if _holder == null:
		_assign_loose(_team0, 1.0, ball_pos)
		_assign_loose(_team1, -1.0, ball_pos)
	elif _holder.team == 0:
		_assign_attacking(_team0, 1.0)
		_assign_defending(_team1, -1.0, ball_pos)
	else:
		_assign_attacking(_team1, -1.0)
		_assign_defending(_team0, 1.0, ball_pos)

## Pelota suelta: el más cercano va a buscarla, los demás forman.
func _assign_loose(team: Array, attack_dir: float, ball_pos: Vector3) -> void:
	var chaser = _nearest_player_to(ball_pos, _without_controlled(team))
	for i in team.size():
		var p = team[i]
		if p == _controlled:
			p.mode = p.MODE_HUMAN
			continue
		p.mode = p.MODE_AI
		p.ai_target = ball_pos if p == chaser else _formation_point(i, attack_dir, ball_pos)

## Equipo con la pelota: el dueño conduce al arco (esquivando); los demás apoyan.
func _assign_attacking(team: Array, attack_dir: float) -> void:
	var ball_pos: Vector3 = _ball.global_position
	var defenders: Array = _team1 if _holder.team == 0 else _team0
	for i in team.size():
		var p = team[i]
		if p == _controlled:
			p.mode = p.MODE_HUMAN
			continue
		p.mode = p.MODE_AI
		if p == _holder:
			p.ai_target = _dribble_target(p, attack_dir, defenders)
		else:
			p.ai_target = _support_point(i, attack_dir, ball_pos)

## Equipo sin la pelota: el más cercano al dueño lo presiona; resto forma.
func _assign_defending(team: Array, attack_dir: float, ball_pos: Vector3) -> void:
	var chaser = _nearest_player_to(_holder.global_position, _without_controlled(team))
	for i in team.size():
		var p = team[i]
		if p == _controlled:
			p.mode = p.MODE_HUMAN
			continue
		p.mode = p.MODE_AI
		p.ai_target = _holder.global_position if p == chaser else _formation_point(i, attack_dir, ball_pos)

## Objetivo del que conduce: hacia el arco, pero alejándose del rival cercano.
func _dribble_target(p, attack_dir: float, defenders: Array) -> Vector3:
	var pos: Vector3 = p.global_position
	var goal_pos := Vector3(GOAL_X * attack_dir, 0, 0)
	var to_goal: Vector3 = goal_pos - pos
	to_goal.y = 0.0
	to_goal = to_goal.normalized()

	var dir_v: Vector3 = to_goal
	var opp = _nearest_player_to(pos, defenders)
	if opp:
		var away: Vector3 = pos - opp.global_position
		away.y = 0.0
		var dd: float = away.length()
		if dd > 0.01 and dd < 3.0:
			# Cuanto más cerca el rival, más pesa la evasión.
			dir_v = (to_goal + away.normalized() * 0.9).normalized()
	return pos + dir_v * 4.0

## Posición de formación (defensiva/neutral), que se desliza con la pelota.
func _formation_point(index: int, attack_dir: float, ball_pos: Vector3) -> Vector3:
	if index == 0:
		return _goalkeeper_point(attack_dir, ball_pos)
	var base: Vector3 = FORMATION[index % FORMATION.size()]
	var pos := Vector3(base.x * attack_dir, 0, base.z)
	pos.x += ball_pos.x * 0.4
	pos.x = clampf(pos.x, -29.0, 29.0)
	pos.z = clampf(pos.z, -16.0, 16.0)
	return pos

## Posición de APOYO: los compañeros suben adelante de la pelota para acompañar.
func _support_point(index: int, attack_dir: float, ball_pos: Vector3) -> Vector3:
	if index == 0:
		return _goalkeeper_point(attack_dir, ball_pos)
	var base: Vector3 = FORMATION[index % FORMATION.size()]
	var pos := Vector3(ball_pos.x + attack_dir * 9.0 + base.x * attack_dir * 0.15, 0, 0)
	pos.z = base.z + ball_pos.z * 0.3
	pos.x = clampf(pos.x, -28.0, 28.0)
	pos.z = clampf(pos.z, -16.0, 16.0)
	return pos

## Comportamiento del arquero: se queda cerca de su arco, se mueve de palo a
## palo siguiendo la pelota, y sale un poco a achicar cuando la pelota se acerca.
func _goalkeeper_point(attack_dir: float, ball_pos: Vector3) -> Vector3:
	var line_x := -GOAL_X * attack_dir          # línea de su propio arco
	var out := 1.5                              # base: un poco adelante de la línea
	var dist_to_goal: float = absf(ball_pos.x - line_x)
	if dist_to_goal < 16.0:
		# cuanto más cerca la pelota, más sale a achicar (hasta ~4.5 m)
		out += (16.0 - dist_to_goal) / 16.0 * 3.0
	var gk_x := line_x + out * attack_dir
	var gk_z := clampf(ball_pos.z * 0.7, -GK_RANGE_Z, GK_RANGE_Z)
	return Vector3(gk_x, 0, gk_z)

# ---------------------------------------------------------------------------
# UTILIDADES
# ---------------------------------------------------------------------------

func _nearest_player_to(pos: Vector3, list: Array):
	var nearest = null
	var best := INF
	for p in list:
		var d: float = p.global_position.distance_to(pos)
		if d < best:
			best = d
			nearest = p
	return nearest

func _without_controlled(team: Array) -> Array:
	var out: Array = []
	for p in team:
		if p != _controlled:
			out.append(p)
	return out

## Cambio manual: prioriza a los jugadores que están del lado de TU arco
## respecto de la pelota (por delante del atacante, para interceptar), y
## rota entre ellos por cercanía con cada toque de J.
func _switch_to_nearest() -> void:
	var ball_pos: Vector3 = _ball.global_position

	# Separar en "por delante" (entre la pelota y tu arco) y el resto.
	var goal_side: Array = []
	var others: Array = []
	for p in _hteam_field:
		var px: float = p.global_position.x
		if (px - ball_pos.x) * _own_goal_dir > 0.0:
			goal_side.append(p)
		else:
			others.append(p)

	# Ordenar cada grupo por cercanía a la pelota y ponerlos: primero los de
	# adelante. Con toques sucesivos de J vas rotando por todos.
	goal_side.sort_custom(func(a, b): return a.global_position.distance_to(ball_pos) < b.global_position.distance_to(ball_pos))
	others.sort_custom(func(a, b): return a.global_position.distance_to(ball_pos) < b.global_position.distance_to(ball_pos))
	var candidates: Array = goal_side + others
	if candidates.is_empty():
		return

	var idx: int = candidates.find(_controlled)
	var next_p = candidates[(idx + 1) % candidates.size()] if idx != -1 else candidates[0]
	_select(next_p)

func _select(p) -> void:
	if _controlled and _controlled != p:
		_controlled.set_controlled(false)
	_controlled = p
	_controlled.set_controlled(true)

func _on_goal_scored(goal) -> void:
	var team_name: String = goal.team_name
	_score[team_name] = int(_score.get(team_name, 0)) + 1
	print("¡GOL de ", team_name, "!  Marcador: ", _score)
	_update_score_ui()
	# Saca del medio el equipo que recibió el gol.
	var scorer_id: int = 0 if team_name == "Local" else 1
	_kickoff(1 - scorer_id)

## Mientras mantenés I (tackle) y el rival tiene la pelota, tu jugador
## controlado corre solo hacia el que la lleva (y la roba al llegar).
func _handle_tackle_pursuit() -> void:
	if _controlled == null or _holder == null:
		return
	if _holder.team == _human_team or _controlled == _holder:
		return
	if Input.is_action_pressed("tackle"):
		_controlled.mode = _controlled.MODE_AI
		_controlled.ai_target = _holder.global_position

## Cancela la carga del tiro y oculta la barra.
func _cancel_charge() -> void:
	_charging = false
	_charge = 0.0
	_charge_action = ""
	if _hud:
		_hud.hide_power()

## Refresca el marcador en pantalla.
func _update_score_ui() -> void:
	if _hud:
		var local: int = int(_score.get("Local", 0))
		var visit: int = int(_score.get("Visitante", 0))
		_hud.set_score(local, visit)
