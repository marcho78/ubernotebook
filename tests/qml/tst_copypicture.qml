import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Library.js" as Library

// A picture out of Uber Notebook: Copy (onto the clipboard, to paste
// anywhere) and Save a copy (where you say, named for its caption or its
// page) from its bar when it's picked, and where it's shown large (its
// buttons, Ctrl+C, Ctrl+S). Shown large, a click is the one thing's it's
// on: an arrow steps (it stays open), a button isn't also the page's
// button under it, a click around the picture closes it.
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
    name: "CopyPicture"
    when: windowShown

    function fresh() {
      files.reset()
      view.page = null
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      files.copiedPicture = ""
      service.saveName = ""
      service.nextSave = ""
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
    // A picture copied into Pages/assets, as one added is: its src.
    function addPicture(path) {
      files.disk[path] = "PNG"
      var src = ""
      ws.importPicture(path, function(s) { src = s })
      tryVerify(function() { return src !== "" }, 1000)
      return src
    }

    function test_1_from_its_bar() {
      fresh()
      var src = addPicture("/tmp/in/generated.png")
      var page = ws.createPage({ title: "Trip to Lisbon", blocks: [{ type: "image", src: src, width: 0.5, align: "center", ratio: 1.5, indent: 0 }, { type: "p", html: "", indent: 0 }] })
      view.open(page.id)
      tryVerify(function() { return view.page && view.page.id === page.id }, 2000)
      var e = view.editor
      var item = null
      tryVerify(function() { item = e.items[e.uidAt(0)]; return item && item.type === "image" && item.height > 50 }, 2000)
      wait(100)
      // Picked (a click on it): its bar, Copy and Save a copy on it.
      mouseClick(named(item, "pictureFrame"))
      var copy = null
      tryVerify(function() { copy = named(item, "pictureBar_copy"); return copy !== null }, 1000, "its bar")
      verify(named(item, "pictureBar_save") !== null)
      // (Its buttons in a row once it's drawn.)
      tryVerify(function() { return named(item, "pictureBar_remove").x > copy.x && copy.x > 0 }, 1000, "laid out")
      // Copy: onto the clipboard.
      mouseClick(copy)
      tryCompare(files, "copiedPicture", ws.folder + "/" + src)
      compare(root.lastToast, "Copied: paste it anywhere")
      // Save a copy: named for its page, where you say.
      service.nextSave = "/tmp/Pictures/Trip to Lisbon.png"
      mouseClick(named(item, "pictureBar_save"))
      compare(service.saveName, "Trip to Lisbon.png")
      tryVerify(function() { return files.disk["/tmp/Pictures/Trip to Lisbon.png"] === "PNG" }, 1000, "saved there")
      compare(root.lastToast, "Saved to ~/Pictures/Trip to Lisbon.png")
      // The dialog closed without a place: nothing.
      service.nextSave = ""
      root.lastToast = ""
      mouseClick(named(item, "pictureBar_save"))
      compare(root.lastToast, "")
      // Copy failing (its file gone): said.
      delete files.disk[ws.folder + "/" + src]
      mouseClick(named(item, "pictureBar_copy"))
      compare(root.lastToast, "The picture couldn't be copied")
    }

    function test_2_shown_large() {
      fresh()
      var e = view.editor
      var a = addPicture("/tmp/in/a.png")
      var b = addPicture("/tmp/in/b.jpg")
      var blocks = e.model.count
      view.showPictures([{ src: a, caption: "Beach day" }, { src: b, caption: "" }], 0)
      var pv = null
      tryVerify(function() { pv = named(view, "pictureViewer"); return pv !== null }, 1000)
      wait(100)
      // Its buttons: copied; a copy saved, named for its caption; still open.
      mouseClick(named(pv, "pictureViewer_copy"))
      compare(files.copiedPicture, ws.folder + "/" + a)
      verify(pv.visible, "still open")
      service.nextSave = "/tmp/out/Beach day.png"
      mouseClick(named(pv, "pictureViewer_save"))
      compare(service.saveName, "Beach day.png")
      tryVerify(function() { return files.disk["/tmp/out/Beach day.png"] === "PNG" }, 1000)
      verify(pv.visible, "still open")
      // The arrow: the next one, still open.
      mouseClick(named(pv, "pictureViewerNext"))
      compare(pv.index, 1)
      verify(pv.visible, "the arrow doesn't close it")
      // Keys: Ctrl+C, Ctrl+S (no caption: named for its page).
      files.copiedPicture = ""
      keyClick(Qt.Key_C, Qt.ControlModifier)
      compare(files.copiedPicture, ws.folder + "/" + b)
      service.nextSave = ""
      keyClick(Qt.Key_S, Qt.ControlModifier)
      compare(service.saveName, Library.saveName(view.page.title, b))
      verify(/\.jpg$/.test(service.saveName), "its own ending")
      // Nothing on the page under its buttons was clicked.
      compare(e.model.count, blocks)
      // A click around the picture: closed.
      mouseClick(pv, 40, 30)
      tryVerify(function() { return !pv.visible }, 1000, "closed")
    }
  }
}
