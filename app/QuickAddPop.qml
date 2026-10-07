import QtQuick
import QtQuick.Controls
import "../Calendar.js" as Calendar
import "../Dates.js" as Dates

// A new event, typed: "Lunch with Sam fri 12:30", "Dentist oct 12 3pm for
// 30 min", "Standup 9:30-9:45", "Holiday dec 24". With no day or time in
// it, it's on the day (or at the time) it was asked for. Enter adds it;
// More opens it to change everything.
Pop {
  id: pop

  property var workspace: null
  property var view: null
  // Where it was asked for: a day, and a time (minutes, or -1: none).
  property var day: new Date()
  property int minutes: -1
  // A place to put its id when it's made (an event block), or null.
  property var made: null

  width: 380
  padding: 12

  function openFor(d, mins, anchor, done) {
    day = d || new Date()
    minutes = typeof mins === "number" ? mins : -1
    made = done || null
    field.text = ""
    if (anchor) {
      var p = anchor.mapToItem(parent, 0, anchor.height + 6)
      x = Math.max(8, Math.min(parent.width - width - 8, p.x))
      y = Math.max(8, Math.min(parent.height - 160, p.y))
    }
    open()
    Qt.callLater(function() { field.focusField() })
  }

  // What's typed, as an event: { title, start, end, allDay }.
  readonly property var guess: {
    var t = field.text.trim()
    // A time alone is on the day asked for (today's: today, or tomorrow if it's gone by).
    var q = t ? Calendar.quick(t, new Date(), Calendar.dayIso(day) === Calendar.dayIso(new Date()) ? null : day) : null
    if (q) return q
    var d = day
    if (minutes >= 0) {
      var st = new Date(d.getFullYear(), d.getMonth(), d.getDate(), Math.floor(minutes / 60), minutes % 60)
      return { title: t, start: Calendar.timeIso(st), end: Calendar.timeIso(new Date(st.getTime() + 3600000)), allDay: false }
    }
    return { title: t, start: Calendar.dayIso(d), end: Calendar.dayIso(d), allDay: true }
  }
  readonly property string when: {
    var g = guess
    var s = Dates.fromIso(g.start).at
    if (g.allDay) return Dates.label(s, false, new Date()) + (g.end !== g.start ? " \u2013 " + Dates.label(Dates.fromIso(g.end).at, false, new Date()) : "") + ", all day"
    var e = Dates.fromIso(g.end).at
    var clock = pop.theme.twelveHour
    return Dates.label(s, false, new Date()) + ", " + Calendar.timeLabel(s) + " \u2013 " + Calendar.timeLabel(e)
  }

  // Added: its id.
  function add(more) {
    var g = guess
    if (!g.title && !more) { close(); return "" }
    var e = Calendar.cleanEvent({ title: g.title, start: g.start, end: g.end, allDay: g.allDay, alert: g.allDay ? -1 : 10 })
    if (!e) return ""
    workspace.setCalendar(Calendar.withEvent(workspace.calendar, e))
    var done = made
    close()
    if (done) done(e.id)
    // In the calendar: where it went, shown.
    if (view && view.calendarView && view.calendarView.visible) view.calendarView.reveal(e.id)
    if (e.title) view.toastUndo("\u201c" + e.title + "\u201d is on the calendar: " + when, function() { pop.workspace.undoCalendar() })
    return e.id
  }

  contentItem: Column {
    spacing: 8
    Field {
      id: field
      objectName: "quickAdd"
      theme: pop.theme
      width: parent.width
      height: 38
      placeholder: "Lunch with Sam fri 12:30"
      onAccepted: pop.add(false)
      onEscaped: pop.close()
    }
    Item {
      width: parent.width
      height: 28
      Text {
        objectName: "quickWhen"
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - more.width - 8
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: pop.when
        font.family: pop.theme.uiFont
        font.pixelSize: 12
        color: pop.theme.muted
      }
      Chip {
        id: more
        objectName: "quickMore"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        theme: pop.theme
        text: "More\u2026"
        onClicked: {
          var id = pop.add(true)
          if (id) { pop.view.justMade = pop.guess.title ? "" : id; pop.view.openEvent(id, "", null) }
        }
      }
    }
  }
}
