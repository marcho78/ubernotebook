import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Workspace.js" as Workspace
import "../../Board.js" as Board
import "../../Html.js" as Html
import "../../Colors.js" as Colors

// The newer blocks in Pages: a button (set up, pressed: a template put in,
// or a page made), a file and a PDF and a video (picked, copied in, opened),
// a web bookmark (a link read: its title, a line, its picture), a board
// (cards written, moved, colored, made pages; columns), a synced block
// (blocks made one, shown, changed where they're kept, unsynced), and
// Markdown of them all.
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
  }

  TestCase {
    name: "MoreBlocks"
    when: windowShown

    function fresh() {
      files.reset()
      files.opened = []
      files.fetchPages = ({})
      files.fetchPictures = ({})
      service.nextFile = ""
      view.page = null
      view.calendarShown = false
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
    function slash(command) {
      var e = view.editor
      e.focusBlock(e.uidAt(e.model.count - 1), 0)
      type("/" + command)
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 }, 1000)
      keyClick(Qt.Key_Return)
    }
    function at(type) { return view.editor.serialize().map(function(b) { return b.type }).indexOf(type) }
    function dataAt(i) { return view.editor.serialize()[i].data }
    function viewOf(i) {
      var e = view.editor
      var uid = e.uidAt(i)
      var v = null
      tryVerify(function() { v = e.items[uid] ? e.items[uid].dataView : null; return v !== null }, 1000)
      waitForRendering(v)
      return v
    }
    function put(block) {
      view.editor.insertBlocksAt(0, [block])
      return viewOf(0)
    }
    function plains() { return view.editor.serialize().map(function(b) { return Html.plainText(b.html || "") }) }

    function test_1_a_button() {
      fresh()
      slash("button")
      var i = at("button")
      verify(i >= 0)
      var setup = null
      tryVerify(function() { setup = named(win(), "buttonLabel"); return setup !== null }, 1000, "it's set up first")
      wait(200)
      var chip = null
      tryVerify(function() { var f = named(win(), "buttonBuiltins"); chip = f ? find(f, function(it) { return it.text === "To-do list" && it.checked !== undefined }) : null; return chip !== null }, 1000)
      mouseClick(chip)
      tryVerify(function() { return dataAt(i).template === "todo" }, 1000)
      setup.text = "Plan the day"
      click(named(win(), "buttonDone"))
      tryVerify(function() { return dataAt(i).label === "Plan the day" }, 1000)
      // Pressed: the template, after it.
      var bv = viewOf(i)
      wait(200)
      click(named(bv, "buttonPill"))
      tryVerify(function() { return at("columns") > i }, 2000, "the to-do list put in after it")
      // A page made from it.
      var d = dataAt(i)
      d.action = "page"
      view.editor.setData(view.editor.uidAt(i), d)
      var before = view.page.id
      view.pressButton(view.editor.uidAt(i))
      tryVerify(function() { return view.page && view.page.id !== before }, 2000)
      compare(ws.index.pages[view.page.id].parent, before, "inside the page with the button")
    }

    function test_2_files_a_pdf_and_a_video() {
      fresh()
      files.disk["/home/me/Q3 report.pdf"] = "%PDF-1.4 a report"
      service.nextFile = "/home/me/Q3 report.pdf"
      slash("pdf")
      var i = at("file")
      verify(i >= 0)
      tryVerify(function() { return dataAt(i).src !== "" }, 2000, "picked and copied in")
      compare(service.pickedKind, "pdf")
      var d = dataAt(i)
      compare(d.name, "Q3 report.pdf")
      compare(d.kind, "pdf")
      compare(d.size, "%PDF-1.4 a report".length)
      verify(/^assets\/file-\d{8}-\d{6}-[a-z0-9]+-q3-report\.pdf$/.test(d.src), d.src)
      verify(files.disk[ws.folder + "/" + d.src] !== undefined, "the copy, in Pages/assets")
      var fv = viewOf(i)
      compare(named(fv, "fileName").text, "Q3 report.pdf")
      click(named(fv, "fileOpen"))
      tryVerify(function() { return files.opened.length === 1 }, 1000)
      verify(files.opened[0].indexOf(d.src) > 0)
      // Its pages, shown or not.
      click(named(fv, "filePages"))
      tryVerify(function() { return dataAt(i).open === false }, 1000)
      // Any file.
      files.disk["/home/me/assets.zip"] = "PK"
      service.nextFile = "/home/me/assets.zip"
      slash("file")
      tryVerify(function() { return view.editor.serialize().some(function(b) { return b.type === "file" && b.data.kind === "archive" }) }, 2000)
      compare(service.pickedKind, "any")
      // A video, and its still.
      files.disk["/home/me/Demo.mp4"] = "video"
      service.nextFile = "/home/me/Demo.mp4"
      slash("video")
      var v = at("video")
      tryVerify(function() { return dataAt(v).src !== "" }, 2000)
      compare(service.pickedKind, "video")
      verify(/-still\.jpg$/.test(dataAt(v).poster), dataAt(v).poster)
      // Picked nothing: nothing changes.
      service.nextFile = ""
      slash("file")
      wait(200)
      verify(view.editor.serialize().some(function(b) { return b.type === "file" && b.data.src === "" }))
    }

    function test_3_a_bookmark() {
      fresh()
      files.fetchPages = { "https://example.com/post": '<html><head><title>Fallback</title><meta property="og:title" content="A good post &amp; more"><meta name="description" content="What it&#39;s about."><meta property="og:image" content="/pic.png"><meta property="og:site_name" content="Example"></head><body></body></html>' }
      files.fetchPictures = { "https://example.com/pic.png": "image/png" }
      slash("bookmark")
      var i = at("bookmark")
      var bv = viewOf(i)
      var field = named(bv, "bookmarkField")
      tryVerify(function() { return field.input.activeFocus }, 1000, "asks for the link")
      type("example.com/post")
      wait(50)
      field.text = "https://example.com/post"
      field.accepted()
      tryVerify(function() { return dataAt(i).title === "A good post & more" }, 2000)
      var d = dataAt(i)
      compare(d.description, "What it's about.")
      compare(d.site, "Example")
      verify(/^assets\/bm-\d{8}-\d{6}-[a-z0-9]+\.png$/.test(d.image), d.image)
      verify(files.disk[ws.folder + "/" + d.image] !== undefined, "its picture, in Pages/assets")
      tryVerify(function() { return named(bv, "bookmarkTitle").text === "A good post & more" }, 1000)
      // Its link changed: Edit (under the pointer), the field as it was;
      // Esc keeps it; a new one read again.
      mouseMove(bv, bv.width / 2, 20)
      var editLink = null
      tryVerify(function() { editLink = named(bv, "bookmarkEdit"); return editLink !== null }, 1000)
      wait(100)
      mouseClick(editLink)
      tryVerify(function() { field = named(bv, "bookmarkField"); return field !== null && field.input.activeFocus }, 1000, "the field, ready")
      compare(field.text, "https://example.com/post")
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return named(bv, "bookmarkTitle") !== null && named(bv, "bookmarkField") === null }, 1000, "kept as it was")
      files.fetchPages["https://example.com/other"] = '<html><head><title>Another post</title></head></html>'
      bv.editLink()
      tryVerify(function() { field = named(bv, "bookmarkField"); return field !== null && field.input.activeFocus }, 1000)
      field.text = "https://example.com/other"
      field.accepted()
      tryVerify(function() { return dataAt(i).url === "https://example.com/other" && dataAt(i).title === "Another post" }, 2000)
      tryVerify(function() { return named(bv, "bookmarkTitle") !== null && named(bv, "bookmarkTitle").text === "Another post" }, 1000)
      view.editor.undo()
      tryVerify(function() { return dataAt(i).url === "https://example.com/post" }, 1000, "Undo: the link before")
      // Opened, copied.
      view.dataAction(view.editor.uidAt(i), "open", null)
      compare(files.opened[files.opened.length - 1], "https://example.com/post")
      view.dataAction(view.editor.uidAt(i), "copy", null)
      compare(files.copied, "https://example.com/post")
      // A page that can't be read: the link's kept, it says so.
      view.dataAction(view.editor.uidAt(i), "fetch", { url: "https://nowhere.example.org/x" })
      tryVerify(function() { return dataAt(i).url === "https://nowhere.example.org/x" && dataAt(i).title === "" }, 2000)
      verify(root.lastToast.indexOf("couldn't be read") >= 0, root.lastToast)
      // Not read (as an agent's bookmark is): read only when you ask, with
      // the card's own button (not opened in the browser by that click).
      tryVerify(function() { var b = named(bv, "bookmarkRead"); return b !== null && b.y > 0 }, 1000, "it says it can be read")
      files.fetchPages["https://nowhere.example.org/x"] = '<html><head><title>Found it</title></head></html>'
      var opened = files.opened.length
      mouseClick(named(bv, "bookmarkRead"))
      tryVerify(function() { return dataAt(i).title === "Found it" }, 2000, "read when you click")
      compare(files.opened.length, opened, "and not opened")
      tryVerify(function() { return named(bv, "bookmarkRead") === null }, 1000, "read: the button goes")
      // Not a web link.
      view.dataAction(view.editor.uidAt(i), "fetch", { url: "file:///etc/passwd" })
      tryVerify(function() { return root.lastToast.indexOf("isn't a web link") >= 0 }, 1000)
      // A picture the page names on your own network (or this computer, or
      // by its address, or plain http): never fetched.
      var pictures = ["https://router.example.com/admin.png", "https://192.168.1.1/admin.png", "http://cdn.example.com/a.png", "https://box.local/a.png"]
      files.privateHosts = { "router.example.com": "192.168.1.1" }
      for (var k = 0; k < pictures.length; k++) {
        files.fetchPictures[pictures[k]] = "image/png"
        files.fetchPages["https://example.com/inside" + k] = '<html><head><title>Inside ' + k + '</title><meta property="og:image" content="' + pictures[k] + '"></head></html>'
        var before = files.ran.length
        view.dataAction(view.editor.uidAt(i), "fetch", { url: "https://example.com/inside" + k })
        tryVerify(function() { return dataAt(i).title === "Inside " + k }, 2000)
        compare(dataAt(i).image, "", "no picture: " + pictures[k])
        verify(!files.ran.slice(before).some(function(a) { return a[0] === "/usr/bin/curl" && a[a.length - 1] === pictures[k] }), "never fetched: " + pictures[k])
      }
      // The page itself: read step by step, from the address looked up,
      // past no proxy, redirects followed here, each checked again.
      function curls(from) { return files.ran.slice(from).filter(function(a) { return a[0] === "/usr/bin/curl" }) }
      files.fetchPages["http://plain.example.com/a"] = "REDIRECT https://example.com/b"
      files.fetchPages["https://example.com/b"] = '<html><head><title>Followed</title></head></html>'
      var mark = files.ran.length
      view.dataAction(view.editor.uidAt(i), "fetch", { url: "http://plain.example.com/a" })
      tryVerify(function() { return dataAt(i).title === "Followed" }, 2000, "plain http, and a redirect followed")
      var two = curls(mark)
      compare(two.length, 2)
      verify(two.every(function(a) { return a.indexOf("--noproxy") > 0 && a[a.indexOf("--noproxy") + 1] === "*" && a[a.indexOf("--max-redirs") + 1] === "0" }), "past no proxy, never redirected by curl")
      compare(two[0][two[0].indexOf("--resolve") + 1], "plain.example.com:80:93.184.215.14")
      compare(two[1][two[1].indexOf("--resolve") + 1], "example.com:443:93.184.215.14")
      // Sent on to your own network: not followed.
      files.privateHosts = { "admin.example.net": "10.0.0.1" }
      files.fetchPages["https://example.com/sneaky"] = "REDIRECT https://admin.example.net/secret"
      files.fetchPages["https://admin.example.net/secret"] = '<html><head><title>Secret</title></head></html>'
      mark = files.ran.length
      view.dataAction(view.editor.uidAt(i), "fetch", { url: "https://example.com/sneaky" })
      tryVerify(function() { return dataAt(i).url === "https://example.com/sneaky" && root.lastToast.indexOf("isn't on the internet") >= 0 }, 2000, root.lastToast)
      compare(dataAt(i).title, "")
      verify(!curls(mark).some(function(a) { return a[a.length - 1] === "https://admin.example.net/secret" }), "never read")
      // A site on your network asked for itself: not read either.
      mark = files.ran.length
      view.dataAction(view.editor.uidAt(i), "fetch", { url: "https://admin.example.net/secret" })
      tryVerify(function() { return root.lastToast.indexOf("isn't on the internet") >= 0 && dataAt(i).url === "https://admin.example.net/secret" }, 2000)
      compare(curls(mark).length, 0)
      // Sent on and on: five times at most.
      for (var hop = 0; hop < 8; hop++) files.fetchPages["https://example.com/loop" + hop] = "REDIRECT https://example.com/loop" + (hop + 1)
      mark = files.ran.length
      view.dataAction(view.editor.uidAt(i), "fetch", { url: "https://example.com/loop0" })
      tryVerify(function() { return root.lastToast.indexOf("too many times") >= 0 }, 2000, root.lastToast)
      compare(curls(mark).length, 6)
      files.privateHosts = ({})
    }

    // A link to a page: Change (under the pointer) picks another; its page
    // gone, it asks for one.
    function test_3b_a_link_to_another_page() {
      fresh()
      var a = ws.createPage({ parent: "", title: "Alpha" })
      var b = ws.createPage({ parent: "", title: "Beta" })
      var e = view.editor
      e.insertBlocksAt(0, [{ type: "link", target: a.id, indent: 0 }])
      var item = null
      tryVerify(function() { item = e.items[e.uidAt(0)]; return item !== null && item.height > 10 }, 1000)
      mouseMove(item, 60, item.height / 2)
      var change = null
      tryVerify(function() { change = find(item, function(it) { return it.objectName === "linkChange" }); return change !== null }, 1000, "Change, under the pointer")
      wait(100)
      mouseClick(change)
      tryVerify(function() { return view.pagePicker.opened && view.pagePicker.purpose === "relink" }, 1000, "the picker")
      view.pagePicker.close()
      view.relink(e.uidAt(0), b.id)
      compare(e.serialize()[0].target, b.id)
      e.undo()
      compare(e.serialize()[0].target, a.id, "Undo: the page before")
      // Its page gone: it says so, and asks for one.
      e.setProp(e.uidAt(0), "target", "00000000-0000-4000-8000-000000000000")
      tryVerify(function() { var c = find(item, function(it) { return it.objectName === "linkChange" }); return c !== null && c.children[0].children[1].text === "Link to a page" }, 1000)
    }

    function test_4_a_board() {
      fresh()
      var bv = put({ type: "board", indent: 0, data: Board.make() })
      var cols = function() { return dataAt(0).columns }
      // A card, written.
      var adds = findAll(bv, function(it) { return it.objectName === "boardAdd" }, [])
      compare(adds.length, 3)
      click(adds[0])
      var edit = null
      tryVerify(function() { edit = named(bv, "boardCardEdit"); return edit !== null && edit.activeFocus }, 1000)
      type("Write the post")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return cols()[0].cards.length === 1 && cols()[0].cards[0].text === "Write the post" }, 1000)
      // Another; Esc on an empty one takes it away.
      adds = findAll(bv, function(it) { return it.objectName === "boardAdd" }, [])
      click(adds[0])
      tryVerify(function() { return named(bv, "boardCardEdit") !== null }, 1000)
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return cols()[0].cards.length === 1 }, 1000)
      // Dragged to Done.
      var card = null
      tryVerify(function() { card = find(bv, function(it) { return it.objectName === "boardCard" && it.cardId === cols()[0].cards[0].id }); return card !== null }, 1000)
      var done = findAll(bv, function(it) { return it.objectName === "boardColumn" }, [])[2]
      wait(100)
      var p0 = card.mapToItem(root, card.width / 2, card.height / 2)
      var p1 = done.mapToItem(root, done.width / 2, 60)
      mousePress(root, p0.x, p0.y)
      for (var k = 1; k <= 10; k++) mouseMove(root, p0.x + (p1.x - p0.x) * k / 10, p0.y + (p1.y - p0.y) * k / 10)
      wait(30)
      mouseRelease(root, p1.x, p1.y)
      tryVerify(function() { return cols()[2].cards.length === 1 && cols()[0].cards.length === 0 }, 1000, "moved to Done")
      // Its color.
      view.dataAction(view.editor.uidAt(0), "colors", bv)
      var cardId = cols()[2].cards[0].id
      bv.colorScope = { what: "card", id: cardId }
      bv.applyColor("background", "yellow")
      tryVerify(function() { return cols()[2].cards[0].background === "yellow" }, 1000)
      // Open as page: a page inside this one, linked.
      var here = view.page.id
      view.dataAction(view.editor.uidAt(0), "openCard", { id: cardId, text: "Write the post", page: "" })
      tryVerify(function() { return view.page && view.page.id !== here }, 2000)
      var made = view.page.id
      compare(ws.index.pages[made].title, "Write the post")
      compare(ws.index.pages[made].parent, here)
      view.open(here)
      tryVerify(function() { return view.page && view.page.id === here }, 2000)
      compare(dataAt(0).columns[2].cards[0].page, made)
      verify(ws.index.pages[here].children.indexOf(made) >= 0, "a page in it, in the tree")
      // A column more, renamed; deleted.
      var b = Board.addColumn(dataAt(0), "Later")
      view.editor.setData(view.editor.uidAt(0), { columns: b.columns })
      tryVerify(function() { return dataAt(0).columns.length === 4 }, 1000)
      view.editor.setData(view.editor.uidAt(0), { columns: Board.removeColumn(dataAt(0), dataAt(0).columns[3].id).columns })
      tryVerify(function() { return dataAt(0).columns.length === 3 }, 1000)
      // Undo.
      view.editor.undo()
      tryVerify(function() { return dataAt(0).columns.length === 4 }, 1000)
    }

    // A board in a narrow page (so it scrolls across): cards and columns
    // renamed (a click, or ⋯ Rename), a new column named first, a column
    // dragged wider, the board shorter, and a card still dragged across.
    function test_4b_renaming_and_sizing_a_board() {
      root.width = 760
      fresh()
      var b = Board.make()
      b = Board.addCard(b, b.columns[0].id, "Old text")[0]
      for (var d = 1; d <= 5; d++) b = Board.addCard(b, b.columns[2].id, "Done " + d)[0]
      var bv = put({ type: "board", indent: 0, data: b })
      var cols = function() { return dataAt(0).columns }
      // A card: a click writes in it, the cursor at its end.
      click(named(bv, "boardCard"))
      var edit = null
      tryVerify(function() { edit = named(bv, "boardCardEdit"); return edit !== null && edit.activeFocus }, 1000, "the card is written in")
      compare(edit.cursorPosition, edit.length)
      type(" two")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return cols()[0].cards[0].text === "Old text two" }, 1000, "card written in")
      // ⋯ Rename: its text picked, so what's typed replaces it.
      var card = named(bv, "boardCard")
      mouseMove(card, card.width / 2, card.height / 2)
      click(named(bv, "boardCardMore"))
      tryVerify(function() { return named(win(), "boardCardRename") !== null }, 1000)
      click(named(win(), "boardCardRename"))
      tryVerify(function() { edit = named(bv, "boardCardEdit"); return edit !== null && edit.activeFocus && edit.selectedText === "Old text two" }, 1000, "picked")
      type("Renamed")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return cols()[0].cards[0].text === "Renamed" }, 1000, "card renamed")
      // A column's name: a click, its name picked.
      click(named(bv, "boardColumnLabel"))
      var name = null
      tryVerify(function() { name = named(bv, "boardColumnName"); return name !== null && name.activeFocus && name.selectedText === "To do" }, 1000, "the column name is written in")
      type("Backlog")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return cols()[0].name === "Backlog" }, 1000, "column renamed")
      verify(named(bv, "boardColumnName") === null, "a label again")
      // ⋯ Rename, and Esc: as it was.
      click(named(bv, "boardColumnMore"))
      tryVerify(function() { return named(win(), "boardColumnRename") !== null }, 1000)
      click(named(win(), "boardColumnRename"))
      tryVerify(function() { name = named(bv, "boardColumnName"); return name !== null && name.activeFocus }, 1000)
      type("Nope")
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return named(bv, "boardColumnName") === null }, 1000)
      compare(cols()[0].name, "Backlog")
      verify(named(bv, "boardColumnName") === null && bv.Window.window.activeFocusItem.visible, "the keyboard back to the page")
      // + : a column, its name written first (the board scrolled to its end).
      var scroller = bv.children[0].children[0]
      scroller.contentX = scroller.contentWidth - scroller.width
      wait(50)
      click(named(bv, "boardAddColumn"))
      tryVerify(function() { name = named(bv, "boardColumnName"); return cols().length === 4 && name !== null && name.activeFocus && name.selectedText === "New column" }, 1000, "named first")
      type("Later")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return cols()[3].name === "Later" }, 1000, "new column named")
      // A column's right edge, dragged: wider; a double-click: as it fits.
      scroller.contentX = 0
      var first = findAll(bv, function(it) { return it.objectName === "boardColumn" }, [])[0]
      var was = first.width
      var colEdge = named(first, "boardColumnEdge")
      var p = colEdge.mapToItem(root, colEdge.width / 2, 40)
      mousePress(root, p.x, p.y)
      for (var k = 1; k <= 8; k++) mouseMove(root, p.x + 10 * k, p.y)
      mouseRelease(root, p.x + 80, p.y)
      tryVerify(function() { return Math.abs(cols()[0].width - (was + 80)) <= 2 }, 1000, "wider: " + cols()[0].width)
      first = findAll(bv, function(it) { return it.objectName === "boardColumn" }, [])[0]
      compare(Math.round(first.width), cols()[0].width)
      // (A double-click on it; QtTest's clicks never make one.)
      bv.fitColumn(cols()[0].id)
      tryVerify(function() { return cols()[0].width === 0 }, 1000, "fits again")
      // The bottom edge, dragged up: shorter (it scrolls inside).
      var tall = bv.height
      var edge = named(bv, "boardEdge")
      p = edge.mapToItem(root, edge.width / 3, edge.height / 2)
      mousePress(root, p.x, p.y)
      for (k = 1; k <= 6; k++) mouseMove(root, p.x, p.y - 10 * k)
      mouseRelease(root, p.x, p.y - 60)
      tryVerify(function() { return dataAt(0).height > 0 && Math.abs(dataAt(0).height - (tall - 60)) <= 2 }, 1000, "shorter: " + dataAt(0).height)
      tryVerify(function() { return Math.abs(bv.height - dataAt(0).height) <= 1 }, 1000)
      verify(scroller.contentHeight > scroller.height + 1, "it scrolls inside")
      // Undo; and a double-click on it: as tall as its cards again.
      view.editor.undo()
      tryVerify(function() { return dataAt(0).height === 0 }, 1000)
      view.editor.redo()
      tryVerify(function() { return dataAt(0).height > 0 }, 1000)
      viewOf(0).fitHeight()
      tryVerify(function() { return dataAt(0).height === 0 && bv.height > dataAt(0).height }, 1000)
      // A card still drags across, in a board that scrolls.
      verify(scroller.contentWidth > scroller.width, "it scrolls across")
      scroller.contentX = 0
      wait(50)
      card = named(bv, "boardCard")
      var second = findAll(bv, function(it) { return it.objectName === "boardColumn" }, [])[1]
      var p0 = card.mapToItem(root, card.width / 2, card.height / 2)
      var p1 = second.mapToItem(root, second.width / 2, 50)
      mousePress(root, p0.x, p0.y)
      for (k = 1; k <= 10; k++) mouseMove(root, p0.x + (p1.x - p0.x) * k / 10, p0.y + (p1.y - p0.y) * k / 10)
      wait(30)
      mouseRelease(root, p1.x, p1.y)
      tryVerify(function() { return cols()[1].cards.length === 1 && cols()[0].cards.length === 0 }, 1000, "moved to Doing")
      root.width = 1320
    }

    // Each card and each column colored on its own (its palette under the
    // pointer; the color menu says what it colors), the whole board apart;
    // a right-click on a card or a column: its menu.
    function test_4c_coloring_a_board_box_by_box() {
      fresh()
      var b = Board.make()
      b = Board.addCard(b, b.columns[0].id, "First")[0]
      b = Board.addCard(b, b.columns[0].id, "Second")[0]
      var bv = put({ type: "board", indent: 0, data: b })
      var cols = function() { return dataAt(0).columns }
      var cards = findAll(bv, function(it) { return it.objectName === "boardCard" }, [])
      // A card's palette: that card only.
      mouseMove(cards[1], cards[1].width / 2, cards[1].height / 2)
      var paint = null
      tryVerify(function() { paint = named(cards[1], "boardCardColors"); return paint !== null }, 1000, "the card's palette under the pointer")
      click(paint)
      tryVerify(function() { var t = named(win(), "colorSubject"); return t !== null && t.text === "Card: Second" }, 1000, "says what it colors")
      bv.applyColor("background", "yellow")
      tryVerify(function() { return cols()[0].cards[1].background === "yellow" }, 1000)
      compare(cols()[0].cards[0].background, "", "the other card as it was")
      compare(dataAt(0).background, "", "the board as it was")
      keyClick(Qt.Key_Escape)
      // A column's palette: its own box (a color of your own, too).
      paint = named(findAll(bv, function(it) { return it.objectName === "boardColumn" }, [])[1], "boardColumnColors")
      click(paint)
      tryVerify(function() { var t = named(win(), "colorSubject"); return t !== null && t.text === "Column: Doing" }, 1000)
      bv.applyColor("background", "#203040")
      tryVerify(function() { return cols()[1].background === "#203040" }, 1000)
      compare(cols()[1].color, "blue", "its name's color kept")
      compare(cols()[0].background, "")
      compare(dataAt(0).background, "")
      var doing = findAll(bv, function(it) { return it.objectName === "boardColumn" }, [])[1]
      verify(Qt.colorEqual(doing.color, "#203040"), "its box: " + doing.color)
      verify(Colors.contrast(Colors.normalize(String(doing.colInk)), "#203040") >= 4.5, "words that read on it: " + doing.colInk)
      keyClick(Qt.Key_Escape)
      // The corner: the whole board.
      mouseMove(bv, bv.width - 20, 20)
      tryVerify(function() { return named(bv, "boardColors") !== null }, 1000)
      click(named(bv, "boardColors"))
      tryVerify(function() { var t = named(win(), "colorSubject"); return t !== null && t.text === "The whole board" }, 1000)
      bv.applyColor("background", "gray")
      tryVerify(function() { return dataAt(0).background === "gray" }, 1000)
      compare(cols()[0].cards[1].background, "yellow", "the card kept its own")
      keyClick(Qt.Key_Escape)
      // Undo: one step each.
      view.editor.undo()
      tryVerify(function() { return dataAt(0).background === "" && cols()[1].background === "#203040" }, 1000)
      // A right-click: a card's menu, a column's menu.
      cards = findAll(bv, function(it) { return it.objectName === "boardCard" }, [])
      mouseClick(cards[0], cards[0].width / 3, cards[0].height / 2, Qt.RightButton)
      tryVerify(function() { return named(win(), "boardCardRename") !== null }, 1000, "the card's menu")
      // (A click away from it closes it.)
      mouseClick(bv, bv.width - 18, bv.height - 30)
      tryVerify(function() { return named(win(), "boardCardRename") === null }, 1000)
      var head = findAll(bv, function(it) { return it.objectName === "boardColumn" }, [])[2]
      mouseClick(head, head.width / 2, head.height - 12, Qt.RightButton)
      tryVerify(function() { return named(win(), "boardColumnRename") !== null }, 1000, "the column's menu")
      mouseClick(bv, bv.width - 18, bv.height - 30)
    }

    function test_5_a_synced_block() {
      fresh()
      var e = view.editor
      e.insertBlocksAt(0, [{ type: "p", html: "Shared rule", indent: 0 }, { type: "check", html: "Shared to-do", indent: 0 }])
      var a = e.uidAt(0), b = e.uidAt(1)
      view.makeSynced([a, b])
      var i = -1
      tryVerify(function() { i = at("synced"); return i >= 0 }, 1000)
      verify(plains().indexOf("Shared rule") < 0, "moved out of the page")
      var id = dataAt(i).page
      verify(ws.index.pages[id].synced === true)
      verify(!Workspace.rows(ws.index, {}).some(function(r) { return r.id === id }), "not in the tree")
      var sv = viewOf(i)
      var inner = named(sv, "syncedEditor")
      tryVerify(function() { return inner.model.count === 2 }, 2000, "its blocks shown")
      // On another page too.
      view.commit()
      var other = ws.createPage({ parent: "", title: "Other", blocks: [{ type: "synced", indent: 0, data: { page: id } }, { type: "p", html: "", indent: 0 }] })
      tryVerify(function() { return Workspace.backlinks(ws.index, id).length === 2 }, 2000, "known where it is")
      // Changed where it's kept: shown changed.
      ws.editPage(id, function(p) { var f = Workspace.flatten(p)[0]; p.blocks[f.uid].html = "Shared rule, changed"; return true })
      tryVerify(function() { return Html.plainText(inner.blockAt(0).html) === "Shared rule, changed" }, 2000)
      // Edit: its page, which says so.
      view.dataAction(e.uidAt(i), "edit", null)
      tryVerify(function() { return view.page && view.page.id === id }, 2000)
      tryVerify(function() { return named(win(), "syncedNote") !== null }, 1000)
      view.back()
      tryVerify(function() { return view.page && view.page.id !== id }, 2000)
      // Unsynced: its blocks, this page's own.
      i = at("synced")
      view.dataAction(view.editor.uidAt(i), "unsync", null)
      tryVerify(function() { return plains().indexOf("Shared rule, changed") >= 0 && at("synced") < 0 }, 2000)
      // A new one from "/synced": it opens to write in.
      slash("synced")
      var nw = null
      tryVerify(function() { nw = named(win(), "syncedNew"); return nw !== null }, 1000)
      wait(200)
      mouseClick(nw)
      tryVerify(function() { return view.page && ws.index.pages[view.page.id].synced === true }, 2000)
    }

    function test_6_as_markdown() {
      fresh()
      var e = view.editor
      var sid = ws.newSyncedPage([{ type: "p", html: "From the synced block", indent: 0 }])
      e.insertBlocksAt(0, [
        { type: "bookmark", indent: 0, data: { url: "https://example.com/post", title: "A post", description: "About it." } },
        { type: "file", indent: 0, data: { src: "assets/file-20261002-120000-abc-x.pdf", name: "X.pdf", size: 2048, kind: "pdf" } },
        { type: "board", indent: 0, data: { columns: [{ id: "a", name: "To do", cards: [{ id: "k", text: "Ship it" }] }] } },
        { type: "synced", indent: 0, data: { page: sid } }
      ])
      view.copyMarkdown()
      var md = files.copied
      verify(md.indexOf("(https://example.com/post)") > 0, md)
      verify(md.indexOf("> About it.") > 0)
      verify(md.indexOf("X.pdf](assets/file-20261002-120000-abc-x.pdf) (2 KB)") > 0, md)
      verify(md.indexOf("**To do**\n- Ship it") > 0)
      verify(md.indexOf("From the synced block") > 0, "the synced block's blocks")
    }
  }
}
