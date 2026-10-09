import QtQuick
import QtQuick.Controls
import "../Calendar.js" as Calendar
import "../Workspace.js" as Workspace
import "../Dates.js" as Dates
import "../Docs.js" as Docs
import "../Colors.js" as Colors

// The calendar, in place of a page (the sidebar's Calendar): your events,
// and the dates in your notes (reminders, projects' due dates), by month,
// by week (hour by hour), as an agenda, or compact (a small month, a dot for
// each event, and the days from the one picked beside it). Click a day or a
// time to add an event there ("Lunch with Sam 12:30"), an event to change
// it; drag one to move it, its bottom edge (in a week) to make it longer or
// shorter. A repeating one asks: just this one, or every one. ← and → go
// back and on, T to today, M, W, A and C to the month, the week, the agenda
// and compact, N for a new event; Ctrl+Z takes a change back. The view you
// were in is the one it opens in.
Item {
  id: cv

  property var theme: null
  property var workspace: null
  // DocView: opening pages, the event editor, quick add, asking, toasts.
  property var view: null

  property string mode: "month"
  // A day in what's shown.
  property var anchorDay: today()
  // The day picked in the compact view (its list starts there).
  property var pickedDay: today()

  // The view as it was last time (Settings' calendarView), once; then kept
  // as it changes.
  readonly property var modes: ["month", "week", "agenda", "compact"]
  property bool restored: false
  function restoreMode(m) {
    if (restored) return
    restored = true
    if (modes.indexOf(m) >= 0) mode = m
  }
  onModeChanged: if (restored && view && view.service) view.service.setSetting("calendarView", mode)

  // The time now (each minute): today, and the line across the week.
  property real nowMs: Date.now()
  Timer { interval: 30000; repeat: true; running: cv.visible; onTriggered: cv.nowMs = Date.now() }

  function today() { var n = new Date(); return new Date(n.getFullYear(), n.getMonth(), n.getDate()) }
  function same(a, b) { return a.getFullYear() === b.getFullYear() && a.getMonth() === b.getMonth() && a.getDate() === b.getDate() }
  function addDays(d, n) { return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n) }
  readonly property var todayDay: { var n = new Date(nowMs); return new Date(n.getFullYear(), n.getMonth(), n.getDate()) }

  readonly property var gridFirst: Calendar.startOfWeek(new Date(anchorDay.getFullYear(), anchorDay.getMonth(), 1))
  readonly property var weekFirst: Calendar.startOfWeek(anchorDay)
  // What's shown: from, to.
  readonly property var range: mode === "month" ? [gridFirst, addDays(gridFirst, 42)]
    : mode === "week" ? [weekFirst, addDays(weekFirst, 7)]
    : mode === "compact" ? [pickedDay < gridFirst ? pickedDay : gridFirst, addDays(pickedDay, 31) > addDays(gridFirst, 42) ? addDays(pickedDay, 31) : addDays(gridFirst, 42)]
    : [anchorDay, addDays(anchorDay, 60)]
  readonly property var occ: { var r = workspace ? workspace.calendarRevision : 0; return workspace ? Calendar.occurrences(workspace.calendar, range[0], range[1]) : [] }
  readonly property var notes: { var r = workspace ? workspace.revision : 0; return workspace ? Workspace.datedNotes(workspace.index, range[0], range[1]) : [] }

  function notesOn(d) { var lo = d; var hi = addDays(d, 1); return notes.filter(function(n) { return n.at >= lo && n.at < hi }) }

  readonly property string title: mode === "month" || mode === "compact" ? Qt.locale().standaloneMonthName(anchorDay.getMonth()) + " " + anchorDay.getFullYear()
    : mode === "week" ? weekTitle()
    : "From " + Dates.label(anchorDay, false, new Date())
  function weekTitle() {
    var a = weekFirst
    var b = addDays(weekFirst, 6)
    var m = Dates.SHORT_MONTHS
    return a.getMonth() === b.getMonth() ? a.getDate() + " \u2013 " + b.getDate() + " " + m[b.getMonth()] + " " + b.getFullYear()
      : a.getDate() + " " + m[a.getMonth()] + " \u2013 " + b.getDate() + " " + m[b.getMonth()] + " " + b.getFullYear()
  }

  function go(step) {
    if (mode === "month") anchorDay = new Date(anchorDay.getFullYear(), anchorDay.getMonth() + step, 1)
    else if (mode === "compact") {
      // Another month: today picked in it, else its first day.
      anchorDay = new Date(anchorDay.getFullYear(), anchorDay.getMonth() + step, 1)
      pickedDay = todayDay.getMonth() === anchorDay.getMonth() && todayDay.getFullYear() === anchorDay.getFullYear() ? todayDay : anchorDay
    }
    else if (mode === "week") anchorDay = addDays(anchorDay, 7 * step)
    else anchorDay = addDays(anchorDay, 30 * step)
  }
  function show(d, m) {
    if (m) mode = m
    anchorDay = d ? new Date(d.getFullYear(), d.getMonth(), d.getDate()) : today()
    pickedDay = anchorDay
    forceActiveFocus()
    if (mode === "week") Qt.callLater(scrollToMorning)
  }
  // Another view; going compact, the day picked is today if it's in the
  // month shown, else the day shown.
  function setMode(m) {
    if (m === "compact" && mode !== "compact")
      pickedDay = anchorDay.getMonth() === todayDay.getMonth() && anchorDay.getFullYear() === todayDay.getFullYear() ? todayDay : anchorDay
    mode = m
    forceActiveFocus()
    if (m === "week") Qt.callLater(scrollToMorning)
  }
  // A day picked in the compact view: its month shown, the days from it listed.
  function pick(d) {
    pickedDay = new Date(d.getFullYear(), d.getMonth(), d.getDate())
    if (d.getMonth() !== anchorDay.getMonth() || d.getFullYear() !== anchorDay.getFullYear()) anchorDay = new Date(d.getFullYear(), d.getMonth(), 1)
    agenda.positionViewAtBeginning()
  }
  // Where + New event and N put one: the day picked (compact), the day in
  // the month gone to, else today.
  function newDay() {
    if (mode === "compact") return pickedDay
    // A week: today, if it's in it, else its Monday; the agenda: the day it's from.
    if (mode === "week") return todayDay >= weekFirst && todayDay < addDays(weekFirst, 7) ? todayDay : weekFirst
    if (mode === "agenda") return anchorDay
    return mode === "month" && !same(anchorDay, todayDay) ? anchorDay : todayDay
  }

  // An agenda's time column: room for "11:30 am – 12:30 pm" on a 12-hour clock.
  readonly property real spanW: theme && theme.twelveHour ? 130 : 110

  // An event just made: its day gone to when it's out of sight, its time
  // scrolled to in a week, and it marked a moment, so you see where it went.
  property string flashId: ""
  Timer { id: flashTimer; interval: 2400; onTriggered: cv.flashId = "" }
  function reveal(id) {
    var ev = workspace ? Calendar.byId(workspace.calendar, id) : null
    var at = ev ? Dates.fromIso(ev.start) : null
    if (!at) return
    var day = new Date(at.at.getFullYear(), at.at.getMonth(), at.at.getDate())
    if (mode === "compact") { if (!same(day, pickedDay)) pick(day) }
    else if (day < range[0] || day >= range[1]) show(day, "")
    if (mode === "week" && !ev.allDay) Qt.callLater(function() {
      var y = Math.max(0, (at.at.getHours() + at.at.getMinutes() / 60) * hourH - weekFlick.height / 3)
      weekFlick.contentY = Math.min(y, Math.max(0, weekFlick.contentHeight - weekFlick.height))
    })
    if (mode === "agenda") Qt.callLater(function() {
      for (var i = 0; i < agendaDays.length; i++) if (same(agendaDays[i].day, day)) { agenda.positionViewAtIndex(i, ListView.Contain); break }
    })
    flashId = id
    flashTimer.restart()
  }

  // The mark round an event just made.
  component Flash: Rectangle {
    property string eventId: ""
    anchors.fill: parent
    anchors.margins: -2
    radius: 6
    color: "transparent"
    border.width: 2
    border.color: cv.theme.accent
    visible: eventId !== "" && cv.flashId === eventId
    z: 5
  }

  // ---- colors ------------------------------------------------------------------------------

  function tintOf(c) {
    var e = c ? Docs.colorEntry(c) : null
    if (e) return e.text[theme.dark ? 1 : 0]
    if (c && Colors.isHex(c)) return Colors.normalize(c)
    return String(theme.accent)
  }
  function fillOf(c) {
    var e = c ? Docs.colorEntry(c) : null
    if (e) return e.background[theme.dark ? 1 : 0]
    return Qt.alpha(tintOf(c), theme.dark ? 0.28 : 0.16)
  }
  // Words on an event's fill, readable.
  function inkOn(c) {
    var e = c ? Docs.colorEntry(c) : null
    return e ? e.text[theme.dark ? 1 : 0] : String(theme.text)
  }

  // ---- changing what's shown ---------------------------------------------------------------

  // An event moved to `start` (its length kept, or to `end`): a repeating
  // one asks whether it's just this one, or every one (moved as much).
  function moveTo(o, start, end, anchor) {
    if (!workspace) return
    var ev = workspace.eventById(o.id)
    if (!ev) return
    var mine = occMoved(o, start, end)
    function done() { cv.view.toastUndo("Moved \u201c" + (o.title || "the event") + "\u201d", function() { cv.workspace.undoCalendar() }) }
    if (!o.repeats) {
      var e1 = JSON.parse(JSON.stringify(ev))
      e1.start = mine.start
      e1.end = mine.end
      workspace.setCalendar(Calendar.withEvent(workspace.calendar, e1))
      done()
      return
    }
    view.ask("\u201c" + (o.title || "The event") + "\u201d repeats", [
      { label: "Just this one", value: "one" },
      { label: "Every one", value: "all" }
    ], function(what) {
      var cal = cv.workspace.calendar
      if (what === "one") cv.workspace.setCalendar(Calendar.detach(cal, o.id, o.day, mine)[0])
      else cv.workspace.setCalendar(Calendar.withEvent(cal, shifted(ev, o, mine)))
      done()
    }, anchor)
  }

  // This one's start and end, as moved: { start, end }.
  function occMoved(o, start, end) {
    var s = Dates.fromIso(start).at
    if (o.allDay) {
      var days = Math.round((o.end - o.start) / 86400000) - 1
      return { start: Calendar.dayIso(s), end: end || Calendar.dayIso(addDays(s, days)) }
    }
    return { start: Calendar.timeIso(s), end: end || Calendar.timeIso(new Date(s.getTime() + (o.end - o.start))) }
  }

  // A repeating event moved as one of its times was (its start and its end
  // by as much).
  function shifted(ev, o, mine) {
    var e = JSON.parse(JSON.stringify(ev))
    var s0 = Dates.fromIso(ev.start).at
    var e0 = Dates.fromIso(ev.end).at
    if (ev.allDay) {
      var ds = Math.round((Dates.fromIso(mine.start).at - o.start) / 86400000)
      var de = Math.round((Dates.fromIso(mine.end).at - addDays(o.end, -1)) / 86400000)
      e.start = Calendar.dayIso(addDays(s0, ds))
      e.end = Calendar.dayIso(addDays(e0, de))
    } else {
      var ms = Dates.fromIso(mine.start).at - o.start
      var me = Dates.fromIso(mine.end).at - o.end
      e.start = Calendar.timeIso(new Date(s0.getTime() + ms))
      e.end = Calendar.timeIso(new Date(e0.getTime() + me))
    }
    return e
  }

  // Whether something named one of `names` is under (x, y) in `item`.
  function over(item, x, y, names) {
    var it = item
    var p = Qt.point(x, y)
    for (var i = 0; i < 12 && it; i++) {
      var c = it.childAt(p.x, p.y)
      if (!c) return false
      if (names.indexOf(c.objectName) >= 0) return true
      p = it.mapToItem(c, p.x, p.y)
      it = c
    }
    return false
  }

  // (While an event's editor is open, a click in it isn't the calendar's
  // under it too: a click beside it closes it first.)
  function openOcc(o, anchor) { if (!view.eventEditorOpen) view.openEvent(o.id, o.day, anchor) }
  function addAt(d, minutes, anchor) { if (!view.eventEditorOpen) view.quickAdd(d, minutes, anchor) }

  // ---- keys --------------------------------------------------------------------------------

  focus: true
  Keys.onPressed: function(e) {
    var ctrl = (e.modifiers & Qt.ControlModifier) !== 0
    var shift = (e.modifiers & Qt.ShiftModifier) !== 0
    if (ctrl && e.key === Qt.Key_Z) { e.accepted = true; if (shift) workspace.redoCalendar(); else workspace.undoCalendar(); return }
    if (ctrl) return
    if (e.key === Qt.Key_Left) { e.accepted = true; go(-1) }
    else if (e.key === Qt.Key_Right) { e.accepted = true; go(1) }
    else if (e.key === Qt.Key_T) { e.accepted = true; show(today(), "") }
    else if (e.key === Qt.Key_M) { e.accepted = true; setMode("month") }
    else if (e.key === Qt.Key_W) { e.accepted = true; setMode("week") }
    else if (e.key === Qt.Key_A) { e.accepted = true; setMode("agenda") }
    else if (e.key === Qt.Key_C) { e.accepted = true; setMode("compact") }
    else if (e.key === Qt.Key_N) { e.accepted = true; addAt(newDay(), -1, newButton) }
  }

  Rectangle { anchors.fill: parent; color: cv.theme.background }

  // ---- the bar at the top --------------------------------------------------------------------

  readonly property var modeList: [{ id: "month", label: "Month", key: "M" }, { id: "week", label: "Week", key: "W" }, { id: "agenda", label: "Agenda", key: "A" }, { id: "compact", label: "Compact", key: "C" }]

  Item {
    id: bar
    x: 24
    y: 14
    width: parent.width - 48
    // Less room: the views in one menu, + New event without its words; less
    // still, the buttons on a line under the title.
    readonly property bool tight: width < 860
    readonly property bool stacked: width < 560
    height: stacked ? 80 : 40
    Row {
      id: leftRow
      y: (40 - height) / 2
      spacing: 6
      Chip { objectName: "calToday"; theme: cv.theme; text: "Today"; onClicked: cv.show(cv.today(), "") }
      IconButton { objectName: "calBack"; theme: cv.theme; icon: cv.theme.icons.left; size: 30; iconSize: 17; tip: "Back  \u2190"; onClicked: cv.go(-1) }
      IconButton { objectName: "calOn"; theme: cv.theme; icon: cv.theme.icons.right; size: 30; iconSize: 17; tip: "On  \u2192"; onClicked: cv.go(1) }
      Text {
        objectName: "calTitle"
        anchors.verticalCenter: parent.verticalCenter
        leftPadding: 8
        textFormat: Text.PlainText
        text: cv.title
        width: Math.min(implicitWidth, bar.width - 150)
        elide: Text.ElideRight
        font.family: cv.theme.uiFont
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: cv.theme.text
      }
    }
    Row {
      id: rightRow
      x: bar.stacked ? 0 : bar.width - width
      y: bar.stacked ? 44 : (40 - height) / 2
      spacing: 6
      Repeater {
        model: cv.modeList
        delegate: Chip {
          required property var modelData
          objectName: "calMode_" + modelData.id
          visible: !bar.tight
          theme: cv.theme
          text: modelData.label
          checked: cv.mode === modelData.id
          onClicked: cv.setMode(modelData.id)
        }
      }
      // (Tight: the view now, a click for the others.)
      Chip {
        id: modesChip
        objectName: "calModes"
        visible: bar.tight
        theme: cv.theme
        text: (cv.modeList.filter(function(m) { return m.id === cv.mode })[0] || cv.modeList[0]).label + "  \u25be"
        onClicked: modesMenu.open()
        Pop {
          id: modesMenu
          theme: cv.theme
          focus: false
          width: 200
          y: modesChip.height + 6
          contentItem: Column {
            spacing: 2
            Repeater {
              model: cv.modeList
              delegate: MenuRow {
                required property var modelData
                objectName: "calModeItem_" + modelData.id
                width: parent.width
                theme: cv.theme
                text: modelData.label
                hint: modelData.key
                checked: cv.mode === modelData.id
                onClicked: { modesMenu.close(); cv.setMode(modelData.id) }
              }
            }
          }
        }
      }
      Item { width: 8; height: 1 }
      IconButton {
        id: newButton
        objectName: "calNew"
        theme: cv.theme; icon: cv.theme.icons.plus; label: bar.tight ? "" : "New event"; size: 32; iconSize: 15
        tip: "A new event  N"
        onClicked: cv.addAt(cv.newDay(), -1, newButton)
      }
      IconButton {
        id: calMore
        objectName: "calMore"
        theme: cv.theme; icon: cv.theme.icons.more; size: 32; iconSize: 16; tip: "Export, undo"
        onClicked: calMenu.open()
        Pop {
          id: calMenu
          theme: cv.theme
          focus: false
          width: 240
          x: calMore.width - width
          y: calMore.height + 6
          contentItem: Column {
            spacing: 2
            MenuRow { objectName: "calendarImport"; width: parent.width; theme: cv.theme; icon: cv.theme.icons.plus; text: "Import .ics\u2026"; hint: "events from another calendar"; onClicked: { calMenu.close(); cv.view.importIcs() } }
            MenuRow { width: parent.width; theme: cv.theme; icon: cv.theme.icons.export; text: "Export as .ics\u2026"; hint: "for another calendar"; onClicked: { calMenu.close(); cv.view.exportCalendar() } }
            MenuRow { width: parent.width; theme: cv.theme; icon: cv.theme.icons.undo; text: "Undo"; hint: "Ctrl+Z"; active: cv.workspace && cv.workspace.calendarUndo.length > 0; onClicked: { calMenu.close(); cv.workspace.undoCalendar() } }
            MenuRow { width: parent.width; theme: cv.theme; icon: cv.theme.icons.redo; text: "Redo"; hint: "Ctrl+Shift+Z"; active: cv.workspace && cv.workspace.calendarRedo.length > 0; onClicked: { calMenu.close(); cv.workspace.redoCalendar() } }
          }
        }
      }
    }
  }

  // An event, or a date in your notes, as a line in a day (month and agenda).
  component Entry: Rectangle {
    id: entry
    property var occ: null
    property var note: null
    property real fontPx: 12
    readonly property bool allDay: occ ? occ.allDay : (note ? !note.time : false)
    readonly property string color_: occ ? occ.color : ""
    signal moved(var point)
    signal dropped()
    height: fontPx + 9
    radius: 4
    color: occ && allDay ? cv.fillOf(color_) : entryHover.hovered ? Qt.alpha(cv.theme.text, 0.06) : "transparent"
    opacity: cv.dragOcc && occ && cv.dragOcc.key === occ.key ? 0.4 : 1
    Flash { objectName: "calFlash"; eventId: entry.occ ? entry.occ.id : "" }
    Rectangle {
      visible: !entry.allDay || entry.note !== null
      x: 4
      anchors.verticalCenter: parent.verticalCenter
      width: 6
      height: 6
      radius: 3
      color: entry.note ? "transparent" : cv.tintOf(entry.color_)
      border.width: entry.note ? 1.2 : 0
      border.color: cv.theme.muted
    }
    Text {
      x: entry.allDay && !entry.note ? 6 : 14
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - x - 4
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: (cv.theme.twelveHour, entry.occ) ? (entry.allDay ? "" : Calendar.timeLabel(entry.occ.start) + " ") + (entry.occ.title || "Untitled")
        : entry.note ? (entry.note.kind === "due" ? "\u2691 " : "\u23f0 ") + entry.note.title + (entry.note.text && entry.note.kind !== "due" ? ": " + entry.note.text : " due") : ""
      font.family: cv.theme.uiFont
      font.pixelSize: entry.fontPx
      font.italic: entry.note !== null
      color: entry.note ? cv.theme.muted : entry.allDay ? cv.inkOn(entry.color_) : cv.theme.text
    }
    HoverHandler { id: entryHover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
      gesturePolicy: TapHandler.ReleaseWithinBounds
      onTapped: {
        if (entry.note) cv.view.open(entry.note.page)
        else if (entry.occ) cv.openOcc(entry.occ, entry)
      }
    }
    DragHandler {
      enabled: entry.occ !== null
      target: null
      dragThreshold: 6
      onActiveChanged: if (active) cv.startMonthDrag(entry.occ, entry); else cv.endMonthDrag()
      onCentroidChanged: if (active) cv.monthDragTo(entry.mapToItem(cv, centroid.position.x, centroid.position.y))
    }
  }

  // ---- the month -----------------------------------------------------------------------------

  property var dragOcc: null
  property var dragDay: null
  // (Another profile opening: a drag under way is over, its event that
  // one's, never moved in the next.)
  Connections {
    target: cv.workspace ? cv.workspace.files : null
    ignoreUnknownSignals: true
    function onSwitchingChanged() { if (cv.workspace.files.switching) { cv.dragOcc = null; cv.dragDay = null; cv.weekDrag = null } }
  }
  property point dragPoint: Qt.point(0, 0)
  function startMonthDrag(o, item) { dragOcc = o; dragDay = null }
  function monthDragTo(p) {
    dragPoint = p
    var q = cv.mapToItem(monthGrid, p.x, p.y)
    var cell = monthGrid.childAt(q.x, q.y)
    dragDay = cell && cell.day ? cell.day : null
  }
  function endMonthDrag() {
    var o = dragOcc
    var d = dragDay
    dragOcc = null
    dragDay = null
    if (!o || !d || same(d, o.start)) return
    var start = o.allDay ? Calendar.dayIso(d) : Calendar.timeIso(new Date(d.getFullYear(), d.getMonth(), d.getDate(), o.start.getHours(), o.start.getMinutes()))
    moveTo(o, start, "", null)
  }

  Item {
    id: month
    objectName: "calMonth"
    visible: cv.mode === "month"
    x: 24
    y: bar.y + bar.height + 12
    width: parent.width - 48
    height: parent.height - y - 18
    Row {
      id: weekdays
      width: parent.width
      Repeater {
        model: 7
        delegate: Text {
          required property int index
          width: month.width / 7
          leftPadding: 8
          textFormat: Text.PlainText
          text: Dates.SHORT_DAYS[(index + 1) % 7]
          font.family: cv.theme.uiFont
          font.pixelSize: 12
          font.weight: Font.DemiBold
          color: cv.theme.muted
        }
      }
    }
    Grid {
      id: monthGrid
      y: weekdays.height + 6
      width: parent.width
      height: parent.height - y
      columns: 7
      Repeater {
        model: 42
        delegate: Rectangle {
          id: cell
          required property int index
          objectName: "calDay"
          readonly property var day: cv.addDays(cv.gridFirst, index)
          readonly property bool inMonth: day.getMonth() === cv.anchorDay.getMonth()
          readonly property bool isToday: cv.same(day, cv.todayDay)
          readonly property var events: Calendar.onDay(cv.occ, day)
          readonly property var dated: cv.notesOn(day)
          readonly property int room: Math.max(0, Math.floor((height - 30) / 19))
          readonly property int total: events.length + dated.length
          width: monthGrid.width / 7
          height: monthGrid.height / 6
          color: cv.dragDay && cv.same(cv.dragDay, day) ? Qt.alpha(cv.theme.accent, 0.12) : cellHover.hovered && cv.dragOcc === null ? Qt.alpha(cv.theme.text, 0.025) : "transparent"
          border.width: 0
          Rectangle { anchors.top: parent.top; width: parent.width; height: 1; color: cv.theme.line }
          Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: cell.index % 7 === 6 ? "transparent" : cv.theme.line }
          // The day: a click shows its week.
          Rectangle {
            id: dayNum
            x: 6
            y: 5
            width: Math.max(22, numText.implicitWidth + 10)
            height: 22
            radius: 11
            color: cell.isToday ? cv.theme.accent : numHover.hovered ? Qt.alpha(cv.theme.text, 0.08) : "transparent"
            Text {
              id: numText
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: cell.day.getDate() === 1 ? cell.day.getDate() + " " + Dates.SHORT_MONTHS[cell.day.getMonth()] : String(cell.day.getDate())
              font.family: cv.theme.uiFont
              font.pixelSize: 12
              font.weight: cell.isToday ? Font.DemiBold : Font.Normal
              color: cell.isToday ? "white" : cell.inMonth ? cv.theme.text : cv.theme.faint
            }
            HoverHandler { id: numHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: cv.show(cell.day, "week") }
          }
          Column {
            x: 4
            y: 30
            width: parent.width - 8
            spacing: 1
            Repeater {
              model: cell.total > cell.room ? cell.events.slice(0, Math.max(0, cell.room - 1)) : cell.events
              delegate: Entry { required property var modelData; objectName: "calEntry"; occ: modelData; width: parent.width }
            }
            Repeater {
              model: { var used = cell.total > cell.room ? Math.max(0, cell.room - 1) - cell.events.length : cell.room - cell.events.length; return used > 0 ? cell.dated.slice(0, used) : [] }
              delegate: Entry { required property var modelData; objectName: "calNote"; note: modelData; width: parent.width }
            }
            Text {
              objectName: "calMore_"
              visible: cell.total > cell.room
              leftPadding: 6
              textFormat: Text.PlainText
              text: "+" + (cell.total - Math.max(0, cell.room - 1)) + " more"
              font.family: cv.theme.uiFont
              font.pixelSize: 11
              font.weight: Font.DemiBold
              color: cv.theme.muted
              HoverHandler { cursorShape: Qt.PointingHandCursor }
              TapHandler { onTapped: cv.show(cell.day, "week") }
            }
          }
          HoverHandler { id: cellHover }
          // A click on the day (not an event): a new one, that day.
          TapHandler {
            onTapped: function(point) {
              if (point.position.y < 30 && point.position.x < dayNum.x + dayNum.width + 4) return
              if (cv.over(cell, point.position.x, point.position.y, ["calEntry", "calNote", "calMore_"])) return
              cv.addAt(cell.day, -1, cell)
            }
          }
        }
      }
    }
  }

  // The event dragged in a month, under the pointer.
  Rectangle {
    visible: cv.dragOcc !== null && cv.mode === "month"
    x: cv.dragPoint.x + 10
    y: cv.dragPoint.y - height / 2
    z: 9
    width: Math.min(220, ghostText.implicitWidth + 20)
    height: 26
    radius: 6
    color: cv.dragOcc ? cv.fillOf(cv.dragOcc.color) : "transparent"
    border.width: 1
    border.color: cv.dragOcc ? cv.tintOf(cv.dragOcc.color) : "transparent"
    Text {
      id: ghostText
      x: 10
      anchors.verticalCenter: parent.verticalCenter
      width: parent.width - 20
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: cv.dragOcc ? cv.dragOcc.title || "Untitled" : ""
      font.family: cv.theme.uiFont
      font.pixelSize: 12
      color: cv.theme.text
    }
  }

  // ---- the week ------------------------------------------------------------------------------

  readonly property real hourH: 48
  readonly property real gutter: 54
  function scrollToMorning() {
    var y = Math.max(0, 7 * hourH - 8)
    weekFlick.contentY = Math.min(y, Math.max(0, weekFlick.contentHeight - weekFlick.height))
  }

  // An event moved or made longer (week): where it would go, as it's dragged.
  property var weekDrag: null   // { occ, kind: "move" | "end", day (index), minutes (start), length (minutes) }

  function minutesOf(d) { return d.getHours() * 60 + d.getMinutes() }

  function weekDragFinish() {
    var w = weekDrag
    weekDrag = null
    if (!w) return
    var d = addDays(weekFirst, w.day)
    if (w.kind === "move") {
      var st = new Date(d.getFullYear(), d.getMonth(), d.getDate(), Math.floor(w.minutes / 60), w.minutes % 60)
      if (st.getTime() === w.occ.start.getTime()) return
      moveTo(w.occ, Calendar.timeIso(st), "", null)
    } else {
      var end = new Date(w.occ.start.getTime() + w.length * 60000)
      if (end.getTime() === w.occ.end.getTime()) return
      moveTo(w.occ, Calendar.timeIso(w.occ.start), Calendar.timeIso(end), null)
    }
  }

  Item {
    id: week
    objectName: "calWeek"
    visible: cv.mode === "week"
    x: 16
    y: bar.y + bar.height + 12
    width: parent.width - 32
    height: parent.height - y - 12
    readonly property real colW: (width - cv.gutter) / 7

    // The days, and what's all day on them.
    Row {
      id: weekHead
      x: cv.gutter
      Repeater {
        model: 7
        delegate: Item {
          required property int index
          readonly property var day: cv.addDays(cv.weekFirst, index)
          width: week.colW
          height: 30
          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: Dates.SHORT_DAYS[parent.day.getDay()] + " " + parent.day.getDate()
            font.family: cv.theme.uiFont
            font.pixelSize: 13
            font.weight: cv.same(parent.day, cv.todayDay) ? Font.Bold : Font.DemiBold
            color: cv.same(parent.day, cv.todayDay) ? cv.theme.accent : cv.theme.text
          }
        }
      }
    }
    // (Each day in its own place: a Row would close up the empty ones.)
    Item {
      id: allDayRow
      x: cv.gutter
      y: weekHead.height
      width: 7 * week.colW
      height: { var h = 0; for (var i = 0; i < adRepeater.count; i++) { var c = adRepeater.itemAt(i); if (c) h = Math.max(h, c.height) } return h }
      Repeater {
        id: adRepeater
        model: 7
        delegate: Column {
          id: adCol
          required property int index
          readonly property var day: cv.addDays(cv.weekFirst, index)
          x: index * week.colW
          width: week.colW
          spacing: 1
          Repeater {
            model: Calendar.onDay(cv.occ, adCol.day).filter(function(o) { return o.allDay })
            delegate: Entry { required property var modelData; objectName: "calEntry"; occ: modelData; width: adCol.width - 4; x: 2 }
          }
          Repeater {
            model: cv.notesOn(adCol.day).filter(function(n) { return !n.time })
            delegate: Entry { required property var modelData; objectName: "calNote"; note: modelData; width: adCol.width - 4; x: 2 }
          }
        }
      }
    }
    Rectangle { y: allDayRow.y + allDayRow.height + 4; width: parent.width; height: 1; color: cv.theme.line }

    Flickable {
      id: weekFlick
      y: allDayRow.y + allDayRow.height + 5
      width: parent.width
      height: parent.height - y
      contentHeight: 24 * cv.hourH + 10
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      interactive: cv.weekDrag === null
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

      Item {
        id: grid
        objectName: "calGrid"
        width: weekFlick.width
        height: 24 * cv.hourH

        // The hours.
        Repeater {
          model: 24
          delegate: Item {
            required property int index
            y: index * cv.hourH
            width: grid.width
            height: cv.hourH
            Rectangle { visible: index > 0; x: cv.gutter; width: parent.width - cv.gutter; height: 1; color: cv.theme.line }
            Text {
              visible: index > 0
              x: cv.gutter - width - 8
              y: -height / 2
              textFormat: Text.PlainText
              // On a 12-hour clock, "9 am", "1 pm".
              text: cv.theme.twelveHour ? (index % 12 === 0 ? 12 : index % 12) + (index < 12 ? " am" : " pm") : index + ":00"
              font.family: cv.theme.uiFont
              font.pixelSize: 11
              color: cv.theme.faint
            }
          }
        }
        // A click on a time: a new event then.
        TapHandler {
          onTapped: function(point) {
            var x = point.position.x - cv.gutter
            if (x < 0) return
            if (cv.over(grid, point.position.x, point.position.y, ["calBlock", "calNote", "calResize"])) return
            var di = Math.floor(x / week.colW)
            var minutes = Math.floor(point.position.y / cv.hourH * 2) * 30
            cv.addAt(cv.addDays(cv.weekFirst, di), Math.max(0, Math.min(23 * 60 + 30, minutes)), slotMark)
          }
        }
        Item { id: slotMark; width: 1; height: 1 }

        // The days.
        Repeater {
          model: 7
          delegate: Item {
            id: dayCol
            required property int index
            readonly property var day: cv.addDays(cv.weekFirst, index)
            readonly property var laid: Calendar.columns(Calendar.onDay(cv.occ, day))
            x: cv.gutter + index * week.colW
            width: week.colW
            height: grid.height
            Rectangle { width: 1; height: parent.height; color: cv.theme.line }
            Rectangle {
              visible: cv.same(dayCol.day, cv.todayDay)
              anchors.fill: parent
              color: Qt.alpha(cv.theme.accent, 0.035)
            }
            // The dates in your notes with a time.
            Repeater {
              model: cv.notesOn(dayCol.day).filter(function(n) { return n.time })
              delegate: Rectangle {
                required property var modelData
                objectName: "calNote"
                x: 3
                y: cv.minutesOf(modelData.at) / 60 * cv.hourH - 9
                width: Math.min(dayCol.width - 6, noteText.implicitWidth + 12)
                height: 18
                radius: 9
                z: 3
                color: cv.theme.surface
                border.width: 1
                border.color: cv.theme.line
                Text {
                  id: noteText
                  anchors.centerIn: parent
                  width: parent.width - 10
                  elide: Text.ElideRight
                  textFormat: Text.PlainText
                  text: "\u23f0 " + modelData.title
                  font.family: cv.theme.uiFont
                  font.pixelSize: 11
                  font.italic: true
                  color: cv.theme.muted
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler { onTapped: cv.view.open(modelData.page) }
              }
            }
            // The events, side by side where they overlap.
            Repeater {
              model: dayCol.laid
              delegate: Rectangle {
                id: block
                required property var modelData
                readonly property var o: modelData.occ
                readonly property real fromMin: Math.max(0, (o.start - dayCol.day) / 60000)
                readonly property real toMin: Math.min(24 * 60, (o.end - dayCol.day) / 60000)
                readonly property bool dragging: cv.weekDrag !== null && cv.weekDrag.occ.key === o.key
                objectName: "calBlock"
                x: 2 + modelData.col * (dayCol.width - 4) / modelData.cols
                y: fromMin / 60 * cv.hourH + 1
                width: (dayCol.width - 4) / modelData.cols - 2
                height: Math.max(18, (toMin - fromMin) / 60 * cv.hourH - 2)
                radius: 5
                z: 2
                opacity: dragging ? 0.35 : 1
                color: cv.fillOf(o.color)
                Flash { objectName: "calFlash"; eventId: block.o.id }
                Rectangle { width: 3; height: parent.height; radius: 1.5; color: cv.tintOf(block.o.color) }
                Column {
                  x: 8
                  y: 3
                  width: parent.width - 10
                  Text {
                    width: parent.width
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: block.o.title || "Untitled"
                    font.family: cv.theme.uiFont
                    font.pixelSize: 12
                    font.weight: Font.DemiBold
                    color: cv.inkOn(block.o.color)
                  }
                  Text {
                    visible: block.height > 34
                    width: parent.width
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                    text: (cv.theme.twelveHour, Calendar.span(block.o, dayCol.day)) + (block.o.place ? "  \u00b7  " + block.o.place : "")
                    font.family: cv.theme.uiFont
                    font.pixelSize: 11
                    color: Qt.alpha(cv.inkOn(block.o.color), 0.75)
                  }
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                TapHandler {
                  gesturePolicy: TapHandler.ReleaseWithinBounds
                  onTapped: cv.openOcc(block.o, block)
                }
                // Moved: by a quarter of an hour, and to another day.
                DragHandler {
                  id: moveDrag
                  target: null
                  dragThreshold: 6
                  property real grab: 0
                  onActiveChanged: {
                    if (active) {
                      grab = centroid.pressPosition.y
                      cv.weekDrag = { occ: block.o, kind: "move", day: dayCol.index, minutes: Math.round(block.fromMin), length: Math.round((block.o.end - block.o.start) / 60000) }
                    } else cv.weekDragFinish()
                  }
                  onCentroidChanged: {
                    if (!active || !cv.weekDrag) return
                    var p = block.mapToItem(grid, centroid.position.x, centroid.position.y - grab)
                    var di = Math.max(0, Math.min(6, Math.floor((p.x - cv.gutter) / week.colW)))
                    var m = Math.max(0, Math.min(24 * 60 - 15, Math.round(p.y / cv.hourH * 4) * 15))
                    cv.weekDrag = { occ: block.o, kind: "move", day: di, minutes: m, length: cv.weekDrag.length }
                  }
                }
                // Its bottom edge: longer or shorter.
                Item {
                  objectName: "calResize"
                  anchors.bottom: parent.bottom
                  width: parent.width
                  height: 7
                  HoverHandler { cursorShape: Qt.SizeVerCursor }
                  DragHandler {
                    target: null
                    dragThreshold: 2
                    onActiveChanged: {
                      if (active) cv.weekDrag = { occ: block.o, kind: "end", day: dayCol.index, minutes: Math.round(block.fromMin), length: Math.round((block.o.end - block.o.start) / 60000) }
                      else cv.weekDragFinish()
                    }
                    onCentroidChanged: {
                      if (!active || !cv.weekDrag) return
                      var p = parent.mapToItem(grid, centroid.position.x, centroid.position.y)
                      var endMin = Math.round(p.y / cv.hourH * 4) * 15
                      var startMin = Math.round((block.o.start - dayCol.day) / 60000)
                      cv.weekDrag = { occ: block.o, kind: "end", day: dayCol.index, minutes: startMin, length: Math.max(15, endMin - startMin) }
                    }
                  }
                }
              }
            }
          }
        }

        // Where a dragged event would go.
        Rectangle {
          objectName: "calDragPreview"
          visible: cv.weekDrag !== null
          readonly property var w: cv.weekDrag
          x: w ? cv.gutter + w.day * week.colW + 2 : 0
          y: w ? w.minutes / 60 * cv.hourH + 1 : 0
          width: week.colW - 4
          height: w ? Math.max(18, w.length / 60 * cv.hourH - 2) : 0
          radius: 5
          z: 5
          color: w ? Qt.alpha(cv.tintOf(w.occ.color), 0.25) : "transparent"
          border.width: 1.5
          border.color: w ? cv.tintOf(w.occ.color) : "transparent"
          Text {
            x: 8
            y: 3
            width: parent.width - 10
            elide: Text.ElideRight
            textFormat: Text.PlainText
            readonly property var w: parent.w
            text: (cv.theme.twelveHour, w) ? Calendar.timeLabel(new Date(0, 0, 1, Math.floor(w.minutes / 60), w.minutes % 60)) + " \u2013 " + Calendar.timeLabel(new Date(0, 0, 1, Math.floor((w.minutes + w.length) / 60), (w.minutes + w.length) % 60)) : ""
            font.family: cv.theme.uiFont
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: cv.theme.text
          }
        }

        // Now.
        Rectangle {
          readonly property int di: Math.floor((cv.todayDay - cv.weekFirst) / 86400000)
          visible: di >= 0 && di < 7
          x: cv.gutter + di * week.colW - 4
          y: cv.minutesOf(new Date(cv.nowMs)) / 60 * cv.hourH - 1
          z: 6
          width: week.colW + 4
          height: 2
          color: cv.theme.dark ? "#ff6b6b" : "#e5484d"
          Rectangle { x: 0; y: -3; width: 8; height: 8; radius: 4; color: parent.color }
        }
      }
    }
  }

  // ---- compact: a small month, and the days from the one picked ------------------------------

  // Side by side when there's room, else the month above the days.
  readonly property bool compactWide: width >= 780

  Item {
    id: mini
    objectName: "calCompact"
    visible: cv.mode === "compact"
    x: cv.compactWide ? 24 : Math.max(24, (cv.width - width) / 2)
    y: bar.y + bar.height + 16
    width: cv.compactWide ? 336 : Math.min(420, cv.width - 48)
    height: miniGrid.y + miniGrid.height
    Row {
      id: miniDays
      width: parent.width
      Repeater {
        model: 7
        delegate: Text {
          required property int index
          width: mini.width / 7
          horizontalAlignment: Text.AlignHCenter
          textFormat: Text.PlainText
          text: Dates.SHORT_DAYS[(index + 1) % 7]
          font.family: cv.theme.uiFont
          font.pixelSize: 11
          font.weight: Font.DemiBold
          color: cv.theme.muted
        }
      }
    }
    Grid {
      id: miniGrid
      y: miniDays.height + 8
      columns: 7
      Repeater {
        model: 42
        delegate: Item {
          id: mcell
          required property int index
          objectName: "calMiniDay"
          readonly property var day: cv.addDays(cv.gridFirst, index)
          readonly property bool inMonth: day.getMonth() === cv.anchorDay.getMonth()
          readonly property bool isToday: cv.same(day, cv.todayDay)
          readonly property bool isPicked: cv.same(day, cv.pickedDay)
          readonly property var events: Calendar.onDay(cv.occ, day)
          readonly property int noteCount: cv.notesOn(day).length
          width: mini.width / 7
          height: 46
          // The day: today filled, the one picked ringed.
          Rectangle {
            id: mnum
            anchors.horizontalCenter: parent.horizontalCenter
            y: 4
            width: 30
            height: 30
            radius: 15
            color: mcell.isToday ? cv.theme.accent : mcell.isPicked ? Qt.alpha(cv.theme.accent, 0.14) : mHover.hovered ? Qt.alpha(cv.theme.text, 0.07) : "transparent"
            border.width: mcell.isPicked && !mcell.isToday ? 1.5 : 0
            border.color: cv.theme.accent
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: String(mcell.day.getDate())
              font.family: cv.theme.uiFont
              font.pixelSize: 13
              font.features: { "tnum": 1 }
              font.weight: mcell.isToday || mcell.isPicked ? Font.DemiBold : Font.Normal
              color: mcell.isToday ? "white" : mcell.isPicked ? cv.theme.accent : mcell.inMonth ? cv.theme.text : cv.theme.faint
            }
          }
          // A dot for each event (three at most), a ring for a date in your notes.
          Row {
            anchors.horizontalCenter: parent.horizontalCenter
            y: mnum.y + mnum.height + 3
            spacing: 3
            opacity: mcell.inMonth ? 1 : 0.45
            Repeater {
              model: mcell.events.slice(0, 3)
              delegate: Rectangle { required property var modelData; width: 5; height: 5; radius: 2.5; color: cv.tintOf(modelData.color) }
            }
            Rectangle {
              visible: mcell.noteCount > 0 && mcell.events.length < 3
              width: 5
              height: 5
              radius: 2.5
              color: "transparent"
              border.width: 1
              border.color: cv.theme.muted
            }
          }
          HoverHandler { id: mHover; cursorShape: Qt.PointingHandCursor }
          // A click picks it; a double-click adds an event on it.
          TapHandler {
            onTapped: cv.pick(mcell.day)
            onDoubleTapped: cv.addAt(mcell.day, -1, mcell)
          }
        }
      }
    }
  }
  // Between the month and the days.
  Rectangle {
    visible: cv.mode === "compact" && cv.compactWide
    x: mini.x + mini.width + 20
    y: mini.y
    width: 1
    height: cv.height - y - 18
    color: cv.theme.line
  }

  // ---- the agenda ----------------------------------------------------------------------------

  // The days listed: the agenda's (from the day shown, 60 days, those with
  // something on), or compact's (from the day picked, a month on; the day
  // picked even with nothing on).
  readonly property var agendaDays: {
    if (mode !== "agenda" && mode !== "compact") return []
    var compact = mode === "compact"
    var from = compact ? pickedDay : anchorDay
    var out = []
    for (var i = 0; i < (compact ? 31 : 60); i++) {
      var d = addDays(from, i)
      var ev = Calendar.onDay(occ, d)
      var nd = notesOn(d)
      if (ev.length || nd.length || (compact && i === 0)) out.push({ day: d, events: ev, notes: nd, first: i === 0 })
    }
    return out
  }

  ListView {
    id: agenda
    objectName: "calAgenda"
    visible: cv.mode === "agenda" || cv.mode === "compact"
    readonly property bool beside: cv.mode === "compact" && cv.compactWide
    readonly property bool below: cv.mode === "compact" && !cv.compactWide
    // (Its left beside the month, else centered: worked out apart from its width.)
    readonly property real leftEdge: beside ? mini.x + mini.width + 44 : 0
    width: beside ? Math.min(680, cv.width - leftEdge - 24) : Math.min(760, cv.width - 48)
    x: beside ? leftEdge : Math.max(24, (cv.width - width) / 2)
    y: below ? mini.y + mini.height + 18 : bar.y + bar.height + 16
    height: parent.height - y - 12
    clip: true
    spacing: 14
    boundsBehavior: Flickable.StopAtBounds
    model: cv.agendaDays
    ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
    delegate: Column {
      id: dayBlock
      required property var modelData
      // The day picked in compact: its name larger, + always there.
      readonly property bool lead: cv.mode === "compact" && dayBlock.modelData.first
      width: agenda.width
      spacing: 2
      // The day (+ under the pointer: an event on it).
      Item {
        width: parent.width
        height: dayName.implicitHeight + 4
        Text {
          id: dayName
          objectName: "calAgendaDay"
          textFormat: Text.PlainText
          text: (cv.same(dayBlock.modelData.day, cv.todayDay) ? "Today  \u00b7  " : cv.same(dayBlock.modelData.day, cv.addDays(cv.todayDay, 1)) ? "Tomorrow  \u00b7  " : "")
            + Qt.locale().dayName(dayBlock.modelData.day.getDay()) + " " + dayBlock.modelData.day.getDate() + " " + Qt.locale().monthName(dayBlock.modelData.day.getMonth())
          font.family: cv.theme.uiFont
          font.pixelSize: dayBlock.lead ? 16 : 13
          font.weight: Font.DemiBold
          color: cv.same(dayBlock.modelData.day, cv.todayDay) ? cv.theme.accent : cv.theme.text
        }
        HoverHandler { id: dayHover }
        IconButton {
          id: dayAdd
          objectName: "calAgendaAdd"
          anchors.right: parent.right
          anchors.verticalCenter: dayName.verticalCenter
          visible: dayBlock.lead || dayHover.hovered
          theme: cv.theme; icon: cv.theme.icons.plus; size: 26; iconSize: 14
          tip: "An event on this day"
          onClicked: cv.addAt(dayBlock.modelData.day, -1, dayAdd)
        }
      }
      Text {
        visible: dayBlock.modelData.events.length + dayBlock.modelData.notes.length === 0
        leftPadding: 10
        topPadding: 4
        bottomPadding: 6
        textFormat: Text.PlainText
        text: "Nothing on."
        font.family: cv.theme.uiFont
        font.pixelSize: 13
        color: cv.theme.muted
      }
      Repeater {
        model: dayBlock.modelData.events
        delegate: Rectangle {
          id: arow
          required property var modelData
          objectName: "calAgendaRow"
          width: dayBlock.width
          height: 36
          radius: 7
          color: arowHover.hovered ? Qt.alpha(cv.theme.text, 0.05) : "transparent"
          Flash { objectName: "calFlash"; eventId: arow.modelData && arow.modelData.id ? arow.modelData.id : "" }
          Text {
            objectName: "calAgendaSpan"
            x: 10
            width: cv.spanW
            elide: Text.ElideRight
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: (cv.theme.twelveHour, Calendar.span(arow.modelData, dayBlock.modelData.day))
            font.family: cv.theme.uiFont
            font.pixelSize: 12
            font.features: { "tnum": 1 }
            color: cv.theme.muted
          }
          Rectangle { x: cv.spanW + 14; anchors.verticalCenter: parent.verticalCenter; width: 4; height: 20; radius: 2; color: cv.tintOf(arow.modelData.color) }
          Text {
            x: cv.spanW + 28
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 12
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: (arow.modelData.title || "Untitled") + (arow.modelData.place ? "  \u00b7  " + arow.modelData.place : "") + (arow.modelData.repeats ? "  \u21bb" : "")
            font.family: cv.theme.uiFont
            font.pixelSize: 14
            color: cv.theme.text
          }
          HoverHandler { id: arowHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: cv.openOcc(arow.modelData, arow) }
        }
      }
      Repeater {
        model: dayBlock.modelData.notes
        delegate: Rectangle {
          id: nrow
          required property var modelData
          objectName: "calNote"
          width: dayBlock.width
          height: 32
          radius: 7
          color: nrowHover.hovered ? Qt.alpha(cv.theme.text, 0.05) : "transparent"
          Text {
            x: 10
            width: cv.spanW
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: (cv.theme.twelveHour, nrow.modelData.time) ? Calendar.timeLabel(nrow.modelData.at) : nrow.modelData.kind === "due" ? "Due" : "All day"
            font.family: cv.theme.uiFont
            font.pixelSize: 12
            color: cv.theme.faint
          }
          Text {
            x: cv.spanW + 28
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 12
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: (nrow.modelData.kind === "due" ? "\u2691 " : "\u23f0 ") + nrow.modelData.title + (nrow.modelData.text && nrow.modelData.kind !== "due" ? ": " + nrow.modelData.text : "")
            font.family: cv.theme.uiFont
            font.pixelSize: 13
            font.italic: true
            color: cv.theme.muted
          }
          HoverHandler { id: nrowHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: cv.view.open(nrow.modelData.page) }
        }
      }
    }
    Text {
      visible: agenda.count === 0
      width: agenda.width
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      text: "Nothing on in the next 60 days. N, or + New event, adds one; reminders and projects' due dates show here too."
      font.family: cv.theme.uiFont
      font.pixelSize: 14
      color: cv.theme.muted
    }
  }
}
