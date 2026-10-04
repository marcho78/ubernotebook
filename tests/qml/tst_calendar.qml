import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Workspace.js" as Workspace
import "../../Calendar.js" as Calendar

// The calendar in Pages: kept in Pages/calendar.json; opened from the
// sidebar; an event added by a click on a day and typing; changed in its
// editor (its title, repeat, alert, color), taken off (a repeating one's
// time, or all of it) and put back with Undo; moved by dragging (in a
// month, in a week; a repeating one asks); its alert as a notification;
// notes for it; Today in the sidebar; your notes' dates on it; .ics.
Item {
  id: root
  width: 1400
  height: 900

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  UberNotebook.Workspace { id: ws; files: files }
  property string lastToast: ""
  property var lastUndo: null

  DocView {
    id: view
    anchors.fill: parent
    theme: th
    workspace: ws
    service: service
    onToast: function(text) { root.lastToast = text }
    onToastUndo: function(text, undo) { root.lastToast = text; root.lastUndo = undo }
  }

  QtObject {
    id: ui
    function saveNow() { view.commit() }
  }
  UberNotebook.Api {
    id: api
    workspace: ws
    files: files
    ui: ui
  }

  TestCase {
    name: "Calendar"
    when: windowShown

    function fresh() {
      // (An event's editor left open by the test before: closed.)
      view.closeEvent()
      tryVerify(function() { return !view.eventEditorOpen }, 1000)
      files.reset()
      view.page = null
      view.calendarShown = false
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      tryCompare(ws, "calendarLoaded", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      root.lastToast = ""
      wait(0)
    }
    function find(item, test) {
      if (!item) return null
      if (item.visible && test(item)) return item
      for (var i = 0; i < item.children.length; i++) {
        var hit = find(item.children[i], test)
        if (hit) return hit
      }
      return null
    }
    function findAll(item, test, out) {
      if (!item) return out
      if (item.visible && test(item)) out.push(item)
      for (var i = 0; i < item.children.length; i++) findAll(item.children[i], test, out)
      return out
    }
    function named(item, name) { return find(item, function(it) { return it.objectName === name }) }
    function win() { return root.Window.window.contentItem }
    function click(item) { verify(item !== null); wait(150); mouseClick(item) }
    function type(text) {
      for (var i = 0; i < text.length; i++) keyClick(text.charAt(i) === " " ? Qt.Key_Space : text.charAt(i))
    }
    function iso(d, h, m) { return Calendar.timeIso(new Date(d.getFullYear(), d.getMonth(), d.getDate(), h, m || 0)) }
    function today() { var n = new Date(); return new Date(n.getFullYear(), n.getMonth(), n.getDate()) }
    function plus(d, n) { return new Date(d.getFullYear(), d.getMonth(), d.getDate() + n) }
    function add(o) {
      var e = Calendar.cleanEvent(o)
      ws.setCalendar(Calendar.withEvent(ws.calendar, e))
      return e
    }
    function onDisk() { return files.parseJson(files.disk[ws.calendarPath()] || "") }
    function cv() { return view.calendarView }
    // The day cell of a date in the month shown.
    function cell(d) {
      return find(cv(), function(it) { return it.objectName === "calDay" && it.day && Calendar.dayIso(it.day) === Calendar.dayIso(d) })
    }
    function entry(title) { return find(cv(), function(it) { return it.objectName === "calEntry" && it.occ && it.occ.title === title }) }

    function test_1_kept_and_opened() {
      fresh()
      var e = add({ title: "Dentist", start: iso(today(), 15), end: iso(today(), 15, 45), color: "blue" })
      tryVerify(function() { var d = onDisk(); return d && d.events.length === 1 && d.events[0].title === "Dentist" }, 1000, "in Pages/calendar.json")
      // Read again, as when Uber Notebook starts.
      ws.calendar = Calendar.make()
      ws.loadCalendar()
      tryVerify(function() { return ws.calendar.events.length === 1 }, 1000)
      // From the sidebar.
      click(named(win(), "calendarTile"))
      tryVerify(function() { return view.calendarShown }, 1000)
      tryVerify(function() { return entry("Dentist") !== null }, 1000, "on its day")
      // Today, in the sidebar (it's later today).
      if (new Date().getHours() < 15) tryVerify(function() { return named(win(), "todayRow") !== null }, 1000, "Today in the sidebar")
      // The week, and the agenda.
      click(named(win(), "calMode_week"))
      tryVerify(function() { return named(cv(), "calBlock") !== null }, 1000)
      click(named(win(), "calMode_agenda"))
      tryVerify(function() { return named(cv(), "calAgendaRow") !== null }, 1000)
      // Back: the page before.
      view.back()
      tryVerify(function() { return !view.calendarShown && view.page !== null }, 2000)
    }

    function test_2_a_click_on_a_day_and_typing() {
      fresh()
      view.openCalendar("")
      var d = plus(today(), 2)
      cv().show(d, "month")
      wait(100)
      var c = null
      tryVerify(function() { c = cell(d); return c !== null }, 1000)
      mouseClick(c, c.width / 2, c.height - 12)
      var field = null
      tryVerify(function() { field = named(win(), "quickAdd"); return field !== null }, 1000)
      wait(200)
      type("Lunch with Sam 12:30")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return ws.calendar.events.length === 1 }, 1000)
      var e = ws.calendar.events[0]
      compare(e.title, "Lunch with Sam")
      verify(/T12:30$/.test(e.start), e.start)
      // With a day typed, it's that day.
      mouseClick(c, c.width / 2, c.height - 12)
      tryVerify(function() { return named(win(), "quickAdd") !== null }, 1000)
      wait(200)
      type("Holiday dec 24")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return ws.calendar.events.length === 2 }, 1000)
      var h = ws.calendar.events[1]
      compare(h.allDay, true)
      verify(/-12-24$/.test(h.start), h.start)
    }

    function test_3_changed_in_its_editor() {
      fresh()
      var e = add({ title: "Review", start: iso(today(), 10), end: iso(today(), 11) })
      view.openCalendar("")
      var en = null
      tryVerify(function() { en = entry("Review"); return en !== null }, 1000)
      click(en)
      var title = null
      tryVerify(function() { title = named(win(), "eventTitle"); return title !== null }, 1000, "its editor")
      wait(200)
      title.text = "Weekly review"
      title.accepted()
      tryCompare(ws.calendar.events[0], "title", "Weekly review", 1000)
      click(named(win(), "eventRepeat_weekly"))
      tryVerify(function() { return ws.calendar.events[0].repeat && ws.calendar.events[0].repeat.freq === "weekly" }, 1000)
      click(named(win(), "eventAlert_30"))
      tryVerify(function() { return ws.calendar.events[0].alert === 30 }, 1000)
      // Its time, typed.
      var st = named(win(), "eventStartTime")
      st.text = "2pm"
      st.accepted()
      tryVerify(function() { return /T14:00$/.test(ws.calendar.events[0].start) && /T15:00$/.test(ws.calendar.events[0].end) }, 1000, "as long as it was")
      // Its color.
      click(named(win(), "eventColor"))
      var tile = null
      tryVerify(function() { tile = find(win(), function(it) { return it.entry !== undefined && it.entry && it.entry.id === "green" }); return tile !== null }, 1000)
      wait(250)
      mouseClick(tile)
      tryVerify(function() { return ws.calendar.events[0].color === "green" }, 1000)
      wait(200)
      // Undo: one step at a time.
      var before = ws.calendar.events[0].alert
      ws.undoCalendar()
      tryVerify(function() { return ws.calendar.events[0].color === "" }, 1000)
      ws.redoCalendar()
      tryVerify(function() { return ws.calendar.events[0].color === "green" }, 1000)
    }

    function test_4_taken_off_and_put_back() {
      fresh()
      var t = today()
      var one = add({ title: "Call", start: iso(t, 9), end: iso(t, 9, 30) })
      var rep = add({ title: "Standup", start: iso(plus(t, -3), 9, 30), end: iso(plus(t, -3), 9, 45), repeat: { freq: "daily" } })
      // A repeating one: just this time.
      view.openEvent(rep.id, Calendar.dayIso(t), view)
      tryVerify(function() { return named(win(), "eventDelete") !== null }, 1000)
      click(named(win(), "eventDelete"))
      var opt = null
      tryVerify(function() { opt = find(win(), function(it) { return it.objectName === "askOption" && it.text === "Just this one" }); return opt !== null }, 1000)
      wait(250)
      mouseClick(opt)
      tryVerify(function() { return Calendar.byId(ws.calendar, rep.id).skip.indexOf(Calendar.dayIso(t)) >= 0 }, 1000)
      verify(root.lastToast.indexOf("off the calendar") >= 0)
      root.lastUndo()
      tryVerify(function() { return Calendar.byId(ws.calendar, rep.id).skip.length === 0 }, 1000, "Undo puts it back")
      wait(300)
      // The ones after.
      view.openEvent(rep.id, Calendar.dayIso(t), view)
      tryVerify(function() { return named(win(), "eventDelete") !== null }, 1000)
      click(named(win(), "eventDelete"))
      tryVerify(function() { opt = find(win(), function(it) { return it.objectName === "askOption" && it.text === "This one and the ones after" }); return opt !== null }, 1000)
      wait(250)
      mouseClick(opt)
      tryVerify(function() { return Calendar.byId(ws.calendar, rep.id).repeat.until === Calendar.dayIso(plus(t, -1)) }, 1000)
      wait(300)
      // A one-off: gone.
      view.openEvent(one.id, "", view)
      tryVerify(function() { return named(win(), "eventDelete") !== null }, 1000)
      click(named(win(), "eventDelete"))
      tryVerify(function() { return Calendar.byId(ws.calendar, one.id) === null }, 1000)
    }

    function test_5_dragged_in_a_month_and_a_week() {
      fresh()
      var t = today()
      var e = add({ title: "Move me", start: iso(t, 10), end: iso(t, 11) })
      view.openCalendar("")
      cv().show(t, "month")
      var src = null
      tryVerify(function() { src = entry("Move me"); return src !== null }, 1000)
      // To another day in the month shown.
      var to = t.getDate() < 20 ? plus(t, 2) : plus(t, -2)
      var dst = cell(to)
      var p0 = src.mapToItem(root, 20, src.height / 2)
      var p1 = dst.mapToItem(root, dst.width / 2, dst.height - 10)
      mousePress(root, p0.x, p0.y)
      for (var i = 1; i <= 10; i++) mouseMove(root, p0.x + (p1.x - p0.x) * i / 10, p0.y + (p1.y - p0.y) * i / 10)
      wait(30)
      mouseRelease(root, p1.x, p1.y)
      tryVerify(function() { return ws.calendar.events[0].start === iso(to, 10) }, 1000, "moved, at its time: " + ws.calendar.events[0].start)
      compare(ws.calendar.events[0].end, iso(to, 11))
      // In a week: an hour later, by dragging.
      cv().show(to, "week")
      var block = null
      tryVerify(function() { block = find(cv(), function(it) { return it.objectName === "calBlock" && it.o && it.o.title === "Move me" }); return block !== null }, 1000)
      wait(100)
      var b0 = block.mapToItem(root, block.width / 2, 10)
      mousePress(root, b0.x, b0.y)
      for (var j = 1; j <= 10; j++) mouseMove(root, b0.x, b0.y + cv().hourH * j / 10)
      wait(30)
      mouseRelease(root, b0.x, b0.y + cv().hourH)
      tryVerify(function() { return ws.calendar.events[0].start === iso(to, 11) }, 1000, "an hour later: " + ws.calendar.events[0].start)
      compare(ws.calendar.events[0].end, iso(to, 12))
      // Its bottom edge: longer.
      tryVerify(function() { block = find(cv(), function(it) { return it.objectName === "calBlock" && it.o && it.o.title === "Move me" }); return block !== null && Math.abs(block.y - 11 * cv().hourH - 1) < 2 }, 1000)
      wait(100)
      var edge = find(block, function(it) { return it.objectName === "calResize" })
      var r0 = edge.mapToItem(root, edge.width / 2, edge.height / 2)
      mousePress(root, r0.x, r0.y)
      for (var k = 1; k <= 10; k++) mouseMove(root, r0.x, r0.y + cv().hourH / 2 * k / 10)
      wait(30)
      mouseRelease(root, r0.x, r0.y + cv().hourH / 2)
      tryVerify(function() { return ws.calendar.events[0].end === iso(to, 12, 30) }, 1000, "half an hour longer: " + ws.calendar.events[0].end)
    }

    function test_6_a_repeating_one_moved_asks() {
      fresh()
      var t = today()
      var rep = add({ title: "Standup", start: iso(plus(t, -7), 9, 30), end: iso(plus(t, -7), 9, 45), repeat: { freq: "daily" } })
      var occ = Calendar.occurrences(ws.calendar, t, plus(t, 1))[0]
      view.openCalendar("")
      cv().moveTo(occ, iso(t, 10), "", null)
      var opt = null
      tryVerify(function() { opt = find(win(), function(it) { return it.objectName === "askOption" && it.text === "Just this one" }); return opt !== null }, 1000)
      wait(250)
      mouseClick(opt)
      tryVerify(function() { return ws.calendar.events.length === 2 }, 1000, "this one, an event of its own")
      var mine = ws.calendar.events.filter(function(e) { return e.id !== rep.id })[0]
      compare(mine.start, iso(t, 10))
      compare(mine.end, iso(t, 10, 15))
      verify(Calendar.byId(ws.calendar, rep.id).skip.indexOf(Calendar.dayIso(t)) >= 0)
      // Every one: the repeat moved as much.
      ws.undoCalendar()
      wait(300)
      cv().moveTo(occ, iso(t, 10), "", null)
      tryVerify(function() { opt = find(win(), function(it) { return it.objectName === "askOption" && it.text === "Every one" }); return opt !== null }, 1000)
      wait(250)
      mouseClick(opt)
      tryVerify(function() { return Calendar.byId(ws.calendar, rep.id).start === iso(plus(t, -7), 10) }, 1000)
      compare(ws.calendar.events.length, 1)
    }

    function test_7_alerts_notes_dates_and_ics() {
      fresh()
      var t = today()
      var now = new Date()
      // An alert, as a notification (its day, to open the calendar on).
      var soon = new Date(now.getTime() - 30000)
      var e = add({ title: "Call the bank", start: Calendar.timeIso(new Date(soon.getTime() + 60000 * 5)), end: Calendar.timeIso(new Date(soon.getTime() + 60000 * 35)), alert: 5 })
      ws.checkReminders()
      tryVerify(function() { return files.notified.some(function(n) { return n.title === "Call the bank" }) }, 2000, "the alert came")
      var n = files.notified.filter(function(x) { return x.title === "Call the bank" })[0]
      verify(n.text.indexOf("In 5 min") === 0, n.text)
      compare(n.day, Calendar.dayIso(new Date(soon.getTime() + 60000 * 5)))
      var count = files.notified.length
      ws.checkReminders()
      compare(files.notified.length, count, "once")
      // Notes for it: a page, linked; again, the same page.
      view.notesForEvent(e.id, "")
      tryVerify(function() { return Calendar.byId(ws.calendar, e.id).page !== "" }, 2000)
      var pageId = Calendar.byId(ws.calendar, e.id).page
      tryVerify(function() { return view.page && view.page.id === pageId }, 2000)
      verify(ws.index.pages[pageId].title.indexOf("Call the bank \u00b7 ") === 0, ws.index.pages[pageId].title)
      view.notesForEvent(e.id, "")
      wait(200)
      compare(Object.keys(ws.index.pages).filter(function(id) { return ws.index.pages[id].title === ws.index.pages[pageId].title }).length, 1)
      // A project's due date on the calendar.
      var p = ws.createPage({ parent: "", title: "Launch", project: { status: "active", due: Calendar.dayIso(plus(t, 1)) } })
      view.openCalendar("")
      cv().show(plus(t, 1), "week")
      tryVerify(function() { return find(cv(), function(it) { return it.objectName === "calNote" && it.note && it.note.title === "Launch" }) !== null }, 1000)
      // Exported as .ics.
      var path = ""
      ws.exportCalendar(function(x) { path = x })
      tryVerify(function() { return path !== "" }, 1000)
      verify(files.disk[path].indexOf("SUMMARY:Call the bank") > 0)
    }

    function test_8_an_agenda_and_an_event_on_a_page() {
      fresh()
      var t = today()
      add({ title: "Standup", start: iso(t, 9, 30), end: iso(t, 9, 45), repeat: { freq: "daily" } })
      add({ title: "Lunch", start: iso(plus(t, 1), 12), end: iso(plus(t, 1), 13) })
      var e = view.editor
      e.focusBlock(e.uidAt(e.model.count - 1), 0)
      type("/agenda")
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 }, 1000)
      compare(e.slashItems[0].id, "agenda")
      keyClick(Qt.Key_Return)
      var at = e.serialize().map(function(b) { return b.type }).indexOf("agenda")
      verify(at >= 0)
      var uid = e.uidAt(at)
      var ag = null
      tryVerify(function() { ag = e.items[uid] ? e.items[uid].calView : null; return ag !== null }, 1000)
      tryVerify(function() { return find(ag, function(it) { return it.objectName === "agendaRow" && it.modelData.title === "Standup" }) !== null }, 1000, "today's")
      // The day after.
      click(named(ag, "agendaOn"))
      tryVerify(function() { return find(ag, function(it) { return it.objectName === "agendaRow" && it.modelData.title === "Lunch" }) !== null }, 1000)
      compare(e.serialize()[at].calendar.day, Calendar.dayIso(plus(t, 1)), "kept on the block")
      click(named(ag, "agendaToday"))
      tryVerify(function() { return e.serialize()[at].calendar.day === "" }, 1000)
      // Added from it, that day; on the calendar, so in it.
      click(named(ag, "agendaAdd"))
      tryVerify(function() { return named(win(), "quickAdd") !== null }, 1000)
      wait(200)
      type("Call Sam today 17:00")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return find(ag, function(it) { return it.objectName === "agendaRow" && it.modelData.title === "Call Sam" }) !== null }, 1000)
      // As Markdown: the day's events.
      view.copyMarkdown()
      verify(files.copied.indexOf("9:30 \u2013 9:45: Standup") > 0, files.copied)
      // "/event": typed, put on the calendar and on the page.
      e.focusBlock(e.uidAt(e.model.count - 1), 0)
      type("/event")
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 && e.slashItems[0].id === "event" }, 1000)
      keyClick(Qt.Key_Return)
      tryVerify(function() { return named(win(), "quickAdd") !== null }, 1000)
      wait(200)
      type("Dentist tomorrow 3pm")
      keyClick(Qt.Key_Return)
      var dentist = null
      tryVerify(function() { dentist = ws.calendar.events.filter(function(x) { return x.title === "Dentist" })[0]; return dentist !== undefined }, 1000)
      var eat = -1
      tryVerify(function() { eat = e.serialize().map(function(b) { return b.type }).indexOf("event"); return eat >= 0 }, 1000, "its block")
      compare(e.serialize()[eat].calendar.id, dentist.id)
      var ev = e.items[e.uidAt(eat)].calView
      tryVerify(function() { return named(ev, "eventBlockTitle").text === "Dentist" }, 1000)
      // Changed on the calendar: changed here.
      var d2 = JSON.parse(JSON.stringify(dentist))
      d2.title = "Dentist (Dr. Lee)"
      ws.setCalendar(Calendar.withEvent(ws.calendar, d2))
      tryVerify(function() { return named(ev, "eventBlockTitle").text === "Dentist (Dr. Lee)" }, 1000)
      // Off the calendar: it says so.
      ws.setCalendar(Calendar.without(ws.calendar, dentist.id))
      tryVerify(function() { return named(ev, "eventBlockTitle").text.indexOf("isn't on the calendar") > 0 }, 1000)
      // Its colors.
      ws.undoCalendar()
      tryVerify(function() { return named(ev, "eventBlockTitle").text === "Dentist (Dr. Lee)" }, 1000)
      // (Its color button shows on hover; the block's below the fold here.)
      ev.askColors(ev)
      var tile = null
      tryVerify(function() { tile = find(win(), function(it) { return it.entry !== undefined && it.entry && it.entry.id === "yellow" && it.back === true }); return tile !== null }, 1000)
      wait(250)
      mouseClick(tile)
      tryVerify(function() { return e.serialize()[eat].calendar.background === "yellow" }, 1000)
    }

    // Compact: a small month (a dot for each event), the days from the one
    // picked beside it, + on a day adding one there; ← → a month; the view
    // kept for next time; a narrow window folding the views into a menu.
    function test_9b_compact() {
      fresh()
      var t = today()
      add({ title: "Dentist", start: iso(t, 15), end: iso(t, 15, 45), color: "blue" })
      var later = plus(t, 3)
      add({ title: "Gym", start: iso(later, 18), end: iso(later, 19), color: "red" })
      view.openCalendar("")
      tryVerify(function() { return cv().visible }, 1000)
      cv().restored = true
      click(named(cv(), "calMode_compact"))
      tryCompare(cv(), "mode", "compact")
      compare(service.user.calendarView, "compact", "kept for next time")
      var mini = function(d) { return find(cv(), function(it) { return it.objectName === "calMiniDay" && Calendar.dayIso(it.day) === Calendar.dayIso(d) }) }
      tryVerify(function() { return mini(t) !== null && mini(t).isPicked && mini(t).isToday }, 1000, "today picked")
      verify(mini(t).events.length >= 1, "a dot for the Dentist")
      var days = function() { return findAll(cv(), function(it) { return it.objectName === "calAgendaDay" }, []).map(function(x) { return x.text }) }
      tryVerify(function() { return days().length > 0 && days()[0].indexOf("Today") === 0 }, 1000, JSON.stringify(days()))
      verify(find(cv(), function(it) { return it.objectName === "calAgendaRow" && it.modelData.title === "Dentist" }) !== null)
      // + by the day picked, always there.
      var addBtn = named(cv(), "calAgendaAdd")
      verify(addBtn !== null, "+ by the day picked")
      var p = addBtn.mapToItem(cv(), 0, 0)
      verify(p.x + addBtn.width <= cv().width && p.x > 0, "on screen: " + p.x + " of " + cv().width)
      // Another day picked: the days from it.
      if (!mini(later)) { click(named(cv(), "calOn")); }
      click(mini(later))
      tryVerify(function() { return cv().same(cv().pickedDay, later) && days()[0].indexOf(String(later.getDate())) >= 0 }, 1000, JSON.stringify(days()))
      verify(find(cv(), function(it) { return it.objectName === "calAgendaRow" && it.modelData.title === "Gym" }) !== null)
      // A day with nothing on: said so; + puts an event on it.
      var empty = plus(later, 1)
      if (!mini(empty)) click(named(cv(), "calOn"))
      click(mini(empty))
      tryVerify(function() { return find(cv(), function(it) { return it.text === "Nothing on." }) !== null }, 1000)
      click(named(cv(), "calAgendaAdd"))
      tryVerify(function() { return named(win(), "quickAdd") !== null }, 1000)
      wait(200)
      type("Call Sam 17:00")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return ws.calendar.events.some(function(e) { return e.title === "Call Sam" && e.start.indexOf(Calendar.dayIso(empty)) === 0 }) }, 1000, "on the day picked")
      // → : the next month, its first day picked (today's isn't in it).
      cv().show(t, "")
      var first = new Date(t.getFullYear(), t.getMonth() + 1, 1)
      click(named(cv(), "calOn"))
      tryVerify(function() { return cv().same(cv().pickedDay, first) }, 1000)
      // Keys: M and C.
      cv().forceActiveFocus()
      keyClick(Qt.Key_M)
      compare(cv().mode, "month")
      keyClick(Qt.Key_C)
      compare(cv().mode, "compact")
      // The view it opens in: as it was.
      cv().restored = false
      cv().mode = "month"
      service.setSetting("calendarView", "agenda")
      view.openCalendar("")
      compare(cv().mode, "agenda")
      // Narrow: the views in one menu.
      root.width = 900
      tryVerify(function() { return named(cv(), "calModes") !== null && named(cv(), "calMode_week") === null }, 1000)
      click(named(cv(), "calModes"))
      tryVerify(function() { return named(win(), "calModeItem_compact") !== null }, 1000)
      click(named(win(), "calModeItem_compact"))
      tryCompare(cv(), "mode", "compact")
      root.width = 1400
      cv().mode = "month"
      service.setSetting("calendarView", "month")
    }

    function test_9_notes_say_whose_and_commands() {
      fresh()
      var t = today()
      var e = add({ title: "Kickoff", start: iso(plus(t, 1), 10), end: iso(plus(t, 1), 11) })
      view.notesForEvent(e.id, "")
      tryVerify(function() { return named(win(), "eventNote") !== null }, 2000, "the page says which event")
      // Commands.
      var r = JSON.parse(api.events("", ""))
      verify(r.events.some(function(x) { return x.title === "Kickoff" && x.notes !== "" }), JSON.stringify(r))
      var made = JSON.parse(api.addEvent("Gym mon 18:00-19:00", "weekly"))
      verify(made.ok, JSON.stringify(made))
      compare(made.repeat, "weekly")
      verify(/T18:00$/.test(made.start))
      var bad = JSON.parse(api.addEvent("Just words", ""))
      verify(!bad.ok)
      var gone = JSON.parse(api.removeEvent(made.id))
      verify(gone.ok)
      compare(Calendar.byId(ws.calendar, made.id), null)
    }
  }
}
