import QtQuick
import QtQuick.Effects

// Find on this page: every match marked, the current one brighter; Enter for
// the next, Shift+Enter for the one before, Esc to put it away.
Item {
  id: bar
  // (Closed as another profile opens: Overlays.js.)
  readonly property bool closesForSwitch: true

  property var theme: null
  property var editor: null
  property bool shown: false
  property int count: 0
  property int current: -1

  signal done()

  width: 380
  height: 44
  visible: opacity > 0
  opacity: shown ? 1 : 0
  Behavior on opacity { NumberAnimation { duration: 120 } }

  function open() {
    shown = true
    field.focusField()
    refresh()
  }

  function close() {
    shown = false
    if (editor) editor.clearFind()
    count = 0
    current = -1
    done()
  }

  function toggle() { if (shown) close(); else open() }
  // Closed, and what was looked for gone (another profile's opened).
  function reset() {
    if (shown) close()
    field.text = ""
  }

  // Opens with text already in it (a search on the shelf led here).
  function openWith(text) {
    shown = true
    field.text = text
    refresh()
  }

  function refresh() {
    if (!shown || !editor) return
    count = editor.find(field.text)
    current = count > 0 ? editor.showMatch(0) : -1
  }

  function step(delta) {
    if (count === 0) return
    current = editor.showMatch(current + delta)
  }

  Rectangle {
    id: plate
    anchors.fill: parent
    radius: height / 2
    color: bar.theme.surface
    border.width: 1
    border.color: bar.theme.line
    visible: false
  }
  MultiEffect {
    source: plate
    anchors.fill: plate
    shadowEnabled: true
    shadowColor: bar.theme.shadow
    shadowBlur: 0.8
    shadowVerticalOffset: 5
    autoPaddingEnabled: true
  }

  Row {
    anchors.fill: parent
    anchors.leftMargin: 6
    anchors.rightMargin: 6
    spacing: 4
    Field {
      id: field
      theme: bar.theme
      width: 210
      height: 32
      anchors.verticalCenter: parent.verticalCenter
      icon: bar.theme.icons.search
      placeholder: "Find on this page"
      color: "transparent"
      border.width: 0
      onEdited: bar.refresh()
      onAccepted: bar.step(1)
      onEscaped: bar.close()
      input.Keys.onReturnPressed: function(e) { bar.step((e.modifiers & Qt.ShiftModifier) ? -1 : 1) }
    }
    Text {
      textFormat: Text.PlainText
      width: 58
      anchors.verticalCenter: parent.verticalCenter
      horizontalAlignment: Text.AlignRight
      text: field.text === "" ? "" : bar.count === 0 ? "None" : (bar.current + 1) + " of " + bar.count
      font.family: bar.theme.uiFont
      font.pixelSize: 12
      color: bar.theme.muted
    }
    IconButton { theme: bar.theme; icon: bar.theme.icons.up; size: 30; tip: "Previous  Shift+Enter"; active: bar.count > 0; onClicked: bar.step(-1); anchors.verticalCenter: parent.verticalCenter }
    IconButton { theme: bar.theme; icon: bar.theme.icons.down; size: 30; tip: "Next  Enter"; active: bar.count > 0; onClicked: bar.step(1); anchors.verticalCenter: parent.verticalCenter }
    IconButton { theme: bar.theme; icon: bar.theme.icons.close; size: 30; tip: "Close  Esc"; onClicked: bar.close(); anchors.verticalCenter: parent.verticalCenter }
  }
}
