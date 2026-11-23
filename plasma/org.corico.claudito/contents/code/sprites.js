.pragma library

// Pixel-art sprites. Each sprite is rows of characters; "." is transparent and
// every other character is looked up in the sprite's palette.

var HATS = {
  hardhat: {
    palette: { y: "#F5C518", Y: "#FFE680", h: "#D9A70F", b: "#E0A800", k: "#9C7800" },
    rows: [
      "..........kkkkkk..........",
      "........kyYYyhyyyk........",
      ".......kyYYyyhyyyyk.......",
      "......kyyyyyyhyyyyyk......",
      "......kyyyyyyhyyyyyk......",
      "......kyyyyyyhyyyyyk......",
      "..kbbbbbbbbbbbbbbbbbbbbk..",
      ".kbbbbbbbbbbbbbbbbbbbbbbk."
    ]
  },
  miner: {
    palette: { o: "#E8590C", O: "#FD7E14", g: "#495057", w: "#FFF3BF", W: "#FFFFFF", k: "#8A3306" },
    rows: [
      "..........kkkkkk..........",
      "........koooooooook.......",
      ".......koooggggoooook.....",
      "......kooooggwwgoooook....",
      "......koooogwWwgoooook....",
      "......kooooggggggooook....",
      "..kOOOOOOOOOOOOOOOOOOOOk..",
      ".kOOOOOOOOOOOOOOOOOOOOOOk."
    ]
  },
  detective: {
    palette: { c: "#8B5E3C", C: "#6B4226", D: "#4A2C17" },
    rows: [
      "..........DD..DD..........",
      "............DD............",
      "........DcCcCcCcCD........",
      ".......DCcCcCcCcCcD.......",
      "......DcCcCcCcCcCcCD......",
      "......DCcCcCcCcCcCcD......",
      "......DcCcCcCcCcCcCD......",
      ".DDDDDDDDDDDDDDDDDDDDDDDD."
    ]
  },
  explorer: {
    palette: { e: "#E9D8A6", E: "#FFF8E1", g: "#6B8E23", s: "#C9B37E", k: "#8A7440" },
    rows: [
      "............kk............",
      ".........keeeeeek.........",
      "........keEEeeeeek........",
      ".......keEeeeeeeeek.......",
      "......keeeeeeeeeeeek......",
      "......kggggggggggggk......",
      ".kssssssssssssssssssssssk.",
      "..kkkkkkkkkkkkkkkkkkkkkk.."
    ]
  },
  captain: {
    palette: { w: "#F8F9FA", k: "#868E96", y: "#FAB005", A: "#1C2A4A", n: "#1C2A4A", K: "#111111" },
    rows: [
      "......kkkkkkkkkkkkkk......",
      "....kwwwwwwwwwwwwwwwwk....",
      "...kwwwwwwwwyyyywwwwwwk...",
      "...kwwwwwwwwyAAywwwwwwk...",
      "....kwwwwwwwyyyywwwwwk....",
      "......nnnnnnnnnnnnnn......",
      "......nyyyyyyyyyyyyn......",
      ".......KKKKKKKKKKKKKK....."
    ]
  },
  wizard: {
    palette: { p: "#5F3DC4", P: "#7048E8", y: "#FFD43B", k: "#3B2381" },
    rows: [
      "...............kk.........",
      "..............kpk.........",
      ".............kppk.........",
      "............kpppk.........",
      "...........kpppppk........",
      "...........kppyppk........",
      "..........kppyyyppk.......",
      "..........kpppyppppk......",
      ".........kpppppppppk......",
      ".........kyyyyyyyyyyk.....",
      "........kppppppppppppk....",
      ".kPPPPPPPPPPPPPPPPPPPPPPk.",
      "..kkkkkkkkkkkkkkkkkkkkkk.."
    ]
  },
  beret: {
    palette: { r: "#C92A2A", R: "#FF8787", d: "#7D1515" },
    rows: [
      "...............d..........",
      "...............d..........",
      "........drrrrrrrrrrd......",
      ".....drrRRrrrrrrrrrrrd....",
      "....drrRRrrrrrrrrrrrrrrd..",
      "....drrrrrrrrrrrrrrrrrrd..",
      ".....dddddddddddddddddd..."
    ]
  },
  beanie: {
    palette: { b: "#228BE6", r: "#FA5252", y: "#FCC419", g: "#40C057", B: "#1864AB", s: "#495057" },
    rows: [
      ".............s............",
      "..........bbbrrryy........",
      "........bbbbbrrryyyy......",
      ".......bbbbbbrrryyyyg.....",
      "......bbbbbbbrrryyyggg....",
      "......bbbbbbbrrryyyggg....",
      "....BBBBBBBBBBBBBBBBBBBB.."
    ]
  },
  nightcap: {
    palette: { n: "#4263EB", y: "#FFE066", w: "#F1F3F5", g: "#ADB5BD" },
    rows: [
      "..........nnnnnnnnn.......",
      "........nnnnnnnnnnnnnn....",
      ".......nnnynnnnnnnnnnnnn..",
      "......nnnnnnnnnnynnnn.nnn.",
      "......nnnnnnnnnnnnnnn..nww",
      ".....wwwwwwwwwwwwwwwwww.ww",
      ".....gggggggggggggggggg..."
    ]
  },
  party: {
    palette: { p: "#F06595", y: "#FFD43B", b: "#74C0FC", k: "#A61E4D" },
    rows: [
      ".............bb...........",
      "............bbbb..........",
      ".............kk...........",
      "............kpyk..........",
      "............kppk..........",
      "...........kpppbk.........",
      "...........kyppppk........",
      "..........kppppypk........",
      "..........kpbpppppk.......",
      ".........kpppppyppk.......",
      ".........yyyyyyyyyyy......"
    ]
  },

  // Seasonal hats, worn when there is no work hat on.
  spring: {
    palette: { p: "#F783AC", w: "#FFFFFF", v: "#B197FC", y: "#FFD43B", g: "#2F9E44", L: "#69DB7C" },
    rows: [
      "....pp......ww......vv....",
      "...pyyp....wyyw....vyyv...",
      ".ggpyypgLggwyywggLgvyyvgg.",
      "..gLppgggLggwwggLgggvvLg.."
    ]
  },
  summer: {
    palette: { s: "#F2D388", S: "#E0B84C", k: "#B58B2A", r: "#E03131" },
    rows: [
      ".........kkkkkkkk.........",
      "........kSsSsSsSsk........",
      ".......ksSsSsSsSsSk.......",
      "......kSsSsSsSsSsSsk......",
      "......krrrrrrrrrrrrk......",
      "..kSsSsSsSsSsSsSsSsSsSsk..",
      ".kssssssssssssssssssssssk."
    ]
  },
  autumn: {
    palette: { c: "#C68642", C: "#A5662B", d: "#6B3F16", s: "#4A2C17", o: "#F76707", O: "#D9480F" },
    rows: [
      "............sss...o.......",
      "............ss...ooo......",
      "........dcCcCcCcCoOo......",
      "......dcCcCcCcCcCcOd......",
      ".....dCcCcCcCcCcCcCcd.....",
      "....dcCcCcCcCcCcCcCcCd....",
      "...dCcCcCcCcCcCcCcCcCcd...",
      "...dddddddddddddddddddd..."
    ]
  },
  winter: {
    palette: { w: "#F8F9FA", g: "#CED4DA", t: "#1C7ED6", T: "#1864AB" },
    rows: [
      "...........wwww...........",
      "..........wwwwgg..........",
      "...........wwgg...........",
      ".........tttttttt.........",
      ".......tttTtttTtttT.......",
      "......tttTtttTtttTtt......",
      "......ttTtttTtttTttt......",
      "...wgwgwgwgwgwgwgwgwgwg...",
      "...wgwgwgwgwgwgwgwgwgwg..."
    ]
  }
}

