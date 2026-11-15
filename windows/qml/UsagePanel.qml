import QtQuick
import QtQuick.Window
import QtQuick.Layouts
import QtQuick.Controls

// MiniClaudito and the strings come from the Plasma usage widget.
import "../../plasma/org.corico.claudito.usage/contents/ui"
import "../../plasma/org.corico.claudito.usage/contents/code/strings.js" as S

// Claude usage panel, opened from the tray icon: account, plan limits, token
// history and the projects and models you use most. Same layout as the Plasma
// panel (plasma/org.corico.claudito.usage/contents/ui/main.qml), without KDE
// parts and without the live session. Plan limits come from Claude Code's
// status line, which the terminal runs but the Code tab of the Claude desktop
// app does not, so they only show after a terminal session has reported them.
Window {
  id: root

  width: 380
  height: 600
  visible: false
  title: S.t("title")
  color: "transparent"
  flags: Qt.Tool | Qt.FramelessWindowHint | Qt.WindowStaysOnTopHint

  // Close like a flyout when you click elsewhere.
  onActiveChanged: if (!active && visible) hide()
  onVisibleChanged: if (visible) { now = Date.now() / 1000; scroll.contentItem.contentY = 0 }

  SystemPalette { id: pal; colorGroup: SystemPalette.Active }

  readonly property color fg: pal.windowText
  readonly property color bg: pal.window
  readonly property color accent: "#EE7E55"
  readonly property color good: "#2F9E44"
  readonly property color warn: "#E67700"
  readonly property color bad: "#E03131"
  readonly property real small: 11
  readonly property int pad: 14
  readonly property bool es: Qt.locale().name.indexOf("es") === 0

  readonly property string noLimitsText: es
    ? "Los límites del plan y cuándo se reinician llegan desde Claude Code en una terminal (comando claude). Abre una sesión ahí y aparecerán; la pestaña Code de la app de escritorio no los comparte."
    : "Plan limits and reset times come from Claude Code in a terminal (the claude command). Start a session there and they'll show up; the Code tab of the Claude desktop app doesn't share them."

  property var usage: null
  property real now: Date.now() / 1000
  property bool showEmail: false
  property int period: 0   // 0 today, 1 week, 2 month

  Connections {
    target: backend
    function onUsageChanged() { root.parseUsage() }
  }
  Component.onCompleted: parseUsage()

  function parseUsage() {
    if (!backend.usageText) return
    try { usage = JSON.parse(backend.usageText) } catch (e) {}
  }

  Timer {
    interval: 1000; running: root.visible; repeat: true
    onTriggered: root.now = Date.now() / 1000
  }

  readonly property var account: usage ? usage.account || {} : {}
  readonly property var live: usage ? usage.live : null
  readonly property var limits: live ? live.limits || {} : {}
  readonly property var five: limits.five_hour || null
  readonly property var week: limits.seven_day || null
  readonly property real fivePct: five && typeof five.percent === "number" ? five.percent : -1
  readonly property real weekPct: week && typeof week.percent === "number" ? week.percent : -1
  readonly property bool liveActive: !!(live && live.updated && now - live.updated < 120)
  // The face follows what Claudito is doing (the buddy window sets backend.mode).
  readonly property string mood: {
    switch (backend.mode) {
    case "sleep": return "sleep"
    case "waiting": case "oops": return "worried"
    case "idle": case "done": case "wake": return "happy"
    default: return "focus"
    }
  }

  // ---------- Formatting (same as the Plasma widget) ----------

  function fmtTokens(n) {
    n = n || 0
    var loc = Qt.locale()
    if (n >= 1e9) return Number(n / 1e9).toLocaleString(loc, "f", 1) + " B"
    if (n >= 1e6) return Number(n / 1e6).toLocaleString(loc, "f", 1) + " M"
    if (n >= 1e3) return Number(n / 1e3).toLocaleString(loc, "f", 1) + " k"
    return Number(n).toLocaleString(loc, "f", 0)
  }

  function pctText(v) { return v < 0 ? "?" : Math.round(v) + " %" }

  function fmtDuration(sec) {
    sec = Math.max(0, Math.round(sec))
    var d = Math.floor(sec / 86400), h = Math.floor(sec % 86400 / 3600), m = Math.floor(sec % 3600 / 60)
    if (d > 0) return d + " d " + h + " h"
    if (h > 0) return h + " h " + m + " min"
    if (m > 0) return m + " min"
    return sec + " s"
  }

  function resetText(lim) {
    if (!lim || !lim.resetsAt) return lim && lim.percent === 0 ? S.t("reset") : ""
    var left = lim.resetsAt - now
    if (left <= 0) return S.t("reset")
    var d = new Date(lim.resetsAt * 1000)
    var when = d.toLocaleString(Qt.locale(), left < 86400 ? "HH:mm" : "ddd d, HH:mm")
    return S.t("resetsIn").arg(fmtDuration(left)) + " (" + when + ")"
  }

  function levelColor(v) { return v >= 80 ? bad : v >= 50 ? warn : good }

  function maskEmail(e) {
    if (!e) return ""
    var at = e.indexOf("@")
    if (at < 0) return "•••"
    return e.slice(0, Math.min(2, at)) + "•••" + e.slice(at)
  }

  // ---------- Frame ----------
  Rectangle {
    anchors.fill: parent
    radius: 10
    color: root.bg
    border.color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.18)
    clip: true

    ColumnLayout {
      anchors.fill: parent
      anchors.margins: 1
      spacing: 0

      // ---------- Header ----------
      RowLayout {
        Layout.fillWidth: true
        Layout.margins: root.pad
        spacing: 12

        MiniClaudito {
          Layout.preferredWidth: 48
          Layout.preferredHeight: 42
          mood: root.mood
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          Txt {
            text: S.t("plan").arg(String(root.account.subscriptionType || root.account.planTier || "").replace(/^./, function(c) { return c.toUpperCase() }))
            font.pixelSize: 16
            font.bold: true
            Layout.fillWidth: true
            elide: Text.ElideRight
          }
          Txt {
            text: root.showEmail ? (root.account.email || "") : root.maskEmail(root.account.email)
            font.pixelSize: root.small
            opacity: 0.75
            Layout.fillWidth: true
            elide: Text.ElideMiddle
            MouseArea {
              id: emailMouse
              anchors.fill: parent
              hoverEnabled: true
              cursorShape: Qt.PointingHandCursor
              onClicked: root.showEmail = !root.showEmail
            }
            ToolTip.visible: emailMouse.containsMouse
            ToolTip.text: S.t("showEmail")
          }
          Txt {
            visible: !!root.account.loginExpiresAt
            text: S.t("loginUntil").arg(new Date(root.account.loginExpiresAt).toLocaleDateString(Qt.locale(), "d MMM yyyy"))
            font.pixelSize: root.small
            opacity: 0.6
            Layout.fillWidth: true
            elide: Text.ElideRight
          }
        }

        ToolButton {
          text: "⟳"
          font.pixelSize: 16
          onClicked: backend.refreshUsage()
          ToolTip.visible: hovered
          ToolTip.text: S.t("refresh")
        }
        ToolButton {
          text: "✕"
          onClicked: root.hide()
        }
      }

      Sep {}

      // ---------- Body ----------
      ScrollView {
        id: scroll
        Layout.fillWidth: true
        Layout.fillHeight: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        contentWidth: availableWidth

        ColumnLayout {
          width: scroll.availableWidth
          spacing: 10

          // ---------- Limits ----------
          Section { title: S.t("limits") }

          Txt {
            visible: !root.five && !root.week
            text: root.noLimitsText
            opacity: 0.7
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
          }

          LimitRow { visible: !!root.five; label: S.t("fiveHour"); value: root.fivePct; lim: root.five }
          LimitRow { visible: !!root.week; label: S.t("week"); value: root.weekPct; lim: root.week }

          Txt {
            visible: (!!root.five || !!root.week) && !!root.live && !root.liveActive
            text: S.t("staleLimits").arg(root.live ? root.fmtDuration(root.now - root.live.updated) : "")
            font.pixelSize: root.small
            opacity: 0.6
            wrapMode: Text.Wrap
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
          }

          // ---------- Usage ----------
          Section { title: S.t("usage") }

          TabBar {
            id: tabs
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            currentIndex: root.period
            onCurrentIndexChanged: root.period = currentIndex
            TabButton { text: S.t("today") }
            TabButton { text: S.t("days7") }
            TabButton { text: S.t("days30") }
          }

          GridLayout {
            id: stats
            readonly property var pdata: root.usage && root.usage.periods ? root.usage.periods[["today", "week", "month"][root.period]] : null
            Layout.fillWidth: true
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad
            columns: 3
            rowSpacing: 6
            columnSpacing: 12

            Stat { label: S.t("output"); value: stats.pdata ? root.fmtTokens(stats.pdata.out) : "–" }
            Stat { label: S.t("input"); value: stats.pdata ? root.fmtTokens(stats.pdata.in + stats.pdata.cacheW) : "–" }
            Stat { label: S.t("cacheRead"); value: stats.pdata ? root.fmtTokens(stats.pdata.cacheR) : "–" }
            Stat { label: S.t("messages"); value: stats.pdata ? Number(stats.pdata.msgs).toLocaleString(Qt.locale(), "f", 0) : "–" }
            Stat { label: S.t("sessions"); value: stats.pdata ? String(stats.pdata.sessions) : "–" }
          }

          // Daily chart
          Txt {
            text: S.t("perDay")
            font.pixelSize: root.small
            opacity: 0.7
            Layout.leftMargin: root.pad
            Layout.topMargin: 4
          }
          Item {
            id: chart
            readonly property var days: root.usage && root.usage.daily ? root.usage.daily.slice(-14) : []
            readonly property real maxOut: Math.max.apply(null, [1].concat(days.map(function(d) { return d.out })))
            Layout.fillWidth: true
            Layout.preferredHeight: 72
            Layout.leftMargin: root.pad
            Layout.rightMargin: root.pad

            Row {
              anchors.fill: parent
              spacing: 2
              Repeater {
                model: chart.days
                Item {
                  required property var modelData
                  required property int index
                  width: (chart.width - 2 * (chart.days.length - 1)) / Math.max(1, chart.days.length)
                  height: chart.height

                  Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(2, (parent.height - 12) * modelData.out / chart.maxOut)
                    radius: 2
                    color: index === chart.days.length - 1 ? root.accent : Qt.alpha(root.accent, 0.55)
                    opacity: modelData.out > 0 ? 1 : 0.25
                  }
                  MouseArea { id: barMouse; anchors.fill: parent; hoverEnabled: true }
                  ToolTip.visible: barMouse.containsMouse
                  ToolTip.text: new Date(modelData.day + "T12:00:00").toLocaleDateString(Qt.locale(), "ddd d MMM")
                    + "\n" + S.t("output") + ": " + root.fmtTokens(modelData.out)
                    + "\n" + S.t("messages") + ": " + modelData.msgs
                }
              }
            }
          }

          Txt {
            text: S.t("projects")
            font.pixelSize: root.small
            opacity: 0.7
            Layout.leftMargin: root.pad
            Layout.topMargin: 4
          }
          ShareList { rows: root.usage && root.usage.projects ? root.usage.projects : [] }

          Txt {
            text: S.t("models")
            font.pixelSize: root.small
            opacity: 0.7
            Layout.leftMargin: root.pad
            Layout.topMargin: 4
          }
          ShareList { rows: root.usage && root.usage.models ? root.usage.models : [] }

          Button {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 4
            Layout.bottomMargin: root.pad
            text: S.t("openUsage")
            onClicked: Qt.openUrlExternally("https://claude.ai/settings/usage")
          }
        }
      }
    }
  }

  // ---------- Small building blocks ----------
  component Txt: Text {
    color: root.fg
    font.pixelSize: 13
  }

  component Sep: Rectangle {
    Layout.fillWidth: true
    Layout.preferredHeight: 1
    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
  }

  component Bar: Rectangle {
    property real value: 0   // 0..100
    property color tint: root.accent
    Layout.fillWidth: true
    Layout.preferredHeight: 6
    radius: 3
    color: Qt.rgba(root.fg.r, root.fg.g, root.fg.b, 0.12)
    Rectangle {
      width: parent.width * Math.min(100, Math.max(0, parent.value)) / 100
      height: parent.height
      radius: 3
      color: parent.tint
    }
  }

  component Section: ColumnLayout {
    id: section
    property string title
    Layout.fillWidth: true
    Layout.topMargin: 6
    spacing: 4
    Txt {
      text: section.title
      font.bold: true
      opacity: 0.85
      Layout.leftMargin: root.pad
    }
    Sep {}
  }

  component LimitRow: ColumnLayout {
    id: limitRow
    property string label
    property real value: -1
    property var lim
    Layout.fillWidth: true
    Layout.leftMargin: root.pad
    Layout.rightMargin: root.pad
    spacing: 3
    RowLayout {
      Layout.fillWidth: true
      Txt { text: limitRow.label; Layout.fillWidth: true }
      Txt { text: root.pctText(limitRow.value); font.bold: true; color: root.levelColor(limitRow.value) }
    }
    Bar { value: limitRow.value; tint: root.levelColor(limitRow.value) }
    Txt { text: root.resetText(limitRow.lim); font.pixelSize: root.small; opacity: 0.6 }
  }

  component Stat: ColumnLayout {
    id: stat
    property string label
    property string value
    spacing: 0
    Layout.fillWidth: true
    Txt { text: stat.value; font.bold: true; font.pixelSize: 16 }
    Txt { text: stat.label; font.pixelSize: root.small; opacity: 0.65 }
  }

  component ShareList: ColumnLayout {
    id: share
    property var rows: []
    readonly property real total: (rows || []).reduce(function(a, r) { return a + r.out }, 0) || 1
    Layout.fillWidth: true
    Layout.leftMargin: root.pad
    Layout.rightMargin: root.pad
    spacing: 6

    Txt {
      visible: !share.rows || share.rows.length === 0
      text: S.t("noData")
      opacity: 0.6
    }
    Repeater {
      model: share.rows
      ColumnLayout {
        required property var modelData
        Layout.fillWidth: true
        spacing: 2
        RowLayout {
          Layout.fillWidth: true
          Txt {
            text: modelData.name.replace(/^claude-/, "")
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          Txt {
            text: root.fmtTokens(modelData.out)
            opacity: 0.75
            font.pixelSize: root.small
          }
        }
        Bar { value: 100 * modelData.out / share.total; Layout.preferredHeight: 4 }
      }
    }
  }
}
