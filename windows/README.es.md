# Claudito para Windows 11

*[Read in English](README.md)*

El mismo muñequito en pixel art del widget de KDE Plasma, en el escritorio de
Windows: una ventana transparente y sin bordes con Claudito y su rótulo, y un
icono en la bandeja que abre el panel de uso de Claude.

No se copia nada de la versión de Plasma. La app carga
`plasma/org.corico.claudito/contents/ui/Character.qml` (con sus sombreros,
sprites y textos) y el `MiniClaudito.qml` y los textos del widget de uso
directamente del repositorio, y ejecuta los mismos scripts `claudito-hook`,
`claudito-statusline` y `claudito-usage` a través de una pequeña capa de
compatibilidad (`compat.py`). Si arreglas un sombrero, se arregla en las dos
plataformas.

## Instalación

Necesitas [Python 3.9+](https://www.python.org/downloads/windows/) y Claude Code.

```powershell
git clone https://github.com/coricogit/claudito.git $HOME\src\claudito
py $HOME\src\claudito\windows\install.py
```

El instalador:

- instala PySide6 para ese Python si falta
- añade `windows\claudito_hook.py` como hook asíncrono de Claude Code y
  `windows\claudito_statusline.py` como status line en
  `%USERPROFILE%\.claude\settings.json` (respeta el resto de tus ajustes y
  hooks, no toca una status line que ya tengas y guarda una copia en
  `settings.json.claudito-backup`)
- hace que Claudito arranque al iniciar sesión (`--no-autostart` para evitarlo)
- lo abre (`--no-start` para no abrirlo)

Las sesiones nuevas de Claude Code usan los hooks automáticamente. En una
sesión que ya estaba abierta, ejecuta `/hooks` una vez.

Para actualizar: `git pull` y vuelve a ejecutar `install.py` (las rutas de los
hooks quedan guardadas en `settings.json`, así que no muevas la carpeta o
reinstala si la mueves). Para quitarlo todo:
`py windows\install.py --uninstall`.

## Uso

**El muñeco** se queda por encima de las demás ventanas, al principio abajo a
la derecha.

- arrástralo a donde quieras: recuerda dónde lo dejaste, también tras reiniciar
- haz clic y da un saltito
- clic derecho para el menú

**El icono de la bandeja** es un mini Claudito cuya cara sigue tu ventana de 5
horas: contento, concentrado o sudando. Le sale un **!** naranja cuando Claude
Code te está esperando. Pasa el ratón por encima para ver qué hace Claude y
tus límites.

- **clic**: el panel de uso (límites del plan y cuándo se reinician, sesión
  actual, tokens de hoy / 7 / 30 días, gráfica de 14 días, proyectos y modelos
  que más usas). Se cierra al hacer clic fuera.
- **clic central**: mostrar u ocultar el muñeco
- **clic derecho**: mostrar el muñeco, uso, tamaño (pequeño / mediano /
  grande), siempre encima, iniciar con Windows, salir

Si no ves el icono, está bajo la flecha **^** de la barra de tareas.
Arrástralo a la barra o actívalo en *Configuración > Personalización > Barra
de tareas > Otros iconos de la bandeja del sistema*.

## Cómo funciona

| Pieza | Archivo de Windows | Código compartido que usa |
|---|---|---|
| Hook | `windows\claudito_hook.py` | `claudito-hook` |
| Status line | `windows\claudito_statusline.py` | `claudito-statusline` |
| Datos de uso | dentro de la app, en un hilo | `claudito-usage` |
| Ventana del muñeco | `windows\qml\Buddy.qml` | `Character.qml`, `hats.js`, `sprites.js`, `strings.js` |
| Panel de uso | `windows\qml\UsagePanel.qml` | `MiniClaudito.qml`, `strings.js` de uso |
| App y bandeja | `windows\claudito.pyw` | — |

`compat.py` apunta `$XDG_RUNTIME_DIR` y `$XDG_CACHE_HOME` de los scripts a
`%LOCALAPPDATA%`, así que todo queda en `%LOCALAPPDATA%\claudito`
(`state.json`, `statusline.json` y cachés). Además sustituye `fcntl` por
bloqueos de `msvcrt`, reintenta `os.replace` mientras la app lee el archivo,
encuentra `claude.exe`/`claude.cmd` para `claude auth status` sin abrir una
consola y entiende rutas `C:\` al nombrar proyectos. No se envía nada a
ningún sitio.

En Windows, Qt Quick dibuja con su renderizador por software: así la ventana
transparente funciona con cualquier tarjeta gráfica, y un sprite de 60 × 50
píxeles no cuesta nada. Con `CLAUDITO_GRAPHICS=d3d11` u `opengl` puedes
probar el renderizado por hardware.

Para abrirlo a mano: doble clic en `claudito.pyw`, o `pyw windows\claudito.pyw`.
Ábrelo con `py` para ver los errores de QML en la consola. Solo se ejecuta una
copia a la vez.

La app también funciona en Linux y macOS (`python3 windows/claudito.pyw`), útil
para trabajar en ella, pero ahí lo bueno son los widgets de Plasma.
