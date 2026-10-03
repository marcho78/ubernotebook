import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Markdown.js" as Markdown

// An email on a page: an .eml picked (copied into Pages/assets, read: its
// subject, who from and to, when, its first lines, its attachments); shown
// in full (its HTML safe: no scripts or pictures from the web); an
// attachment written out and opened (once); the .eml in the mail app;
// something that isn't an email said so; the Library's Emails; Markdown.
Item {
  id: root
  width: 1320
  height: 1000

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  UberNotebook.Workspace { id: ws; files: files }
  property string lastToast: ""

  DocView {
    id: view
    anchors.fill: parent
    theme: th
    workspace: ws
    service: service
    onToast: function(text) { root.lastToast = text }
    onToastUndo: function(text, undo) { root.lastToast = text }
  }

  function eml() {
    return [
      "From: Sam Rivera <sam@acme.com>",
      "To: Jane Doe <jane@contoso.com>, team@acme.com",
      "Subject: =?UTF-8?B?" + Qt.btoa("Launch plan") + "?=",
      "Date: Fri, 02 Oct 2026 09:30:00 +0000",
      "MIME-Version: 1.0",
      "Content-Type: multipart/mixed; boundary=\"outer\"",
      "",
      "--outer",
      "Content-Type: multipart/alternative; boundary=\"alt\"",
      "",
      "--alt",
      "Content-Type: text/plain; charset=utf-8",
      "",
      "Hi team, the launch moves to Friday.",
      "--alt",
      "Content-Type: text/html; charset=utf-8",
      "",
      "<p>Hi <b>team</b>, the launch moves to Friday. <a href=\"https://acme.com/plan\">The plan</a>.</p><script>alert(1)</script><img src=\"https://tracker.example/p.gif\">",
      "--alt--",
      "--outer",
      "Content-Type: application/pdf; name=\"plan.pdf\"",
      "Content-Disposition: attachment; filename=\"plan.pdf\"",
      "Content-Transfer-Encoding: base64",
      "",
      Qt.btoa("%PDF-1.4 the plan"),
      "--outer--",
      ""
    ].join("\r\n")
  }

  TestCase {
    name: "Email"
    when: windowShown

    function fresh() {
      wait(100)
      files.reset()
      files.opened = []
      files.noApp = null
      view.page = null
      view.libraryShown = false
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
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
    function named(item, name) { return find(item, function(it) { return it.objectName === name }) }
    function click(item) { verify(item !== null); wait(120); mouseClick(item) }
    function win() { return root.Window.window.contentItem }
    function type(text) { for (var i = 0; i < text.length; i++) keyClick(text.charAt(i) === " " ? Qt.Key_Space : text.charAt(i)) }
    function at(t) { return view.editor.serialize().map(function(b) { return b.type }).indexOf(t) }
    function dataAt(i) { return view.editor.serialize()[i].data }
    function viewOf(i) {
      var e = view.editor
      var v = null
      tryVerify(function() { v = e.items[e.uidAt(i)] ? e.items[e.uidAt(i)].dataView : null; return v !== null }, 1000)
      return v
    }

    function test_1_an_email_on_a_page() {
      fresh()
      files.disk["/tmp/in/Launch.eml"] = root.eml()
      service.nextFile = "/tmp/in/Launch.eml"
      var e = view.editor
      e.focusBlock(e.uidAt(e.model.count - 1), 0)
      type("/email")
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 }, 1000)
      keyClick(Qt.Key_Return)
      var i = -1
      tryVerify(function() { i = at("email"); return i >= 0 && dataAt(i).src !== "" }, 2000, "picked and read")
      compare(service.pickedKind, "email")
      var d = dataAt(i)
      compare(d.subject, "Launch plan")
      compare(d.from, "Sam Rivera <sam@acme.com>")
      compare(d.to, "Jane Doe <jane@contoso.com>, team@acme.com")
      compare(d.date, "2026-10-02T09:30:00.000Z")
      compare(d.preview, "Hi team, the launch moves to Friday.")
      compare(d.attachments.length, 1)
      verify(/^assets\/mail-\d{8}-\d{6}-[a-z0-9]+-launch\.eml$/.test(d.src), d.src)
      // The card: subject, who, first lines.
      var v = viewOf(i)
      tryVerify(function() { var s = named(v, "emailSubject"); return s !== null && s.text === "Launch plan" }, 1000)
      compare(named(v, "emailWho").text, "Sam Rivera  \u2192  Jane Doe, team@acme.com")
      compare(named(v, "emailPreview").text, "Hi team, the launch moves to Friday.")
      // Shown in full: its HTML, made safe.
      click(named(v, "emailToggle"))
      tryVerify(function() { var b = named(v, "emailBody"); return b !== null && b.text.indexOf("<b>team</b>") >= 0 }, 2000)
      var body = named(v, "emailBody").text
      verify(body.indexOf("<script") < 0 && body.indexOf("tracker.example") < 0, body)
      verify(body.indexOf("href=\"https://acme.com/plan\">The plan</a>") >= 0, body)
      verify(dataAt(i).open === true, "kept open")
      // An attachment: written out, opened; the second time, as it was.
      click(named(v, "emailAttachment"))
      tryVerify(function() { return files.opened.length === 1 }, 2000)
      verify(/assets\/mail-\d{8}-\d{6}-[a-z0-9]+-plan\.pdf$/.test(files.opened[0]), files.opened[0])
      tryVerify(function() { return dataAt(i).attachments[0].src !== "" }, 1000)
      var pdf = ws.folder + "/" + dataAt(i).attachments[0].src
      compare(files.disk[pdf], "%PDF-1.4 the plan")
      click(named(v, "emailAttachment"))
      tryVerify(function() { return files.opened.length === 2 }, 1000)
      compare(files.opened[1], files.opened[0])
      // The .eml, in the mail app.
      mouseMove(v, v.width / 2, 20)
      tryVerify(function() { return named(v, "emailOpen") !== null }, 1000)
      click(named(v, "emailOpen"))
      tryVerify(function() { return files.opened.length === 3 && /\.eml$/.test(files.opened[2]) }, 1000)
      // Markdown: who, when, what about, the .eml.
      view.commit()
      var md = Markdown.fromDocPage(ws.readPageNow(view.page.id), null, {})
      verify(md.indexOf("> \u2709 **Launch plan**\n> From Sam Rivera <sam@acme.com> \u00b7 to Jane Doe <jane@contoso.com>, team@acme.com \u00b7 2026-10-02") >= 0, md)
      // The Library's Emails: subject, from, to; a click: the page, at it.
      var here = view.page.id
      view.openLibrary("email")
      var lib = view.libraryView
      var row = null
      tryVerify(function() { row = find(lib, function(it) { return it.objectName === "libraryRow" && it.modelData.title === "Launch plan" }); return row !== null }, 2000)
      compare(row.modelData.sub, "From Sam Rivera to Jane Doe, team@acme.com")
      compare(row.modelData.kind, "email")
      lib.query = "contoso"
      tryVerify(function() { return lib.shown.length === 1 }, 1000, "found by who it's to")
      lib.query = ""
      tryVerify(function() { row = find(lib, function(it) { return it.objectName === "libraryRow" && it.modelData.title === "Launch plan" }); return row !== null }, 1000)
      wait(50)
      mouseClick(row, 60, row.height / 2)
      tryVerify(function() { return view.page && view.page.id === here && !view.libraryShown }, 2000)
    }

    // Attachments that open here: a calendar file's events, shown and put on
    // the calendar (not twice); a contact card's people, into People; one
    // with no app but a web browser isn't handed to it.
    function test_1b_attachments_that_open_here() {
      fresh()
      tryVerify(function() { return ws.calendarLoaded && ws.contactsLoaded }, 2000)
      var ics = ["BEGIN:VCALENDAR", "BEGIN:VEVENT", "DTSTART:20261011T072500", "DTEND:20261011T104000", "SUMMARY:Flight SK 214", "LOCATION:Gate 12", "END:VEVENT",
        "BEGIN:VEVENT", "DTSTART;VALUE=DATE:20261011", "DTEND;VALUE=DATE:20261014", "SUMMARY:Lisbon", "END:VEVENT", "END:VCALENDAR"].join("\r\n")
      var vcf = ["BEGIN:VCARD", "VERSION:3.0", "FN:Ana Costa", "EMAIL:ana@example.org", "END:VCARD"].join("\r\n")
      files.disk["/tmp/in/Trip.eml"] = [
        "From: Skylark <bookings@skylark.example>", "To: me@example.com", "Subject: Your trip", "MIME-Version: 1.0",
        "Content-Type: multipart/mixed; boundary=\"b\"", "", "--b", "Content-Type: text/plain", "", "Booked.",
        "--b", "Content-Type: text/calendar; name=\"flights.ics\"", "Content-Disposition: attachment; filename=\"flights.ics\"", "", ics,
        "--b", "Content-Type: text/vcard; name=\"ana.vcf\"", "Content-Disposition: attachment; filename=\"ana.vcf\"", "", vcf,
        "--b", "Content-Type: application/x-thing; name=\"data.weird\"", "Content-Disposition: attachment; filename=\"data.weird\"", "Content-Transfer-Encoding: base64", "", Qt.btoa("stuff"),
        "--b--", ""].join("\r\n")
      var e = view.editor
      e.insertBlocksAt(0, [{ type: "email", indent: 0, data: {} }])
      view.addEmailTo(view.page.id, e.uidAt(0), "/tmp/in/Trip.eml")
      tryVerify(function() { return dataAt(0).attachments.length === 3 }, 2000)
      var v = viewOf(0)
      var chips = []
      function chipsNow() { var out = []; (function walk(it) { if (it.objectName === "emailAttachment" && it.visible) out.push(it); for (var i = 0; i < it.children.length; i++) walk(it.children[i]) })(v); return out }
      tryVerify(function() { chips = chipsNow(); return chips.length === 3 }, 1000)
      // The calendar file: its events, here.
      click(chips[0])
      var add = null
      tryVerify(function() { add = named(win(), "icsAdd"); return add !== null }, 2000, "its events shown")
      var rows = []
      ;(function walk(it) { if (it.objectName === "icsEvent" && it.visible) rows.push(it); for (var i = 0; i < it.children.length; i++) walk(it.children[i]) })(win())
      compare(rows.length, 2)
      compare(files.opened.length, 0, "nothing handed to another app")
      var before = ws.calendar.events.length
      click(add)
      tryVerify(function() { return ws.calendar.events.length === before + 2 }, 1000)
      verify(ws.calendar.events.some(function(x) { return x.title === "Flight SK 214" && x.start === "2026-10-11T07:25" && x.place === "Gate 12" }))
      verify(root.lastToast.indexOf("2 events on your calendar") === 0, root.lastToast)
      // Again: they're there already.
      wait(300)
      click(chipsNow()[0])
      tryVerify(function() { return find(win(), function(it) { return typeof it.text === "string" && it.text === "They're on your calendar already." }) !== null }, 2000)
      compare(named(win(), "icsAdd"), null)
      keyClick(Qt.Key_Escape)
      // The contact card: into People.
      wait(300)
      click(chipsNow()[1])
      tryVerify(function() { return ws.contacts.contacts.some(function(c) { return c.name === "Ana Costa" }) }, 2000)
      verify(root.lastToast.indexOf("1 person added to People") === 0, root.lastToast)
      // No app for it but a web browser: kept, and said so.
      files.noApp = /\.weird$/
      click(chipsNow()[2])
      tryVerify(function() { return root.lastToast === "No app here opens .weird files but your web browser: it's kept in Pages/assets" }, 2000, root.lastToast)
      compare(files.opened.length, 0)
      files.noApp = null
    }

    function test_2_not_an_email() {
      fresh()
      files.disk["/tmp/in/notes.eml"] = "just some words, no headers"
      var e = view.editor
      e.insertBlocksAt(0, [{ type: "email", indent: 0, data: {} }])
      view.addEmailTo(view.page.id, e.uidAt(0), "/tmp/in/notes.eml")
      tryVerify(function() { return root.lastToast === "That isn't an email (.eml)" }, 2000)
      compare(dataAt(0).src, "")
    }
  }
}
