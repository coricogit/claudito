"""Builds Claudito's installer on Windows.

    py installer\\build.py      ->  installer\\dist\\Claudito-Setup-<version>.exe

Needs any Python 3.9+ with pip, and an internet connection the first time.
Nothing is installed on this computer: Python, Qt and Inno Setup are downloaded
to installer\\build (checked against the hashes below) and used from there.

To publish it, so that the installed copies update themselves to it, the tag
has to be v<version> and the file has to keep its name:

    gh release create v<version> installer\\dist\\Claudito-Setup-<version>.exe

The installer carries the official embeddable Python and only the parts of Qt
that Claudito uses, next to Claudito's own files as they are in the repository.
"""
import hashlib
import os
import shutil
import subprocess
import sys
import urllib.request
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
BUILD = os.path.join(HERE, "build")
STAGE = os.path.join(BUILD, "stage")
DIST = os.path.join(HERE, "dist")

PYTHON = ("https://www.python.org/ftp/python/3.12.10/python-3.12.10-embed-amd64.zip",
          "4acbed6dd1c744b0376e3b1cf57ce906f9dc9e95e68824584c8099a63025a3c3")
INNO = ("https://api.nuget.org/v3-flatcontainer/tools.innosetup/6.7.3/tools.innosetup.6.7.3.nupkg",
        "f780898e402ff80612cc8d9fcb8c6e02932bd1cb4c900ffdaa31f9341cfb49f4")
WHEELS = (("PySide6_Essentials==6.12.0", "c9a95102aa23c1f86516a30d5a9be37552d324eee7e567eb7508973f1218cb42"),
          ("shiboken6==6.12.0", "a1906cb8116869178c64b6bab52623bbc8b4ceed7b30bfc3c9aa0f6e67f6438e"))

# What of the repository goes in (from git, so nothing else slips in).
SOURCES = ("LICENSE", "README.md", "README.es.md", "claudito-hook", "claudito-statusline", "claudito-usage",
           "plasma", "windows")
LEFT_OUT = ("windows/tests/", "windows/instalar.bat", "windows/reiniciar.bat", "windows/.gitignore")

# What of PySide6 goes in.
QT_MODULES = ("Core", "Gui", "Network", "OpenGL", "Qml", "Quick", "QuickControls2", "Widgets")
QT_DLLS = ("Core", "Gui", "Network", "OpenGL", "Qml", "QmlMeta", "QmlModels", "QmlWorkerScript", "Quick",
           "QuickControls2", "QuickControls2Basic", "QuickControls2BasicStyleImpl", "QuickControls2Fusion",
           "QuickControls2FusionStyleImpl", "QuickControls2Impl", "QuickLayouts", "QuickTemplates2", "Widgets")
QT_PLUGINS = ("platforms/qwindows.dll", "styles/qmodernwindowsstyle.dll")
QT_QML = ("QtQml", "QtQuick/Window", "QtQuick/Layouts", "QtQuick/Templates", "QtQuick/Controls/impl",
          "QtQuick/Controls/Basic", "QtQuick/Controls/Fusion")
QT_QML_FLAT = ("", "QtQuick", "QtQuick/Controls")   # only the files right in them


def say(text):
    print("==>", text, flush=True)


def fetch(url, sha256):
    os.makedirs(BUILD, exist_ok=True)
    path = os.path.join(BUILD, url.rsplit("/", 1)[1])
    if not os.path.exists(path):
        say("Downloading " + url)
        with urllib.request.urlopen(url, timeout=120) as r, open(path + ".part", "wb") as f:
            shutil.copyfileobj(r, f)
        os.replace(path + ".part", path)
    with open(path, "rb") as f:
        got = hashlib.sha256(f.read()).hexdigest()
    if got != sha256:
        sys.exit(f"{path}: wrong hash {got}")
    return path


def fresh(path):
    shutil.rmtree(path, ignore_errors=True)
    os.makedirs(path)
    return path


def unzip(path, dest):
    with zipfile.ZipFile(path) as z:
        z.extractall(fresh(dest))
    return dest


def copy(src, dst):
    os.makedirs(os.path.dirname(dst), exist_ok=True)
    shutil.copy2(src, dst)


def stage_claudito():
    files = subprocess.run(["git", "-C", ROOT, "ls-files", "-z", "--", *SOURCES],
                           capture_output=True, check=True).stdout.decode().split("\0")
    for name in filter(None, files):
        if not name.startswith(LEFT_OUT):
            copy(os.path.join(ROOT, name), os.path.join(STAGE, name))
    for name in os.listdir(os.path.join(HERE, "licenses")):
        copy(os.path.join(HERE, "licenses", name), os.path.join(STAGE, "licenses", name))


