import QtQuick
import QtQuick.Controls

// A table's row or column menu (its handle, clicked): a row or a column in
// before or after it, moved, or taken out, and whether the first row is a
// header row, and its cells' colors. TableBlock.qml does them.
Pop {
  id: menu

  property var editor: null
  property string uid: ""
  // "row" or "col", and which.
  property string kind: "row"
  property int index: 0
  // The handle it opened from (the colors open beside it).
  property var anchor: null

  focus: false
  width: 240
  padding: 6

  readonly property var target: editor && editor.items[uid] ? editor.items[uid].tableView : null
  readonly property bool row: kind === "row"
  readonly property int last: target ? (row ? target.rowCount : target.cols) - 1 : 0

  function openFor(uid, kind, index, anchor, over) {
    menu.uid = uid
    menu.kind = kind
    menu.index = index
    menu.anchor = anchor
    var p = anchor.mapToItem(over, kind === "row" ? -width - 6 : anchor.width / 2 - width / 2, kind === "row" ? -8 : anchor.height + 6)
    parent = over
    x = p.x
    y = p.y
    open()
  }

  function act(what) {
    var t = target
    var k = kind
    var i = index
    close()
    if (t) t.act(k, what, i)
  }

  contentItem: Column {
    spacing: 2

    Text {
      textFormat: Text.PlainText
      leftPadding: 10
      topPadding: 4
      bottomPadding: 4
      text: (menu.row ? "Row " : "Column ") + (menu.index + 1)
      font.family: menu.theme.uiFont
      font.pixelSize: 11
      font.weight: Font.DemiBold
      color: menu.theme.muted
    }
    MenuRow {
      visible: menu.row
      theme: menu.theme; icon: menu.theme.icons.rowAbove; text: "Insert row above"
      width: parent.width
      onClicked: menu.act("above")
    }
    MenuRow {
      visible: menu.row
      theme: menu.theme; icon: menu.theme.icons.rowBelow; text: "Insert row below"
      width: parent.width
      onClicked: menu.act("below")
    }
    MenuRow {
      visible: !menu.row
      theme: menu.theme; icon: menu.theme.icons.colLeft; text: "Insert column left"
      width: parent.width
      onClicked: menu.act("left")
    }
    MenuRow {
      visible: !menu.row
      theme: menu.theme; icon: menu.theme.icons.colRight; text: "Insert column right"
      width: parent.width
      onClicked: menu.act("right")
    }
    Rectangle { width: parent.width; height: 1; color: menu.theme.line }
    MenuRow {
      visible: menu.row
      active: menu.index > 0
      theme: menu.theme; icon: menu.theme.icons.arrowUp; text: "Move up"
      width: parent.width
      onClicked: if (active) menu.act("up")
    }
    MenuRow {
      visible: menu.row
      active: menu.index < menu.last
      theme: menu.theme; icon: menu.theme.icons.arrowDown; text: "Move down"
      width: parent.width
      onClicked: if (active) menu.act("down")
    }
    MenuRow {
      visible: !menu.row
      active: menu.index > 0
      theme: menu.theme; icon: menu.theme.icons.arrowLeft; text: "Move left"
      width: parent.width
      onClicked: if (active) menu.act("moveLeft")
    }
    MenuRow {
      visible: !menu.row
      active: menu.index < menu.last
      theme: menu.theme; icon: menu.theme.icons.arrowRight; text: "Move right"
      width: parent.width
      onClicked: if (active) menu.act("moveRight")
    }
    MenuRow {
      theme: menu.theme; icon: menu.theme.icons.palette; text: "Color"; hint: "\u203a"
      width: parent.width
      onClicked: {
        var t = menu.target
        var k = menu.kind
        var i = menu.index
        var a = menu.anchor
        menu.close()
        if (t) t.askColors(k, k === "row" ? i : 0, k === "col" ? i : 0, a)
      }
    }
    MenuRow {
      theme: menu.theme; icon: menu.theme.icons.header; text: "Header row"
      checked: menu.target ? menu.target.table.header : false
      width: parent.width
      onClicked: menu.act("header")
    }
    Rectangle { width: parent.width; height: 1; color: menu.theme.line }
    MenuRow {
      active: menu.last > 0
      theme: menu.theme; icon: menu.row ? menu.theme.icons.rowRemove : menu.theme.icons.colRemove
      text: menu.row ? "Delete row" : "Delete column"; danger: true
      width: parent.width
      onClicked: if (active) menu.act("delete")
    }
  }
}
