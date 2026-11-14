"""Claudito for Windows: the desktop buddy in a transparent window and the
Claude usage panel behind a tray icon.

    pythonw claudito.pyw        (or double-click this file)

The buddy is the same Character.qml as the KDE Plasma widget, loaded straight
from ../plasma. Claude Code drives it through windows/claudito_hook.py, which
writes %LOCALAPPDATA%\\claudito\\state.json; this app polls that file.
"""
import json
import os
import sys
import threading
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import compat  # noqa: E402

compat.setup_env()

from PySide6.QtCore import (QLocale, QLockFile, QObject, QPoint, QSettings,  # noqa: E402
                            Qt, QTimer, QUrl, Property, Signal, Slot)
from PySide6.QtGui import QAction, QActionGroup, QColor, QCursor, QGuiApplication, QIcon, QPainter, QPixmap  # noqa: E402
from PySide6.QtQml import QQmlApplicationEngine  # noqa: E402
from PySide6.QtQuick import QQuickWindow, QSGRendererInterface  # noqa: E402
from PySide6.QtQuickControls2 import QQuickStyle  # noqa: E402
from PySide6.QtWidgets import QApplication, QMenu, QSystemTrayIcon  # noqa: E402

import install  # noqa: E402  (autostart helpers)

QML_DIR = os.path.join(HERE, "qml")
SIZES = {"small": 2, "medium": 3, "large": 4}   # pixels per Claudito pixel

TEXT = {
    "en": {
        "show": "Show Claudito",
        "usage": "Claude usage…",
        "size": "Size",
        "small": "Small", "medium": "Medium", "large": "Large",
        "onTop": "Always on top",
        "autostart": "Start with Windows",
        "quit": "Quit",
        "tip5h": "5 h: {five} · week: {week}",
        "already": "Claudito is already running (look in the tray).",
    },
    "es": {
        "show": "Mostrar a Claudito",
        "usage": "Uso de Claude…",
        "size": "Tamaño",
        "small": "Pequeño", "medium": "Mediano", "large": "Grande",
        "onTop": "Siempre encima",
        "autostart": "Iniciar con Windows",
        "quit": "Salir",
        "tip5h": "5 h: {five} · semana: {week}",
        "already": "Claudito ya está abierto (búscalo en la bandeja).",
    },
}
LANG = "es" if QLocale.system().name().startswith("es") else "en"


def tr(key):
    return TEXT[LANG].get(key) or TEXT["en"][key]


# ---------------------------------------------------------------------------
# Backend shared with QML as `backend`
# ---------------------------------------------------------------------------

