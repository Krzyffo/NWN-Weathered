"""Where Neverwinter Nights lives on this machine, for the other tools.

nwn_root(): the game's install folder (the one with data/nwn_base.key).
    From the NWN_ROOT environment variable, else the Steam libraries listed
    in the registry.
nwn_user(): the NWN user folder (modules, hak, localvault, logs).
    From the NWN_USER environment variable (or NWN_HOME, as Beamdog's tools
    use), else Documents\\Neverwinter Nights.

Nothing machine-specific is stored in the repository: set the variables
once if the game or its user folder is somewhere else, for example
    setx NWN_USER "D:\\Games\\NWN user"
"""
import os
import re
import sys

NWN_FOLDER = os.path.join("steamapps", "common", "Neverwinter Nights")


def is_nwn_root(path):
    return bool(path) and os.path.exists(os.path.join(path, "data", "nwn_base.key"))


def is_nwn_user(path):
    return bool(path) and any(os.path.exists(os.path.join(path, name))
                              for name in ("nwn.ini", "settings.tml", "modules", "hak"))


def _steam_libraries():
    """Steam library folders, from Steam's libraryfolders.vdf."""
    try:
        import winreg
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Software\Valve\Steam") as key:
            steam = winreg.QueryValueEx(key, "SteamPath")[0]
    except (ImportError, OSError):
        return []
    vdf = os.path.join(steam, "steamapps", "libraryfolders.vdf")
    if not os.path.exists(vdf):
        return [steam]
    with open(vdf, encoding="utf-8", errors="replace") as f:
        paths = re.findall(r'"path"\s+"([^"]+)"', f.read())
    # The file escapes backslashes: "D:\\Games\\Steam".
    return [p.replace("\\\\", "\\") for p in paths] or [steam]


def _documents():
    try:
        import winreg
        key_path = r"Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders"
        with winreg.OpenKey(winreg.HKEY_CURRENT_USER, key_path) as key:
            return os.path.expandvars(winreg.QueryValueEx(key, "Personal")[0])
    except (ImportError, OSError):
        return os.path.join(os.path.expanduser("~"), "Documents")


def nwn_root(required=True):
    env = os.environ.get("NWN_ROOT")
    if is_nwn_root(env):
        return env
    for library in _steam_libraries():
        path = os.path.join(library, NWN_FOLDER)
        if is_nwn_root(path):
            return path
    if required:
        sys.exit("Neverwinter Nights install not found. Set NWN_ROOT to the folder with data in it:\n"
                 '  setx NWN_ROOT "C:\\path\\to\\Neverwinter Nights"   (then open a new terminal)')
    return None


def nwn_user(required=True):
    for var in ("NWN_USER", "NWN_HOME"):
        env = os.environ.get(var)
        if is_nwn_user(env):
            return env
    path = os.path.join(_documents(), "Neverwinter Nights")
    if is_nwn_user(path):
        return path
    if required:
        sys.exit("NWN user folder not found (the one with modules and hak in it). Set NWN_USER to it:\n"
                 '  setx NWN_USER "C:\\path\\to\\your\\NWN user folder"   (then open a new terminal)')
    return None
