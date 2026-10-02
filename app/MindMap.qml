import QtQuick
import QtQuick.Shapes
import "../Mindmap.js" as Mindmap
import "../Docs.js" as Docs
import "../Colors.js" as Colors

// A mind map on a page in Pages: the topic in the middle, its ideas branching
// out to both sides (or all to the right, when that fits better), each branch
// in a color of its own. Click an idea to write on it: Enter adds the next
// idea beside it, Tab one branching from it, Shift+Tab moves it out a level,
// ↑ ↓ go to the ideas above and below, Backspace on an empty idea takes it
// away, Ctrl+Backspace takes an idea and its branch, Esc (or a click
// elsewhere) stops. The circle at an idea's end folds its branch away (and
// says how many ideas are folded). Everything changed while writing is one
// step to undo. The color button over the idea you're writing on gives it a
// text color and a background (a main idea's color is its branch's). A
// locked page's map only folds.
Item {
  id: map

  property var editor: null
  property string uid: ""
  property string outline: ""
  property string folds: ""
  property real available: 600
  readonly property bool readOnly: editor ? editor.readOnly : false
  // The ideas' text color, when they have none of their own (the block's).
  property color ink: editor ? editor.ink : "black"

  // While writing: a copy of the map being changed (saved when you stop),
  // and the idea you're on.
  property bool editing: false
  property var draft: null
  property var current: null
  property bool switching: false
  // The color picker is open for the idea you're on: writing goes on.
  property bool picking: false

  readonly property var tree: Mindmap.applyFolds(Mindmap.parse(outline), folds)
  property var lay: ({ nodes: [], edges: [], width: 0, height: 0, scale: 1 })

  width: available
  height: Math.max(48, Math.ceil(lay.height * lay.scale))

  onTreeChanged: if (!editing) relayout()
  onAvailableChanged: relayout()
  Component.onCompleted: relayout()

  // ---- how it looks ---------------------------------------------------------------------------

  readonly property var branchColors: ["blue", "green", "orange", "purple", "pink", "red", "yellow", "brown"]
    .map(function(id) { return Docs.colorEntry(id).text[map.editor && map.editor.dark ? 1 : 0] })
  readonly property color rootInk: editor && editor.accent.hslLightness > 0.55 ? "#14161c" : "#ffffff"

  // An idea's color as text or as a background on this page: one of Pages'
  // ("red", in its light or dark shade) or one of your own ("#ff8800").
  function textOf(id) { var c = Docs.colorEntry(id); return c ? c.text[editor.dark ? 1 : 0] : Colors.normalize(id) }
  function backOf(id) { var c = Docs.colorEntry(id); return c ? c.background[editor.dark ? 1 : 0] : Colors.normalize(id) }
  readonly property string paperHex: Colors.normalize(String(editor ? editor.paper : "#ffffff")) || "#ffffff"
  readonly property string inkHex: Colors.normalize(String(ink)) || "#000000"

  // A branch's color: its main idea's (its background's, else its text's,
  // made to show on the page), else the next of branchColors; the topic's
  // is the accent.
  function tint(branch) {
    if (branch < 0) return editor.accent
    var root = editing ? draft : tree
    var main = root && root.children[branch]
    var own = main ? (main.background ? textOf(main.background) : main.color ? textOf(main.color) : "") : ""
    if (own) return Colors.visibleOn(own, paperHex)
    return branchColors[branch % branchColors.length]
  }

  // An idea's fill and its text's color (on a background of its own with no
  // text color of its own, the page's text if it reads there, else dark or
  // light text, whichever reads).
  function fillOf(n, writing, hovered) {
    if (n.node.background) return backOf(n.node.background)
    if (n.depth === 0) return editor.accent
    if (n.depth === 1) return Qt.alpha(tint(n.branch), writing ? 0.26 : 0.16)
    return writing || (hovered && !readOnly) ? Qt.alpha(ink, 0.07) : "transparent"
  }
  function inkOf(node, depth) {
    if (node && node.color) return textOf(node.color)
    if (node && node.background) return Colors.readableOn(backOf(node.background), inkHex)
    if (depth === 0) return rootInk
    return ink
  }

  // The idea you're on, as the color picker sees it: its words, its fill (as
  // it shows on the page), its own text color, and the page's.
  function colorInfo() {
    var e = entryFor(current)
    var fill = paperHex
    if (current.background) fill = backOf(current.background)
    else if (e && e.depth === 0) fill = Colors.normalize(String(editor.accent))
    else if (e && e.depth === 1) fill = Colors.normalize(String(Qt.tint(editor.paper, Qt.alpha(tint(e.branch), 0.16))))
    return { text: current.text || "Idea", fill: fill, ownInk: current.color ? textOf(current.color) : "", pageInk: inkHex }
  }

  // The idea you're writing on in a color (kind "color" or "background"):
  // one of Pages' ("red"), one of yours ("#ff8800"), or "" for none. Saved
  // with the rest when you stop.
  function setIdeaColor(kind, id) {
    previewIdeaColor(kind, id)
    input.forceActiveFocus()
  }

  // The same, while the color picker is open: it shows, the picker keeps the keys.
  function previewIdeaColor(kind, id) {
    if (!editing || !current || (kind !== "color" && kind !== "background")) return
    var value = Mindmap.cleanColor(id)
    if (current[kind] === value) return
    current[kind] = value
    relayout()
  }

  function askColors(anchor) {
    picking = true
    editor.mindMapColorsRequested(uid, anchor)
  }

  // A color picker closed: writing goes on where it was (`refocus`: the
  // picker had the keys), unless you went on to something else.
  function colorsClosed(refocus) {
    picking = false
    if (!editing) return
    if (refocus) input.forceActiveFocus()
    else if (!input.activeFocus) finish()
  }

  function sizeOf(depth) { return depth === 0 ? 17 : depth === 1 ? 15 : 14 }
  function weightOf(depth) { return depth === 0 ? Font.Bold : depth === 1 ? Font.DemiBold : Font.Normal }
  function metrics(depth) { return depth === 0 ? fm0 : depth === 1 ? fm1 : fm2 }
  function padOf(depth) { return depth === 0 ? { x: 18, y: 10 } : depth === 1 ? { x: 12, y: 6 } : { x: 6, y: 4 } }

  FontMetrics { id: fm0; font.family: map.editor.family; font.pixelSize: map.sizeOf(0); font.weight: map.weightOf(0) }
  FontMetrics { id: fm1; font.family: map.editor.family; font.pixelSize: map.sizeOf(1); font.weight: map.weightOf(1) }
  FontMetrics { id: fm2; font.family: map.editor.family; font.pixelSize: map.sizeOf(2); font.weight: map.weightOf(2) }

  function relayout() {
    var root = editing ? draft : tree
    lay = Mindmap.layout(root, {
      advance: function(s, d) { return map.metrics(d).advanceWidth(s) },
      lineHeight: function(d) { return Math.ceil(map.metrics(d).lineSpacing) },
      maxWidth: function(d) { return d === 0 ? 220 : d === 1 ? 190 : 170 },
      pad: function(d) { return map.padOf(d) },
      minWidth: 40,
      gapX: function(d) { return d === 0 ? 46 : 32 },
      gapY: function(d) { return d === 1 ? 14 : 6 },
      margin: 12,
      available: Math.max(200, available)
    })
  }

  function entryFor(n) {
    for (var i = 0; i < lay.nodes.length; i++) if (lay.nodes[i].node === n) return lay.nodes[i]
    return null
  }

  // ---- writing on it ----------------------------------------------------------------------------

  function indexIn(root, n) {
    var at = -1
    var i = 0
    Mindmap.walk(root, function(x) { if (x === n) at = i; i++ })
    return at
  }
  function nodeAt(root, index) {
    var found = null
    var i = 0
    Mindmap.walk(root, function(x) { if (i === index) found = x; i++ })
    return found
  }

  // Starts writing on the idea at `index` (0: the topic).
  function start(index) {
    if (readOnly || !tree) return
    draft = Mindmap.copy(tree)
    editing = true
    choose(nodeAt(draft, index) || draft, true)
  }

  // A click on an idea: writing on it.
  function edit(n) {
    if (readOnly) return
    if (!editing) { start(indexIn(tree, n)); return }
    choose(n, false)
  }

  function choose(n, selectAll) {
    switching = true
    current = n
    relayout()
    input.text = n.text
    input.forceActiveFocus()
    if (selectAll) input.selectAll()
    else input.cursorPosition = input.length
    switching = false
  }

  function count() {
    var total = 0
    Mindmap.walk(draft, function() { total++ })
    return total
  }

  function addChild() {
    if (count() >= Mindmap.MAX_NODES) return
    var c = { text: "", children: [], folded: false }
    current.folded = false
    current.children.push(c)
    choose(c, true)
  }

  function addSibling() {
    var parent = Mindmap.parentOf(draft, current)
    if (!parent) { addChild(); return }
    if (count() >= Mindmap.MAX_NODES) return
    var c = { text: "", children: [], folded: false }
    parent.children.splice(parent.children.indexOf(current) + 1, 0, c)
    choose(c, true)
  }

  function outdent() {
    var parent = Mindmap.parentOf(draft, current)
    var grand = parent ? Mindmap.parentOf(draft, parent) : null
    if (!grand) return
    parent.children.splice(parent.children.indexOf(current), 1)
    grand.children.splice(grand.children.indexOf(parent) + 1, 0, current)
    choose(current, false)
  }

  // The idea goes (with its branch, if `branch`); the one before it is next.
  function remove(branch) {
    var parent = Mindmap.parentOf(draft, current)
    if (!parent || (!branch && current.children.length)) return false
    var i = parent.children.indexOf(current)
    parent.children.splice(i, 1)
    var next = i > 0 ? parent.children[i - 1] : parent
    while (!branch && next !== parent && next.children.length && !next.folded) next = next.children[next.children.length - 1]
    choose(next, false)
    return true
  }

  function step(dir) {
    var i = -1
    for (var k = 0; k < lay.nodes.length; k++) if (lay.nodes[k].node === current) i = k
    var j = i + dir
    if (i >= 0 && j >= 0 && j < lay.nodes.length) choose(lay.nodes[j].node, false)
  }

  // Stops writing: ideas left empty go, and the map is saved (one step).
  function finish() {
    if (!editing) return
    var before = tree ? tree.text : ""
    editing = false
    Mindmap.prune(draft)
    if (!draft.text) draft.text = before || "Mind map"
    var outlineNow = Mindmap.serialize(draft)
    var foldsNow = Mindmap.foldsOf(draft)
    draft = null
    current = null
    editor.setMindMap(uid, outlineNow, foldsNow)
    relayout()
  }

  // Esc: back to writing on the page, after the map.
  function leave() {
    finish()
    var i = editor.indexOf(uid)
    var next = i >= 0 ? editor.textNeighbor(i, 1) : -1
    if (next >= 0) editor.focusBlock(editor.uidAt(next), 0)
  }

  function toggleFold(n) {
    if (editing) {
      n.folded = !n.folded
      relayout()
      input.forceActiveFocus()
      return
    }
    n.folded = !n.folded
    editor.setMindMapFolds(uid, Mindmap.foldsOf(tree))
  }

  function key(e) {
    var ctrl = (e.modifiers & Qt.ControlModifier) !== 0
    var shift = (e.modifiers & Qt.ShiftModifier) !== 0
    if (e.key === Qt.Key_Escape) { e.accepted = true; leave(); return }
    if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && !ctrl) { e.accepted = true; addSibling(); return }
    if (e.key === Qt.Key_Tab && !shift) { e.accepted = true; addChild(); return }
    if (e.key === Qt.Key_Backtab || (e.key === Qt.Key_Tab && shift)) { e.accepted = true; outdent(); return }
    if (e.key === Qt.Key_Up && !ctrl) { e.accepted = true; step(-1); return }
    if (e.key === Qt.Key_Down && !ctrl) { e.accepted = true; step(1); return }
    if (ctrl && (e.key === Qt.Key_Backspace || e.key === Qt.Key_Delete)) { e.accepted = true; remove(true); return }
    if (e.key === Qt.Key_Backspace && input.length === 0 && current !== draft) { e.accepted = true; remove(false); return }
  }

  // ---- drawing it -------------------------------------------------------------------------------

  // A click on the map away from its ideas: writing stops, and the block is picked.
  TapHandler {
    onTapped: {
      // (Not a click on the color picker, over the map.)
      if (map.picking) return
      if (map.editing) map.finish()
      else map.editor.selectBlocks(map.uid, map.uid)
    }
  }

  Item {
    id: canvasArea
    x: Math.max(0, (map.width - map.lay.width * map.lay.scale) / 2)
    width: map.lay.width
    height: map.lay.height
    scale: map.lay.scale
    transformOrigin: Item.TopLeft

    // The branches: a curve from each idea to each of its ideas.
    Repeater {
      model: map.lay.edges.length
      delegate: Shape {
        id: branch
        required property int index
        readonly property var e: map.lay.edges[index]
        readonly property var a: map.lay.nodes[e.from]
        readonly property var b: map.lay.nodes[e.to]
        readonly property bool rightward: b.side > 0
        readonly property real x1: rightward ? a.x + a.w : a.x
        readonly property real y1: a.depth === 0 ? a.y + a.h / 2 : a.anchorY
        readonly property real x2: rightward ? b.x : b.x + b.w
        readonly property real y2: b.anchorY
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: map.tint(branch.b.branch)
          strokeWidth: branch.b.depth === 1 ? 2.6 : 1.8
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          startX: branch.x1
          startY: branch.y1
          PathCubic {
            x: branch.x2
            y: branch.y2
            control1X: (branch.x1 + branch.x2) / 2
            control1Y: branch.y1
            control2X: (branch.x1 + branch.x2) / 2
            control2Y: branch.y2
          }
        }
      }
    }

    Repeater {
      model: map.lay.nodes
      delegate: Item {
        id: idea
        required property int index
        // The layout's own entry (a model's modelData is a copy, and the
        // ideas in it wouldn't be the map's).
        readonly property var n: map.lay.nodes[index]
        readonly property color tint: map.tint(n.branch)
        readonly property bool writing: map.editing && n.node === map.current
        readonly property bool folding: n.depth > 0 && n.node.children.length > 0
        x: n.x
        y: n.y
        width: n.w
        height: n.h

        Rectangle {
          anchors.fill: parent
          radius: idea.n.depth === 0 ? 12 : idea.n.depth === 1 ? 8 : 5
          color: map.fillOf(idea.n, idea.writing, hover.hovered)
          border.width: idea.n.depth === 1 ? 1.5 : idea.writing && idea.n.depth === 0 ? 2 : 0
          border.color: idea.n.depth === 0 ? Qt.alpha(map.inkOf(idea.n.node, 0), 0.6) : idea.tint
        }
        // Ideas further out sit on a line in their branch's color.
        Rectangle {
          visible: idea.n.depth >= 2
          width: parent.width
          height: 2
          radius: 1
          y: parent.height - 1
          color: idea.tint
        }
        Text {
          visible: !idea.writing
          anchors.centerIn: parent
          textFormat: Text.PlainText
          horizontalAlignment: Text.AlignHCenter
          text: idea.n.lines.join("\n")
          font.family: map.editor.family
          font.pixelSize: map.sizeOf(idea.n.depth)
          font.weight: map.weightOf(idea.n.depth)
          lineHeightMode: Text.FixedHeight
          lineHeight: Math.ceil(map.metrics(idea.n.depth).lineSpacing)
          color: map.inkOf(idea.n.node, idea.n.depth)
        }
        HoverHandler { id: hover; cursorShape: map.readOnly ? Qt.ArrowCursor : Qt.IBeamCursor }
        // (Taken here, not by the map behind it.)
        TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: map.edit(idea.n.node) }

        // Colors for the idea you're writing on.
        Rectangle {
          id: colorButton
          visible: idea.writing
          z: 4
          width: 22
          height: 22
          radius: 11
          x: parent.width - width / 2 - 2
          y: -height / 2 - 2
          color: colorHover.hovered ? Qt.lighter(map.editor.paper, 1.6) : map.editor.paper
          border.width: 1.2
          border.color: Qt.alpha(map.ink, 0.35)
          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: "\u{f0e0c}"
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 13
            color: map.ink
          }
          HoverHandler { id: colorHover; cursorShape: Qt.PointingHandCursor }
          TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: map.askColors(colorButton)
          }
        }

        // Folds the branch away (with how many ideas are in it, when folded).
        Rectangle {
          visible: idea.folding && (idea.n.node.folded || hover.hovered || foldHover.hovered || idea.writing)
          z: 2
          width: Math.max(18, foldCount.implicitWidth + 8)
          height: 18
          radius: 9
          x: idea.n.side < 0 ? -width + 6 : parent.width - 6
          y: (idea.n.anchorY - idea.n.y) - height / 2
          color: idea.n.node.folded ? idea.tint : map.editor.paper
          border.width: 1.4
          border.color: idea.tint
          Text {
            id: foldCount
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: idea.n.node.folded ? String(Mindmap.descendants(idea.n.node)) : "\u2212"
            font.family: map.editor.uiFamily
            font.pixelSize: 11
            font.weight: Font.DemiBold
            color: idea.n.node.folded ? map.editor.paper : idea.tint
          }
          HoverHandler { id: foldHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: map.toggleFold(idea.n.node) }
        }
      }
    }

    // Where you write, over the idea you're on.
    TextEdit {
      id: input
      readonly property var at: { var l = map.lay; return map.editing ? map.entryFor(map.current) : null }
      readonly property int depth: at ? at.depth : 1
      visible: map.editing && at !== null
      x: at ? at.x + map.padOf(depth).x - 1 : 0
      y: at ? at.y + (at.h - height) / 2 : 0
      width: at ? at.w - 2 * map.padOf(depth).x + 2 : 40
      z: 3
      textFormat: TextEdit.PlainText
      wrapMode: TextEdit.Wrap
      horizontalAlignment: TextEdit.AlignHCenter
      font.family: map.editor.family
      font.pixelSize: map.sizeOf(depth)
      font.weight: map.weightOf(depth)
      color: map.inkOf(map.current, depth)
      selectionColor: map.editor.selectionColor
      selectedTextColor: map.editor.ink
      selectByMouse: true
      Keys.onPressed: function(e) { map.key(e) }
      onTextChanged: {
        if (map.switching || !map.editing || !map.current) return
        var t = Mindmap.cleanText(text)
        if (t === map.current.text) return
        map.current.text = t
        map.relayout()
      }
      onActiveFocusChanged: if (!activeFocus && map.editing && !map.switching && !map.picking) map.finish()
      Text {
        visible: input.length === 0
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: input.depth === 0 ? "Topic" : "Idea"
        font: input.font
        color: Qt.alpha(input.color, 0.4)
      }
    }
  }
}
