import QtQuick
import QtQuick.Window

// The same Character.qml, strings and hats as the KDE Plasma widget.
import "../../plasma/org.corico.claudito/contents/ui"
import "../../plasma/org.corico.claudito/contents/code/strings.js" as S
import "../../plasma/org.corico.claudito/contents/code/hats.js" as Hats

// Claudito on the Windows desktop: a frameless, transparent window that only
// shows the buddy and its caption. Drag it anywhere, click to poke it,
// right-click for the menu. The state logic mirrors plasma/.../main.qml.
Window {
  id: win

  readonly property int p: backend.pixelSize
  readonly property int captionArea: 46

  width: Math.max(60 * p, 200)
  height: 50 * p + captionArea
  minimumWidth: width; maximumWidth: width
  minimumHeight: height; maximumHeight: height
  visible: false   // claudito.pyw restores it
  title: "Claudito"
  color: "transparent"
  flags: Qt.FramelessWindowHint | Qt.Tool | Qt.NoDropShadowWindowHint
         | (backend.onTop ? Qt.WindowStaysOnTopHint : 0)

  // Raw state from the hook.
  property string rawMode: "sleep"
  property string tool: ""
  property string detail: ""
  property string project: ""
  property real eventTs: 0
  property bool haveData: false

  // What is shown.
  property string mode: "sleep"
  property string hat: "nightcap"
  property real now: Date.now() / 1000
  property real thinkingSince: 0

  readonly property var toolModes: ["build", "terminal", "search", "explore", "lead", "plan", "create", "work"]

  readonly property string label: {
    var d = detail
    switch (mode) {
    case "wake": return S.t("wake")
    case "thinking": return S.t("thinking")
    case "build": return d ? S.t("build").arg(d) : S.t("buildPlain")
    case "terminal": return d ? S.t("terminal").arg(d) : S.t("terminalPlain")
    case "search": return d ? S.t("search").arg(d) : S.t("searchPlain")
    case "explore": return d ? S.t("explore").arg(d) : S.t("explorePlain")
    case "lead": return d ? S.t("lead").arg(d) : S.t("leadPlain")
    case "plan": return S.t("plan")
    case "create": return d ? S.t("create").arg(d) : S.t("createPlain")
    case "work": return tool ? S.t("work").arg(tool) : S.t("workPlain")
    case "waiting": return S.t("waiting")
    case "oops": return S.t("oops")
    case "done": return S.t("done")
    case "idle": return S.t("idle")
    default: return S.t("sleep")
    }
  }

  // Tell the tray icon what Claudito is doing.
  Binding { target: backend; property: "activity"; value: win.label }
  Binding { target: backend; property: "mode"; value: win.mode }

  // ---------- Reading the state file ----------
  Connections {
    target: backend
    function onStateChanged() { win.readState(backend.stateText) }
  }
  Component.onCompleted: readState(backend.stateText)

  function readState(text) {
    if (!text) { haveData = false; return }
    try {
      var s = JSON.parse(text)
      var best = null
      for (var id in s.sessions) {
        var v = s.sessions[id]
        if (!best || v.ts > best.ts) best = v
      }
      if (!best) { haveData = false; return }
      haveData = true
      if (best.ts !== eventTs) {
        eventTs = best.ts
        tool = best.tool || ""
        detail = best.detail || ""
        project = best.project || ""
        rawMode = best.mode || "idle"
      }
    } catch (e) {
      // Half-written file: try again on the next poll.
    }
  }

  Timer {
    interval: 500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: { win.now = Date.now() / 1000; win.update() }
  }

  onRawModeChanged: update()
  onEventTsChanged: update()

  function update() {
    var age = now - eventTs
    var next
    if (!haveData) next = "sleep"
    else if (rawMode === "done") next = age < 6 ? "done" : age < 600 ? "idle" : "sleep"
    else if (rawMode === "wake") next = age < 3 ? "wake" : age < 600 ? "idle" : "sleep"
    else if (rawMode === "oops") next = age < 3 ? "oops" : "thinking"
    else if (rawMode === "sleep") next = "sleep"
    else if (rawMode === "waiting") next = "waiting"
    // A tool that never reported back (Claude Code closed mid-task).
    else if (age > 900) next = "sleep"
    else next = rawMode

    // Short "thinking" gaps between tools keep the current hat on.
    if (next === "thinking" && toolModes.indexOf(mode) >= 0 && age < 1.5) return
    if (next === mode) return
    mode = next
    if (mode !== "waiting" && mode !== "oops") hat = Hats.hatFor(mode)
  }

  // ---------- The buddy ----------
  Character {
    id: buddy
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    width: 60 * win.p
    height: 50 * win.p
    mode: win.mode
    hat: win.hat

    SequentialAnimation {
      id: poke
      NumberAnimation { target: buddy; property: "scale"; to: 1.12; duration: 120; easing.type: Easing.OutQuad }
      NumberAnimation { target: buddy; property: "scale"; to: 1; duration: 380; easing.type: Easing.OutElastic }
    }
  }

  Rectangle {
    id: caption
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: buddy.bottom
    anchors.topMargin: 2
    width: Math.min(win.width, Math.max(captionText.implicitWidth, projectText.visible ? projectText.implicitWidth : 0) + 24)
    height: captionCol.implicitHeight + 8
    radius: Math.min(height / 2, 14)
    color: Qt.rgba(0, 0, 0, 0.55)

    Column {
      id: captionCol
      anchors.centerIn: parent
      width: parent.width - 24

      Text {
        id: captionText
        width: parent.width
        text: win.label
        color: "white"
        font.bold: true
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideMiddle
      }
      Text {
        id: projectText
        visible: win.project !== "" && win.mode !== "sleep"
        width: parent.width
        text: win.project
        color: "white"
        opacity: 0.75
        font.pixelSize: 11
        horizontalAlignment: Text.AlignHCenter
        elide: Text.ElideMiddle
      }
    }
  }

  // Drag to move (Windows moves the window itself), click to poke,
  // right-click for the tray menu.
  MouseArea {
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    property point pressPos
    property bool moved: false

    onPressed: function(mouse) {
      pressPos = Qt.point(mouse.x, mouse.y)
      moved = false
    }
    onPositionChanged: function(mouse) {
      if (moved || !(mouse.buttons & Qt.LeftButton)) return
      if (Math.abs(mouse.x - pressPos.x) + Math.abs(mouse.y - pressPos.y) > 4) {
        moved = true
        win.startSystemMove()
      }
    }
    onClicked: function(mouse) {
      if (mouse.button === Qt.RightButton) backend.showMenu()
      else if (!moved) poke.restart()
    }
  }
}
