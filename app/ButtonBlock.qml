import QtQuick
import QtQuick.Controls
import "../Templates.js" as Templates

// A button on a page in Pages: a click puts in a template (yours, or one of
// Uber Notebook's) after it, or makes a new page from it inside this page. Not set
// up yet, it asks for its words and its template. Its gear sets it up again;
// its colors are Pages' or your own.
DataCard {
  id: bb
  kind: "button"

  readonly property bool ready: info.template !== ""
  readonly property string what: {
    var t = info.template
    if (!t) return ""
    var r = editor ? editor.pagesRevision : 0
    if (t.indexOf("tpl:") === 0) { var meta = editor && editor.pageInfo ? editor.pageInfo(t.slice(4)) : null; return meta ? meta.title || "Untitled" : "a template that's gone" }
    return Templates.byId(t).label
  }
  function sample() { return info.label || what || "Button" }

  width: available
  height: 44

  Rectangle {
    id: pill
    objectName: "buttonPill"
    anchors.verticalCenter: parent.verticalCenter
    width: Math.min(bb.width - tools.width - 8, row.implicitWidth + 28)
    height: 36
    radius: 10
    color: !bb.ready ? "transparent" : bb.look.background ? bb.fill : Qt.alpha(bb.accent, pillHover.hovered ? 0.2 : 0.12)
    border.width: bb.ready ? (bb.look.background ? 1 : 0) : 1.5
    border.color: bb.ready ? Qt.alpha(bb.words, 0.12) : Qt.alpha(bb.ink, 0.25)
    scale: pillTap.pressed ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: 90 } }
    Row {
      id: row
      anchors.centerIn: parent
      spacing: 8
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: bb.theme ? (bb.ready ? (bb.info.action === "page" ? bb.theme.icons.newPage : bb.theme.icons.plus) : bb.theme.icons.button) : ""
        font.family: bb.theme ? bb.theme.iconFont : ""
        font.pixelSize: 16
        color: bb.ready ? bb.accent : bb.faint
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: Math.min(implicitWidth, bb.width - 120)
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: bb.ready ? (bb.info.label || (bb.info.action === "page" ? "New " + bb.what : bb.what)) : (bb.readOnly ? "A button, not set up" : "Set up the button: a click puts in a template")
        font.family: bb.editor ? bb.editor.uiFamily : ""
        font.pixelSize: 14
        font.weight: bb.ready ? Font.DemiBold : Font.Normal
        color: bb.ready ? (bb.look.color ? bb.accent : bb.words) : bb.faint
      }
    }
    HoverHandler { id: pillHover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
      id: pillTap
      gesturePolicy: TapHandler.ReleaseWithinBounds
      onTapped: {
        if (bb.ready) bb.act("press", null)
        else if (!bb.readOnly) bb.act("setup", pill)
      }
    }
    ToolTip.visible: pillHover.hovered && bb.ready
    ToolTip.delay: 700
    ToolTip.text: (bb.info.action === "page" ? "A new page inside this one, from " : "Puts in ") + "\u201c" + bb.what + "\u201d"
  }

  Row {
    id: tools
    anchors.left: pill.right
    anchors.leftMargin: 6
    anchors.verticalCenter: parent.verticalCenter
    spacing: 2
    visible: !bb.readOnly && bb.ready && (bb.pointerIn || bb.trying !== null)
    IconButton {
      objectName: "buttonSetup"
      theme: bb.theme; icon: bb.theme ? bb.theme.icons.cog : ""; size: 28; iconSize: 14; tint: bb.ink
      tip: "Set it up"
      onClicked: bb.act("setup", pill)
    }
    IconButton {
      id: colorButton
      objectName: "buttonColors"
      theme: bb.theme; icon: bb.theme ? bb.theme.icons.palette : ""; size: 28; iconSize: 14; tint: bb.ink
      tip: "Its colors"
      onClicked: bb.askColors(colorButton)
    }
  }
}
