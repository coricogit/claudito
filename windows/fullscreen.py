"""Tells whether a full-screen window (a game, a video, a presentation) covers
the screen Claudito is on. Windows only; elsewhere it always says no."""
import os

WS_CAPTION = 0x00C00000
MONITOR_DEFAULTTONEAREST = 2
# Full-screen windows of Windows itself: desktop, Start, Alt+Tab, lock screen...
SHELL_CLASSES = {"Progman", "WorkerW", "Shell_TrayWnd", "Shell_SecondaryTrayWnd",
                 "XamlExplorerHostIslandWindow", "MultitaskingViewFrame", "ForegroundStaging",
                 "Windows.UI.Core.CoreWindow", "LockScreenBackstopFrame"}


def covers(rect, monitor):
    """Both are (left, top, right, bottom)."""
    return (rect[0] <= monitor[0] and rect[1] <= monitor[1]
            and rect[2] >= monitor[2] and rect[3] >= monitor[3])


class Detector:
    def __init__(self, api=None):
        self._last = None   # the last full-screen window seen on Claudito's screen
        self._api = api or (_Api() if os.name == "nt" else None)

    def covered(self, buddy):
        """Is there a full-screen window on the screen of the window `buddy`?"""
        api = self._api
        if not api:
            return False
        screen = api.monitor(buddy)
        front = api.foreground()
        if front and api.monitor(front) == screen:
            self._last = front if self._is_fullscreen(front) else None
        elif self._last and not (api.monitor(self._last) == screen and self._is_fullscreen(self._last)):
            # You are using another screen; the game on this one was closed,
            # minimized or moved meanwhile.
            self._last = None
        return self._last is not None

    def _is_fullscreen(self, hwnd):
        api = self._api
        if not api.shown(hwnd) or api.own(hwnd) or api.class_name(hwnd) in SHELL_CLASSES:
            return False
        if api.style(hwnd) & WS_CAPTION == WS_CAPTION:   # only maximized
            return False
        return covers(api.rect(hwnd), api.monitor_rect(api.monitor(hwnd)))


class _Api:
    """The few user32 calls needed."""

    def __init__(self):
        import ctypes
        from ctypes import wintypes as w

        class MONITORINFO(ctypes.Structure):
            _fields_ = [("cbSize", w.DWORD), ("rcMonitor", w.RECT), ("rcWork", w.RECT), ("dwFlags", w.DWORD)]

        self.c, self.w, self.MONITORINFO = ctypes, w, MONITORINFO
        u = self.u = ctypes.WinDLL("user32")
        for name, res, args in (
                ("GetForegroundWindow", w.HWND, ()),
                ("GetWindowRect", w.BOOL, (w.HWND, ctypes.POINTER(w.RECT))),
                ("MonitorFromWindow", w.HANDLE, (w.HWND, w.DWORD)),
                ("GetMonitorInfoW", w.BOOL, (w.HANDLE, ctypes.POINTER(MONITORINFO))),
                ("GetClassNameW", ctypes.c_int, (w.HWND, w.LPWSTR, ctypes.c_int)),
                ("GetWindowLongW", w.LONG, (w.HWND, ctypes.c_int)),
                ("IsWindowVisible", w.BOOL, (w.HWND,)),
                ("IsIconic", w.BOOL, (w.HWND,)),
                ("GetWindowThreadProcessId", w.DWORD, (w.HWND, ctypes.POINTER(w.DWORD)))):
            f = getattr(u, name)
            f.restype, f.argtypes = res, args

    def foreground(self):
        return self.u.GetForegroundWindow()

    def monitor(self, hwnd):
        return self.u.MonitorFromWindow(hwnd, MONITOR_DEFAULTTONEAREST)

    def monitor_rect(self, monitor):
        info = self.MONITORINFO(cbSize=self.c.sizeof(self.MONITORINFO))
        if not self.u.GetMonitorInfoW(monitor, self.c.byref(info)):
            return (-10**9, -10**9, 10**9, 10**9)   # nothing covers it
        r = info.rcMonitor
        return (r.left, r.top, r.right, r.bottom)

    def rect(self, hwnd):
        r = self.w.RECT()
        self.u.GetWindowRect(hwnd, self.c.byref(r))
        return (r.left, r.top, r.right, r.bottom)

    def class_name(self, hwnd):
        buf = self.c.create_unicode_buffer(128)
        self.u.GetClassNameW(hwnd, buf, 128)
        return buf.value

    def style(self, hwnd):
        return self.u.GetWindowLongW(hwnd, -16) & 0xFFFFFFFF   # GWL_STYLE

    def shown(self, hwnd):
        return bool(self.u.IsWindowVisible(hwnd)) and not self.u.IsIconic(hwnd)

    def own(self, hwnd):
        pid = self.w.DWORD()
        self.u.GetWindowThreadProcessId(hwnd, self.c.byref(pid))
        return pid.value == os.getpid()
