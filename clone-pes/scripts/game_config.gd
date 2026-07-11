extends Node

## Configuración elegida en el menú, que el partido (main.gd) lee al cargar.
## Es un "autoload" (singleton global): siempre existe y conserva estos
## valores al cambiar de escena.

## Equipo que controla el humano: 0 = Local (azul), 1 = Visitante (rojo).
var human_team: int = 0

## Cantidad de jugadores humanos (para el multijugador futuro).
var num_humans: int = 1
