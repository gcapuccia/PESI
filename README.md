# PESI — Clone PES ⚽

Prototipo de un juego de **fútbol 5 vs 5 en 3D** hecho con **Godot 4.7**, inspirado
en la jugabilidad del viejo **Winning Eleven / Pro Evolution Soccer** de PS1
(arcade, directo, divertido).

> Proyecto en desarrollo — se va construyendo por etapas. Ver
> [DOCUMENTATION.md](DOCUMENTATION.md) para el detalle de diseño, lo hecho y lo que viene.

---

## Cómo correrlo

1. Instalá **Godot 4.7** (o superior de la rama 4.x).
2. Abrí el proyecto: en Godot, *Import* → elegí `clone-pes/project.godot`.
3. Apretá **F5** (Play). Arranca en el menú principal.

## Controles (teclado)

| Tecla | Acción |
|-------|--------|
| **W A S D** | Mover al jugador |
| **K** (mantener) | Pase (semi-automático, carga potencia) |
| **L** (mantener) | Tiro al arco (carga potencia) |
| **J** | Cambiar de jugador |
| **I** (mantener) | Robar / perseguir al rival |

Los menús se navegan con teclado o **gamepad**. *(El control con gamepad dentro del
partido está en la hoja de ruta.)*

## Estructura

```
PESI/
├── README.md
├── DOCUMENTATION.md          # diseño, devlog y roadmap
└── clone-pes/                # proyecto Godot
    ├── project.godot
    ├── scenes/               # menu, selección, partido, jugador, pelota, arco, HUD…
    ├── scripts/              # main.gd (lógica del partido), player.gd, etc.
    └── assets/models/        # personajes 3D (Quaternius, CC0)
```

## Características actuales

- Partido 5v5 con IA (persecución, formación, apoyo a la jugada, pases del rival).
- Modelo de **posesión** estilo WE: conducción, pases y tiros con **barra de potencia**.
- Cambio de jugador inteligente + persecución automática.
- Arcos con detección de gol, **saque del medio**, marcador en pantalla.
- Menú principal y **selección de equipo** (jugás como Local o Visitante).
- Personajes 3D animados (en integración).

## Créditos

- Personajes / animaciones: **[Quaternius](https://quaternius.com/)** — *Universal
  Animation Library 2* (licencia **CC0**, uso libre).

---

Hecho con la asistencia de Claude Code.
