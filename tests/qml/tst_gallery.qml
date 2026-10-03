import QtQuick
import QtTest
import "../.." as Omanote
import "../../app"
import "../../Workspace.js" as Workspace

// Pictures: a gallery (/gallery: pictures picked, several at once, copied
// in; how many to a row; one moved, captioned, taken out; taller by its
// edge; shown large, the others a key away; in the Library), and a picture
// on a page sized by the handles at its sides.
Item {
  id: root
  width: 1320
  height: 1000

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  Omanote.Workspace { id: ws; files: files }
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
    name: "Gallery"
    when: windowShown

    function fresh() {
      wait(100)
      files.reset()
      view.page = null
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
    function click(item) { verify(item !== null); wait(120); mouseClick(item) }
    function type(text) { for (var i = 0; i < text.length; i++) keyClick(text.charAt(i) === " " ? Qt.Key_Space : text.charAt(i)) }
    function at(t) { return view.editor.serialize().map(function(b) { return b.type }).indexOf(t) }
    function dataAt(i) { return view.editor.serialize()[i].data }
    function viewOf(i) {
      var e = view.editor
      var v = null
      tryVerify(function() { v = e.items[e.uidAt(i)] ? e.items[e.uidAt(i)].dataView : null; return v !== null }, 1000)
      return v
    }
    function tiles(v) { return findAll(v, function(it) { return it.objectName === "galleryTile" }, []) }

    function test_1_a_gallery() {
      fresh()
      files.disk["/tmp/Pictures/beach.png"] = "PNG"
      files.disk["/tmp/Pictures/tram.jpg"] = "JPG"
      files.disk["/tmp/Pictures/cake.webp"] = "WEBP"
      files.disk["/tmp/Pictures/notes.txt"] = "words"
      files.disk["/tmp/Pictures/Trips/lisbon.jpg"] = "JPG"
      var e = view.editor
      e.focusBlock(e.uidAt(e.model.count - 1), 0)
      type("/gallery")
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 }, 1000)
      compare(e.slashItems[0].id, "gallery")
      keyClick(Qt.Key_Return)
      // Pictures, shown as pictures: Pictures' (a folder first, no notes.txt).
      var pk = view.picturePicker
      tryVerify(function() { return pk.visible && pk.entries.length === 4 }, 2000, "the picker, at Pictures")
      compare(pk.folder, "/tmp/Pictures")
      compare(pk.entries[0].dir, true)
      var pics = function() { return findAll(pk, function(it) { return it.objectName === "pickerPicture" }, []) }
      tryVerify(function() { return pics().length === 3 }, 1000)
      // One, then Shift: the run to it.
      click(pics()[0])
      compare(pk.chosen.length, 1)
      wait(150)
      mouseClick(pics()[2], 20, 20, Qt.LeftButton, Qt.ShiftModifier)
      compare(pk.chosen.length, 3, "a run of them")
      click(pics()[1])
      compare(pk.chosen.length, 2, "another click: let go")
      keyClick(Qt.Key_A, Qt.ControlModifier)
      compare(pk.chosen.length, 3, "Ctrl+A: all")
      click(named(pk, "pickerAdd"))
      var i = -1
      tryVerify(function() { i = at("gallery"); return i >= 0 && dataAt(i).images.length === 3 }, 2000, "added, copied in")
      verify(!pk.visible)
      var d = dataAt(i)
      verify(d.images.every(function(x) { return /^assets\//.test(x.src) && files.disk[ws.folder + "/" + x.src] !== undefined }), JSON.stringify(d.images))
      compare(d.columns, 3)
      var v = viewOf(i)
      tryVerify(function() { return tiles(v).length === 3 }, 1000)
      verify(named(v, "galleryAdd") !== null, "more, at its end")
      // Two to a row.
      mouseMove(v, 20, 20)
      var two = null
      tryVerify(function() { two = named(v, "galleryColumns2"); return two !== null }, 1000)
      click(two)
      tryCompare(dataAt(i), "columns", 2)
      // The first later; a caption; the last out.
      var first = d.images[0].src
      var t = tiles(v)[0]
      mouseMove(t, t.width / 2, 40)
      var later = null
      tryVerify(function() { later = find(tiles(v)[0], function(it) { return it.objectName === "gallery_later" }); return later !== null }, 1000)
      click(later)
      tryVerify(function() { return dataAt(i).images[1].src === first }, 1000, "moved later")
      wait(100)
      t = tiles(v)[1]
      mouseMove(t, t.width / 2, 40)
      var cap = null
      tryVerify(function() { cap = find(tiles(v)[1], function(it) { return it.objectName === "gallery_caption" }); return cap !== null }, 1000)
      click(cap)
      var input = null
      tryVerify(function() { input = find(tiles(v)[1], function(it) { return it.objectName === "galleryCaptionEdit" }); return input !== null && input.activeFocus }, 1000)
      type("Beach day")
      keyClick(Qt.Key_Return)
      tryVerify(function() { return dataAt(i).images[1].caption === "Beach day" }, 1000)
      // (The second row: the page scrolled to it.)
      t = tiles(v)[2]
      view.flick.contentY = Math.max(0, t.mapToItem(view.flick.contentItem, 0, 0).y - 200)
      wait(300)
      t = tiles(v)[2]
      mouseMove(t, t.width / 2, 40)
      var out = null
      tryVerify(function() { out = find(tiles(v)[2], function(it) { return it.objectName === "gallery_remove" }); return out !== null }, 1000)
      click(out)
      tryVerify(function() { return dataAt(i).images.length === 2 }, 1000)
      e.undo()
      tryVerify(function() { return dataAt(i).images.length === 3 }, 1000, "Undo puts it back")
      // Taller by its edge (each row by its share).
      var edge = named(v, "galleryEdge")
      verify(edge !== null)
      var before = v.tileH
      mouseDrag(edge, edge.width / 2, edge.height / 2, 0, 120)
      tryVerify(function() { return dataAt(i).height > before }, 1000)
      v.fitHeight()
      tryCompare(dataAt(i), "height", 0)
      // Shown large: the one clicked, the others a key away, Esc.
      t = tiles(v)[1]
      view.flick.contentY = Math.max(0, t.mapToItem(view.flick.contentItem, 0, 0).y - 200)
      wait(300)
      t = tiles(v)[1]
      mouseClick(t, 30, t.height / 2)
      var viewer = null
      tryVerify(function() { viewer = named(view, "pictureViewer"); return viewer !== null }, 1000, "shown large")
      compare(viewer.index, 1)
      compare(viewer.shown.caption, "Beach day")
      compare(named(viewer, "pictureViewerCount").text, "2 / 3")
      keyClick(Qt.Key_Right)
      compare(viewer.index, 2)
      keyClick(Qt.Key_Right)
      compare(viewer.index, 0, "round again")
      keyClick(Qt.Key_Escape)
      verify(!viewer.visible)
      // In the Library, each picture; Markdown, too.
      view.commit()
      var pics = Workspace.collected(ws.index).filter(function(r) { return r.kind === "picture" && r.page === view.page.id })
      compare(pics.length, 3)
      verify(pics.some(function(r) { return r.title === "Beach day" }))
      // Dropped on it: more.
      files.disk["/tmp/in/more.png"] = "PNG"
      view.addToGallery(view.page.id, e.uidAt(i), ["/tmp/in/more.png"])
      tryVerify(function() { return dataAt(i).images.length === 4 }, 1000)
    }

    function test_2_a_picture_sized_by_its_sides() {
      fresh()
      files.disk["/tmp/in/pic.png"] = "PNG"
      files.disk["/tmp/Pictures/one.png"] = "PNG"
      var e = view.editor
      var src = ""
      ws.importPicture("/tmp/in/pic.png", function(s) { src = s })
      tryVerify(function() { return src !== "" }, 1000)
      e.insertBlocksAt(0, [{ type: "image", src: src, width: 0.5, align: "center", ratio: 1.5, indent: 0 }])
      var item = null
      tryVerify(function() { item = e.items[e.uidAt(0)]; return item !== null && item.height > 50 }, 1000)
      // Under the pointer: a handle each side.
      wait(100)
      var pf = find(item, function(it) { return it.objectName === "pictureFrame" })
      mouseMove(pf, pf.width / 2, pf.height / 2)
      var right = null
      tryVerify(function() { right = find(item, function(it) { return it.objectName === "pictureSizeRight" }); return right !== null }, 1000)
      verify(find(item, function(it) { return it.objectName === "pictureSizeLeft" }) !== null)
      var w0 = e.blockAt(0).width
      mouseDrag(right, right.width / 2, right.height / 2, 80, 0)
      tryVerify(function() { return e.blockAt(0).width > w0 }, 1000, "wider")
      var w1 = e.blockAt(0).width
      e.undo()
      tryVerify(function() { return Math.abs(e.blockAt(0).width - w0) < 0.001 }, 1000, "Undo: as it was")
      verify(w1 > w0)
      // A corner, dragged out and down: bigger, its shape kept.
      mouseMove(pf, pf.width / 2, pf.height / 2)
      var corner = null
      tryVerify(function() { corner = find(item, function(it) { return it.objectName === "pictureCorner_br" }); return corner !== null }, 1000, "a handle at each corner")
      verify(find(item, function(it) { return it.objectName === "pictureCorner_tl" }) !== null)
      var h0 = item.picH
      mouseDrag(corner, corner.width / 2, corner.height / 2, 60, 40)
      tryVerify(function() { return e.blockAt(0).width > w0 && item.picH > h0 }, 1000, "bigger both ways")
      compare(Math.round(item.picW / item.picH * 100), 150, "its shape")
      e.undo()
      tryVerify(function() { return Math.abs(e.blockAt(0).width - w0) < 0.001 }, 1000)
      // /image: one picture, a click on it.
      var got = []
      view.picturePicker.choose(false, function(paths) { got = paths })
      tryVerify(function() { return findAll(view.picturePicker, function(it) { return it.objectName === "pickerPicture" }, []).length > 0 }, 2000)
      click(findAll(view.picturePicker, function(it) { return it.objectName === "pickerPicture" }, [])[0])
      compare(got.length, 1)
      verify(!view.picturePicker.visible)
      // Clicked twice: shown large here (not in another app).
      e.openPicture(src)
      var viewer = null
      tryVerify(function() { viewer = named(view, "pictureViewer"); return viewer !== null }, 1000, "shown large, here")
      compare(files.opened.length, 0)
      keyClick(Qt.Key_Escape)
    }
  }
}
