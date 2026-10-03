import QtQuick
import QtQuick.Controls
import "../Contacts.js" as Contacts

// A person named on a page ("@Sam Rivera"), clicked: their card. A number
// or an email copies with a click; Email opens your mail app; Open in People
// is where they're changed.
Pop {
  id: pop

  property var workspace: null
  property string personId: ""
  readonly property var person: { var r = workspace ? workspace.contactsRevision : 0; return workspace && personId ? workspace.contactById(personId) : null }

  signal copied(string what)
  signal emailRequested(string email)
  signal peopleRequested(string id)

  focus: false
  width: 320
  padding: 14

  function openAt(id, anchor, x, y) {
    personId = id
    var p = anchor ? anchor.mapToItem(parent, x, y + 18) : Qt.point((parent.width - width) / 2, 120)
    pop.x = Math.max(8, Math.min(parent.width - width - 8, p.x - 20))
    pop.y = Math.max(8, Math.min(parent.height - 260, p.y))
    open()
  }

  component Way: Rectangle {
    id: way
    property string icon: ""
    property string value: ""
    property string label: ""
    property bool email: false
    width: parent.width
    height: 34
    radius: 7
    color: wayHover.hovered ? pop.theme.hover : "transparent"
    Text {
      x: 8
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: way.icon
      font.family: pop.theme.iconFont
      font.pixelSize: 14
      color: pop.theme.muted
    }
    Column {
      x: 32
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - x - (way.email ? 70 : 40)
      Text {
        width: parent.width
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: way.value
        font.family: pop.theme.uiFont
        font.pixelSize: 13
        font.features: { "tnum": 1 }
        color: pop.theme.text
      }
    }
    Text {
      anchors.right: tools.left
      anchors.rightMargin: 6
      anchors.verticalCenter: parent.verticalCenter
      visible: !wayHover.hovered
      textFormat: Text.PlainText
      text: way.label
      font.family: pop.theme.uiFont
      font.pixelSize: 11
      color: pop.theme.muted
    }
    Row {
      id: tools
      anchors.right: parent.right
      anchors.verticalCenter: parent.verticalCenter
      IconButton {
        objectName: "contactPopEmail"
        visible: way.email
        theme: pop.theme; icon: pop.theme.icons.mail; size: 28; iconSize: 14; tip: "Email them"
        onClicked: { pop.emailRequested(way.value); pop.close() }
      }
      IconButton {
        objectName: "contactPopCopy"
        theme: pop.theme; icon: pop.theme.icons.copy; size: 28; iconSize: 14; tip: "Copy it"
        onClicked: pop.copied(way.value)
      }
    }
    HoverHandler { id: wayHover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
      gesturePolicy: TapHandler.ReleaseWithinBounds
      onTapped: function(p) { if (!tools.contains(tools.mapFromItem(way, p.position.x, p.position.y))) pop.copied(way.value) }
    }
  }

  contentItem: Column {
    spacing: 8
    Row {
      spacing: 12
      Avatar { theme: pop.theme; person: pop.person; size: 42; visible: pop.person !== null }
      Column {
        anchors.verticalCenter: parent.verticalCenter
        width: pop.width - pop.padding * 2 - 54
        Text {
          objectName: "contactPopName"
          width: parent.width
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: pop.person ? Contacts.nameOf(pop.person) : "Not in People any more"
          font.family: pop.theme.uiFont
          font.pixelSize: 16
          font.weight: Font.DemiBold
          color: pop.theme.text
        }
        Text {
          visible: text !== ""
          width: parent.width
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: pop.person && (pop.person.title || pop.person.company) ? Contacts.subtitle(pop.person) : ""
          font.family: pop.theme.uiFont
          font.pixelSize: 12
          color: pop.theme.muted
        }
      }
    }
    Column {
      width: parent.width
      spacing: 0
      Repeater {
        model: pop.person ? pop.person.phones : []
        delegate: Way { required property var modelData; objectName: "contactPopPhone"; icon: pop.theme.icons.phone; value: modelData.value; label: modelData.label }
      }
      Repeater {
        model: pop.person ? pop.person.emails : []
        delegate: Way { required property var modelData; objectName: "contactPopMail"; icon: pop.theme.icons.mail; value: modelData.value; label: modelData.label; email: true }
      }
    }
    Rectangle { width: parent.width; height: 1; color: pop.theme.line }
    MenuRow {
      objectName: "contactPopPeople"
      width: parent.width
      theme: pop.theme
      icon: pop.theme.icons.contacts
      text: pop.person ? "Open in People" : "Open People"
      onClicked: { pop.close(); pop.peopleRequested(pop.person ? pop.personId : "") }
    }
  }
}
