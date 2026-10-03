import QtQuick
import QtQuick.Controls
import "../Calendar.js" as Calendar
import "../Workspace.js" as Workspace
import "../Dates.js" as Dates
import "../Docs.js" as Docs
import "../Colors.js" as Colors

// The calendar on a page in Pages. An agenda ("/agenda"): a day's events
// and the dates in your notes, today's (or a day's: ‹ and › go from day to
// day, Today back), kept up to date; + adds an event that day, a click
// opens one. An event ("/event"): one event, when it next happens, kept up
// to date as it changes; a click opens it. Their colors (the card's, its
// accent) are Pages' colors or your own.
Item {
  id: cb

  property var editor: null
  property string uid: ""
  // "agenda" or "event".
  property string kind: "agenda"
  // The block's data (JSON): { day, id, color, background }.
  property string source: ""
  property real available: 600
  property color ink: "black"
  readonly property bool readOnly: editor ? editor.readOnly : true
  readonly property var theme: editor ? editor.theme : null
  readonly property bool dark: editor ? editor.dark : false
  readonly property var ws: editor ? editor.calendarSource : null

  property var ref: Calendar.cleanRef({})
  property string written: ""
  property var trying: null
  readonly property var look: trying || ref

  onSourceChanged: if (source !== written) load()
  Component.onCompleted: load()
  function load() {
    var r = null
    try { r = JSON.parse(source) } catch (e) { r = null }
    written = source
    ref = Calendar.cleanRef(r)
  }
  function change(fields) {
    var next = JSON.parse(JSON.stringify(ref))
    for (var k in fields) next[k] = fields[k]
    var clean = Calendar.cleanRef(next)
    written = JSON.stringify(clean)
    ref = clean
    editor.setCalRef(uid, clean)
  }

  // ---- what it shows -----------------------------------------------------------------------

  property real nowMs: Date.now()
  Timer { interval: 60000; repeat: true; running: true; onTriggered: cb.nowMs = Date.now() }
  readonly property var today: { var n = new Date(nowMs); return new Date(n.getFullYear(), n.getMonth(), n.getDate()) }
  readonly property var shownDay: ref.day ? Dates.fromIso(ref.day).at : today
  readonly property bool isToday: !ref.day || Calendar.dayIso(shownDay) === Calendar.dayIso(today)
  readonly property var events: {
    var r = ws ? ws.calendarRevision : 0
    if (!ws || kind !== "agenda") return []
    var lo = shownDay
    return Calendar.occurrences(ws.calendar, lo, new Date(lo.getFullYear(), lo.getMonth(), lo.getDate() + 1))
  }
  readonly property var dated: {
    var r = ws ? ws.revision : 0
    if (!ws || kind !== "agenda") return []
    var lo = shownDay
    return Workspace.datedNotes(ws.index, lo, new Date(lo.getFullYear(), lo.getMonth(), lo.getDate() + 1))
  }
  readonly property var ev: { var r = ws ? ws.calendarRevision : 0; return ws && kind === "event" && ref.id ? ws.eventById(ref.id) : null }
  readonly property var next: { var n = nowMs; return ev ? Calendar.nextOf(ev, new Date(nowMs)) : null }

  // ---- colors ------------------------------------------------------------------------------

  function textOf(id) { var c = Docs.colorEntry(id); return c ? c.text[dark ? 1 : 0] : Colors.normalize(id) }
  function backOf(id) { var c = Docs.colorEntry(id); return c ? c.background[dark ? 1 : 0] : Colors.normalize(id) }
  function tintOf(c) { return c ? textOf(c) : String(editor ? editor.accent : "#2456b3") }
  readonly property string inkHex: Colors.normalize(String(ink)) || "#000000"
  readonly property string paperHex: Colors.normalize(String(editor ? editor.paper : "#ffffff")) || "#ffffff"
  readonly property string fillHex: look.background ? backOf(look.background) : ""
  readonly property color fill: fillHex ? fillHex : Qt.alpha(ink, dark ? 0.06 : 0.035)
  readonly property color words: fillHex && Colors.isHex(look.background) ? Colors.readableOn(fillHex, inkHex) : ink
  readonly property color faint: Qt.alpha(words, 0.55)
  readonly property color accent: look.color ? textOf(look.color) : ev ? tintOf(ev.color) : (editor ? editor.accent : "#2456b3")

  function askColors(anchor) { if (!readOnly) editor.calendarAction(uid, "colors", anchor) }
  function scopeColors() { return { color: ref.color, background: ref.background } }
  function colorInfo() {
    return { text: kind === "event" && ev ? ev.title || "Event" : "Agenda", fill: ref.background ? backOf(ref.background) : paperHex,
      ownInk: ref.color ? textOf(ref.color) : "", pageInk: inkHex }
  }
  function previewColor(k, value) { var t = { color: ref.color, background: ref.background }; t[k === "background" ? "background" : "color"] = value; trying = t }
  function applyColor(k, value) { trying = null; var f = {}; f[k === "background" ? "background" : "color"] = value; change(f) }
  function cancelColor() { trying = null }
  function colorsClosed(refocus) { trying = null }

  function step(n) {
    var d = shownDay
    var to = new Date(d.getFullYear(), d.getMonth(), d.getDate() + n)
    change({ day: Calendar.dayIso(to) === Calendar.dayIso(today) ? "" : Calendar.dayIso(to) })
  }

  // ---- the card ----------------------------------------------------------------------------

  width: available
  height: card.height
  readonly property bool pointerIn: hover.hovered
  HoverHandler { id: hover }

  Rectangle {
    id: card
    width: cb.width
    height: cb.kind === "event" ? eventRow.height + 16 : agendaCol.height + 20
    radius: 10
    color: cb.fill
    border.width: 1
    border.color: Qt.alpha(cb.words, cb.pointerIn ? 0.14 : 0.08)

    // ---- an event ----
    Item {
      id: eventRow
      visible: cb.kind === "event"
      x: 12
      y: 8
      width: parent.width - 24
      height: 44
      Rectangle { width: 4; height: parent.height; radius: 2; color: cb.accent }
      Column {
        x: 14
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - x - eventTools.width - 8
        spacing: 2
        Text {
          objectName: "eventBlockTitle"
          width: parent.width
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: cb.ev ? (cb.ev.title || "Untitled") : cb.ref.id ? "This event isn't on the calendar any more" : "An event"
          font.family: cb.editor ? cb.editor.uiFamily : ""
          font.pixelSize: 15
          font.weight: cb.ev ? Font.DemiBold : Font.Normal
          font.italic: !cb.ev
          color: cb.ev ? cb.words : cb.faint
        }
        Text {
          visible: cb.ev !== null
          width: parent.width
          elide: Text.ElideRight
          textFormat: Text.PlainText
          text: cb.next ? Dates.label(cb.next.start, false, new Date(cb.nowMs)) + ", " + Calendar.span(cb.next) + (cb.ev.repeat ? "  \u00b7  " + Calendar.repeatLabel(cb.ev.repeat).toLowerCase() : "") + (cb.ev.place ? "  \u00b7  " + cb.ev.place : "") : ""
          font.family: cb.editor ? cb.editor.uiFamily : ""
          font.pixelSize: 12
          color: cb.faint
        }
      }
      Row {
        id: eventTools
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        IconButton {
          id: evColors
          objectName: "calBlockColors"
          visible: !cb.readOnly && (cb.pointerIn || cb.trying !== null)
          theme: cb.theme; icon: cb.theme ? cb.theme.icons.palette : ""; size: 28; iconSize: 14; tint: cb.words
          tip: "Its colors"
          onClicked: cb.askColors(evColors)
        }
      }
      HoverHandler { cursorShape: cb.ev ? Qt.PointingHandCursor : Qt.ArrowCursor }
      TapHandler {
        enabled: cb.ev !== null
        onTapped: function(p) {
          var q = evColors.mapFromItem(eventRow, p.position.x, p.position.y)
          if (evColors.visible && evColors.contains(q)) return
          cb.editor.calendarAction(cb.uid, "open", { id: cb.ref.id, day: cb.next ? cb.next.day : "", anchor: eventRow })
        }
      }
    }

    // ---- an agenda ----
    Column {
      id: agendaCol
      visible: cb.kind === "agenda"
      x: 14
      y: 10
      width: parent.width - 28
      spacing: 4
      Item {
        width: parent.width
        height: 30
        Row {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 8
          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: cb.theme ? cb.theme.icons.calendarWeek : ""
            font.family: cb.theme ? cb.theme.iconFont : ""
            font.pixelSize: 16
            color: cb.accent
          }
          Text {
            objectName: "agendaDay"
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: (cb.isToday ? "Today  \u00b7  " : "") + Qt.locale().dayName(cb.shownDay.getDay()) + " " + cb.shownDay.getDate() + " " + Qt.locale().monthName(cb.shownDay.getMonth())
            font.family: cb.editor ? cb.editor.uiFamily : ""
            font.pixelSize: 14
            font.weight: Font.DemiBold
            color: cb.words
          }
        }
        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 2
          IconButton {
            id: agColors
            objectName: "calBlockColors"
            visible: !cb.readOnly && (cb.pointerIn || cb.trying !== null)
            theme: cb.theme; icon: cb.theme ? cb.theme.icons.palette : ""; size: 28; iconSize: 14; tint: cb.words
            tip: "Its colors"
            onClicked: cb.askColors(agColors)
          }
          IconButton { objectName: "agendaBack"; visible: !cb.readOnly; theme: cb.theme; icon: cb.theme ? cb.theme.icons.left : ""; size: 28; iconSize: 15; tint: cb.words; tip: "The day before"; onClicked: cb.step(-1) }
          IconButton { objectName: "agendaToday"; visible: !cb.readOnly && !cb.isToday; theme: cb.theme; label: "Today"; size: 28; tint: cb.words; tip: "Today's, each day"; onClicked: cb.change({ day: "" }) }
          IconButton { objectName: "agendaOn"; visible: !cb.readOnly; theme: cb.theme; icon: cb.theme ? cb.theme.icons.right : ""; size: 28; iconSize: 15; tint: cb.words; tip: "The day after"; onClicked: cb.step(1) }
          IconButton {
            id: agAdd
            objectName: "agendaAdd"
            visible: !cb.readOnly
            theme: cb.theme; icon: cb.theme ? cb.theme.icons.plus : ""; size: 28; iconSize: 15; tint: cb.words
            tip: "An event that day"
            onClicked: cb.editor.calendarAction(cb.uid, "add", { day: cb.shownDay, anchor: agAdd })
          }
        }
      }
      Repeater {
        model: cb.events
        delegate: Rectangle {
          id: row
          required property var modelData
          objectName: "agendaRow"
          width: agendaCol.width
          height: 30
          radius: 6
          color: rowHover.hovered ? Qt.alpha(cb.words, 0.06) : "transparent"
          Text {
            x: 6
            width: 96
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: Calendar.span(row.modelData, cb.shownDay)
            font.family: cb.editor ? cb.editor.uiFamily : ""
            font.pixelSize: 12
            font.features: { "tnum": 1 }
            color: cb.faint
          }
          Rectangle { x: 106; anchors.verticalCenter: parent.verticalCenter; width: 3; height: 18; radius: 1.5; color: cb.tintOf(row.modelData.color) }
          Text {
            x: 118
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 8
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: (row.modelData.title || "Untitled") + (row.modelData.place ? "  \u00b7  " + row.modelData.place : "")
            font.family: cb.editor ? cb.editor.family : ""
            font.pixelSize: 15
            color: cb.words
          }
          HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: cb.editor.calendarAction(cb.uid, "open", { id: row.modelData.id, day: row.modelData.day, anchor: row }) }
        }
      }
      Repeater {
        model: cb.dated
        delegate: Rectangle {
          id: nrow
          required property var modelData
          objectName: "agendaNote"
          width: agendaCol.width
          height: 28
          radius: 6
          color: nHover.hovered ? Qt.alpha(cb.words, 0.06) : "transparent"
          Text {
            x: 6
            width: 96
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: nrow.modelData.time ? Calendar.timeLabel(nrow.modelData.at) : nrow.modelData.kind === "due" ? "Due" : "All day"
            font.family: cb.editor ? cb.editor.uiFamily : ""
            font.pixelSize: 12
            color: cb.faint
          }
          Text {
            x: 118
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - x - 8
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: (nrow.modelData.kind === "due" ? "\u2691 " : "\u23f0 ") + nrow.modelData.title + (nrow.modelData.text && nrow.modelData.kind !== "due" ? ": " + nrow.modelData.text : "")
            font.family: cb.editor ? cb.editor.uiFamily : ""
            font.pixelSize: 13
            font.italic: true
            color: cb.faint
          }
          HoverHandler { id: nHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: cb.editor.pageOpened(nrow.modelData.page) }
        }
      }
      Text {
        visible: cb.events.length === 0 && cb.dated.length === 0
        leftPadding: 6
        textFormat: Text.PlainText
        text: "Nothing on the calendar" + (cb.isToday ? " today" : " that day")
        font.family: cb.editor ? cb.editor.uiFamily : ""
        font.pixelSize: 13
        font.italic: true
        color: cb.faint
      }
    }
  }
}