// Seasonal clothes over the lower part of the body (26 x 8, from its left
// edge). "sleeve" also dresses the arms.
var OUTFITS = {
  spring: {
    palette: { g: "#69DB7C", G: "#2F9E44", y: "#FFD43B", p: "#F783AC" },
    rows: [
      "....GG..............GG....",
      "....GyggggggggggggggyG....",
      "....GggggggppggggggggG....",
      "....GgggggpyypgggggggG....",
      "Gggggggggggppggggggggggggg",
      "Gggggggggggggggggggggggggg",
      "Gggggggggggggggggggggggggg",
      ".GGGGGGGGGGGGGGGGGGGGGGGG."
    ]
  },
  summer: {
    sleeve: "#15AABF",
    palette: { b: "#15AABF", B: "#0B7285", c: "#E3FAFC", y: "#FFD43B", p: "#FF8FB8", o: "#FFFFFF", w: "#E3FAFC" },
    rows: [
      "bbbbbbbbcc......ccbbbbbbbb",
      "bbybbbbbbcc....ccbbpbbbbbb",
      "byoybbpbbbcc..ccbbpopbbybb",
      "bbybbpopbbbbccbbbbbpbbyoyb",
      "bbbbbbpbbbbbwbbbbbbbbbbybb",
      "bbbpbbbbbbybbbbbbpbbbbbbbb",
      "bbpopbbbbyoybwbbpopbbbbbbb",
      ".BBBBBBBBBBBBBBBBBBBBBBBB."
    ]
  },
  autumn: {
    sleeve: "#8C2F39",
    palette: { m: "#8C2F39", M: "#6D1F29", z: "#F2B134" },
    rows: [
      "mmmmmmMmMmMmMmMmMmMmmmmmmm",
      "mmmmmmmmmmmmmmmmmmmmmmmmmm",
      "zmmmzmmmzmmmzmmmzmmmzmmmzm",
      "mzmzmzmzmzmzmzmzmzmzmzmzmz",
      "mmzmmmzmmmzmmmzmmmzmmmzmmm",
      "mmmmmmmmmmmmmmmmmmmmmmmmmm",
      "mmmmmmmmmmmmmmmmmmmmmmmmmm",
      ".MmMmMmMmMmMmMmMmMmMmMmMm."
    ]
  },
  winter: {
    palette: { r: "#E03131", w: "#F8F9FA", d: "#8E1B1B" },
    rows: [
      "rrrrwwrrrrwwrrrrwwrrrrwwrr",
      "rrrrwwrrrrwwrrrrwwrrrrwwrr",
      "dddddddddddddddddddddddddd",
      "...............drrrrd.....",
      "...............dwwwwd.....",
      "...............drrrrd.....",
      "...............drrrrd.....",
      "...............w.ww.w....."
    ]
  }
}