def stage_python():
    python = unzip(fetch(*PYTHON), os.path.join(STAGE, "python"))
    with open(os.path.join(python, "python312._pth"), "w", encoding="ascii") as f:
        f.write("python312.zip\n.\nLib\\site-packages\n")
    return python


def stage_qt(python):
    reqs = os.path.join(BUILD, "requirements.txt")
    with open(reqs, "w", encoding="ascii") as f:
        f.writelines(f"{name} --hash=sha256:{sha}\n" for name, sha in WHEELS)
    whole = fresh(os.path.join(BUILD, "qt"))
    say("Getting PySide6")
    subprocess.run([sys.executable, "-m", "pip", "install", "-q", "--disable-pip-version-check", "--no-compile",
                    "--no-deps", "--only-binary", ":all:", "--platform", "win_amd64", "--python-version", "3.12",
                    "--require-hashes", "--target", whole, "-r", reqs], check=True)
    site = os.path.join(python, "Lib", "site-packages")

    for folder in ("shiboken6", "PySide6"):
        src = os.path.join(whole, folder)
        for name in os.listdir(src):
            path = os.path.join(src, name)
            if not os.path.isfile(path) or name.endswith((".pyi", ".exe", ".lib")):
                continue
            low = name.lower()
            keep = (folder == "shiboken6" or name.endswith(".py") or low.startswith(("msvcp140", "vcruntime140"))
                    or name in ("pyside6.abi3.dll", "pyside6qml.abi3.dll")
                    or name in {f"Qt{m}.pyd" for m in QT_MODULES} or name in {f"Qt6{m}.dll" for m in QT_DLLS})
            if keep:
                copy(path, os.path.join(site, folder, name))
    pyside, out = os.path.join(whole, "PySide6"), os.path.join(site, "PySide6")
    for name in QT_PLUGINS:
        copy(os.path.join(pyside, "plugins", name), os.path.join(out, "plugins", name))
    for name in QT_QML:
        shutil.copytree(os.path.join(pyside, "qml", name), os.path.join(out, "qml", name), dirs_exist_ok=True)
    for folder in QT_QML_FLAT:
        src = os.path.join(pyside, "qml", folder)
        for name in os.listdir(src):
            if os.path.isfile(os.path.join(src, name)):
                copy(os.path.join(src, name), os.path.join(out, "qml", folder, name))
    for m in (*(f"Qt{m}.pyd" for m in QT_MODULES), *(f"Qt6{m}.dll" for m in QT_DLLS)):
        if not os.path.exists(os.path.join(out, m)):
            sys.exit("PySide6 has no " + m)


def main():
    if os.name != "nt":
        sys.exit("The installer can only be built on Windows.")
    with open(os.path.join(HERE, "version.txt"), encoding="ascii") as f:
        version = f.read().strip()
    say("Claudito " + version)
    fresh(STAGE)
    stage_claudito()
    copy(os.path.join(HERE, "version.txt"), os.path.join(STAGE, "version.txt"))
    python = stage_python()
    stage_qt(python)
    say("Icon")
    env = {**os.environ, "PYTHONDONTWRITEBYTECODE": "1"}
    copy(os.path.join(HERE, "make_icon.py"), os.path.join(STAGE, "tmp", "make_icon.py"))
    # With the Python that will be shipped: -B, as it ignores the environment.
    subprocess.run([os.path.join(python, "python.exe"), "-B", os.path.join(STAGE, "tmp", "make_icon.py"),
                    os.path.join(STAGE, "claudito.ico")], check=True, env=env)
    shutil.rmtree(os.path.join(STAGE, "tmp"))
    for folder, _, _ in list(os.walk(STAGE)):
        if os.path.basename(folder) == "__pycache__":
            shutil.rmtree(folder)

    inno = unzip(fetch(*INNO), os.path.join(BUILD, "inno"))
    say("Inno Setup")
    os.makedirs(DIST, exist_ok=True)
    subprocess.run([os.path.join(inno, "tools", "ISCC.exe"), "/Qp", f"/DVersion={version}", f"/DStage={STAGE}",
                    f"/DOut={DIST}", os.path.join(HERE, "claudito.iss")], check=True)
    exe = os.path.join(DIST, f"Claudito-Setup-{version}.exe")
    with open(exe, "rb") as f:
        data = f.read()
    say(f"{exe}\n    {len(data) / 1e6:.1f} MB, SHA-256 {hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    main()
