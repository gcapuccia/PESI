# Documentación — PESI (Clone PES)

Documento de diseño, registro de desarrollo (devlog) y hoja de ruta del proyecto.

---

## 1. Objetivo

Un juego de **fútbol 5 vs 5 en 3D** con la sensación arcade del **Winning Eleven de
PS1**: mover al jugador con la pelota pegada (conducción), pases y tiros directos,
robos con un botón, y una IA simple pero que juegue "como equipo". Se construye por
etapas, empezando por lo mínimo jugable y sumando de a poco.

## 2. Stack técnico

- **Motor:** Godot 4.7 (rama 4.x).
- **Render:** Forward+ (Direct3D 12 en Windows).
- **Física 3D:** Jolt Physics.
- **Lenguaje:** GDScript (tipado; el proyecto trata las advertencias de tipo
  "inferido desde Variant" como error, así que se usan tipos explícitos).

## 3. Estructura del proyecto

Todo el juego vive en `clone-pes/`.

| Archivo | Qué hace |
|---------|----------|
| `scenes/menu.tscn` + `scripts/menu.gd` | Menú principal (banner + Iniciar/Salir). Escena inicial. |
| `scenes/team_select.tscn` + `scripts/team_select.gd` | Elegir equipo (Local azul / Visitante rojo). |
| `scripts/game_config.gd` | *Autoload* singleton: guarda la elección del menú (`human_team`) y la pasa al partido. |
| `scenes/main.tscn` + `scripts/main.gd` | El partido: cancha, luces, cámara, jugadores, pelota, arcos, HUD. `main.gd` es el "cerebro" (posesión, roles, IA, marcador, saque). |
| `scenes/player.tscn` + `scripts/player.gd` | Un jugador (`CharacterBody3D`). Solo se mueve; la lógica de la pelota está en `main.gd`. Carga el modelo 3D y sus animaciones. |
| `scenes/ball.tscn` + `scripts/ball.gd` | La pelota (`RigidBody3D`). Se congela (kinematic) cuando alguien la conduce. |
| `scenes/goal.tscn` + `scripts/goal.gd` | Arco: jaula sólida con `Area3D` que detecta el gol al cruzar la línea. |
| `scenes/boundary.tscn` | Vallas que encierran la cancha. |
| `scenes/hud.tscn` + `scripts/hud.gd` | Marcador arriba y barra de potencia abajo. |
| `scripts/camera_follow.gd` | Cámara de transmisión que panea siguiendo la pelota. |
| `assets/models/` | Personajes 3D (Quaternius UAL2, CC0). |

## 4. Cómo funciona el juego (modelo)

### Posesión (estilo Winning Eleven)
- Un jugador "tiene" la pelota y la **conduce pegada** adelante suyo (no la empuja a
  los golpes). La pelota se congela y se reposiciona cada frame.
- **Tirar/pasar:** suelta la pelota con una velocidad. Pase (K) es semi-automático
  (busca un compañero en un cono de ~30° de hacia donde mira; si no hay, va recto).
  Tiro (L) va hacia donde mira. Ambos con **barra de potencia** (mantener = más fuerte).
- **Robar:** un rival cercano (dentro de un radio) roba. La IA roba con algo de
  probabilidad; el humano con la tecla **I**. Hay un tiempo de **protección** al ganar
  la pelota para que no sea un ping-pong.
- El que **pierde** la pelota **trastabilla ~0.5s** (animación de retroceso) antes de
  poder ir a recuperarla.

### Roles de la IA (cada frame, en `main.gd`)
- **Con la pelota:** el dueño conduce hacia el arco esquivando al rival; los compañeros
  suben a **posiciones de apoyo** para acompañar la jugada.
- **Sin la pelota:** el más cercano al que la lleva lo **presiona**; el resto mantiene
  la **formación**, que se desliza siguiendo la pelota. El arquero se queda cerca del arco.
