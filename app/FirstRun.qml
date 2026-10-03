import QtQuick

// The first time Uber Notebook opens: your first profile (its name, and the folder
// its notes go in), the demo to look around in first, or your profiles put
// back from a backup (from another computer, say). Nothing's made anywhere
// until one of them is picked.
Rectangle {
  id: fr

  property var theme: null
  property var service: null
  // Putting a backup back: "" or "working", or what went wrong.
  property string restoring: ""

  function restore() {
    if (!service || !service.backups) return
    service.pickFile("backup", function(path) {
      if (!path) return
      fr.restoring = "working"
      fr.service.backups.restore(path, true, function(r) { fr.restoring = r.ok ? "" : r.error })
    }, service.backups.folder)
  }

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
      text: "Welcome to Uber Notebook"
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
    Item { width: 1; height: 6 }
    Row {
      width: parent.width
      spacing: 12
      Column {
        width: parent.width - restoreButton.width - 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Text {
          textFormat: Text.PlainText
          text: "Coming from another computer?"
          font.family: fr.theme.uiFont
          font.pixelSize: 14
          font.weight: Font.Medium
          color: fr.theme.text
        }
        Text {
          objectName: "firstRunRestoreNote"
          width: parent.width
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          text: fr.restoring === "working" ? "Putting your profiles back…" : fr.restoring || "Put your profiles back from a backup Uber Notebook made (Settings → Backups)."
          font.family: fr.theme.uiFont
          font.pixelSize: 12
          color: fr.restoring !== "" && fr.restoring !== "working" ? fr.theme.urgent : fr.theme.muted
        }
      }
      TextButton {
        id: restoreButton
        objectName: "firstRunRestore"
        anchors.verticalCenter: parent.verticalCenter
        theme: fr.theme
        text: "Restore a backup…"
        onClicked: if (fr.restoring !== "working") fr.restore()
      }
    }
  }
}
