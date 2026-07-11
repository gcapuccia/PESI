extends CanvasLayer

## Interfaz en pantalla: marcador arriba y barra de potencia del tiro abajo.

@onready var _score_label = get_node_or_null("ScoreLabel")
@onready var _power_bar = get_node_or_null("PowerBar")

func _ready() -> void:
	if _power_bar:
		_power_bar.visible = false

## Actualiza el marcador.
func set_score(local: int, visitante: int) -> void:
	if _score_label:
		_score_label.text = "LOCAL   %d - %d   VISITANTE" % [local, visitante]

## Muestra la barra de potencia con un valor 0..1.
func set_power(value: float) -> void:
	if _power_bar:
		_power_bar.visible = true
		_power_bar.value = value

## Oculta la barra de potencia.
func hide_power() -> void:
	if _power_bar:
		_power_bar.visible = false