- **Pelota suelta:** el más cercano de cada equipo la va a buscar.

### Colisiones
- Mundo/vallas en capa 1; pelota en capa 2 (solo choca con el mundo); jugadores en
  capa 3 (solo chocan con el mundo). Los jugadores **no chocan entre sí ni con la
  pelota**: la posesión se resuelve por cercanía, no por choque físico. (Esto evitó los
  bugs de "jugadores que salían volando" y "se trababan en las esquinas").

### Cambio de jugador
- **Manual (J):** rota entre tus jugadores de campo, priorizando a los que están del
  lado de tu arco (por delante del atacante, para interceptar). Se respeta 2s antes de
  que el auto-cambio lo pise.
- **Automático:** al ganar la pelota tu equipo, controlás al que la tiene. En defensa,
  controlás al más cercano a la pelota (con histéresis para no parpadear).

### Cancha, arcos y saque
- Cancha de 46 × 25. Arcos como **jaula sólida** en X = ±20, con detección de gol solo
  al cruzar la línea por el frente. Línea, círculo y punto centrales.
- **Saque del medio** al empezar y tras cada gol: todos vuelven a su mitad, nadie se
  mueve hasta el primer pase (que debe ir a un compañero detrás de la línea). Saca el
  equipo que recibió el gol.

## 5. Etapas completadas

1. **Mínimo jugable** — cancha, pelota con física, un jugador (mover + patear).
2. **Cámara + arcos + gol** — cámara que sigue la jugada, arcos con detección, bordes.
3. **5 vs 5** — dos equipos, IA, cambio de jugador, modelo de posesión, robos, pases
   de la IA, ajustes de dificultad/feel.
4. **HUD + potencia** — marcador en pantalla y barra de potencia para tiros y pases.
5. **Menú + selección de equipo** — pantalla de inicio y elegir de qué lado jugás.
6. **Modelos 3D** — reemplazo de las cápsulas por personajes de Quaternius (en curso).

## 6. Problemas conocidos / pendientes

- **Animaciones del modelo:** al integrar los personajes de Quaternius, a veces quedan
  en "T-pose" (sin animar). Se está depurando la detección del `AnimationPlayer` y los
  nombres de las animaciones (`player.gd` imprime `[UAL2] …` en el panel Output para
  diagnosticar).
- **Animaciones de fútbol:** el pack *Universal Animation Library 2* es genérico
  (combate, granja, etc.); **no tiene correr ni patear**. Se usa una caminata como
  placeholder. Para correr/patear reales, se planea traer animaciones de **Mixamo**.
- **Herramientas de indexado:** CodeGraph no soporta GDScript (índice vacío); se usa
  otro MCP (codebase-memory-mcp) que sí lo indexa.

## 7. Hoja de ruta (lo que viene)

Ideas ordenadas por impacto, no necesariamente en este orden:

- [ ] **Terminar los modelos 3D** — animaciones andando, orientación y escala finas.
- [ ] **Animaciones de fútbol reales** (Mixamo): idle, correr, patear, cabecear.
- [ ] **Gamepad dentro del partido** — mover con el stick, botones para pase/tiro/robar.
- [ ] **Multijugador local (2+)** — varios humanos con sus gamepads, en el mismo equipo
      (co-op) o en equipos rivales (versus), como el PES.
- [ ] **Arquero que ataja** de verdad (se tira, despeja).
- [ ] **Temporizador de partido** y pantalla de resultado final.
- [ ] **Pelota que se eleva** (pases y tiros altos).
- [ ] **Sonidos** (patada, silbato, gol, público) y **música** de menú.
- [ ] **Más equipos** y personalización (nombres, colores, camisetas).

## 8. Créditos / licencias de assets

- **Quaternius** — *Universal Animation Library 2*, licencia **CC0** (uso libre en
  proyectos personales, educativos y comerciales). https://quaternius.com/
