extends Node3D

## Genera el "público": una multitud de figuritas de colores sobre las gradas.
## Usa un MultiMesh (miles de instancias en una sola llamada de dibujo).

const SPACING := 1.2                     ## separación entre espectadores
const BODY := Vector3(0.35, 0.8, 0.35)   ## tamaño de cada persona

func _ready() -> void:
	_build_crowd()

func _build_crowd() -> void:
	var positions: Array[Vector3] = []

	# Tribunas largas (Norte/Sur): filas a lo largo de X.
	var long_tiers: Array[Vector3] = [
		Vector3(0, 1, 20), Vector3(0, 2.6, 25), Vector3(0, 4.2, 30),
		Vector3(0, 1, -20), Vector3(0, 2.6, -25), Vector3(0, 4.2, -30),
	]
	for t in long_tiers:
		var top_y: float = t.y + 1.0 + BODY.y * 0.5
		var x: float = -32.0
		while x <= 32.0:
			positions.append(Vector3(x, top_y, t.z - 1.0))
			positions.append(Vector3(x, top_y, t.z + 1.0))
			x += SPACING

	# Tribunas laterales (Este/Oeste): filas a lo largo de Z.
	var side_tiers: Array[Vector3] = [
		Vector3(33, 1, 0), Vector3(38, 2.6, 0), Vector3(43, 4.2, 0),
		Vector3(-33, 1, 0), Vector3(-38, 2.6, 0), Vector3(-43, 4.2, 0),
	]
	for t in side_tiers:
		var top_y: float = t.y + 1.0 + BODY.y * 0.5
		var z: float = -19.0
		while z <= 19.0:
			positions.append(Vector3(t.x - 1.0, top_y, z))
			positions.append(Vector3(t.x + 1.0, top_y, z))
			z += SPACING

	# Mesh de un espectador (caja simple) con material que usa el color por instancia.
	var body := BoxMesh.new()
	body.size = BODY
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	body.material = mat

	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = body
	mm.instance_count = positions.size()

	for i in positions.size():
		var p: Vector3 = positions[i]
		# Pequeño desorden para que no queden en fila perfecta.
		p.x += randf_range(-0.25, 0.25)
		p.z += randf_range(-0.25, 0.25)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))
		mm.set_instance_color(i, _shirt_color())

	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)

## Color de camiseta al azar (paleta variada, tipo hinchada).
func _shirt_color() -> Color:
	var palette: Array[Color] = [
		Color(0.80, 0.20, 0.20), Color(0.20, 0.40, 0.80), Color(0.92, 0.92, 0.92),
		Color(0.90, 0.80, 0.20), Color(0.20, 0.70, 0.35), Color(0.60, 0.30, 0.70),
		Color(0.90, 0.50, 0.20), Color(0.30, 0.30, 0.35),
	]
	return palette[randi() % palette.size()]
