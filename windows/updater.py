"""Keeps an installed Claudito up to date with the releases on GitHub.

Only the copy made by the .exe installer updates itself: it carries version.txt
and its own Python. A copy run from the source code is yours to `git pull`.

The installer of the new version is downloaded, checked against the SHA-256 that
GitHub publishes for it and run silently; installer/claudito.iss puts the old
version back if that fails. claudito.pyw decides when.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import time
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)

LATEST = "https://api.github.com/repos/coricogit/claudito/releases/latest"
DOWNLOADS = "https://github.com/coricogit/claudito/releases/download/"
PROTOCOL = "=https"
MAX_BYTES = 300_000_000
MAX_TRIES = 2             # a day: an update that fails is left alone until tomorrow
CREATE_NO_WINDOW = 0x08000000


class Offline(OSError):
    """Nothing could be downloaded; try again another time."""


def installed_version(root=ROOT):
    """"1.2.3", or "" when this is not an installed copy."""
    if os.name != "nt" or not os.path.exists(os.path.join(root, "python", "pythonw.exe")):
        return ""
    try:
        with open(os.path.join(root, "version.txt"), encoding="ascii") as f:
            text = f.read().strip()
    except (OSError, ValueError):
        return ""
    return text if numbers(text) else ""


def numbers(version):
    """"1.2.3" -> (1, 2, 3, 0), or None if it doesn't look like that."""
    if not isinstance(version, str) or not re.fullmatch(r"[0-9]{1,6}(\.[0-9]{1,6}){0,3}", version):
        return None
    parts = [int(n) for n in version.split(".")]
    return tuple(parts + [0] * (4 - len(parts)))


def newer_release(text, current):
    """(version, url, sha256) of the installer in GitHub's answer, or None if
    there is nothing newer that can be trusted."""
    try:
        release = json.loads(text)
    except ValueError:
        return None
    if not isinstance(release, dict) or release.get("draft") or release.get("prerelease"):
        return None
    tag = release.get("tag_name")
    version = tag[1:] if isinstance(tag, str) and tag.startswith("v") else ""
    if not numbers(version) or numbers(version) <= numbers(current):
        return None
    name = f"Claudito-Setup-{version}.exe"
    for asset in release.get("assets") or ():
        if not isinstance(asset, dict) or asset.get("name") != name:
            continue
        digest = re.fullmatch(r"sha256:([0-9a-f]{64})", str(asset.get("digest")))
        if digest and asset.get("browser_download_url") == DOWNLOADS + tag + "/" + name:
            return version, asset["browser_download_url"], digest.group(1)
    return None


def fetch(url, path):
    """Downloads with Windows' own curl: unlike Python, it uses (and gets when
    missing) the certificates of Windows."""
    curl = os.path.join(os.environ.get("SystemRoot", r"C:\Windows"), "System32", "curl.exe")
    cmd = [curl, "-q", "--silent", "--fail", "--location", "--max-redirs", "5", "--proto", PROTOCOL,
           "--proto-redir", PROTOCOL, "--connect-timeout", "30", "--speed-limit", "1000", "--speed-time", "60",
           "--max-filesize", str(MAX_BYTES), "--user-agent", "Claudito", "--output", path]
    proxy = urllib.request.getproxies().get("https")   # the one set in Windows
    if proxy:
        cmd += ["--proxy", proxy]
    try:
        code = subprocess.run(cmd + ["--url", url], creationflags=CREATE_NO_WINDOW, stdin=subprocess.DEVNULL,
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL).returncode
    except OSError as e:
        raise Offline(f"curl: {e}") from e
    if code:
        raise Offline(f"curl: error {code}")


def sha256(path):
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for block in iter(lambda: f.read(1 << 20), b""):
            h.update(block)
    return h.hexdigest()


def download(current, folder, skip=lambda version: False, fetch=fetch):
    """Gets the installer of a newer version. Returns (version, path, sha256),
    or None if there isn't one; raises Offline, or ValueError if what came is
    not what GitHub announced."""
    os.makedirs(folder, exist_ok=True)
    answer = os.path.join(folder, "latest.json")
    fetch(LATEST, answer)
    with open(answer, encoding="utf-8") as f:
        found = newer_release(f.read(), current)
    if not found or skip(found[0]):
        shutil.rmtree(folder, ignore_errors=True)   # the installer of the last update
        return None
    version, url, digest = found
    path = os.path.join(folder, f"Claudito-Setup-{version}.exe")
    if not (os.path.exists(path) and sha256(path) == digest):
        part = path + ".part"
        fetch(url, part)
        if sha256(part) != digest:
            os.remove(part)
            raise ValueError(f"the installer of {version} has the wrong SHA-256")
        os.replace(part, path)
    return version, path, digest


def run(path, digest, log, root=ROOT):
    """Starts the installer, which closes this Claudito and opens the new one."""
    if sha256(path) != digest:   # it may have been there for hours
        raise ValueError("the downloaded installer has changed")
    return subprocess.Popen([path, "/VERYSILENT", "/SUPPRESSMSGBOXES", "/NORESTART", "/SP-", "/UPDATE=1",
                             f"/DIR={root}", f"/LOG={log}"], cwd=os.path.dirname(path), close_fds=True,
                            stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def today():
    return time.strftime("%Y-%m-%d")


def tries(saved, version):
    """How many times this version was tried today, from the text in the settings."""
    parts = str(saved or "").split(":")
    return int(parts[1]) if len(parts) == 3 and parts[::2] == [version, today()] and parts[1].isdigit() else 0


def count_try(saved, version):
    """That text with one more."""
    return f"{version}:{tries(saved, version) + 1}:{today()}"
