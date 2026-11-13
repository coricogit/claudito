import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
import org.kde.plasma.plasma5support as P5Support
import org.kde.kirigami as Kirigami

import "../code/strings.js" as S

// Claude usage in the panel: plan limits, current Claude Code session, token
// history and account. Data comes from ~/.local/bin/claudito-usage.
PlasmoidItem {
  id: root

  property var usage: null
  property real now: Date.now() / 1000
  property bool showEmail: false
  property int period: 0   // 0 today, 1 week, 2 month

  readonly property var account: usage ? usage.account || {} : {}
  readonly property var live: usage ? usage.live : null
  readonly property var limits: live ? live.limits || {} : {}
  readonly property var five: limits.five_hour || null
  readonly property var week: limits.seven_day || null
  readonly property real fivePct: five && typeof five.percent === "number" ? five.percent : -1
  readonly property real weekPct: week && typeof week.percent === "number" ? week.percent : -1
  readonly property bool liveActive: !!(live && live.updated && now - live.updated < 120)

  Plasmoid.icon: "office-chart-bar"
  toolTipMainText: S.t("title")
  toolTipSubText: S.t("tooltip").arg(pctText(fivePct)).arg(pctText(weekPct))

  // ---------- Formatting ----------
  function pctText(v) { return v < 0 ? S.t("unknown") : Math.round(v) + " %" }

  function fmtTokens(n) {
    n = n || 0
    var loc = Qt.locale()
    if (n >= 1e9) return Number(n / 1e9).toLocaleString(loc, "f", 1) + " B"
    if (n >= 1e6) return Number(n / 1e6).toLocaleString(loc, "f", 1) + " M"
    if (n >= 1e3) return Number(n / 1e3).toLocaleString(loc, "f", 1) + " k"
    return Number(n).toLocaleString(loc, "f", 0)
  }

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
    if (left < 86400) return S.t("resetsIn").arg(fmtDuration(left))
    var d = new Date(lim.resetsAt * 1000)
    return S.t("resetsAt").arg(d.toLocaleString(Qt.locale(), "ddd d, HH:mm"))
  }

  function maskEmail(e) {
    if (!e) return ""
    var at = e.indexOf("@")
    if (at < 0) return "•••"
    return e.slice(0, Math.min(2, at)) + "•••" + e.slice(at)
  }

  function levelColor(v) {
    if (v >= 80) return Kirigami.Theme.negativeTextColor
    if (v >= 50) return Kirigami.Theme.neutralTextColor
    return Kirigami.Theme.positiveTextColor
  }

  readonly property string mood: fivePct < 0 ? "sleep" : fivePct >= 80 ? "worried" : fivePct >= 50 ? "focus" : "happy"

  // ---------- Data ----------
  P5Support.DataSource {
    id: reader
    engine: "executable"
    interval: root.expanded ? 5000 : 30000
    readonly property string cmd: "\"$HOME/.local/bin/claudito-usage\""
    connectedSources: [cmd]
    onNewData: function(source, d) {
      try { root.usage = JSON.parse(d.stdout) } catch (e) {}
    }
  }

  function refresh() {
    reader.disconnectSource(reader.cmd)
    reader.connectSource(reader.cmd)
  }

  Timer {
    interval: 1000; running: root.expanded; repeat: true
    onTriggered: root.now = Date.now() / 1000
  }
  Timer {
    interval: 30000; running: !root.expanded; repeat: true
    onTriggered: root.now = Date.now() / 1000
  }
  onExpandedChanged: if (root.expanded) { now = Date.now() / 1000; refresh() }

  // ---------- Panel ----------
  compactRepresentation: MouseArea {
    id: compact
    Layout.minimumWidth: row.implicitWidth
    Layout.preferredWidth: row.implicitWidth
    hoverEnabled: true
    onClicked: root.expanded = !root.expanded

    RowLayout {
      id: row
      anchors.fill: parent
      spacing: Kirigami.Units.smallSpacing

      MiniClaudito {
        Layout.fillHeight: true
        Layout.preferredWidth: height * 16 / 14
        mood: root.mood
      }
      PlasmaComponents.Label {
        visible: root.fivePct >= 0
        text: Math.round(root.fivePct) + "%"
        color: root.fivePct >= 80 ? Kirigami.Theme.negativeTextColor : Kirigami.Theme.textColor
        font.bold: root.fivePct >= 80
        Layout.rightMargin: Kirigami.Units.smallSpacing
      }
    }
  }

  fullRepresentation: PlasmaExtras.Representation {
    Layout.minimumWidth: Kirigami.Units.gridUnit * 22
    Layout.preferredWidth: Kirigami.Units.gridUnit * 24
    Layout.preferredHeight: Kirigami.Units.gridUnit * 34
    collapseMarginsHint: true

    header: PlasmaExtras.PlasmoidHeading {
      RowLayout {
        anchors.fill: parent
        spacing: Kirigami.Units.largeSpacing

        MiniClaudito {
          Layout.preferredWidth: Kirigami.Units.iconSizes.large
          Layout.preferredHeight: Kirigami.Units.iconSizes.large * 14 / 16
          mood: root.mood
        }

        ColumnLayout {
          Layout.fillWidth: true
          spacing: 0
          Kirigami.Heading {
            level: 3
            text: S.t("plan").arg(String(root.account.subscriptionType || root.account.planTier || "").replace(/^./, function(c) { return c.toUpperCase() }))
            Layout.fillWidth: true
            elide: Text.ElideRight
          }
          PlasmaComponents.Label {
            text: root.showEmail ? (root.account.email || "") : root.maskEmail(root.account.email)
            font: Kirigami.Theme.smallFont
            opacity: 0.75
            Layout.fillWidth: true
            elide: Text.ElideMiddle
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.showEmail = !root.showEmail
            }
            PlasmaComponents.ToolTip { text: S.t("showEmail") }
          }
          PlasmaComponents.Label {
            visible: !!root.account.loginExpiresAt
            text: S.t("loginUntil").arg(new Date(root.account.loginExpiresAt).toLocaleDateString(Qt.locale(), "d MMM yyyy"))
            font: Kirigami.Theme.smallFont
            opacity: 0.6
            Layout.fillWidth: true
            elide: Text.ElideRight
          }
        }

        PlasmaComponents.ToolButton {
          icon.name: "view-refresh"
          onClicked: root.refresh()
          PlasmaComponents.ToolTip { text: S.t("refresh") }
        }
      }
    }

    contentItem: PlasmaComponents.ScrollView {
      id: scroll
      QQC2.ScrollBar.horizontal.policy: QQC2.ScrollBar.AlwaysOff

      ColumnLayout {
        width: scroll.availableWidth
        spacing: Kirigami.Units.largeSpacing

        // ---------- Limits ----------
        Section { title: S.t("limits") }

        PlasmaComponents.Label {
          visible: !root.five && !root.week
          text: S.t("noLimits")
          opacity: 0.7
          wrapMode: Text.Wrap
          Layout.fillWidth: true
          Layout.leftMargin: Kirigami.Units.largeSpacing
        }

        LimitRow { visible: !!root.five; label: S.t("fiveHour"); value: root.fivePct; lim: root.five }
        LimitRow { visible: !!root.week; label: S.t("week"); value: root.weekPct; lim: root.week }

        PlasmaComponents.Label {
          visible: (!!root.five || !!root.week) && root.live && !root.liveActive
          text: S.t("staleLimits").arg(root.live ? root.fmtDuration(root.now - root.live.updated) : "")
          font: Kirigami.Theme.smallFont
          opacity: 0.6
          Layout.leftMargin: Kirigami.Units.largeSpacing
        }

        // ---------- Current session ----------
        Section { title: S.t("session") }

        PlasmaComponents.Label {
          visible: !root.live
          text: S.t("noSession")
          opacity: 0.7
          wrapMode: Text.Wrap
          Layout.fillWidth: true
          Layout.leftMargin: Kirigami.Units.largeSpacing
        }

        ColumnLayout {
          visible: !!root.live
          Layout.fillWidth: true
          Layout.leftMargin: Kirigami.Units.largeSpacing
          Layout.rightMargin: Kirigami.Units.largeSpacing
          spacing: Kirigami.Units.smallSpacing

          RowLayout {
            Layout.fillWidth: true
            Rectangle {
              width: Kirigami.Units.smallSpacing * 2; height: width; radius: width / 2
              color: root.liveActive ? Kirigami.Theme.positiveTextColor : Kirigami.Theme.disabledTextColor
            }
            PlasmaComponents.Label {
              text: root.live ? (root.live.sessionName || root.live.project || "") : ""
              font.bold: true
              elide: Text.ElideRight
              Layout.fillWidth: true
            }
          }
          PlasmaComponents.Label {
            text: root.live ? [root.live.model, root.live.project, root.live.version ? "v" + root.live.version : ""].filter(function(x) { return x }).join(" · ") : ""
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            elide: Text.ElideRight
            Layout.fillWidth: true
          }

          KV {
            key: S.t("context")
            value: root.live && typeof root.live.contextPercent === "number"
              ? S.t("contextOf").arg(Math.round(root.live.contextPercent)).arg(root.fmtTokens(root.live.contextSize)) : "?"
          }
          PlasmaComponents.ProgressBar {
            Layout.fillWidth: true
            from: 0; to: 100
            value: root.live && root.live.contextPercent ? root.live.contextPercent : 0
          }
          KV {
            key: S.t("duration")
            value: root.live && root.live.durationMs
              ? S.t("durationValue").arg(root.fmtDuration(root.live.durationMs / 1000)).arg(root.fmtDuration((root.live.apiDurationMs || 0) / 1000)) : "?"
          }
          KV {
            key: S.t("lines")
            value: root.live ? "+" + (root.live.linesAdded || 0) + " / −" + (root.live.linesRemoved || 0) : ""
          }
          KV {
            key: S.t("cost")
            value: root.live && typeof root.live.costUsd === "number"
              ? Number(root.live.costUsd).toLocaleString(Qt.locale(), "f", 2) + " $" : "?"
            hint: S.t("costHint")
          }
        }

        // ---------- Usage ----------
        Section { title: S.t("usage") }

        PlasmaComponents.TabBar {
          id: tabs
          Layout.fillWidth: true
          Layout.leftMargin: Kirigami.Units.largeSpacing
          Layout.rightMargin: Kirigami.Units.largeSpacing
          currentIndex: root.period
          onCurrentIndexChanged: root.period = currentIndex
          PlasmaComponents.TabButton { text: S.t("today") }
          PlasmaComponents.TabButton { text: S.t("days7") }
          PlasmaComponents.TabButton { text: S.t("days30") }
        }

        GridLayout {
          readonly property var pdata: root.usage && root.usage.periods ? root.usage.periods[["today", "week", "month"][root.period]] : null
          Layout.fillWidth: true
          Layout.leftMargin: Kirigami.Units.largeSpacing
          Layout.rightMargin: Kirigami.Units.largeSpacing
          columns: 3
          rowSpacing: Kirigami.Units.smallSpacing
          columnSpacing: Kirigami.Units.largeSpacing

          Stat { label: S.t("output"); value: parent.pdata ? root.fmtTokens(parent.pdata.out) : "–" }
          Stat { label: S.t("input"); value: parent.pdata ? root.fmtTokens(parent.pdata.in + parent.pdata.cacheW) : "–" }
          Stat { label: S.t("cacheRead"); value: parent.pdata ? root.fmtTokens(parent.pdata.cacheR) : "–" }
          Stat { label: S.t("messages"); value: parent.pdata ? Number(parent.pdata.msgs).toLocaleString(Qt.locale(), "f", 0) : "–" }
          Stat { label: S.t("sessions"); value: parent.pdata ? String(parent.pdata.sessions) : "–" }
        }

        // Daily chart
        PlasmaComponents.Label {
          text: S.t("perDay")
          font: Kirigami.Theme.smallFont
          opacity: 0.7
          Layout.leftMargin: Kirigami.Units.largeSpacing
          Layout.topMargin: Kirigami.Units.smallSpacing
        }
        Item {
          id: chart
          readonly property var days: root.usage && root.usage.daily ? root.usage.daily.slice(-14) : []
          readonly property real maxOut: Math.max.apply(null, [1].concat(days.map(function(d) { return d.out })))
          Layout.fillWidth: true
          Layout.preferredHeight: Kirigami.Units.gridUnit * 4
          Layout.leftMargin: Kirigami.Units.largeSpacing
          Layout.rightMargin: Kirigami.Units.largeSpacing

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
                  height: Math.max(2, (parent.height - Kirigami.Units.gridUnit) * modelData.out / chart.maxOut)
                  radius: 2
                  color: index === chart.days.length - 1 ? "#EE7E55" : Qt.alpha("#EE7E55", 0.55)
                  opacity: modelData.out > 0 ? 1 : 0.25
                }
                MouseArea { id: barMouse; anchors.fill: parent; hoverEnabled: true }
                PlasmaComponents.ToolTip {
                  visible: barMouse.containsMouse
                  text: new Date(modelData.day + "T12:00:00").toLocaleDateString(Qt.locale(), "ddd d MMM")
                    + "\n" + S.t("output") + ": " + root.fmtTokens(modelData.out)
                    + "\n" + S.t("messages") + ": " + modelData.msgs
                }
              }
            }
          }
        }

        // Projects
        PlasmaComponents.Label {
          text: S.t("projects")
          font: Kirigami.Theme.smallFont
          opacity: 0.7
          Layout.leftMargin: Kirigami.Units.largeSpacing
          Layout.topMargin: Kirigami.Units.smallSpacing
        }
        ShareList { rows: root.usage && root.usage.projects ? root.usage.projects : [] }

        PlasmaComponents.Label {
          text: S.t("models")
          font: Kirigami.Theme.smallFont
          opacity: 0.7
          Layout.leftMargin: Kirigami.Units.largeSpacing
          Layout.topMargin: Kirigami.Units.smallSpacing
        }
        ShareList { rows: root.usage && root.usage.models ? root.usage.models : []; isModel: true }

        PlasmaComponents.Button {
          Layout.alignment: Qt.AlignHCenter
          Layout.topMargin: Kirigami.Units.smallSpacing
          Layout.bottomMargin: Kirigami.Units.largeSpacing
          text: S.t("openUsage")
          icon.name: "internet-web-browser"
          onClicked: Qt.openUrlExternally("https://claude.ai/settings/usage")
        }
      }
    }
  }

  // ---------- Small building blocks ----------
  component Section: ColumnLayout {
    property string title
    Layout.fillWidth: true
    Layout.topMargin: Kirigami.Units.smallSpacing
    spacing: Kirigami.Units.smallSpacing
    Kirigami.Heading {
      level: 5
      text: parent.title
      opacity: 0.85
      Layout.leftMargin: Kirigami.Units.largeSpacing
    }
    Kirigami.Separator { Layout.fillWidth: true }
  }

  component LimitRow: ColumnLayout {
    property string label
    property real value: -1
    property var lim
    Layout.fillWidth: true
    Layout.leftMargin: Kirigami.Units.largeSpacing
    Layout.rightMargin: Kirigami.Units.largeSpacing
    spacing: 2
    RowLayout {
      Layout.fillWidth: true
      PlasmaComponents.Label { text: parent.parent.label; Layout.fillWidth: true }
      PlasmaComponents.Label {
        text: root.pctText(parent.parent.value)
        font.bold: true
        color: root.levelColor(parent.parent.value)
      }
    }
    PlasmaComponents.ProgressBar {
      Layout.fillWidth: true
      from: 0; to: 100
      value: Math.max(0, parent.value)
    }
    PlasmaComponents.Label {
      text: root.resetText(parent.lim)
      font: Kirigami.Theme.smallFont
      opacity: 0.6
    }
  }

  component KV: RowLayout {
    property string key
    property string value
    property string hint: ""
    Layout.fillWidth: true
    PlasmaComponents.Label { text: parent.key; opacity: 0.75; Layout.fillWidth: true }
    PlasmaComponents.Label {
      text: parent.value
      font.bold: true
      MouseArea { id: kvMouse; anchors.fill: parent; hoverEnabled: true }
      PlasmaComponents.ToolTip { visible: kvMouse.containsMouse && parent.parent.hint !== ""; text: parent.parent.hint }
    }
  }

  component Stat: ColumnLayout {
    property string label
    property string value
    spacing: 0
    Layout.fillWidth: true
    PlasmaComponents.Label { text: parent.value; font.bold: true; font.pointSize: Kirigami.Theme.defaultFont.pointSize * 1.2 }
    PlasmaComponents.Label { text: parent.label; font: Kirigami.Theme.smallFont; opacity: 0.65 }
  }

  component ShareList: ColumnLayout {
    property var rows: []
    property bool isModel: false
    readonly property real total: (rows || []).reduce(function(a, r) { return a + r.out }, 0) || 1
    Layout.fillWidth: true
    Layout.leftMargin: Kirigami.Units.largeSpacing
    Layout.rightMargin: Kirigami.Units.largeSpacing
    spacing: Kirigami.Units.smallSpacing

    PlasmaComponents.Label {
      visible: !parent.rows || parent.rows.length === 0
      text: S.t("noData")
      opacity: 0.6
    }
    Repeater {
      model: parent.rows
      ColumnLayout {
        required property var modelData
        Layout.fillWidth: true
        spacing: 1
        RowLayout {
          Layout.fillWidth: true
          PlasmaComponents.Label {
            text: modelData.name.replace(/^claude-/, "")
            elide: Text.ElideRight
            Layout.fillWidth: true
          }
          PlasmaComponents.Label {
            text: root.fmtTokens(modelData.out)
            opacity: 0.75
            font: Kirigami.Theme.smallFont
          }
        }
        Rectangle {
          Layout.fillWidth: true
          Layout.preferredHeight: 4
          radius: 2
          color: Qt.alpha(Kirigami.Theme.textColor, 0.1)
          Rectangle {
            width: parent.width * modelData.out / parent.parent.parent.total
            height: parent.height
            radius: 2
            color: "#EE7E55"
          }
        }
      }
    }
  }
}
