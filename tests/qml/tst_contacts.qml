import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Html.js" as Html
import "../../Contacts.js" as Contacts
import "../../Markdown.js" as Markdown

// People in Pages: imported from a .vcf, found, changed in their card
// (kept at once, Delete taken back with Undo); "@" and a name on a page (a
// new person too), their card on a click, Open in People, the pages they're
// on; an email typed made a link (theirs, when it's someone's); a contact
// block; the Library's People and Emails; Markdown; the commands agents use.
Item {
  id: root
  width: 1320
  height: 1000

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
  UberNotebook.Api { id: api; workspace: ws; files: files; ui: ui }

  readonly property string vcf: "BEGIN:VCARD\nVERSION:3.0\nFN:Sam Rivera\nORG:Acme\nTITLE:Designer\nTEL;TYPE=CELL:+1 555 123 4567\nEMAIL;TYPE=WORK:sam@acme.com\nEND:VCARD\n"
    + "BEGIN:VCARD\nVERSION:3.0\nFN:Ana Lopez\nEMAIL:ana@x.org\nEND:VCARD\n"

  TestCase {
    name: "Contacts"
    when: windowShown

    function fresh() {
      wait(100)
      files.reset()
      files.opened = []
      view.page = null
      view.peopleShown = false
      view.libraryShown = false
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      tryCompare(ws, "contactsLoaded", true, 2000)
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
    function click(item) { verify(item !== null); wait(120); mouseClick(item) }
    function type(text) {
      for (var i = 0; i < text.length; i++) {
        var ch = text.charAt(i)
        if (ch === " ") keyClick(Qt.Key_Space)
        else if (ch === "@") keyClick(Qt.Key_At)
        else keyClick(ch)
      }
    }
    function pv() { return view.peopleView }
    function imported() {
      files.disk["/tmp/in/people.vcf"] = root.vcf
      service.nextFile = "/tmp/in/people.vcf"
      view.pickContacts(null)
      tryVerify(function() { return ws.contacts.contacts.length === 2 }, 1000)
      return { sam: Contacts.find(ws.contacts, "sam")[0], ana: Contacts.find(ws.contacts, "ana")[0] }
    }
    function lastText() { var e = view.editor; return e.items[e.uidAt(e.model.count - 1)] }

    // Another profile opens: what you looked for in People, picked or were
    // writing there, gone (not shown, filtered by, in the next one).
    function test_0_whats_looked_for_goes_with_the_profile() {
      fresh()
      var root0 = files.rootPath
      ws.saveContact({ id: "c-sam", name: "Sam Rivera", phones: [], emails: [] })
      view.openPeople("", false)
      tryVerify(function() { return view.peopleShown }, 1000)
      try {
        // (The cards' search, Esc'd once: still the query's.)
        var cards = null
        pv().layoutMode = "cards"
        tryVerify(function() { cards = find(win(), function(it) { return it.objectName === "peopleCardSearch" }); return cards !== null }, 1000)
        cards.escaped()
        pv().query = "Dana Whitfield"
        compare(cards.text, "Dana Whitfield")
        pv().selected = "c-someone"
        // A person being written (New person: a name typed).
        pv().layoutMode = pv().savedLayout
        pv().newPerson()
        var name = null
        tryVerify(function() { name = find(win(), function(it) { return it.objectName === "formName" }); return name !== null }, 1000)
        name.input.forceActiveFocus()
        type("Dr Jane Roe")
        compare(name.input.text, "Dr Jane Roe")
        var notes = null
        tryVerify(function() { notes = find(win(), function(it) { return it.objectName === "formNotes" }); return notes !== null }, 1000)
        notes.forceActiveFocus()
        type("Oncology")
        compare(notes.text, "Oncology")
        files.rootPath = "/tmp/other-people-view"
        compare(pv().query, "", "what was looked for, gone")
        compare(cards.text, "", "in the cards' search too")
        compare(pv().selected, "", "who was picked, too")
        tryCompare(ws, "ready", true, 2000)
        pv().newPerson()
        compare(name.input.text, "", "the new person's form: nothing of the one before")
        compare(notes.text, "", "nor in its notes")
      } finally {
        pv().layoutMode = pv().savedLayout
        files.rootPath = root0
        tryCompare(ws, "ready", true, 2000)
      }
    }

    function test_1_people_imported_found_changed() {
      fresh()
      click(named(win(), "peopleTile"))
      tryVerify(function() { return view.peopleShown }, 1000)
      verify(named(pv(), "peopleEmpty") !== null, "how to start")
      // Import (a .vcf picked).
      files.disk["/tmp/in/people.vcf"] = root.vcf
      service.nextFile = "/tmp/in/people.vcf"
      click(named(pv(), "peopleImport"))
      tryVerify(function() { return ws.contacts.contacts.length === 2 }, 1000)
      compare(service.pickedKind, "contacts")
      compare(root.lastToast, "2 people added")
      verify(files.disk[ws.contactsPath()].indexOf("Sam Rivera") > 0, "in Pages/contacts.json")
      // Again: filled in, not twice.
      view.pickContacts(null)
      tryVerify(function() { return root.lastToast === "0 people added" }, 1000)
      compare(ws.contacts.contacts.length, 2)
      // A list, found as it's typed (cards too, a click away).
      var cards = function() { return findAll(pv(), function(it) { return it.objectName === "personRow" }, []) }
      tryCompare(cards(), "length", 2)
      pv().focusSearch()
      type("acme")
      tryVerify(function() { return cards().length === 1 && cards()[0].modelData.name === "Sam Rivera" }, 1000)
      click(cards()[0])
      tryVerify(function() { var h = named(pv(), "personHeading"); return h !== null && h.text === "Sam Rivera" }, 1000)
      verify(!pv().editing, "read, not a form")
      // A number, copied with a click.
      var phone = named(pv(), "personPhone")
      waitForRendering(pv())
      mouseClick(phone, 80, phone.height / 2)
      compare(files.copied, "+1 555 123 4567")
      // Edit: the name, and another number.
      click(named(pv(), "personEdit"))
      tryVerify(function() { return pv().editing && named(pv(), "formName").input.activeFocus }, 1000)
      keyClick(Qt.Key_End)
      type(" Jr")
      click(named(pv(), "formAddPhone"))
      var valueOf = function(name, i) { var l = findAll(pv(), function(it) { return it.objectName === name }, []); return l.length > i ? l[i] : null }
      tryVerify(function() { var f = valueOf("formPhoneValue", 1); return f !== null && f.input.activeFocus }, 1000, "the new number's field, ready")
      type("555 000 1111")
      click(named(pv(), "personSave"))
      tryVerify(function() { return !pv().editing }, 1000)
      var id = pv().selected
      compare(ws.contactById(id).name, "Sam Rivera Jr")
      compare(ws.contactById(id).phones.length, 2)
      // Something wrong: said under it, and nothing kept.
      click(named(pv(), "personEdit"))
      tryVerify(function() { return pv().editing }, 1000)
      click(named(pv(), "formAddEmail"))
      tryVerify(function() { var f = valueOf("formEmailValue", 1); return f !== null && f.input.activeFocus }, 1000)
      type("nope")
      click(named(pv(), "personSave"))
      tryVerify(function() { return pv().errors.email1 !== undefined }, 1000)
      verify(pv().editing, "still the form")
      verify(find(pv(), function(it) { return it.text === "That isn't an email (like name@example.com)" }) !== null)
      click(named(pv(), "personCancel"))
      tryVerify(function() { return !pv().editing }, 1000)
      compare(ws.contactById(id).emails.length, 1)
      // Deleted, from ⋯, and back with Undo.
      click(named(pv(), "personMore"))
      tryVerify(function() { return named(win(), "personDelete") !== null }, 1000)
      click(named(win(), "personDelete"))
      tryVerify(function() { return ws.contactById(id) === null }, 1000)
      verify(root.lastToast.indexOf("Deleted Sam Rivera Jr") === 0)
      root.lastUndo()
      tryVerify(function() { return ws.contactById(id) !== null }, 1000)
      // Someone new: a form with its fields named; a name needed.
      click(named(pv(), "peopleNew"))
      tryVerify(function() { var h = named(pv(), "personHeading"); return h !== null && h.text === "New person" && named(pv(), "formName").input.activeFocus }, 1000)
      var before = ws.contacts.contacts.length
      click(named(pv(), "personSave"))
      tryVerify(function() { return pv().errors.name !== undefined }, 1000)
      compare(ws.contacts.contacts.length, before)
      mouseClick(named(pv(), "formName").input)
      type("Bo Chen")
      click(named(pv(), "personSave"))
      tryVerify(function() { return ws.contacts.contacts.length === before + 1 }, 1000)
      compare(root.lastToast, "Added Bo Chen")
      tryVerify(function() { var h = named(pv(), "personHeading"); return h !== null && h.text === "Bo Chen" }, 1000)
      // As cards: kept for next time; a click on one, their card; back.
      pv().show("")
      click(named(pv(), "peopleLayoutCards"))
      tryCompare(pv(), "layoutMode", "cards")
      compare(service.user.peopleLayout, "cards")
      var tiles = function() { return findAll(pv(), function(it) { return it.objectName === "personCard" }, []) }
      tryVerify(function() { return tiles().length === pv().shown.length && tiles().length > 0 }, 1000, "the same search, as cards")
      click(tiles()[0])
      tryVerify(function() { var h = named(pv(), "personHeading"); return h !== null && h.visible }, 1000)
      click(named(pv(), "peopleBack"))
      tryVerify(function() { return tiles().length > 0 }, 1000)
      click(named(pv(), "peopleLayoutList"))
      tryCompare(pv(), "layoutMode", "list")
    }

    function test_2_named_on_a_page() {
      fresh()
      var who = imported()
      var e = view.editor
      e.focusBlock(e.uidAt(e.model.count - 1), 0)
      // "@" and a name: them, first.
      type("Call @sa")
      tryVerify(function() { return e.mention !== null && e.mentionItems.length > 0 && e.mentionItems[0].kind === "person" }, 1000, JSON.stringify(e.mentionItems))
      compare(e.mentionItems[0].label, "Sam Rivera")
      keyClick(Qt.Key_Return)
      var html = function() { return e.serialize()[e.model.count - 1].html }
      tryVerify(function() { return html().indexOf("uber-notebook://contact/" + who.sam.id) >= 0 && Html.plainText(html()).indexOf("Call @Sam Rivera") === 0 }, 1000, html())
      // Someone new from "@".
      type("and @Zed Q")
      tryVerify(function() { return e.mentionItems.some(function(x) { return x.kind === "personnew" }) }, 1000)
      e.mentionIndex = e.mentionItems.map(function(x) { return x.kind }).indexOf("personnew")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return Contacts.find(ws.contacts, "zed")[0] !== undefined && html().indexOf("@Zed Q") >= 0 }, 1000)
      view.commit()
      // A click on them: their card.
      var item = lastText()
      var link = Html.links(item.edit.text).filter(function(l) { return l.href === "uber-notebook://contact/" + who.sam.id })[0]
      verify(link !== undefined)
      var at = item.edit.getText(0, item.edit.length).indexOf("@Sam") + 2
      var r = item.edit.positionToRectangle(at)
      mouseClick(item.edit, r.x + 1, r.y + r.height / 2)
      tryVerify(function() { return view.contactPop.opened && view.contactPop.personId === who.sam.id }, 1000)
      tryVerify(function() { var n = named(win(), "contactPopName"); return n !== null && n.text === "Sam Rivera" }, 1000)
      var phone = named(win(), "contactPopPhone")
      mouseClick(phone, 60, phone.height / 2)
      compare(files.copied, "+1 555 123 4567")
      // Open in People: them, and the page they're named on.
      var here = view.page.id
      click(named(win(), "contactPopPeople"))
      tryVerify(function() { return view.peopleShown && pv().selected === who.sam.id }, 1000)
      tryVerify(function() { var p = named(pv(), "personPage"); return p !== null && p.modelData.page === here }, 2000, "on your pages")
      click(named(pv(), "personPage"))
      tryVerify(function() { return !view.peopleShown && view.page && view.page.id === here }, 2000)
    }

    function test_3_emails_typed_and_a_contact_block() {
      fresh()
      var who = imported()
      var e = view.editor
      e.focusBlock(e.uidAt(e.model.count - 1), 0)
      type("Write to ana@x.org or bo@y.net then")
      var html = function() { return e.serialize()[e.model.count - 1].html }
      tryVerify(function() { return html().indexOf("uber-notebook://contact/" + who.ana.id) >= 0 }, 1000, "Ana's: a link to her: " + html())
      verify(html().indexOf("mailto:bo@y.net") >= 0, "no one's: mailto")
      compare(Html.plainText(html()), "Write to ana@x.org or bo@y.net then")
      // An email last, then Enter: a link too.
      type(" mail sam@acme.com")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return e.serialize()[e.model.count - 2].html.indexOf("uber-notebook://contact/" + who.sam.id) >= 0 }, 1000, e.serialize()[e.model.count - 2].html)
      keyClick(Qt.Key_Backspace)
      // A contact block: who, picked as it's typed.
      keyClick(Qt.Key_Return)
      type("/contact")
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 }, 1000)
      keyClick(Qt.Key_Return)
      var i = -1
      tryVerify(function() { i = e.serialize().map(function(b) { return b.type }).indexOf("contact"); return i >= 0 }, 1000)
      var cv = null
      tryVerify(function() { cv = e.items[e.uidAt(i)] ? e.items[e.uidAt(i)].dataView : null; return cv !== null }, 1000)
      tryVerify(function() { var f = named(cv, "contactPick"); return f !== null && f.input.activeFocus }, 1000, "who?")
      type("sam")
      tryVerify(function() { return findAll(cv, function(it) { return it.objectName === "contactHit" }, []).length === 1 }, 1000)
      keyClick(Qt.Key_Return)
      tryVerify(function() { return e.serialize()[i].data.contact === who.sam.id && e.serialize()[i].data.name === "Sam Rivera" }, 1000)
      tryVerify(function() { var n = named(cv, "contactName"); return n !== null && n.text === "Sam Rivera" }, 1000)
      var ways = findAll(cv, function(it) { return it.objectName === "contactWay" }, [])
      compare(ways.length, 2)
      mouseClick(ways[0], 80, ways[0].height / 2)
      compare(files.copied, "+1 555 123 4567")
      // Markdown: the mention and the card.
      view.commit()
      var md = Markdown.fromDocPage(view.workspace.readPageNow(view.page.id), null, { contactOf: function(id) { return ws.contactById(id) } })
      verify(md.indexOf("**Sam Rivera** \u00b7 Designer at Acme") >= 0, md)
      verify(md.indexOf("- \u260e +1 555 123 4567 (mobile)") >= 0, md)
      // The Library: People and Emails.
      view.openLibrary("")
      var lib = view.libraryView
      tryVerify(function() { return lib.counts.person >= 2 && lib.counts.email === 1 }, 2000, JSON.stringify(lib.counts))
    }

    // As cards: in groups (A to Z, or by company) under headings, A to Z
    // down the side; each card who and where, a number and an email with
    // Copy and Write under the pointer, what's worth knowing; the search in
    // bold; the arrow keys and Enter.
    function test_5_cards() {
      fresh()
      var soon = new Date(Date.now() + 3 * 86400000)
      ws.setContacts({ contacts: [
        { id: "ana", name: "Ana Lopez", company: "Mapas", title: "CTO", phones: [{ label: "mobile", value: "+34 91 555 0101" }], emails: [{ label: "work", value: "ana@mapas.es" }, { label: "home", value: "ana@x.org" }] },
        { id: "aub", name: "Aubrey Rogers", company: "Westwind Insurance", title: "Controller", phones: [{ label: "mobile", value: "+1-818-555-9479" }], emails: [] },
        { id: "bo", name: "Bo Chen", company: "", phones: [{ label: "mobile", value: "+1 415 555 0199" }], emails: [] },
        { id: "cal", name: "Caleb Perez", company: "Westwind Insurance", title: "Account Executive", phones: [], emails: [{ label: "work", value: "caleb@westwind.com" }],
          birthday: "--" + Qt.formatDate(soon, "MM-dd") },
        { id: "zoe", name: "Zoe Hill", company: "", phones: [], emails: [] }
      ] })
      ws.createPage({ parent: "", title: "Plans", blocks: [{ type: "p", indent: 0, html: "Call <a href=\"uber-notebook://contact/ana\">@Ana Lopez</a>" }] })
      view.openPeople("", false)
      tryVerify(function() { return pv().visible }, 1000)
      // (Nothing searched for, no one open, from before.)
      pv().query = ""
      pv().show("")
      pv().setLayout("cards")
      pv().setGroup("letter")
      var cards = function() { return findAll(pv(), function(it) { return it.objectName === "personCard" }, []) }
      var card = function(id) { return cards().filter(function(c) { return c.modelData.id === id })[0] || null }
      var headings = function() { return findAll(pv(), function(it) { return it.objectName === "peopleGroupHeading" }, []).map(function(h) { return h.children[0].text }) }
      tryVerify(function() { return cards().length === 5 }, 1000)
      compare(headings().join(","), "A,B,C,Z", "A to Z, a heading each")
      // A to Z down the side: the letters with someone under them.
      verify(named(pv(), "peopleLetters") !== null)
      verify(named(pv(), "peopleLetter_Z").row >= 0)
      compare(named(pv(), "peopleLetter_Q").row, -1, "no one under Q")
      // What's on a card.
      var facts = function(id) { return findAll(card(id), function(it) { return it.objectName === "cardFact" }, []).map(function(f) { return f.text }) }
      tryVerify(function() { return facts("ana").indexOf("On 1 page") >= 0 }, 1000, "the pages they're named on")
      verify(facts("ana").indexOf("+1 more") >= 0, "another email")
      verify(facts("cal").indexOf("Birthday in 3 days") >= 0, JSON.stringify(facts("cal")))
      verify(named(card("zoe"), "cardAddReach") !== null, "no number or email: said")
      // Copy, under the pointer.
      var c = card("aub")
      var number = find(c, function(it) { return it.text === "+1-818-555-9479" })
      verify(number !== null)
      mouseMove(number, 5, number.height / 2)
      var lines = []
      tryVerify(function() { lines = findAll(c, function(it) { return it.objectName === "cardCopy" }, []); return lines.length === 1 }, 1000, "Copy, on the line under the pointer")
      mouseMove(lines[0], 5, 5)
      click(lines[0])
      compare(files.copied, "+1-818-555-9479")
      compare(pv().selected, "", "a button, not the card")
      // A click on the card: theirs; back, on it, the keys going on from there.
      click(card("bo"))
      tryCompare(pv(), "selected", "bo")
      pv().show("")
      tryVerify(function() { return cards().length === 5 && pv().activeFocus }, 1000)
      compare(pv().cardFocus, "bo")
      keyClick(Qt.Key_Down)
      compare(pv().cardFocus, "cal")
      // The keys: from card to card, Enter opens one.
      pv().cardFocus = ""
      pv().forceActiveFocus()
      keyClick(Qt.Key_Right)
      compare(pv().cardFocus, "ana", "the first")
      keyClick(Qt.Key_Right)
      compare(pv().cardFocus, "aub")
      keyClick(Qt.Key_Down)
      compare(pv().cardFocus, "bo", "the row below (B's)")
      keyClick(Qt.Key_Down)
      compare(pv().cardFocus, "cal")
      keyClick(Qt.Key_Up)
      keyClick(Qt.Key_Up)
      compare(pv().cardFocus, "ana", "up, the same place in the row above")
      keyClick(Qt.Key_Return)
      tryCompare(pv(), "selected", "ana")
      pv().show("")
      // By company: the ones with none last; no A to Z.
      tryVerify(function() { return named(pv(), "peopleGroup_company") !== null }, 1000)
      click(named(pv(), "peopleGroup_company"))
      compare(service.user.peopleGroup, "company", "kept for next time")
      tryVerify(function() { return headings().join(",") === "Mapas,Westwind Insurance,No company" }, 1000, headings().join(","))
      compare(named(pv(), "peopleLetters"), null)
      // The search, in bold.
      pv().query = "west"
      tryVerify(function() { return cards().length === 2 }, 1000)
      verify(find(card("aub"), function(it) { return it.text === "<b>West</b>wind Insurance" }) !== null, "what was searched for, in bold")
      pv().query = ""
      pv().setGroup("letter")
      pv().setLayout("list")
    }

    function test_4_commands() {
      fresh()
      files.disk["/tmp/in/c.vcf"] = root.vcf
      var r = JSON.parse(api.importContacts("/tmp/in/c.vcf"))
      verify(r.ok && r.added === 2, JSON.stringify(r))
      var list = JSON.parse(api.contacts("acme"))
      compare(list.length, 1)
      compare(list[0].phones[0].number, "+1 555 123 4567")
      var one = JSON.parse(api.contact("Sam"))
      compare(one.name, "Sam Rivera")
      compare(one.emails[0].email, "sam@acme.com")
      var add = JSON.parse(api.addContact("Kim Park", "+82 2 555 0100", ""))
      verify(add.ok && add.added, JSON.stringify(add))
      var again = JSON.parse(api.addContact("", "", "sam@acme.com"))
      verify(again.ok && !again.added, "filled in, not twice")
      compare(JSON.parse(api.addContact("", "not a number", "")).ok, false)
      compare(JSON.parse(api.contact("nobody like this")).ok, false)
      compare(JSON.parse(api.contacts("")).length, 3)
    }
  }
}
