import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"

// The Library: everything put on the pages, from the sidebar. Its kinds,
// words to find a thing by, a click opening its page there (and Back
// coming back), Open and Copy, and what's added or put in the trash
// showing there as it happens.
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
    name: "Library"
    when: windowShown

    property string launch: ""
    property string trip: ""

    function fresh() {
      // (The workspace's own first load, a moment after it's made, done.)
      wait(100)
      files.reset()
      files.opened = []
      view.page = null
      view.libraryShown = false
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      // Two pages with things on them, and one in the trash.
      launch = ws.createPage({ parent: "", title: "Launch", icon: "\u{1f680}", blocks: [
        { type: "p", html: 'Read <a href="https://example.com/guide">the guide</a> first', indent: 0 },
        { type: "bookmark", indent: 0, data: { url: "https://omarchy.org/news", title: "Omarchy 4", site: "Omarchy" } },
        { type: "file", indent: 0, data: { src: "assets/file-20261001-090000-abc-spec.pdf", name: "Spec.pdf", size: 52311, kind: "pdf" } }
      ] }).id
      trip = ws.createPage({ parent: "", title: "Trip to Lisbon", blocks: [
        { type: "image", src: "assets/20261002-101010-k3f2.png", indent: 0 },
        { type: "video", indent: 0, data: { src: "assets/file-20261002-120000-def-tram.mp4", name: "Tram.mp4", size: 1200000 } },
        { type: "audio", indent: 0, audio: { src: "assets/audio-20261002-130000-k3f.ogg", duration: 42, transcript: "Remember the pastry shop" } }
      ] }).id
      var gone = ws.createPage({ parent: "", title: "Old", blocks: [{ type: "bookmark", indent: 0, data: { url: "https://gone.example.com", title: "Gone" } }] }).id
      ws.trashPage(gone, false)
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
    function lib() { return named(view, "libraryView") }
    function rows() { return findAll(lib(), function(it) { return it.objectName === "libraryRow" }, []) }
    function titles() { return rows().map(function(r) { return r.modelData.title }) }
    function rowOf(title) { return rows().filter(function(r) { return r.modelData.title === title })[0] || null }
    function click(item) { verify(item !== null); wait(120); mouseClick(item) }
    function type(text) { for (var i = 0; i < text.length; i++) keyClick(text.charAt(i) === " " ? Qt.Key_Space : text.charAt(i)) }

    function test_1_everything_from_the_sidebar() {
      fresh()
      click(named(view, "libraryTile"))
      tryVerify(function() { return view.libraryShown && lib() !== null }, 1000)
      tryVerify(function() { return titles().indexOf("Spec.pdf") >= 0 }, 1000)
      var t = titles()
      ;["the guide", "Omarchy 4", "Spec.pdf", "Picture", "Tram.mp4", "Remember the pastry shop"].forEach(function(want) { verify(t.indexOf(want) >= 0, want + " in " + JSON.stringify(t)) })
      verify(t.indexOf("Gone") < 0, "not the trash's")
      compare(view.page, null)
      // Newest first: the trip's (2 Oct) before the launch's PDF (1 Oct).
      verify(t.indexOf("Tram.mp4") < t.indexOf("Spec.pdf"), JSON.stringify(t))
      var pdf = rowOf("Spec.pdf")
      verify(find(pdf, function(it) { return it.text !== undefined && String(it.text).indexOf("PDF") === 0 && String(it.text).indexOf("on \u{1f680} Launch") > 0 }) !== null, "what it is, and its page")
    }

    function test_2_kinds_and_words() {
      fresh()
      view.openLibrary("")
      tryVerify(function() { return rows().length > 0 }, 1000)
      var chips = findAll(lib(), function(it) { return it.objectName === "libraryKind" }, [])
      var files_ = chips.filter(function(c) { return c.kindId === "file" })[0]
      verify(files_ !== undefined && files_.text === "Files  1", files_ ? files_.text : "no Files chip")
      verify(chips.filter(function(c) { return c.kindId === "sketch" }).length === 0, "no Sketches: there are none")
      click(files_)
      tryVerify(function() { return JSON.stringify(titles()) === JSON.stringify(["Spec.pdf"]) }, 1000)
      click(named(lib(), "libraryAll"))
      tryVerify(function() { return rows().length > 3 }, 1000)
      // Words: the search field has the keyboard as the Library opens.
      tryVerify(function() { return named(lib(), "librarySearch").input.activeFocus }, 1000)
      type("lisbon")
      tryVerify(function() { var t = titles(); return t.length === 3 && t.indexOf("Tram.mp4") >= 0 }, 1000, "the page's name counts: " + JSON.stringify(titles()))
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return rows().length > 3 }, 1000)
      type("nothing like it")
      tryVerify(function() { return rows().length === 0 }, 1000)
    }

    function test_3_open_copy_and_go_to_it() {
      fresh()
      view.openLibrary("")
      tryVerify(function() { return rowOf("Omarchy 4") !== null }, 1000)
      // Open and Copy, under the pointer.
      var r = rowOf("Omarchy 4")
      mouseMove(r, r.width / 2, r.height / 2)
      tryVerify(function() { return named(r, "libraryOpen") !== null }, 1000)
      click(named(r, "libraryCopy"))
      compare(files.copied, "https://omarchy.org/news")
      click(named(r, "libraryOpen"))
      compare(files.opened[files.opened.length - 1], "https://omarchy.org/news")
      verify(view.libraryShown, "still here")
      r = rowOf("Spec.pdf")
      mouseMove(r, r.width / 2, r.height / 2)
      tryVerify(function() { return named(r, "libraryOpen") !== null }, 1000)
      verify(named(r, "libraryCopy") === null, "a file: no link to copy")
      click(named(r, "libraryOpen"))
      verify(/^file:\/\/.*\/assets\/file-20261001-090000-abc-spec\.pdf$/.test(files.opened[files.opened.length - 1]), files.opened[files.opened.length - 1])
      // A click on it: its page, at it.
      r = rowOf("Spec.pdf")
      mouseClick(r, 60, r.height / 2)
      tryVerify(function() { return view.page !== null && view.page.id === launch && !view.libraryShown }, 2000)
      tryVerify(function() { return view.editor.selectedList.length === 1 && view.editor.serialize()[2].type === "file" && view.editor.selectedList[0] === view.editor.uidAt(2) }, 1000, "the file's block, picked")
      // Back: the Library again.
      view.back()
      tryVerify(function() { return view.libraryShown && rows().length > 0 }, 2000)
    }

    function test_4_as_pages_change() {
      fresh()
      view.openLibrary("")
      tryVerify(function() { return rowOf("Spec.pdf") !== null }, 1000)
      var before = rows().length
      // A page with a bookmark on it: there.
      ws.createPage({ parent: "", title: "Notes", blocks: [{ type: "bookmark", indent: 0, data: { url: "https://visitlisbon.com", title: "Visit Lisbon" } }] })
      tryVerify(function() { return rowOf("Visit Lisbon") !== null }, 2000)
      compare(rows().length, before + 1)
      // A page to the trash: its things go.
      ws.trashPage(launch, false)
      tryVerify(function() { return rowOf("Spec.pdf") === null && rowOf("Omarchy 4") === null && rowOf("the guide") === null }, 2000)
      verify(rowOf("Tram.mp4") !== null)
    }
  }
}
