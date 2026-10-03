import QtQuick
import QtQuick.Controls
import "../Board.js" as Board
import "../Colors.js" as Colors

// A board on a page in Pages (kanban): columns of cards. A click on a card
// writes in it (Enter keeps it, Esc puts it back); + New under a column adds
// one; a card drags to another place or column. Each card and each column
// has its own colors (its text's and its box's, Pages' or your own): the
// palette on it under the pointer. A card's ⋯ (or a right-click): Rename,
// Open as page (it becomes a page inside this one, and opens; after, Open
// page), and Delete. A column's name is written in with a click (or its ⋯,
// Rename); its ⋯ also has moving it, deleting it. + adds a column, named first. A
// column's right edge drags it wider or narrower, and the board's bottom
// edge makes it taller or shorter (it scrolls inside); a double-click on
// either puts it back as it fits. The board's own colors are at its corner.
// Each change is a step to undo.
DataCard {
  id: bd
  kind: "board"

  readonly property var cols: look.columns || []
  // Columns as wide as fit (no narrower than 200: then the board scrolls),
  // but for those dragged to a width.
  readonly property real fitW: {
    var fixed = 0, n = 0
    for (var i = 0; i < cols.length; i++) {
      if (cols[i].width > 0) fixed += cols[i].width
      else n++
    }
    return Math.max(200, Math.min(300, (scroller.width - (cols.length - 1) * 10 - (readOnly ? 0 : 46) - fixed) / Math.max(1, n)))
  }
  function widthOf(c) { return sizing && sizing.id === c.id ? sizing.w : c.width > 0 ? c.width : fitW }
  function sample() { return "Card" }

  // A column being dragged wider or narrower: { id, w }.
  property var sizing: null
  // The board's height while its edge is dragged (else -1), and as kept (0:
  // as tall as its cards).
  property real dragH: -1
  readonly property real fixedH: dragH >= 0 ? dragH : (look.height || 0)

  // What's being colored: { what: "board" | "column" | "card", id }.
  property var colorScope: ({ what: "board", id: "" })
  function colorsFor(what, id, anchor) { colorScope = { what: what, id: id }; askColors(anchor) }
  function scopeColors() {
    var s = colorScope
    if (s.what === "card") { var k = Board.card(info, s.id); return k ? { color: k.color, background: k.background } : { color: "", background: "" } }
    if (s.what === "column") { var c = columnOf(s.id); return c ? { color: c.color, background: c.background } : { color: "", background: "" } }
    return { color: info.color || "", background: info.background || "" }
  }
  function columnOf(id) { return info.columns.filter(function(x) { return x.id === id })[0] || null }
  function colorSubject() {
    var s = colorScope
    if (s.what === "card") { var k = Board.card(info, s.id); return "Card: " + (k && k.text ? k.text : "Untitled") }
    if (s.what === "column") { var c = columnOf(s.id); return "Column: " + (c && c.name ? c.name : "Untitled") }
    return "The whole board"
  }
  // Words on a box's background: the page's ink, or (on a color of your
  // own) black or white, whichever reads.
  function inkOn(back) { return back && Colors.isHex(back) ? Colors.readableOn(backOf(back), inkHex) : ink }
  function colorInfo() {
    var s = colorScope
    var now = scopeColors()
    var text = s.what === "card" ? (Board.card(info, s.id) || { text: "Card" }).text : s.what === "column" ? ((columnOf(s.id) || {}).name || "Column") : "Board"
    return { text: text.slice(0, 24) || "Card", fill: now.background ? backOf(now.background) : paperHex, ownInk: now.color ? textOf(now.color) : "", pageInk: inkHex }
  }
  // The board with a color put on what's being colored: the whole of it.
  function withColor(k, value) {
    var s = colorScope
    var key = k === "background" ? "background" : "color"
    var n = JSON.parse(JSON.stringify(info))
    var f = {}
    f[key] = value
    if (s.what === "card") n.columns = Board.setCard(info, s.id, f).columns
    else if (s.what === "column") n.columns = Board.setColumn(info, s.id, f).columns
    else n[key] = value
    return n
  }
  function previewColor(k, value) { trying = withColor(k, value) }
  function applyColor(k, value) {
    trying = null
    var n = withColor(k, value)
    change({ columns: n.columns, color: n.color, background: n.background })
  }

  // Its cards and columns as they are now (from Board.js), kept.
  function save(b) { change({ columns: b.columns }) }

  // Written in and done: the keyboard back to the page.
  function parkFocus() { if (editor && editor.parkFocus) editor.parkFocus() }

  // A column as wide as fits again, the board as tall as its cards.
  function fitColumn(id) {
    var c = info.columns.filter(function(x) { return x.id === id })[0]
    if (c && c.width > 0) save(Board.setColumn(info, id, { width: 0 }))
  }
  function fitHeight() { if (info.height > 0) change({ height: 0 }) }

  // ---- a column's name ---------------------------------------------------------------------

  property string naming: ""
  function startNaming(id) { if (!readOnly) { editing = ""; naming = id } }
  function finishNaming(id, text, keep) {
    if (naming !== id) return
    naming = ""
    var name = text.trim()
    var c = info.columns.filter(function(x) { return x.id === id })[0]
    if (keep && c && name && name !== c.name) save(Board.setColumn(info, id, { name: name }))
  }
  // Another column, named first (its name picked, so what's written replaces it).
  function addColumn() {
    var n = Board.addColumn(info, "")
    if (n.columns.length === info.columns.length) return
    save(n)
    naming = n.columns[n.columns.length - 1].id
    Qt.callLater(function() { scroller.contentX = Math.max(0, scroller.contentWidth - scroller.width) })
  }

  // ---- writing in a card -------------------------------------------------------------------

  property string editing: ""
  // Its text picked as it opens (Rename), or the cursor at its end (a click).
  property bool editWhole: false
  function startEdit(id, whole) { if (!readOnly) { naming = ""; editWhole = whole === true; editing = id } }
  function finishEdit(id, text, keep) {
    if (editing !== id) return
    editing = ""
    var k = Board.card(info, id)
    if (!k) return
    if (keep && text.trim() !== k.text) save(Board.setCard(info, id, { text: text }))
    else if (!k.text && !text.trim()) save(Board.removeCard(info, id))
  }
  function newCard(colId) {
    var r = Board.addCard(info, colId, "")
    save(r[0])
    editing = r[1]
  }

  // ---- dragging a card ---------------------------------------------------------------------

  property string dragId: ""
  property var dropAt: null   // { col (id), at, x, y, w }
  property point dragPoint: Qt.point(0, 0)
  function dragMove(p) {
    dragPoint = p
    var q = bd.mapToItem(colRow, p.x, p.y)
    var colItem = null
    for (var i = 0; i < colRepeater.count; i++) {
      var it = colRepeater.itemAt(i)
      if (it && q.x >= it.x && q.x < it.x + it.width) colItem = it
    }
    if (!colItem) { dropAt = null; return }
    var cards = colItem.cardItems()
    var local = colRow.mapToItem(colItem.list, q.x, q.y)
    var at = cards.length
    var y = cards.length ? cards[cards.length - 1].y + cards[cards.length - 1].height + 3 : 0
    for (var j = 0; j < cards.length; j++) {
      if (local.y < cards[j].y + cards[j].height / 2) { at = j; y = cards[j].y - 3; break }
    }
    // (Its own place, not counted.)
    var idx = cards.map(function(c) { return c.cardId }).indexOf(dragId)
    var target = idx >= 0 && at > idx ? at - 1 : at
    var pt = colItem.list.mapToItem(bd, 0, y)
    dropAt = { col: colItem.colId, at: target, x: pt.x, y: pt.y, w: colItem.list.width }
  }
  function dragEnd() {
    var id = dragId
    var d = dropAt
    dragId = ""
    dropAt = null
    if (!id || !d) return
    var f = Board.find(info, id)
    if (f && info.columns[f.col].id === d.col && f.at === d.at) return
    save(Board.moveCard(info, id, d.col, d.at))
  }

  width: available
  height: card.height

  // A slim bar in the page's ink, wider under the pointer.
  component Bar: ScrollBar {
    id: bar
    policy: ScrollBar.AlwaysOn
    padding: 2
    background: Item {}
    contentItem: Rectangle {
      implicitWidth: bar.hovered || bar.pressed ? 7 : 4
      implicitHeight: bar.hovered || bar.pressed ? 7 : 4
      radius: 3.5
      color: Qt.alpha(bd.ink, bar.pressed ? 0.5 : bar.hovered ? 0.38 : 0.22)
    }
  }

  Rectangle {
    id: card
    width: bd.width
    height: bd.fixedH > 0 ? bd.fixedH : Math.max(150, scroller.contentHeight + 24)
    radius: 10
    color: bd.look.background ? bd.fill : "transparent"
    border.width: bd.look.background ? 1 : 0
    border.color: Qt.alpha(bd.words, 0.08)

    Flickable {
      id: scroller
      x: bd.look.background ? 12 : 0
      y: 12
      width: parent.width - 2 * x
      // (Room under the columns for the bar across, when it scrolls across.)
      readonly property bool across: contentWidth > width + 1
      readonly property bool down: contentHeight > height + 1
      height: bd.fixedH > 0 ? card.height - 24 : colRow.height + (across ? 12 : 0)
      contentWidth: colRow.width
      contentHeight: colRow.height + (across ? 12 : 0)
      clip: true
      interactive: bd.dragId === "" && bd.sizing === null && (across || down)
      boundsBehavior: Flickable.StopAtBounds
      // Shown while there's more than fits, so it's plain the board scrolls.
      ScrollBar.horizontal: Bar { visible: scroller.across }
      ScrollBar.vertical: Bar { visible: scroller.down }

      Row {
        id: colRow
        spacing: 10
        Repeater {
          id: colRepeater
          model: bd.cols
          delegate: Rectangle {
            id: col
            required property var modelData
            required property int index
            readonly property string colId: modelData.id
            readonly property alias list: cardCol
            function cardItems() { var out = []; for (var i = 0; i < cardRep.count; i++) { var c = cardRep.itemAt(i); if (c) out.push(c) } return out }
            readonly property bool naming: bd.naming === modelData.id
            // Its own background, if it has one (else a shade of its color).
            readonly property color colInk: bd.inkOn(modelData.background)
            readonly property color colFaint: Qt.alpha(colInk, 0.55)
            objectName: "boardColumn"
            width: bd.widthOf(modelData)
            height: Math.max(110, head.height + cardCol.height + addRow.height + 18)
            radius: 8
            color: col.modelData.background ? bd.backOf(col.modelData.background)
              : col.modelData.color ? Qt.alpha(bd.textOf(col.modelData.color), bd.dark ? 0.12 : 0.07) : Qt.alpha(bd.ink, bd.dark ? 0.05 : 0.035)
            // A right-click on it (not on a card): its menu.
            TapHandler {
              acceptedButtons: Qt.RightButton
              enabled: !bd.readOnly
              onTapped: colMenu.open()
            }

            // Its name (a click writes in it), how many, its ⋯.
            Item {
              id: head
              x: 10
              y: 8
              width: parent.width - 20
              height: 26
              Rectangle {
                id: colDot
                anchors.verticalCenter: parent.verticalCenter
                width: 9
                height: 9
                radius: 4.5
                color: col.modelData.color ? bd.textOf(col.modelData.color) : Qt.alpha(col.colInk, 0.4)
              }
              // Its name: shaded under the pointer (a click writes in it);
              // while it's written in, a field.
              Rectangle {
                id: namePill
                objectName: "boardColumnLabel"
                x: 10
                anchors.verticalCenter: parent.verticalCenter
                width: col.naming ? parent.width - x - 28 : Math.min(parent.width - x - 80, nameText.implicitWidth + 12)
                height: 24
                radius: 5
                color: col.naming ? (bd.editor ? bd.editor.paper : "white") : nameHover.hovered && !bd.readOnly ? Qt.alpha(col.colInk, 0.08) : "transparent"
                border.width: col.naming ? 1.5 : 0
                border.color: bd.accent
                Text {
                  id: nameText
                  visible: !col.naming
                  x: 6
                  width: parent.width - 12
                  anchors.verticalCenter: parent.verticalCenter
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  text: col.modelData.name || "Untitled"
                  font.family: bd.editor ? bd.editor.uiFamily : ""
                  font.pixelSize: 13
                  font.weight: Font.DemiBold
                  color: col.modelData.color ? bd.textOf(col.modelData.color) : col.colInk
                }
                TextInput {
                  id: nameInput
                  objectName: "boardColumnName"
                  visible: col.naming
                  x: 6
                  width: parent.width - 12
                  anchors.verticalCenter: parent.verticalCenter
                  font.family: bd.editor ? bd.editor.uiFamily : ""
                  font.pixelSize: 13
                  font.weight: Font.DemiBold
                  color: bd.ink
                  selectionColor: Qt.alpha(bd.accent, 0.35)
                  selectedTextColor: bd.ink
                  selectByMouse: true
                  clip: true
                  maximumLength: 80
                  function begin() { text = col.modelData.name; forceActiveFocus(); selectAll() }
                  onVisibleChanged: if (visible) begin(); else if (activeFocus) bd.parkFocus()
                  Component.onCompleted: if (visible) begin()
                  onActiveFocusChanged: if (!activeFocus && col.naming) bd.finishNaming(col.colId, text, true)
                  Keys.onPressed: function(e) {
                    if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter) { e.accepted = true; bd.finishNaming(col.colId, text, true) }
                    else if (e.key === Qt.Key_Escape) { e.accepted = true; bd.finishNaming(col.colId, text, false) }
                  }
                }
                HoverHandler { id: nameHover; cursorShape: bd.readOnly ? Qt.ArrowCursor : Qt.IBeamCursor }
                TapHandler {
                  enabled: !bd.readOnly && !col.naming
                  gesturePolicy: TapHandler.ReleaseWithinBounds
                  onTapped: bd.startNaming(col.colId)
                }
                ToolTip.visible: nameHover.hovered && !col.naming && !bd.readOnly
                ToolTip.delay: 700
                ToolTip.text: "Click to rename"
              }
              Text {
                visible: !col.naming
                anchors.left: namePill.right
                anchors.leftMargin: 4
                anchors.verticalCenter: parent.verticalCenter
                textFormat: Text.PlainText
                text: String(col.modelData.cards.length)
                font.family: bd.editor ? bd.editor.uiFamily : ""
                font.pixelSize: 12
                color: col.colFaint
              }
              IconButton {
                id: colPaint
                objectName: "boardColumnColors"
                anchors.right: colMore.left
                anchors.verticalCenter: parent.verticalCenter
                visible: !bd.readOnly && !col.naming && (bd.pointerIn || colMenu.opened)
                theme: bd.theme; icon: bd.theme ? bd.theme.icons.palette : ""; size: 24; iconSize: 13; tint: col.colInk
                tip: "This column's colors"
                onClicked: bd.colorsFor("column", col.colId, colPaint)
              }
              IconButton {
                id: colMore
                objectName: "boardColumnMore"
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                visible: !bd.readOnly && (bd.pointerIn || colMenu.opened)
                theme: bd.theme; icon: bd.theme ? bd.theme.icons.more : ""; size: 24; iconSize: 13; tint: col.colInk
                tip: "Rename, color, move or delete"
                onClicked: colMenu.open()
                Pop {
                  id: colMenu
                  theme: bd.theme
                  focus: false
                  width: 210
                  y: colMore.height + 4
                  contentItem: Column {
                    spacing: 2
                    MenuRow { objectName: "boardColumnRename"; width: parent.width; theme: bd.theme; icon: bd.theme ? bd.theme.icons.pen : ""; text: "Rename"; onClicked: { colMenu.close(); bd.startNaming(col.colId) } }
                    MenuRow { width: parent.width; theme: bd.theme; icon: bd.theme ? bd.theme.icons.palette : ""; text: "Color\u2026"; onClicked: { colMenu.close(); bd.colorsFor("column", col.colId, colPaint) } }
                    MenuRow { width: parent.width; theme: bd.theme; icon: bd.theme ? bd.theme.icons.left : ""; text: "Move left"; active: col.index > 0; onClicked: { colMenu.close(); bd.save(Board.moveColumn(bd.info, col.colId, -1)) } }
                    MenuRow { width: parent.width; theme: bd.theme; icon: bd.theme ? bd.theme.icons.right : ""; text: "Move right"; active: col.index < bd.cols.length - 1; onClicked: { colMenu.close(); bd.save(Board.moveColumn(bd.info, col.colId, 1)) } }
                    MenuRow { objectName: "boardColumnDelete"; width: parent.width; theme: bd.theme; icon: bd.theme ? bd.theme.icons.trash : ""; text: "Delete the column"; danger: true; active: bd.cols.length > 1; onClicked: { colMenu.close(); bd.save(Board.removeColumn(bd.info, col.colId)) } }
                  }
                }
              }
            }

            // Its cards.
            Column {
              id: cardCol
              x: 8
              y: head.y + head.height + 6
              width: parent.width - 16
              spacing: 6
              Repeater {
                id: cardRep
                model: col.modelData.cards
                delegate: Rectangle {
                  id: cardItem
                  required property var modelData
                  readonly property string cardId: modelData.id
                  readonly property bool editingMe: bd.editing === modelData.id
                  objectName: "boardCard"
                  width: cardCol.width
                  height: Math.max(36, (editingMe ? cardEdit.contentHeight : cardText.contentHeight) + 18)
                  radius: 7
                  opacity: bd.dragId === modelData.id ? 0.35 : 1
                  color: modelData.background ? bd.backOf(modelData.background) : (bd.editor ? bd.editor.paper : "white")
                  border.width: editingMe ? 1.5 : 1
                  border.color: editingMe ? bd.accent : Qt.alpha(bd.ink, cardHover.hovered ? 0.2 : 0.1)
                  Text {
                    id: cardText
                    visible: !cardItem.editingMe
                    x: 10
                    y: 9
                    width: parent.width - 20 - (cardItem.modelData.page ? 18 : 0)
                    wrapMode: Text.Wrap
                    textFormat: Text.PlainText
                    text: cardItem.modelData.text || "Untitled"
                    font.family: bd.editor ? bd.editor.family : ""
                    font.pixelSize: 14
                    color: cardItem.modelData.color ? bd.textOf(cardItem.modelData.color) : Qt.alpha(bd.inkOn(cardItem.modelData.background), cardItem.modelData.text ? 1 : 0.55)
                  }
                  Text {
                    visible: cardItem.modelData.page !== "" && !cardItem.editingMe
                    anchors.right: parent.right
                    anchors.rightMargin: 8
                    y: 10
                    textFormat: Text.PlainText
                    text: bd.theme ? bd.theme.icons.page : ""
                    font.family: bd.theme ? bd.theme.iconFont : ""
                    font.pixelSize: 13
                    color: bd.faint
                  }
                  TextEdit {
                    id: cardEdit
                    objectName: "boardCardEdit"
                    visible: cardItem.editingMe
                    x: 10
                    y: 9
                    width: parent.width - 20
                    wrapMode: TextEdit.Wrap
                    textFormat: TextEdit.PlainText
                    font.family: bd.editor ? bd.editor.family : ""
                    font.pixelSize: 14
                    color: bd.inkOn(cardItem.modelData.background)
                    selectionColor: Qt.alpha(bd.accent, 0.35)
                    selectedTextColor: color
                    selectByMouse: true
                    function begin() {
                      text = cardItem.modelData.text
                      forceActiveFocus()
                      if (bd.editWhole) selectAll()
                      else cursorPosition = length
                    }
                    onVisibleChanged: if (visible) begin(); else if (activeFocus) bd.parkFocus()
                    Component.onCompleted: if (visible) begin()
                    onActiveFocusChanged: if (!activeFocus && cardItem.editingMe) bd.finishEdit(cardItem.cardId, text, true)
                    Keys.onPressed: function(e) {
                      if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !(e.modifiers & Qt.ShiftModifier)) { e.accepted = true; bd.finishEdit(cardItem.cardId, text, true) }
                      else if (e.key === Qt.Key_Escape) { e.accepted = true; bd.finishEdit(cardItem.cardId, text, false) }
                    }
                  }
                  HoverHandler { id: cardHover; cursorShape: bd.readOnly ? Qt.ArrowCursor : Qt.PointingHandCursor }
                  TapHandler {
                    gesturePolicy: TapHandler.ReleaseWithinBounds
                    onTapped: function(p) {
                      var q = cardTools.mapFromItem(cardItem, p.position.x, p.position.y)
                      if (cardTools.visible && cardTools.contains(q)) return
                      if (cardItem.modelData.page && !bd.readOnly && !cardItem.editingMe) bd.act("openCard", { id: cardItem.cardId, text: cardItem.modelData.text, page: cardItem.modelData.page })
                      else bd.startEdit(cardItem.cardId)
                    }
                  }
                  TapHandler {
                    acceptedButtons: Qt.RightButton
                    enabled: !bd.readOnly && !cardItem.editingMe
                    onTapped: cardMenu.open()
                  }
                  DragHandler {
                    enabled: !bd.readOnly && !cardItem.editingMe
                    target: null
                    dragThreshold: 6
                    // (Not given up to the board's scrolling.)
                    grabPermissions: PointerHandler.CanTakeOverFromAnything
                    onActiveChanged: if (active) bd.dragId = cardItem.cardId; else bd.dragEnd()
                    onCentroidChanged: if (active) bd.dragMove(cardItem.mapToItem(bd, centroid.position.x, centroid.position.y))
                  }
                  // Under the pointer: its colors, and its ⋯ (on the card's
                  // own color, over the end of its words).
                  Rectangle {
                    id: cardTools
                    visible: !bd.readOnly && (cardHover.hovered || cardMenu.opened) && !cardItem.editingMe
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.margins: 3
                    width: toolRow.width
                    height: toolRow.height
                    radius: 5
                    color: cardItem.color
                    Row {
                      id: toolRow
                      IconButton {
                        id: cardPaint
                        objectName: "boardCardColors"
                        theme: bd.theme; icon: bd.theme ? bd.theme.icons.palette : ""; size: 22; iconSize: 12; tint: bd.inkOn(cardItem.modelData.background)
                        tip: "This card's colors"
                        onClicked: bd.colorsFor("card", cardItem.cardId, cardItem)
                      }
                      IconButton {
                        id: cardMore
                        objectName: "boardCardMore"
                        theme: bd.theme; icon: bd.theme ? bd.theme.icons.more : ""; size: 22; iconSize: 12; tint: bd.inkOn(cardItem.modelData.background)
                        tip: "Rename, open as a page, delete"
                        onClicked: cardMenu.open()
                      }
                    }
                    Pop {
                      id: cardMenu
                      theme: bd.theme
                      focus: false
                      width: 210
                      y: cardMore.height + 4
                      contentItem: Column {
                        spacing: 2
                        MenuRow { width: parent.width; theme: bd.theme; icon: bd.theme ? bd.theme.icons.palette : ""; text: "Color\u2026"; onClicked: { cardMenu.close(); bd.colorsFor("card", cardItem.cardId, cardItem) } }
                        MenuRow {
                          objectName: "boardCardPage"
                          width: parent.width; theme: bd.theme; icon: bd.theme ? bd.theme.icons.page : ""
                          text: cardItem.modelData.page ? "Open page" : "Open as page"
                          onClicked: { cardMenu.close(); bd.act("openCard", { id: cardItem.cardId, text: cardItem.modelData.text, page: cardItem.modelData.page }) }
                        }
                        MenuRow { objectName: "boardCardRename"; width: parent.width; theme: bd.theme; icon: bd.theme ? bd.theme.icons.pen : ""; text: "Rename"; onClicked: { cardMenu.close(); bd.startEdit(cardItem.cardId, true) } }
                        MenuRow { objectName: "boardCardDelete"; width: parent.width; theme: bd.theme; icon: bd.theme ? bd.theme.icons.trash : ""; text: "Delete"; danger: true; onClicked: { cardMenu.close(); bd.save(Board.removeCard(bd.info, cardItem.cardId)) } }
                      }
                    }
                  }
                }
              }
            }

            // Its right edge: dragged, the column wider or narrower; a
            // double-click, as wide as fits again.
            Item {
              objectName: "boardColumnEdge"
              visible: !bd.readOnly
              x: parent.width - 3
              z: 3
              width: 9
              height: parent.height
              Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 3
                height: parent.height - 8
                y: 4
                radius: 1.5
                color: Qt.alpha(bd.accent, 0.6)
                visible: edgeHover.hovered || edgeDrag.active
              }
              HoverHandler { id: edgeHover; cursorShape: Qt.SplitHCursor }
              DragHandler {
                id: edgeDrag
                target: null
                cursorShape: Qt.SplitHCursor
                grabPermissions: PointerHandler.CanTakeOverFromAnything
                property real from: 0
                onActiveChanged: {
                  if (active) { from = col.width; bd.sizing = { id: col.colId, w: from }; return }
                  var w = bd.sizing ? Math.round(bd.sizing.w) : 0
                  bd.sizing = null
                  if (w > 0 && w !== col.modelData.width) bd.save(Board.setColumn(bd.info, col.colId, { width: w }))
                }
                onTranslationChanged: if (active) bd.sizing = { id: col.colId, w: Math.max(Board.MIN_WIDTH, Math.min(Board.MAX_WIDTH, from + translation.x)) }
              }
              TapHandler { onDoubleTapped: bd.fitColumn(col.colId) }
              ToolTip.visible: edgeHover.hovered && !edgeDrag.active
              ToolTip.delay: 700
              ToolTip.text: "Drag to resize the column"
            }

            // A new card.
            Rectangle {
              id: addRow
              objectName: "boardAdd"
              visible: !bd.readOnly
              x: 8
              y: cardCol.y + cardCol.height + (cardCol.height > 0 ? 6 : 0)
              width: parent.width - 16
              height: bd.readOnly ? 0 : 30
              radius: 6
              color: addHover.hovered ? Qt.alpha(col.colInk, 0.08) : "transparent"
              Row {
                x: 8
                anchors.verticalCenter: parent.verticalCenter
                spacing: 6
                Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: bd.theme ? bd.theme.icons.plus : ""; font.family: bd.theme ? bd.theme.iconFont : ""; font.pixelSize: 13; color: col.colFaint }
                Text { anchors.verticalCenter: parent.verticalCenter; textFormat: Text.PlainText; text: "New"; font.family: bd.editor ? bd.editor.uiFamily : ""; font.pixelSize: 13; color: col.colFaint }
              }
              HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
              TapHandler { onTapped: bd.newCard(col.colId) }
            }
          }
        }
        // Another column.
        Rectangle {
          objectName: "boardAddColumn"
          visible: !bd.readOnly
          width: 36
          height: 36
          radius: 8
          color: addColHover.hovered ? Qt.alpha(bd.ink, 0.06) : "transparent"
          border.width: 1
          border.color: Qt.alpha(bd.ink, 0.1)
          Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: bd.theme ? bd.theme.icons.plus : ""; font.family: bd.theme ? bd.theme.iconFont : ""; font.pixelSize: 15; color: bd.faint }
          HoverHandler { id: addColHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: bd.addColumn() }
          ToolTip.visible: addColHover.hovered
          ToolTip.delay: 500
          ToolTip.text: "Another column"
        }
      }
    }

    // Its bottom edge: dragged, the board taller or shorter (it scrolls
    // inside); a double-click, as tall as its cards again.
    Item {
      objectName: "boardEdge"
      visible: !bd.readOnly
      anchors.bottom: parent.bottom
      anchors.bottomMargin: -4
      z: 3
      width: parent.width
      height: 10
      Rectangle {
        anchors.centerIn: parent
        width: 44
        height: 4
        radius: 2
        color: Qt.alpha(bd.ink, heightHover.hovered || heightDrag.active ? 0.45 : 0.18)
        visible: bd.pointerIn || heightDrag.active
      }
      HoverHandler { id: heightHover; cursorShape: Qt.SizeVerCursor }
      DragHandler {
        id: heightDrag
        target: null
        cursorShape: Qt.SizeVerCursor
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        property real from: 0
        onActiveChanged: {
          if (active) { from = card.height; bd.dragH = from; return }
          var h = Math.round(bd.dragH)
          bd.dragH = -1
          if (h !== (bd.info.height || 0)) bd.change({ height: h })
        }
        onTranslationChanged: if (active) bd.dragH = Math.max(Board.MIN_HEIGHT, Math.min(Board.MAX_HEIGHT, from + translation.y))
      }
      TapHandler { onDoubleTapped: bd.fitHeight() }
      ToolTip.visible: heightHover.hovered && !heightDrag.active
      ToolTip.delay: 700
      ToolTip.text: "Drag to resize the board"
    }

    // The board's own colors.
    IconButton {
      id: boardColors
      objectName: "boardColors"
      visible: !bd.readOnly && (bd.pointerIn || bd.trying !== null)
      anchors.right: parent.right
      anchors.top: parent.top
      anchors.margins: 2
      theme: bd.theme; icon: bd.theme ? bd.theme.icons.palette : ""; size: 26; iconSize: 13; tint: bd.ink
      tip: "The whole board's colors (each card's and column's are on it)"
      onClicked: bd.colorsFor("board", "", boardColors)
    }
  }

  // Where a dragged card would go, and the card, under the pointer.
  Rectangle {
    visible: bd.dropAt !== null
    x: bd.dropAt ? bd.dropAt.x : 0
    y: bd.dropAt ? bd.dropAt.y - 1 : 0
    z: 5
    width: bd.dropAt ? bd.dropAt.w : 0
    height: 3
    radius: 1.5
    color: bd.accent
  }
  Rectangle {
    visible: bd.dragId !== ""
    x: bd.dragPoint.x + 12
    y: bd.dragPoint.y - 16
    z: 6
    width: Math.min(220, ghost.implicitWidth + 20)
    height: 32
    radius: 7
    color: bd.editor ? bd.editor.paper : "white"
    border.width: 1
    border.color: Qt.alpha(bd.ink, 0.2)
    Text {
      id: ghost
      x: 10
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 20
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: { var k = bd.dragId ? Board.card(bd.info, bd.dragId) : null; return k ? k.text || "Untitled" : "" }
      font.family: bd.editor ? bd.editor.family : ""
      font.pixelSize: 14
      color: bd.ink
    }
  }
}