// Propeller frames for the beanie (spinning).
var PROPELLER = [
  ["rrrrrsyyyyy"],
  ["..rrrsyyy.."],
  [".....s....."],
  ["..yyysrrr.."],
  ["yyyyysrrrrr"]
]
var PROPELLER_PALETTE = { r: "#FA5252", y: "#FCC419", s: "#495057" }

var LAPTOP = {
  palette: { k: "#1F1F24", K: "#2B2B33", w: "#E9ECEF", G: "#3A3A42", g: "#55555F" },
  rows: [
    ".....kkkkkkkkkkkk",
    "....kKKKKKKKKKKk.",
    "...kKKKKwKKKKKk..",
    "...kKKKKKwwKKKk..",
    "..kKKKKKKKKKKk...",
    "..kKKKKKKKKKKk...",
    ".kKKKKKKKKKKk....",
    ".kkkkkkkkkkkk....",
    "gGGGGGGGGGGGGGGGg",
    ".GGGGGGGGGGGGGGG."
  ]
}

var MUG = {
  palette: { c: "#C9A06A", w: "#FFF4E0", b: "#4A2A17" },
  rows: [
    ".cccccc..",
    "cbbbbbbc.",
    "cwwwwwwccc",
    "cwwwwwwc.c",
    "cwwwwwwc.c",
    "cwwwwwwccc",
    ".cccccc.."
  ]
}

var HAMMER_UP = {
  palette: { g: "#ADB5BD", G: "#495057", h: "#8B5E3C", H: "#5C3A21" },
  rows: [
    "GGGGGGGG",
    "GggggggG",
    "GggggggG",
    "GGGGGGGG",
    "...hH...",
    "...hH...",
    "...hH...",
    "...hH...",
    "...hH..."
  ]
}
var HAMMER_DOWN = {
  palette: { g: "#ADB5BD", G: "#495057", h: "#8B5E3C", H: "#5C3A21" },
  rows: [
    "......GGGG",
    "......GggG",
    "hhhhhhGggG",
    "HHHHHHGggG",
    "......GggG",
    "......GGGG"
  ]
}

var MAGNIFIER = {
  palette: { k: "#495057", l: "#A5D8FF", L: "#E7F5FF", h: "#6B4226" },
  rows: [
    ".kkkk..",
    "kLlllk.",
    "klllLk.",
    "kllllk.",
    ".kkkkh.",
    ".....hh",
    "......h"
  ]
}

var BRUSH = {
  palette: { h: "#8B5E3C", m: "#ADB5BD", b: "#4C6EF5" },
  rows: [
    ".b.",
    "bbb",
    "bbb",
    ".m.",
    ".h.",
    ".h.",
    ".h."
  ]
}

var BANG = {
  palette: { y: "#FFD43B", k: "#E67700", t: "#5C3D00" },
  rows: [
    ".kkkkk.",
    "kyytyyk",
    "kyytyyk",
    "kyytyyk",
    "kyyyyyk",
    "kyytyyk",
    ".kkkkk.",
    "..k...."
  ]
}

var Z = {
  palette: { z: "#5C7CFA" },
  rows: ["zzz", "..z", ".z.", "z..", "zzz"]
}

var STAR = {
  palette: { s: "#FFD43B" },
  rows: [".s.", "sss", ".s."]
}

var DROP = {
  palette: { b: "#74C0FC", B: "#1C7ED6" },
  rows: [".B.", "BbB", "BbB", ".B."]
}
