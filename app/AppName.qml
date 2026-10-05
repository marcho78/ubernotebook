import QtQuick

// Uber Notebook's icon and name, at the top left of Pages' sidebar and the
// shelf: a click on it, Settings → About.
Row {
  id: name
  objectName: "appName"
  property var theme: null
  signal clicked()
  spacing: 8

  Image {
    anchors.verticalCenter: parent.verticalCenter
    width: 22
    height: 22
    source: "../logo.png"
    sourceSize: Qt.size(64, 64)
    fillMode: Image.PreserveAspectFit
    smooth: true
    mipmap: true
  }
  Text {
    anchors.verticalCenter: parent.verticalCenter
    textFormat: Text.PlainText
    text: "Uber Notebook"
    font.family: name.theme ? name.theme.uiFont : ""
    font.pixelSize: 14
    font.weight: Font.DemiBold
    color: name.theme ? name.theme.text : "black"
  }
  HoverHandler { cursorShape: Qt.PointingHandCursor }
  // (Taken by it alone: nothing under it is clicked too.)
  TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: name.clicked() }
}
