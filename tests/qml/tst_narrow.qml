import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Calendar.js" as Calendar

// Blocks in a narrow column (three, or six, to a row): a habit's days, a
// meeting's buttons and an agenda's day and buttons go on a line of their own
// rather than over its words, and stay inside the column. At full width, as
// they were.
Item {
  id: root
  width: 1320
  height: 1400

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  UberNotebook.Workspace { id: ws; files: files }
  DocView { id: view; anchors.fill: parent; theme: th; workspace: ws; service: service }

  TestCase {
    name: "Narrow"
    when: windowShown

    function find(item, test) {
      if (!item) return null
      if (test(item)) return item
      for (var i = 0; i < item.children.length; i++) {
        var hit = find(item.children[i], test)
        if (hit) return hit
      }
      return null
    }
    function named(item, name) { return find(item, function(it) { return it.objectName === name }) }
    function load(per, kinds) {
      files.reset()
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      var q = Calendar.quick("Standup with the whole team today 9:30", new Date())
      ws.setCalendar(Calendar.withEvent(Calendar.make(), Calendar.cleanEvent({ title: q.title, start: q.start, end: q.end, allDay: false, alert: -1, repeat: null })))
      var list = []
      if (per > 1) {
        list.push({ type: "columns" })
        for (var c = 0; c < per; c++) {
          list.push({ type: "column", indent: 1 })
          list.push({ type: kinds[c % kinds.length], html: "Run every morning", days: "1010100", indent: 2 })
        }
      } else {
        kinds.forEach(function(k) { list.push({ type: k, html: "Run every morning", days: "1010100" }) })
      }
      list.push({ type: "p", html: "" })
      view.editor.load(list)
      waitForRendering(view)
      wait(300)
    }
    function blocksOf(type) {
      var e = view.editor
      var out = []
      for (var i = 0; i < e.model.count; i++) if (e.typeOf(e.uidAt(i)) === type) out.push(e.items[e.uidAt(i)])
      return out
    }
    // `inner` lies within `outer` across (a pixel's give).
    function inside(inner, outer, what) {
      var a = inner.mapToItem(outer, 0, 0)
      verify(a.x >= -1 && a.x + inner.width <= outer.width + 1, what + ": " + Math.round(a.x) + "+" + Math.round(inner.width) + " in " + Math.round(outer.width))
    }
    function below(lower, upper, what) {
      var a = upper.mapToItem(lower.parent, 0, 0)
      verify(lower.y >= a.y + upper.height - 1, what + ": " + Math.round(lower.y) + " under " + Math.round(a.y + upper.height))
    }

    function test_1_a_habit() {
      for (var per of [3, 6]) {
        load(per, ["habit"])
        var b = blocksOf("habit")[0]
        verify(b.daysBelow, per + " to a row: its days under its name")
        var days = named(b, "habitDays")
        inside(days, b, per + " to a row: the days in its column")
        verify(days.y >= b.textTop + b.lineHeight - 1, "under the name")
        verify(b.textW > b.width * 0.6, "its name has the line")
      }
      load(1, ["habit"])
      var w = blocksOf("habit")[0]
      verify(!w.daysBelow, "full width: at the end of its line")
      compare(w.dot, Math.round(w.st.lineHeight * 0.9))
    }

    function test_2_a_meeting() {
      for (var per of [3, 6]) {
        load(per, ["meeting"])
        var b = blocksOf("meeting")[0]
        var tools = named(b, "meetingTools")
        var words = named(b, "meetingWords")
        verify(tools && words)
        var card = tools.parent
        verify(card.narrow, per + " to a row: narrow")
        inside(tools, card, per + " to a row: its buttons in the card")
        inside(words, card, per + " to a row: its words in the card")
        below(tools, words, per + " to a row: the buttons under the words")
        verify(words.width >= 40, "room for its words: " + words.width)
      }
      load(1, ["meeting"])
      var w = blocksOf("meeting")[0]
      var head = named(w, "meetingTools").parent
      verify(!head.narrow, "full width: on one line")
      compare(head.height, 64)
    }

    function test_3_an_agenda() {
      for (var per of [3, 6]) {
        load(per, ["agenda"])
        var b = blocksOf("agenda")[0]
        var tools = named(b, "agendaTools")
        var day = named(b, "agendaDay")
        var head = tools.parent
        verify(head.narrow, per + " to a row: narrow")
        inside(tools, head, per + " to a row: its buttons in it")
        inside(day, head, per + " to a row: its day in it")
        verify(tools.y >= 30, "the buttons on a line of their own")
        var row = named(b, "agendaRow")
        verify(row !== null, "today's event")
        verify(row.height > 40, "time, then title")
      }
      load(1, ["agenda"])
      var w = blocksOf("agenda")[0]
      var t = named(w, "agendaTools")
      verify(!t.parent.narrow, "full width: on one line")
      verify(named(w, "agendaDay").text.indexOf(Qt.locale().monthName(new Date().getMonth(), Locale.LongFormat)) >= 0, "the day in full")
      compare(named(w, "agendaRow").height, 30)
    }
  }
}
