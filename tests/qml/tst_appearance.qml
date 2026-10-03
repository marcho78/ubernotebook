import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"

// Appearance (Settings): the sidebar, the page, the sections and cards and
// the text in colors of your own over the theme's; picked with the color
// picker (shown as it's picked, kept with Apply, put back with Esc);
// reset; the sidebar's sections as cards; a warning when text won't read.
Item {
  id: root
  width: 1320
  height: 900

  FakeStore { id: store }
  FakeService { id: service; store: store; user: ({ sounds: false }) }
  FakeFiles { id: files }
  UberNotebook.Workspace { id: ws; files: files }

  App {
    id: app
    anchors.fill: parent
    store: store
    workspace: ws
    service: service
    background: "#eeeae2"
    foreground: "#2b2a28"
    accent: "#c05a36"
  }

  Theme { id: plain; baseBackground: "#101010"; baseForeground: "#eeeeee" }

  TestCase {
    name: "Appearance"
    when: windowShown

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
    function hex(c) { return String(c).toLowerCase() }
    function type(text) {
      for (var i = 0; i < text.length; i++) {
        var ch = text.charAt(i)
        if (ch === "#") keyClick(Qt.Key_NumberSign)
        else keyClick(ch)
      }
    }
    function sidebar() { return find(app, function(it) { return String(it).indexOf("DocSidebar") === 0 }) }
    function cards() { return findAll(sidebar(), function(it) { return it.objectName === "sectionCard" }, []) }

    function test_1_the_theme_with_colors_of_your_own() {
      compare(hex(plain.background), "#101010")
      verify(plain.dark)
      verify(!plain.cardsShown)
      plain.pageColor = "#fafafa"
      plain.textColor = "#222222"
      plain.sidebarColor = "#ececec"
      plain.cardColor = "#ffffff"
      compare(hex(plain.background), "#fafafa")
      compare(hex(plain.foreground), "#222222")
      compare(hex(plain.text), "#222222")
      verify(!plain.dark, "light now: the rest follows")
      compare(hex(plain.sidebar), "#ececec")
      verify(plain.cardsShown)
      compare(hex(plain.surface), "#ffffff")
      verify(plain.surfaceHigh.r > 0.8 && plain.surfaceHigh.r < 1, "a shade of the card, not black: " + plain.surfaceHigh)
      plain.pageColor = "red"
      compare(hex(plain.background), "#101010", "not a hex: the theme's")
      plain.pageColor = ""
      plain.textColor = ""
      plain.sidebarColor = ""
      plain.cardColor = ""
    }

    function test_2_the_sidebar_and_its_sections() {
      app.showSpace("pages")
      tryVerify(function() { return sidebar() !== null }, 2000)
      compare(hex(sidebar().color), hex(app.theme.sidebar))
      compare(cards().length, 0, "no cards until they have a color")
      service.setSetting("colorSidebar", "#223344")
      tryVerify(function() { return hex(sidebar().color) === "#223344" }, 1000)
      service.setSetting("colorCards", "#334455")
      tryVerify(function() { return cards().length >= 3 }, 1000, "sections as cards")
      compare(hex(cards()[0].color), "#334455")
      service.setSetting("colorPage", "#1b1d22")
      tryVerify(function() { return hex(app.theme.background) === "#1b1d22" && app.theme.dark }, 1000)
      service.setSetting("colorText", "#d8dee9")
      tryVerify(function() { return hex(app.theme.text) === "#d8dee9" }, 1000)
      ;["colorSidebar", "colorCards", "colorPage", "colorText"].forEach(function(k) { service.setSetting(k, "") })
      tryVerify(function() { return hex(app.theme.background) === "#eeeae2" && cards().length === 0 }, 1000)
    }

    function test_3_picked_in_settings() {
      app.openSettings("appearance")
      var swatch = null
      tryVerify(function() { swatch = named(win(), "appearanceSwatch_colorPage"); return swatch !== null }, 2000)
      wait(200)
      mouseClick(swatch)
      // (The picker's a popup: what typing in it does is what's checked.)
      wait(250)
      // Typed: shown at once; Enter keeps it.
      keyClick(Qt.Key_A, Qt.ControlModifier)
      type("#f5f0e6")
      tryVerify(function() { return service.settings.colorPage === "#f5f0e6" && hex(app.theme.background) === "#f5f0e6" }, 1000, "shown as it's picked")
      keyClick(Qt.Key_Return)
      wait(150)
      compare(service.settings.colorPage, "#f5f0e6")
      verify(String(service.settings.recentColors).indexOf("#f5f0e6") === 0, "remembered")
      // Again, then Esc: as it was.
      swatch = named(win(), "appearanceSwatch_colorPage")
      mouseClick(swatch)
      wait(150)
      keyClick(Qt.Key_A, Qt.ControlModifier)
      type("#000000")
      tryVerify(function() { return service.settings.colorPage === "#000000" }, 1000)
      keyClick(Qt.Key_Escape)
      tryVerify(function() { return service.settings.colorPage === "#f5f0e6" }, 1000, "put back")
      // Text that won't read: said so.
      service.setSetting("colorText", "#e8e4dc")
      tryVerify(function() { return find(win(), function(it) { return it.text !== undefined && String(it.text).indexOf("Text is hard to read on it") >= 0 }) !== null }, 1000)
      // Reset; all back.
      var reset = named(win(), "appearanceReset_colorPage")
      verify(reset !== null)
      mouseClick(reset)
      tryVerify(function() { return service.settings.colorPage === "" }, 1000)
      mouseClick(named(win(), "appearanceResetAll"))
      tryVerify(function() { return service.settings.colorText === "" }, 1000)
    }
  }
}
