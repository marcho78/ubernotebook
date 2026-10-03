import QtQuick
import QtQuick.Controls
import "../Calendar.js" as Calendar
import "../Dates.js" as Dates
import "../Docs.js" as Docs
import "../Colors.js" as Colors

// An event, to change: its title, when (all day, or a start and an end,
// typed as "fri", "oct 12", "9:30"), how it repeats, its alert, its color,
// its place and a few words, the page of notes for it, and taking it off
// the calendar. A change is kept as it's made (Ctrl+Z in the calendar takes
// it back). A repeating one is changed every time it happens; "Just this
// one" makes this time an event of its own first.
Pop {
  id: pop

  property var workspace: null
  // DocView: notes for it, asking, toasts, colors.
  property var view: null
  property string eventId: ""
  // Which time of it (a repeating one's), "2026-10-05".
  property string day: ""

  readonly property var ev: { var r = workspace ? workspace.calendarRevision : 0; return workspace && eventId ? workspace.eventById(eventId) : null }
  readonly property bool repeats: ev !== null && ev.repeat !== null

  width: 400
  padding: 14
  // While it's open, the calendar under it isn't clicked through it (a
  // click beside it closes it first); nothing's dimmed.
  modal: true
  Overlay.modal: Item {}

  function openFor(id, dayKey, anchor) {
    eventId = id
    day = dayKey || ""
    if (anchor) {
      var p = anchor.mapToItem(parent, anchor.width + 8, 0)
      x = Math.max(8, Math.min(parent.width - width - 8, p.x))
      y = Math.max(8, Math.min(parent.height - 520, p.y - 20))
    }
    open()
    Qt.callLater(load)
  }

  function load() {
    if (!ev) return
    titleField.text = ev.title
    placeField.text = ev.place
    detailEdit.text = ev.detail
    startDay.text = dayLabel(ev.start)
    endDay.text = dayLabel(ev.end)
    startTime.text = ev.allDay ? "" : Calendar.timeLabel(Dates.fromIso(ev.start).at)
    endTime.text = ev.allDay ? "" : Calendar.timeLabel(Dates.fromIso(ev.end).at)
    everyField.text = ev.repeat ? String(ev.repeat.every) : "1"
    untilField.text = ev.repeat && ev.repeat.until ? dayLabel(ev.repeat.until) : ""
    if (!ev.title) titleField.focusField()
  }

  function dayLabel(text) { var d = Dates.fromIso(text); return d ? Dates.label(d.at, false, new Date()) : "" }

  // A change kept: `fields` put on it.
  function change(fields) {
    if (!ev) return
    var e = JSON.parse(JSON.stringify(ev))
    for (var k in fields) e[k] = fields[k]
    workspace.setCalendar(Calendar.withEvent(workspace.calendar, e))
  }

  // A day typed ("fri", "oct 12"), or "".
  function dayOf(text) {
    var d = Dates.parse(text, new Date())
    return d ? Calendar.dayIso(d.at) : ""
  }
  // A time typed ("9:30", "2pm") in minutes, or -1.
  function timeOf(text) { return Dates.parseTime(text) }

  // The start, from what's typed: the event as long as it was.
  function setStart() {
    if (!ev) return
    var s0 = Dates.fromIso(ev.start).at
    var sd = dayOf(startDay.text) || ev.start.slice(0, 10)
    var d = Dates.fromIso(sd).at
    if (ev.allDay) {
      var days = Math.round((Dates.fromIso(ev.end).at - s0) / 86400000)
      change({ start: sd, end: Calendar.dayIso(new Date(d.getFullYear(), d.getMonth(), d.getDate() + days)) })
    } else {
      var st = timeOf(startTime.text)
      if (st < 0) st = s0.getHours() * 60 + s0.getMinutes()
      var start = new Date(d.getFullYear(), d.getMonth(), d.getDate(), Math.floor(st / 60), st % 60)
      var length = Dates.fromIso(ev.end).at - s0
      change({ start: Calendar.timeIso(start), end: Calendar.timeIso(new Date(start.getTime() + length)) })
    }
    Qt.callLater(load)
  }

  // The end, from what's typed (an end before the start: the next day's,
  // as in "22:00 to 1:00").
  function setEnd() {
    if (!ev) return
    var s0 = Dates.fromIso(ev.start).at
    var e0 = Dates.fromIso(ev.end).at
    var ed = dayOf(endDay.text) || ev.end.slice(0, 10)
    if (ev.allDay) {
      change({ end: ed < ev.start ? ev.start : ed })
    } else {
      var et = timeOf(endTime.text)
      if (et < 0) et = e0.getHours() * 60 + e0.getMinutes()
      var d = Dates.fromIso(ed).at
      var end = new Date(d.getFullYear(), d.getMonth(), d.getDate(), Math.floor(et / 60), et % 60)
      if (end <= s0) end = new Date(s0.getFullYear(), s0.getMonth(), s0.getDate() + (end.getHours() * 60 + end.getMinutes() <= s0.getHours() * 60 + s0.getMinutes() ? 1 : 0), Math.floor(et / 60), et % 60)
      change({ end: Calendar.timeIso(end) })
    }
    Qt.callLater(load)
  }

  function setAllDay(on) {
    if (!ev || ev.allDay === on) return
    var s = Dates.fromIso(ev.start).at
    if (on) change({ allDay: true, start: Calendar.dayIso(s), end: Calendar.dayIso(Dates.fromIso(ev.end).at) })
    else {
      var st = new Date(s.getFullYear(), s.getMonth(), s.getDate(), 9, 0)
      change({ allDay: false, start: Calendar.timeIso(st), end: Calendar.timeIso(new Date(st.getTime() + 3600000)) })
    }
    Qt.callLater(load)
  }

  function setRepeat(freq) {
    if (!ev) return
    if (!freq) change({ repeat: null })
    else change({ repeat: { freq: freq, every: Math.max(1, Number(everyField.text) || 1), until: ev.repeat ? ev.repeat.until : "" } })
    Qt.callLater(load)
  }

  // This time made an event of its own (then changed here).
  function justThisOne() {
    if (!ev || !repeats || !day) return
    var r = Calendar.detach(workspace.calendar, eventId, day, {})
    workspace.setCalendar(r[0])
    eventId = r[1]
    day = ""
    Qt.callLater(load)
  }

  function remove() {
    if (!ev) return
    var title = ev.title || "The event"
    var id = eventId
    var dayKey = day
    function done() { pop.view.toastUndo("\u201c" + title + "\u201d is off the calendar", function() { pop.workspace.undoCalendar() }) }
    if (!repeats || !dayKey) {
      close()
      workspace.setCalendar(Calendar.without(workspace.calendar, id))
      done()
      return
    }
    view.ask("\u201c" + title + "\u201d repeats", [
      { label: "Just this one", value: "one" },
      { label: "This one and the ones after", value: "after" },
      { label: "Every one", value: "all" }
    ], function(what) {
      pop.close()
      var cal = pop.workspace.calendar
      if (what === "one") {
        var e = JSON.parse(JSON.stringify(Calendar.byId(cal, id)))
        e.skip.push(dayKey)
        pop.workspace.setCalendar(Calendar.withEvent(cal, e))
      } else if (what === "after") pop.workspace.setCalendar(Calendar.endBefore(cal, id, dayKey))
      else pop.workspace.setCalendar(Calendar.without(cal, id))
      done()
    }, deleteButton)
  }

  onClosed: {
    // What's typed and not kept yet.
    if (ev && titleField.text !== ev.title) change({ title: titleField.text })
    if (ev && placeField.text !== ev.place) change({ place: placeField.text })
    if (ev && detailEdit.text !== ev.detail) change({ detail: detailEdit.text })
    // An event with nothing in it that was just made goes.
    if (ev && !ev.title && !ev.place && !ev.detail && view && view.justMade === eventId) workspace.setCalendar(Calendar.without(workspace.calendar, eventId))
    if (view) view.justMade = ""
  }

  component Label2: Text {
    textFormat: Text.PlainText
    font.family: pop.theme.uiFont
    font.pixelSize: 12
    color: pop.theme.muted
  }

  contentItem: Column {
    spacing: 10
    width: pop.width - 2 * pop.padding

    // Its color, and its title.
    Row {
      spacing: 8
      width: parent.width
      Rectangle {
        id: colorDot
        objectName: "eventColor"
        anchors.verticalCenter: parent.verticalCenter
        width: 22
        height: 22
        radius: 11
        color: {
          var c = pop.ev ? pop.ev.color : ""
          var e = c ? Docs.colorEntry(c) : null
          return e ? e.text[pop.theme.dark ? 1 : 0] : c && Colors.isHex(c) ? Colors.normalize(c) : pop.theme.accent
        }
        border.width: dotHover.hovered ? 2 : 0
        border.color: Qt.alpha(pop.theme.text, 0.3)
        HoverHandler { id: dotHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: pop.view.openEventColors(pop.eventId, colorDot) }
        ToolTip.visible: dotHover.hovered
        ToolTip.delay: 600
        ToolTip.text: "Its color"
      }
      Field {
        id: titleField
        objectName: "eventTitle"
        theme: pop.theme
        width: parent.width - colorDot.width - 8
        height: 36
        placeholder: "What is it?"
        onAccepted: pop.change({ title: text })
        onEscaped: pop.close()
      }
    }

    Text {
      visible: pop.repeats
      width: parent.width
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      text: Calendar.repeatLabel(pop.ev ? pop.ev.repeat : null) + ": what's changed here is for every one"
      font.family: pop.theme.uiFont
      font.pixelSize: 12
      color: pop.theme.muted
      bottomPadding: -4
    }
    Chip {
      objectName: "eventJustThis"
      visible: pop.repeats && pop.day !== ""
      theme: pop.theme
      icon: pop.theme.icons.page
      text: "Change just this one (" + pop.dayLabel(pop.day) + ")"
      onClicked: pop.justThisOne()
    }

    // When.
    Row {
      spacing: 8
      Label2 { anchors.verticalCenter: parent.verticalCenter; text: "All day"; width: 64 }
      Toggle {
        objectName: "eventAllDay"
        anchors.verticalCenter: parent.verticalCenter
        theme: pop.theme
        checked: pop.ev ? pop.ev.allDay : false
        onToggled: function(on) { pop.setAllDay(on) }
      }
    }
    Row {
      spacing: 6
      Label2 { anchors.verticalCenter: parent.verticalCenter; text: "Starts"; width: 64 }
      Field { id: startDay; objectName: "eventStartDay"; theme: pop.theme; width: 130; height: 32; placeholder: "fri, oct 12"; onAccepted: pop.setStart(); input.onActiveFocusChanged: if (!input.activeFocus && pop.opened && text !== pop.dayLabel(pop.ev.start)) pop.setStart() }
      Field { id: startTime; objectName: "eventStartTime"; visible: pop.ev && !pop.ev.allDay; theme: pop.theme; width: 80; height: 32; placeholder: "9:30"; onAccepted: pop.setStart(); input.onActiveFocusChanged: if (!input.activeFocus && pop.opened && !pop.ev.allDay && text !== Calendar.timeLabel(Dates.fromIso(pop.ev.start).at)) pop.setStart() }
    }
    Row {
      spacing: 6
      Label2 { anchors.verticalCenter: parent.verticalCenter; text: "Ends"; width: 64 }
      Field { id: endDay; objectName: "eventEndDay"; theme: pop.theme; width: 130; height: 32; placeholder: "the same day"; onAccepted: pop.setEnd(); input.onActiveFocusChanged: if (!input.activeFocus && pop.opened && text !== pop.dayLabel(pop.ev.end)) pop.setEnd() }
      Field { id: endTime; objectName: "eventEndTime"; visible: pop.ev && !pop.ev.allDay; theme: pop.theme; width: 80; height: 32; placeholder: "10:30"; onAccepted: pop.setEnd(); input.onActiveFocusChanged: if (!input.activeFocus && pop.opened && !pop.ev.allDay && text !== Calendar.timeLabel(Dates.fromIso(pop.ev.end).at)) pop.setEnd() }
    }

    // How it repeats.
    Column {
      spacing: 6
      width: parent.width
      Label2 { text: "Repeats" }
      Flow {
        width: parent.width
        spacing: 5
        Repeater {
          model: [{ id: "", label: "No" }, { id: "daily", label: "Daily" }, { id: "weekdays", label: "Weekdays" }, { id: "weekly", label: "Weekly" }, { id: "monthly", label: "Monthly" }, { id: "yearly", label: "Yearly" }]
          delegate: Chip {
            required property var modelData
            objectName: "eventRepeat_" + (modelData.id || "no")
            theme: pop.theme
            text: modelData.label
            checked: pop.ev ? (pop.ev.repeat ? pop.ev.repeat.freq : "") === modelData.id : false
            onClicked: pop.setRepeat(modelData.id)
          }
        }
      }
      Row {
        visible: pop.repeats
        spacing: 6
        Label2 { anchors.verticalCenter: parent.verticalCenter; text: "Every" }
        Field {
          id: everyField
          objectName: "eventEvery"
          theme: pop.theme
          width: 52
          height: 30
          onAccepted: pop.setRepeat(pop.ev.repeat.freq)
          input.onActiveFocusChanged: if (!input.activeFocus && pop.opened && pop.repeats) pop.setRepeat(pop.ev.repeat.freq)
        }
        Label2 { anchors.verticalCenter: parent.verticalCenter; text: pop.ev && pop.ev.repeat ? ({ daily: "days", weekdays: "weeks", weekly: "weeks", monthly: "months", yearly: "years" })[pop.ev.repeat.freq] : "" }
        Item { width: 10; height: 1 }
        Label2 { anchors.verticalCenter: parent.verticalCenter; text: "until" }
        Field {
          id: untilField
          objectName: "eventUntil"
          theme: pop.theme
          width: 120
          height: 30
          placeholder: "for good"
          function keep() {
            var r = JSON.parse(JSON.stringify(pop.ev.repeat))
            r.until = text.trim() ? pop.dayOf(text) : ""
            pop.change({ repeat: r })
            Qt.callLater(pop.load)
          }
          onAccepted: keep()
          input.onActiveFocusChanged: if (!input.activeFocus && pop.opened && pop.repeats) keep()
        }
      }
    }

    // An alert before it.
    Column {
      spacing: 6
      width: parent.width
      Label2 { text: "Alert" }
      Flow {
        width: parent.width
        spacing: 5
        Repeater {
          model: [{ m: -1, label: "None" }, { m: 0, label: "At the start" }, { m: 5, label: "5 min" }, { m: 10, label: "10 min" }, { m: 30, label: "30 min" }, { m: 60, label: "1 hour" }, { m: 1440, label: "A day" }]
          delegate: Chip {
            required property var modelData
            objectName: "eventAlert_" + modelData.m
            theme: pop.theme
            text: modelData.label
            checked: pop.ev ? pop.ev.alert === modelData.m : false
            onClicked: pop.change({ alert: modelData.m })
          }
        }
      }
    }

    Field {
      id: placeField
      objectName: "eventPlace"
      theme: pop.theme
      width: parent.width
      height: 32
      placeholder: "Where (a room, an address, a link)"
      onAccepted: pop.change({ place: text })
      input.onActiveFocusChanged: if (!input.activeFocus && pop.opened && pop.ev && text !== pop.ev.place) pop.change({ place: text })
    }
    Rectangle {
      width: parent.width
      height: Math.max(54, detailEdit.contentHeight + 14)
      radius: 8
      color: "transparent"
      border.width: 1
      border.color: detailEdit.activeFocus ? pop.theme.accent : pop.theme.line
      TextEdit {
        id: detailEdit
        objectName: "eventDetail"
        x: 8
        y: 7
        width: parent.width - 16
        wrapMode: TextEdit.Wrap
        textFormat: TextEdit.PlainText
        font.family: pop.theme.uiFont
        font.pixelSize: 13
        color: pop.theme.text
        selectByMouse: true
        onActiveFocusChanged: if (!activeFocus && pop.opened && pop.ev && text !== pop.ev.detail) pop.change({ detail: text })
        Text {
          visible: detailEdit.text === "" && !detailEdit.activeFocus
          textFormat: Text.PlainText
          text: "A few words"
          font: detailEdit.font
          color: pop.theme.faint
        }
      }
    }

    // Its notes; taking it off; done.
    Item {
      width: parent.width
      height: 34
      Row {
        spacing: 6
        anchors.verticalCenter: parent.verticalCenter
        IconButton {
          objectName: "eventNotes"
          theme: pop.theme
          icon: pop.theme.icons.page
          label: pop.ev && pop.ev.page && pop.workspace.index.pages[pop.ev.page] ? "Open notes" : "Notes for it"
          size: 32; iconSize: 15
          tip: pop.ev && pop.ev.page ? "Its page of notes" : "A page of notes for it (from your meeting template), linked to it"
          onClicked: { var id = pop.eventId; var d = pop.day; pop.close(); pop.view.notesForEvent(id, d) }
        }
        IconButton {
          id: deleteButton
          objectName: "eventDelete"
          theme: pop.theme; icon: pop.theme.icons.trash; size: 32; iconSize: 15; tip: "Take it off the calendar"
          onClicked: pop.remove()
        }
      }
      Chip {
        objectName: "eventDone"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        theme: pop.theme
        text: "Done"
        checked: true
        onClicked: pop.close()
      }
    }
  }
}
