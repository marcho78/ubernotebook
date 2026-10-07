import QtQuick
import QtQuick.Controls
import "../Docs.js" as Docs
import "../Blocks.js" as Blocks

// A block's menu (its ⋮⋮ handle, clicked): turn it into another kind, color
// it, duplicate it, move it to another page, or delete it, with everything
// inside it. Works on all the blocks picked when there are several.
Pop {
  id: menu

  property var editor: null
  property var uids: []
  // What's shown: the actions, or the kinds. (Its colors are the same
  // ones as everywhere in Pages: colorRequested.)
  property string panel: "main"

  signal moveRequested(var uids)
  signal toPageRequested(string uid)
  signal mindMapRequested(var uids)
  signal agentRequested(var uids)
  signal syncedRequested(var uids)
  // Color: Pages' colors and your own, beside where the menu was.
  signal colorRequested(var uids, Item anchor, real x, real y)

  focus: false
  width: 250
  padding: 6

  readonly property var first: {
    var s = editor ? editor.structure : 0
    var i = editor && uids.length ? editor.indexOf(uids[0]) : -1
    return i >= 0 ? editor.model.get(i) : null
  }
  readonly property bool text: first !== null && Blocks.isText(first.type)

  function openFor(uid, anchor) {
    uids = editor.selectedMap[uid] ? editor.selectedList.slice() : [uid]
    if (!editor.selectedMap[uid]) editor.selectBlocks(uid, uid)
    panel = "main"
    parent = anchor
    x = -width - 6
    y = -8
    open()
  }

  onClosed: panel = "main"

  contentItem: Column {
    spacing: 2

    Text {
      textFormat: Text.PlainText
      visible: menu.panel === "main"
      leftPadding: 10
      topPadding: 4
      bottomPadding: 4
      text: menu.first ? Docs.kindLabel(menu.first.type, menu.first.toggle) : ""
      font.family: menu.theme.uiFont
      font.pixelSize: 11
      font.weight: Font.DemiBold
      color: menu.theme.muted
    }
    MenuRow {
      visible: menu.panel === "main"
      theme: menu.theme; icon: menu.theme.icons.agent; text: "Ask agent"; hint: "Ctrl+J"
      width: parent.width
      onClicked: { var list = menu.uids; menu.close(); menu.agentRequested(list) }
    }
    MenuRow {
      visible: menu.panel === "main" && menu.text
      theme: menu.theme; icon: menu.theme.icons.swap; text: "Turn into"; hint: "\u203a"
      width: parent.width
      onClicked: menu.panel = "turn"
    }
    MenuRow {
      visible: menu.panel === "main"
      theme: menu.theme; icon: menu.theme.icons.palette; text: "Color"; hint: "\u203a"
      width: parent.width
      onClicked: { var u = menu.uids; var a = menu.parent; var x = menu.x; var y = menu.y; menu.close(); menu.colorRequested(u, a, x, y) }
    }
    MenuRow {
      visible: menu.panel === "main" && menu.text && menu.uids.length > 0
      theme: menu.theme; icon: menu.theme.icons.toPage; text: "Turn into page"
      width: parent.width
      onClicked: { var uid = menu.uids[0]; menu.close(); menu.toPageRequested(uid) }
    }
    MenuRow {
      visible: menu.panel === "main" && menu.text && !menu.editor.readOnly
      theme: menu.theme; icon: menu.theme.icons.mindmap; text: "Turn into mind map"
      width: parent.width
      onClicked: { var list = menu.uids; menu.close(); menu.mindMapRequested(list) }
    }
    MenuRow {
      visible: menu.panel === "main" && menu.first !== null && menu.first.type === "mindmap" && !menu.editor.readOnly
      theme: menu.theme; icon: menu.theme.icons.bullets; text: "Turn into list"
      width: parent.width
      onClicked: { var uid = menu.uids[0]; menu.close(); menu.editor.mindMapToList(uid) }
    }
    MenuRow {
      objectName: "makeSynced"
      visible: menu.panel === "main" && menu.editor.doc && !menu.editor.readOnly && menu.first !== null && menu.first.type !== "synced" && menu.first.type !== "page"
      theme: menu.theme; icon: menu.theme.icons.synced; text: "Turn into a synced block"
      width: parent.width
      onClicked: { var list = menu.uids; menu.close(); menu.syncedRequested(list) }
    }
    MenuRow {
      visible: menu.panel === "main"
      theme: menu.theme; icon: menu.theme.icons.copy; text: "Duplicate"; hint: "Ctrl+D"
      width: parent.width
      onClicked: { menu.close(); menu.editor.duplicateBlocks(menu.uids) }
    }
    MenuRow {
      visible: menu.panel === "main"
      theme: menu.theme; icon: menu.theme.icons.move; text: "Move to\u2026"
      width: parent.width
      onClicked: { var list = menu.uids; menu.close(); menu.moveRequested(list) }
    }
    Rectangle { visible: menu.panel === "main"; width: parent.width; height: 1; color: menu.theme.line }
    MenuRow {
      visible: menu.panel === "main"
      theme: menu.theme; icon: menu.theme.icons.trash; text: "Delete"; hint: "Del"; danger: true
      width: parent.width
      onClicked: { menu.close(); menu.editor.removeBlocks(menu.uids) }
    }

    // Turn into...
    MenuRow {
      visible: menu.panel !== "main"
      theme: menu.theme; icon: menu.theme.icons.left; text: "Turn into"
      width: parent.width
      onClicked: menu.panel = "main"
    }
    Repeater {
      model: menu.panel === "turn" ? Docs.TURN_INTO : []
      delegate: MenuRow {
        required property var modelData
        theme: menu.theme
        icon: menu.theme.icons[modelData.icon] || ""
        text: modelData.label
        width: parent.width
        checked: menu.first !== null && menu.first.type === modelData.type && !!menu.first.toggle === !!modelData.toggle
        onClicked: { menu.close(); menu.editor.turnInto(menu.uids, modelData.type, modelData.toggle === true) }
      }
    }
  }
}
