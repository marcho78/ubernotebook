import QtQuick
import "../Audio.js" as Audio

// The bar at the foot of a page while something records: dictation
// listening (then writing it down), an audio note recording on a page that
// isn't the one open, or a meeting. A red dot, what it's doing, the time,
// the level as you speak (when there is one); Done (or Stop), and throwing
// it away (when it can be).
Rectangle {
  id: bar

  property var theme: null
  // What it's doing ("Listening", "Recording an audio note", "Meeting").
  property string label: ""
  // Still recording (else: `busyText`, as it finishes).
  property bool listening: false
  property string busyText: ""
  property real seconds: 0
  // The last levels (0 to 1), or none.
  property var levels: []
  property string doneLabel: "Done"
  property bool cancelable: true

  signal done()
  signal canceled()

  readonly property color red: theme && theme.dark ? "#ff6b6b" : "#e5484d"

  width: row.implicitWidth + 28
  height: 48
  radius: 24
  color: theme ? theme.surface : "white"
  border.width: 1
  border.color: theme ? Qt.alpha(theme.text, 0.12) : "#dddddd"

  Row {
    id: row
    x: 16
    anchors.verticalCenter: parent.verticalCenter
    spacing: 10

    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: 10
      height: 10
      radius: 5
      color: bar.listening ? bar.red : bar.theme ? bar.theme.muted : "gray"
      SequentialAnimation on opacity {
        running: bar.visible
        loops: Animation.Infinite
        NumberAnimation { to: 0.25; duration: 650; easing.type: Easing.InOutSine }
        NumberAnimation { to: 1; duration: 650; easing.type: Easing.InOutSine }
      }
    }
    Text {
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: bar.listening ? bar.label : bar.busyText
      font.family: bar.theme ? bar.theme.uiFont : ""
      font.pixelSize: 14
      font.weight: Font.DemiBold
      color: bar.theme ? bar.theme.text : "black"
    }
    Text {
      visible: bar.listening
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: Audio.clock(bar.seconds)
      font.family: bar.theme ? bar.theme.uiFont : ""
      font.pixelSize: 13
      font.features: { "tnum": 1 }
      color: bar.theme ? bar.theme.muted : "gray"
    }
    // The level as you speak, the newest at the right.
    Item {
      visible: bar.listening && bar.levels.length > 0
      anchors.verticalCenter: parent.verticalCenter
      width: 24 * 5
      height: 22
      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Repeater {
          model: bar.levels.slice(-24)
          delegate: Rectangle {
            required property var modelData
            anchors.verticalCenter: parent ? parent.verticalCenter : undefined
            width: 3
            height: Math.max(3, 22 * modelData)
            radius: 1.5
            color: bar.red
          }
        }
      }
    }
    Rectangle {
      objectName: "recordingDone"
      visible: bar.listening
      anchors.verticalCenter: parent.verticalCenter
      width: doneText.implicitWidth + 22
      height: 30
      radius: 15
      color: doneHover.hovered ? Qt.darker(bar.theme ? bar.theme.accent : "#2456b3", 1.1) : (bar.theme ? bar.theme.accent : "#2456b3")
      Text {
        id: doneText
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: bar.doneLabel
        font.family: bar.theme ? bar.theme.uiFont : ""
        font.pixelSize: 13
        font.weight: Font.DemiBold
        color: "white"
      }
      HoverHandler { id: doneHover; cursorShape: Qt.PointingHandCursor }
      TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: bar.done() }
    }
    IconButton {
      objectName: "recordingCancel"
      visible: bar.cancelable
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme; icon: bar.theme ? bar.theme.icons.close : ""; size: 30; iconSize: 15
      tip: "Throw it away"
      onClicked: bar.canceled()
    }
  }
}
