import QtQuick

// A one-line text field with a placeholder.
Rectangle {
  id: field

  property var theme: null
  property alias text: input.text
  property alias input: input
  property string placeholder: ""
  property string icon: ""
  property int maximumLength: 200
  property int fontSize: 14

  signal accepted()
  signal escaped()
  signal edited(string text)
  // ↑ and ↓ (a list under the field picks with them).
  signal upPressed()
  signal downPressed()
  // Clicked (as well as the cursor put where it was clicked).
  signal tapped()

  implicitWidth: 240
  implicitHeight: 34
  radius: 9
  color: theme.dark ? Qt.alpha("#000000", 0.18) : Qt.alpha("#ffffff", 0.6)
  border.width: input.activeFocus ? 1.5 : 1
  border.color: input.activeFocus ? Qt.alpha(theme.accent, 0.85) : theme.line

  function focusField() { input.forceActiveFocus(); input.selectAll() }

  Icon {
    id: glyph
    visible: field.icon !== ""
    theme: field.theme
    text: field.icon
    size: 15
    color: field.theme.muted
    x: 10
    anchors.verticalCenter: parent.verticalCenter
  }

  TextInput {
    id: input
    anchors.left: glyph.visible ? glyph.right : parent.left
    anchors.leftMargin: glyph.visible ? 8 : 11
    anchors.right: parent.right
    anchors.rightMargin: 11
    anchors.verticalCenter: parent.verticalCenter
    font.family: field.theme.uiFont
    font.pixelSize: field.fontSize
    color: field.theme.text
    selectionColor: Qt.alpha(field.theme.accent, 0.4)
    selectedTextColor: field.theme.text
    selectByMouse: true
    clip: true
    maximumLength: field.maximumLength
    onAccepted: field.accepted()
    onTextEdited: field.edited(text)
    Keys.onEscapePressed: function(e) { e.accepted = true; field.escaped() }
    Keys.onUpPressed: function(e) { e.accepted = true; field.upPressed() }
    Keys.onDownPressed: function(e) { e.accepted = true; field.downPressed() }
    TapHandler { onTapped: field.tapped() }

    Text {
      textFormat: Text.PlainText
      visible: input.text === "" && !input.inputMethodComposing
      text: field.placeholder
      font: input.font
      color: field.theme.faint
      anchors.verticalCenter: parent.verticalCenter
    }
  }
}
