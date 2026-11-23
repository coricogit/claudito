"""Which season it is where you live, for Claudito's seasonal clothes."""
import datetime as dt
import os

SEASONS = ("spring", "summer", "autumn", "winter")

# First day of each season in the northern hemisphere (the equinoxes and
# solstices move a day or so between years).
STARTS = (((3, 20), "spring"), ((6, 21), "summer"), ((9, 22), "autumn"), ((12, 21), "winter"))
OPPOSITE = {"spring": "autumn", "summer": "winter", "autumn": "spring", "winter": "summer"}

# Countries with (nearly) all their people south of the equator.
SOUTHERN = set("AO AR AU BI BO BR BW CD CG CL FJ ID KM LS MG MU MW MZ NA NC NZ PE PF PG PY "
               "RE RW SB SC SZ TL TO TZ UY VU WS ZA ZM ZW".split())


def season_on(day, southern=False):
    name = "winter"   # before the first start of the year
    for start, season in STARTS:
        if (day.month, day.day) >= start:
            name = season
    return OPPOSITE[name] if southern else name


def country(fallback=""):
    """Two-letter code of the country chosen in Windows settings."""
    if os.name == "nt":
        import winreg
        try:
            with winreg.OpenKey(winreg.HKEY_CURRENT_USER, r"Control Panel\International\Geo") as key:
                return str(winreg.QueryValueEx(key, "Name")[0]).upper()
        except OSError:
            pass
    return fallback.upper()


def current(fallback_country=""):
    return season_on(dt.date.today(), country(fallback_country) in SOUTHERN)
