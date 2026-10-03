import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Workspace.js" as Workspace
import "../../Html.js" as Html
import "../../Tags.js" as Tags
import "../../Docs.js" as Docs

// Tags in Pages: "#" typed in a line, the "#" menu, a tag clicked showing
// every block with it, to-dos ticked there, a tag renamed, taken away and
// colored, the sidebar's tags, and finding a tag with Ctrl+P.
Item {
  id: root
  width: 1320
  height: 900

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  UberNotebook.Workspace { id: ws; files: files }

  DocView {
    id: view
    anchors.fill: parent
    theme: th
    workspace: ws
    service: service
  }

  // Confirm dialogs (removing a tag), answered yes.
  Connections {
    target: view
    function onConfirmRequested(title, text, action, confirmed) { confirmed() }
  }

  TestCase {
    name: "Tags"
    when: windowShown

    function fresh() {
      files.reset()
      view.page = null
      view.tagShown = ""
      view.history = []
      view.historyAt = -1
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      wait(0)
    }
    function type(text) {
      for (var i = 0; i < text.length; i++) {
        var ch = text.charAt(i)
        if (ch === " ") keyClick(Qt.Key_Space)
        else if (ch === "#") keyClick(Qt.Key_NumberSign, Qt.ShiftModifier)
        else keyClick(ch)
      }
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
    function all(item, test, out) {
      if (!item) return out
      if (item.visible && test(item)) out.push(item)
      for (var i = 0; i < item.children.length; i++) all(item.children[i], test, out)
      return out
    }
    function named(item, name) { return find(item, function(it) { return it.objectName === name }) }
    // A new line at the end of the page, with the cursor in it.
    function newLine() {
      var e = view.editor
      e.insertBlocksAt(e.model.count, [{ type: "p", html: "", indent: 0 }])
      e.focusBlock(e.uidAt(e.model.count - 1), 0)
      return e.uidAt(e.model.count - 1)
    }
    function htmlOf(uid) { var e = view.editor; e.syncAll(); var i = e.indexOf(uid); return i >= 0 ? e.blockAt(i).html : "(gone: " + uid + ")" }
    function tagsOf(uid) { return Tags.inHtml(htmlOf(uid)).map(function(t) { return t.name }) }

    function test_1_typed_in_a_line() {
      fresh()
      var e = view.editor
      var uid = newLine()
      type("Buy milk #Errand ")
      compare(tagsOf(uid), ["errand"], "a space after it: it's a tag")
      verify(htmlOf(uid).indexOf(">#Errand</a>") >= 0, "as written")
      compare(Html.plainText(htmlOf(uid)), "Buy milk #Errand ")
      type("and #home.")
      compare(tagsOf(uid), ["errand", "home"], "a stop ends it too")
      compare(Html.plainText(htmlOf(uid)), "Buy milk #Errand and #home.")
      // Not tags: in a word, a number, "# " (a heading).
      var other = newLine()
      type("C# and #1 and issue#2 ")
      compare(tagsOf(other), [])
      var head = newLine()
      type("# Title")
      compare(e.typeOf(head), "h1", "\"# \" at the start is still a heading")
      compare(tagsOf(head), [])
      // Saved: the page knows its tags, and the sidebar lists them.
      view.commit()
      compare(Workspace.pageTags(ws.readPageNow(view.page.id)).map(function(t) { return t.name }), ["errand", "home"])
      tryVerify(function() { return all(root, function(it) { return it.objectName === "tagRow" }, []).length === 2 }, 1000, "the sidebar's tags")
    }

    function test_2_the_hash_menu() {
      fresh()
      var e = view.editor
      newLine()
      type("one #chores ")
      view.commit()
      var uid = newLine()
      type("two #ch")
      tryVerify(function() { return e.mention !== null && e.mention.kind === "tag" }, 1000, "the # menu")
      compare(e.mentionItems[0].kind, "tag")
      compare(e.mentionItems[0].name, "chores", "the tag there is")
      compare(e.mentionItems[e.mentionItems.length - 1].kind, "tagnew", "and a new one with what's typed")
      keyClick(Qt.Key_Return)
      compare(tagsOf(uid), ["chores"])
      compare(Html.plainText(htmlOf(uid)), "two #chores ", "the tag as it's written elsewhere, and a space")
      // Esc: what's typed stays plain.
      var plain = newLine()
      type("three #later")
      tryVerify(function() { return e.mention !== null }, 1000)
      keyClick(Qt.Key_Escape)
      compare(e.mention, null)
      compare(tagsOf(plain), [], "Esc leaves it plain")
    }

    function test_3_clicked_the_tag_view_and_back() {
      fresh()
      var e = view.editor
      var home = view.page.id
      ws.createPage({ parent: "", title: "Groceries", blocks: [
        { type: "check", html: "milk " + Tags.html("errand"), indent: 0 },
        { type: "p", html: "no tag here", indent: 0 },
        { type: "bullet", html: "bread " + Tags.html("errand") + " " + Tags.html("Home"), indent: 0 }] })
      var uid = newLine()
      type("post the letter #errand ")
      view.commit()
      // A click on the tag in the line.
      e.openLink(Tags.href("errand"))
      tryCompare(view, "tagShown", "errand", 1000)
      verify(view.tagView.visible)
      tryVerify(function() { return view.tagView.groups.length === 2 }, 2000, "both pages")
      compare(view.tagView.blockCount, 3, "every block with it")
      var groceries = view.tagView.groups.filter(function(g) { return g.title === "Groceries" })[0]
      compare(groceries.blocks.map(function(b) { return b.type }), ["check", "bullet"], "only the blocks with it, in order")
      // A to-do ticked there: on its page.
      tryVerify(function() { return named(view.tagView, "tagCheck") !== null }, 1000)
      mouseClick(named(view.tagView, "tagCheck"))
      tryVerify(function() {
        var p = ws.readPageNow(Workspace.pageNamed(ws.index, "Groceries"))
        return Workspace.flatten(p)[0].checked === true
      }, 2000, "ticked on its page")
      // Back to the page; forward to the tag.
      view.back()
      tryVerify(function() { return view.page && view.page.id === home && view.tagShown === "" }, 2000, "back on the page")
      view.forward()
      tryCompare(view, "tagShown", "errand", 1000)
      // A block clicked: its page, the cursor on it.
      tryVerify(function() { return all(view.tagView, function(it) { return it.objectName === "tagged" }, []).length === 3 }, 1000)
      var rows = all(view.tagView, function(it) { return it.objectName === "tagged" }, [])
      var bread = rows.filter(function(r) { return r.modelData.type === "bullet" })[0]
      mouseClick(bread, bread.width - 20, bread.height / 2)
      tryVerify(function() { return view.page && view.page.title === "Groceries" }, 2000, "its page")
      tryVerify(function() { return e.focusUid !== "" && e.typeOf(e.focusUid) === "bullet" }, 2000, "on the block")
    }

    function test_4_renamed_colored_taken_away() {
      fresh()
      ws.createPage({ parent: "", title: "Chores", blocks: [
        { type: "p", html: "vacuum " + Tags.html("todo") + " " + Tags.html("home"), indent: 0 },
        { type: "table", table: { rows: [["a", Tags.html("todo")]] }, indent: 0 }] })
      var uid = newLine()
      type("dishes #todo ")
      view.commit()
      view.openTag("todo")
      tryVerify(function() { return view.tagView.groups.length === 2 }, 2000)
      compare(view.tagView.blockCount, 3, "a table's cells too")
      // A color: the tag in the view, the sidebar, and the page's text.
      ws.setTagColor("todo", "blue")
      compare(view.tagLook("todo").background, Docs.colorEntry("blue").background[th.dark ? 1 : 0])
      compare(ws.index.tagColors.todo, "blue")
      // Renamed everywhere.
      view.renameTag("#Chores")
      tryCompare(view, "tagShown", "chores", 2000)
      tryVerify(function() { return Workspace.tagList(ws.index).map(function(t) { return t.name }).join() === "chores,home" }, 2000, "renamed on every page")
      compare(ws.index.tagColors.chores, "blue", "its color too")
      verify(view.history.indexOf("tag:todo") < 0, "the history says the new name")
      tryVerify(function() { return view.tagView.blockCount === 3 }, 2000)
      var versions = Object.keys(files.disk).filter(function(p) { return p.indexOf("/Pages/history/") > 0 })
      verify(versions.length >= 2, "each page kept the version before")
      // Taken off every page.
      view.removeTag()
      tryVerify(function() { return Workspace.tagList(ws.index).map(function(t) { return t.name }).join() === "home" }, 2000, "gone")
      var chores = ws.readPageNow(Workspace.pageNamed(ws.index, "Chores"))
      compare(Html.plainText(Workspace.flatten(chores)[0].html), "vacuum #home", "its words, and a space")
      tryVerify(function() { return view.tagView.groups.length === 0 }, 2000)
    }

    // A tile in the color menu that's open.
    function tile(test) {
      var win = root.Window.window.contentItem
      var t = null
      tryVerify(function() { t = find(win, test); return t !== null }, 1000, "the color is on screen")
      wait(250)
      return find(win, test)
    }
    function clickText(text) {
      var win = root.Window.window.contentItem
      var t = null
      tryVerify(function() { t = find(win, function(it) { return it.text === text && it.width > 0 && typeof it.textFormat !== "undefined" }); return t !== null }, 1000, text + " is on screen")
      wait(250)
      mouseClick(find(win, function(it) { return it.text === text && it.width > 0 && typeof it.textFormat !== "undefined" }))
    }
    function sidebarRow(name) {
      var r = null
      tryVerify(function() { r = all(root, function(it) { return it.objectName === "tagRow" && it.modelData && it.modelData.name === name }, [])[0] || null; return r !== null }, 1000, "#" + name + " in the sidebar")
      return r
    }

    function test_6_colors_for_organizing() {
      fresh()
      var e = view.editor
      var uid = newLine()
      type("plan #work/acme and #work and #home ")
      view.commit()
      // A tag inside another takes its color, unless it has its own.
      ws.setTagColor("work", "blue")
      var blue = Docs.colorEntry("blue").background[th.dark ? 1 : 0]
      compare(view.tagLook("work/acme").background, blue, "#work/acme takes #work's color")
      // The page's text is drawn in it at once.
      tryVerify(function() { return e.items[uid].edit.text.toLowerCase().indexOf(blue.toLowerCase()) >= 0 }, 1000, "the tags on the open page, in their color")
      var acme = sidebarRow("work/acme")
      compare(acme.modelData.depth, 1, "under #work in the sidebar")
      compare(String(acme.look.color), String(Qt.color(Docs.colorEntry("blue").text[th.dark ? 1 : 0])))
      // The sidebar's ⋯: its color, there. (The rows are drawn again as colors change.)
      wait(50)
      acme = sidebarRow("work/acme")
      mouseMove(acme, 20, acme.height / 2)
      var more = null
      tryVerify(function() { more = find(acme, function(it) { return it.objectName === "tagMore" }); return more !== null }, 1000, "⋯ on hover")
      mouseClick(more)
      compare(view.tagShown, "", "the ⋯ is its menu, not the tag's blocks")
      clickText("Color")
      mouseClick(tile(function(it) { return it.entry !== undefined && it.entry && it.entry.id === "green" && it.back === false }))
      tryCompare(ws.index.tagColors, "work/acme", "green", 1000)
      compare(view.tagLook("work/acme").background, Docs.colorEntry("green").background[th.dark ? 1 : 0], "its own now")
      compare(view.tagLook("work").background, blue, "and #work's is still blue")
      wait(200)
      // A right-click opens the menu too; Gray takes its own off: #work's again.
      acme = sidebarRow("work/acme")
      mouseClick(acme, 40, acme.height / 2, Qt.RightButton)
      clickText("Color")
      mouseClick(tile(function(it) { return it.entry === null && it.back === false && it.visible }))
      tryVerify(function() { return ws.index.tagColors["work/acme"] === undefined }, 1000)
      compare(view.tagLook("work/acme").background, blue, "back to #work's")
      wait(200)
      // Sorted by color.
      ws.setTagColor("home", "red")
      var sort = named(root, "tagSort")
      mouseClick(sort)
      compare(service.settings.tagSort, "color")
      tryVerify(function() {
        var rows = all(root, function(it) { return it.objectName === "tagRow" }, []).sort(function(a, b) { return a.y - b.y })
        return rows.map(function(r) { return r.modelData.name }).join() === "work,work/acme,home"
      }, 1000, "blue before red")
      mouseClick(sort)
      compare(service.settings.tagSort, "name")
      // The # menu shows each tag in its color.
      newLine()
      type("x #wo")
      tryVerify(function() { return e.mention !== null && e.mentionItems.length > 0 }, 1000)
      compare(e.tagStyle(Tags.href("work")).background, blue)
      keyClick(Qt.Key_Escape)
      // Renamed from the sidebar, with a page open: the page shows the new name.
      var homeRow = sidebarRow("home")
      mouseClick(homeRow, 40, homeRow.height / 2, Qt.RightButton)
      clickText("Rename\u2026")
      var field = null
      tryVerify(function() { field = named(root.Window.window.contentItem, "tagName"); return field !== null }, 1000)
      wait(200)
      field.text = "#house"
      keyClick(Qt.Key_Return)
      tryVerify(function() { return Tags.inHtml(htmlOf(uid)).map(function(t) { return t.name }).indexOf("house") >= 0 }, 2000, "the open page has the new name")
      compare(ws.index.tagColors.house, "red", "and its color")
    }

    function test_5_found_with_ctrl_p() {
      fresh()
      newLine()
      type("call #dentist ")
      view.commit()
      view.openFind()
      var qf = find(root.Window.window.contentItem, function(it) { return it.placeholder === "Search your pages" })
      tryVerify(function() { return find(root.Window.window.contentItem, function(it) { return it.placeholder === "Search your pages" }) !== null }, 1000)
      type("#den")
      tryVerify(function() { return find(root.Window.window.contentItem, function(it) { return it.text === "#dentist" && typeof it.textFormat !== "undefined" }) !== null }, 1000, "the tag first")
      keyClick(Qt.Key_Return)
      tryCompare(view, "tagShown", "dentist", 1000)
    }
  }
}
