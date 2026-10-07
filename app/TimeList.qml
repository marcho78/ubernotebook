import QtQuick
import QtQuick.Controls
import "../Dates.js" as Dates

// The times of a day, every 15 minutes, on the clock you chose ("9:00 am",
// "13:15"), under a time box while it's being written in, scrolled to its
// time: a click picks one. (Typing a time still works.)
Popup {
  id: list

  property var theme: null
  // The box's time now, in minutes (-1: none), marked and scrolled to.
  property int minutes: -1

  signal picked(int minutes)

  // (Never takes the keyboard from the box.)
  focus: false
  closePolicy: Popup.NoAutoClose
  padding: 4
  width: 132
  height: 228

  background: Rectangle {
    color: list.theme ? list.theme.surface : "white"
    radius: 8
    border.width: 1
    border.color: list.theme ? list.theme.line : "gray"
  }

  contentItem: ListView {
    id: times
    objectName: "timeList"
    clip: true
    model: 96
    boundsBehavior: Flickable.StopAtBounds
    delegate: Rectangle {
      id: option
      required property int index
      readonly property int at: index * 15
      readonly property bool here: list.minutes >= 0 && Math.floor(list.minutes / 15) === index
      objectName: "timeOption"
      width: times.width
      height: 28
      radius: 5
      color: here ? list.theme.accentSoft : optionHover.hovered ? list.theme.hover : "transparent"
      Text {
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: (list.theme && list.theme.twelveHour, Dates.clock(Math.floor(option.at / 60), option.at % 60))
        font.family: list.theme ? list.theme.uiFont : ""
        font.pixelSize: 13
        font.features: { "tnum": 1 }
        color: option.here ? list.theme.accent : list.theme.text
      }
      HoverHandler { id: optionHover; cursorShape: Qt.PointingHandCursor }
      TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: list.picked(option.at) }
    }
  }

  function scrollToTime() {
    var i = minutes >= 0 ? Math.floor(minutes / 15) : 36
    times.positionViewAtIndex(Math.max(0, i - 2), ListView.Beginning)
  }
  onOpened: scrollToTime()
  onMinutesChanged: if (opened) scrollToTime()
}