class Backend(QObject):
    stateChanged = Signal()
    usageChanged = Signal()
    settingsChanged = Signal()
    activityChanged = Signal()
    _usageReady = Signal(str)

    def __init__(self, settings):
        super().__init__()
        self.settings = settings
        self._state = ""
        self._usage = ""
        self._usage_data = {}
        self._activity = ""
        self._mode = "sleep"
        self._worker = None
        self._fast = False

        self._usageReady.connect(self._set_usage)

        self._state_timer = QTimer(self, interval=500, timeout=self._poll_state)
        self._state_timer.start()
        self._poll_state()

        self._usage_timer = QTimer(self, interval=30000, timeout=self.refreshUsage)
        self._usage_timer.start()
        QTimer.singleShot(0, self.refreshUsage)

    # ----- state.json (written by the hook) -----
    def _poll_state(self):
        try:
            with open(compat.state_file(), encoding="utf-8") as f:
                text = f.read()
        except OSError:
            text = ""
        if text != self._state:
            self._state = text
            self.stateChanged.emit()

    def _get_state(self):
        return self._state

    stateText = Property(str, _get_state, notify=stateChanged)

    # ----- usage (claudito-usage, run in a thread) -----
    @Slot()
    def refreshUsage(self):
        if self._worker and self._worker.is_alive():
            return
        self._worker = threading.Thread(target=self._compute_usage, daemon=True)
        self._worker.start()

    def _compute_usage(self):
        try:
            mod = compat.load_usage()
            out = {"generated": time.time(), "account": mod.account(), "live": mod.live()}
            out.update(mod.totals(mod.transcripts()))
            self._usageReady.emit(json.dumps(out))
        except Exception as e:  # keep the last good data
            print("claudito: usage failed:", e, file=sys.stderr)

    def _set_usage(self, text):
        self._usage = text
        try:
            self._usage_data = json.loads(text)
        except ValueError:
            self._usage_data = {}
        self.usageChanged.emit()

    def _get_usage(self):
        return self._usage

    usageText = Property(str, _get_usage, notify=usageChanged)

    def set_fast_refresh(self, fast):
        """Refresh every 5 s while the panel is open, every 30 s otherwise."""
        self._fast = fast
        self._usage_timer.setInterval(5000 if fast else 30000)
        if fast:
            self.refreshUsage()

    def limit_percent(self, key):
        live = self._usage_data.get("live") or {}
        lim = (live.get("limits") or {}).get(key) or {}
        pct = lim.get("percent")
        return pct if isinstance(pct, (int, float)) else -1

    # ----- what the buddy is doing (set from QML, used by the tray) -----
    def _get_activity(self):
        return self._activity

    def _set_activity(self, v):
        if v != self._activity:
            self._activity = v
            self.activityChanged.emit()

    activity = Property(str, _get_activity, _set_activity, notify=activityChanged)

    def _get_mode(self):
        return self._mode

    def _set_mode(self, v):
        if v != self._mode:
            self._mode = v
            self.activityChanged.emit()

    mode = Property(str, _get_mode, _set_mode, notify=activityChanged)

    # ----- settings -----
    def _get_pixel(self):
        return SIZES.get(self.settings.value("size", "medium"), 3)

    pixelSize = Property(int, _get_pixel, notify=settingsChanged)

    def _get_on_top(self):
        return self.settings.value("onTop", True, type=bool)

    onTop = Property(bool, _get_on_top, notify=settingsChanged)

    # ----- called from QML -----
    menuRequested = Signal()

    @Slot()
    def showMenu(self):
        self.menuRequested.emit()


# ---------------------------------------------------------------------------
# Tray icon: the panel's MiniClaudito, painted with QPainter
# ---------------------------------------------------------------------------

def tray_pixmap(mood, waiting=False, size=32):
    pm = QPixmap(size, size)
    pm.fill(Qt.GlobalColor.transparent)
    qp = QPainter(pm)
    p = size // 16
    ox = (size - 16 * p) // 2
    oy = (size - 14 * p) // 2 + p // 2

    def px(x, y, w, h, c):
        qp.fillRect(ox + x * p, oy + y * p, w * p, h * p, QColor(c))

    front, side, top, ink = "#EE7E55", "#C2582F", "#F7A07B", "#1A1A1A"
    px(1, 2, 1, 9, side)
    px(2, 1, 13, 10, front)
    px(3, 0, 11, 1, top)
    px(2, 1, 1, 1, top)
    for x in (3, 6, 9, 12):
        px(x, 11, 1, 2, side)
    for i, x in enumerate((4, 10)):
        if mood == "sleep":
            px(x, 5, 3, 1, ink)
        elif mood == "happy":
            px(x + 1, 4, 1, 1, ink); px(x, 5, 1, 1, ink); px(x + 2, 5, 1, 1, ink)
        elif mood == "worried":
            if i == 0:
                px(x, 4, 1, 1, ink); px(x + 1, 5, 1, 1, ink); px(x, 6, 1, 1, ink)
            else:
                px(x + 2, 4, 1, 1, ink); px(x + 1, 5, 1, 1, ink); px(x + 2, 6, 1, 1, ink)
        else:
            px(x + 1, 4, 2, 2, ink)
    if mood == "worried":
        px(14, 1, 1, 1, "#74C0FC"); px(14, 2, 1, 2, "#1C7ED6")
    if mood == "happy":
        px(3, 7, 2, 1, "#F28B82"); px(12, 7, 2, 1, "#F28B82")
    if waiting:   # Claude Code is waiting for you: a little "!" badge
        qp.fillRect(size - 3 * p - 1, 0, 3 * p + 1, 8 * p, QColor("#E67700"))
        qp.fillRect(size - 2 * p - 1, p, p + 1, 4 * p, QColor("#FFF3BF"))
        qp.fillRect(size - 2 * p - 1, 6 * p, p + 1, p, QColor("#FFF3BF"))
    qp.end()
    return pm


