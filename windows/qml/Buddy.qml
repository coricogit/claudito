import QtQuick
import QtQuick.Window

// The same Character.qml, strings and hats as the KDE Plasma widget.
import "../../plasma/org.corico.claudito/contents/ui"
import "../../plasma/org.corico.claudito/contents/code/strings.js" as S
import "../../plasma/org.corico.claudito/contents/code/hats.js" as Hats

// Claudito on the Windows desktop: a frameless, transparent window that only
// shows the buddy and its caption. Drag it anywhere, click to poke it,
// right-click for the menu.
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

  // What is shown: windows/activity.py picks the session and its mode.
  property string mode: "sleep"
  property string hat: "nightcap"
  property string tool: ""
  property string detail: ""
  property string project: ""

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

  // ---------- What Claude is doing ----------
  Connections {
    target: backend
    function onViewChanged() { win.readView() }
  }
  Component.onCompleted: readView()

  function readView() {
    var v = JSON.parse(backend.viewText)
    tool = v.tool
    detail = v.detail
    project = v.project
    if (v.mode === mode) return
    mode = v.mode
    if (mode !== "waiting" && mode !== "oops") hat = Hats.hatFor(mode)
  }

  // ---------- The buddy ----------
  Character {
    id: buddy
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: parent.top
    width: 60 * win.p
    height: 50 * win.p
    visible: win.visible   // don't animate while hidden
    mode: win.mode
    hat: win.hat
    seasonHat: backend.seasonHat
    seasonOutfit: backend.seasonOutfit

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
