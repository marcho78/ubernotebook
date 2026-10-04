import QtQuick
import QtQuick.Controls
import QtQuick.Pdf
import "../Files.js" as Files

// A file on a page in Pages: what it is, what it's called and how big, and
// Open (in the app it opens in). A PDF shows its pages here too, one under
// another (Show pages / Hide), in a frame whose bottom edge drags to make
// it taller or shorter, with the page you're on. Not added yet, it asks for
// one. Its colors are Pages' or your own.
DataCard {
  id: fb
  kind: "file"

  readonly property bool has: info.src !== ""
  readonly property bool pdf: has && info.kind === "pdf"
  readonly property bool showing: pdf && info.open
  readonly property string url: has && editor ? editor.assetUrl(info.src) : ""
  // A PDF's pages are shown only from a plain file of at most maxPdf bytes,
  // as it really is (not as the page says): 1 yes, 0 no, -1 asking.
  readonly property real maxPdf: 200 * 1024 * 1024
  property int pdfOk: -1
  onUrlChanged: checkPdf()
  Component.onCompleted: checkPdf()
  function checkPdf() {
    pdfOk = -1
    if (!pdf || !editor) return
    var src = info.src
    editor.assetInfo(src, function(r) {
      if (src !== fb.info.src) return
      fb.pdfOk = r !== null && r.regular && r.size <= fb.maxPdf ? 1 : 0
    })
  }
  function sample() { return info.name || "File" }

  readonly property string glyph: {
    if (!theme) return ""
    var k = info.kind
    var i = theme.icons
    return k === "pdf" ? i.pdf : k === "video" ? i.video : k === "audio" ? i.fileMusic : k === "image" ? i.fileImage : k === "doc" ? i.fileDoc
      : k === "sheet" ? i.fileSheet : k === "slides" ? i.fileSlides : k === "archive" ? i.fileZip : k === "code" ? i.fileCode : i.attach
  }

  // The frame's height as it's dragged (not kept yet), or -1.
  property real dragH: -1
  readonly property real frameH: dragH >= 0 ? dragH : info.height

  width: available
  height: card.height

  Rectangle {
    id: card
    width: fb.width
    height: head.height + (fb.showing ? frame.height + 10 : 0)
    radius: 10
    color: fb.fill
    border.width: 1
    border.color: Qt.alpha(fb.words, fb.pointerIn ? 0.14 : 0.08)

    Item {
      id: head
      width: parent.width
      height: 54
      Rectangle {
        id: badge
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: 8
        color: Qt.alpha(fb.accent, 0.14)
        Text {
          anchors.centerIn: parent
          textFormat: Text.PlainText
          text: fb.has ? fb.glyph : (fb.theme ? fb.theme.icons.attach : "")
          font.family: fb.theme ? fb.theme.iconFont : ""
          font.pixelSize: 19
          color: fb.accent
        }
      }
      Column {
        x: badge.x + badge.width + 12
        anchors.verticalCenter: parent.verticalCenter
        width: tools.x - x - 8
        spacing: 1
        Text {
          objectName: "fileName"
          width: parent.width
          elide: Text.ElideMiddle
          textFormat: Text.PlainText
          text: fb.has ? fb.info.name || "File" : (fb.readOnly ? "A file, not added" : fb.info.kind === "pdf" ? "Add a PDF" : "Add a file")
          font.family: fb.editor ? fb.editor.uiFamily : ""
          font.pixelSize: 14
          font.weight: fb.has ? Font.DemiBold : Font.Normal
          color: fb.has ? fb.words : fb.faint
        }
        Text {
          width: parent.width
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: fb.has ? (fb.info.kind === "other" ? "" : fb.info.kind.toUpperCase() + "  \u00b7  ") + Files.sizeLabel(fb.info.size) + (fb.pdf && pdfDoc.pageCount > 0 ? "  \u00b7  " + pdfDoc.pageCount + (pdfDoc.pageCount === 1 ? " page" : " pages") : "")
            : "Click to pick one, or drop a file on the page"
          font.family: fb.editor ? fb.editor.uiFamily : ""
          font.pixelSize: 12
          color: fb.faint
        }
      }
      Row {
        id: tools
        anchors.right: parent.right
        anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        IconButton {
          objectName: "filePages"
          visible: fb.pdf
          theme: fb.theme; icon: fb.theme ? fb.theme.icons.pdf : ""; label: fb.info.open ? "Hide pages" : "Show pages"; size: 30; iconSize: 14; tint: fb.words
          onClicked: fb.change({ open: !fb.info.open })
        }
        IconButton {
          objectName: "fileOpen"
          visible: fb.has
          theme: fb.theme; icon: fb.theme ? fb.theme.icons.openExternal : ""; label: "Open"; size: 30; iconSize: 14; tint: fb.words
          tip: "Open it in its app"
          onClicked: fb.act("open", null)
        }
        IconButton {
          id: colorButton
          objectName: "fileColors"
          visible: !fb.readOnly && (fb.pointerIn || fb.trying !== null)
          theme: fb.theme; icon: fb.theme ? fb.theme.icons.palette : ""; size: 30; iconSize: 14; tint: fb.words
          tip: "Its colors"
          onClicked: fb.askColors(colorButton)
        }
      }
      HoverHandler { cursorShape: fb.has ? Qt.ArrowCursor : Qt.PointingHandCursor }
      TapHandler {
        enabled: !fb.has && !fb.readOnly
        onTapped: fb.act("pick", null)
      }
    }

    // A PDF's pages.
    PdfDocument {
      id: pdfDoc
      source: fb.pdf && fb.pdfOk === 1 ? fb.url : ""
    }
    Rectangle {
      id: frame
      objectName: "pdfFrame"
      visible: fb.showing
      x: 10
      y: head.height
      width: parent.width - 20
      height: fb.frameH
      radius: 6
      color: fb.dark ? "#2a2b33" : "#d9d6cf"
      clip: true
      ListView {
        id: pages
        objectName: "pdfPages"
        anchors.fill: parent
        anchors.margins: 8
        spacing: 8
        clip: true
        model: fb.showing ? pdfDoc.pageCount : 0
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
        delegate: Item {
          required property int index
          readonly property size pt: pdfDoc.pagePointSize(index)
          width: pages.width
          height: pt.width > 0 ? pages.width * pt.height / pt.width : pages.width * 1.3
          Rectangle { anchors.fill: parent; color: "white" }
          PdfPageImage {
            anchors.fill: parent
            document: pdfDoc
            currentFrame: index
            asynchronous: true
            fillMode: Image.PreserveAspectFit
            sourceSize.width: Math.round(pages.width * 1.5)
          }
        }
      }
      Rectangle {
        visible: pdfDoc.pageCount > 0
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: 12
        width: pageLabel.implicitWidth + 16
        height: 24
        radius: 12
        color: Qt.rgba(0, 0, 0, 0.55)
        Text {
          id: pageLabel
          anchors.centerIn: parent
          textFormat: Text.PlainText
          readonly property int at: { var i = pages.indexAt(10, pages.contentY + pages.height / 3); return i < 0 ? 1 : i + 1 }
          text: at + " / " + pdfDoc.pageCount
          font.family: fb.editor ? fb.editor.uiFamily : ""
          font.pixelSize: 11
          color: "white"
        }
      }
      Text {
        visible: pdfDoc.status === PdfDocument.Error || fb.pdfOk === 0
        anchors.centerIn: parent
        width: Math.min(implicitWidth, parent.width - 40)
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignHCenter
        textFormat: Text.PlainText
        text: fb.pdfOk === 0 ? "Too big to show here (over 200 MB, or not a plain file): Open opens it in its app" : "The PDF couldn't be read"
        font.family: fb.editor ? fb.editor.uiFamily : ""
        font.pixelSize: 13
        color: fb.faint
      }
      // Its bottom edge: taller or shorter.
      Item {
        objectName: "pdfEdge"
        anchors.bottom: parent.bottom
        width: parent.width
        height: 8
        visible: !fb.readOnly
        HoverHandler { cursorShape: Qt.SizeVerCursor }
        DragHandler {
          target: null
          property real from: 0
          onActiveChanged: {
            if (active) { from = fb.info.height; fb.dragH = from }
            else { var h = Math.round(fb.dragH); fb.dragH = -1; if (h !== fb.info.height) fb.change({ height: h }) }
          }
          onTranslationChanged: if (active) fb.dragH = Math.max(200, Math.min(2000, from + translation.y))
        }
      }
    }
  }
}
