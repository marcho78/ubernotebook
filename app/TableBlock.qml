import QtQuick
import QtQuick.Layouts
import "../Table.js" as Table
import "../Html.js" as Html
import "../Docs.js" as Docs
import "../Colors.js" as Colors

// A table on a page in Pages: rows of cells, the first row a header row
// (shaded) unless that's switched off. Click a cell to write in it: Tab and
// Shift+Tab go to the next and the previous cell (Tab in the last cell makes
// a new row), Enter to the cell below (a new row past the last), Shift+Enter
// is a new line in the cell, the arrows cross into the next cell at a cell's
// ends and leave the table at its top and bottom, Esc picks the table.
// Ctrl+B, I and U, Ctrl+Shift+X (struck), Ctrl+E (code) and Ctrl+\ (plain)
// work on what's selected in a cell. Cells pasted from a spreadsheet fill the
// table from the cell you're in, and it grows to take them. Writing in it is
// undone as any writing is.
// While the pointer is over it: a handle at the left end of its row and the top
// of its column (for their menus: rows and columns in, out and moved, the
// header row), + bars along the bottom and the right (a new row, a new
// column), and the lines between columns drag to make them wider or
// narrower. A locked page's table is only read.
// Cells have colors: a text color and a background, one of Pages' or one of
// your own from the color picker. The color button on the cell you're in
// colors it; *Color* in a row's or a column's menu colors all of it.
Item {
  id: grid

  property var editor: null
  // The block it's in (DocBlock), told when cells have been written in.
  property var host: null
  property string uid: ""
  // The table as the page has it (JSON).
  property string source: ""
  property real available: 600
  property color ink: "black"
  property real fontPx: 15
  property real lineH: 22
  readonly property bool readOnly: editor ? editor.readOnly : true

  // The table shown: the page's, with what's being written in its cells.
  property var table: ({ rows: [[""]], header: true, widths: [1] })
  // The JSON it was last read from or written as (the page's table changing
  // to this isn't news).
  property string written: ""
  readonly property int cols: table.rows.length ? table.rows[0].length : 0
  readonly property int rowCount: table.rows.length
  readonly property int count: rowCount * cols

  // The cell you're writing in, and whether you are.
  property int curRow: -1
  property int curCol: -1
  property bool writing: false
  // A column's edge being dragged.
  property bool sizing: false

  signal reloaded()

  readonly property real pad: 9
  readonly property real gap: 6
  readonly property real bar: 22
  readonly property real minCol: 72
  readonly property real viewW: Math.max(minCol, available - bar)
  readonly property real tableW: Math.max(viewW, cols * minCol)
  readonly property color lineColor: Qt.alpha(ink, 0.17)
  readonly property color headFill: Qt.alpha(ink, 0.05)

  // A color as text or as a background on this page: one of Pages' ("red",
  // in its light or dark shade) or one of your own ("#ff8800").
  function textOf(id) { var c = Docs.colorEntry(id); return c ? c.text[editor.dark ? 1 : 0] : Colors.normalize(id) }
  function backOf(id) { var c = Docs.colorEntry(id); return c ? c.background[editor.dark ? 1 : 0] : Colors.normalize(id) }
  readonly property string inkHex: Colors.normalize(String(ink)) || "#000000"
  readonly property string paperHex: Colors.normalize(String(editor ? editor.paper : "#ffffff")) || "#ffffff"

  width: available
  height: gap + frame.height + bar

  function colW(c) { return Math.max(24, (table.widths[c] || 1 / Math.max(1, cols)) * tableW) }
  function colX(c) { var x = 0; for (var k = 0; k < c; k++) x += colW(k); return x }
  function colAt(x) {
    var at = 0
    for (var c = 0; c < cols; c++) {
      if (x < at + colW(c)) return c
      at += colW(c)
    }
    return cols - 1
  }
  function rowAt(y) {
    for (var r = 0; r < rowCount; r++) {
      var it = cells.itemAt(r * cols)
      if (it && y < it.y + it.height) return r
    }
    return rowCount - 1
  }
  function rowY(r) { var it = cells.itemAt(r * cols); return it ? it.y : 0 }
  function rowH(r) { var it = cells.itemAt(r * cols); return it ? it.height : 0 }
  function cellAt(r, c) { return r >= 0 && c >= 0 && r < rowCount && c < cols ? cells.itemAt(r * cols + c) : null }

  // ---- reading and writing ----------------------------------------------------------------

  onSourceChanged: if (source !== written) load()
  Component.onCompleted: load()

  function load() {
    var t = null
    try { t = Table.clean(JSON.parse(source)) } catch (e) { t = null }
    var at = writing && curRow >= 0 ? { r: curRow, c: curCol, pos: cellAt(curRow, curCol) ? cellAt(curRow, curCol).edit.cursorPosition : 0 } : null
    written = source
    table = t || Table.make(3, 3)
    reloaded()
    // Still in the cell you were in (or the nearest still there).
    if (at) focusCell(Math.min(at.r, rowCount - 1), Math.min(at.c, cols - 1), at.pos)
  }

  // The table as it's kept, with what's been written in it.
  function json() {
    var t = Table.clean(table)
    if (!t) return ""
    written = JSON.stringify(t)
    return written
  }

  // Writing in a cell: into the table (as it is, not a copy, so nothing
  // shown is read again), and a step to undo.
  function typed(cell) {
    if (cell.loading || readOnly) return
    if (cell.r >= rowCount || cell.c >= cols) return
    var inner = editor.innerOf(cell.edit, 0, cell.edit.length)
    // Qt also reports changes that change nothing (a cell focused, words
    // selected): those aren't writing.
    if (Table.cleanCell(inner) === Table.cleanCell(table.rows[cell.r][cell.c])) return
    table.rows[cell.r][cell.c] = inner
    host.dirty = true
    editor.tableTyped(host)
  }

  // A change that isn't writing (rows, columns, widths, the header row), as
  // a step of its own; then the cursor's in cell (r, c) at `pos` (-1: its end).
  function change(t, r, c, pos) {
    if (readOnly || !t) return
    settle()
    editor.setTable(uid, t)
    if (r !== undefined && r >= 0) focusCell(r, c, pos === undefined ? -1 : pos)
  }

  // What's been written so far, as a step of its own.
  function settle() {
    if (host && host.dirty) editor.syncBlock(uid)
    editor.closeBurst()
  }

  // ---- moving around -------------------------------------------------------------------------

  function focusCell(r, c, pos) {
    var it = cellAt(r, c)
    if (!it) return
    it.edit.forceActiveFocus()
    var len = it.edit.length
    it.edit.cursorPosition = pos === undefined || pos < 0 ? len : Math.min(pos, len)
    showCell(it)
  }

  // A cell scrolled to, when the table's wider than the page.
  function showCell(it) {
    if (it.x < scroller.contentX) scroller.contentX = it.x
    else if (it.x + it.width > scroller.contentX + scroller.width) scroller.contentX = Math.min(scroller.contentWidth - scroller.width, it.x + it.width - scroller.width)
  }

  // Into the table from above (dir 1: its first row) or below (its last),
  // `x` across the block.
  function enter(dir, x) {
    if (count === 0) return
    var r = dir > 0 ? 0 : rowCount - 1
    var tx = x - scroller.x + scroller.contentX
    var c = colAt(tx)
    var it = cellAt(r, c)
    if (!it) return
    var py = dir > 0 ? lineH * 0.5 : it.edit.contentHeight - lineH * 0.5
    focusCell(r, c, it.edit.positionAt(Math.max(0, tx - it.x - it.edit.x), Math.max(0, py)))
  }

  // Out of the table, up or down, from where the cursor is across the page.
  function leave(cell, dir) {
    var rect = cell.edit.cursorRectangle
    var x = host.x + grid.x + scroller.x + cell.x - scroller.contentX + cell.edit.x + rect.x
    cell.edit.deselect()
    editor.leaveTable(uid, dir, x)
  }

  // Up or down a row, keeping the cursor's place across.
  function vertical(cell, dir) {
    var r = cell.r + dir
    if (r < 0 || r >= rowCount) { leave(cell, dir); return }
    var it = cellAt(r, cell.c)
    var x = cell.edit.cursorRectangle.x
    var y = dir > 0 ? lineH * 0.5 : it.edit.contentHeight - lineH * 0.5
    focusCell(r, cell.c, it.edit.positionAt(Math.max(0, x), Math.max(0, y)))
  }

  function focused(cell) {
    curRow = cell.r
    curCol = cell.c
    writing = true
    editor.tableFocused(uid)
  }

  function blurred() {
    Qt.callLater(function() {
      var any = false
      for (var i = 0; i < grid.count; i++) { var it = cells.itemAt(i); if (it && it.edit.activeFocus) any = true }
      grid.writing = any
    })
  }

  // ---- keys -------------------------------------------------------------------------------------

  function key(cell, e) {
    var edit = cell.edit
    if (edit.inputMethodComposing) return
    var ctrl = (e.modifiers & Qt.ControlModifier) !== 0
    var shift = (e.modifiers & Qt.ShiftModifier) !== 0
    var alt = (e.modifiers & Qt.AltModifier) !== 0
    var k = e.key
    var pos = edit.cursorPosition
    var hasSel = edit.selectionStart !== edit.selectionEnd

    if (ctrl && !alt && k === Qt.Key_Z) { e.accepted = true; settle(); if (shift) editor.redo(); else editor.undo(); return }
    if (ctrl && !alt && k === Qt.Key_Y) { e.accepted = true; settle(); editor.redo(); return }
    if (k === Qt.Key_Escape) { e.accepted = true; edit.deselect(); settle(); editor.selectBlocks(uid, uid); return }

    if (k === Qt.Key_Tab || k === Qt.Key_Backtab) {
      e.accepted = true
      var i = cell.r * cols + cell.c + (k === Qt.Key_Backtab || shift ? -1 : 1)
      if (i < 0) return
      if (i >= count) {
        if (!readOnly) change(Table.insertRow(table, rowCount), rowCount, 0, 0)
        return
      }
      focusCell(Math.floor(i / cols), i % cols, -1)
      return
    }
    if ((k === Qt.Key_Return || k === Qt.Key_Enter) && !ctrl && !alt) {
      e.accepted = true
      if (shift) {
        if (readOnly) return
        if (hasSel) edit.remove(edit.selectionStart, edit.selectionEnd)
        edit.insert(edit.cursorPosition, "<br />")
        return
      }
      if (cell.r + 1 < rowCount) focusCell(cell.r + 1, cell.c, -1)
      else if (!readOnly) change(Table.insertRow(table, rowCount), rowCount, cell.c, 0)
      return
    }
    if (!ctrl && !alt && !shift && k === Qt.Key_Up) {
      if (edit.positionToRectangle(pos).y < lineH * 0.5) { e.accepted = true; vertical(cell, -1) }
      return
    }
    if (!ctrl && !alt && !shift && k === Qt.Key_Down) {
      var r = edit.positionToRectangle(pos)
      if (r.y + r.height > edit.contentHeight - lineH * 0.5) { e.accepted = true; vertical(cell, 1) }
      return
    }
    if (!ctrl && !alt && !shift && k === Qt.Key_Left && pos === 0 && !hasSel) {
      var p = cell.r * cols + cell.c - 1
      if (p >= 0) { e.accepted = true; focusCell(Math.floor(p / cols), p % cols, -1) }
      return
    }
    if (!ctrl && !alt && !shift && k === Qt.Key_Right && pos === edit.length && !hasSel) {
      var n = cell.r * cols + cell.c + 1
      if (n < count) { e.accepted = true; focusCell(Math.floor(n / cols), n % cols, 0) }
      return
    }
    if (readOnly) return

    if (ctrl && !alt && k === Qt.Key_V) { e.accepted = true; paste(cell, shift); return }
    var kind = ctrl && !alt && !shift && k === Qt.Key_B ? "bold"
      : ctrl && !alt && !shift && k === Qt.Key_I ? "italic"
      : ctrl && !alt && !shift && k === Qt.Key_U ? "underline"
      : ctrl && !alt && shift && k === Qt.Key_X ? "strike"
      : ctrl && !alt && !shift && k === Qt.Key_E ? "code"
      : ctrl && !alt && !shift && k === Qt.Key_Backslash ? "clear" : ""
    if (kind) { e.accepted = true; format(cell, kind) }
  }

  // Formatting what's selected in a cell, as a step of its own.
  function format(cell, kind) {
    var edit = cell.edit
    var s = edit.selectionStart
    var t = edit.selectionEnd
    if (s === t) return
    settle()
    var inner = editor.transformed(editor.innerOf(edit, s, t), kind)
    cell.loading = true
    edit.remove(s, t)
    if (inner) edit.insert(s, editor.spaced(Html.decorateLinks(editor.display(inner), editor.linkColor)))
    cell.loading = false
    // Shown as it is (not read again), so what's selected stays selected.
    var next = Table.clean(Table.setCell(table, cell.r, cell.c, editor.innerOf(edit, 0, edit.length)))
    written = JSON.stringify(next)
    table = next
    editor.setTable(uid, next)
    edit.select(s, t)
  }

  // Pasting in a cell: cells (from a spreadsheet, or a table) fill the table
  // from this cell on; anything else goes in where the cursor is.
  function paste(cell, plainOnly) {
    var edit = cell.edit
    var text = editor.clipboardText()
    var many = Table.cellsOf(text)
    if (!plainOnly && !(many && (many.length > 1 || many[0].length > 1))) {
      var blocks = editor.clipboardBlocks(false)
      var tab = blocks.filter(function(b) { return b.type === "table" })[0]
      if (tab && tab.table) many = tab.table.rows
      else {
        var inner = blocks.filter(function(b) { return b.html !== undefined }).map(function(b) { return b.html || "" }).join("<br />")
        if (inner === "" && text === "") return
        if (edit.selectionStart !== edit.selectionEnd) edit.remove(edit.selectionStart, edit.selectionEnd)
        edit.insert(edit.cursorPosition, editor.spaced(Html.decorateLinks(editor.display(inner || Html.fromPlainText(text)), editor.linkColor)))
        return
      }
    }
    if (many && (many.length > 1 || many[0].length > 1)) {
      change(Table.pasteInto(table, cell.r, cell.c, many), cell.r, cell.c, -1)
      return
    }
    if (edit.selectionStart !== edit.selectionEnd) edit.remove(edit.selectionStart, edit.selectionEnd)
    edit.insert(edit.cursorPosition, Html.fromPlainText(text))
  }

  // ---- colors -----------------------------------------------------------------------------------

  // The cells being colored ({ what: "cell" | "row" | "col", r, c }), and the
  // table before (what the color picker shows is put back on Cancel).
  property var colorScope: null
  property var colorBase: null

  function scopeCells() {
    var s = colorScope
    return s ? Table.cellsIn(table, s.what, s.r, s.c) : []
  }

  // DocView's color menu, for them.
  function askColors(what, r, c, anchor) {
    if (readOnly) return
    settle()
    colorScope = { what: what, r: r, c: c }
    colorBase = Table.copy(table)
    editor.tableColorsRequested(uid, anchor)
  }

  // Their colors now (if they're all the same).
  function scopeColors() { return Table.colorsOf(table, scopeCells()) }

  // What the color picker shows as the sample: { text, fill, ownInk, pageInk }.
  function colorInfo() {
    var cells = scopeCells()
    var first = cells.length ? cells[0] : [0, 0]
    var now = scopeColors()
    var words = Html.plainText((table.rows[first[0]] || [])[first[1]] || "").replace(/\s+/g, " ").trim()
    return { text: words.slice(0, 24) || "Cell", fill: now.background ? backOf(now.background) : paperHex,
      ownInk: now.color ? textOf(now.color) : "", pageInk: inkHex }
  }

  // Shown while you pick (not kept yet).
  function previewColor(kind, value) {
    if (!colorScope || !colorBase) return
    table = Table.setColors(colorBase, scopeCells(), kind, value)
  }

  // Kept, as a step of its own.
  function applyColor(kind, value) {
    if (!colorScope || !colorBase) return
    var next = Table.setColors(colorBase, scopeCells(), kind, value)
    var s = colorScope
    change(next)
    colorBase = Table.copy(table)
    colorScope = s
  }

  // The picker canceled: as it was.
  function cancelColor() {
    if (colorBase) table = Table.copy(colorBase)
  }

  // The colors closed: back to writing in the cell (`refocus`: the picker
  // had the keys).
  function colorsClosed(refocus) {
    var s = colorScope
    colorScope = null
    colorBase = null
    if (refocus && s && s.what === "cell") focusCell(s.r, s.c, -1)
  }

  // ---- what the menus do ---------------------------------------------------------------------

  // A row's or a column's menu (TableMenu.qml): `what` it does to row or
  // column `at`.
  function act(kind, what, at) {
    var t = table
    var r = Math.max(0, curRow)
    var c = Math.max(0, curCol)
    if (kind === "row") {
      if (what === "above") change(Table.insertRow(t, at), at, c, 0)
      else if (what === "below") change(Table.insertRow(t, at + 1), at + 1, c, 0)
      else if (what === "up") change(Table.moveRow(t, at, -1), Math.max(0, at - 1), c, -1)
      else if (what === "down") change(Table.moveRow(t, at, 1), Math.min(rowCount - 1, at + 1), c, -1)
      else if (what === "delete") change(Table.deleteRow(t, at), Math.min(at, rowCount - 2), c, -1)
    } else if (kind === "col") {
      if (what === "left") change(Table.insertCol(t, at), r, at, 0)
      else if (what === "right") change(Table.insertCol(t, at + 1), r, at + 1, 0)
      else if (what === "moveLeft") change(Table.moveCol(t, at, -1), r, Math.max(0, at - 1), -1)
      else if (what === "moveRight") change(Table.moveCol(t, at, 1), r, Math.min(cols - 1, at + 1), -1)
      else if (what === "delete") change(Table.deleteCol(t, at), r, Math.min(at, cols - 2), -1)
    }
    if (what === "header") {
      var x = Table.copy(t)
      x.header = !t.header
      change(x)
    }
  }

  // ---- how it looks -------------------------------------------------------------------------------

  // (Only the topmost thing under the pointer is told it's there, so the
  // table has one HoverHandler, on top, and works out from where the
  // pointer is what it's over: a handle, an edge, a link.)
  readonly property bool pointerIn: hover.hovered
  readonly property real pointX: hover.point.position.x
  readonly property real pointY: hover.point.position.y
  readonly property bool over: hover.hovered && !sizing
  function inside(it, pad) {
    if (!it || !it.visible) return false
    var m = pad || 0
    return pointX >= it.x - m && pointX < it.x + it.width + m && pointY >= it.y - m && pointY < it.y + it.height + m
  }
  readonly property bool onRowHandle: over && inside(rowHandle, 2)
  readonly property bool onColHandle: over && inside(colHandle, 2)
  readonly property bool onAddRow: over && inside(addRow, 0)
  readonly property bool onAddCol: over && inside(addCol, 0)
  readonly property bool onColorButton: over && inside(colorButton, 2)
  // The edge between columns the pointer's on (its left column), or -1.
  readonly property int onEdge: {
    if (!hover.hovered || readOnly || pointY < gap || pointY > gap + frame.height) return -1
    for (var c = 0; c + 1 < cols; c++) {
      var x = scroller.x + colX(c + 1) - scroller.contentX
      if (Math.abs(pointX - x) <= 4) return c
    }
    return -1
  }
  // A link under the pointer, in the cell it's over.
  readonly property string linkUnder: {
    if (!over || hoverRow < 0 || hoverCol < 0) return ""
    var it = cellAt(hoverRow, hoverCol)
    if (!it) return ""
    return it.edit.linkAt(pointX - scroller.x + scroller.contentX - it.x - it.edit.x, pointY - gap - it.y - it.edit.y)
  }
  readonly property int cursor: sizing || onEdge >= 0 ? Qt.SplitHCursor
    : onRowHandle || onColHandle || onAddRow || onAddCol || onColorButton ? Qt.PointingHandCursor
    : linkUnder !== "" && ((hover.point.modifiers & Qt.ControlModifier) || Html.pageOf(linkUnder) !== "") ? Qt.PointingHandCursor
    : hoverRow >= 0 && hoverCol >= 0 ? Qt.IBeamCursor : Qt.ArrowCursor
  readonly property int hoverRow: over && pointY >= gap && pointY < gap + frame.height ? rowAt(pointY - gap) : -1
  readonly property int hoverCol: over && pointX >= scroller.x && pointX < scroller.x + scroller.width ? colAt(pointX - scroller.x + scroller.contentX) : -1
  // The row's and the column's handles: where the pointer is, else where you write.
  readonly property int handleRow: readOnly ? -1 : hoverRow >= 0 ? hoverRow : writing ? curRow : -1
  readonly property int handleCol: readOnly ? -1 : hoverCol >= 0 ? hoverCol : writing ? curCol : -1

  Flickable {
    id: scroller
    y: grid.gap
    width: grid.viewW
    height: frame.height
    contentWidth: frame.width
    contentHeight: frame.height
    flickableDirection: Flickable.HorizontalFlick
    interactive: contentWidth > width + 1
    boundsBehavior: Flickable.StopAtBounds
    clip: interactive

    Item {
      id: frame
      width: grid.tableW + 1
      height: layout.implicitHeight + 1

      GridLayout {
        id: layout
        x: 0.5
        y: 0.5
        columns: Math.max(1, grid.cols)
        rowSpacing: 0
        columnSpacing: 0

        Repeater {
          id: cells
          model: grid.count
          delegate: Rectangle {
            id: cell
            required property int index
            readonly property int r: Math.floor(index / Math.max(1, grid.cols))
            readonly property int c: index % Math.max(1, grid.cols)
            readonly property bool head: grid.table.header && r === 0 && grid.rowCount > 1
            readonly property var tint: Table.colorOf(grid.table, r, c)
            readonly property string backHex: tint.background ? grid.backOf(tint.background) : ""
            // Its text: its own color, else the page's, else (on a background of
            // your own it doesn't read on) dark or light.
            readonly property color inkColor: tint.color ? grid.textOf(tint.color)
              : backHex !== "" && Colors.isHex(tint.background) ? Colors.readableOn(backHex, grid.inkHex) : grid.ink
            readonly property bool current: grid.writing && grid.curRow === r && grid.curCol === c
            property bool loading: false
            property alias edit: text

            Layout.preferredWidth: grid.colW(c)
            Layout.minimumWidth: Layout.preferredWidth
            Layout.maximumWidth: Layout.preferredWidth
            Layout.preferredHeight: Math.max(grid.lineH, text.contentHeight) + grid.pad * 1.3
            Layout.fillHeight: true
            color: backHex !== "" ? backHex : head ? grid.headFill : "transparent"

            function reload() {
              loading = true
              var row = grid.table.rows[r]
              text.text = Html.wrapBlock(grid.editor.display(row ? row[c] || "" : ""), grid.lineH, grid.editor.linkColor)
              loading = false
            }
            Component.onCompleted: reload()
            Connections {
              target: grid
              function onReloaded() { cell.reload() }
            }

            // The lines between cells (the frame draws the outside), and the
            // cell you're in, outlined.
            Rectangle { visible: cell.c < grid.cols - 1; x: parent.width - 1; width: 1; height: parent.height; color: grid.lineColor }
            Rectangle { visible: cell.r < grid.rowCount - 1; y: parent.height - 1; width: parent.width; height: 1; color: grid.lineColor }
            Rectangle {
              visible: cell.current
              x: -0.5
              y: -0.5
              width: parent.width
              height: parent.height
              color: "transparent"
              border.width: 2
              border.color: Qt.alpha(grid.editor.accent, 0.75)
            }

            TextEdit {
              id: text
              // (The first column leaves room for the rows' handles.)
              x: grid.pad + (cell.c === 0 ? 6 : 0)
              y: grid.pad * 0.65
              width: parent.width - grid.pad * 2 - (cell.c === 0 ? 6 : 0)
              height: Math.max(contentHeight, parent.height - y - grid.pad * 0.65)
              textFormat: TextEdit.RichText
              wrapMode: TextEdit.Wrap
              readOnly: grid.readOnly
              selectByMouse: true
              font.family: grid.editor.family
              font.pixelSize: grid.fontPx
              font.weight: cell.head ? Font.DemiBold : Font.Normal
              color: cell.inkColor
              selectionColor: grid.editor.selectionColor
              selectedTextColor: grid.editor.ink

              Keys.onPressed: function(event) { grid.key(cell, event) }
              onTextChanged: grid.typed(cell)
              onActiveFocusChanged: if (activeFocus) grid.focused(cell); else grid.blurred()
              onCursorRectangleChanged: if (activeFocus) {
                var p = text.mapToItem(grid.host, 0, cursorRectangle.y)
                grid.editor.cursorAt(grid.host.y + p.y, cursorRectangle.height)
              }

              // Ctrl+click opens a link (a link to a page, a plain click).
              TapHandler {
                acceptedModifiers: Qt.ControlModifier
                onTapped: function(eventPoint) {
                  var link = text.linkAt(eventPoint.position.x, eventPoint.position.y)
                  if (link) grid.editor.openLink(link)
                }
              }
              TapHandler {
                acceptedModifiers: Qt.NoModifier
                onTapped: function(eventPoint) {
                  var link = text.linkAt(eventPoint.position.x, eventPoint.position.y)
                  if (Html.pageOf(link)) grid.editor.openLink(link)
                }
              }
            }
          }
        }
      }

      Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 1
        border.color: grid.lineColor
        radius: 2
      }
    }
  }

  // ---- the columns' edges, dragged -------------------------------------------------------------

  Repeater {
    model: grid.readOnly ? 0 : Math.max(0, grid.cols - 1)
    delegate: Item {
      id: edge
      objectName: "edge"
      required property int index
      property real startX: 0
      property var start: null
      x: scroller.x + grid.colX(index + 1) - scroller.contentX - width / 2
      y: grid.gap
      width: 9
      height: frame.height
      visible: x > scroller.x && x < scroller.x + scroller.width
      Rectangle {
        anchors.horizontalCenter: parent.horizontalCenter
        width: 2
        height: parent.height
        color: grid.editor.accent
        visible: grid.onEdge === edge.index || edgeDrag.active
      }
      DragHandler {
        id: edgeDrag
        target: null
        xAxis.enabled: true
        yAxis.enabled: false
        cursorShape: Qt.SplitHCursor
        onActiveChanged: {
          if (active) {
            grid.settle()
            edge.start = Table.copy(grid.table)
            edge.startX = edge.mapToItem(grid, centroid.position.x, 0).x
            grid.sizing = true
          } else {
            grid.sizing = false
            grid.change(grid.table)
          }
        }
        onCentroidChanged: if (active && edge.start) {
          var dx = edge.mapToItem(grid, centroid.position.x, 0).x - edge.startX
          grid.table = Table.resize(edge.start, edge.index, dx / grid.tableW)
        }
      }
    }
  }

  // ---- the row's and the column's handles ------------------------------------------------------

  Rectangle {
    id: rowHandle
    objectName: "rowHandle"
    readonly property int at: grid.handleRow
    visible: at >= 0 && grid.count > 0
    // Just inside the table's left edge (the pointer isn't seen past the
    // page's text column), in the first column's wider padding.
    width: 11
    height: 24
    radius: 4
    x: scroller.x + 2 - scroller.contentX
    y: grid.gap + grid.rowY(Math.max(0, at)) + grid.rowH(Math.max(0, at)) / 2 - height / 2
    color: grid.onRowHandle ? grid.editor.accent : grid.editor.paper
    border.width: 1
    border.color: grid.onRowHandle ? grid.editor.accent : Qt.alpha(grid.ink, 0.25)
    Column {
      anchors.centerIn: parent
      spacing: 2
      Repeater {
        model: 3
        delegate: Rectangle { width: 3; height: 3; radius: 1.5; color: grid.onRowHandle ? grid.editor.paper : Qt.alpha(grid.ink, 0.55) }
      }
    }
    TapHandler {
      gesturePolicy: TapHandler.ReleaseWithinBounds
      onTapped: { grid.settle(); grid.editor.tableMenuRequested(grid.uid, "row", rowHandle.at, rowHandle) }
    }
  }

  Rectangle {
    id: colHandle
    objectName: "colHandle"
    readonly property int at: grid.handleCol
    visible: at >= 0 && grid.count > 0 && x + width > scroller.x && x < scroller.x + scroller.width
    width: 24
    height: 14
    radius: 5
    x: scroller.x + grid.colX(Math.max(0, at)) - scroller.contentX + grid.colW(Math.max(0, at)) / 2 - width / 2
    y: grid.gap - height / 2
    color: grid.onColHandle ? grid.editor.accent : grid.editor.paper
    border.width: 1
    border.color: grid.onColHandle ? grid.editor.accent : Qt.alpha(grid.ink, 0.25)
    Row {
      anchors.centerIn: parent
      spacing: 2
      Repeater {
        model: 3
        delegate: Rectangle { width: 3; height: 3; radius: 1.5; color: grid.onColHandle ? grid.editor.paper : Qt.alpha(grid.ink, 0.55) }
      }
    }
    TapHandler {
      gesturePolicy: TapHandler.ReleaseWithinBounds
      onTapped: { grid.settle(); grid.editor.tableMenuRequested(grid.uid, "col", colHandle.at, colHandle) }
    }
  }

  // ---- the color button, on the cell you're in -------------------------------------------------

  Rectangle {
    id: colorButton
    objectName: "colorButton"
    readonly property var cell: grid.writing ? grid.cellAt(grid.curRow, grid.curCol) : null
    visible: !grid.readOnly && cell !== null && !grid.sizing && x + width > scroller.x && x < scroller.x + scroller.width
    width: 22
    height: 22
    radius: 11
    x: cell ? scroller.x + cell.x - scroller.contentX + cell.width - width / 2 - 1 : 0
    y: cell ? grid.gap + cell.y - height / 2 + 1 : 0
    z: 2
    color: grid.onColorButton ? grid.editor.accent : grid.editor.paper
    border.width: 1
    border.color: grid.onColorButton ? grid.editor.accent : Qt.alpha(grid.ink, 0.25)
    Text {
      anchors.centerIn: parent
      textFormat: Text.PlainText
      text: "\u{f0e0c}"
      font.family: "JetBrainsMono Nerd Font"
      font.pixelSize: 13
      color: grid.onColorButton ? grid.editor.paper : Qt.alpha(grid.ink, 0.7)
    }
    TapHandler {
      gesturePolicy: TapHandler.ReleaseWithinBounds
      onTapped: grid.askColors("cell", grid.curRow, grid.curCol, colorButton)
    }
  }

  // ---- + for a new row, + for a new column -----------------------------------------------------

  Rectangle {
    id: addRow
    objectName: "addRow"
    visible: !grid.readOnly && grid.over
    x: scroller.x
    y: grid.gap + frame.height + 4
    width: Math.min(scroller.width, frame.width)
    height: 15
    radius: 4
    color: Qt.alpha(grid.ink, grid.onAddRow ? 0.1 : 0.045)
    Text {
      anchors.centerIn: parent
      text: "+"
      textFormat: Text.PlainText
      font.pixelSize: 14
      color: Qt.alpha(grid.ink, 0.55)
    }
    TapHandler {
      gesturePolicy: TapHandler.ReleaseWithinBounds
      onTapped: grid.change(Table.insertRow(grid.table, grid.rowCount), grid.rowCount, 0, 0)
    }
  }

  Rectangle {
    id: addCol
    objectName: "addCol"
    visible: !grid.readOnly && grid.over && grid.cols < Table.MAX_COLS
    x: scroller.x + Math.min(scroller.width, frame.width) + 4
    y: grid.gap
    width: 15
    height: frame.height
    radius: 4
    color: Qt.alpha(grid.ink, grid.onAddCol ? 0.1 : 0.045)
    Text {
      anchors.centerIn: parent
      text: "+"
      textFormat: Text.PlainText
      font.pixelSize: 14
      color: Qt.alpha(grid.ink, 0.55)
    }
    TapHandler {
      gesturePolicy: TapHandler.ReleaseWithinBounds
      onTapped: grid.change(Table.insertCol(grid.table, grid.cols), Math.max(0, grid.curRow), grid.cols, 0)
    }
  }

  // The pointer over the table. On top, as the cells take hovering for
  // themselves; it takes nothing from them.
  Item {
    id: hoverArea
    width: grid.width
    height: grid.height
    HoverHandler { id: hover; cursorShape: grid.cursor }
  }
}
