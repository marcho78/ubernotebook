import QtQuick
import QtQuick.Controls

// A short list to pick one from (a code block's language).
Pop {
  id: pop

  property var choices: []
  property string current: ""

  signal picked(string value)

  width: 220
  height: Math.min(360, list.contentHeight + 2 * padding)
  padding: 6

  contentItem: ListView {
    id: list
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    model: pop.choices
    delegate: MenuRow {
      required property var modelData
      width: list.width
      theme: pop.theme
      text: modelData
      checked: (pop.current || pop.choices[0]) === modelData
      onClicked: { pop.close(); pop.picked(modelData) }
    }
  }
}
