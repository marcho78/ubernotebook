import QtQuick
import QtTest
import "../../app"

// Grey text easy to read, and a step below the text, on every opaque
// background it's drawn on (the page, the sidebar, cards and popovers, a
// raised row): secondary (muted) 80% of the text's contrast there, at most
// 8:1, the faintest 62%, at most 6:1; never fainter than they were (42% /
// 68% of the way to the page).
Item {
  Theme { id: th }

  TestCase {
    name: "Theme"

    function check(name) {
      var text = th.leastContrast(th.text), muted = th.leastContrast(th.muted), faint = th.leastContrast(th.faint)
      var bg = th.background
      verify(muted >= Math.min(8, text * 0.8) - 0.05, name + ": muted " + muted.toFixed(2) + " of text " + text.toFixed(2))
      verify(faint >= Math.min(6, text * 0.62) - 0.05, name + ": faint " + faint.toFixed(2))
      // A step: text, then muted, then faint, each one you can tell apart.
      verify(text - muted >= Math.min(1, text * 0.1), name + ": text " + text.toFixed(2) + " muted " + muted.toFixed(2))
      verify(muted - faint >= Math.min(1, muted * 0.1) - 0.05, name + ": muted " + muted.toFixed(2) + " faint " + faint.toFixed(2))
      // Never fainter than before.
      verify(th.contrast(th.muted, bg) >= th.contrast(th.mix(th.text, bg, 0.42), bg) - 0.01, name)
      verify(th.contrast(th.faint, bg) >= th.contrast(th.mix(th.text, bg, 0.68), bg) - 0.01, name)
    }

    function test_grey_text_readable_and_a_step_below_on_every_theme() {
      // [background, text]: Hackerman, Tokyo Night, Gruvbox, Rose Pine,
      // Catppuccin Latte, Everforest, white, a custom pair.
      var themes = [["#0B0C16", "#ddf7ff"], ["#1a1b26", "#c0caf5"], ["#282828", "#d4be98"], ["#faf4ed", "#575279"],
        ["#eff1f5", "#4c4f69"], ["#2d353b", "#d3c6aa"], ["#ffffff", "#000000"], ["#202020", "#9a9a9a"]]
      for (var i = 0; i < themes.length; i++) {
        th.baseBackground = themes[i][0]
        th.baseForeground = themes[i][1]
        check(themes[i].join(" on "))
      }
      // Hackerman: faint well up from 2.7:1 on the page, to 6:1 everywhere.
      th.baseBackground = "#0B0C16"
      th.baseForeground = "#ddf7ff"
      verify(th.leastContrast(th.faint) >= 5.95 && th.leastContrast(th.muted) >= 7.95)
      // Colors of your own count: a grey card between a black page and white
      // text (it was faint 1.3:1 on it), a dark card, a sidebar of your own.
      th.pageColor = "#000000"
      th.textColor = "#ffffff"
      th.cardColor = "#767676"
      check("a grey card")
      verify(th.contrast(th.faint, th.surface) >= 2.75, "faint on the grey card: " + th.contrast(th.faint, th.surface).toFixed(2))
      th.cardColor = "#1c1c1c"
      check("a dark card")
      th.sidebarColor = "#2a3a4a"
      check("a sidebar of your own")
      th.cardColor = ""
      th.sidebarColor = ""
      th.pageColor = "#f5f0e6"
      th.textColor = "#3c3c3c"
      check("a page of your own")
      th.pageColor = ""
      th.textColor = ""
    }
  }
}
