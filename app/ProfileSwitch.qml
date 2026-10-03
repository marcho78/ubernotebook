import QtQuick
import QtQuick.Controls

// The profile open, and a click away the others (at the top of Pages'
// sidebar, and of the shelf): each profile, a new one, the demo, and
// Manage profiles (Settings).
Rectangle {
  id: ps

  property var theme: null
  // The service: its profiles (Profiles.qml), pickFolder().
  property var service: null
  // How wide its name may get.
  property real maxName: 150
  // As wide as it's given (the sidebar's), its arrow at the end.
  property bool wide: false
  signal manageRequested()

  readonly property var profiles: service && service.profiles ? service.profiles : null
  readonly property var current: profiles ? profiles.current : null

  objectName: "profileSwitch"
  implicitWidth: row.implicitWidth + arrow.width + 22
  implicitHeight: 32
  radius: 8
  color: tap.pressed ? theme.pressed : hover.hovered || menu.opened ? theme.hover : "transparent"
  border.width: 1
  border.color: hover.hovered || menu.opened ? Qt.alpha(theme.text, 0.25) : theme.line

  function openMenu() { menu.open() }
  function initial(name) { return String(name || "?").trim().charAt(0).toUpperCase() || "?" }
  function newProfile() {
    menu.close()
    form.reset("")
    newPop.open()
    Qt.callLater(form.focusName)
  }

  Row {
    id: row
    x: 8
    anchors.verticalCenter: parent.verticalCenter
    spacing: 8
    Rectangle {
      width: 20
      height: 20
      radius: 5
      anchors.verticalCenter: parent.verticalCenter
      color: Qt.alpha(ps.theme.text, 0.1)
      Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: ps.initial(ps.current ? ps.current.name : "")
        font.family: ps.theme.uiFont
        font.pixelSize: 11
        font.weight: Font.DemiBold
        color: ps.theme.text
      }
    }
    Text {
      objectName: "profileSwitchName"
      anchors.verticalCenter: parent.verticalCenter
      width: ps.wide ? Math.min(implicitWidth, ps.width - 66) : Math.min(implicitWidth, ps.maxName)
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: ps.current ? ps.current.name : "No profile"
      font.family: ps.theme.uiFont
      font.pixelSize: 13
      font.weight: Font.Medium
      color: ps.theme.text
    }
  }
  Icon {
    id: arrow
    theme: ps.theme
    anchors.right: parent.right
    anchors.rightMargin: 9
    anchors.verticalCenter: parent.verticalCenter
    text: ps.theme.icons.down
    size: 14
    color: ps.theme.muted
  }
  HoverHandler { id: hover; cursorShape: Qt.PointingHandCursor }
  TapHandler { id: tap; onTapped: menu.open() }
  ToolTip.visible: hover.hovered && !menu.opened
  ToolTip.delay: 600
  ToolTip.text: "Switch profile"

  // The profiles.
  Pop {
    id: menu
    objectName: "profileMenu"
    theme: ps.theme
    y: ps.height + 4
    width: 300
    contentItem: Column {
      spacing: 2
      Text {
        textFormat: Text.PlainText
        leftPadding: 8
        bottomPadding: 4
        text: "Profiles"
        font.family: ps.theme.uiFont
        font.pixelSize: 12
        color: ps.theme.muted
      }
      Repeater {
        model: ps.profiles ? ps.profiles.shown : []
        delegate: MenuRow {
          required property var modelData
          objectName: "profileChoice"
          readonly property string profileId: modelData.id
          width: parent.width
          theme: ps.theme
          text: modelData.name
          hint: modelData.demo ? "demo" : ""
          checked: ps.current !== null && ps.current.id === modelData.id
          onClicked: { menu.close(); ps.profiles.use(modelData.id) }
        }
      }
      Rectangle { width: parent.width; height: 1; color: ps.theme.line }
      MenuRow {
        objectName: "profileNew"
        width: parent.width
        theme: ps.theme
        icon: ps.theme.icons.plus
        text: "New profile…"
        onClicked: ps.newProfile()
      }
      MenuRow {
        objectName: "profileDemo"
        visible: ps.profiles !== null && ps.profiles.demo === null
        width: parent.width
        theme: ps.theme
        icon: ps.theme.icons.library
        text: "Explore the demo"
        hint: "example pages"
        onClicked: { menu.close(); ps.profiles.openDemo() }
      }
      MenuRow {
        objectName: "profileManage"
        width: parent.width
        theme: ps.theme
        icon: ps.theme.icons.cog
        text: "Manage profiles…"
        onClicked: { menu.close(); ps.manageRequested() }
      }
    }
  }

  // A new one.
  Pop {
    id: newPop
    objectName: "profileNewPop"
    theme: ps.theme
    y: ps.height + 4
    width: 380
    padding: 18
    contentItem: Column {
      spacing: 12
      Text {
        textFormat: Text.PlainText
        text: "New profile"
        font.family: ps.theme.uiFont
        font.pixelSize: 15
        font.weight: Font.DemiBold
        color: ps.theme.text
      }
      ProfileForm {
        id: form
        width: parent.width
        theme: ps.theme
        service: ps.service
        onCreated: newPop.close()
        onCancelled: newPop.close()
      }
    }
  }
}
