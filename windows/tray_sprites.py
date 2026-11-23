"""Seasonal clothes for the tiny Claudito (the 16 x 16 tray icon and the face
in the usage panel): the small version of the HATS and
OUTFITS in sprites.js. "." is transparent."""

HAT_TOP = -3      # rows above the head; the last one covers its top
OUTFIT_TOP = 8    # rows of the body

HATS = {
    "spring": ({"p": "#F783AC", "w": "#FFFFFF", "v": "#B197FC", "y": "#FFD43B", "g": "#2F9E44", "L": "#69DB7C"}, (
        "................",
        "...p....w....v..",
        "..pyp..wyw..vyv.",
        "..gpggLgwgLggvg.")),
    "summer": ({"s": "#F2D388", "S": "#E0B84C", "k": "#B58B2A", "r": "#E03131"}, (
        "......kkkkk.....",
        ".....sSsSsSs....",
        ".....rrrrrrr....",
        ".sSsSsSsSsSsSsSs")),
    "autumn": ({"c": "#C68642", "C": "#A5662B", "d": "#6B3F16", "s": "#4A2C17", "o": "#F76707", "O": "#D9480F"}, (
        ".......ss..o....",
        "......cCcCooo...",
        "....cCcCcCcOc...",
        "..ddddddddddddd.")),
    "winter": ({"w": "#F8F9FA", "g": "#CED4DA", "t": "#1C7ED6", "T": "#1864AB"}, (
        ".......www......",
        "......ttttt.....",
        "....ttTttTttt...",
        "..wgwgwgwgwgwgw.")),
}

OUTFITS = {
    "spring": ({"g": "#69DB7C", "G": "#2F9E44", "y": "#FFD43B", "p": "#F783AC"}, (
        "...G.........G..",
        "...GgggpypgggG..",
        ".Gggggggggggggg.")),
    "summer": ({"b": "#15AABF", "c": "#E3FAFC", "y": "#FFD43B", "p": "#FF8FB8"}, (
        ".bbbbcc...ccbbb.",
        ".bybbbbcccbbbpb.",
        ".bbbpbbbcbbybbb.")),
    "autumn": ({"m": "#8C2F39", "z": "#F2B134"}, (
        ".mmmmmmmmmmmmmm.",
        ".mzmzmzmzmzmzmz.",
        ".mmmmmmmmmmmmmm.")),
    "winter": ({"r": "#E03131", "w": "#F8F9FA", "d": "#8E1B1B"}, (
        ".rrwwrrwwrrwwrr.",
        ".dddddddddddddd.",
        ".........drrd...")),
}


def pixels(sprite, top):
    """(x, y, color) of every pixel."""
    palette, rows = sprite
    for dy, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch != ".":
                yield x, top + dy, palette[ch]
