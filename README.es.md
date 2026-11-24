# Claudito: Claude Code como compañero de escritorio para Windows 11

Un muñequito en pixel art en tu escritorio de Windows que muestra lo que está
haciendo [Claude Code](https://claude.com/claude-code), con un sombrero o casco
distinto para cada tipo de trabajo.

*[Read in English](README.md)* · ¿Usas KDE Plasma? Los widgets de Plasma están
en [esta versión](https://github.com/coricogit/claudito/tree/ab9e865): después de clonar, ejecuta `git checkout ab9e865`.

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

Descarga **Claudito-Setup** de la
[última versión](https://github.com/coricogit/claudito/releases/latest) y
ejecútalo. No necesita Python ni permisos de administrador, conecta Claudito
con Claude Code y se quita desde *Configuración > Aplicaciones*. No está
firmado, así que Windows puede mostrar el aviso azul «Windows protegió su PC»:
*Más información > Ejecutar de todas formas*.

Desde la versión 1.1.0 se actualiza solo: cada pocas horas busca una versión
nueva en GitHub, comprueba la descarga y la instala cuando Claude Code está en
reposo. Se desactiva con *Actualizar automáticamente* en el menú de la bandeja.
La 1.0.0 todavía no lo hace: ejecuta una vez el instalador nuevo.

Hace falta que Claude Code se ejecute en este ordenador: el comando `claude` en
una terminal o una sesión **Local** en la pestaña Code de la aplicación de
escritorio de Claude. Las sesiones en la nube no ejecutan tus hooks locales,
así que Claudito no se entera de ellas.

### Si ya tenías Claudito desde el código fuente

Ejecuta el instalador: cierra la copia antigua, pasa los hooks y el inicio con
Windows a la nueva y conserva tus ajustes. Después:

- cierra las sesiones de Claude Code que estuvieran abiertas (o ejecuta
  `/hooks` en ellas) antes de borrar la carpeta antigua: pueden seguir usando
  su hook
- borra la carpeta antigua y nada más. No ejecutes su
  `install.py --uninstall`: desconectaría también la copia nueva. Si ya lo
  hiciste, vuelve a ejecutar el instalador

### Desde el código fuente

Necesitas [Python 3.9+](https://www.python.org/downloads/windows/) (marca
**Add python.exe to PATH**).

```powershell
git clone https://github.com/coricogit/claudito.git $HOME\src\claudito
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
esperando. Pasa el ratón por encima para ver qué hace Claude, cuántos tokens
ha escrito hoy y cuánto llevas usado de los límites de 5 horas y semanal de tu
plan. A partir del 80 % pone cara de agobio.

- **clic**: el panel de uso
- **clic central**: mostrar u ocultar el muñeco
- **clic derecho**: mostrar el muñeco, uso, tamaño (pequeño / mediano /
  grande), estación, siempre encima, avisos, ocultar con apps a pantalla completa,
  iniciar con Windows, salir

**Estaciones**: Claudito se viste según la estación de donde vives (por el
país de la configuración de Windows, así que acierta en los dos hemisferios).
El gorro sale cuando no lleva uno de trabajo; el traje, siempre. El icono de
la bandeja y la carita del panel de uso llevan los dos. En *Estación*,
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
esperándote y cuando termina una tarea de un minuto o más. El aviso se quita
solo a los 5 segundos. De los permisos en la aplicación de escritorio de Claude
ya avisa la propia aplicación.

**Pantalla completa**: el muñeco se oculta mientras un juego, un vídeo o una
presentación ocupa su pantalla.

Si no ves el icono, está bajo la flecha **^** de la barra de tareas.
Arrástralo a la barra o actívalo en *Configuración > Personalización > Barra
de tareas > Otros iconos de la bandeja del sistema*.

`windows\reiniciar.bat` cierra Claudito y lo vuelve a abrir.

## Panel de uso

Haz clic en el icono de la bandeja para ver:

- tu plan y tu cuenta (el correo, oculto hasta que haces clic)
- los límites del plan: ventana de 5 horas y semana, y cuándo se reinician
- tokens escritos y leídos, respuestas y sesiones de hoy, 7 y 30 días
- una gráfica de 14 días y los proyectos y modelos que más usas
- un botón para abrir tu página de uso en claude.ai

Se cierra al hacer clic fuera. Todo sale de archivos que Claude Code guarda en
tu ordenador (`~/.claude.json` y los historiales de sesión de
`~/.claude\projects`); no se envía nada de eso a ningún sitio. Los límites del plan
llegan por la línea de estado de Claude Code, que se ejecuta en la terminal
pero no en la pestaña Code de la aplicación de escritorio de Claude: aparecen
cuando una sesión de terminal los comunica.

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
| Límites del plan en la bandeja | `windows\limits.py` | `claudito-usage` |
| Estaciones | `windows\seasons.py` | `Character.qml`, `sprites.js` |
| Detección de pantalla completa | `windows\fullscreen.py` | — |
| Actualizaciones (solo la copia instalada) | `windows\updater.py` | — |
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

Si el hook falla, lo deja escrito en `%LOCALAPPDATA%\claudito\hook.log`; la
aplicación, en `claudito.log`, al lado.

Pruebas: `py -m unittest discover -s windows/tests`.

El rótulo muestra nombres de archivo, patrones de búsqueda, dominios web y la
descripción de los comandos de terminal, nunca el contenido de los archivos.

## Licencia

[MIT](LICENSE). El instalador lleva además Python y Qt, con sus propias
licencias: [THIRD-PARTY.txt](installer/licenses/THIRD-PARTY.txt). Se construye
con `py installer\build.py`.

Claudito es un proyecto no oficial; Anthropic no lo hace ni lo respalda.
