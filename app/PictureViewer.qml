import QtQuick
import QtQuick.Controls

// Pictures shown large, here in Uber Notebook (a picture on a page, a gallery's):
// its caption under it, how many there are, ← and → (or the arrows at its
// sides) for the others, Esc or a click around it to close; at the corner,
// Copy (Ctrl+C), Save a copy (Ctrl+S) and Open in its app. A click is the
// one thing's it's on (a button, or around the picture), not the page's
// under it too.
Rectangle {
  id: pv

  property var theme: null
  // [{ src, caption }], and the one shown.
  property var pictures: []
  property int index: 0
  // A picture's src as a URL to show.
  property var urlOf: function(src) { return src }
  readonly property var shown: pictures[index] || null
  signal openRequested(string src)
  // Onto the clipboard; a copy saved where you say (named for its caption).
  signal copyRequested(string src)
  signal saveRequested(string src, string caption)

  objectName: "pictureViewer"
  visible: false
  color: Qt.rgba(0.02, 0.02, 0.03, 0.9)

  function show(list, at) {
    pictures = list || []
    index = Math.max(0, Math.min(pictures.length - 1, at || 0))
    visible = pictures.length > 0
    if (visible) forceActiveFocus()
  }
  function close() { visible = false }
  function step(by) { if (pictures.length > 1) index = (index + by + pictures.length) % pictures.length }

  Keys.onPressed: function(e) {
    if (e.matches(StandardKey.Copy)) { if (shown) copyRequested(shown.src) }
    else if (e.matches(StandardKey.Save)) { if (shown) saveRequested(shown.src, shown.caption || "") }
    else if (e.key === Qt.Key_Escape || e.key === Qt.Key_Space) close()
    else if (e.key === Qt.Key_Left || e.key === Qt.Key_Up) step(-1)
    else if (e.key === Qt.Key_Right || e.key === Qt.Key_Down) step(1)
    else if (e.key === Qt.Key_Home) index = 0
    else if (e.key === Qt.Key_End) index = pictures.length - 1
    e.accepted = true
  }
  // (A click around the picture closes it; on it, nothing.)
  TapHandler {
    gesturePolicy: TapHandler.ReleaseWithinBounds
    onTapped: function(point) { if (!picture.contains(picture.mapFromItem(pv, point.position.x, point.position.y))) pv.close() }
  }
  WheelHandler { onWheel: function(e) { pv.step(e.angleDelta.y > 0 ? -1 : 1) } }

  Image {
    id: picture
    objectName: "pictureViewerImage"
    anchors.centerIn: parent
    anchors.verticalCenterOffset: caption.visible ? -16 : 0
    width: Math.min(implicitWidth > 0 ? implicitWidth : parent.width, parent.width - 160)
    height: Math.min(implicitHeight > 0 ? implicitHeight : parent.height, parent.height - (caption.visible ? 150 : 110))
    fillMode: Image.PreserveAspectFit
    // (Read no bigger than it can be shown: a picture of any size takes no
    // more than the screen does. One smaller isn't made bigger.)
    sourceSize.width: Math.min(8192, Math.ceil(Math.max(1, pv.width - 160) * Math.max(1, Screen.devicePixelRatio)))
    sourceSize.height: Math.min(8192, Math.ceil(Math.max(1, pv.height - 110) * Math.max(1, Screen.devicePixelRatio)))
    asynchronous: true
    smooth: true
    mipmap: true
    source: pv.shown ? pv.urlOf(pv.shown.src) : ""
  }
  Text {
    id: caption
    visible: pv.shown !== null && pv.shown.caption !== undefined && pv.shown.caption !== ""
    anchors.horizontalCenter: parent.horizontalCenter
    anchors.top: picture.bottom
    anchors.topMargin: 14
    width: Math.min(implicitWidth, parent.width - 160)
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignHCenter
    textFormat: Text.PlainText
    text: pv.shown ? pv.shown.caption || "" : ""
    font.family: pv.theme ? pv.theme.uiFont : ""
    font.pixelSize: 14
    color: "#e8e8e8"
  }
  Text {
    objectName: "pictureViewerCount"
    visible: pv.pictures.length > 1
    x: 24
    y: 22
    textFormat: Text.PlainText
    text: (pv.index + 1) + " / " + pv.pictures.length
    font.family: pv.theme ? pv.theme.uiFont : ""
    font.pixelSize: 13
    color: "#bdbdbd"
  }
  Row {
    anchors.right: parent.right
    anchors.rightMargin: 16
    y: 14
    spacing: 4
    Repeater {
      model: [["copy", "copy", "Copy  Ctrl+C"], ["save", "download", "Save a copy  Ctrl+S"], ["open", "openExternal", "Open in its app"], ["close", "close", "Close  Esc"]]
      delegate: Rectangle {
        required property var modelData
        objectName: "pictureViewer_" + modelData[0]
        width: 34
        height: 34
        radius: 17
        color: btnHover.hovered ? Qt.rgba(1, 1, 1, 0.14) : "transparent"
        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: pv.theme ? pv.theme.icons[parent.modelData[1]] : ""
          font.family: pv.theme ? pv.theme.iconFont : ""
          font.pixelSize: 16
          color: "#f2f2f2"
        }
        HoverHandler { id: btnHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
          gesturePolicy: TapHandler.ReleaseWithinBounds
          onTapped: {
            var what = parent.modelData[0]
            if (what === "close" || !pv.shown) pv.close()
            else if (what === "copy") pv.copyRequested(pv.shown.src)
            else if (what === "save") pv.saveRequested(pv.shown.src, pv.shown.caption || "")
            else pv.openRequested(pv.shown.src)
          }
        }
        ToolTip.visible: btnHover.hovered
        ToolTip.delay: 600
        ToolTip.text: modelData[2]
      }
    }
  }
  // The others, either side.
  Repeater {
    model: pv.pictures.length > 1 ? [-1, 1] : []
    delegate: Rectangle {
      required property int modelData
      objectName: modelData < 0 ? "pictureViewerPrevious" : "pictureViewerNext"
      x: modelData < 0 ? 24 : pv.width - width - 24
      anchors.verticalCenter: parent.verticalCenter
      width: 44
      height: 44
      radius: 22
      color: sideHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.06)
      Text {
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: pv.theme ? (parent.modelData < 0 ? pv.theme.icons.left : pv.theme.icons.right) : ""
        font.family: pv.theme ? pv.theme.iconFont : ""
        font.pixelSize: 20
        color: "#f2f2f2"
      }
      HoverHandler { id: sideHover; cursorShape: Qt.PointingHandCursor }
      TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: pv.step(parent.modelData) }
    }
  }
}
