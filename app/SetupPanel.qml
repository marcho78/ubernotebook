import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// What to turn on: the Uber Notebook skill, and reminder details in
// notifications. Both off till you turn them on, here or in Settings (AI,
// and Notifications). Opens by itself once (App.qml: settings.setupShown),
// and from the strip over Pages; closed, however, it's been shown.
Popup {
  id: panel
  objectName: "setupPanel"

  property var theme: null
  // The service: settings, setSetting(), setupSeen().
  property var service: null
  readonly property var s: service ? service.settings : ({})

  function set(key, value) { if (service) service.setSetting(key, value) }

  anchors.centerIn: Overlay.overlay
  width: Math.min(460, (parent ? parent.width : 460) - 40)
  height: body.implicitHeight + 48
  modal: true
  focus: true
  padding: 0
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, panel.theme && panel.theme.dark ? 0.5 : 0.3) }

  // (The keys come here, so Esc closes it, whatever had them before.)
  onOpened: contentItem.forceActiveFocus()
  onClosed: if (service && typeof service.setupSeen === "function") service.setupSeen()

  background: Item {
    Rectangle { id: plate; anchors.fill: parent; radius: 16; color: panel.theme.surface; border.width: 1; border.color: panel.theme.line; visible: false }
    MultiEffect { source: plate; anchors.fill: plate; shadowEnabled: true; shadowColor: panel.theme.shadow; shadowBlur: 1.0; shadowVerticalOffset: 14; autoPaddingEnabled: true }
  }

  // A row: what it turns on (and a line about it), and its toggle at the right.
  component Line: Item {
    id: line
    property string label: ""
    property string note: ""
    default property alias control: slot.data
    width: parent ? parent.width : 400
    height: Math.max(52, texts.implicitHeight + 22)
    Rectangle { visible: !line.Positioner.isFirstItem; x: 16; width: parent.width - 32; height: 1; color: panel.theme.line; opacity: 0.7 }
    Column {
      id: texts
      anchors.left: parent.left
      anchors.leftMargin: 16
      anchors.right: slot.left
      anchors.rightMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      spacing: 3
      Text { textFormat: Text.PlainText; width: parent.width; text: line.label; wrapMode: Text.WordWrap; font.family: panel.theme.uiFont; font.pixelSize: 14; color: panel.theme.text }
      Text { textFormat: Text.PlainText; visible: line.note !== ""; width: parent.width; text: line.note; wrapMode: Text.WordWrap; font.family: panel.theme.uiFont; font.pixelSize: 12; color: panel.theme.muted }
    }
    Item {
      id: slot
      anchors.right: parent.right
      anchors.rightMargin: 16
      anchors.verticalCenter: parent.verticalCenter
      width: childrenRect.width
      height: childrenRect.height
    }
  }

  contentItem: FocusScope {
    focus: true
    Keys.onEscapePressed: panel.close()
    // (A click on the panel is its own, never what's under it.)
    Item { anchors.fill: parent; TapHandler { gesturePolicy: TapHandler.WithinBounds } }

    Column {
      id: body
      x: 24
      y: 24
      width: parent.width - 48
      spacing: 18

      Text {
        objectName: "setupTitle"
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: "Choose what to turn on"
        font.family: panel.theme.uiFont
        font.pixelSize: 19
        font.weight: Font.DemiBold
        color: panel.theme.text
      }

      Rectangle {
        width: parent.width
        height: rows.height
        radius: 10
        color: Qt.alpha(panel.theme.text, 0.025)
        border.width: 1
        border.color: panel.theme.line
        Column {
          id: rows
          width: parent.width
          Line {
            label: "Enable Uber Notebook skill"
            note: "For Claude Code, Codex and other agents."
            Toggle { objectName: "setupSkill"; theme: panel.theme; checked: panel.s.agentSkill === true; onToggled: function(on) { panel.set("agentSkill", on) } }
          }
          Line {
            label: "Show reminder details in notifications"
            Toggle { objectName: "setupReminders"; theme: panel.theme; checked: panel.s.reminderWords === true; onToggled: function(on) { panel.set("reminderWords", on) } }
          }
        }
      }

      Item {
        width: parent.width
        height: done.height
        TextButton {
          id: done
          objectName: "setupDone"
          anchors.right: parent.right
          theme: panel.theme
          primary: true
          text: "Done"
          onClicked: panel.close()
        }
      }
    }
  }
}
