import QtQuick
import QtTest
import "../../app"

// Grey text easy to read on any theme: secondary (muted) at least 8:1 on
// every background it's drawn on (the page, the sidebar, cards and popovers,
// a raised row), the faintest at least 6:1 (or the text's own color, when
// even that hasn't), each a step below the text where there's room, and
// never fainter than they were (42% / 68% of the way).
Item {
  Theme { id: th }

  TestCase {
    name: "Theme"

    function test_grey_text_readable_on_every_theme() {
      // [background, text]: Hackerman, Tokyo Night, Gruvbox, Rose Pine,
      // Catppuccin Latte, white, a custom pair.
      var themes = [["#0B0C16", "#ddf7ff"], ["#1a1b26", "#c0caf5"], ["#282828", "#d4be98"], ["#faf4ed", "#575279"],
        ["#eff1f5", "#4c4f69"], ["#ffffff", "#000000"], ["#202020", "#7a7a7a"]]
      for (var i = 0; i < themes.length; i++) {
        th.baseBackground = themes[i][0]
        th.baseForeground = themes[i][1]
        var bg = th.background, text = th.leastContrast(th.text)
        var muted = th.leastContrast(th.muted), faint = th.leastContrast(th.faint)
        var name = themes[i].join(" on ")
        verify(muted >= Math.min(8, text) - 0.05, name + ": muted " + muted.toFixed(2))
        verify(faint >= Math.min(6, text) - 0.05, name + ": faint " + faint.toFixed(2))
        verify(muted >= faint - 0.01 && text >= muted - 0.01, name + ": text, then muted, then faint")
        // Never fainter than before.
        verify(muted >= th.contrast(th.mix(th.text, bg, 0.42), bg) - 0.01, name)
        verify(faint >= th.contrast(th.mix(th.text, bg, 0.68), bg) - 0.01, name)
      }
      // Under a selected or hovered row, and an accent-tinted one (Codex's
      // white-theme case: a selected sidebar row): each grey on the blend
      // that shows, at its target or as near as the text itself gets.
      th.baseBackground = "#ffffff"
      th.baseForeground = "#000000"
      var under = [th.mix(th.sidebar, th.foreground, th.pressed.a), th.mix(th.surface, th.foreground, th.hover.a), th.mix(th.surface, th.accent, th.accentSoft.a),
        th.mix(th.surfaceHigh, th.foreground, th.pressed.a)]
      for (var u = 0; u < under.length; u++) {
        var best = th.contrast(th.text, under[u])
        verify(th.contrast(th.muted, under[u]) >= Math.min(8, best) - 0.05, "muted on a row: " + th.contrast(th.muted, under[u]).toFixed(2))
        verify(th.contrast(th.faint, under[u]) >= Math.min(6, best) - 0.05, "faint on a row: " + th.contrast(th.faint, under[u]).toFixed(2))
      }
      // Hackerman: faint well up from 2.7:1, still below its muted and text.
      th.baseBackground = "#0B0C16"
      th.baseForeground = "#ddf7ff"
      verify(th.contrast(th.faint, th.background) < th.contrast(th.muted, th.background) - 1, "a step between them")
      // On every background it's drawn on, not the page's alone: a grey card
      // between a black page and white text (Codex's case) gets the best
      // there is, the text's own color, not a grey that reads 1.3:1 on it.
      th.pageColor = "#000000"
      th.textColor = "#ffffff"
      th.cardColor = "#767676"
      verify(th.contrast(th.faint, th.surface) >= th.contrast(th.text, th.surface) - 0.01, "faint on the card: " + th.contrast(th.faint, th.surface).toFixed(2))
      verify(th.contrast(th.muted, th.surface) >= th.contrast(th.text, th.surface) - 0.01)
      th.cardColor = "#1c1c1c"
      verify(th.contrast(th.faint, th.surface) >= 5.95 && th.contrast(th.faint, th.sidebar) >= 5.95 && th.contrast(th.faint, th.background) >= 5.95)
      th.sidebarColor = "#2a3a4a"
      verify(th.contrast(th.muted, th.sidebar) >= 7.95, "a sidebar of your own: " + th.contrast(th.muted, th.sidebar).toFixed(2))
      th.cardColor = ""
      th.sidebarColor = ""
      // Your own page color counts, as the theme's does.
      th.pageColor = "#f5f0e6"
      th.textColor = "#3c3c3c"
      verify(th.contrast(th.faint, th.background) >= 5.95)
      th.pageColor = ""
      th.textColor = ""
    }
  }
}
