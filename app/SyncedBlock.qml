import QtQuick
import QtQuick.Controls
import "../Workspace.js" as Workspace

// A synced block on a page in Pages: blocks kept on a page of their own and
// shown here, as they are, wherever else the same synced block is too;
// changed in one place (Edit), changed in all. Its bar (on hover) says how
// many pages it's on; Edit opens its blocks to change them, Unsync makes
// them this page's own, plain blocks again. Its colors (its outline, its
// background) are Pages' or your own.
DataCard {
  id: sb
  kind: "synced"

  readonly property var ws: editor ? editor.calendarSource : null
  readonly property string pageId: info.page
  property bool gone: false
  readonly property int places: { var r = ws ? ws.revision : 0; return ws && pageId ? Workspace.backlinks(ws.index, pageId).length : 0 }
  function sample() { return "Synced" }

  function reload() {
    if (!ws || !pageId) { inner.load([]); gone = !!pageId; return }
    ws.readPage(pageId, function(p) {
      sb.gone = !p
      inner.load(p ? Workspace.flatten(p) : [])
    })
  }
  onLoaded: reload()
  onWsChanged: reload()
  Connections {
    target: sb.ws
    function onSaved(id) { if (id === sb.pageId) sb.reload() }
    function onPageChanged(id) { if (id === sb.pageId) sb.reload() }
  }

  width: available
  height: frame.height

  Rectangle {
    id: frame
    objectName: "syncedFrame"
    width: sb.width
    height: Math.max(44, inner.height + 16)
    radius: 8
    color: sb.look.background ? sb.fill : "transparent"
    border.width: 1.5
    border.color: Qt.alpha(sb.look.color ? sb.accent : "#e5904d", sb.pointerIn ? 0.85 : 0.4)

    Editor {
      id: inner
      objectName: "syncedEditor"
      x: 8
      y: 8
      width: parent.width - 16
      height: implicitHeight
      layout: "doc"
      readOnly: true
      enabled: true
      contentWidth: width
      theme: sb.theme
      family: sb.editor ? sb.editor.family : ""
      monoFamily: sb.editor ? sb.editor.monoFamily : ""
      uiFamily: sb.editor ? sb.editor.uiFamily : ""
      ink: sb.look.background ? sb.words : (sb.editor ? sb.editor.ink : "black")
      muted: sb.editor ? sb.editor.muted : "gray"
      accent: sb.editor ? sb.editor.accent : "blue"
      linkColor: sb.editor ? sb.editor.linkColor : "blue"
      selectionColor: sb.editor ? sb.editor.selectionColor : "lightblue"
      dark: sb.dark
      paper: sb.editor ? sb.editor.paper : "white"
      smallText: sb.editor ? sb.editor.smallText : false
      assetUrl: sb.editor ? sb.editor.assetUrl : function(s) { return "" }
      pageInfo: sb.editor ? sb.editor.pageInfo : function(i) { return null }
      pagesRevision: sb.editor ? sb.editor.pagesRevision : 0
      onPageOpened: function(id) { if (sb.editor) sb.editor.pageOpened(id) }
      onLinkOpened: function(url) { if (sb.editor) sb.editor.linkOpened(url) }
    }

    Text {
      visible: sb.gone || !sb.pageId
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: "This synced block's blocks aren't there any more"
      font.family: sb.editor ? sb.editor.uiFamily : ""
      font.pixelSize: 13
      font.italic: true
      color: sb.faint
    }
  }

  // Its bar: how many pages it's on, Edit, Unsync, its colors.
  Rectangle {
    id: bar
    visible: !sb.readOnly && (sb.pointerIn || sb.trying !== null) && sb.pageId !== ""
    anchors.right: parent.right
    anchors.rightMargin: 8
    y: -14
    z: 4
    width: barRow.implicitWidth + 12
    height: 28
    radius: 8
    color: sb.editor ? sb.editor.paper : "white"
    border.width: 1
    border.color: Qt.alpha(sb.look.color ? sb.accent : "#e5904d", 0.6)
    Row {
      id: barRow
      x: 6
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
      Text {
        anchors.verticalCenter: parent.verticalCenter
        rightPadding: 6
        textFormat: Text.PlainText
        text: (sb.theme ? sb.theme.icons.synced + "  " : "") + "Synced" + (sb.places > 1 ? ", on " + sb.places + " pages" : "")
        font.family: sb.editor ? sb.editor.uiFamily : ""
        font.pixelSize: 12
        color: sb.look.color ? sb.accent : "#c86f2a"
      }
      IconButton { objectName: "syncedEdit"; theme: sb.theme; icon: sb.theme ? sb.theme.icons.edit : ""; label: "Edit"; size: 24; iconSize: 12; tint: sb.ink; tip: "Change its blocks (everywhere it is)"; onClicked: sb.act("edit", null) }
      IconButton { objectName: "syncedUnsync"; theme: sb.theme; icon: sb.theme ? sb.theme.icons.unsync : ""; size: 24; iconSize: 13; tint: sb.ink; tip: "Unsync: its blocks this page's own, here"; onClicked: sb.act("unsync", null) }
      IconButton { id: colorButton; objectName: "syncedColors"; theme: sb.theme; icon: sb.theme ? sb.theme.icons.palette : ""; size: 24; iconSize: 13; tint: sb.ink; tip: "Its colors"; onClicked: sb.askColors(colorButton) }
    }
  }
}
