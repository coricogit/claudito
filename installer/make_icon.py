"""make_icon.py <out.ico>: Claudito's tray icon as a Windows icon."""
import importlib.machinery
import importlib.util
import os
import struct
import sys

WINDOWS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "windows")
sys.path.insert(0, WINDOWS)
loader = importlib.machinery.SourceFileLoader("claudito_app", os.path.join(WINDOWS, "claudito.pyw"))
app_module = importlib.util.module_from_spec(importlib.util.spec_from_loader("claudito_app", loader))
loader.exec_module(app_module)

from PySide6.QtCore import QBuffer, QIODevice  # noqa: E402
from PySide6.QtGui import QGuiApplication  # noqa: E402

app = QGuiApplication([])
images = []
for size in (16, 32, 48, 64, 128, 256):
    buffer = QBuffer()
    buffer.open(QIODevice.OpenModeFlag.WriteOnly)
    app_module.tray_pixmap("happy", size=size).save(buffer, "PNG")
    images.append((size, bytes(buffer.data())))

offset = 6 + 16 * len(images)
head = struct.pack("<HHH", 0, 1, len(images))
for size, data in images:
    head += struct.pack("<BBBBHHII", size % 256, size % 256, 0, 0, 1, 32, len(data), offset)
    offset += len(data)
with open(sys.argv[1], "wb") as f:
    f.write(head + b"".join(data for _, data in images))
