import QtQuick
import "../Profiles.js" as Profiles

// A new profile: its name, and the folder its notes go in (suggested from
// the name until you change it, typed, or picked). Create makes it, and
// opens it; what's wrong is said under it.
Column {
  id: form

  property var theme: null
  // The service: its profiles (Profiles.qml), pickFolder().
  property var service: null
  property string createLabel: "Create profile"
  property bool cancellable: true
  property string error: ""
  property bool folderTouched: false

  signal created()
  signal cancelled()

  spacing: 6

  function suggest(name) { return Profiles.suggestFolder(service && service.profiles ? service.profiles.list : [], name) }
  function reset(name) {
    nameField.text = name || ""
    folderField.text = suggest(name || "")
    folderTouched = false
    error = ""
  }
  function focusName() { nameField.focusField() }
  function tilde(path) {
    var home = service && service.home ? service.home : ""
    return home && path.indexOf(home + "/") === 0 ? "~" + path.slice(home.length) : path
  }
  function create() {
    if (!service || !service.profiles) return
    error = service.profiles.add(nameField.text, folderField.text.trim(), true)
    if (error === "") created()
  }

  Text {
    textFormat: Text.PlainText
    text: "Name"
    font.family: form.theme.uiFont
    font.pixelSize: 12
    color: form.theme.muted
  }
  Field {
    id: nameField
    objectName: "profileName"
    theme: form.theme
    width: form.width
    placeholder: "Personal, Work, Studio…"
    maximumLength: 60
    onEdited: function(text) { if (!form.folderTouched) folderField.text = form.suggest(text); form.error = "" }
    onAccepted: form.create()
    onEscaped: if (form.cancellable) form.cancelled()
  }
  Item { width: 1; height: 4 }
  Text {
    textFormat: Text.PlainText
    text: "Where its notes go"
    font.family: form.theme.uiFont
    font.pixelSize: 12
    color: form.theme.muted
  }
  Row {
    width: form.width
    spacing: 6
    Field {
      id: folderField
      objectName: "profileFolder"
      theme: form.theme
      width: form.width - choose.width - 6
      placeholder: "~/Documents/Uber Notebook"
      maximumLength: 1000
      onEdited: { form.folderTouched = true; form.error = "" }
      onAccepted: form.create()
      onEscaped: if (form.cancellable) form.cancelled()
    }
    TextButton {
      id: choose
      objectName: "profileChoose"
      theme: form.theme
      text: "Choose…"
      anchors.verticalCenter: parent.verticalCenter
      onClicked: form.service.pickFolder("Where its notes go", function(path) {
        if (!path) return
        folderField.text = form.tilde(path)
        form.folderTouched = true
        form.error = ""
      })
    }
  }
  Text {
    objectName: "profileError"
    visible: form.error !== ""
    width: form.width
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
    text: form.error
    font.family: form.theme.uiFont
    font.pixelSize: 12
    color: form.theme.urgent
  }
  Text {
    width: form.width
    wrapMode: Text.Wrap
    textFormat: Text.PlainText
    text: "An empty folder starts fresh; one with Uber Notebook's notes in it opens them."
    font.family: form.theme.uiFont
    font.pixelSize: 11
    color: form.theme.faint
  }
  Item { width: 1; height: 6 }
  Row {
    spacing: 8
    TextButton {
      objectName: "profileCreate"
      theme: form.theme
      primary: true
      text: form.createLabel
      onClicked: form.create()
    }
    TextButton {
      visible: form.cancellable
      theme: form.theme
      text: "Cancel"
      onClicked: form.cancelled()
    }
  }
}
