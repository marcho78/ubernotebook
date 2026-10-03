import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import "../Workspace.js" as Workspace
import "../Docs.js" as Docs
import "../Calendar.js" as Calendar
import "../Dates.js" as Dates
import "../Colors.js" as Colors

// The sidebar of Pages: the switch back to notebooks, search, a new page,
// the projects (+ makes one; each with the pages in it) and the other pages,
// as trees (a page's arrow shows the pages inside it; + adds one, ⋯ has its
// menu; drag a page to put it before, after or inside another, or on
// Projects to make it a project; a project dragged into Pages is a page
// again), the tags (a click shows every block with one), the archive, the
// trash and the settings at the foot.
Rectangle {
  id: bar

  property var theme: null
  property var view: null

  // The trees' rows, the projects' and the pages' (kept as they are while a
  // page is dragged, so the row being dragged isn't drawn again under the
  // pointer).
  readonly property var liveTrees: {
    var r = view.workspace ? view.workspace.revision : 0
    var o = view.openRows
    return view.workspace ? Workspace.sidebarRows(view.workspace.index, o, new Date()) : { projects: [], pages: [] }
  }
  property var rows: []
  property var projectRows: []
  function takeRows() { rows = liveTrees.pages; projectRows = liveTrees.projects }
  onLiveTreesChanged: if (dragId === "") takeRows()
  Component.onCompleted: takeRows()

  // ---- dragging a page ---------------------------------------------------------------------

  property string dragId: ""
  property string dragLabel: ""
  property point dragAt: Qt.point(0, 0)
  // Where it would go: { id, where: "before" | "after" | "inside" | "end" |
  // "project", depth, top, h (of the row), list (the tree), inPages } or null.
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

  // Where in a tree: on a row, before, after or inside it (a project's,
  // inside: the projects keep their order); below Pages' rows, its end.
  function spotIn(list, p, inPages) {
    var q = bar.mapToItem(list.contentItem, p.x, p.y)
    var item = list.itemAt(Math.min(list.width - 2, Math.max(2, q.x)), q.y)
    if (item && item.modelData) {
      var rel = (q.y - item.y) / item.height
      var where = item.modelData.isProject ? "inside" : rel < 0.28 ? "before" : rel > 0.72 ? "after" : "inside"
      return { id: item.modelData.id, where: where, depth: item.modelData.depth, top: item.y, h: item.height, list: list, inPages: inPages }
    }
    if (inPages && q.y >= list.contentItem.childrenRect.height - 4) {
      var last = bar.rows.length ? list.itemAt(4, list.contentItem.childrenRect.height - 4) : null
      return { id: "", where: "end", depth: 0, top: last ? last.y : 0, h: last ? last.height : 0, list: list, inPages: true }
    }
    return null
  }

  function moveDrag(p) {
    dragAt = p
    var spot = null
    if (over(projHeadArea, p) || over(projEmpty, p)) spot = { id: "", where: "project", depth: 0, top: 0, h: 0, list: null, inPages: false }
    else if (over(projRows, p)) spot = spotIn(projRows, p, false)
    else if (bar.mapToItem(tree, p.x, p.y).y >= 0) spot = spotIn(tree, p, true)
    var ix = view.workspace.index
    if (spot && (spot.where === "project" ? !!ix.pages[dragId].project : !Workspace.dropPlace(ix, dragId, spot.id, spot.where))) spot = null
    drop = spot
    // Near the top or the bottom of a tree: it scrolls.
    scroller.list = over(projRows, p) ? projRows : tree
    var edge = bar.mapToItem(scroller.list, p.x, p.y).y
    scroller.dir = scroller.list === tree && edge < 0 ? 0 : edge < 24 ? -1 : edge > scroller.list.height - 24 ? 1 : 0
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
    property var list: tree
    interval: 30
    repeat: true
    running: dir !== 0 && bar.dragId !== ""
    onTriggered: {
      list.contentY = Math.max(0, Math.min(Math.max(0, list.contentHeight - list.height), list.contentY + dir * 8))
      bar.moveDrag(bar.dragAt)
    }
  }
  readonly property var favorites: {
    var r = view.workspace ? view.workspace.revision : 0
    return view.workspace ? Workspace.favorites(view.workspace.index) : []
  }
  // The tags, by name (a tag inside another under it) or by color, as Settings has it.
  readonly property string tagSort: view.settings.tagSort === "color" ? "color" : "name"
  readonly property var tagList: {
    var r = view.workspace ? view.workspace.revision : 0
    var k = view.tagColorsKey
    return view.workspace ? Workspace.sortTags(Workspace.tagList(view.workspace.index), view.tagColorsShown, bar.tagSort) : []
  }
  property bool tagsOpen: true
  property bool projectsOpen: true
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

  color: theme.sidebar

  Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: bar.theme.line }

  // Its sections as cards (Settings → Appearance, Sections and cards: a
  // color of their own), each behind its section.
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
  SectionCard { objectName: "sectionCard"; target: head; above: 4; below: 4 }
  SectionCard { objectName: "sectionCard"; target: todayBox }
  SectionCard { objectName: "sectionCard"; target: favs }
  SectionCard { objectName: "sectionCard"; target: projectsBox }
  SectionCard {
    objectName: "sectionCard"
    target: tree
    y: pagesLabel.y - 6
    height: tree.y + tree.height - pagesLabel.y + 8
  }
  SectionCard { objectName: "sectionCard"; target: tagsBox; above: -2; below: 4 }
  SectionCard { objectName: "sectionCard"; target: foot; above: -2; below: 4 }

  component Row2: Rectangle {
    id: r2
    property string icon: ""
    property string text: ""
    property string hint: ""
    // What it opens is shown.
    property bool checked: false
    signal clicked()
    width: parent ? parent.width : 200
    height: 30
    radius: 6
    color: checked ? bar.theme.pressed : rowHover.hovered ? bar.theme.hover : "transparent"
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
      x: 38
      anchors.verticalCenter: parent.verticalCenter
      text: r2.text
      font.family: bar.theme.uiFont
      font.pixelSize: 13
      color: bar.theme.text
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

  Column {
    id: head
    x: 8
    y: 10
    width: parent.width - 16
    spacing: 2

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
    Item { width: 1; height: 4 }
    Row2 { icon: bar.theme.icons.search; text: "Search"; hint: "Ctrl+P"; onClicked: bar.view.openFind() }
    Row2 { icon: bar.theme.icons.newPage; text: "New page"; hint: "Ctrl+N"; onClicked: bar.view.newPage("") }
    Row2 {
      objectName: "calendarRow"
      icon: bar.theme.icons.calendarMonth
      text: "Calendar"
      hint: Dates.SHORT_DAYS[new Date(bar.nowMs).getDay()] + " " + new Date(bar.nowMs).getDate()
      color: bar.view.calendarShown ? bar.theme.pressed : rowHover2.hovered ? bar.theme.hover : "transparent"
      HoverHandler { id: rowHover2 }
      onClicked: bar.view.openCalendar("")
    }
    Row2 {
      objectName: "libraryRow"
      icon: bar.theme.icons.library
      text: "Library"
      hint: { var r = bar.view.workspace ? bar.view.workspace.revision : 0; var n = bar.view.workspace ? Workspace.collected(bar.view.workspace.index).length : 0; return n > 0 ? String(n) : "" }
      color: bar.view.libraryShown ? bar.theme.pressed : rowHover3.hovered ? bar.theme.hover : "transparent"
      HoverHandler { id: rowHover3 }
      onClicked: bar.view.openLibrary("")
    }
    Row2 {
      objectName: "peopleRow"
      icon: bar.theme.icons.contacts
      text: "People"
      hint: { var r = bar.view.workspace ? bar.view.workspace.contactsRevision : 0; var n = bar.view.workspace ? bar.view.workspace.contacts.contacts.length : 0; return n > 0 ? String(n) : "" }
      color: bar.view.peopleShown ? bar.theme.pressed : rowHover4.hovered ? bar.theme.hover : "transparent"
      HoverHandler { id: rowHover4 }
      onClicked: bar.view.openPeople("")
    }
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
  Column {
    id: todayBox
    objectName: "sidebarToday"
    x: 8
    width: parent.width - 16
    anchors.top: head.bottom
    anchors.topMargin: visible ? 16 : 0
    visible: bar.todayLeft.length > 0
    spacing: 0
    Text {
      textFormat: Text.PlainText
      leftPadding: 12
      bottomPadding: 6
      text: "Today"
      font.family: bar.theme.uiFont
      font.pixelSize: 11
      font.weight: Font.DemiBold
      font.letterSpacing: 0.4
      color: bar.theme.muted
    }
    Repeater {
      model: bar.todayLeft.slice(0, 4)
      delegate: Rectangle {
        id: trow
        required property var modelData
        readonly property bool now: !modelData.allDay && modelData.start <= new Date(bar.nowMs)
        readonly property real soon: (modelData.start - bar.nowMs) / 60000
        objectName: "todayRow"
        width: todayBox.width
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
      visible: bar.todayLeft.length > 4
      icon: ""
      text: (bar.todayLeft.length - 4) + " more today"
      onClicked: bar.view.openCalendar("")
    }
  }

  // Favorites: the pages starred, at the top.
  Column {
    id: favs
    x: 8
    width: parent.width - 16
    anchors.top: todayBox.visible ? todayBox.bottom : head.bottom
    anchors.topMargin: bar.favorites.length ? 16 : 0
    visible: bar.favorites.length > 0
    spacing: 0
    Text {
      textFormat: Text.PlainText
      leftPadding: 12
      bottomPadding: 6
      text: "Favorites"
      font.family: bar.theme.uiFont
      font.pixelSize: 11
      font.weight: Font.DemiBold
      font.letterSpacing: 0.4
      color: bar.theme.muted
    }
    Repeater {
      model: bar.favorites
      delegate: Rectangle {
        required property var modelData
        readonly property var e: bar.view.workspace.index.pages[modelData] || ({ title: "", icon: "" })
        readonly property bool current: bar.view.page && bar.view.page.id === modelData
        width: favs.width
        height: 30
        radius: 6
        color: current ? bar.theme.pressed : favHover.hovered ? bar.theme.hover : "transparent"
        Text {
          id: favIcon
          textFormat: Text.PlainText
          x: 12
          anchors.verticalCenter: parent.verticalCenter
          text: parent.e.icon || "\u{1f4c4}"
          font.family: "Noto Color Emoji"
          font.pixelSize: 14
        }
        Text {
          textFormat: Text.PlainText
          x: 36
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - x - 8
          elide: Text.ElideRight
          text: parent.e.title || "Untitled"
          font.family: bar.theme.uiFont
          font.pixelSize: 13
          font.weight: parent.current ? Font.DemiBold : Font.Normal
          color: bar.theme.text
        }
        HoverHandler { id: favHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: bar.view.open(modelData) }
      }
    }
  }

  // A page's row in the trees: its arrow (the pages inside it), its icon
  // and title; hovered, ⋯ (its menu) and + (a page inside it). A project's
  // says when it's due (late in red) and has its progress, as a ring round
  // its status color. Dragged: before, after or inside another.
  component TreeRow: Rectangle {
    id: rowItem
    required property var modelData
    required property int index
    property var list: null
    property bool inPages: true
    readonly property bool isProject: modelData.isProject === true
    readonly property bool current: bar.view.page !== null && bar.view.page.id === modelData.id
    readonly property bool dropInside: bar.drop !== null && bar.drop.where === "inside" && bar.drop.id === modelData.id
    readonly property var status: isProject ? Workspace.statusOf(modelData.status) : null
    readonly property var due: isProject && modelData.due ? Workspace.dueInfo(modelData.due, new Date()) : null
    objectName: isProject ? "projectRow" : inPages ? "pageRow" : "projectPageRow"
    width: list ? list.width : 200
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
      width: parent.width - x - (treeHover.hovered ? 56 : projectInfo.visible ? projectInfo.width + 14 : 8)
      elide: Text.ElideRight
      text: rowItem.modelData.title || "Untitled"
      font.family: bar.theme.uiFont
      font.pixelSize: 13
      font.weight: rowItem.current ? Font.DemiBold : Font.Normal
      color: !rowItem.modelData.title || rowItem.isProject && (rowItem.modelData.status === "paused" || rowItem.modelData.status === "done") ? bar.theme.muted : bar.theme.text
    }

    // A project's: when it's due (not once it's done), and its ring (its
    // status's color; full, done).
    Row {
      id: projectInfo
      visible: rowItem.isProject && !treeHover.hovered
      anchors.right: parent.right
      anchors.rightMargin: 9
      anchors.verticalCenter: parent.verticalCenter
      spacing: 7
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: rowItem.isProject && rowItem.due && rowItem.modelData.status !== "done" ? rowItem.due.label : ""
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
        readonly property real part: rowItem.isProject && rowItem.modelData.progress.total ? rowItem.modelData.progress.done / rowItem.modelData.progress.total : rowItem.isProject && rowItem.modelData.status === "done" ? 1 : 0
        readonly property var shades: rowItem.isProject ? Docs.colorEntry(rowItem.status.color) : null
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

    Row {
      anchors.right: parent.right
      anchors.rightMargin: 2
      anchors.verticalCenter: parent.verticalCenter
      visible: treeHover.hovered
      IconButton {
        theme: bar.theme; icon: bar.theme.icons.more; size: 24; iconSize: 14; tip: "Delete, move\u2026"
        onClicked: bar.view.openRowMenu(rowItem.modelData.id, rowItem)
      }
      IconButton {
        theme: bar.theme; icon: bar.theme.icons.plus; size: 24; iconSize: 14; tip: "A page inside it"
        onClicked: bar.view.newPage(rowItem.modelData.id)
      }
    }
    HoverHandler { id: treeHover }
    TapHandler { onTapped: bar.view.open(rowItem.modelData.id) }
    ToolTip.visible: rowItem.isProject && treeHover.hovered && bar.dragId === ""
    ToolTip.delay: 700
    ToolTip.text: !rowItem.isProject ? "" : rowItem.status.label + (rowItem.due ? "  \u00b7  " + (rowItem.modelData.overdue ? rowItem.due.label : "due " + rowItem.due.label) : "")
      + "  \u00b7  " + rowItem.modelData.progress.done + " of " + rowItem.modelData.progress.total + " to-dos"
  }

  // Projects: + makes one (a page dragged here is one too), what's on now
  // first, late first; each with the pages in it.
  Column {
    id: projectsBox
    objectName: "sidebarProjects"
    x: 8
    width: parent.width - 16
    anchors.top: favs.visible ? favs.bottom : todayBox.visible ? todayBox.bottom : head.bottom
    anchors.topMargin: 16
    spacing: 0
    Rectangle {
      id: projHeadArea
      objectName: "projectsHead"
      readonly property bool dropHere: bar.drop !== null && bar.drop.where === "project"
      width: parent.width
      height: 24
      radius: 6
      color: dropHere ? Qt.alpha(bar.theme.accent, 0.18) : projHead.hovered && bar.dragId === "" ? bar.theme.hover : "transparent"
      border.width: dropHere ? 1.5 : 0
      border.color: bar.theme.accent
      Text {
        id: projLabel
        textFormat: Text.PlainText
        x: 12
        anchors.verticalCenter: parent.verticalCenter
        text: bar.dragId !== "" && bar.projectRows.length > 0 && !(bar.view.workspace.index.pages[bar.dragId] || {}).project ? "Projects  \u00b7  drop to make it one" : "Projects"
        font.family: bar.theme.uiFont
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.4
        color: projHeadArea.dropHere ? bar.theme.accent : bar.theme.muted
      }
      Icon {
        theme: bar.theme
        anchors.left: projLabel.right
        anchors.leftMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: bar.projectsOpen ? bar.theme.icons.down : bar.theme.icons.right
        size: 12
        color: bar.theme.muted
        visible: projHead.hovered && bar.dragId === ""
      }
      IconButton {
        id: newProjectButton
        objectName: "newProject"
        anchors.right: parent.right
        anchors.rightMargin: 2
        anchors.verticalCenter: parent.verticalCenter
        theme: bar.theme; icon: bar.theme.icons.plus; size: 22; iconSize: 14; tip: "New project"
        onClicked: bar.view.newProject()
      }
      HoverHandler { id: projHead; cursorShape: Qt.PointingHandCursor }
      // (Not a click on its +, which makes one.)
      TapHandler {
        onTapped: function(point) {
          var p = newProjectButton.mapFromItem(projHeadArea, point.position.x, point.position.y)
          if (newProjectButton.contains(p)) return
          bar.projectsOpen = !bar.projectsOpen
        }
      }
    }
    Item { width: 1; height: 4 }
    // None yet: a new one, here (or a page dragged here).
    Rectangle {
      id: projEmpty
      objectName: "projectsEmpty"
      visible: bar.projectsOpen && bar.projectRows.length === 0
      width: parent.width
      height: visible ? 30 : 0
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
    ListView {
      id: projRows
      width: parent.width
      height: bar.projectsOpen ? Math.max(Math.min(bar.projectRows.length, 2) * 30, Math.min(bar.projectRows.length * 30, Math.max(120, bar.height * 0.36),
        foot.y - projectsBox.y - 82 - bar.treeKeep - (tagsBox.visible ? 96 : 0))) : 0
      visible: height > 0
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: bar.projectRows
      delegate: TreeRow { list: projRows; inPages: false }
    }
  }

  Text {
    id: pagesLabel
    textFormat: Text.PlainText
    x: 20
    anchors.top: projectsBox.bottom
    anchors.topMargin: 16
    text: "Pages"
    font.family: bar.theme.uiFont
    font.pixelSize: 11
    font.weight: Font.DemiBold
    font.letterSpacing: 0.4
    color: bar.theme.muted
  }

  // The Pages tree keeps room for a few of its pages, however many projects
  // and tags there are: those scroll in what's left.
  readonly property real treeKeep: Math.min(Math.max(bar.rows.length, 1), 4) * 30 + 12

  ListView {
    id: tree
    anchors.top: pagesLabel.bottom
    anchors.topMargin: 6
    anchors.bottom: tagsBox.visible ? tagsBox.top : foot.top
    anchors.bottomMargin: 6
    x: 8
    width: parent.width - 16
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    model: bar.rows
    delegate: TreeRow { list: tree; inPages: true }

    Text {
      textFormat: Text.PlainText
      visible: tree.count === 0 && bar.projectRows.length === 0 && bar.view.workspace && bar.view.workspace.ready
      x: 12
      y: 6
      width: tree.width - 24
      wrapMode: Text.Wrap
      text: "No pages yet. Make one with New page."
      font.family: bar.theme.uiFont
      font.pixelSize: 12
      color: bar.theme.muted
    }
  }

  // Where a dragged page would go: a line before or after a page (as deep
  // as it), or the page it goes inside lit up; and the page, under the pointer.
  Rectangle {
    id: dropLine
    objectName: "dropLine"
    readonly property bool shown: bar.drop !== null && bar.drop.list !== null && bar.drop.where !== "inside" && bar.drop.where !== "project"
    readonly property var p: shown ? bar.drop.list.contentItem.mapToItem(bar, 0, bar.drop.where === "before" ? bar.drop.top : bar.drop.top + bar.drop.h) : Qt.point(0, 0)
    visible: shown
    x: p.x + 8 + (bar.drop ? bar.drop.depth * 14 : 0) + 18
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

  // The tags, above the foot: each with its color and how many blocks have it.
  Column {
    id: tagsBox
    objectName: "sidebarTags"
    x: 8
    width: parent.width - 16
    anchors.bottom: foot.top
    anchors.bottomMargin: 6
    visible: bar.tagList.length > 0
    spacing: 0
    // (Cards instead of the line, when sections are cards.)
    Rectangle { width: parent.width; height: 1; color: bar.theme.line; opacity: bar.theme.cardsShown ? 0 : 1 }
    Item { width: 1; height: 6 }
    Rectangle {
      width: parent.width
      height: 26
      radius: 6
      color: tagsHead.hovered ? bar.theme.hover : "transparent"
      Icon {
        theme: bar.theme
        x: 6
        anchors.verticalCenter: parent.verticalCenter
        text: bar.tagsOpen ? bar.theme.icons.down : bar.theme.icons.right
        size: 13
        color: bar.theme.muted
      }
      Text {
        textFormat: Text.PlainText
        x: 24
        anchors.verticalCenter: parent.verticalCenter
        text: "Tags"
        font.family: bar.theme.uiFont
        font.pixelSize: 11
        font.weight: Font.DemiBold
        font.letterSpacing: 0.4
        color: bar.theme.muted
      }
      Text {
        textFormat: Text.PlainText
        anchors.right: sortButton.left
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
        text: String(bar.tagList.length)
        font.family: bar.theme.uiFont
        font.pixelSize: 11
        color: bar.theme.faint
      }
      HoverHandler { id: tagsHead; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: bar.tagsOpen = !bar.tagsOpen }
      // By name or by color.
      Rectangle {
        id: sortButton
        objectName: "tagSort"
        anchors.right: parent.right
        anchors.rightMargin: 4
        anchors.verticalCenter: parent.verticalCenter
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
        ToolTip.visible: sortHover.hovered
        ToolTip.delay: 500
        ToolTip.text: bar.tagSort === "color" ? "Sorted by color: click for A\u2013Z" : "Sorted by name: click to sort by color"
      }
    }
    ListView {
      id: tagRows
      width: parent.width
      height: bar.tagsOpen ? Math.max(Math.min(bar.tagList.length, 2) * 28, Math.min(bar.tagList.length * 28, Math.max(90, bar.height * 0.26),
        foot.y - 52 - (pagesLabel.y + pagesLabel.height + 6) - bar.treeKeep)) : 0
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      model: bar.tagList
      delegate: Rectangle {
        id: tagRow
        required property var modelData
        readonly property bool current: bar.view.tagShown === modelData.name
        readonly property var look: { var k = bar.view.tagColorsKey; return bar.view.tagLook(modelData.name) }
        objectName: "tagRow"
        width: tagRows.width
        height: 28
        radius: 6
        color: current ? bar.theme.pressed : tagHover.hovered ? bar.theme.hover : "transparent"
        Rectangle {
          id: dot
          x: 14 + tagRow.modelData.depth * 14
          anchors.verticalCenter: parent.verticalCenter
          width: 10
          height: 10
          radius: 5
          color: tagRow.look.color
        }
        Text {
          textFormat: Text.PlainText
          x: dot.x + 20
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - x - (tagHover.hovered ? 34 : 34)
          elide: Text.ElideRight
          // Under the tag it's in, only its own part ("/acme").
          text: tagRow.modelData.depth > 0 ? "/" + tagRow.modelData.label.slice(tagRow.modelData.label.lastIndexOf("/") + 1) : tagRow.modelData.label
          font.family: bar.theme.uiFont
          font.pixelSize: 13
          font.weight: tagRow.current ? Font.DemiBold : Font.Normal
          color: bar.theme.text
        }
        Text {
          visible: !tagHover.hovered
          textFormat: Text.PlainText
          anchors.right: parent.right
          anchors.rightMargin: 10
          anchors.verticalCenter: parent.verticalCenter
          text: String(tagRow.modelData.blocks)
          font.family: bar.theme.uiFont
          font.pixelSize: 11
          color: bar.theme.faint
        }
        IconButton {
          id: tagMore
          objectName: "tagMore"
          visible: tagHover.hovered
          anchors.right: parent.right
          anchors.rightMargin: 2
          anchors.verticalCenter: parent.verticalCenter
          theme: bar.theme; icon: bar.theme.icons.more; size: 24; iconSize: 14; tip: "Color, rename\u2026"
          onClicked: bar.view.openTagMenu(tagRow.modelData.name, tagRow)
        }
        HoverHandler { id: tagHover; cursorShape: Qt.PointingHandCursor }
        // (Not a click on its ⋯, which has its own.)
        TapHandler {
          onTapped: function(point) {
            var p = tagMore.mapFromItem(tagRow, point.position.x, point.position.y)
            if (tagMore.visible && tagMore.contains(p)) return
            bar.view.openTag(tagRow.modelData.name)
          }
        }
        // A right-click: its menu.
        TapHandler {
          acceptedButtons: Qt.RightButton
          onTapped: bar.view.openTagMenu(tagRow.modelData.name, tagRow)
        }
      }
    }
  }

  Column {
    id: foot
    x: 8
    width: parent.width - 16
    anchors.bottom: parent.bottom
    anchors.bottomMargin: 10
    spacing: 2
    Rectangle { width: parent.width; height: 1; color: bar.theme.line; opacity: bar.theme.cardsShown ? 0 : 1 }
    Item { width: 1; height: 4 }
    Row2 {
      id: importRow
      icon: bar.theme.icons.export
      text: bar.view.workspace && bar.view.workspace.importing ? "Importing\u2026 " + bar.view.workspace.importCount : "Import\u2026"
      onClicked: bar.view.openImport(importRow)
    }
    Row2 { objectName: "templatesRow"; icon: bar.theme.icons.templates; text: "Templates"; hint: bar.templateCount > 0 ? String(bar.templateCount) : ""; checked: bar.view.templatesShown; onClicked: bar.view.openTemplates() }
    Row2 { objectName: "archiveRow"; icon: bar.theme.icons.archive; text: "Archive"; hint: bar.archiveCount > 0 ? String(bar.archiveCount) : ""; onClicked: bar.view.openArchive() }
    Row2 { icon: bar.theme.icons.trash; text: "Trash"; hint: bar.trashCount > 0 ? String(bar.trashCount) : ""; onClicked: bar.view.openTrash() }
    Row2 { icon: bar.theme.icons.cog; text: "Settings"; hint: "Ctrl+,"; onClicked: bar.view.settingsRequested() }
    Item { width: 1; height: 4 }
    Rectangle { width: parent.width; height: 1; color: bar.theme.line; opacity: 0.7 }
    Item { width: 1; height: 4 }
    // A newer version, if there's one; who makes Omanote, on X.
    SideFooter {
      objectName: "sidebarFooter"
      width: parent.width
      theme: bar.theme
      service: bar.view.service
      onNotesRequested: bar.view.releaseNotesRequested()
    }
  }
}
