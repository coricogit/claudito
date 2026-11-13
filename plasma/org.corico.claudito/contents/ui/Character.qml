import QtQuick

import "../code/hats.js" as Hats
import "../code/sprites.js" as Sp

// Claudito in pixel art: a coral block with a shaded side, ^ ^ eyes and little
// legs, wearing a different pixel hat for each kind of work. Drawn on a 60 x 50
// pixel grid, scaled by whole numbers so it stays crisp.
Item {
  id: root

  // idle, wake, thinking, build, terminal, search, explore, lead, plan,
  // create, work, waiting, oops, done, sleep
  property string mode: "idle"
  property string hat: hatFor(mode)

  function hatFor(m) { return Hats.hatFor(m) }

  readonly property int gridW: 60
  readonly property int gridH: 50
  readonly property real p: Math.max(1, Math.floor(Math.min(width / gridW, height / gridH)))

  // ---------- Animation clock ----------
  property int frame: 0
  property bool blinking: false
  property string shownHat: ""
  property real hatDrop: 0

  Component.onCompleted: shownHat = hat
  onHatChanged: if (hat !== shownHat) hatSwap.restart()
  onModeChanged: canvas.requestPaint()

  SequentialAnimation {
    id: hatSwap
    NumberAnimation { target: root; property: "hatDrop"; to: -22; duration: root.shownHat ? 150 : 0; easing.type: Easing.InQuad }
    ScriptAction { script: root.shownHat = root.hat }
    NumberAnimation { target: root; property: "hatDrop"; from: -22; to: 0; duration: 500; easing.type: Easing.OutBounce }
  }

  Timer {
    interval: 100
    repeat: true
    running: root.visible && root.width > 0
    onTriggered: { root.frame++; canvas.requestPaint() }
  }

  Timer {
    interval: 3000 + Math.random() * 2500
    repeat: true
    running: root.visible
    onTriggered: {
      interval = 3000 + Math.random() * 2500
      root.blinking = true
      unblink.restart()
    }
  }
  Timer { id: unblink; interval: 140; onTriggered: root.blinking = false }

  // ---------- Drawing ----------
  Canvas {
    id: canvas
    anchors.fill: parent
    renderStrategy: Canvas.Cooperative

    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var p = root.p
      var ox = Math.floor((width - root.gridW * p) / 2)
      var oy = Math.floor((height - root.gridH * p) / 2)
      var f = root.frame
      var mode = root.mode

      function px(x, y, w, h, c) {
        ctx.fillStyle = c
        ctx.fillRect(ox + Math.round(x) * p, oy + Math.round(y) * p, w * p, h * p)
      }
      function sprite(s, x, y) {
        x = Math.round(x); y = Math.round(y)
        for (var r = 0; r < s.rows.length; r++) {
          var row = s.rows[r]
          for (var c = 0; c < row.length; c++) {
            var ch = row[c]
            if (ch === ".") continue
            px(x + c, y + r, 1, 1, s.palette[ch])
          }
        }
      }
      function tri(t) { return Math.abs((t % 2) - 1) }   // 1..0..1 triangle wave

      // --- Motion ---
      var busy = ["build", "terminal", "search", "explore", "lead", "plan", "create", "work"].indexOf(mode) >= 0
      var hop = 0
      if (mode === "done") hop = Math.round(Math.abs(Math.sin(f * 0.45)) * 7)
      else if (mode === "build") hop = [0, 1, 2, 1][f % 4]
      else if (busy || mode === "wake") hop = (f >> 1) % 2
      var shiftX = mode === "explore" ? [0, 1, 0, -1][(f >> 1) % 4] : 0
      var bx = 18 + shiftX
      var by = 20 - hop

      // --- Shadow ---
      var sw = Math.max(12, 24 - hop * 2)
      px(32 - sw / 2 + shiftX, 46, sw, 1, "rgba(0,0,0,0.22)")
      px(32 - sw / 2 + 2 + shiftX, 47, sw - 4, 1, "rgba(0,0,0,0.12)")

      // --- Legs ---
      var legY = by + 22
      var legs = [bx + 4, bx + 9, bx + 15, bx + 20]
      for (var i = 0; i < 4; i++) {
        var lift = mode === "explore" ? ((i + (f >> 1)) % 2) : 0
        var lh = mode === "done" && hop > 2 ? 2 : 3
        px(legs[i], legY - lift, 2, lh, "#C2582F")
      }

      // --- Body: front face, shaded left side, top highlight, stepped corners ---
      var front = "#EE7E55", side = "#C2582F", top = "#F7A07B", bottom = "#D96A41"
      px(bx, by + 3, 2, 19, side)
      px(bx + 1, by + 2, 1, 1, side)
      px(bx + 2, by + 2, 24, 19, front)      // middle
      px(bx + 3, by + 1, 22, 1, front)       // rounded top
      px(bx + 4, by, 20, 1, top)
      px(bx + 3, by + 1, 1, 1, top)
      px(bx + 24, by + 1, 1, 1, top)
      px(bx + 3, by + 21, 22, 1, bottom)     // rounded bottom
      px(bx + 2, by + 20, 1, 1, bottom)
      px(bx + 25, by + 20, 1, 1, bottom)
      px(bx + 1, by + 21, 2, 1, side)
      // --- Arms ---
      var armC = "#D96A41"
      var leftArm = { x: bx - 2, y: by + 12 }
      var rightArm = { x: bx + 26, y: by + 12 }
      if (mode === "idle" || mode === "thinking") leftArm = { x: bx - 2, y: by + 11 }
      if (mode === "waiting" || mode === "wake") rightArm = { x: bx + 26 + (f >> 1) % 2, y: by + 2 + (f >> 1) % 2 * 2 }
      if (mode === "lead") rightArm = { x: bx + 26, y: by + 5 }
      if (mode === "build") rightArm = { x: bx + 26, y: (f % 4 < 2) ? by + 6 : by + 10 }
      if (mode === "done") { leftArm = { x: bx - 2, y: by + 2 }; rightArm = { x: bx + 26, y: by + 2 } }
      if (mode === "sleep") { leftArm = { x: bx - 1, y: by + 15 }; rightArm = { x: bx + 25, y: by + 15 } }
      if (mode === "terminal" || mode === "work") rightArm = { x: bx + 22, y: by + 17 + (f % 2) }
      px(leftArm.x, leftArm.y, 3, 3, armC)
      px(rightArm.x, rightArm.y, 3, 3, armC)

      // --- Eyes ---
      var ink = "#1A1A1A"
      var look = 0, lookY = 0
      if (mode === "search") look = Math.round((tri(f / 12) - 0.5) * 4)
      if (mode === "thinking") { look = 1; lookY = -1 }
      if (mode === "terminal" || mode === "work") { look = 2; lookY = 1 }
      var eyes = [bx + 6 + look, bx + 17 + look]
      var ey = by + 7 + lookY
      for (var e = 0; e < 2; e++) {
        var x = eyes[e]
        if (mode === "sleep" || root.blinking) {
          px(x, ey + 1, 5, 1, ink)
        } else if (mode === "oops") {
          if (e === 0) { px(x, ey, 1, 1, ink); px(x + 1, ey + 1, 2, 1, ink); px(x, ey + 2, 1, 1, ink) }
          else { px(x + 3, ey, 1, 1, ink); px(x + 1, ey + 1, 2, 1, ink); px(x + 3, ey + 2, 1, 1, ink) }
        } else if (busy) {
          px(x + 1, ey, 3, 3, ink)
          px(x + 1, ey, 1, 1, "#FFFFFF")
        } else {
          // happy ^ ^
          px(x + 1, ey, 3, 1, ink)
          px(x, ey + 1, 1, 2, ink)
          px(x + 4, ey + 1, 1, 2, ink)
        }
      }
      if (mode === "done" || mode === "wake" || mode === "idle") {
        px(bx + 4, by + 12, 3, 1, "#F28B82")
        px(bx + 21, by + 12, 3, 1, "#F28B82")
      }
      if (mode === "done" || mode === "wake") { px(bx + 13, by + 12, 2, 1, ink); px(bx + 12, by + 11, 1, 1, ink); px(bx + 15, by + 11, 1, 1, ink) }
      if (mode === "oops") { px(bx + 12, by + 13, 1, 1, ink); px(bx + 13, by + 12, 2, 1, ink); px(bx + 15, by + 13, 1, 1, ink) }

      // --- Hat ---
      var hatName = root.shownHat
      if (hatName && Sp.HATS[hatName]) {
        var hs = Sp.HATS[hatName]
        var hx = bx + 1 + (hatName === "beret" ? 1 : 0)
        var hy = by - hs.rows.length + 2 + Math.round(root.hatDrop)
        sprite(hs, hx, hy)
        if (hatName === "beanie") {
          var pf = Sp.PROPELLER[f % Sp.PROPELLER.length]
          sprite({ palette: Sp.PROPELLER_PALETTE, rows: pf }, hx + 8, hy - 1)
        }
        if (hatName === "miner" && root.hatDrop === 0 && (f % 14) !== 0) {
          for (var bi = 1; bi <= 16; bi++) {
            var spread = Math.floor(bi / 3)
            px(hx + 16 + bi, hy + 4 - spread, 1, spread * 2 + 1,
               "rgba(255,243,191," + (0.55 - bi * 0.03).toFixed(2) + ")")
          }
        }
      }

      // --- Props ---
      if (mode === "idle" || mode === "thinking") {
        sprite(Sp.MUG, bx - 10, by + 9)
        for (var s2 = 0; s2 < 3; s2++) {
          var st = (f + s2 * 5) % 15
          px(bx - 8 + s2 * 2 + (st >> 2) % 2, by + 7 - st / 2, 1, 1,
             "rgba(233,211,176," + (1 - st / 15).toFixed(2) + ")")
        }
      }
      if (mode === "terminal" || mode === "work") {
        sprite(Sp.LAPTOP, bx + 20, by + 12)
        if (f % 3 === 0) px(bx + 24 + (f * 7) % 9, by + 20, 1, 1, "#8CE99A")
      }
      if (mode === "build") {
        sprite((f % 4 < 2) ? Sp.HAMMER_UP : Sp.HAMMER_DOWN, bx + 27, (f % 4 < 2) ? by - 5 : by + 6)
        if (f % 4 === 2) { px(bx + 37, by + 4, 1, 1, "#FFD43B"); px(bx + 38, by + 8, 1, 1, "#FFD43B"); px(bx + 36, by + 12, 1, 1, "#FFD43B") }
      }
      if (mode === "search") sprite(Sp.MAGNIFIER, bx + 26 + Math.round((tri(f / 12) - 0.5) * 4), by + 2)
      if (mode === "create") {
        sprite(Sp.BRUSH, bx + 28, by + 1 + (f >> 1) % 2)
        var paint = ["#FA5252", "#FCC419", "#40C057", "#4C6EF5"]
        for (var d = 0; d < 4; d++) px(bx + 31 + (d * 3 + f) % 6, by + 9 + d, 1, 1, paint[d])
      }
      if (mode === "lead") {
        px(bx + 28, by - 3, 1, 9, "#495057")
        px(bx + 29, by - 3, 5 + (f >> 1) % 2, 3, "#E03131")
      }
      if (mode === "thinking") {
        for (var dd = 0; dd < 3; dd++)
          if ((f >> 2) % 4 > dd) px(bx + 28 + dd * 3, by - 6, 2, 2, "#ADB5BD")
      }
      if (mode === "waiting") sprite(Sp.BANG, bx + 27, by - 12 + ((f >> 2) % 2))
      if (mode === "oops") sprite(Sp.DROP, bx + 25, by + 1 + (f % 10) / 2)
      if (mode === "sleep") {
        for (var z = 0; z < 3; z++) {
          var zt = (f + z * 10) % 30
          sprite(Sp.Z, bx + 27 + zt / 4, by - 2 - zt / 2)
        }
      }
      if (mode === "done" || mode === "plan") {
        for (var k = 0; k < 6; k++) {
          var a = (k / 6) * Math.PI * 2 + f * (mode === "done" ? 0.15 : 0.05)
          if (mode === "plan" && (f + k * 3) % 8 < 3) continue
          sprite(Sp.STAR, 31 + Math.cos(a) * 26, 30 + Math.sin(a) * 16)
        }
      }
      if (mode === "done") {
        var conf = ["#FA5252", "#FCC419", "#40C057", "#4C6EF5", "#BE4BDB"]
        for (var c2 = 0; c2 < 10; c2++) {
          var cy = (f * 1.5 + c2 * 9) % 46
          px((c2 * 13 + Math.floor(cy / 6)) % 58, cy, 1, 1, conf[c2 % 5])
        }
      }
    }
  }
}