# ---------------------------------------------------------------------------
# App
# ---------------------------------------------------------------------------

class Claudito(QObject):
    def __init__(self, app):
        super().__init__()
        self.app = app
        self.settings = QSettings("corico", "Claudito")
        self.backend = Backend(self.settings)

        self.engine = QQmlApplicationEngine()
        self.engine.rootContext().setContextProperty("backend", self.backend)
        self.buddy = self._load("Buddy.qml")
        self.panel = self._load("UsagePanel.qml")

        self._panel_hidden_at = 0.0
        self.panel.visibleChanged.connect(self._on_panel_visible)

        # Buddy position: restore, keep on a visible screen, save when moved.
        self._save_pos = QTimer(self, singleShot=True, interval=400, timeout=self._store_position)
        self._place_buddy()
        self.buddy.xChanged.connect(lambda _: self._save_pos.start())
        self.buddy.yChanged.connect(lambda _: self._save_pos.start())
        self.buddy.setVisible(self.settings.value("visible", True, type=bool))

        self._build_tray()
        self.backend.menuRequested.connect(lambda: self.menu.popup(QCursor.pos()))
        self.backend.usageChanged.connect(self._update_tray)
        self.backend.activityChanged.connect(self._update_tray)
        self._update_tray()

    def _load(self, name):
        self.engine.load(QUrl.fromLocalFile(os.path.join(QML_DIR, name)))
        roots = self.engine.rootObjects()
        if not roots:
            sys.exit(f"claudito: could not load {name}")
        return roots[-1]

    # ----- buddy window -----
    def _place_buddy(self):
        w, h = self.buddy.width(), self.buddy.height()
        if self.settings.contains("x") and self.settings.contains("y"):
            x = self.settings.value("x", 0, type=int)
            y = self.settings.value("y", 0, type=int)
            if QGuiApplication.screenAt(QPoint(x + w // 2, y + h // 2)):
                self.buddy.setPosition(x, y)
                return
        area = QGuiApplication.primaryScreen().availableGeometry()
        self.buddy.setPosition(area.right() - w - 24, area.bottom() - h - 24)

    def _store_position(self):
        self.settings.setValue("x", self.buddy.x())
        self.settings.setValue("y", self.buddy.y())

    def set_buddy_visible(self, on):
        self.buddy.setVisible(on)
        self.settings.setValue("visible", on)
        self.show_action.setChecked(on)

    def set_size(self, key):
        self.settings.setValue("size", key)
        self.backend.settingsChanged.emit()

    def set_on_top(self, on):
        self.settings.setValue("onTop", on)
        self.backend.settingsChanged.emit()

    # ----- usage panel -----
    def _on_panel_visible(self, visible):
        self.backend.set_fast_refresh(visible)
        if not visible:
            self._panel_hidden_at = time.monotonic()

    def toggle_panel(self):
        if self.panel.isVisible():
            self.panel.hide()
            return
        # Clicking the tray icon closes the panel (it loses focus) right
        # before this runs: don't reopen it.
        if time.monotonic() - self._panel_hidden_at < 0.3:
            return
        self._place_panel()
        self.panel.show()
        self.panel.raise_()
        self.panel.requestActivate()

    def _place_panel(self):
        w, h = self.panel.width(), self.panel.height()
        icon = self.tray.geometry()
        anchor = icon.center() if not icon.isEmpty() else QCursor.pos()
        screen = QGuiApplication.screenAt(anchor) or QGuiApplication.primaryScreen()
        area = screen.availableGeometry()
        margin = 8
        x = min(max(anchor.x() - w // 2, area.left() + margin), area.right() - w - margin)
        # Taskbar at the bottom (the usual) or at the top.
        y = area.bottom() - h - margin if anchor.y() >= area.center().y() else area.top() + margin
        if anchor.x() < area.left() or anchor.x() > area.right():   # taskbar at a side
            x = area.left() + margin if anchor.x() < area.left() else area.right() - w - margin
            y = min(max(anchor.y() - h // 2, area.top() + margin), area.bottom() - h - margin)
        self.panel.setPosition(x, y)

    # ----- tray -----
    def _build_tray(self):
        self.tray = QSystemTrayIcon(self)
        menu = self.menu = QMenu()

        self.show_action = QAction(tr("show"), menu, checkable=True)
        self.show_action.setChecked(self.buddy.isVisible())
        self.show_action.toggled.connect(self.set_buddy_visible)
        menu.addAction(self.show_action)

        usage = QAction(tr("usage"), menu)
        usage.triggered.connect(lambda: (self._place_panel(), self.panel.show(), self.panel.requestActivate()))
        menu.addAction(usage)
        menu.addSeparator()

        size_menu = menu.addMenu(tr("size"))
        group = QActionGroup(size_menu)
        current = self.settings.value("size", "medium")
        for key in SIZES:
            a = QAction(tr(key), size_menu, checkable=True)
            a.setChecked(key == current)
            a.triggered.connect(lambda _=False, k=key: self.set_size(k))
            group.addAction(a)
            size_menu.addAction(a)

        on_top = QAction(tr("onTop"), menu, checkable=True)
        on_top.setChecked(self.backend.onTop)
        on_top.toggled.connect(self.set_on_top)
        menu.addAction(on_top)

        if compat.IS_WINDOWS:
            auto = QAction(tr("autostart"), menu, checkable=True)
            auto.setChecked(install.autostart_enabled())
            auto.toggled.connect(lambda on: install.set_autostart(on))
            menu.addAction(auto)

        menu.addSeparator()
        quit_action = QAction(tr("quit"), menu)
        quit_action.triggered.connect(self.app.quit)
        menu.addAction(quit_action)

        self.tray.setContextMenu(menu)
        self.tray.activated.connect(self._on_tray)
        self.tray.show()

    def _on_tray(self, reason):
        if reason == QSystemTrayIcon.ActivationReason.Trigger:
            self.toggle_panel()
        elif reason == QSystemTrayIcon.ActivationReason.MiddleClick:
            self.set_buddy_visible(not self.buddy.isVisible())

    def _update_tray(self):
        five = self.backend.limit_percent("five_hour")
        week = self.backend.limit_percent("seven_day")
        mood = "sleep" if five < 0 else "worried" if five >= 80 else "focus" if five >= 50 else "happy"
        self.tray.setIcon(QIcon(tray_pixmap(mood, waiting=self.backend.mode == "waiting")))

        def pct(v):
            return "?" if v < 0 else f"{round(v)} %"

        lines = ["Claudito: " + self.backend.activity if self.backend.activity else "Claudito",
                 tr("tip5h").format(five=pct(five), week=pct(week))]
        self.tray.setToolTip("\n".join(lines))


def main():
    # Pixel art wants whole pixels; the software renderer also keeps the
    # transparent window reliable on every GPU. CLAUDITO_GRAPHICS=d3d11 or
    # opengl switches back to hardware rendering.
    graphics = os.environ.get("CLAUDITO_GRAPHICS", "software" if compat.IS_WINDOWS else "").lower()
    api = {"software": QSGRendererInterface.GraphicsApi.Software,
           "opengl": QSGRendererInterface.GraphicsApi.OpenGL,
           "d3d11": QSGRendererInterface.GraphicsApi.Direct3D11}.get(graphics)
    if api is not None:
        QQuickWindow.setGraphicsApi(api)
    QQuickWindow.setDefaultAlphaBuffer(True)
    QQuickStyle.setStyle("Fusion")

    app = QApplication(sys.argv)
    app.setApplicationName("Claudito")
    app.setOrganizationName("corico")
    app.setQuitOnLastWindowClosed(False)

    os.makedirs(compat.data_dir(), exist_ok=True)
    lock = QLockFile(os.path.join(compat.data_dir(), "app.lock"))
    if not lock.tryLock(100):
        print(tr("already"), file=sys.stderr)
        return 0

    if not QSystemTrayIcon.isSystemTrayAvailable():
        print("claudito: no system tray found", file=sys.stderr)

    claudito = Claudito(app)  # noqa: F841  (keeps everything alive)
    return app.exec()


if __name__ == "__main__":
    sys.exit(main())
