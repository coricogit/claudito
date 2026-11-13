import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

import "../code/strings.js" as S
import "../code/hats.js" as Hats

// Claudito: Claude Code as a little desktop buddy. The claudito-hook script
// (run by Claude Code hooks) writes what Claude is doing to
// $XDG_RUNTIME_DIR/claudito/state.json; this widget polls it and animates.
PlasmoidItem {
  id: root

  Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground | PlasmaCore.Types.ConfigurableBackground
  preferredRepresentation: Plasmoid.formFactor === PlasmaCore.Types.Planar ? fullRepresentation : compactRepresentation
  Plasmoid.icon: "face-smile"

  toolTipMainText: "Claudito"
  toolTipSubText: label

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

  // ---------- Reading the state file ----------
  P5Support.DataSource {
    id: reader
    engine: "executable"
    interval: 500
    readonly property string cmd: "cat \"${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/claudito/state.json\" 2>/dev/null"
    connectedSources: [cmd]
    onNewData: function(source, data) { root.readState(data.stdout || "") }
  }

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

  // Ticks the clock and recomputes the shown mode.
  Timer {
    interval: 500
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: { root.now = Date.now() / 1000; root.update() }
  }

  onRawModeChanged: update()
  onEventTsChanged: update()

  property real thinkingSince: 0

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

  // ---------- On the desktop ----------
  fullRepresentation: Item {
    Layout.minimumWidth: Kirigami.Units.gridUnit * 5
    Layout.minimumHeight: Kirigami.Units.gridUnit * 7
    Layout.preferredWidth: Kirigami.Units.gridUnit * 9
    Layout.preferredHeight: Kirigami.Units.gridUnit * 12

    Character {
      id: buddy
      anchors.left: parent.left
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.bottom: caption.top
      mode: root.mode
      hat: root.hat

      MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: poke.restart()
      }
      SequentialAnimation {
        id: poke
        NumberAnimation { target: buddy; property: "scale"; to: 1.12; duration: 120; easing.type: Easing.OutQuad }
        NumberAnimation { target: buddy; property: "scale"; to: 1; duration: 380; easing.type: Easing.OutElastic }
      }
    }

    Rectangle {
      id: caption
      anchors.horizontalCenter: parent.horizontalCenter
      anchors.bottom: parent.bottom
      width: Math.min(parent.width, captionText.implicitWidth + Kirigami.Units.largeSpacing * 2)
      height: captionCol.implicitHeight + Kirigami.Units.smallSpacing * 2
      radius: height / 2
      color: Qt.rgba(0, 0, 0, 0.45)

      Column {
        id: captionCol
        anchors.centerIn: parent
        width: parent.width - Kirigami.Units.largeSpacing * 2

        PlasmaComponents.Label {
          id: captionText
          width: parent.width
          text: root.label
          color: "white"
          font.bold: true
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideMiddle
        }
        PlasmaComponents.Label {
          visible: root.project !== "" && root.mode !== "sleep"
          width: parent.width
          text: root.project
          color: "white"
          opacity: 0.7
          font: Kirigami.Theme.smallFont
          horizontalAlignment: Text.AlignHCenter
          elide: Text.ElideMiddle
        }
      }
    }
  }

  // ---------- In a panel ----------
  compactRepresentation: Character {
    mode: root.mode
    hat: root.hat
    MouseArea { anchors.fill: parent; onClicked: root.expanded = !root.expanded }
  }
}
