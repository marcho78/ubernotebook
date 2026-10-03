import QtQuick

// The first time Omanote opens: your first profile (its name, and the folder
// its notes go in), or the demo to look around in first. Nothing's made
// anywhere until one of them is picked.
Rectangle {
  id: fr

  property var theme: null
  property var service: null

  objectName: "firstRun"
  color: theme.background

  onVisibleChanged: if (visible) { form.reset("Personal"); Qt.callLater(form.focusName) }

  // (Every click and key stays here.)
  TapHandler {}
  Keys.onPressed: function(e) { e.accepted = true }

  Column {
    id: body
    width: Math.min(440, fr.width - 48)
    anchors.centerIn: parent
    spacing: 12

    Text {
      textFormat: Text.PlainText
      text: "Welcome to Omanote"
      font.family: fr.theme.uiFont
      font.pixelSize: 28
      font.weight: Font.DemiBold
      color: fr.theme.text
    }
    Text {
      width: parent.width
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      text: "Your notes stay on your computer, in a folder you choose. Start with a profile; make more later to keep personal, work and anything else apart."
      font.family: fr.theme.uiFont
      font.pixelSize: 14
      lineHeight: 1.2
      color: fr.theme.muted
    }
    Item { width: 1; height: 8 }
    ProfileForm {
      id: form
      width: parent.width
      theme: fr.theme
      service: fr.service
      cancellable: false
      createLabel: "Create profile"
    }
    Item { width: 1; height: 14 }
    Rectangle { width: parent.width; height: 1; color: fr.theme.line }
    Item { width: 1; height: 6 }
    Row {
      width: parent.width
      spacing: 12
      Column {
        width: parent.width - demoButton.width - 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
          textFormat: Text.PlainText
          text: "Look around first?"
          font.family: fr.theme.uiFont
          font.pixelSize: 14
          font.weight: Font.Medium
          color: fr.theme.text
        }
        Text {
          width: parent.width
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          text: "The demo is a profile of its own, full of example pages. Make yours whenever you're ready."
          font.family: fr.theme.uiFont
          font.pixelSize: 12
          color: fr.theme.muted
        }
      }
      TextButton {
        id: demoButton
        objectName: "firstRunDemo"
        anchors.verticalCenter: parent.verticalCenter
        theme: fr.theme
        text: "Explore the demo"
        onClicked: fr.service.profiles.openDemo()
      }
    }
  }
}
