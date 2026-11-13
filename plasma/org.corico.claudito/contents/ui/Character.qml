import QtQuick
import QtQuick.Shapes

import "../code/hats.js" as Hats

// Claudito: a little bean that wears a different hat for each kind of work.
// Everything is laid out on a 100 x 120 stage and scaled to fit, so shapes stay sharp.
Item {
  id: root

  // idle, wake, thinking, build, terminal, search, explore, lead, plan,
  // create, work, waiting, oops, done, sleep
  property string mode: "idle"
  // The hat stays on while waiting or after an error, so it is separate from mode.
  property string hat: hatFor(mode)

  readonly property color bodyColor: "#E8835F"
  readonly property color bodyDark: "#C4613F"
  readonly property color ink: "#2B1D16"
  readonly property real u: Math.min(width / 100, height / 120)

  readonly property bool busy: ["build", "terminal", "search", "explore", "lead", "plan", "create", "work"].indexOf(mode) >= 0

  function hatFor(m) { return Hats.hatFor(m) }

  // The hat drops on with a bounce whenever it changes.
  property string shownHat: ""
  onHatChanged: if (hat !== shownHat) hatSwap.restart()
  Component.onCompleted: shownHat = hat

  SequentialAnimation {
    id: hatSwap
    NumberAnimation { target: hatItem; property: "dropY"; to: -60; duration: shownHat ? 160 : 0; easing.type: Easing.InQuad }
    ScriptAction { script: root.shownHat = root.hat }
    NumberAnimation { target: hatItem; property: "dropY"; from: -60; to: 0; duration: 420; easing.type: Easing.OutBounce }
  }

  Item {
    id: stage
    width: 100
    height: 120
    scale: root.u
    transformOrigin: Item.TopLeft
    x: (root.width - 100 * root.u) / 2
    y: (root.height - 120 * root.u) / 2

    // ---------- Shadow ----------
    Rectangle {
      x: 50 - width / 2
      y: 105
      width: 50 * (1 - body.hop / 60)
      height: 7
      radius: height / 2
      color: "#000000"
      opacity: 0.18
    }

    // ---------- Body (everything that bobs) ----------
    Item {
      id: body
      width: 100
      height: 120
      property real hop: 0       // jump height, up is positive
      property real sway: 0      // degrees
      property real breathe: 1
      y: -hop
      rotation: sway
      transformOrigin: Item.Bottom

      // Feet
      Repeater {
        model: 2
        Rectangle {
          required property int index
          property real lift: index === 0 ? feet.left : feet.right
          x: index === 0 ? 30 : 56
          y: 96 - lift
          width: 14
          height: 8
          radius: 4
          color: root.bodyDark
        }
      }
      QtObject { id: feet; property real left: 0; property real right: 0 }

      // Arms (behind the body edge)
      Rectangle {
        id: leftArm
        x: 12; y: 70
        width: 14; height: 7; radius: 3.5
        color: root.bodyDark
        transformOrigin: Item.Right
        rotation: arms.left
      }
      Rectangle {
        id: rightArm
        x: 74; y: 70
        width: 14; height: 7; radius: 3.5
        color: root.bodyDark
        transformOrigin: Item.Left
        rotation: arms.right
      }
      QtObject { id: arms; property real left: 20; property real right: -20 }

      // Bean
      Rectangle {
        id: bean
        x: 20; y: 100 - 62 * body.breathe
        width: 60; height: 62 * body.breathe
        radius: 28
        color: root.bodyColor
        border.color: root.bodyDark
        border.width: 1.5
        Rectangle {  // belly highlight
          x: 14; y: parent.height * 0.55
          width: 32; height: parent.height * 0.32
          radius: height / 2
          color: "#F4A989"
          opacity: 0.6
        }
      }

      // Face
      Item {
        id: face
        x: 20; y: bean.y
        width: 60; height: 40
        property real lookX: 0
        property real lookY: 0

        // Eyes
        Repeater {
          model: 2
          Item {
            required property int index
            x: (index === 0 ? 16 : 37) + face.lookX
            y: 18 + face.lookY
            width: 7; height: 9

            Rectangle {   // open eye
              visible: !root.eyesClosed
              anchors.centerIn: parent
              width: 7
              height: 9 * eyes.open
              radius: 3.5
              color: root.ink
              Rectangle { x: 1.5; y: 1.2; width: 2.4; height: 2.4; radius: 1.2; color: "white"; visible: eyes.open > 0.5 }
            }
            Rectangle {   // closed eye
              visible: root.eyesClosed
              anchors.centerIn: parent
              width: 7; height: 1.8; radius: 0.9
              color: root.ink
            }
          }
        }
        QtObject { id: eyes; property real open: 1 }

        // Cheeks
        Rectangle { x: 9; y: 29; width: 8; height: 4.5; radius: 2.25; color: "#F06595"; opacity: 0.45 }
        Rectangle { x: 43; y: 29; width: 8; height: 4.5; radius: 2.25; color: "#F06595"; opacity: 0.45 }

        // Mouth
        Shape {
          x: 30 + face.lookX * 0.5
          y: 31 + face.lookY * 0.5
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            strokeColor: root.ink
            strokeWidth: 1.8
            capStyle: ShapePath.RoundCap
            fillColor: root.mouthOpen ? "#8B2E2E" : "transparent"
            startX: -root.mouthWidth / 2; startY: 0
            PathQuad { x: root.mouthWidth / 2; y: 0; controlX: 0; controlY: root.mouthCurve }
            PathQuad { x: -root.mouthWidth / 2; y: 0; controlX: 0; controlY: root.mouthOpen ? -root.mouthCurve * 0.3 : root.mouthCurve }
          }
        }

        // Sweat drop when something failed
        Shape {
          visible: root.mode === "oops"
          x: 52; y: 2 + sweat.drip
          opacity: 1 - sweat.drip / 14
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            fillColor: "#74C0FC"; strokeColor: "#1c7ed6"; strokeWidth: 0.8
            startX: 0; startY: 0
            PathQuad { x: 0; y: 9; controlX: 6; controlY: 7 }
            PathQuad { x: 0; y: 0; controlX: -6; controlY: 7 }
          }
        }
        QtObject { id: sweat; property real drip: 0 }
      }

      // ---------- Hat ----------
      Item {
        id: hatItem
        property real dropY: 0
        x: 15; y: bean.y - 30 + dropY
        width: 70; height: 42
        rotation: root.shownHat === "beret" ? -8 : root.shownHat === "nightcap" ? 6 : 0
        transformOrigin: Item.Bottom
        opacity: dropY < -40 ? 0 : 1

        Image {
          anchors.fill: parent
          visible: root.shownHat !== ""
          source: root.shownHat ? Qt.resolvedUrl("../images/" + root.shownHat + ".svg") : ""
          sourceSize.width: 420
          sourceSize.height: 252
          smooth: true
        }

        // Propeller on the thinking beanie
        Image {
          visible: root.shownHat === "beanie"
          x: 35 - 13; y: 1
          width: 26; height: 6.5
          source: Qt.resolvedUrl("../images/propeller.svg")
          sourceSize.width: 160
          sourceSize.height: 40
          transform: Scale { origin.x: 13; xScale: Math.cos(prop.angle * Math.PI / 180) }
        }
        QtObject { id: prop; property real angle: 0 }

        // Miner's lamp beam
        Shape {
          visible: root.shownHat === "miner"
          x: 35; y: 18
          opacity: beam.glow
          preferredRendererType: Shape.CurveRenderer
          ShapePath {
            strokeColor: "transparent"
            fillGradient: LinearGradient {
              x1: 0; y1: 0; x2: 45; y2: 0
              GradientStop { position: 0; color: "#ccFFF3BF" }
              GradientStop { position: 1; color: "#00FFF3BF" }
            }
            startX: 0; startY: -2
            PathLine { x: 45; y: -16 }
            PathLine { x: 45; y: 14 }
            PathLine { x: 0; y: 2 }
          }
        }
        QtObject { id: beam; property real glow: 0.8 }
      }

      // ---------- Props ----------
      // Hammer for build
      Item {
        visible: root.mode === "build"
        x: 86; y: 72
        rotation: arms.right * 1.6 - 30
        transformOrigin: Item.BottomLeft
        Rectangle { x: -1; y: -14; width: 3; height: 16; radius: 1; color: "#8B5E3C" }
        Rectangle { x: -5; y: -19; width: 11; height: 6; radius: 1.5; color: "#868E96"; border.color: "#495057"; border.width: 0.8 }
      }

      // Magnifier for search
      Item {
        visible: root.mode === "search"
        x: 82 + face.lookX * 2; y: 60
        Rectangle { x: 3; y: 9; width: 3; height: 11; radius: 1.5; color: "#6B4226"; rotation: -35 }
        Rectangle {
          width: 13; height: 13; radius: 6.5
          color: "#55D0EBFF"
          border.color: "#495057"; border.width: 2
        }
      }

      // Pointing paper for lead / brush for create
      Rectangle {
        visible: root.mode === "create"
        x: 86; y: 56; width: 3; height: 16; radius: 1.5
        color: "#8B5E3C"
        rotation: arms.right
        transformOrigin: Item.Bottom
        Rectangle { x: -1.5; y: -5; width: 6; height: 7; radius: 3; color: "#4C6EF5" }
      }
    }

    // ---------- Floating bits (don't bob with the body) ----------
    // Thought dots
    Row {
      visible: root.mode === "thinking"
      x: 72; y: 12
      spacing: 2.5
      Repeater {
        model: 3
        Rectangle {
          required property int index
          width: 4.5; height: 4.5; radius: 2.25
          color: "#868E96"
          opacity: dots.step % 4 > index ? 1 : 0.2
        }
      }
    }
    QtObject { id: dots; property int step: 0 }

    // Exclamation bubble while waiting for the user
    Rectangle {
      visible: root.mode === "waiting"
      x: 74; y: 4
      width: 16; height: 18; radius: 8
      color: "#FFD43B"
      border.color: "#E67700"; border.width: 1.2
      scale: bubble.pulse
      Text { anchors.centerIn: parent; text: "!"; font.pixelSize: 13; font.bold: true; color: "#5c3d00" }
    }
    QtObject { id: bubble; property real pulse: 1 }

    // Zzz
    Repeater {
      model: 3
      Text {
        required property int index
        visible: root.mode === "sleep"
        property real t: (zzz.t + index / 3) % 1
        x: 70 + t * 18
        y: 30 - t * 26
        opacity: Math.sin(t * Math.PI)
        text: "z"
        font.pixelSize: 7 + t * 7
        font.bold: true
        color: "#5C7CFA"
      }
    }
    QtObject { id: zzz; property real t: 0 }

    // Stars for done / plan sparkles
    Repeater {
      model: 5
      Text {
        required property int index
        visible: root.mode === "done" || root.mode === "plan"
        property real a: index * 72 + stars.t * 360
        x: 50 + Math.cos(a * Math.PI / 180) * 40 - 4
        y: 55 + Math.sin(a * Math.PI / 180) * 32 - 6
        text: "✦"
        color: ["#FFD43B", "#FF8787", "#74C0FC", "#8CE99A", "#B197FC"][index]
        font.pixelSize: 9
        opacity: root.mode === "done" ? 1 : 0.4 + 0.6 * Math.abs(Math.sin((stars.t * 4 + index) * Math.PI))
        scale: 0.8 + 0.4 * Math.abs(Math.sin((stars.t * 3 + index / 2) * Math.PI))
      }
    }
    QtObject { id: stars; property real t: 0 }
  }

  // ---------- Face state ----------
  readonly property bool eyesClosed: mode === "sleep" || (mode === "done" && body.hop > 4)
  readonly property bool mouthOpen: mode === "done" || mode === "wake" || mode === "oops"
  readonly property real mouthWidth: mode === "oops" ? 5 : mode === "terminal" || mode === "build" ? 6 : 8
  readonly property real mouthCurve: mode === "oops" ? -3
    : mode === "sleep" ? 1 : mode === "terminal" || mode === "build" || mode === "search" ? 0.5 : 4

  // ---------- Animations ----------
  // Breathing, always.
  SequentialAnimation {
    running: true; loops: Animation.Infinite
    NumberAnimation { target: body; property: "breathe"; to: root.mode === "sleep" ? 0.95 : 1.03; duration: root.mode === "sleep" ? 1800 : 1100; easing.type: Easing.InOutSine }
    NumberAnimation { target: body; property: "breathe"; to: 1; duration: root.mode === "sleep" ? 1800 : 1100; easing.type: Easing.InOutSine }
  }

  // Blinking.
  Timer {
    interval: 2600 + Math.random() * 2400
    running: !root.eyesClosed
    repeat: true
    onTriggered: { interval = 2600 + Math.random() * 2400; blink.restart() }
  }
  SequentialAnimation {
    id: blink
    NumberAnimation { target: eyes; property: "open"; to: 0.1; duration: 70 }
    NumberAnimation { target: eyes; property: "open"; to: 1; duration: 110 }
  }

  // Bounce while working; harder for build.
  SequentialAnimation {
    running: root.busy || root.mode === "wake"
    loops: Animation.Infinite
    onRunningChanged: if (!running) body.hop = 0
    NumberAnimation { target: body; property: "hop"; to: root.mode === "build" ? 5 : 2.5; duration: root.mode === "build" ? 180 : 260; easing.type: Easing.OutQuad }
    NumberAnimation { target: body; property: "hop"; to: 0; duration: root.mode === "build" ? 180 : 260; easing.type: Easing.InQuad }
  }

  // Big jumps when done.
  SequentialAnimation {
    running: root.mode === "done"
    loops: 3
    onRunningChanged: if (!running) body.hop = 0
    NumberAnimation { target: body; property: "hop"; to: 16; duration: 260; easing.type: Easing.OutQuad }
    NumberAnimation { target: body; property: "hop"; to: 0; duration: 260; easing.type: Easing.InQuad }
    PauseAnimation { duration: 120 }
  }

  // Sway: thinking / explore / idle look-around.
  SequentialAnimation {
    running: root.mode === "thinking" || root.mode === "explore" || root.mode === "plan"
    loops: Animation.Infinite
    onRunningChanged: if (!running) body.sway = 0
    NumberAnimation { target: body; property: "sway"; to: 4; duration: 700; easing.type: Easing.InOutSine }
    NumberAnimation { target: body; property: "sway"; to: -4; duration: 1400; easing.type: Easing.InOutSine }
    NumberAnimation { target: body; property: "sway"; to: 0; duration: 700; easing.type: Easing.InOutSine }
  }

  // Walking in place for explore.
  SequentialAnimation {
    running: root.mode === "explore"
    loops: Animation.Infinite
    onRunningChanged: if (!running) { feet.left = 0; feet.right = 0 }
    NumberAnimation { target: feet; property: "left"; to: 4; duration: 200 }
    NumberAnimation { target: feet; property: "left"; to: 0; duration: 200 }
    NumberAnimation { target: feet; property: "right"; to: 4; duration: 200 }
    NumberAnimation { target: feet; property: "right"; to: 0; duration: 200 }
  }

  // Arms per mode.
  states: [
    State { name: "typing"; when: root.mode === "terminal" || root.mode === "work" },
    State { name: "hammer"; when: root.mode === "build" },
    State { name: "point"; when: root.mode === "lead"
      PropertyChanges { arms.right: -70; arms.left: 20 } },
    State { name: "wave"; when: root.mode === "waiting" || root.mode === "wake" || root.mode === "create" },
    State { name: "cheer"; when: root.mode === "done"
      PropertyChanges { arms.right: -60; arms.left: 60 } },
    State { name: "rest"; when: root.mode === "sleep"
      PropertyChanges { arms.right: 30; arms.left: -30 } }
  ]
  transitions: Transition { NumberAnimation { properties: "left,right"; duration: 200 } }

  SequentialAnimation {   // typing: arms alternate quickly
    running: root.state === "typing"
    loops: Animation.Infinite
    onRunningChanged: if (!running && root.state === "") { arms.left = 20; arms.right = -20 }
    ParallelAnimation {
      NumberAnimation { target: arms; property: "left"; to: 35; duration: 90 }
      NumberAnimation { target: arms; property: "right"; to: -10; duration: 90 }
    }
    ParallelAnimation {
      NumberAnimation { target: arms; property: "left"; to: 10; duration: 90 }
      NumberAnimation { target: arms; property: "right"; to: -35; duration: 90 }
    }
  }
  SequentialAnimation {   // hammering
    running: root.state === "hammer"
    loops: Animation.Infinite
    NumberAnimation { target: arms; property: "right"; to: -60; duration: 260; easing.type: Easing.OutQuad }
    NumberAnimation { target: arms; property: "right"; to: 15; duration: 110; easing.type: Easing.InQuad }
    PauseAnimation { duration: 80 }
  }
  SequentialAnimation {   // waving
    running: root.state === "wave"
    loops: Animation.Infinite
    NumberAnimation { target: arms; property: "right"; to: -95; duration: 220 }
    NumberAnimation { target: arms; property: "right"; to: -55; duration: 220 }
  }
  Binding {   // back to rest when no arm animation is running
    when: root.state === ""
    arms.left: 20
    arms.right: -20
    restoreMode: Binding.RestoreNone
  }

  // Eyes: search sweeps, thinking looks up, others centered.
  SequentialAnimation {
    running: root.mode === "search"
    loops: Animation.Infinite
    onRunningChanged: if (!running) face.lookX = 0
    NumberAnimation { target: face; property: "lookX"; to: 3; duration: 600; easing.type: Easing.InOutSine }
    NumberAnimation { target: face; property: "lookX"; to: -3; duration: 1200; easing.type: Easing.InOutSine }
    NumberAnimation { target: face; property: "lookX"; to: 0; duration: 600; easing.type: Easing.InOutSine }
  }
  Binding { target: face; property: "lookY"; value: root.mode === "thinking" ? -3 : root.mode === "terminal" ? 2 : 0 }

  // Propeller spin, thought dots, lamp flicker, sweat, Zzz, stars.
  NumberAnimation { target: prop; property: "angle"; from: 0; to: 360; duration: 400; loops: Animation.Infinite; running: root.shownHat === "beanie" }
  Timer { interval: 350; repeat: true; running: root.mode === "thinking"; onTriggered: dots.step++ }
  SequentialAnimation {
    running: root.shownHat === "miner"; loops: Animation.Infinite
    NumberAnimation { target: beam; property: "glow"; to: 0.45; duration: 120 }
    NumberAnimation { target: beam; property: "glow"; to: 0.85; duration: 300 }
    PauseAnimation { duration: 900 }
  }
  NumberAnimation { target: sweat; property: "drip"; from: 0; to: 14; duration: 1100; loops: Animation.Infinite; running: root.mode === "oops" }
  NumberAnimation { target: zzz; property: "t"; from: 0; to: 1; duration: 3000; loops: Animation.Infinite; running: root.mode === "sleep" }
  NumberAnimation { target: stars; property: "t"; from: 0; to: 1; duration: root.mode === "done" ? 2400 : 6000; loops: Animation.Infinite; running: root.mode === "done" || root.mode === "plan" }
  SequentialAnimation {
    running: root.mode === "waiting"; loops: Animation.Infinite
    NumberAnimation { target: bubble; property: "pulse"; to: 1.18; duration: 350; easing.type: Easing.OutQuad }
    NumberAnimation { target: bubble; property: "pulse"; to: 1; duration: 350; easing.type: Easing.InQuad }
  }
}
