# Claudito: Claude Code como compañero de escritorio para KDE Plasma 6

Un muñequito en pixel art en tu escritorio de KDE Plasma que muestra lo que está
haciendo [Claude Code](https://claude.com/claude-code), con un sombrero o casco
distinto para cada tipo de trabajo.

*[Read in English](README.md)*

| Claude Code está… | Sombrero | Animación |
|---|---|---|
| Pensando tu mensaje | Gorrito con hélice | La hélice gira, mira hacia arriba, «…» |
| Editando o escribiendo archivos | Casco de obra | Martillea con chispas |
| Ejecutando comandos en la terminal | Casco de minero | Teclea en el portátil, linterna encendida |
| Leyendo o buscando código | Gorro de detective | Mueve la lupa |
| Buscando en internet | Salacot de explorador | Camina en el sitio |
| Lanzando subagentes | Gorra de capitán | Levanta una banderita |
| Planificando o con tareas | Sombrero de mago | Destellos |
| Creando artifacts, skills o usando MCP | Boina | Pinta |
| Esperando tu permiso o tu respuesta | (mantiene el que llevaba) | Saluda, con un «!» |
| Una herramienta falló | — | Gota de sudor, ojos `> <` |
| Terminó | Gorro de fiesta | Salta entre confeti |
| 10 minutos sin actividad | Gorro de dormir | Zzz |

Cuando está tranquilo se toma un café. Si le haces clic, da un saltito. Debajo,
un rótulo dice qué está haciendo y en qué proyecto.

## Widget de uso para el panel

**Claudito Usage** va en la barra de tareas: un mini Claudito y cuánto llevas
gastado de la ventana de 5 horas. Su cara cambia según te acercas al límite:
contento, concentrado o sudando. Al hacer clic muestra:

- tu plan y tu cuenta (el email queda oculto hasta que haces clic) y hasta
  cuándo dura la sesión iniciada
- los límites del plan: ventana de 5 horas y semanal, con cuándo se reinicia cada una
- la sesión actual de Claude Code: nombre, modelo, proyecto, contexto usado,
  tiempo, líneas cambiadas y coste equivalente en API (no te lo cobran con el plan)
- tokens escritos y leídos, respuestas y sesiones de hoy, 7 y 30 días
- una gráfica de los últimos 14 días y los proyectos y modelos que más usas

Los límites del plan y la sesión en vivo salen de la *status line* de Claude
Code, así que se actualizan mientras Claude Code está abierto. El instalador
configura `claudito-statusline` como status line, salvo que ya tengas otra. El
historial sale de tus transcripciones locales en `~/.claude/projects` y la
cuenta, de `claude auth status`. No se envía nada a ningún sitio.

## Cómo funciona

`claudito-hook` se ejecuta como [hook de Claude Code](https://docs.claude.com/en/docs/claude-code/hooks)
asíncrono en los eventos de sesión, mensaje, herramientas, notificaciones y fin.
Guarda la actividad de cada sesión en `$XDG_RUNTIME_DIR/claudito/state.json`
(una carpeta en RAM que solo puede leer tu usuario) y el widget lee ese archivo.
Si tienes varias sesiones abiertas, sigue la más reciente.

El rótulo muestra nombres de archivo, patrones de búsqueda, dominios web y la
descripción de los comandos de terminal, nunca el contenido de los archivos.

## Instalación

Necesitas KDE Plasma 6, Python 3 y `jq`.

```bash
git clone https://github.com/coricogit/claudito.git ~/src/claudito
~/src/claudito/install.sh
```

El instalador enlaza `claudito-hook`, `claudito-statusline` y `claudito-usage`
en `~/.local/bin`, añade los hooks y la status line a `~/.claude/settings.json`
(respeta el resto de tus ajustes y hooks, no toca una status line que ya
tengas y guarda una copia en `settings.json.claudito-backup`) e instala los dos
widgets. Después, clic derecho > *Añadir widgets*: **Claudito** en el
escritorio (también cabe en un panel) y **Claudito Usage** en la barra de tareas.

Las sesiones nuevas de Claude Code usan los hooks automáticamente. En una sesión
que ya estaba abierta, ejecuta `/hooks` una vez.

Para actualizar: `git pull && ./install.sh`. Para quitarlo todo:
`./install.sh --uninstall`.
