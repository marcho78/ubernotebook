import QtQuick
import "../Papers.js" as Papers

// One page of the notebook: the paper, the title written on its top line with
// the date beside it, the writing below, and the page number at the foot.
// The writing scrolls on the page (the wheel, or following the cursor), and
// the paper's lines scroll with it.
Item {
  id: sheet

  // ---- what to show (set by the notebook) ------------------------------------------

  property var look: Papers.resolve({}, {})
  property string pen: "sans"
  property string spacing: look.spacing || "regular"
  property string family: "Adwaita Sans"
  property string monoFamily: "iA Writer Mono S"
  property string uiFamily: "Adwaita Sans"
  property color accent: "#2456b3"
  property bool strikeDone: true
  property bool readOnly: false
  // Room the binding takes at the left edge.
  property real leftGutter: 48
  property string placeholder: "Untitled"
  property string dateText: ""
  property int pageNumber: 1
  property var assetUrl: function(src) { return "" }

  property alias editor: editor
  property alias ink: inkLayer
  // Drawing instead of writing (the pen, marker or eraser is out).
  property bool drawing: false
  property alias titleField: titleInput
  readonly property alias contentY: flick.contentY

  signal titleEdited(string text)
  signal picturesDropped(var urls)

  // ---- measurements -------------------------------------------------------------------

  readonly property real pitch: look.pitch || 30
  readonly property var titleStyle: Papers.typeStyle("h1", pen, spacing)
  readonly property real marginLine: leftGutter + Math.round(pitch * 1.45)
  readonly property real textLeft: look.hasMargin ? marginLine + Math.round(pitch * 0.5) : leftGutter + Math.round(pitch * 1.5)
  readonly property real textRight: Math.round(pitch * 1.5)
  readonly property int headerRows: 3
  readonly property real bodyTop: headerRows * pitch

  clip: true

  function scrollToTop() { flick.contentY = 0 }

  // The page's title, when a page is shown.
  function setTitle(text) {
    titleInput.text = text || ""
    titleInput.cursorPosition = 0
  }

  // Keeps [y, y + h] (in the editor's coordinates) in view, with two lines to spare.
  function ensureVisible(y, h) {
    var top = editor.y + y - pitch * 2
    var bottom = editor.y + y + h + pitch * 2
    var max = Math.max(0, flick.contentHeight - flick.height)
    if (top < flick.contentY) flick.contentY = Math.max(0, Math.round(top))
    else if (bottom > flick.contentY + flick.height) flick.contentY = Math.round(Math.min(max, bottom - flick.height))
  }

  Paper {
    anchors.fill: parent
    look: sheet.look
    originY: sheet.bodyTop - flick.contentY
    scrollOffset: flick.contentY
    marginLine: sheet.marginLine
    gridOrigin: sheet.textLeft
  }

  Flickable {
    id: flick
    anchors.fill: parent
    // Scrolled by the wheel and the cursor only: dragging selects text.
    interactive: false
    contentWidth: width
    contentHeight: Math.max(height, sheet.bodyTop + editor.height + sheet.pitch * 4)
    Behavior on contentY { enabled: !wheel.active; NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }

    // The title, on the top rule.
    TextInput {
      id: titleInput
      x: sheet.textLeft
      width: flick.width - sheet.textLeft - sheet.textRight - dateLabel.implicitWidth - sheet.pitch
      y: sheet.pitch * 2.8 - baselineOffset
      readOnly: sheet.readOnly || sheet.drawing
      font.family: sheet.family
      font.pixelSize: sheet.titleStyle.size
      font.bold: sheet.titleStyle.bold
      color: sheet.look.ink
      selectionColor: sheet.look.selection
      selectedTextColor: sheet.look.ink
      selectByMouse: true
      clip: true
      maximumLength: 120
      onTextEdited: sheet.titleEdited(text)
      Keys.onPressed: function(e) {
        if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Down || (e.key === Qt.Key_Tab && !(e.modifiers & Qt.ShiftModifier))) {
          e.accepted = true
          editor.focusStart()
        }
      }

      Text {
        textFormat: Text.PlainText
        visible: titleInput.text === ""
        text: sheet.placeholder
        font: titleInput.font
        color: Qt.alpha(sheet.look.ink, 0.3)
        y: 0
      }
    }

    // The date, written small at the end of the title line.
    Text {
      textFormat: Text.PlainText
      id: dateLabel
      anchors.right: parent.right
      anchors.rightMargin: sheet.textRight
      y: sheet.pitch * 2.8 - baselineOffset
      text: sheet.dateText
      font.family: sheet.uiFamily
      font.pixelSize: Math.max(11, Math.round(sheet.pitch * 0.4))
      font.letterSpacing: 0.6
      font.capitalization: Font.AllUppercase
      color: sheet.look.muted
    }

    Editor {
      id: editor
      enabled: !sheet.drawing
      x: sheet.textLeft
      y: sheet.bodyTop
      width: flick.width - sheet.textLeft - sheet.textRight
      contentWidth: width
      focus: true
      pitch: sheet.pitch
      pen: sheet.pen
      spacing: sheet.spacing
      family: sheet.family
      monoFamily: sheet.monoFamily
      uiFamily: sheet.uiFamily
      ink: sheet.look.ink
      muted: sheet.look.muted
      accent: sheet.accent
      linkColor: sheet.look.link
      selectionColor: Qt.alpha(sheet.look.selection, 0.85)
      dark: sheet.look.dark === true
      strikeDone: sheet.strikeDone
      readOnly: sheet.readOnly
      assetUrl: sheet.assetUrl
      onCursorAt: function(y, h) { sheet.ensureVisible(y, h) }
      onLeaveTop: {
        titleInput.forceActiveFocus()
        titleInput.cursorPosition = titleInput.text.length
        sheet.ensureVisible(-sheet.bodyTop, sheet.pitch)
      }
    }

    // Drawings, over the writing.
    InkLayer {
      id: inkLayer
      z: 5
      width: flick.width
      height: flick.contentHeight
      drawing: sheet.drawing
      dark: sheet.look.dark === true
    }

    // Clicking the empty paper under the writing writes there.
    MouseArea {
      enabled: !sheet.drawing
      x: 0
      y: editor.y + editor.height
      width: flick.width
      height: Math.max(0, flick.contentHeight - y)
      cursorShape: Qt.IBeamCursor
      onClicked: editor.clickBelow()
    }
  }

  WheelHandler {
    id: wheel
    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: function(event) {
      var dy = event.pixelDelta.y !== 0 ? event.pixelDelta.y : event.angleDelta.y / 120 * sheet.pitch * 2.5
      var max = Math.max(0, flick.contentHeight - flick.height)
      flick.contentY = Math.round(Math.max(0, Math.min(max, flick.contentY - dy)))
    }
  }

  // A thin scroll mark at the right edge while there's more page than fits.
  Rectangle {
    visible: flick.contentHeight > flick.height + 1
    anchors.right: parent.right
    anchors.rightMargin: 4
    width: 3
    radius: 1.5
    color: Qt.alpha(sheet.look.ink, 0.22)
    height: Math.max(24, flick.height * flick.height / flick.contentHeight)
    y: (flick.height - height) * (flick.contentY / Math.max(1, flick.contentHeight - flick.height))
  }

  // The page number, in the bottom corner.
  Text {
    textFormat: Text.PlainText
    anchors.right: parent.right
    anchors.rightMargin: sheet.textRight * 0.7
    anchors.bottom: parent.bottom
    anchors.bottomMargin: sheet.pitch * 0.45
    text: sheet.pageNumber
    font.family: sheet.uiFamily
    font.pixelSize: Math.max(11, Math.round(sheet.pitch * 0.42))
    font.features: { "tnum": 1 }
    color: sheet.look.muted
    opacity: 0.8
  }

  DropArea {
    anchors.fill: parent
    enabled: !sheet.readOnly
    onEntered: function(drag) { drag.accepted = drag.hasUrls }
    onDropped: function(drop) { if (drop.hasUrls) sheet.picturesDropped(drop.urls) }
  }
}
