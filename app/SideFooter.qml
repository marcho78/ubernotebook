import QtQuick

// The foot of Pages' sidebar, and the shelf's corner: when there's a newer
// Uber Notebook, a line that says so (a click: what's new in it, and updating);
// then who made Uber Notebook, on X (a click opens the profile in your browser).
Column {
  id: sf

  property var theme: null
  property var service: null
  signal notesRequested()

  readonly property string handle: "devsec_ai"
  readonly property string profileUrl: "https://x.com/" + handle
  readonly property var updates: service && service.updates ? service.updates : null
  readonly property bool updateShown: updates !== null && updates.available

  spacing: 2

  // A newer version.
  Rectangle {
    id: updateLine
    objectName: "footerUpdate"
    visible: sf.updateShown
    width: parent.width
    height: 30
    radius: 6
    color: updateHover.hovered ? sf.theme.hover : "transparent"
    Rectangle {
      x: 12
      anchors.verticalCenter: parent.verticalCenter
      width: 7
      height: 7
      radius: 3.5
      color: sf.theme.accent
    }
    Text {
      x: 30
      width: parent.width - 40
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: sf.updates && sf.updates.latest ? "Version " + sf.updates.latest.version + " is available" : ""
      font.family: sf.theme.uiFont
      font.pixelSize: 12
      font.weight: Font.Medium
      color: sf.theme.text
    }
    HoverHandler { id: updateHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: sf.notesRequested() }
  }

  // On X.
  Rectangle {
    id: xLine
    objectName: "footerX"
    width: parent.width
    height: 28
    radius: 6
    color: xHover.hovered ? sf.theme.hover : "transparent"
    Row {
      x: 12
      anchors.verticalCenter: parent.verticalCenter
      spacing: 7
      XLogo {
        anchors.verticalCenter: parent.verticalCenter
        size: 11
        color: xHover.hovered ? sf.theme.text : sf.theme.muted
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "Follow me on X"
        font.family: sf.theme.uiFont
        font.pixelSize: 12
        color: sf.theme.muted
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "@" + sf.handle
        font.family: sf.theme.uiFont
        font.pixelSize: 12
        font.weight: Font.DemiBold
        font.underline: xHover.hovered
        color: sf.theme.text
      }
    }
    HoverHandler { id: xHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: if (sf.service && sf.service.store) sf.service.store.openUrl(sf.profileUrl) }
  }
}
