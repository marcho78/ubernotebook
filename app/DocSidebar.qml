import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import "../Workspace.js" as Workspace
import "../Docs.js" as Docs
import "../Calendar.js" as Calendar
import "../Dates.js" as Dates
import "../Colors.js" as Colors
import "../Sidebar.js" as Sidebar

// The sidebar of Pages. At the top, staying put: the switch back to
// notebooks, the profile, search and a new page, then the calendar, the
// library and people. In the middle, scrolling as one: what's left of today,
// the favorites, the projects (+ makes one; each with the pages in it), the
// tags (a click shows every block with one) and the pages, as a tree (a
// page's arrow shows the pages inside it; + adds one, ⋯ has its menu; drag a
// page to put it before, after or inside another, or on Projects to make it
// a project; a project dragged into Pages is a page again). A click on a
// section's name folds it, and it stays folded. At the foot, small: import,
// templates, the archive, the trash and the settings; then a newer version,
// if there's one, and who makes Uber Notebook, on X.
//
// What's in it is yours (Settings → Appearance → Sidebar, or a right-click
// on it): all of it but Pages and Settings can be left out.
Rectangle {
  id: bar

  property var theme: null
  property var view: null

  // ---- what's in it ------------------------------------------------------------------------

  readonly property var hidden: view.settings.sidebarHidden || []
  readonly property var folded: view.settings.sidebarFolded || []
  function shows(id) { return hidden.indexOf(id) < 0 }
  function isFolded(id) { return folded.indexOf(id) >= 0 }
  function fold(id) { if (view.service) view.service.setSetting("sidebarFolded", Sidebar.toggled(folded, id)) }
  // Left out: the toast says where it comes back from (Undo, at once).
  function hide(id) {
    if (!id || !view.service) return
    view.service.setSetting("sidebarHidden", Sidebar.setIn(hidden, id, true))
    view.toastUndo(Sidebar.label(id) + " is hidden. Settings \u2192 Appearance shows it again.", function() {
      if (bar.view.service) bar.view.service.setSetting("sidebarHidden", Sidebar.setIn(bar.hidden, id, false))
    })
  }

  // A right-click on something in it: hide it, or choose what's in the sidebar.
  property string menuFor: ""
  function openItemMenu(id, anchor) {
    menuFor = id
    // (Under it, or over it when there's no room under it: the foot's.)
    menuRows.forceLayout()
    var h = menuRows.implicitHeight + itemMenu.topPadding + itemMenu.bottomPadding
    var top = anchor.mapToItem(bar, 0, 0)
    itemMenu.x = Math.max(4, Math.min(top.x + 4, bar.width - 60))
    itemMenu.y = top.y + anchor.height + 2 + h > bar.height - 12 ? top.y - h - 2 : top.y + anchor.height + 2
    itemMenu.open()
  }

  // ---- the trees ---------------------------------------------------------------------------

  // The projects' rows and the pages' (without Projects in the sidebar,
  // every page in Pages, where it is). Kept as they are while a page is
  // dragged, so the row being dragged isn't drawn again under the pointer;
  // changed a row at a time (Sidebar.steps), so a title typed redraws its
  // row, not the tree.
  readonly property var liveTrees: {
    var r = view.workspace ? view.workspace.revision : 0
    var o = view.openRows
    return view.workspace ? Workspace.sidebarRows(view.workspace.index, o, new Date(), !shows("projects")) : { projects: [], pages: [] }
  }
  ListModel { id: projectModel }
  ListModel { id: pageModel }
  function takeRows() {
    syncRows(projectModel, liveTrees.projects)
    syncRows(pageModel, liveTrees.pages)
    // (Each row where it goes now, not at the next frame: a drag finds them there.)
    projRows.forceLayout()
    pageRows.forceLayout()
  }
  function syncRows(model, rows) {
    var keys = []
    for (var i = 0; i < model.count; i++) keys.push(model.get(i).rowId)
    var byId = {}
    rows.forEach(function(r) { byId[r.id] = r })
    Sidebar.steps(keys, rows.map(function(r) { return r.id })).forEach(function(s) {
      if (s.op === "remove") model.remove(s.at, 1)
      else if (s.op === "insert") model.insert(s.at, { rowId: s.key, json: JSON.stringify(byId[s.key]) })
      else model.move(s.from, s.to, 1)
    })
    rows.forEach(function(r, n) {
      var json = JSON.stringify(r)
      if (model.get(n).json !== json) model.setProperty(n, "json", json)
    })
  }
  onLiveTreesChanged: if (dragId === "") takeRows()
  Component.onCompleted: { takeRows(); takeTags(); takeFavorites() }
  // How many at the top of each (said by a folded section).
  readonly property int projectTops: liveTrees.projects.filter(function(r) { return r.depth === 0 }).length
  readonly property int pageTops: liveTrees.pages.filter(function(r) { return r.depth === 0 }).length

  // ---- dragging a page ---------------------------------------------------------------------

  property string dragId: ""
  property string dragLabel: ""
  property point dragAt: Qt.point(0, 0)
  // Where it would go: { id, where: "before" | "after" | "inside" | "end" |
  // "project", depth, top, h (of the row), list (the rows), inPages } or null.
  property var drop: null

  function startDrag(row) {
    dragId = row.id
    dragLabel = (row.icon || "\u{1f4c4}") + "  " + (row.title || "Untitled")
    drop = null
  }

  function over(item, p) {
    if (!item.visible || item.height <= 0) return false
    var l = bar.mapToItem(item, p.x, p.y)
    return l.x >= 0 && l.y >= 0 && l.x <= item.width && l.y <= item.height
  }

  // Where among the rows: on a row, before, after or inside it (a project's,
  // inside: the projects keep their order); below Pages' rows, its end.
  function spotIn(list, p, inPages) {
    var q = bar.mapToItem(list, p.x, p.y)
    var item = list.childAt(Math.min(list.width - 2, Math.max(2, q.x)), q.y)
    if (item && item.modelData) {
      var rel = (q.y - item.y) / item.height
      var where = item.modelData.isProject ? "inside" : rel < 0.28 ? "before" : rel > 0.72 ? "after" : "inside"
      return { id: item.modelData.id, where: where, depth: item.modelData.depth, top: item.y, h: item.height, list: list, inPages: inPages }
    }
    if (inPages && q.y >= list.height - 4) {
      var last = pageModel.count ? list.childAt(4, list.height - 4) : null
      return { id: "", where: "end", depth: 0, top: last ? last.y : 0, h: last ? last.height : 0, list: list, inPages: true }
    }
    return null
  }

  function moveDrag(p) {
    dragAt = p
    var spot = null
    if (over(mid, p)) {
      if (over(projHead, p) || over(projEmpty, p)) spot = { id: "", where: "project", depth: 0, top: 0, h: 0, list: null, inPages: false }
      else if (over(projRows, p)) spot = spotIn(projRows, p, false)
      // On Pages' name: the end of it (folded too).
      else if (over(pagesHead, p)) spot = { id: "", where: "end", depth: 0, top: 0, h: 0, list: null, inPages: true }
      else if (pageRows.visible && bar.mapToItem(pageRows, p.x, p.y).y >= 0) spot = spotIn(pageRows, p, true)
    }
    var ix = view.workspace.index
    if (spot && (spot.where === "project" ? !!ix.pages[dragId].project : !Workspace.dropPlace(ix, dragId, spot.id, spot.where))) spot = null
    drop = spot
    // Near the top or the bottom of the middle: it scrolls.
    var edge = bar.mapToItem(mid, p.x, p.y).y
    scroller.dir = edge < 24 ? -1 : edge > mid.height - 24 ? 1 : 0
  }

  function endDrag(dropped) {
    var id = dragId
    var spot = drop
    dragId = ""
    drop = null
    scroller.dir = 0
    takeRows()
    if (dropped && id && spot) view.dropPage(id, spot.id, spot.where, spot.inPages === true)
  }

  Timer {
    id: scroller
    property int dir: 0
    interval: 30
    repeat: true
    running: dir !== 0 && bar.dragId !== ""
    onTriggered: {
      mid.contentY = Math.max(0, Math.min(Math.max(0, mid.contentHeight - mid.height), mid.contentY + dir * 8))
      bar.moveDrag(bar.dragAt)
    }
  }

  // ---- the rest of what it shows -----------------------------------------------------------

  // The favorites (the pages starred), and the tags, by name (a tag inside
  // another after it) or by color, as Settings has it: taken again only when
  // they change (not as each title is typed).
  readonly property var favorites: {
    var r = view.workspace ? view.workspace.revision : 0
    return view.workspace ? Workspace.favorites(view.workspace.index) : []
  }
  property var favIds: []
  function takeFavorites() { if (JSON.stringify(favorites) !== JSON.stringify(favIds)) favIds = favorites }
  onFavoritesChanged: takeFavorites()

  readonly property string tagSort: view.settings.tagSort === "color" ? "color" : "name"
  readonly property var tagList: {
    var r = view.workspace ? view.workspace.revision : 0
    var k = view.tagColorsKey
    return view.workspace ? Workspace.sortTags(Workspace.tagList(view.workspace.index), view.tagColorsShown, bar.tagSort) : []
  }
  property var tagChips: []
  function takeTags() { if (JSON.stringify(tagList) !== JSON.stringify(tagChips)) tagChips = tagList }
  onTagListChanged: takeTags()
  // Every tag shown, not just the first rows of them.
  property bool allTags: false

  readonly property int templateCount: {
    var r = view.workspace ? view.workspace.revision : 0
    return view.workspace ? Workspace.templates(view.workspace.index).length : 0
  }
  readonly property int archiveCount: {
    var r = view.workspace ? view.workspace.revision : 0
    return view.workspace ? Workspace.archived(view.workspace.index).length : 0
  }
  readonly property int trashCount: {
    var r = view.workspace ? view.workspace.revision : 0
    return view.workspace ? Workspace.trashed(view.workspace.index).length : 0
  }
  readonly property int libraryCount: {
    var r = view.workspace ? view.workspace.revision : 0
    return view.workspace ? Workspace.collected(view.workspace.index).length : 0
  }
  readonly property int peopleCount: {
    var r = view.workspace ? view.workspace.contactsRevision : 0
    return view.workspace ? view.workspace.contacts.contacts.length : 0
  }

  // Today: what's left of it on the calendar, soonest first.
  property real nowMs: Date.now()
  Timer { interval: 60000; repeat: true; running: true; onTriggered: bar.nowMs = Date.now() }
  readonly property var todayLeft: {
    var r = view.workspace ? view.workspace.calendarRevision : 0
    var n = new Date(nowMs)
    var lo = new Date(n.getFullYear(), n.getMonth(), n.getDate())
    var hi = new Date(lo.getFullYear(), lo.getMonth(), lo.getDate() + 1)
    return view.workspace ? Calendar.occurrences(view.workspace.calendar, lo, hi).filter(function(o) { return o.end > n }) : []
  }
  function eventTint(c) {
    var e = c ? Docs.colorEntry(c) : null
    return e ? e.text[theme.dark ? 1 : 0] : c && Colors.isHex(c) ? Colors.normalize(c) : theme.accent
  }

  color: theme.sidebar

  Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: bar.theme.line }

  // ---- its parts ---------------------------------------------------------------------------

  // A card behind the top or the foot, when sections are cards (Settings →
  // Appearance, Sections and cards: a color of their own).
  component SectionCard: Rectangle {
    property Item target: null
    property real above: 6
    property real below: 6
    visible: bar.theme.cardsShown && target !== null && target.visible && target.height > 0
    x: 4
    y: target ? target.y - above : 0
    width: bar.width - 9
    height: target ? target.height + above + below : 0
    radius: 10
    color: bar.theme.surface
    border.width: 1
    border.color: bar.theme.line
  }

  // A tooltip in the theme's colors, above what it's on.
  component Tip: ToolTip {
    id: tip
    property bool shown: false
    visible: shown && text !== ""
    delay: 600
    timeout: 5000
    y: -implicitHeight - 6
    x: parent ? (parent.width - implicitWidth) / 2 : 0
    padding: 6
    leftPadding: 9
    rightPadding: 9
    contentItem: Text {
      textFormat: Text.PlainText
      text: tip.text
      font.family: bar.theme.uiFont
      font.pixelSize: 12
      color: bar.theme.text
    }
    background: Rectangle {
      radius: 7
      color: bar.theme.surfaceHigh
      border.width: 1
      border.color: bar.theme.line
    }
  }

  component Row2: Rectangle {
    id: r2
    property string icon: ""
    property string text: ""
    property string hint: ""
    signal clicked()
    width: parent ? parent.width : 200
    height: 30
    radius: 6
    color: rowHover.hovered ? bar.theme.hover : "transparent"
    Icon {
      theme: bar.theme
      x: 12
      anchors.verticalCenter: parent.verticalCenter
      text: r2.icon
      size: 15
      color: bar.theme.muted
    }
    Text {
      textFormat: Text.PlainText
      x: r2.icon ? 38 : 12
      anchors.verticalCenter: parent.verticalCenter
      text: r2.text
      font.family: bar.theme.uiFont
      font.pixelSize: 13
      color: r2.icon ? bar.theme.text : bar.theme.muted
      opacity: 0.85
    }
    Text {
      textFormat: Text.PlainText
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      text: r2.hint
      font.family: bar.theme.uiFont
      font.pixelSize: 11
      color: bar.theme.faint
    }
    HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: r2.clicked() }
  }

  // The calendar, the library, people: side by side, each its icon over its name.
  component NavTile: Rectangle {
    id: tile
    property string itemId: ""
    property string icon: ""
    property string text: ""
    property string tip: ""
    property bool checked: false
    signal clicked()
    height: 50
    radius: 8
    color: checked ? bar.theme.pressed : tileHover.hovered ? bar.theme.hover : Qt.alpha(bar.theme.text, 0.035)
    Column {
      anchors.centerIn: parent
      spacing: 4
      Icon {
        anchors.horizontalCenter: parent.horizontalCenter
        theme: bar.theme
        text: tile.icon
        size: 18
        color: tile.checked || tileHover.hovered ? bar.theme.text : bar.theme.muted
      }
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: tile.text
        font.family: bar.theme.uiFont
        font.pixelSize: 11
        font.weight: tile.checked ? Font.DemiBold : Font.Normal
        color: tile.checked || tileHover.hovered ? bar.theme.text : bar.theme.muted
      }
    }
    HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: tile.clicked() }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: bar.openItemMenu(tile.itemId, tile) }
    Tip { shown: tileHover.hovered; text: tile.tip }
  }

  // A small button at the foot: its icon, and how many there are in it.
  component FootButton: Rectangle {
    id: fb
    property string itemId: ""
    property string icon: ""
    property string tip: ""
    property int count: 0
    property bool checked: false
    signal clicked()
    width: fbRow.implicitWidth + 16
    height: 30
    radius: 7
    color: checked ? bar.theme.pressed : fbHover.hovered ? bar.theme.hover : "transparent"
    Row {
      id: fbRow
      anchors.centerIn: parent
      spacing: 4
      Icon {
        anchors.verticalCenter: parent.verticalCenter
        theme: bar.theme
        text: fb.icon
        size: 16
        color: fb.checked || fbHover.hovered ? bar.theme.text : bar.theme.muted
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        visible: fb.count > 0
        textFormat: Text.PlainText
        text: String(fb.count)
        font.family: bar.theme.uiFont
        font.pixelSize: 11
        color: bar.theme.faint
      }
    }
    HoverHandler { id: fbHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: fb.clicked() }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: bar.openItemMenu(fb.itemId, fb) }
    Tip { shown: fbHover.hovered; text: fb.tip }
  }

  // A section's name: a click folds it (and opens it again); folded, how
  // many are in it. What it has at the right (+, the tags' order) is its own.
  component SectionHead: Rectangle {
    id: sh
    // Its name in sidebarFolded, and what Hide leaves out ("": can't be).
    property string fold: ""
    property string itemId: ""
    property string label: ""
    property string count: ""
    // A page dragged here goes here.
    property bool lit: false
    default property alias tools: toolsRow.data
    readonly property bool shut: fold !== "" && bar.isFolded(fold)
    width: parent ? parent.width : 200
    height: 26
    radius: 6
    color: lit ? Qt.alpha(bar.theme.accent, 0.18) : headHover.hovered && bar.dragId === "" ? bar.theme.hover : "transparent"
    border.width: lit ? 1.5 : 0
    border.color: bar.theme.accent
    Text {
      id: shLabel
      x: 12
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: sh.label
      font.family: bar.theme.uiFont
      font.pixelSize: 11
      font.weight: Font.DemiBold
      font.letterSpacing: 0.4
      color: sh.lit ? bar.theme.accent : bar.theme.muted
    }
    Icon {
      id: shArrow
      anchors.left: shLabel.right
      anchors.leftMargin: 4
      anchors.verticalCenter: parent.verticalCenter
      theme: bar.theme
      text: sh.shut ? bar.theme.icons.right : bar.theme.icons.down
      size: 12
      color: bar.theme.muted
      visible: sh.fold !== "" && (sh.shut || headHover.hovered && bar.dragId === "")
    }
    Text {
      anchors.left: shArrow.right
      anchors.leftMargin: 2
      anchors.verticalCenter: parent.verticalCenter
      visible: sh.shut && sh.count !== ""
      textFormat: Text.PlainText
      text: sh.count
      font.family: bar.theme.uiFont
      font.pixelSize: 11
      color: bar.theme.faint
    }
    Row {
      id: toolsRow
      anchors.right: parent.right
      anchors.rightMargin: 2
      anchors.verticalCenter: parent.verticalCenter
      spacing: 2
    }
    HoverHandler { id: headHover; cursorShape: sh.fold !== "" ? Qt.PointingHandCursor : Qt.ArrowCursor }
    // (Not a click on what's at its right, which has its own.)
    TapHandler {
      onTapped: function(point) {
        if (toolsRow.contains(toolsRow.mapFromItem(sh, point.position.x, point.position.y))) return
        if (sh.fold !== "") bar.fold(sh.fold)
      }
    }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: bar.openItemMenu(sh.itemId, sh) }
  }

  // A section of the middle, on a card when sections are cards.
  component Section: Item {
    id: sec
    default property alias content: secCol.data
    readonly property real pad: bar.theme.cardsShown ? 6 : 0
    width: parent ? parent.width : 200
    height: secCol.height + pad * 2
    Rectangle {
      objectName: "sectionCard"
      visible: bar.theme.cardsShown
      x: -4
      width: parent.width + 8
      height: parent.height
      radius: 10
      color: bar.theme.surface
      border.width: 1
      border.color: bar.theme.line
    }
    Column {
      id: secCol
      y: sec.pad
      width: parent.width
    }
  }

  // A page's row in the trees: its arrow (the pages inside it), its icon
  // and title; hovered, ⋯ (its menu) and + (a page inside it). A project's
  // says when it's due (late in red) and has its progress, as a ring round
  // its status color. Dragged: before, after or inside another.
  component TreeRow: Rectangle {
    id: rowItem
    required property string rowId
    required property string json
    property bool inPages: true
    readonly property var modelData: JSON.parse(json)
    readonly property bool isProject: modelData.isProject === true
    readonly property bool current: bar.view.page !== null && bar.view.page.id === modelData.id
    readonly property bool dropInside: bar.drop !== null && bar.drop.where === "inside" && bar.drop.id === modelData.id
    readonly property var status: isProject ? Workspace.statusOf(modelData.status) : null
    readonly property var due: isProject && modelData.due ? Workspace.dueInfo(modelData.due, new Date()) : null
    objectName: isProject ? "projectRow" : inPages ? "pageRow" : "projectPageRow"
    width: parent ? parent.width : 200
    height: 30
    radius: 6
    opacity: bar.dragId === modelData.id ? 0.4 : 1
    color: dropInside ? Qt.alpha(bar.theme.accent, 0.18) : current ? bar.theme.pressed : treeHover.hovered && bar.dragId === "" ? bar.theme.hover : "transparent"
    border.width: dropInside ? 1.5 : 0
    border.color: bar.theme.accent

    DragHandler {
      id: rowDrag
      target: null
      dragThreshold: 6
      grabPermissions: PointerHandler.CanTakeOverFromAnything
      onActiveChanged: {
        if (active) bar.startDrag(rowItem.modelData)
        else bar.endDrag(true)
      }
      onCentroidChanged: if (active) bar.moveDrag(rowItem.mapToItem(bar, centroid.position.x, centroid.position.y))
      onCanceled: bar.endDrag(false)
    }

    // The arrow: the pages inside it, shown or not.
    Rectangle {
      id: arrow
      x: 4 + rowItem.modelData.depth * 14
      anchors.verticalCenter: parent.verticalCenter
      width: 20
      height: 20
      radius: 4
      color: arrowHover.hovered ? bar.theme.pressed : "transparent"
      visible: rowItem.modelData.hasChildren || treeHover.hovered
      Icon {
        anchors.centerIn: parent
        theme: bar.theme
        text: rowItem.modelData.open ? bar.theme.icons.down : bar.theme.icons.right
        size: 14
        color: bar.theme.muted
        opacity: rowItem.modelData.hasChildren ? 1 : 0.35
      }
      HoverHandler { id: arrowHover; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: bar.view.toggleRow(rowItem.modelData.id) }
    }
    Text {
      id: rowIcon
      textFormat: Text.PlainText
      x: arrow.x + 22
      anchors.verticalCenter: parent.verticalCenter
      text: rowItem.modelData.icon || "\u{1f4c4}"
      font.family: "Noto Color Emoji"
      font.pixelSize: 14
      opacity: rowItem.modelData.icon ? 1 : 0.7
    }
    Text {
      textFormat: Text.PlainText
      x: rowIcon.x + 24
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - x - (treeHover.hovered ? 56 : projectInfo.item ? projectInfo.item.width + 14 : 8)
      elide: Text.ElideRight
      text: rowItem.modelData.title || "Untitled"
      font.family: bar.theme.uiFont
      font.pixelSize: 13
      font.weight: rowItem.current ? Font.DemiBold : Font.Normal
      color: !rowItem.modelData.title || rowItem.isProject && (rowItem.modelData.status === "paused" || rowItem.modelData.status === "done") ? bar.theme.muted : bar.theme.text
    }

    // A project's: when it's due (not once it's done), and its ring (its
    // status's color; full, done).
    Loader {
      id: projectInfo
      active: rowItem.isProject
      visible: !treeHover.hovered
      anchors.right: parent.right
      anchors.rightMargin: 9
      anchors.verticalCenter: parent.verticalCenter
      sourceComponent: Row {
        spacing: 7
        Text {
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: rowItem.due && rowItem.modelData.status !== "done" ? rowItem.due.label : ""
          visible: text !== ""
          font.family: bar.theme.uiFont
          font.pixelSize: 11
          font.weight: rowItem.modelData.overdue ? Font.DemiBold : Font.Normal
          color: rowItem.modelData.overdue ? (Docs.colorEntry("red").text[bar.theme.dark ? 1 : 0]) : bar.theme.faint
        }
        Item {
          id: ring
          anchors.verticalCenter: parent.verticalCenter
          width: 14
          height: 14
          readonly property real part: rowItem.modelData.progress && rowItem.modelData.progress.total ? rowItem.modelData.progress.done / rowItem.modelData.progress.total : rowItem.modelData.status === "done" ? 1 : 0
          readonly property var shades: rowItem.status ? Docs.colorEntry(rowItem.status.color) : null
          readonly property color tint: shades ? shades.text[bar.theme.dark ? 1 : 0] : bar.theme.muted
          Rectangle { anchors.fill: parent; radius: 7; color: "transparent"; border.width: 2; border.color: Qt.alpha(ring.tint, 0.3) }
          Shape {
            anchors.fill: parent
            visible: ring.part > 0
            preferredRendererType: Shape.CurveRenderer
            ShapePath {
              strokeColor: ring.tint
              strokeWidth: 2
              fillColor: "transparent"
              capStyle: ShapePath.RoundCap
              PathAngleArc { centerX: 7; centerY: 7; radiusX: 6; radiusY: 6; startAngle: -90; sweepAngle: 360 * Math.min(1, ring.part) }
            }
          }
        }
      }
    }

    // Hovered: its menu, and a page inside it.
    Loader {
      active: treeHover.hovered
      anchors.right: parent.right
      anchors.rightMargin: 2
      anchors.verticalCenter: parent.verticalCenter
      sourceComponent: Row {
        IconButton {
          theme: bar.theme; icon: bar.theme.icons.more; size: 24; iconSize: 14; tip: "Delete, move\u2026"
          onClicked: bar.view.openRowMenu(rowItem.modelData.id, rowItem)
        }
        IconButton {
          theme: bar.theme; icon: bar.theme.icons.plus; size: 24; iconSize: 14; tip: "A page inside it"
          onClicked: bar.view.newPage(rowItem.modelData.id)
        }
      }
    }
    HoverHandler { id: treeHover }
    TapHandler { onTapped: bar.view.open(rowItem.modelData.id) }
    ToolTip.visible: rowItem.isProject && treeHover.hovered && bar.dragId === ""
    ToolTip.delay: 700
    ToolTip.text: !rowItem.isProject ? "" : rowItem.status.label + (rowItem.due ? "  \u00b7  " + (rowItem.modelData.overdue ? rowItem.due.label : "due " + rowItem.due.label) : "")
      + "  \u00b7  " + rowItem.modelData.progress.done + " of " + rowItem.modelData.progress.total + " to-dos"
  }

  // The top's card and the foot's (under them), when sections are cards.
  SectionCard { objectName: "sectionCard"; target: head; above: 4; below: 4 }
  SectionCard { objectName: "sectionCard"; target: foot; above: -2; below: 4 }

  // ---- at the top, staying put -------------------------------------------------------------

  Column {
    id: head
    x: 8
    y: 10
    width: parent.width - 16
    spacing: 6

    Item {
      width: parent.width
      height: 40
      SpaceSwitch {
        theme: bar.theme
        space: "pages"
        anchors.verticalCenter: parent.verticalCenter
        x: 4
        onPicked: function(space) { if (space === "notebooks") bar.view.notebooksRequested() }
      }
      IconButton {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        theme: bar.theme
        icon: bar.theme.icons.hideSidebar
        size: 28
        iconSize: 15
        tip: "Hide the sidebar  Ctrl+\\"
        onClicked: bar.view.sidebarShown = false
      }
    }
    // The profile open, and the others.
    ProfileSwitch {
      visible: bar.view.service !== null && bar.view.service.profiles !== undefined && bar.view.service.profiles !== null
      theme: bar.theme
      service: bar.view.service
      wide: true
      width: parent.width
      onManageRequested: bar.view.settingsRequested()
    }
    // Search, and a new page (without search, a row of its own).
    Item {
      width: parent.width
      height: 32
      Rectangle {
        id: searchBox
        objectName: "searchRow"
        visible: bar.shows("search")
        width: parent.width - newPageButton.width - 6
        height: parent.height
        radius: 8
        color: searchHover.hovered ? bar.theme.hover : "transparent"
        border.width: 1
        border.color: bar.theme.line
        Icon {
          x: 10
          anchors.verticalCenter: parent.verticalCenter
          theme: bar.theme
          text: bar.theme.icons.search
          size: 15
          color: bar.theme.muted
        }
        Text {
          x: 32
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "Search"
          font.family: bar.theme.uiFont
          font.pixelSize: 13
          color: bar.theme.muted
        }
        Text {
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: "Ctrl+P"
          font.family: bar.theme.uiFont
          font.pixelSize: 11
          color: bar.theme.faint
        }
        HoverHandler { id: searchHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: bar.view.openFind() }
        TapHandler { acceptedButtons: Qt.RightButton; onTapped: bar.openItemMenu("search", searchBox) }
      }
      Rectangle {
        id: newPageButton
        objectName: "newPageButton"
        visible: bar.shows("search")
        anchors.right: parent.right
        width: 32
        height: 32
        radius: 8
        color: newHover.hovered ? bar.theme.hover : "transparent"
        border.width: 1
        border.color: bar.theme.line
        Icon {
          anchors.centerIn: parent
          theme: bar.theme
          text: bar.theme.icons.newPage
          size: 16
          color: newHover.hovered ? bar.theme.text : bar.theme.muted
        }
        HoverHandler { id: newHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: bar.view.newPage("") }
        Tip { shown: newHover.hovered; text: "New page  Ctrl+N" }
      }
      Row2 {
        objectName: "newPageRow"
        visible: !bar.shows("search")
        icon: bar.theme.icons.newPage
        text: "New page"
        hint: "Ctrl+N"
        onClicked: bar.view.newPage("")
      }
    }
    // The calendar, the library and people.
    Row {
      id: navRow
      readonly property int shown: (bar.shows("calendar") ? 1 : 0) + (bar.shows("library") ? 1 : 0) + (bar.shows("people") ? 1 : 0)
      readonly property real tileW: shown ? (width - spacing * (shown - 1)) / shown : 0
      visible: shown > 0
      width: parent.width
      spacing: 4
      NavTile {
        objectName: "calendarTile"
        visible: bar.shows("calendar")
        width: navRow.tileW
        itemId: "calendar"
        icon: bar.theme.icons.calendarMonth
        text: "Calendar"
        tip: Dates.SHORT_DAYS[new Date(bar.nowMs).getDay()] + " " + new Date(bar.nowMs).getDate() + (bar.todayLeft.length === 1 ? ", 1 event left today" : bar.todayLeft.length > 1 ? ", " + bar.todayLeft.length + " events left today" : "")
        checked: bar.view.calendarShown
        onClicked: bar.view.openCalendar("")
      }
      NavTile {
        objectName: "libraryTile"
        visible: bar.shows("library")
        width: navRow.tileW
        itemId: "library"
        icon: bar.theme.icons.library
        text: "Library"
        tip: bar.libraryCount === 1 ? "1 item" : bar.libraryCount > 1 ? bar.libraryCount + " items" : "Nothing in it yet"
        checked: bar.view.libraryShown
        onClicked: bar.view.openLibrary("")
      }
      NavTile {
        objectName: "peopleTile"
        visible: bar.shows("people")
        width: navRow.tileW
        itemId: "people"
        icon: bar.theme.icons.contacts
        text: "People"
        tip: bar.peopleCount === 1 ? "1 person" : bar.peopleCount > 1 ? bar.peopleCount + " people" : "No one yet"
        checked: bar.view.peopleShown
        onClicked: bar.view.openPeople("")
      }
    }
  }

  // ---- the middle, scrolling as one --------------------------------------------------------

  Flickable {
    id: mid
    objectName: "sidebarMiddle"
    anchors.top: head.bottom
    anchors.topMargin: bar.theme.cardsShown ? 10 : 12
    anchors.bottom: foot.top
    anchors.bottomMargin: 4
    width: parent.width - 1
    contentWidth: width
    contentHeight: secs.height + 16
    interactive: false
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    onContentHeightChanged: if (contentY > Math.max(0, contentHeight - height)) contentY = Math.max(0, contentHeight - height)
    Behavior on contentY { enabled: midScroll.animate && bar.dragId === ""; NumberAnimation { duration: 120; easing.type: Easing.OutCubic } }
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

    Column {
      id: secs
      x: 8
      y: 4
      width: bar.width - 16
      spacing: bar.theme.cardsShown ? 10 : 14

      // What's left of today.
      Section {
        id: todaySec
        objectName: "sidebarToday"
        visible: bar.shows("today") && bar.todayLeft.length > 0
        SectionHead { fold: "today"; itemId: "today"; label: "Today"; count: String(bar.todayLeft.length) }
        Item { width: 1; height: 2 }
        Repeater {
          model: bar.isFolded("today") ? [] : bar.todayLeft.slice(0, 4)
          delegate: Rectangle {
            id: trow
            required property var modelData
            readonly property bool now: !modelData.allDay && modelData.start <= new Date(bar.nowMs)
            readonly property real soon: (modelData.start - bar.nowMs) / 60000
            objectName: "todayRow"
            width: parent ? parent.width : 200
            height: 30
            radius: 6
            color: trowHover.hovered ? bar.theme.hover : "transparent"
            Rectangle { x: 12; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 16; radius: 1.5; color: bar.eventTint(trow.modelData.color) }
            Text {
              id: tWhen
              x: 22
              anchors.verticalCenter: parent.verticalCenter
              width: 44
              textFormat: Text.PlainText
              text: trow.modelData.allDay ? "All day" : trow.now ? "Now" : Calendar.timeLabel(trow.modelData.start)
              font.family: bar.theme.uiFont
              font.pixelSize: 11
              font.weight: trow.now || trow.soon <= 15 && !trow.modelData.allDay ? Font.DemiBold : Font.Normal
              font.features: { "tnum": 1 }
              color: trow.now ? (bar.theme.dark ? "#ff6b6b" : "#e5484d") : bar.theme.muted
            }
            Text {
              x: tWhen.x + tWhen.width + 4
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - x - 8
              elide: Text.ElideRight
              textFormat: Text.PlainText
              text: (trow.modelData.title || "Untitled") + (!trow.modelData.allDay && !trow.now && trow.soon > 0 && trow.soon <= 60 ? "  \u00b7  in " + Math.max(1, Math.round(trow.soon)) + " min" : "")
              font.family: bar.theme.uiFont
              font.pixelSize: 13
              color: bar.theme.text
            }
            HoverHandler { id: trowHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: bar.view.openEvent(trow.modelData.id, trow.modelData.day, trow) }
          }
        }
        Row2 {
          visible: !bar.isFolded("today") && bar.todayLeft.length > 4
          text: (bar.todayLeft.length - 4) + " more today"
          onClicked: bar.view.openCalendar("")
        }
      }

      // The pages starred.
      Section {
        id: favSec
        objectName: "sidebarFavorites"
        visible: bar.shows("favorites") && bar.favIds.length > 0
        SectionHead { fold: "favorites"; itemId: "favorites"; label: "Favorites"; count: String(bar.favIds.length) }
        Item { width: 1; height: 2 }
        Repeater {
          model: bar.isFolded("favorites") ? [] : bar.favIds
          delegate: Rectangle {
            id: favRow
            required property var modelData
            readonly property var e: { var r = bar.view.workspace ? bar.view.workspace.revision : 0; return bar.view.workspace.index.pages[modelData] || ({ title: "", icon: "" }) }
            readonly property bool current: bar.view.page !== null && bar.view.page.id === modelData
            objectName: "favoriteRow"
            width: parent ? parent.width : 200
            height: 30
            radius: 6
            color: current ? bar.theme.pressed : favHover.hovered ? bar.theme.hover : "transparent"
            Text {
              textFormat: Text.PlainText
              x: 12
              anchors.verticalCenter: parent.verticalCenter
              text: favRow.e.icon || "\u{1f4c4}"
              font.family: "Noto Color Emoji"
              font.pixelSize: 14
            }
            Text {
              textFormat: Text.PlainText
              x: 36
              anchors.verticalCenter: parent.verticalCenter
              width: parent.width - x - 8
              elide: Text.ElideRight
              text: favRow.e.title || "Untitled"
              font.family: bar.theme.uiFont
              font.pixelSize: 13
              font.weight: favRow.current ? Font.DemiBold : Font.Normal
              color: bar.theme.text
            }
            HoverHandler { id: favHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: bar.view.open(favRow.modelData) }
          }
        }
      }

      // Projects: + makes one (a page dragged here is one too), what's on
      // now first, late first; each with the pages in it.
      Section {
        id: projectsSec
        objectName: "sidebarProjects"
        visible: bar.shows("projects")
        SectionHead {
          id: projHead
          objectName: "projectsHead"
          fold: "projects"
          itemId: "projects"
          label: bar.dragId !== "" && projectModel.count > 0 && !(bar.view.workspace.index.pages[bar.dragId] || {}).project ? "Projects  \u00b7  drop to make it one" : "Projects"
          count: String(bar.projectTops)
          lit: bar.drop !== null && bar.drop.where === "project"
          IconButton {
            objectName: "newProject"
            theme: bar.theme; icon: bar.theme.icons.plus; size: 22; iconSize: 14; tint: bar.theme.muted; tip: "New project"
            onClicked: bar.view.newProject()
          }
        }
        Item { width: 1; height: 2 }
        // None yet: a new one, here (or a page dragged here).
        Rectangle {
          id: projEmpty
          objectName: "projectsEmpty"
          visible: !bar.isFolded("projects") && projectModel.count === 0
          width: parent.width
          height: 30
          radius: 6
          color: emptyHover.hovered && bar.dragId === "" ? bar.theme.hover : "transparent"
          Icon {
            theme: bar.theme
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            text: bar.theme.icons.plus
            size: 14
            color: bar.theme.faint
          }
          Text {
            textFormat: Text.PlainText
            x: 38
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 8
            elide: Text.ElideRight
            text: bar.dragId !== "" ? "Drop it here: a project" : "New project"
            font.family: bar.theme.uiFont
            font.pixelSize: 13
            color: bar.theme.muted
          }
          HoverHandler { id: emptyHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: bar.view.newProject() }
        }
        Column {
          id: projRows
          visible: !bar.isFolded("projects")
          width: parent.width
          Repeater { model: projectModel; delegate: TreeRow { inPages: false } }
        }
      }

      // The tags, as chips in their colors: a few rows of them, and Show all.
      Section {
        id: tagsSec
        objectName: "sidebarTags"
        visible: bar.shows("tags") && bar.tagChips.length > 0
        SectionHead {
          fold: "tags"
          itemId: "tags"
          label: "Tags"
          count: String(bar.tagChips.length)
          // By name or by color.
          Rectangle {
            id: sortButton
            objectName: "tagSort"
            visible: !bar.isFolded("tags")
            width: sortText.implicitWidth + 12
            height: 20
            radius: 10
            color: sortHover.hovered ? bar.theme.pressed : "transparent"
            Text {
              id: sortText
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: bar.tagSort === "color" ? "By color" : "A\u2013Z"
              font.family: bar.theme.uiFont
              font.pixelSize: 10
              color: bar.theme.muted
            }
            HoverHandler { id: sortHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
              gesturePolicy: TapHandler.ReleaseWithinBounds
              onTapped: if (bar.view.service) bar.view.service.setSetting("tagSort", bar.tagSort === "color" ? "name" : "color")
            }
            Tip { shown: sortHover.hovered; text: bar.tagSort === "color" ? "Sorted by color: click for A\u2013Z" : "Sorted by name: click to sort by color" }
          }
        }
        Item { width: 1; height: 4 }
        Item {
          id: chipsBox
          visible: !bar.isFolded("tags")
          // Four rows of them, and Show all for the rest (all of them, if
          // they'd take five at most).
          readonly property real rowsH: 4 * 26 + 3 * 6
          readonly property bool long: chipFlow.height > 5 * 26 + 4 * 6 + 1
          width: parent.width
          height: chipClip.height + (long ? moreTags.height + 6 : 0) + 2
          Item {
            id: chipClip
            width: parent.width
            height: chipsBox.long && !bar.allTags ? chipsBox.rowsH : chipFlow.height
            clip: chipsBox.long && !bar.allTags
            Flow {
              id: chipFlow
              x: 6
              width: parent.width - 8
              spacing: 6
              Repeater {
                model: bar.tagChips
                delegate: Rectangle {
                  id: chip
                  required property var modelData
                  readonly property bool current: bar.view.tagShown === modelData.name
                  readonly property var look: { var k = bar.view.tagColorsKey; return bar.view.tagLook(modelData.name) }
                  objectName: "tagChip"
                  width: Math.min(chipFlow.width, chipRow.implicitWidth + 18)
                  height: 26
                  radius: 13
                  color: current ? bar.theme.pressed : chipHover.hovered ? bar.theme.hover : "transparent"
                  border.width: 1
                  border.color: current ? Qt.alpha(bar.theme.text, 0.3) : bar.theme.line
                  Row {
                    id: chipRow
                    x: 9
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 6
                    Rectangle {
                      anchors.verticalCenter: parent.verticalCenter
                      width: 8
                      height: 8
                      radius: 4
                      color: chip.look.color
                    }
                    Text {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Math.min(implicitWidth, chipFlow.width - 64)
                      elide: Text.ElideRight
                      textFormat: Text.PlainText
                      text: chip.modelData.label
                      font.family: bar.theme.uiFont
                      font.pixelSize: 12
                      font.weight: chip.current ? Font.DemiBold : Font.Normal
                      color: bar.theme.text
                    }
                    // How many blocks have it; hovered, its menu, there.
                    Item {
                      anchors.verticalCenter: parent.verticalCenter
                      width: Math.max(10, chipCount.implicitWidth)
                      height: 18
                      Text {
                        id: chipCount
                        anchors.centerIn: parent
                        visible: !chipHover.hovered
                        textFormat: Text.PlainText
                        text: String(chip.modelData.blocks)
                        font.family: bar.theme.uiFont
                        font.pixelSize: 11
                        color: bar.theme.faint
                      }
                      Loader {
                        id: chipMore
                        anchors.centerIn: parent
                        active: chipHover.hovered
                        sourceComponent: IconButton {
                          objectName: "tagMore"
                          theme: bar.theme; icon: bar.theme.icons.more; size: 18; iconSize: 13; tint: bar.theme.muted; tip: "Color, rename\u2026"
                          onClicked: bar.view.openTagMenu(chip.modelData.name, chip)
                        }
                      }
                    }
                  }
                  HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
                  // (Not a click on its ⋯, which has its own.)
                  TapHandler {
                    onTapped: function(point) {
                      var more = chipMore.item
                      if (more && more.contains(more.mapFromItem(chip, point.position.x, point.position.y))) return
                      bar.view.openTag(chip.modelData.name)
                    }
                  }
                  // A right-click: its menu.
                  TapHandler {
                    acceptedButtons: Qt.RightButton
                    onTapped: bar.view.openTagMenu(chip.modelData.name, chip)
                  }
                }
              }
            }
          }
          Text {
            id: moreTags
            objectName: "tagsMore"
            visible: chipsBox.long
            x: 8
            y: chipClip.height + 6
            textFormat: Text.PlainText
            text: bar.allTags ? "Show fewer" : "Show all " + bar.tagChips.length
            font.family: bar.theme.uiFont
            font.pixelSize: 11
            font.underline: moreHover.hovered
            color: bar.theme.muted
            HoverHandler { id: moreHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: bar.allTags = !bar.allTags }
          }
        }
      }

      // The pages.
      Section {
        id: pagesSec
        objectName: "sidebarPages"
        SectionHead {
          id: pagesHead
          objectName: "pagesHead"
          fold: "pages"
          label: "Pages"
          count: String(bar.pageTops)
          lit: bar.drop !== null && bar.drop.where === "end" && bar.drop.list === null
        }
        Item { width: 1; height: 2 }
        Column {
          id: pageRows
          visible: !bar.isFolded("pages")
          width: parent.width
          Repeater { model: pageModel; delegate: TreeRow { inPages: true } }
        }
        Text {
          visible: !bar.isFolded("pages") && pageModel.count === 0 && projectModel.count === 0 && bar.view.workspace !== null && bar.view.workspace.ready
          x: 12
          width: parent.width - 24
          topPadding: 4
          wrapMode: Text.Wrap
          textFormat: Text.PlainText
          text: "No pages yet. Make one with New page."
          font.family: bar.theme.uiFont
          font.pixelSize: 12
          color: bar.theme.muted
        }
      }
    }
  }
  // A trackpad as the fingers move (and on, gliding); a wheel a step a notch.
  WheelHandler {
    target: null
    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
    onWheel: function(event) { midScroll.wheel(event) }
  }
  SmoothScroll { id: midScroll; flick: mid; step: 60; notchMs: 120; speed: bar.view.settings.scrollSpeed || "normal" }

  // Where a dragged page would go: a line before or after a page (as deep
  // as it), or the page it goes inside lit up; and the page, under the pointer.
  Rectangle {
    id: dropLine
    objectName: "dropLine"
    readonly property bool shown: bar.drop !== null && bar.drop.list !== null && bar.drop.where !== "inside" && bar.drop.where !== "project"
    readonly property var p: shown ? bar.drop.list.mapToItem(bar, 0, bar.drop.where === "before" ? bar.drop.top : bar.drop.top + bar.drop.h) : Qt.point(0, 0)
    visible: shown && p.y >= mid.y - 1 && p.y <= mid.y + mid.height + 1
    x: p.x + (bar.drop ? bar.drop.depth * 14 : 0) + 26
    y: p.y - 1
    width: bar.width - x - 14
    height: 2
    radius: 1
    color: bar.theme.accent
    z: 5
    Rectangle { x: -4; y: -2; width: 6; height: 6; radius: 3; color: bar.theme.accent }
  }
  Rectangle {
    visible: bar.dragId !== ""
    x: bar.dragAt.x + 12
    y: bar.dragAt.y - height / 2
    z: 6
    width: Math.min(200, ghost.implicitWidth + 20)
    height: 28
    radius: 7
    color: bar.theme.surface
    border.width: 1
    border.color: bar.theme.line
    opacity: 0.92
    Text {
      id: ghost
      x: 10
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 20
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: bar.dragLabel
      font.family: bar.theme.uiFont
      font.pixelSize: 13
      color: bar.theme.text
    }
  }

  // ---- at the foot -------------------------------------------------------------------------

  Column {
    id: foot
    x: 8
    width: parent.width - 16
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 8
    spacing: 2
    Rectangle { width: parent.width; height: 1; color: bar.theme.line; opacity: bar.theme.cardsShown ? 0 : 1 }
    Item { width: 1; height: 4 }
    // Notes coming in.
    Text {
      visible: bar.view.workspace !== null && bar.view.workspace.importing === true
      leftPadding: 12
      textFormat: Text.PlainText
      text: "Importing\u2026 " + (bar.view.workspace ? bar.view.workspace.importCount : 0)
      font.family: bar.theme.uiFont
      font.pixelSize: 12
      color: bar.theme.muted
    }
    Item {
      width: parent.width
      height: 30
      Row {
        spacing: 2
        FootButton {
          id: importButton
          objectName: "importButton"
          visible: bar.shows("import")
          itemId: "import"
          icon: bar.theme.icons.export
          tip: "Import\u2026"
          onClicked: bar.view.openImport(importButton)
        }
        FootButton {
          objectName: "templatesButton"
          visible: bar.shows("templates")
          itemId: "templates"
          icon: bar.theme.icons.templates
          count: bar.templateCount
          tip: "Templates"
          checked: bar.view.templatesShown
          onClicked: bar.view.openTemplates()
        }
        FootButton {
          objectName: "archiveButton"
          visible: bar.shows("archive")
          itemId: "archive"
          icon: bar.theme.icons.archive
          count: bar.archiveCount
          tip: "Archive"
          onClicked: bar.view.openArchive()
        }
        FootButton {
          objectName: "trashButton"
          visible: bar.shows("trash")
          itemId: "trash"
          icon: bar.theme.icons.trash
          count: bar.trashCount
          tip: "Trash"
          onClicked: bar.view.openTrash()
        }
      }
      FootButton {
        objectName: "settingsButton"
        anchors.right: parent.right
        icon: bar.theme.icons.cog
        tip: "Settings  Ctrl+,"
        onClicked: bar.view.settingsRequested()
      }
    }
    Item { width: 1; height: 2 }
    // A newer version, if there's one; who makes Uber Notebook, on X.
    SideFooter {
      objectName: "sidebarFooter"
      width: parent.width
      theme: bar.theme
      service: bar.view.service
      onNotesRequested: bar.view.releaseNotesRequested()
    }
  }

  // A right-click's menu.
  Pop {
    id: itemMenu
    theme: bar.theme
    width: 250
    contentItem: Column {
      id: menuRows
      spacing: 2
      MenuRow {
        objectName: "sidebarHide"
        visible: bar.menuFor !== ""
        width: parent.width
        theme: bar.theme
        icon: bar.theme.icons.eyeOff
        text: "Hide " + Sidebar.label(bar.menuFor)
        onClicked: { itemMenu.close(); bar.hide(bar.menuFor) }
      }
      MenuRow {
        objectName: "sidebarChoose"
        width: parent.width
        theme: bar.theme
        icon: bar.theme.icons.tune
        text: "Choose what\u2019s in the sidebar\u2026"
        onClicked: { itemMenu.close(); bar.view.sidebarChoicesRequested() }
      }
    }
  }
}
