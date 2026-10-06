import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// A popover: a floating panel over everything, closed by a click outside it
// or Esc.
Popup {
  id: pop

  property var theme: null
  property real radius: 12

  padding: 10
  // Always wholly inside the window, whatever button it opened from.
  margins: 12
  modal: false
  focus: true
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  enter: Transition {
    ParallelAnimation {
      NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 110 }
      NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: 140; easing.type: Easing.OutCubic }
    }
  }
  exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90 } }

  background: Item {
    // (A click on it is its own: under its contents, this takes any its
    // choices don't take for themselves, so none reaches what's under it
    // on the page, a link or a bookmark's card there included.)
    MouseArea { objectName: "popCatch"; anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true; cursorShape: Qt.ArrowCursor }
    Rectangle {
      id: plate
      anchors.fill: parent
      radius: pop.radius
      color: pop.theme.surface
      border.width: 1
      border.color: pop.theme.line
      visible: false
    }
    MultiEffect {
      source: plate
      anchors.fill: plate
      shadowEnabled: true
      shadowColor: pop.theme.shadow
      shadowBlur: 0.9
      shadowVerticalOffset: 6
      autoPaddingEnabled: true
    }
  }
}
