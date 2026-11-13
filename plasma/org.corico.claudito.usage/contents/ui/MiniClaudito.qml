import QtQuick

// Tiny pixel Claudito for the panel. mood: "happy", "focus", "worried", "sleep".
Item {
  id: root
  property string mood: "happy"
  readonly property int gw: 16
  readonly property int gh: 14
  readonly property real p: Math.max(1, Math.floor(Math.min(width / gw, height / gh)))
  property bool blink: false
  implicitWidth: gw * 2
  implicitHeight: gh * 2

  onMoodChanged: canvas.requestPaint()
  onBlinkChanged: canvas.requestPaint()
  onWidthChanged: canvas.requestPaint()
  onHeightChanged: canvas.requestPaint()

  Timer {
    interval: 3500 + Math.random() * 3000
    running: root.mood !== "sleep"
    repeat: true
    onTriggered: { interval = 3500 + Math.random() * 3000; root.blink = true; unblink.restart() }
  }
  Timer { id: unblink; interval: 150; onTriggered: root.blink = false }

  Canvas {
    id: canvas
    anchors.fill: parent
    onPaint: {
      var ctx = getContext("2d")
      ctx.reset()
      var p = root.p
      var ox = Math.floor((width - root.gw * p) / 2)
      var oy = Math.floor((height - root.gh * p) / 2)
      function px(x, y, w, h, c) { ctx.fillStyle = c; ctx.fillRect(ox + x * p, oy + y * p, w * p, h * p) }
      var front = "#EE7E55", side = "#C2582F", top = "#F7A07B", ink = "#1A1A1A"
      // body
      px(1, 2, 1, 9, side)
      px(2, 1, 13, 10, front)
      px(3, 0, 11, 1, top)
      px(2, 1, 1, 1, top)
      // legs
      px(3, 11, 1, 2, side); px(6, 11, 1, 2, side); px(9, 11, 1, 2, side); px(12, 11, 1, 2, side)
      // eyes
      var m = root.mood
      var eyes = [4, 10]
      for (var i = 0; i < 2; i++) {
        var x = eyes[i]
        if (m === "sleep" || root.blink) px(x, 5, 3, 1, ink)
        else if (m === "happy") { px(x + 1, 4, 1, 1, ink); px(x, 5, 1, 1, ink); px(x + 2, 5, 1, 1, ink) }
        else if (m === "worried") {
          if (i === 0) { px(x, 4, 1, 1, ink); px(x + 1, 5, 1, 1, ink); px(x, 6, 1, 1, ink) }
          else { px(x + 2, 4, 1, 1, ink); px(x + 1, 5, 1, 1, ink); px(x + 2, 6, 1, 1, ink) }
        } else { px(x + 1, 4, 2, 2, ink) }
      }
      if (m === "worried") { px(14, 1, 1, 1, "#74C0FC"); px(14, 2, 1, 2, "#1C7ED6") }
      if (m === "happy") { px(3, 7, 2, 1, "#F28B82"); px(12, 7, 2, 1, "#F28B82") }
    }
  }
}
