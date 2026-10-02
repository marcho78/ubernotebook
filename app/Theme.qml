import QtQuick

// The colors and fonts of everything around the notebook: the desk it lies
// on, the bars, the popovers. They come from the Omarchy theme (its
// background, foreground and accent), so the desk changes with your theme;
// the paper keeps its own colors (Papers.js).
QtObject {
  id: theme

  property color background: "#1a1b26"
  property color foreground: "#c0caf5"
  property color accent: "#7aa2f7"
  property color urgent: "#f7768e"

  readonly property bool dark: luminance(background) < 0.5

  // The desk, with a little light in the middle.
  readonly property color desk: background
  readonly property color deskLight: mix(background, foreground, dark ? 0.045 : 0.03)
  readonly property color text: foreground
  readonly property color muted: mix(foreground, background, 0.42)
  readonly property color faint: mix(foreground, background, 0.68)
  readonly property color line: Qt.alpha(foreground, dark ? 0.1 : 0.14)
  // Bars and popovers.
  readonly property color surface: mix(background, foreground, dark ? 0.075 : 0.035)
  readonly property color surfaceHigh: mix(background, foreground, dark ? 0.13 : 0.08)
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

  function mix(a, b, t) {
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1)
  }

  // Glyphs from the Nerd Font (Material Design icons).
  readonly property var icons: ({
    back: "\u{f004d}", shelf: "\u{f125f}", notebook: "\u{f082e}", notebookPlus: "\u{f1612}",
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
    bookmark: "\u{f00c0}", export: "\u{f0b93}", copy: "\u{f018f}", folder: "\u{f0256}", check: "\u{f012c}",
    zoomIn: "\u{f06ed}", zoomOut: "\u{f06ec}", pen: "\u{f03eb}", calendar: "\u{f00f6}", history: "\u{f02da}",
    volume: "\u{f057e}", keyboard: "\u{f097b}", info: "\u{f02fd}", sticky: "\u{f1782}", drag: "\u{f01dd}",
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
    columns: "\u{f056d}", star: "\u{f04ce}", starOutline: "\u{f04d2}", lock: "\u{f033e}", unlock: "\u{f0fc7}",
    duplicate: "\u{f0191}", toPage: "\u{f0ab9}", agent: "\u{f06a9}", mindmap: "\u{f0645}",
    table: "\u{f04eb}", rowAbove: "\u{f04f4}", rowBelow: "\u{f04f3}", rowRemove: "\u{f04f5}",
    colLeft: "\u{f04ed}", colRight: "\u{f04ec}", colRemove: "\u{f04ee}", header: "\u{f121d}",
    arrowUp: "\u{f005d}", arrowDown: "\u{f0045}", arrowLeft: "\u{f004d}", arrowRight: "\u{f0054}",
    sketch: "\u{f0f49}", eraser: "\u{f01fe}",
    archive: "\u{f120e}", unarchive: "\u{f125c}", briefcase: "\u{f0814}"
  })
}
