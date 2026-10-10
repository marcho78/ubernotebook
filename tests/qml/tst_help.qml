import QtQuick
import QtTest
import "../../app"
import "../../Help.js" as Help

// Help: it opens on Start here; a section a click away; the words typed
// find their rows, in every section; Esc empties the search, then closes.
Item {
  id: root
  width: 1200
  height: 820

  Theme { id: th }
  HelpPanel { id: help; theme: th; parent: root }

  TestCase {
    name: "Help"
    when: windowShown

    function find(item, test, out) {
      if (!item) return out
      if (item.visible && test(item)) out.push(item)
      var kids = item.children || []
      for (var i = 0; i < kids.length; i++) find(kids[i], test, out)
      return out
    }
    function named(name) { var r = find(help.contentItem, function(it) { return it.objectName === name }, []); return r.length ? r[0] : null }
    function rows() { return find(help.contentItem, function(it) { return it.objectName === "helpRow" }, []) }
    function title() { return named("helpTitle").text }

    function test_1_sections_search_and_close() {
      help.open()
      tryVerify(function() { return help.opened }, 1000)
      compare(title(), "Start here")
      compare(rows().length, Help.SECTIONS[0].groups[0].rows.length, "its rows, each")
      // Another section, a click away.
      mouseClick(named("helpSection_keys"))
      tryCompare(help, "section", "keys")
      compare(title(), "Keyboard")
      verify(rows().length > 100, "every key: " + rows().length)
      // Words typed: found, wherever they are.
      var field = named("helpSearch")
      field.text = "remind me"
      field.edited("remind me")
      tryVerify(function() { return /found for/.test(title()) }, 1000, title())
      verify(rows().length === Help.find("remind me").length, rows().length + " rows")
      field.text = "zzzz-nothing"
      field.edited("zzzz-nothing")
      compare(title(), "Nothing found")
      compare(rows().length, 0)
      // Esc: the search emptied; again, closed.
      field.escaped()
      compare(help.query, "")
      compare(title(), "Keyboard")
      field.escaped()
      tryVerify(function() { return !help.visible }, 1000, "closed")
    }

    // Only plain text: nothing in it is a link or markup that does anything.
    function test_2_plain_text_only() {
      help.openAt("terminal")
      tryVerify(function() { return help.opened }, 1000)
      var texts = find(help.contentItem, function(it) { return it.textFormat !== undefined && it.text !== undefined && typeof it.text === "string" && it.text !== "" }, [])
      verify(texts.length > 20)
      for (var i = 0; i < texts.length; i++) compare(texts[i].textFormat, Text.PlainText, texts[i].text.slice(0, 40))
      help.close()
      tryVerify(function() { return !help.visible }, 1000)
    }
  }
}
