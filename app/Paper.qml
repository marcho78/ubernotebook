import QtQuick

// A sheet of paper: its color and grain, and the pattern printed on it, drawn
// by shaders/paper.frag so the lines stay crisp at any zoom. `look` is a
// resolved paper (Papers.resolve); rows start at `originY` and move with
// `scroll`, so the pattern scrolls with the writing. The rule under the
// title sits one row above the first row's.
ShaderEffect {
  id: paper

  property var look: ({})
  property real originY: 0
  property real scrollOffset: 0
  property real marginLine: 0
  property real gridOrigin: 0

  readonly property size size: Qt.size(width, height)
  readonly property real pitch: look.pitch || 30
  // A rule's center a pixel under the baseline (4/5 down the row), on a
  // pixel's center so it's drawn one pixel wide.
  readonly property real rule: Math.floor(pitch * 0.8) + 1.5
  readonly property real marginX: Math.round(look.hasMargin ? marginLine : gridOrigin) + 0.5
  readonly property real pattern: look.shader !== undefined ? look.shader : 1
  readonly property real lineWidth: 1
  readonly property real grain: look.grain !== undefined ? look.grain : 0.8
  readonly property real fiber: look.fiber || 0
  readonly property real dpr: Screen.devicePixelRatio || 1
  readonly property real scroll: scrollOffset
  readonly property color paper: look.paper || "#fbf6e9"
  readonly property color lineColor: Qt.alpha(look.line || "#7d9cc4", look.lineAlpha !== undefined ? look.lineAlpha : 0.45)
  readonly property color marginColor: Qt.alpha(look.margin || "#df8f8f", look.hasMargin ? (look.marginAlpha || 0.7) : 0)
  // The rule under the title: a little stronger than the others.
  readonly property color headColor: Qt.alpha(look.line || "#7d9cc4", look.headRule ? Math.min(1, (look.lineAlpha || 0.45) * 1.6) : 0)

  fragmentShader: Qt.resolvedUrl("../shaders/paper.frag.qsb")
}
