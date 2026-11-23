# Claudito: Claude Code como compañero de escritorio para Windows 11

Un muñequito en pixel art en tu escritorio de Windows que muestra lo que está
haciendo [Claude Code](https://claude.com/claude-code), con un sombrero o casco
distinto para cada tipo de trabajo.

*[Read in English](README.md)* · ¿Usas KDE Plasma? Los widgets de Plasma están
en la rama [`main`](https://github.com/coricogit/claudito/tree/main).

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

Claudito vive en una ventana transparente y sin bordes que se queda por encima
de las demás. Debajo, un rótulo dice qué está haciendo y en qué proyecto.

## Instalación

Necesitas [Python 3.9+](https://www.python.org/downloads/windows/) (marca
**Add python.exe to PATH**) y que Claude Code se ejecute en este ordenador: el
comando `claude` en una terminal o una sesión **Local** en la pestaña Code de
la aplicación de escritorio de Claude. Las sesiones en la nube no ejecutan tus
hooks locales, así que Claudito no se entera de ellas.

```powershell
git clone -b windows https://github.com/coricogit/claudito.git $HOME\src\claudito
py $HOME\src\claudito\windows\install.py
```

También puedes hacer doble clic en `windows\instalar.bat`, que hace lo mismo y
guarda el resultado en `windows\install.log`.

El instalador:

- instala PySide6 para ese Python si falta
- añade `windows\claudito_hook.py` como hook asíncrono de Claude Code y
  `windows\claudito_statusline.py` como línea de estado en
  `%USERPROFILE%\.claude\settings.json` (respeta el resto de tus ajustes y
  hooks, no toca una línea de estado que ya tengas y guarda una copia en
  `settings.json.claudito-backup`)
- hace que Claudito arranque al iniciar sesión (`--no-autostart` para evitarlo)
- lo abre (`--no-start` para no abrirlo)

Las sesiones nuevas de Claude Code cogen los hooks solas. En una sesión de
terminal que ya estaba abierta, ejecuta `/hooks` una vez; en la aplicación de
escritorio, abre una sesión nueva.

Para actualizar: `git pull` y vuelve a ejecutar `install.py` (las rutas de los
hooks quedan guardadas en `settings.json`, así que no muevas la carpeta o
reinstala si la mueves). Para quitarlo todo:
`py windows\install.py --uninstall`.

## Uso

**El muñeco** empieza en la esquina inferior derecha de tu pantalla principal.

- arrástralo a donde quieras: recuerda dónde lo dejaste, también al reiniciar
- haz clic y da un saltito
- clic derecho para el menú

**El icono de la bandeja** es un mini Claudito cuya cara sigue lo que hace
Claude: dormido, concentrado mientras trabaja, contento cuando termina y
preocupado si algo falla. Le sale un **!** naranja cuando Claude Code te está
esperando. Pasa el ratón por encima para ver qué hace Claude y cuántos tokens
ha escrito hoy.

- **clic**: el panel de uso
- **clic central**: mostrar u ocultar el muñeco
- **clic derecho**: mostrar el muñeco, uso, tamaño (pequeño / mediano /
  grande), estación, siempre encima, avisos, ocultar con apps a pantalla completa,
  iniciar con Windows, salir

**Estaciones**: Claudito se viste según la estación de donde vives (por el
país de la configuración de Windows, así que acierta en los dos hemisferios).
El gorro sale cuando no lleva uno de trabajo; el traje, siempre. El icono de
la bandeja lleva los dos. En *Estación*,
en el menú, puedes elegir otra o quitarle cualquiera de las dos prendas.

| Estación | Gorro | Traje |
|---|---|---|
| Primavera | Corona de flores | Peto de jardinero |
| Verano | Sombrero de paja | Camisa hawaiana |
| Otoño | Gorro de bellota con una hoja | Suéter tejido |
| Invierno | Gorro de lana con pompón | Bufanda |

**Varias sesiones**: primero se muestra la que te necesita, después las que
trabajan y al final las inactivas.

**Avisos**: Windows te avisa cuando Claude lleva más de 5 segundos
esperándote y cuando termina una tarea de un minuto o más.

**Pantalla completa**: el muñeco se oculta mientras un juego, un vídeo o una
presentación ocupa su pantalla.

Si no ves el icono, está bajo la flecha **^** de la barra de tareas.
Arrástralo a la barra o actívalo en *Configuración > Personalización > Barra
de tareas > Otros iconos de la bandeja del sistema*.

`windows\reiniciar.bat` cierra Claudito y lo vuelve a abrir.

## Panel de uso

Haz clic en el icono de la bandeja para ver:

- tu plan y tu cuenta (el correo, oculto hasta que haces clic)
- tokens escritos y leídos, respuestas y sesiones de hoy, 7 y 30 días
- una gráfica de 14 días y los proyectos y modelos que más usas
- un botón para abrir tu página de uso en claude.ai

Se cierra al hacer clic fuera. Todo sale de archivos que Claude Code guarda en
tu ordenador (`~/.claude.json` y los historiales de sesión de
`~/.claude\projects`); no se envía nada a ningún sitio. En Windows no se
muestran los límites del plan ni la sesión en curso: Claude Code solo los pasa
a su línea de estado, y la pestaña Code de la aplicación de escritorio de
Claude no la ejecuta. Puedes consultarlos en claude.ai.

## Cómo funciona

La versión de Windows comparte el código con la de KDE Plasma en lugar de
copiarlo:

| Pieza | Archivo de Windows | Código compartido que usa |
|---|---|---|
| Hook | `windows\claudito_hook.py` | `claudito-hook` |
| Línea de estado | `windows\claudito_statusline.py` | `claudito-statusline` |
| Datos de uso | dentro de la aplicación, en un hilo | `claudito-usage` |
| Ventana del muñeco | `windows\qml\Buddy.qml` | `plasma/.../Character.qml`, `hats.js`, `sprites.js`, `strings.js` |
| Panel de uso | `windows\qml\UsagePanel.qml` | `plasma/.../MiniClaudito.qml`, `strings.js` de uso |
| Qué mostrar y avisos | `windows\activity.py` | — |
| Estaciones | `windows\seasons.py` | `Character.qml`, `sprites.js` |
| Detección de pantalla completa | `windows\fullscreen.py` | — |
| Aplicación y bandeja | `windows\claudito.pyw` | — |

`windows\compat.py` apunta `$XDG_RUNTIME_DIR` y `$XDG_CACHE_HOME` de los
scripts a `%LOCALAPPDATA%`, así que todo queda en `%LOCALAPPDATA%\claudito`
(`state.json`, `statusline.json` y cachés). Además sustituye `fcntl` por
bloqueos de `msvcrt`, reintenta `os.replace` mientras la aplicación lee el
archivo, encuentra `claude.exe`/`claude.cmd` para `claude auth status` sin
abrir una consola y entiende rutas `C:\` al nombrar proyectos.

En Windows, Qt Quick dibuja con su renderizador por software: así la ventana
transparente funciona con cualquier tarjeta gráfica, y un sprite de 60 × 50
píxeles no cuesta nada. Con `CLAUDITO_GRAPHICS=d3d11` u `opengl` puedes probar
el renderizado por hardware.

Para abrirlo a mano: doble clic en `windows\claudito.pyw`, o
`pyw windows\claudito.pyw`. Ábrelo con `py` para ver los errores de QML en la
consola. Solo se ejecuta una copia a la vez.

Ningún hook avisa cuando respondes a un permiso, pulsas Esc o cierras la
terminal, así que `activity.py` también mira el estado que Claude Code guarda
en `~/.claude\sessions`. Esa carpeta es interna de Claude Code: si cambia,
Claudito vuelve a usar solo los hooks.

Pruebas: `py -m unittest discover -s windows/tests`.

El rótulo muestra nombres de archivo, patrones de búsqueda, dominios web y la
descripción de los comandos de terminal, nunca el contenido de los archivos.
