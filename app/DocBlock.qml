import QtQuick
import QtQuick.Shapes
import "../Html.js" as Html
import "../Blocks.js" as Blocks
import "../Docs.js" as Docs
import "../Workspace.js" as Workspace

// One block of a page in Pages, the way Notion draws it: text in its kind's
// size with space around it, a list's bullet or number, a to-do's box, a
// toggle's arrow, a callout's icon, a quote's bar, a code block's box. The
// blocks inside a block come after it, further in; a callout's or a colored
// block's background, and a quote's bar, reach down past them.
//
// Beside it, while the pointer is over it: + (a new block below, with the
// "/" menu) and a handle to drag it, and what's inside it, somewhere else,
// or to click for its menu. Editor.qml owns the page; this draws one block.
Item {
  id: block

  required property int index
  required property string uid
  required property string type
  required property int indent
  required property bool checked
  required property string align
  required property string src
  required property real imgWidth
  required property real ratio
  required property string hint
  required property string color
  required property bool toggle
  required property bool collapsed
  required property string lang
  required property string target
  required property string icon
  required property string days
  required property string month
  required property string marks
  required property string outline
  required property string folds
  required property string table
  required property string sketch
  required property string audio
  required property string meeting
  required property string calref
  // (A block's data, as JSON: `data` is every item's own.)
  required property string extra

  property var editor: null

  // Where it is on the page (Editor.computeLayout).
  readonly property var info: {
    var s = editor.structure
    return editor.docLayout[uid] || ({ x: 0, hidden: false, kids: false, boxes: [] })
  }
  readonly property bool hidden: info.hidden === true
  // Columns and a column only arrange other blocks; they don't show.
  readonly property bool structure: type === "columns" || type === "column"
  readonly property real bx: info.x
  readonly property var st: Docs.typeStyle(type, editor.smallText)
  readonly property var colors: Docs.blockColors(color, editor.dark)
  readonly property bool isText: Blocks.isText(type)
  readonly property bool folding: Workspace.folds({ type: type, toggle: toggle })
  readonly property bool listy: type === "bullet" || type === "number" || type === "check" || type === "toggle"
  readonly property bool heading: type === "h1" || type === "h2" || type === "h3"
  readonly property bool selected: editor.selectedMap[uid] === true
  readonly property bool dragged: editor.dragUid === uid
  readonly property var matches: editor.findMatches[uid] || []
  readonly property color inkColor: colors.text !== "" ? colors.text : editor.ink

  // The boxes it's in (outermost first), and how much room each takes at the
  // top (its own block) and bottom (the last block showing in it).
  readonly property var boxes: info.boxes || []
  function boxPad(b) { return b.callout ? 12 : b.color ? 3 : 0 }
  function boxSide(b) { return b.callout ? 14 : b.color ? 6 : 0 }
  readonly property real boxTop: { var t = 0; boxes.forEach(function(b) { if (b.uid === block.uid) t += boxPad(b) }); return t }
  readonly property real boxBottom: { var t = 0; boxes.forEach(function(b) { if (b.last === block.uid) t += boxPad(b) }); return t }
  readonly property real boxRight: { var t = 0; boxes.forEach(function(b) { t += boxSide(b) }); return t }

  // Where its text starts: past a marker, an icon or a bar.
  readonly property real textX: bx + (listy || folding || type === "callout" || type === "quote" ? editor.childOffset({ type: type })
    : type === "code" ? 16 : type === "page" || type === "link" ? 30 : colors.background !== "" ? 6 : 0)
  readonly property real textW: Math.max(40, width - textX - boxRight - (type === "code" ? 16 : 0) - habitW)

  // A habit's week: a circle for each day, at the end of its line.
  readonly property real dot: Math.round(st.lineHeight * 0.9)
  readonly property real dotGap: 6
  readonly property real daysW: 7 * dot + 6 * dotGap
  readonly property real habitW: type === "habit" ? daysW + 14 : 0

  // A month's calendar: its name, the days of the week, a row a week.
  readonly property var cal: type === "calendar" ? Blocks.monthLayout(month) : ({ offset: 0, days: 0, weeks: 0 })
  readonly property real calHead: Math.round(st.lineHeight * 1.3)
  readonly property real calWeekdays: Math.round(st.lineHeight * 0.95)
  readonly property real calRow: Math.round(st.lineHeight * 1.4)

  // The biggest text in it (px; 0: its kind's own size) sets its lines' height.
  property real maxPx: 0
  readonly property real fontPx: Math.max(st.size, maxPx)
  readonly property real lineHeight: Math.round(fontPx * st.lineHeight / st.size)
  // Qt puts a fixed-height line's baseline at 4/5 of it; moving the text up
  // this much centers the letters in the line, as a browser would.
  readonly property real textShift: Math.round(((lineHeight - fontPx * 1.2) / 2 + fontPx * 0.95) - lineHeight * 0.8)
  readonly property real codePad: type === "code" ? 34 : 0
  readonly property real textTop: st.above + boxTop + (type === "code" ? codePad : 0)
  readonly property real firstBaseline: textTop + textShift + lineHeight * 0.8
  readonly property real markY: firstBaseline - fontPx * 0.34

  // An open toggle with nothing in it says so, on a line of its own.
  readonly property bool emptyToggle: folding && !collapsed && !info.kids
  readonly property real emptyRow: emptyToggle ? st.lineHeight : 0

  readonly property real picW: Math.max(60, (width - bx) * Math.max(0.15, Math.min(1, imgWidth || 0.6)))
  readonly property real picRatio: ratio > 0 ? ratio : (picture.implicitHeight > 0 ? picture.implicitWidth / picture.implicitHeight : 1.5)
  readonly property real picH: picW / picRatio
  readonly property var tocList: { var s = editor.structure; return type === "toc" ? editor.headings() : [] }
  readonly property real contentH: isText ? Math.max(lineHeight, textEdit.contentHeight) + (type === "code" ? codePad + 14 : 0) + emptyRow
    : type === "divider" ? 1
    : type === "image" ? picH
    : type === "page" || type === "link" ? st.lineHeight + 4
    : type === "toc" ? Math.max(1, tocList.length) * st.lineHeight
    : type === "calendar" ? calHead + calWeekdays + cal.weeks * calRow + 4
    : type === "mindmap" ? (mapLoader.item ? mapLoader.item.height : st.lineHeight)
    : type === "table" ? (tableLoader.item ? tableLoader.item.height : st.lineHeight)
    : type === "sketch" ? (sketchLoader.item ? sketchLoader.item.height : st.lineHeight)
    : type === "audio" ? (audioLoader.item ? audioLoader.item.height : 60)
    : type === "meeting" ? (meetingLoader.item ? meetingLoader.item.height : 80)
    : type === "agenda" || type === "event" ? (calLoader.item ? calLoader.item.height : 40)
    : Blocks.hasData(type) ? (dataLoader.item ? dataLoader.item.height : 40)
    : st.lineHeight

  property alias edit: textEdit
  property bool dirty: false
  property bool loading: false
  // Its text is shown as code (in its language's colors).
  property bool shownCode: false

  // Where it goes across (the page, or its column); positionBlocks puts it
  // down the page, and again whenever its height changes.
  x: info.left !== undefined ? info.left : 0
  width: info.w > 0 ? info.w : editor.contentWidth
  height: hidden || structure ? 0 : st.above + boxTop + contentH + boxBottom + st.below
  visible: !hidden && !structure
  opacity: dragged ? 0.35 : 1
  onHeightChanged: editor.schedulePosition()

  // ---- loading the text -------------------------------------------------------------------

  function measure(inner) {
    maxPx = Html.maxSize(inner || "")
  }

  // "/mindmap": you write the new map's topic first.
  readonly property var mindMap: mapLoader.item
  function startMindMap() { if (mapLoader.item) mapLoader.item.start(0) }

  // A table: what's written in it (Editor.syncTable), and the cursor into
  // it from above (dir 1) or below, `x` across the block.
  readonly property var tableView: tableLoader.item
  function tableJson() { return tableLoader.item ? tableLoader.item.json() : "" }
  function enter(dir, x) { if (tableLoader.item) tableLoader.item.enter(dir, x - tableLoader.x) }

  // A sketch: drawn on (startDrawing).
  readonly property var sketchView: sketchLoader.item
  // A table or a sketch tells where the pointer is itself (the block's own
  // pointer zone would keep it from knowing).
  property bool pictureHovered: false
  // (A picture's own handles, at its sides, need the pointer over it.)
  readonly property bool ownHover: type === "table" || type === "sketch" || type === "audio" || type === "meeting" || type === "agenda" || type === "event" || type === "image" || Blocks.hasData(type)
  readonly property bool contentHovered: (tableLoader.item !== null && tableLoader.item.pointerIn) || (sketchLoader.item !== null && sketchLoader.item.pointerIn)
    || (audioLoader.item !== null && audioLoader.item.pointerIn) || (meetingLoader.item !== null && meetingLoader.item.pointerIn)
    || (calLoader.item !== null && calLoader.item.pointerIn) || (dataLoader.item !== null && dataLoader.item.pointerIn)
    || (type === "image" && pictureHovered)
  // An audio note: recorded into, played, written out.
  readonly property var audioView: audioLoader.item
  // A meeting: started, stopped, written out.
  readonly property var meetingView: meetingLoader.item
  // An agenda or an event block.
  readonly property var calView: calLoader.item
  // A button, a file, a video, a bookmark, a board, a synced block.
  readonly property var dataView: dataLoader.item

  function reload() {
    if (!isText) return
    var had = textEdit.activeFocus
    var pos = textEdit.cursorPosition
    loading = true
    measure(editor.htmls[uid] || "")
    textEdit.text = Html.wrapBlock(editor.displayOf(uid, type, lang), lineHeight, editor.linkColor, editor.tagStyle)
    shownCode = type === "code"
    loading = false
    dirty = false
    if (had) textEdit.cursorPosition = Math.min(pos, textEdit.length)
  }

  onLineHeightChanged: if (!loading && textEdit.text !== "") { editor.syncBlock(uid); reload() }
  // Code in another language, or text that is or isn't code now: shown again.
  onLangChanged: if (isText && type === "code") { editor.syncBlock(uid); reload() }
  onTypeChanged: if (isText && (type === "code") !== shownCode) editor.retyped(block)
  Component.onCompleted: {
    editor.register(block)
    reload()
  }
  Component.onDestruction: editor.unregister(block)

  Connections {
    target: block.editor
    function onRestyle() {
      block.editor.syncBlock(block.uid)
      block.reload()
    }
  }

  // ---- behind it --------------------------------------------------------------------------

  // The boxes it's in: a callout's or a colored block's background, from the
  // block itself down past the last block inside it; a quote's bar.
  Repeater {
    model: block.boxes
    delegate: Item {
      required property var modelData
      required property int index
      readonly property bool first: modelData.uid === block.uid
      readonly property bool last: modelData.last === block.uid
      readonly property real inset: {
        var t = 0
        for (var i = 0; i < index; i++) t += block.boxSide(block.boxes[i])
        return t
      }
      x: modelData.x
      y: first ? Math.max(0, block.st.above - 2) : 0
      width: block.width - x - inset
      height: block.height - y - (last ? Math.max(0, block.st.below - 2) : 0)
      Rectangle {
        visible: modelData.color !== ""
        anchors.fill: parent
        color: modelData.color
        topLeftRadius: parent.first ? 5 : 0
        topRightRadius: parent.first ? 5 : 0
        bottomLeftRadius: parent.last ? 5 : 0
        bottomRightRadius: parent.last ? 5 : 0
      }
      Rectangle {
        visible: modelData.bar && modelData.color === ""
        x: 1
        y: parent.first ? 3 : 0
        width: 3
        height: parent.height - y - (parent.last ? 3 : 0)
        color: block.editor.ink
        opacity: 0.85
      }
    }
  }

  // Picked as a block (Esc, Shift+arrows, a drag across blocks).
  Rectangle {
    visible: block.selected
    x: block.bx - 4
    y: 1
    width: block.width - x + 4
    height: block.height - 2
    radius: 4
    color: Qt.alpha(block.editor.accent, 0.16)
  }

  // A code block's box, its language and a copy button.
  Rectangle {
    visible: block.type === "code"
    x: block.bx
    y: block.st.above + block.boxTop
    width: block.width - block.bx - block.boxRight
    height: block.contentH
    radius: 5
    color: Qt.alpha(block.editor.ink, block.editor.dark ? 0.08 : 0.055)

    Text {
      textFormat: Text.PlainText
      x: 14
      y: 9
      text: (block.lang || "Plain text") + "  \u25be"
      font.family: block.editor.uiFamily
      font.pixelSize: 12
      color: Qt.alpha(block.editor.ink, langHover.hovered ? 0.8 : 0.5)
      HoverHandler { id: langHover; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: block.editor.languageRequested(block.uid) }
    }
    Rectangle {
      visible: codeHover.hovered || copyTap.pressed
      anchors.right: parent.right
      anchors.rightMargin: 8
      y: 6
      width: copyLabel.implicitWidth + 16
      height: 24
      radius: 5
      color: copyHover.hovered ? Qt.alpha(block.editor.ink, 0.1) : Qt.alpha(block.editor.ink, 0.04)
      Text {
        id: copyLabel
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: "Copy"
        font.family: block.editor.uiFamily
        font.pixelSize: 12
        color: Qt.alpha(block.editor.ink, 0.7)
      }
      HoverHandler { id: copyHover; cursorShape: Qt.PointingHandCursor }
      TapHandler { id: copyTap; onTapped: block.editor.textCopied(textEdit.getText(0, textEdit.length).replace(/\u2028/g, "\n")) }
    }
    HoverHandler { id: codeHover }
  }

  // Found text (Find on this page).
  Repeater {
    model: block.matches
    delegate: Rectangle {
      required property var modelData
      required property int index
      readonly property var r0: textEdit.positionToRectangle(modelData[0])
      readonly property var r1: textEdit.positionToRectangle(modelData[1])
      readonly property bool current: block.editor.findCurrentUid === block.uid && block.editor.findCurrentIndex === index
      x: textEdit.x + r0.x - 1
      y: textEdit.y + r0.y - 1
      width: Math.max(4, (r1.y === r0.y ? r1.x - r0.x : textEdit.width - r0.x)) + 2
      height: r0.height + 2
      radius: 3
      color: current ? Qt.alpha("#ff9f0a", 0.55) : Qt.alpha("#ffd60a", 0.4)
    }
  }

  // ---- before the text ---------------------------------------------------------------------

  // Bullets: a dot, a ring, a square, by how many lists the item is inside.
  Rectangle {
    visible: block.type === "bullet"
    readonly property int level: (block.info.lists || 0) % 3
    readonly property real size: Math.round(block.fontPx * 0.36)
    width: size
    height: size
    radius: level === 2 ? 1 : size / 2
    x: block.bx + block.editor.docGutter * 0.46 - size / 2
    y: block.markY - size / 2
    color: level === 1 ? "transparent" : block.inkColor
    border.width: level === 1 ? 1.4 : 0
    border.color: block.inkColor
  }

  // Numbers: 1. then a. then i.
  Text {
    textFormat: Text.PlainText
    visible: block.type === "number"
    text: block.editor.numbers[block.uid] || "1."
    x: block.bx
    width: block.editor.docGutter - 5
    y: block.firstBaseline - baselineOffset
    horizontalAlignment: Text.AlignRight
    font.family: block.editor.family
    font.pixelSize: block.st.size
    font.features: { "tnum": 1 }
    color: block.inkColor
  }

  // A to-do's box: ticked, it's filled with the accent and the text goes gray.
  Rectangle {
    id: box
    visible: block.type === "check"
    readonly property real size: Math.round(block.fontPx * 1.0)
    width: size
    height: size
    x: block.bx + block.editor.docGutter * 0.46 - size / 2
    y: block.markY - size / 2
    radius: 3
    color: block.checked ? block.editor.accent : "transparent"
    border.width: block.checked ? 0 : 1.5
    border.color: Qt.alpha(block.editor.ink, 0.6)
    Behavior on color { ColorAnimation { duration: 120 } }
    Shape {
      anchors.fill: parent
      visible: block.checked
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: "white"
        strokeWidth: Math.max(1.8, box.size * 0.13)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: box.size * 0.24; startY: box.size * 0.52
        PathLine { x: box.size * 0.43; y: box.size * 0.72 }
        PathLine { x: box.size * 0.78; y: box.size * 0.3 }
      }
    }
    TapHandler {
      margin: 5
      cursorShape: Qt.PointingHandCursor
      onTapped: block.editor.toggleCheck(block.uid)
    }
  }

  // A toggle's arrow (and a toggle heading's): right when folded, down when open.
  Item {
    visible: block.folding
    x: block.bx
    y: block.markY - height / 2
    width: block.editor.docGutter - 3
    height: width
    Rectangle {
      anchors.centerIn: parent
      width: 22
      height: 22
      radius: 4
      color: arrowHover.hovered ? Qt.alpha(block.editor.ink, 0.08) : "transparent"
    }
    Shape {
      anchors.centerIn: parent
      width: 10
      height: 10
      rotation: block.collapsed ? 0 : 90
      Behavior on rotation { NumberAnimation { duration: 140; easing.type: Easing.OutCubic } }
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: block.inkColor
        startX: 2; startY: 0
        PathLine { x: 9; y: 5 }
        PathLine { x: 2; y: 10 }
        PathLine { x: 2; y: 0 }
      }
    }
    HoverHandler { id: arrowHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: block.editor.toggleFold(block.uid) }
  }

  // A callout's icon: click it for another.
  Text {
    textFormat: Text.PlainText
    visible: block.type === "callout"
    x: block.bx + 12
    y: block.markY - height / 2
    text: block.icon || "\u{1f4a1}"
    font.family: "Noto Color Emoji"
    font.pixelSize: Math.round(block.fontPx * 1.15)
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: block.editor.iconRequested(block.uid) }
  }

  // ---- the text ----------------------------------------------------------------------------

  TextEdit {
    id: textEdit
    visible: block.isText
    enabled: block.isText
    x: block.textX
    y: block.textTop + block.textShift
    width: block.textW
    textFormat: TextEdit.RichText
    wrapMode: TextEdit.Wrap
    readOnly: block.editor.readOnly
    selectByMouse: true
    persistentSelection: true
    font.family: block.st.mono ? block.editor.monoFamily : block.editor.family
    font.pixelSize: block.st.size
    font.weight: block.st.weight
    font.strikeout: block.type === "check" && block.checked && block.editor.strikeDone
    color: block.type === "check" && block.checked ? Qt.alpha(block.inkColor, 0.45) : block.inkColor
    selectionColor: block.editor.selectionColor
    selectedTextColor: block.editor.ink
    horizontalAlignment: block.align === "center" ? TextEdit.AlignHCenter
      : block.align === "right" ? TextEdit.AlignRight
      : block.align === "justify" ? TextEdit.AlignJustify : TextEdit.AlignLeft
    tabStopDistance: 32

    Keys.onPressed: function(event) { block.editor.onKey(block, event) }

    onTextChanged: {
      if (block.loading) return
      block.dirty = true
      block.editor.edited(block)
    }
    onCursorRectangleChanged: if (activeFocus) block.editor.cursorMovedIn(block)
    onSelectionStartChanged: if (activeFocus) block.editor.selectionChangedIn(block)
    onSelectionEndChanged: if (activeFocus) block.editor.selectionChangedIn(block)
    onActiveFocusChanged: block.editor.focusChangedIn(block, activeFocus)

    // Ctrl+click opens a link; Ctrl+hover shows it can.
    HoverHandler {
      id: hover
      readonly property string link: textEdit.linkAt(hover.point.position.x, hover.point.position.y)
      cursorShape: (link !== "" && (hover.point.modifiers & Qt.ControlModifier)) || Html.pageOf(link) !== "" || Html.isTag(link) || Html.contactOf(link) !== ""
        ? Qt.PointingHandCursor : Qt.IBeamCursor
    }
    TapHandler {
      acceptedModifiers: Qt.ControlModifier
      onTapped: function(eventPoint) {
        var link = textEdit.linkAt(eventPoint.position.x, eventPoint.position.y)
        if (link) block.editor.openLink(link, textEdit, eventPoint.position.x, eventPoint.position.y)
      }
    }
    // A link to a page opens with a plain click, as in Notion, a tag shows
    // every block with it, and a person their card.
    TapHandler {
      acceptedModifiers: Qt.NoModifier
      onTapped: function(eventPoint) {
        var link = textEdit.linkAt(eventPoint.position.x, eventPoint.position.y)
        if (Html.pageOf(link) || Html.isTag(link) || Html.contactOf(link)) block.editor.openLink(link, textEdit, eventPoint.position.x, eventPoint.position.y)
      }
    }
  }

  // What an empty block is for: its kind, or "/" on the line you're on.
  Text {
    textFormat: Text.PlainText
    readonly property string words: block.hint !== "" ? block.hint : Docs.placeholder(block.type, textEdit.activeFocus)
    visible: block.isText && words !== "" && textEdit.length === 0 && textEdit.preeditText === ""
    x: textEdit.x
    y: block.firstBaseline - baselineOffset
    width: textEdit.width
    elide: Text.ElideRight
    horizontalAlignment: textEdit.horizontalAlignment
    text: words
    font: textEdit.font
    color: Qt.alpha(block.editor.ink, 0.35)
  }

  // An open toggle with nothing inside it.
  Text {
    textFormat: Text.PlainText
    visible: block.emptyToggle
    x: block.bx + block.editor.docGutter
    y: block.textTop + block.textShift + Math.max(block.lineHeight, textEdit.contentHeight) + block.st.lineHeight * 0.8 - baselineOffset
    text: "Empty toggle. Click to write inside it, or drop blocks in."
    font.family: block.editor.family
    font.pixelSize: block.st.size
    color: Qt.alpha(block.editor.ink, 0.35)
    HoverHandler { cursorShape: Qt.PointingHandCursor }
    TapHandler { onTapped: block.editor.addChild(block.uid) }
  }

  // ---- a mind map ------------------------------------------------------------------------------

  Loader {
    id: mapLoader
    active: block.type === "mindmap"
    x: block.bx
    y: block.st.above + block.boxTop
    sourceComponent: MindMap {
      editor: block.editor
      uid: block.uid
      outline: block.outline
      folds: block.folds
      ink: block.inkColor
      available: block.width - block.bx - block.boxRight
    }
  }

  // ---- a table ----------------------------------------------------------------------------------

  Loader {
    id: tableLoader
    active: block.type === "table"
    x: block.bx
    y: block.st.above + block.boxTop
    sourceComponent: TableBlock {
      editor: block.editor
      host: block
      uid: block.uid
      source: block.table
      ink: block.inkColor
      fontPx: block.st.size
      lineH: Math.round(block.st.size * 1.45)
      available: block.width - block.bx - block.boxRight
    }
  }

  // ---- a sketch ----------------------------------------------------------------------------------

  Loader {
    id: sketchLoader
    active: block.type === "sketch"
    x: block.bx
    y: block.st.above + block.boxTop
    sourceComponent: SketchBlock {
      editor: block.editor
      host: block
      uid: block.uid
      source: block.sketch
      ink: block.inkColor
      available: block.width - block.bx - block.boxRight
    }
  }

  // ---- an audio note ---------------------------------------------------------------------------

  Loader {
    id: audioLoader
    active: block.type === "audio"
    x: block.bx
    y: block.st.above + block.boxTop
    sourceComponent: AudioBlock {
      editor: block.editor
      host: block
      uid: block.uid
      source: block.audio
      ink: block.inkColor
      available: block.width - block.bx - block.boxRight
    }
  }

  // ---- a meeting ---------------------------------------------------------------------------------

  Loader {
    id: meetingLoader
    active: block.type === "meeting"
    x: block.bx
    y: block.st.above + block.boxTop
    sourceComponent: MeetingBlock {
      editor: block.editor
      uid: block.uid
      source: block.meeting
      ink: block.inkColor
      available: block.width - block.bx - block.boxRight
    }
  }

  // ---- the calendar: a day's events, or one -----------------------------------------------------

  Loader {
    id: calLoader
    active: block.type === "agenda" || block.type === "event"
    x: block.bx
    y: block.st.above + block.boxTop
    sourceComponent: CalendarBlock {
      editor: block.editor
      uid: block.uid
      kind: block.type
      source: block.calref
      ink: block.inkColor
      available: block.width - block.bx - block.boxRight
    }
  }

  // ---- a button, a file, a video, a bookmark, a board, a synced block ---------------------------

  Loader {
    id: dataLoader
    active: Blocks.hasData(block.type)
    x: block.bx
    y: block.st.above + block.boxTop
    sourceComponent: block.type === "button" ? buttonComp : block.type === "file" ? fileComp : block.type === "video" ? videoComp
      : block.type === "bookmark" ? bookmarkComp : block.type === "board" ? boardComp : block.type === "contact" ? contactComp : block.type === "email" ? emailComp
      : block.type === "gallery" ? galleryComp : null
    // (A synced block has an editor of its own, of these blocks: by name, so
    // the types aren't each other's when they're compiled.)
    source: block.type === "synced" ? "SyncedBlock.qml" : ""
    onLoaded: if (block.type === "synced") {
      item.editor = Qt.binding(function() { return block.editor })
      item.uid = Qt.binding(function() { return block.uid })
      item.source = Qt.binding(function() { return block.extra })
      item.ink = Qt.binding(function() { return block.inkColor })
      item.available = Qt.binding(function() { return block.width - block.bx - block.boxRight })
    }
  }
  Component { id: buttonComp; ButtonBlock { editor: block.editor; uid: block.uid; source: block.extra; ink: block.inkColor; available: block.width - block.bx - block.boxRight } }
  Component { id: fileComp; FileBlock { editor: block.editor; uid: block.uid; source: block.extra; ink: block.inkColor; available: block.width - block.bx - block.boxRight } }
  Component { id: videoComp; VideoBlock { editor: block.editor; uid: block.uid; source: block.extra; ink: block.inkColor; available: block.width - block.bx - block.boxRight } }
  Component { id: galleryComp; GalleryBlock { editor: block.editor; uid: block.uid; source: block.extra; ink: block.inkColor; available: block.width - block.bx - block.boxRight } }
  Component { id: emailComp; EmailBlock { editor: block.editor; uid: block.uid; source: block.extra; ink: block.inkColor; available: block.width - block.bx - block.boxRight } }
  Component { id: contactComp; ContactBlock { editor: block.editor; uid: block.uid; source: block.extra; ink: block.inkColor; available: block.width - block.bx - block.boxRight } }
  Component { id: bookmarkComp; BookmarkBlock { editor: block.editor; uid: block.uid; source: block.extra; ink: block.inkColor; available: block.width - block.bx - block.boxRight } }
  Component { id: boardComp; BoardBlock { editor: block.editor; uid: block.uid; source: block.extra; ink: block.inkColor; available: block.width - block.bx - block.boxRight } }

  // ---- a habit's week --------------------------------------------------------------------------

  // A circle for each day of the week, Monday first, today's rimmed in the
  // accent: click one to tick the day off, again to take the tick away.
  Row {
    id: habitDays
    visible: block.type === "habit"
    x: block.width - block.boxRight - block.daysW
    y: block.markY - block.dot / 2
    spacing: block.dotGap
    Repeater {
      model: block.type === "habit" ? 7 : 0
      delegate: Item {
        id: day
        required property int index
        readonly property bool done: block.days.charAt(index) === "1"
        readonly property bool today: (new Date().getDay() + 6) % 7 === index
        width: block.dot
        height: block.dot
        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: day.done ? Qt.alpha(block.editor.accent, 0.18) : dayHover.hovered ? Qt.alpha(block.editor.ink, 0.07) : "transparent"
          border.width: day.today && !day.done ? 1.6 : 1.2
          border.color: day.done ? Qt.alpha(block.editor.accent, 0.85) : day.today ? Qt.alpha(block.editor.accent, 0.9) : Qt.alpha(block.editor.ink, 0.3)
          Behavior on color { ColorAnimation { duration: 120 } }
        }
        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          visible: !day.done
          text: Qt.locale().dayName((day.index + 1) % 7, Locale.NarrowFormat)
          font.family: block.editor.uiFamily
          font.pixelSize: Math.max(9, Math.round(block.dot * 0.45))
          color: Qt.alpha(block.editor.ink, day.today ? 0.8 : 0.5)
        }
        Shape {
          id: dayTick
          anchors.fill: parent
          preferredRendererType: Shape.CurveRenderer
          opacity: day.done ? 1 : 0
          scale: day.done ? 1 : 0.4
          Behavior on opacity { NumberAnimation { duration: 120 } }
          Behavior on scale { NumberAnimation { duration: 200; easing.type: Easing.OutBack; easing.overshoot: 2 } }
          ShapePath {
            strokeColor: block.editor.accent
            strokeWidth: Math.max(1.8, block.dot * 0.11)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: dayTick.width * 0.28; startY: dayTick.height * 0.53
            PathLine { x: dayTick.width * 0.44; y: dayTick.height * 0.68 }
            PathLine { x: dayTick.width * 0.73; y: dayTick.height * 0.35 }
          }
        }
        HoverHandler { id: dayHover; cursorShape: block.editor.readOnly ? Qt.ArrowCursor : Qt.PointingHandCursor }
        TapHandler {
          margin: block.dotGap / 2
          onTapped: block.editor.toggleDay(block.uid, day.index)
        }
      }
    }
  }

  // ---- a month's calendar ------------------------------------------------------------------------

  // The month's name (and, while the pointer is over it, the months before
  // and after), the days of the week, and the dates, Monday first. Today is
  // in the accent; click a date to circle it, again to rub it out.
  Item {
    id: calendar
    visible: block.type === "calendar"
    x: block.bx
    y: block.st.above + block.boxTop
    width: block.width - block.bx - block.boxRight
    height: block.type === "calendar" ? block.contentH : 0
    readonly property real colW: width / 7
    readonly property var first: block.type === "calendar" ? new Date(Number(block.month.slice(0, 4)), Number(block.month.slice(5, 7)) - 1, 1) : new Date(2000, 0, 1)
    readonly property var now: new Date()
    readonly property int today: block.type === "calendar" && now.getFullYear() === first.getFullYear() && now.getMonth() === first.getMonth() ? now.getDate() : 0
    readonly property var markList: block.marks === "" ? [] : block.marks.split(",").map(Number).filter(function(d) { return d <= block.cal.days })
    readonly property real gridTop: block.calHead + block.calWeekdays
    readonly property int hoverDay: calHover.hovered ? dayAt(calHover.point.position.x, calHover.point.position.y) : 0

    function dayAt(px, py) {
      if (py < gridTop) return 0
      var row = Math.floor((py - gridTop) / block.calRow)
      var col = Math.floor(px / colW)
      if (row < 0 || col < 0 || col > 6) return 0
      var d = row * 7 + col - block.cal.offset + 1
      return d >= 1 && d <= block.cal.days ? d : 0
    }
    function cellX(d) { return ((d - 1 + block.cal.offset) % 7) * colW }
    function cellY(d) { return gridTop + Math.floor((d - 1 + block.cal.offset) / 7) * block.calRow }

    Text {
      textFormat: Text.PlainText
      x: 6
      height: block.calHead
      verticalAlignment: Text.AlignVCenter
      text: block.type === "calendar" ? Qt.formatDate(calendar.first, "MMMM yyyy") : ""
      font.family: block.editor.uiFamily
      font.pixelSize: Math.round(block.st.size * 0.8)
      font.capitalization: Font.AllUppercase
      font.letterSpacing: 1.2
      font.weight: Font.DemiBold
      color: Qt.alpha(block.editor.ink, 0.7)
    }

    Row {
      anchors.right: parent.right
      height: block.calHead
      visible: (calHover.hovered || block.selected) && !block.editor.readOnly
      spacing: 2
      Repeater {
        model: [[-1, "\u{f0141}", "The month before"], [0, "Today", "This month"], [1, "\u{f0142}", "The month after"]]
        delegate: Rectangle {
          required property var modelData
          anchors.verticalCenter: parent.verticalCenter
          width: modelData[0] === 0 ? todayLabel.implicitWidth + 14 : block.calHead * 0.85
          height: block.calHead * 0.85
          radius: height / 2
          color: arrowHover.hovered ? Qt.alpha(block.editor.ink, 0.08) : "transparent"
          Text {
            id: todayLabel
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: modelData[1]
            font.family: modelData[0] === 0 ? block.editor.uiFamily : "JetBrainsMono Nerd Font"
            font.pixelSize: modelData[0] === 0 ? 12 : Math.round(block.calHead * 0.55)
            color: Qt.alpha(block.editor.ink, 0.7)
          }
          HoverHandler { id: arrowHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: block.editor.shiftMonth(block.uid, modelData[0]) }
        }
      }
    }

    Repeater {
      model: block.type === "calendar" ? 7 : 0
      delegate: Text {
        required property int index
        textFormat: Text.PlainText
        x: index * calendar.colW
        y: block.calHead
        width: calendar.colW
        height: block.calWeekdays
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: Qt.locale().dayName((index + 1) % 7, Locale.ShortFormat)
        font.family: block.editor.uiFamily
        font.pixelSize: Math.round(block.st.size * 0.75)
        font.weight: Font.DemiBold
        color: Qt.alpha(block.editor.ink, index >= 5 ? 0.38 : 0.5)
      }
    }

    // The date under the pointer, and today.
    Rectangle {
      visible: calendar.hoverDay > 0 && !block.editor.readOnly
      readonly property real side: Math.min(block.calRow, calendar.colW) - 4
      x: calendar.cellX(calendar.hoverDay) + (calendar.colW - side) / 2
      y: calendar.cellY(calendar.hoverDay) + (block.calRow - side) / 2
      width: side
      height: side
      radius: side / 2
      color: Qt.alpha(block.editor.ink, 0.07)
    }
    Rectangle {
      visible: calendar.today > 0
      readonly property real side: Math.min(block.calRow, calendar.colW) - 6
      x: calendar.cellX(calendar.today) + (calendar.colW - side) / 2
      y: calendar.cellY(calendar.today) + (block.calRow - side) / 2
      width: side
      height: side
      radius: side / 2
      color: Qt.alpha(block.editor.accent, 0.22)
    }

    Repeater {
      model: block.type === "calendar" ? block.cal.days : 0
      delegate: Text {
        required property int index
        readonly property int day: index + 1
        textFormat: Text.PlainText
        x: calendar.cellX(day)
        y: calendar.cellY(day)
        width: calendar.colW
        height: block.calRow
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        text: day
        font.family: block.editor.family
        font.pixelSize: block.st.size
        font.features: { "tnum": 1 }
        font.bold: day === calendar.today
        color: day === calendar.today ? block.editor.accent
          : Qt.alpha(block.editor.ink, (day - 1 + block.cal.offset) % 7 >= 5 ? 0.55 : 0.85)
      }
    }

    // Circled dates: a pen's loop, a little wider than tall.
    Repeater {
      model: calendar.markList
      delegate: Shape {
        id: loop
        required property var modelData
        width: Math.min(calendar.colW - 4, block.calRow * 1.25)
        height: block.calRow * 0.86
        x: calendar.cellX(modelData) + (calendar.colW - width) / 2
        y: calendar.cellY(modelData) + (block.calRow - height) / 2
        rotation: -8
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: Qt.alpha(block.editor.accent, 0.9)
          strokeWidth: 1.7
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          PathAngleArc {
            centerX: loop.width / 2
            centerY: loop.height / 2
            radiusX: loop.width / 2 - 1.5
            radiusY: loop.height / 2 - 1.5
            startAngle: -150
            sweepAngle: 385
          }
        }
      }
    }

    HoverHandler {
      id: calHover
      cursorShape: calendar.hoverDay > 0 && !block.editor.readOnly ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
    TapHandler {
      onTapped: function(eventPoint) {
        var d = calendar.dayAt(eventPoint.position.x, eventPoint.position.y)
        if (d > 0 && !block.editor.readOnly) block.editor.toggleMark(block.uid, d)
        else block.editor.selectBlocks(block.uid, block.uid)
      }
    }
  }

  // ---- blocks that aren't text ----------------------------------------------------------------

  // A divider: a thin line.
  Rectangle {
    visible: block.type === "divider"
    x: block.bx
    y: block.st.above + block.boxTop
    width: block.width - block.bx - block.boxRight
    height: 1
    color: Qt.alpha(block.editor.ink, 0.16)
  }

  // A page inside this page, or a link to one elsewhere: its icon and name.
  Rectangle {
    id: pageRow
    visible: block.type === "page" || block.type === "link"
    readonly property var page: {
      var r = block.editor.pagesRevision
      return visible ? block.editor.pageInfo(block.type === "page" ? block.uid : block.target) : null
    }
    x: block.bx - 2
    y: block.st.above + block.boxTop
    width: Math.min(block.width - x - block.boxRight, pageName.implicitWidth + 44)
    height: block.st.lineHeight + 4
    radius: 4
    color: pageHover.hovered ? Qt.alpha(block.editor.ink, 0.06) : "transparent"
    Text {
      textFormat: Text.PlainText
      x: 4
      anchors.verticalCenter: parent.verticalCenter
      text: pageRow.page && pageRow.page.icon ? pageRow.page.icon : "\u{1f4c4}"
      font.family: "Noto Color Emoji"
      font.pixelSize: Math.round(block.st.size * 1.05)
    }
    Text {
      textFormat: Text.PlainText
      visible: block.type === "link"
      x: 18
      y: parent.height / 2 + 1
      text: "\u2197"
      font.pixelSize: 10
      font.bold: true
      color: block.editor.ink
    }
    Text {
      id: pageName
      textFormat: Text.PlainText
      x: 32
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, parent.width - 36)
      elide: Text.ElideRight
      text: pageRow.page ? (pageRow.page.title || "Untitled") : "A page that isn't here"
      font.family: block.editor.family
      font.pixelSize: block.st.size
      font.weight: Font.Medium
      color: pageRow.page ? block.inkColor : Qt.alpha(block.editor.ink, 0.45)
      Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 1
        height: 1
        color: Qt.alpha(block.editor.ink, 0.25)
      }
    }
    HoverHandler { id: pageHover; cursorShape: Qt.PointingHandCursor }
    TapHandler {
      onTapped: {
        if (!pageRow.page) { block.editor.selectBlocks(block.uid, block.uid); return }
        block.editor.pageOpened(block.type === "page" ? block.uid : block.target)
      }
    }
  }
  // A link to a page, under the pointer: to another one (or, its page gone, to one that's here).
  Rectangle {
    objectName: "linkChange"
    visible: block.type === "link" && !block.editor.readOnly && (zoneHover.hovered || !pageRow.page)
    x: pageRow.x + pageRow.width + 4
    y: pageRow.y + (pageRow.height - height) / 2
    width: changeRow.implicitWidth + 14
    height: 24
    radius: 6
    color: changeTap.pressed ? Qt.alpha(block.editor.ink, 0.12) : Qt.alpha(block.editor.ink, 0.05)
    Row {
      id: changeRow
      anchors.centerIn: parent
      spacing: 5
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: block.editor.theme ? block.editor.theme.icons.edit : ""
        font.family: block.editor.theme ? block.editor.theme.iconFont : ""
        font.pixelSize: 11
        color: Qt.alpha(block.editor.ink, 0.6)
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: pageRow.page ? "Change" : "Link to a page"
        font.family: block.editor.uiFamily
        font.pixelSize: 12
        color: Qt.alpha(block.editor.ink, 0.6)
      }
    }
    TapHandler { id: changeTap; onTapped: block.editor.pageRelinkRequested(block.uid) }
  }

  // A table of contents: the page's headings, further in the smaller they
  // are; click one to go to it.
  Column {
    visible: block.type === "toc"
    x: block.bx
    y: block.st.above + block.boxTop
    width: block.width - block.bx - block.boxRight
    Text {
      textFormat: Text.PlainText
      visible: block.tocList.length === 0
      height: block.st.lineHeight
      verticalAlignment: Text.AlignVCenter
      text: "Headings on this page show here."
      font.family: block.editor.family
      font.pixelSize: block.st.size
      color: Qt.alpha(block.editor.ink, 0.4)
    }
    Repeater {
      model: block.tocList
      delegate: Item {
        required property var modelData
        width: parent.width
        height: block.st.lineHeight
        Text {
          textFormat: Text.PlainText
          x: (modelData.level - 1) * 18 + 2
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - x
          elide: Text.ElideRight
          text: modelData.text || "Untitled"
          font.family: block.editor.family
          font.pixelSize: block.st.size
          font.underline: tocHover.hovered
          color: Qt.alpha(block.editor.ink, 0.62)
        }
        HoverHandler { id: tocHover; cursorShape: Qt.PointingHandCursor }
        TapHandler { onTapped: block.editor.reveal(modelData.uid) }
      }
    }
  }

  // A picture, with rounded corners.
  Item {
    id: pictureFrame
    objectName: "pictureFrame"
    visible: block.type === "image"
    width: block.picW
    height: block.picH
    y: block.st.above + block.boxTop
    x: block.align === "left" ? block.bx : block.align === "right" ? block.width - block.boxRight - width : block.bx + (block.width - block.bx - block.boxRight - width) / 2

    Image {
      id: picture
      anchors.fill: parent
      source: block.type === "image" && block.src ? block.editor.assetUrl(block.src) : ""
      fillMode: Image.PreserveAspectFit
      asynchronous: true
      smooth: true
      mipmap: true
      onStatusChanged: {
        if (status === Image.Ready && block.ratio <= 0 && implicitHeight > 0)
          block.editor.setRatio(block.uid, implicitWidth / implicitHeight)
      }
    }
    Rectangle {
      visible: block.selected
      anchors.fill: parent
      anchors.margins: -3
      radius: 5
      color: "transparent"
      border.width: 2
      border.color: block.editor.accent
    }
    // Under the pointer: a handle on each side, dragged to size it (how wide
    // it is shown as it's dragged); a double-click, as wide as the page.
    HoverHandler { id: picHover; onHoveredChanged: block.pictureHovered = hovered }
    property bool sizing: leftSize.active || rightSize.active || cornerSize.active
    Repeater {
      model: block.type === "image" && !block.editor.readOnly ? ["left", "right"] : []
      delegate: Item {
        id: side
        required property string modelData
        readonly property bool isLeft: modelData === "left"
        objectName: "pictureSize" + (isLeft ? "Left" : "Right")
        visible: picHover.hovered || pictureFrame.sizing
        x: isLeft ? 0 : pictureFrame.width - width
        width: 22
        height: pictureFrame.height
        Rectangle {
          anchors.centerIn: parent
          width: 6
          height: Math.min(56, Math.max(24, pictureFrame.height * 0.3))
          radius: 3
          color: Qt.rgba(0.08, 0.08, 0.1, sizeDrag.active || sizeHover.hovered ? 0.85 : 0.6)
          border.width: 1
          border.color: Qt.rgba(1, 1, 1, 0.85)
        }
        HoverHandler { id: sizeHover; cursorShape: Qt.SizeHorCursor }
        DragHandler {
          id: sizeDrag
          target: null
          cursorShape: Qt.SizeHorCursor
          grabPermissions: PointerHandler.CanTakeOverFromAnything
          property real startWidth: 0
          onActiveChanged: {
            if (side.isLeft) leftSize.active = active
            else rightSize.active = active
            if (active) {
              startWidth = block.imgWidth || 0.6
              block.editor.beginResize(block.uid)
            } else {
              block.editor.endResize(block.uid)
            }
          }
          onTranslationChanged: {
            if (!active) return
            var factor = block.align === "center" ? 2 : 1
            var dx = side.isLeft ? -translation.x : translation.x
            var next = startWidth + dx * factor / Math.max(1, block.width - block.bx)
            block.editor.resizeImage(block.uid, Math.max(0.15, Math.min(1, next)))
          }
        }
        TapHandler {
          onDoubleTapped: {
            block.editor.beginResize(block.uid)
            block.editor.resizeImage(block.uid, 1)
            block.editor.endResize(block.uid)
          }
        }
      }
    }
    QtObject { id: leftSize; property bool active: false }
    QtObject { id: rightSize; property bool active: false }
    QtObject { id: cornerSize; property bool active: false }
    // How wide it is, while it's sized.
    Rectangle {
      objectName: "pictureSizeBadge"
      visible: pictureFrame.sizing
      anchors.horizontalCenter: parent.horizontalCenter
      y: 10
      width: sizeText.implicitWidth + 16
      height: 24
      radius: 12
      color: Qt.rgba(0.08, 0.08, 0.1, 0.85)
      Text {
        id: sizeText
        anchors.centerIn: parent
        textFormat: Text.PlainText
        text: Math.round((block.imgWidth || 0.6) * 100) + "%"
        font.family: block.editor.uiFamily
        font.pixelSize: 12
        color: "#f2f2f2"
      }
    }
    // Under the pointer (or picked): a handle at each corner, dragged any
    // way, it the size it's dragged to (as tall as its shape says).
    Repeater {
      model: block.type === "image" && !block.editor.readOnly ? ["tl", "tr", "bl", "br"] : []
      delegate: Item {
        id: corner
        required property string modelData
        readonly property int sx: modelData === "tr" || modelData === "br" ? 1 : -1
        readonly property int sy: modelData === "bl" || modelData === "br" ? 1 : -1
        objectName: "pictureCorner_" + modelData
        visible: picHover.hovered || cornerHover.hovered || pictureFrame.sizing || block.selected
        width: 22
        height: 22
        x: (sx > 0 ? pictureFrame.width : 0) - width / 2
        y: (sy > 0 ? pictureFrame.height : 0) - height / 2
        Rectangle {
          anchors.centerIn: parent
          width: cornerDrag.active || cornerHover.hovered ? 14 : 12
          height: width
          radius: width / 2
          color: block.editor.accent
          border.width: 2
          border.color: "white"
        }
        HoverHandler { id: cornerHover; cursorShape: corner.sx === corner.sy ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor }
        DragHandler {
          id: cornerDrag
          target: null
          cursorShape: corner.sx === corner.sy ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
          grabPermissions: PointerHandler.CanTakeOverFromAnything
          property real startWidth: 0
          onActiveChanged: {
            cornerSize.active = active
            if (active) {
              startWidth = block.imgWidth || 0.6
              block.editor.beginResize(block.uid)
            } else {
              block.editor.endResize(block.uid)
            }
          }
          onTranslationChanged: {
            if (!active) return
            // Across and down, each as width: the drag's way, half and half.
            var across = corner.sx * translation.x
            var down = corner.sy * translation.y * block.picRatio
            var factor = block.align === "center" ? 2 : 1
            var next = startWidth + (across + down) / 2 * factor / Math.max(1, block.width - block.bx)
            block.editor.resizeImage(block.uid, Math.max(0.15, Math.min(1, next)))
          }
        }
      }
    }
  }

  // A picked picture: how it sits, or out it goes.
  Rectangle {
    visible: block.type === "image" && block.selected && block.editor.selectedList.length === 1 && !block.editor.readOnly
    z: 10
    width: picRow.implicitWidth + 12
    height: 34
    radius: 17
    x: Math.max(0, Math.min(block.width - width, pictureFrame.x + (pictureFrame.width - width) / 2))
    y: pictureFrame.y + 8
    color: Qt.rgba(0.12, 0.12, 0.14, 0.92)
    Row {
      id: picRow
      anchors.centerIn: parent
      spacing: 2
      Repeater {
        model: [["left", "\u{f0262}"], ["center", "\u{f0260}"], ["right", "\u{f0263}"], ["open", "\u{f05da}"], ["remove", "\u{f0a7a}"]]
        delegate: Rectangle {
          required property var modelData
          width: 28
          height: 28
          radius: 14
          color: modelData[0] === block.align ? Qt.rgba(1, 1, 1, 0.16) : optHover.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: modelData[1]
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            color: modelData[0] === "remove" ? "#ff8a80" : "#f2f2f2"
          }
          HoverHandler { id: optHover; cursorShape: Qt.PointingHandCursor }
          TapHandler {
            onTapped: {
              var what = modelData[0]
              if (what === "remove") block.editor.removeBlocks([block.uid])
              else if (what === "open") block.editor.openPicture(block.src)
              else block.editor.setImageAlign(block.uid, what)
            }
          }
        }
      }
    }
  }

  // Blocks that aren't text are picked with a click (a calendar picks
  // itself, away from its dates).
  TapHandler {
    enabled: !block.isText && block.type !== "page" && block.type !== "link" && block.type !== "toc" && block.type !== "calendar" && block.type !== "mindmap" && block.type !== "table" && block.type !== "sketch" && block.type !== "audio" && block.type !== "meeting" && block.type !== "agenda" && block.type !== "event" && !Blocks.hasData(block.type)
    onTapped: block.editor.selectBlocks(block.uid, block.uid)
    onDoubleTapped: if (block.type === "image") block.editor.openPicture(block.src)
  }

  // ---- the handles beside it --------------------------------------------------------------------

  // While the pointer is over the block (or the room left of it): + for a
  // new block below it, and ⋮⋮ to drag it or, clicked, for its menu.
  // (A table's own pointer handling takes the table: only the topmost thing
  // under the pointer knows it's there.)
  Item {
    id: hoverZone
    x: block.bx - 56
    width: block.ownHover ? 56 : block.width - x
    height: block.height
    HoverHandler { id: zoneHover }
  }

  Row {
    id: handles
    visible: (zoneHover.hovered || grip.active || (block.ownHover && (block.contentHovered || plusHover.hovered || gripHover.hovered))) && !block.editor.readOnly && block.editor.dragUid === "" || block.dragged
    x: block.bx - 48
    y: (block.isText ? block.markY : block.st.above + block.boxTop + Math.min(block.contentH, 30) / 2) - height / 2
    spacing: 0
    height: 24

    Rectangle {
      width: 22
      height: 24
      radius: 4
      color: plusHover.hovered ? Qt.alpha(block.editor.ink, 0.08) : "transparent"
      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: "\u{f0415}"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 16
        color: Qt.alpha(block.editor.ink, 0.45)
      }
      HoverHandler { id: plusHover; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: block.editor.addBelow(block.uid) }
    }
    Rectangle {
      id: gripBox
      width: 18
      height: 24
      radius: 4
      color: gripHover.hovered || grip.active ? Qt.alpha(block.editor.ink, 0.08) : "transparent"
      Text {
        textFormat: Text.PlainText
        anchors.centerIn: parent
        text: "\u{f01dd}"
        font.family: "JetBrainsMono Nerd Font"
        font.pixelSize: 17
        color: Qt.alpha(block.editor.ink, 0.45)
      }
      HoverHandler { id: gripHover; cursorShape: grip.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor }
      TapHandler { onTapped: block.editor.blockMenuRequested(block.uid) }
      DragHandler {
        id: grip
        target: null
        dragThreshold: 4
        onActiveChanged: {
          if (active) block.editor.dragStart(block.uid)
          else block.editor.dragEnd(true)
        }
        onCentroidChanged: {
          if (!active) return
          var p = gripBox.mapToItem(block.parent, centroid.position.x, centroid.position.y)
          block.editor.dragMove(p.x, p.y)
        }
      }
    }
  }
}
