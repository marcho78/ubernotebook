import QtQuick
import QtTest
import "../../app"
import "../../Templates.js" as Templates

// The open notebook: pages, turning them, autosaving, tabs and paper.
Item {
  id: root
  width: 1320
  height: 900

  FakeStore { id: fakeStore }
  Theme { id: th }

  NotebookView {
    id: view
    anchors.fill: parent
    theme: th
    store: fakeStore
    settings: ({ strikeDone: true })
    reduceMotion: true
  }

  TestCase {
    name: "Notebook"
    when: windowShown

    function openFirst() {
      fakeStore.reset()
      var done = null
      fakeStore.openNotebook(fakeStore.notebooks[0].id, function(nb) { done = nb })
      view.show(done, 0)
      wait(0)
      return done
    }
    function stored(pageId) {
      var nb = fakeStore.data[view.nb.id]
      return nb.pages.filter(function(p) { return p.id === pageId })[0]
    }

    function test_1_opens_at_the_first_page() {
      openFirst()
      compare(view.pageIndex, 0)
      compare(view.pageCount, 2)
      compare(view.page.title, "Lisbon, in October")
      verify(view.editor.model.count > 5)
    }

    function test_2_autosaves() {
      openFirst()
      var item = view.editor.items[view.editor.uidAt(0)]
      view.editor.focusBlock(item.uid, -1)
      keyClick("!")
      tryCompare(view, "pageDirty", false, 2000)
      var saved = stored(view.page.id)
      verify(/Before we go!/.test(saved.blocks[0].html), saved.blocks[0].html)
      verify(saved.text.indexOf("Before we go!") >= 0)
    }

    // Another profile opening: the page saved at once, where it was; an
    // edit made then too (not left for a timer that would come too late).
    function test_2c_saved_as_another_profile_opens() {
      openFirst()
      var item = view.editor.items[view.editor.uidAt(0)]
      view.editor.focusBlock(item.uid, -1)
      try {
        keyClick("!")
        verify(view.pageDirty)
        fakeStore.switching = true
        verify(!view.pageDirty, "saved the moment it started")
        verify(/Before we go!/.test(stored(view.page.id).blocks[0].html))
        keyClick("?")
        verify(!view.pageDirty, "and an edit then, at once")
        verify(/Before we go!\?/.test(stored(view.page.id).blocks[0].html), stored(view.page.id).blocks[0].html)
      } finally {
        fakeStore.switching = false
      }
    }

    // A picture copied in as another profile opens: not put on a page of
    // that one (a restored one's notebooks have the same ids).
    function test_2d_a_picture_as_another_profile_opens() {
      openFirst()
      var count = view.editor.model.count
      try {
        fakeStore.nextPicture = "assets/pasted.png"
        fakeStore.holdSearch = true
        view.pastePicture(view.editor.uidAt(0))
        view.addPicture("/tmp/a.png", view.editor.uidAt(0))
        compare(fakeStore.heldSearches.length, 2)
        fakeStore.switching = true
        fakeStore.answerSearches()
        wait(50)
        compare(view.editor.model.count, count, "no picture put in")
      } finally {
        fakeStore.holdSearch = false
        fakeStore.answerSearches()
        fakeStore.switching = false
        fakeStore.nextPicture = ""
      }
    }

    // A notebook's page changed, then another profile opened before it's
    // saved: never saved into that one (a restored one's notebooks have
    // the same ids).
    function test_2e_never_saved_into_another_profile() {
      openFirst()
      var root0 = fakeStore.rootPath
      var item = view.editor.items[view.editor.uidAt(0)]
      view.editor.focusBlock(item.uid, -1)
      try {
        keyClick("#")
        verify(view.pageDirty)
        fakeStore.rootPath = "/tmp/another-profile"
        view.commit()
        verify(!/Before we go#/.test(stored(view.page.id).blocks[0].html), stored(view.page.id).blocks[0].html)
        verify(!view.pageDirty)
      } finally {
        fakeStore.rootPath = root0
      }
    }

    // A middle click pastes what's selected (the primary selection), read
    // through the view's forwarding to the store, not the clipboard.
    function test_2b_middle_click_pastes_whats_selected() {
      openFirst()
      var asked = []
      fakeStore.readClipboard = function(done, primary) { asked.push(primary === true); done(primary ? { html: "", text: "picked " } : { html: "", text: "the clipboard" }) }
      try {
        var item = view.editor.items[view.editor.uidAt(0)]
        mouseClick(item.edit, 1, item.edit.cursorRectangle.height / 2, Qt.MiddleButton)
        compare(asked, [true])
        verify(/^picked Before/.test(item.edit.getText(0, item.edit.length)), item.edit.getText(0, item.edit.length))
      } finally {
        fakeStore.readClipboard = null
      }
    }

    function test_3_turns_pages() {
      openFirst()
      view.next()
      tryCompare(view, "pageIndex", 1, 1000)
      compare(view.page.title, "Reading list")
      view.previous()
      tryCompare(view, "pageIndex", 0, 1000)
    }

    function test_4_a_new_page_past_the_last() {
      openFirst()
      view.turnTo(1)
      tryCompare(view, "pageIndex", 1, 1000)
      wait(300)
      view.next()
      tryCompare(view, "pageCount", 3, 1000)
      tryCompare(view, "pageIndex", 2, 1000)
      view.next()
      wait(300)
      compare(view.pageCount, 3, "a blank last page isn't followed by another")
    }

    function test_5_tearing_out_and_moving() {
      openFirst()
      var first = view.nb.pages[0].id
      view.movePage(0, 1)
      compare(view.nb.pages[1].id, first)
      compare(view.pageIndex, 1, "still on the same page")
      view.deletePage(1)
      compare(view.pageCount, 1)
      compare(fakeStore.data[view.nb.id].pages.length, 1)
      view.deletePage(0)
      compare(view.pageCount, 1, "the last page is wiped, not torn out")
      compare(view.page.title, "")
    }

    function test_6_paper_and_tabs() {
      openFirst()
      view.setPaper({ pattern: "dots", color: "night", spacing: "roomy" }, false)
      compare(view.look.pattern, "dots")
      compare(view.look.dark, true)
      compare(view.editor.dark, true)
      view.setPaper({ pattern: "grid", color: "white", spacing: "compact" }, true)
      compare(view.page.paper, null, "every page follows the notebook")
      compare(view.look.pattern, "grid")
      compare(fakeStore.data[view.nb.id].paper.pattern, "grid")
      view.setTab({ color: "#f2c14e", label: "Trips" })
      compare(stored(view.page.id).tab.label, "Trips")
    }

    function test_8_drawing() {
      openFirst()
      view.setDrawing(true)
      var ink = view.sheet ? view.sheet.ink : null
      var layer = findInk(view)
      verify(layer !== null, "an ink layer")
      waitForRendering(view)
      mousePress(layer, 200, 400)
      mouseMove(layer, 230, 410, -1, Qt.LeftButton)
      mouseMove(layer, 260, 430, -1, Qt.LeftButton)
      mouseMove(layer, 300, 440, -1, Qt.LeftButton)
      mouseRelease(layer, 300, 440)
      compare(layer.strokes.length, 1)
      compare(layer.strokes[0].tool, "pen")
      verify(layer.strokes[0].points.length >= 6)
      view.inkTool = "marker"
      mousePress(layer, 200, 600)
      mouseMove(layer, 260, 600, -1, Qt.LeftButton)
      mouseRelease(layer, 260, 600)
      compare(layer.strokes.length, 2)
      compare(layer.strokes[1].tool, "marker")
      view.inkTool = "eraser"
      mousePress(layer, 230, 410)
      mouseMove(layer, 232, 412, -1, Qt.LeftButton)
      mouseRelease(layer, 232, 412)
      compare(layer.strokes.length, 1, "the eraser lifts the pen stroke")
      keyClick(Qt.Key_Z, Qt.ControlModifier)
      compare(layer.strokes.length, 2, "and Ctrl+Z puts it back")
      keyClick(Qt.Key_Escape)
      compare(view.drawing, false)
      tryCompare(view, "pageDirty", false, 2000)
      compare(stored(view.page.id).ink.length, 2, "saved with the page")
    }

    function findInk(item) {
      if (item.strokes !== undefined && item.eraseAt !== undefined) return item
      for (var i = 0; i < item.children.length; i++) {
        var found = findInk(item.children[i])
        if (found) return found
      }
      return null
    }

    function test_9_a_new_page_has_no_title() {
      // Title a new, untitled page, then start another one after it.
      openFirst()
      view.turnTo(1)
      tryCompare(view, "pageIndex", 1, 1000)
      view.next()
      tryCompare(view, "pageIndex", 2, 1000)
      compare(view.pageSheet.titleField.text, "")
      view.pageSheet.titleField.forceActiveFocus()
      keyClick("M")
      keyClick("y")
      view.pageSheet.titleEdited(view.pageSheet.titleField.text)
      view.editor.focusStart()
      keyClick("a")
      wait(300)
      view.next()
      tryCompare(view, "pageCount", 4, 1000)
      tryCompare(view, "pageIndex", 3, 1000)
      compare(view.pageSheet.titleField.text, "", "the new page's title is empty")
      view.editor.focusStart()
      keyClick("x")
      tryCompare(view, "pageDirty", false, 2000)
      compare(stored(view.page.id).title, "", "and stays empty when it's saved")
      compare(stored(view.nb.pages[2].id).title, "My", "the page before kept its own")
    }

    function today() { return Templates.iso(new Date()) }

    function test_10_a_page_from_a_template() {
      openFirst()
      view.addTemplatePage("daily")
      tryCompare(view, "pageIndex", 1, 2000)
      compare(view.pageCount, 3, "a new page after the one you were on")
      compare(view.page.template, "daily")
      compare(view.page.day, today())
      verify(view.page.title !== "", "titled with its day")
      verify(view.page.blocks.some(function(b) { return b.type === "time" }), "with a schedule")
      compare(stored(view.page.id).template, "daily", "saved as one")
      // Another daily page after it is the next day's.
      view.newPage(view.pageIndex + 1, "daily")
      tryCompare(view, "pageIndex", 2, 2000)
      compare(view.page.day, Templates.addDays(today(), 1))
    }

    function test_11_a_template_on_a_blank_page() {
      openFirst()
      view.turnTo(1)
      tryCompare(view, "pageIndex", 1, 1000)
      view.newPage(2)
      tryCompare(view, "pageIndex", 2, 1000)
      compare(view.pageCount, 3)
      view.addTemplatePage("meeting")
      compare(view.pageCount, 3, "the blank page takes it")
      compare(view.page.template, "meeting")
      compare(view.pageSheet.titleField.text, "", "the meeting is yours to name")
      verify(view.pageSheet.titleField.activeFocus, "so the cursor waits there")
      compare(view.pageSheet.placeholder, "What's the meeting?")
      tryCompare(view, "pageDirty", false, 2000)
      compare(stored(view.page.id).template, "meeting")
    }

    function test_12_a_planner_notebook_goes_on_by_the_week() {
      openFirst()
      view.nb.template = "weekly"
      view.turnTo(1)
      tryCompare(view, "pageIndex", 1, 1000)
      view.next()
      tryCompare(view, "pageCount", 3, 1000)
      tryCompare(view, "pageIndex", 2, 1000)
      compare(view.page.template, "weekly")
      compare(view.page.day, Templates.mondayOf(today()))
      view.next()
      tryCompare(view, "pageCount", 4, 1000)
      tryCompare(view, "pageIndex", 3, 1000)
      compare(view.page.day, Templates.addDays(Templates.mondayOf(today()), 7), "and the next is the week after")
      compare(view.pageSheet.dateText, "", "its title is its dates, so they aren't written twice")
      view.pageSheet.titleField.text = "The big week"
      view.markDirty()
      view.commit()
      verify(view.pageSheet.dateText.indexOf("\u2013") > 0, "named otherwise, the week's dates are beside it")
    }

    // A save that couldn't be written stays to be saved: the next one has it.
    function test_12b_a_failed_save_is_tried_again() {
      openFirst()
      var id = view.page.id
      view.pageSheet.titleField.text = "Kept"
      view.markDirty()
      fakeStore.failSaves = true
      view.commit()
      verify(view.pageDirty, "still to be saved")
      compare(stored(id).title, "Lisbon, in October")
      fakeStore.failSaves = false
      view.commit()
      verify(!view.pageDirty)
      compare(stored(id).title, "Kept")
    }

    function test_13_the_template_picker() {
      openFirst()
      view.openTemplates()
      var pop = findPop(view)
      verify(pop !== null)
      tryCompare(pop, "opened", true, 1000)
      compare(pop.currentId, "blank", "starting at the notebook's own kind")
      keyClick(Qt.Key_Right)
      compare(pop.currentId, "todo")
      keyClick(Qt.Key_Up)
      compare(pop.currentId, "weekly", "the card above it")
      keyClick(Qt.Key_Down)
      compare(pop.currentId, "todo")
      keyClick(Qt.Key_Right)
      compare(pop.currentId, "meeting")
      keyClick(Qt.Key_Return)
      tryCompare(pop, "opened", false, 1000)
      tryCompare(view, "pageIndex", 1, 2000)
      compare(view.page.template, "meeting")
    }

    function findPop(item) {
      if (item.planners !== undefined && item.pick !== undefined) return item
      var kids = item.children || []
      for (var i = 0; i < kids.length; i++) {
        var found = findPop(kids[i])
        if (found) return found
      }
      var res = item.resources || []
      for (var j = 0; j < res.length; j++) {
        if (res[j] && res[j].planners !== undefined) return res[j]
      }
      return null
    }

    function test_7_keys() {
      openFirst()
      view.editor.focusStart()
      keyClick(Qt.Key_PageDown, Qt.ControlModifier)
      tryCompare(view, "pageIndex", 1, 1000)
      wait(300)
      keyClick(Qt.Key_T, Qt.ControlModifier)
      var pop = findPop(view)
      tryCompare(pop, "opened", true, 1000)
      keyClick(Qt.Key_Escape)
      tryCompare(pop, "visible", false, 1000)
    }
  }
}
