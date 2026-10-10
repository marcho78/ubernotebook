import QtQuick
import "../Dates.js" as Dates

// The colors and fonts of everything around the notebook: the desk it lies
// on, the bars, the popovers. They come from the Omarchy theme (its
// background, foreground and accent), so the desk changes with your theme;
// the paper keeps its own colors (Papers.js). Settings → Appearance can put
// colors of your own over four of them: the sidebar, the page (and desk),
// the sections and cards, and the text ("" follows the theme).
QtObject {
  id: theme

  // The clock times are shown with (Settings: Clock, "12" or "24"). What
  // shows a time reads twelveHour, so it's drawn again when it changes; the
  // shared Dates.js is told first.
  property string clockSetting: "12"
  readonly property bool twelveHour: { var t = clockSetting !== "24"; Dates.setTwelveHour(t); return t }

  // The Omarchy theme's.
  property color baseBackground: "#1a1b26"
  property color baseForeground: "#c0caf5"
  property color accent: "#7aa2f7"
  property color urgent: "#f7768e"

  // Your own (hex, or "" for the theme's).
  property string pageColor: ""
  property string textColor: ""
  property string sidebarColor: ""
  property string cardColor: ""
  function own(value) { return /^#[0-9a-fA-F]{6}$/.test(String(value || "")) }

  readonly property color background: own(pageColor) ? pageColor : baseBackground
  readonly property color foreground: own(textColor) ? textColor : baseForeground

  readonly property bool dark: luminance(background) < 0.5
  // The sidebar: a shade of the page, or your own.
  readonly property color sidebar: own(sidebarColor) ? sidebarColor : (dark ? Qt.darker(background, 1.12) : Qt.darker(background, 1.035))
  // Sections and cards: shown as cards (the sidebar's sections) only once
  // they have a color of their own.
  readonly property bool cardsShown: own(cardColor)
  // (As a color, to mix: a color written as text has no .r .g .b.)
  readonly property color card: cardsShown ? cardColor : "#000000"

  // The desk, with a little light in the middle.
  readonly property color desk: background
  readonly property color deskLight: mix(background, foreground, dark ? 0.045 : 0.03)
  readonly property color text: foreground
  // Grey text: easy to read, and still a step below the text, on every
  // opaque background it's drawn on (the page, the sidebar, popovers and
  // cards, a raised row: `fills`). Secondary text gets 80% of the contrast
  // the text has there (at most 8:1), the faintest (hints, dates, a model's
  // description) 62% (at most 6:1); never fainter than the 42% / 68% of the
  // way to the page they once were. (A hovered or selected row's see-through
  // tint lowers them a little, as it does the text.)
  readonly property real textContrast: leastContrast(foreground)
  readonly property color muted: mix(foreground, background, toward(foreground, background, Math.min(8, textContrast * 0.8), 0.42))
  readonly property color faint: mix(foreground, background, toward(foreground, background, Math.min(6, textContrast * 0.62), 0.68))
  readonly property color line: Qt.alpha(foreground, dark ? 0.1 : 0.14)
  // Bars and popovers.
  readonly property color surface: cardsShown ? card : mix(background, foreground, dark ? 0.075 : 0.035)
  readonly property color surfaceHigh: cardsShown ? mix(card, foreground, 0.06) : mix(background, foreground, dark ? 0.13 : 0.08)
  readonly property color hover: Qt.alpha(foreground, dark ? 0.08 : 0.07)
  readonly property color pressed: Qt.alpha(foreground, dark ? 0.15 : 0.13)
  readonly property color accentSoft: Qt.alpha(accent, 0.18)
  readonly property color onAccent: luminance(accent) > 0.55 ? "#15161a" : "#ffffff"
  readonly property color shadow: Qt.rgba(0, 0, 0, dark ? 0.55 : 0.28)

  // Fonts. The UI reads like the rest of a modern desktop; icons are the Nerd
  // Font Omarchy ships; the bundled fonts give the notebook its hand.
  readonly property string uiFont: first(["Adwaita Sans", "Inter", "Noto Sans"], "sans-serif")
  readonly property string iconFont: first(["JetBrainsMono Nerd Font", "JetBrainsMono NF", "Symbols Nerd Font"], "monospace")
  readonly property string monoFont: first(["iA Writer Mono S", "JetBrainsMono Nerd Font", "Noto Sans Mono"], "monospace")
  readonly property string markerFont: "Permanent Marker"
  readonly property string handFont: "Caveat"
  readonly property string printFont: "Patrick Hand"
  readonly property string serifFont: first(["Lora", "Noto Serif"], "serif")
  readonly property string typewriterFont: "Special Elite"
  readonly property var coverFonts: ({ marker: markerFont, hand: handFont, serif: serifFont, typewriter: typewriterFont })

  // Bumped when the bundled fonts finish loading, so bindings look again.
  property int fontsVersion: 0

  function first(list, fallback) {
    var have = Qt.fontFamilies()
    for (var i = 0; i < list.length; i++) if (have.indexOf(list[i]) >= 0) return list[i]
    return fallback
  }

  // The family a pen writes in (Papers.PENS), the first one installed.
  function penFamily(families) {
    var v = fontsVersion
    return first(families || [], uiFont)
  }

  function luminance(c) {
    return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b
  }

  // WCAG's contrast between two colors (1 to 21).
  function lit(v) { return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4) }
  function relativeLuminance(c) { return 0.2126 * lit(c.r) + 0.7152 * lit(c.g) + 0.0722 * lit(c.b) }
  function contrast(a, b) {
    var x = relativeLuminance(a), y = relativeLuminance(b)
    return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05)
  }
  // The opaque backgrounds grey text is drawn on.
  readonly property var fills: [background, sidebar, surface, surfaceHigh]
  // Its contrast on the one of them it reads least well on.
  function leastContrast(c) {
    var least = 21
    for (var i = 0; i < fills.length; i++) least = Math.min(least, contrast(c, fills[i]))
    return least
  }
  // How far from `fg` toward `bg` (0 to `most`) a color can go and still have
  // `ratio` on every one of `fills`; 0 when even `fg` hasn't (the text's own
  // color).
  function toward(fg, bg, ratio, most) {
    if (leastContrast(mix(fg, bg, most)) >= ratio) return most
    var lo = 0, hi = most
    for (var i = 0; i < 24; i++) {
      var m = (lo + hi) / 2
      if (leastContrast(mix(fg, bg, m)) >= ratio) lo = m
      else hi = m
    }
    return lo
  }

  function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
  }

  // Glyphs from the Nerd Font (Material Design icons).
  readonly property var icons: ({
    back: "\u{f004d}", shelf: "\u{f125f}", terminal: "\u{f018d}", print: "\u{f042a}", word: "\u{f022c}", markdown: "\u{f0354}", notebook: "\u{f082e}", notebookPlus: "\u{f1612}",
    left: "\u{f0141}", right: "\u{f0142}", down: "\u{f0140}", plus: "\u{f0415}", close: "\u{f0156}",
    search: "\u{f0349}", pages: "\u{f0836}", more: "\u{f01d8}", cog: "\u{f08bb}",
    undo: "\u{f054c}", redo: "\u{f044e}",
    bold: "\u{f0264}", italic: "\u{f0277}", underline: "\u{f0287}", strike: "\u{f0281}",
    ink: "\u{f069e}", highlight: "\u{f0e31}", marker: "\u{f0652}", font: "\u{f06d6}", size: "\u{f027f}",
    bullets: "\u{f0279}", numbers: "\u{f027b}", checks: "\u{f0756}",
    h1: "\u{f026b}", h2: "\u{f026c}", h3: "\u{f026d}", text: "\u{f0284}", quote: "\u{f0757}", code: "\u{f0169}",
    note: "\u{f039b}", divider: "\u{f0374}", image: "\u{f0976}", link: "\u{f0339}", unlink: "\u{f033a}",
    alignLeft: "\u{f0262}", alignCenter: "\u{f0260}", alignRight: "\u{f0263}", alignJustify: "\u{f0261}",
    indent: "\u{f0276}", outdent: "\u{f0275}", clear: "\u{f0265}",
    paper: "\u{f09ee}", grid: "\u{f02c1}", dots: "\u{f15fc}", trash: "\u{f0a7a}", tag: "\u{f04fc}",
    bookmark: "\u{f00c0}", export: "\u{f0b93}", copy: "\u{f018f}", download: "\u{f01da}", folder: "\u{f0256}", check: "\u{f012c}",
    zoomIn: "\u{f06ed}", zoomOut: "\u{f06ec}", pen: "\u{f03eb}", calendar: "\u{f00f6}", history: "\u{f02da}",
    volume: "\u{f057e}", keyboard: "\u{f097b}", info: "\u{f02fd}", help: "\u{f0625}", sticky: "\u{f1782}", drag: "\u{f01dd}",
    open: "\u{f05da}", up: "\u{f005d}", eraser: "\u{f01fe}",
    // Page templates, and the planner blocks.
    page: "\u{f0224}", templates: "\u{f0a1d}", calendarWeek: "\u{f0a33}", calendarMonth: "\u{f0e18}",
    journal: "\u{f14e7}", habits: "\u{f00ef}", people: "\u{f0849}", school: "\u{f0474}", project: "\u{f14de}",
    book: "\u{f14f7}", recipe: "\u{f0b7c}", bag: "\u{f158b}", time: "\u{f0150}", habit: "\u{f0456}",
    // Pages.
    toggle: "\u{f035f}", toc: "\u{f0836}", emoji: "\u{f01f2}", cover: "\u{f02eb}", linkTo: "\u{f005c}",
    move: "\u{f1031}", sidebar: "\u{f06fd}", restore: "\u{f099b}", deleteForever: "\u{f0b89}",
    textColor: "\u{f069e}", palette: "\u{f0e0c}", newPage: "\u{f1a9e}", width: "\u{f084e}",
    tree: "\u{f13d2}", random: "\u{f049f}", hideSidebar: "\u{f013d}", forward: "\u{f0054}", swap: "\u{f04e1}",
    columns: "\u{f056d}", star: "\u{f04ce}", starOutline: "\u{f04d2}", lock: "\u{f033e}", unlock: "\u{f0fc7}", bell: "\u{f009a}",
    duplicate: "\u{f0191}", toPage: "\u{f0ab9}", agent: "\u{f06a9}", mindmap: "\u{f0645}",
    table: "\u{f04eb}", rowAbove: "\u{f04f4}", rowBelow: "\u{f04f3}", rowRemove: "\u{f04f5}",
    colLeft: "\u{f04ed}", colRight: "\u{f04ec}", colRemove: "\u{f04ee}", header: "\u{f121d}",
    arrowUp: "\u{f005d}", send: "\u{f048a}", arrowDown: "\u{f0045}", arrowLeft: "\u{f004d}", arrowRight: "\u{f0054}",
    sketch: "\u{f0f49}", eraser: "\u{f01fe}",
    archive: "\u{f120e}", unarchive: "\u{f125c}", briefcase: "\u{f0814}",
    // Audio notes and dictation.
    mic: "\u{f036c}", dictate: "\u{f036c}", micOff: "\u{f036d}", play: "\u{f040a}", pause: "\u{f03e4}",
    stop: "\u{f04db}", record: "\u{f044a}", waveform: "\u{f147d}", transcript: "\u{f09ed}",
    // Files, links, boards, buttons, synced blocks.
    attach: "\u{f0066}", library: "\u{f0331}", person: "\u{f0004}", contacts: "\u{f06cb}", mail: "\u{f01ee}", phone: "\u{f03f2}", web: "\u{f059f}", place: "\u{f034e}", cake: "\u{f00eb}", pdf: "\u{f0226}", video: "\u{f0567}", board: "\u{f0564}", button: "\u{f0a1e}", synced: "\u{f04e6}",
    fileDoc: "\u{f0219}", fileZip: "\u{f05c4}", fileSheet: "\u{f021b}", fileSlides: "\u{f0227}", fileCode: "\u{f022e}", fileMusic: "\u{f0223}", fileImage: "\u{f021f}",
    openExternal: "\u{f03cc}", refresh: "\u{f0450}", unsync: "\u{f04e7}", edit: "\u{f03eb}",
    // What's in the sidebar.
    eye: "\u{f0208}", eyeOff: "\u{f0209}", tune: "\u{f062e}",
    // Equations, diagrams, footnotes.
    equation: "\u{f0871}", inlineEquation: "\u{f0784}", diagram: "\u{f199c}", decision: "\u{f0641}",
    network: "\u{f0317}", system: "\u{f048d}", footnote: "\u{f0283}",
    expand: "\u{f004c}", fitScreen: "\u{f18f5}"
  })
}
