import QtQuick
import QtQuick.Controls
import QtQuick.Shapes
import "../Html.js" as Html
import "../Blocks.js" as Blocks
import "../Papers.js" as Papers

// One block of a page. Text blocks (paragraphs, headings, list and checklist
// items, quotes, sticky notes, code, time slots, habits) are each their own
// rich-text editor; dividers, pictures and calendars are drawn. Editor.qml
// owns the page and decides what every key does; this block draws itself and
// reports what happens in it.
//
// Every block is a whole number of ruled lines tall, and each line of its
// text sits on a rule, so the lines on the paper and the writing always agree.
Item {
  id: block

  required property int index
  required property string uid
  required property string type
  required property int indent
  required property bool checked
  required property string align
  required property string tone
  required property string dstyle
  required property string src
  required property real imgWidth
  required property real ratio
  required property string label
  required property string days
  required property string month
  required property string marks
  required property string hint

  property var editor: null

  readonly property bool isText: Blocks.isText(type)
  readonly property bool listy: Blocks.isList(type)
  readonly property bool boxed: type === "callout" || type === "code"
  readonly property var st: Papers.typeStyle(type, editor.pen, editor.spacing)
  readonly property real pitch: editor.pitch
  // The biggest text in the block (px; 0 is its kind's own size). Text too
  // big for one ruled line takes two or more, like big writing in a real
  // notebook, so it never runs into the line above.
  property real maxPx: 0
  readonly property int lineRows: Math.max(st.rows, maxPx > 0 ? Math.ceil(maxPx / (0.84 * pitch)) : 1)
  readonly property real lineHeight: pitch * lineRows
  // A line n rows tall has its baseline at 4/5 of it; moving the text down by
  // this much puts it on the last rule of those rows instead.
  readonly property real shift: pitch * 0.2 * (lineRows - 1)
  readonly property real indentX: indent * editor.indentStep
  readonly property real markerW: type === "time" ? editor.timeGutter : listy ? editor.gutter : 0
  readonly property real textX: indentX + markerW + (boxed ? editor.boxPad : 0) + (type === "quote" ? editor.quotePad : 0)
  // A habit's seven days, as circles at the end of its line.
  readonly property real dot: Math.round(pitch * 0.68)
  readonly property real dotGap: Math.round(pitch * 0.2)
  readonly property real daysW: 7 * dot + 6 * dotGap
  readonly property real habitW: type === "habit" ? daysW + pitch * 0.6 : 0
  readonly property real textW: Math.max(40, width - textX - (boxed ? editor.boxPad : 0) - habitW)
  // A calendar: a row for the month, one for the days of the week, one a week.
  readonly property var cal: type === "calendar" ? Blocks.monthLayout(month) : ({ offset: 0, days: 0, weeks: 0 })
  readonly property real textBaseline: shift + lineHeight * 0.8
  readonly property int textRows: Math.max(lineRows, Math.ceil((textEdit.contentHeight - 1) / lineHeight) * lineRows)
  readonly property real picW: Math.max(40, editor.contentWidth * Math.max(0.15, Math.min(1, imgWidth || 0.6)))
  readonly property real picRatio: ratio > 0 ? ratio : (picture.implicitHeight > 0 ? picture.implicitWidth / picture.implicitHeight : 1.5)
  readonly property real picH: picW / picRatio
  readonly property int imageRows: Math.max(2, Math.ceil((picH + pitch * 0.7) / pitch))
  readonly property int rows: isText ? textRows : type === "image" ? imageRows : type === "calendar" ? 2 + cal.weeks : 1
  readonly property bool selected: editor.selectedMap[uid] === true
  readonly property bool focused: textEdit.activeFocus
  readonly property var matches: editor.findMatches[uid] || []

  property alias edit: textEdit
  property bool dirty: false
  property bool loading: false

  width: editor.contentWidth
  height: rows * pitch

  // ---- loading the text -------------------------------------------------------

  // Puts the stored text into the editor, keeping the cursor where it was.
  // How big its biggest text is (from its stored text).
  function measure(inner) {
    maxPx = Html.maxSize(inner || "")
  }

  function reload() {
    if (!isText) return
    var had = textEdit.activeFocus
    var pos = textEdit.cursorPosition
    loading = true
    measure(editor.htmls[uid] || "")
    textEdit.text = Html.wrapBlock(editor.display(editor.htmls[uid] || ""), lineHeight, editor.linkColor)
    loading = false
    dirty = false
    if (had) textEdit.cursorPosition = Math.min(pos, textEdit.length)
    strikes.refresh()
  }

  onLineHeightChanged: if (!loading && textEdit.text !== "") { editor.syncBlock(uid); reload() }
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

  // ---- behind the text ----------------------------------------------------------

  // Picked as a block (Esc, Shift+arrows, or dragging across blocks).
  Rectangle {
    visible: block.selected
    x: block.indentX - 6
    y: 2
    width: block.width - x + 6
    height: block.height - 2
    radius: 5
    color: Qt.alpha(block.editor.accent, 0.13)
    border.width: 1
    border.color: Qt.alpha(block.editor.accent, 0.35)
  }

  // A sticky note, or a code block's box, around the text but inside its rows.
  Rectangle {
    visible: block.boxed
    x: block.indentX
    y: block.pitch * 0.16
    width: block.width - block.indentX
    height: block.height - y + block.pitch * 0.1
    radius: block.type === "code" ? 6 : 3
    color: block.type === "code"
      ? Qt.alpha(block.editor.ink, block.editor.dark ? 0.08 : 0.055)
      : Papers.toneColor(block.tone, block.editor.dark)
    border.width: block.type === "code" ? 1 : 0
    border.color: Qt.alpha(block.editor.ink, 0.1)

    // A sticky note's corner, curling up a little.
    Shape {
      visible: block.type === "callout"
      anchors.right: parent.right
      anchors.bottom: parent.bottom
      width: 14
      height: 14
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeWidth: 0
        strokeColor: "transparent"
        fillColor: Qt.darker(Papers.toneColor(block.tone, block.editor.dark), block.editor.dark ? 0.8 : 1.12)
        startX: 14; startY: 0
        PathLine { x: 0; y: 14 }
        PathLine { x: 14; y: 14 }
        PathLine { x: 14; y: 0 }
      }
    }
  }

  // A quote's bar.
  Rectangle {
    visible: block.type === "quote"
    x: block.indentX + 3
    y: block.pitch * 0.22
    width: 3
    radius: 1.5
    height: block.height - y + block.pitch * 0.02
    color: Qt.alpha(block.editor.accent, 0.7)
  }

  // Found text (Find in page).
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

  // ---- the marker before a list item ------------------------------------------------

  // Bullets: a dot, a ring, then a square, by how deep the item is.
  Rectangle {
    visible: block.type === "bullet"
    readonly property real size: Math.max(5, Math.round(block.st.size * 0.3))
    readonly property int level: block.indent % 3
    width: size
    height: size
    radius: level === 2 ? 1 : size / 2
    x: block.indentX + block.markerW * 0.42 - size / 2
    y: block.textBaseline - block.st.size * 0.3 - size / 2
    color: level === 1 ? "transparent" : block.editor.ink
    border.width: level === 1 ? 1.5 : 0
    border.color: block.editor.ink
    opacity: 0.85
  }

  // Numbers: 1. then a. then i.
  Text {
    textFormat: Text.PlainText
    visible: block.type === "number"
    text: block.editor.numbers[block.uid] || "1."
    x: block.indentX
    width: block.markerW - block.pitch * 0.22
    y: block.textBaseline - baselineOffset
    horizontalAlignment: Text.AlignRight
    font.family: block.editor.family
    font.pixelSize: block.st.size
    font.features: { "tnum": 1 }
    color: block.editor.ink
    opacity: 0.85
  }

  // Checkboxes, ticked by hand.
  Item {
    id: box
    visible: block.type === "check"
    readonly property real size: Math.max(12, Math.round(block.st.size * 0.8))
    width: size
    height: size
    x: block.indentX + block.markerW * 0.42 - size / 2
    y: block.textBaseline - size + 1

    Rectangle {
      anchors.fill: parent
      radius: 3.5
      color: block.checked ? Qt.alpha(block.editor.accent, 0.14) : "transparent"
      border.width: 1.6
      border.color: Qt.alpha(block.editor.ink, block.checked ? 0.55 : 0.75)
      Behavior on color { ColorAnimation { duration: 140 } }
    }

    Shape {
      id: tick
      width: box.size * 1.25
      height: box.size * 1.25
      x: box.size * 0.05
      y: -box.size * 0.3
      preferredRendererType: Shape.CurveRenderer
      opacity: block.checked ? 1 : 0
      scale: block.checked ? 1 : 0.4
      transformOrigin: Item.BottomLeft
      Behavior on opacity { NumberAnimation { duration: 140 } }
      Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
      ShapePath {
        strokeColor: block.editor.accent
        strokeWidth: Math.max(2, box.size * 0.16)
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        joinStyle: ShapePath.RoundJoin
        startX: tick.width * 0.12; startY: tick.height * 0.58
        PathQuad { x: tick.width * 0.36; y: tick.height * 0.86; controlX: tick.width * 0.26; controlY: tick.height * 0.7 }
        PathQuad { x: tick.width * 0.94; y: tick.height * 0.08; controlX: tick.width * 0.55; controlY: tick.height * 0.36 }
      }
    }

    TapHandler {
      margin: 6
      cursorShape: Qt.PointingHandCursor
      onTapped: block.editor.toggleCheck(block.uid)
    }
  }

  // ---- the text ----------------------------------------------------------------------

  TextEdit {
    id: textEdit
    visible: block.isText
    enabled: block.isText
    x: block.textX
    y: block.shift
    width: block.textW
    textFormat: TextEdit.RichText
    wrapMode: TextEdit.Wrap
    readOnly: block.editor.readOnly
    selectByMouse: true
    persistentSelection: true
    font.family: block.st.mono ? block.editor.monoFamily : block.editor.family
    font.pixelSize: block.st.size
    font.bold: block.st.bold
    font.italic: block.st.italic
    font.capitalization: block.st.caps ? Font.AllUppercase : Font.MixedCase
    font.letterSpacing: block.st.caps ? 1.2 : 0
    color: block.type === "quote" ? Qt.alpha(block.editor.ink, 0.86) : block.editor.ink
    selectionColor: block.editor.selectionColor
    selectedTextColor: block.editor.ink
    horizontalAlignment: block.align === "center" ? TextEdit.AlignHCenter
      : block.align === "right" ? TextEdit.AlignRight
      : block.align === "justify" ? TextEdit.AlignJustify : TextEdit.AlignLeft
    tabStopDistance: block.pitch * 2
    opacity: block.type === "check" && block.checked ? 0.5 : 1
    Behavior on opacity { NumberAnimation { duration: 160 } }

    Keys.onPressed: function(event) { block.editor.onKey(block, event) }

    onTextChanged: {
      if (block.loading) return
      block.dirty = true
      block.editor.edited(block)
      strikes.refresh()
    }
    onCursorRectangleChanged: if (activeFocus) block.editor.cursorMovedIn(block)
    onSelectionStartChanged: if (activeFocus) block.editor.selectionChangedIn(block)
    onSelectionEndChanged: if (activeFocus) block.editor.selectionChangedIn(block)
    onActiveFocusChanged: block.editor.focusChangedIn(block, activeFocus)
    onWidthChanged: strikes.refresh()

    // A middle click pastes what's selected, the way Ctrl+V pastes (not Qt's
    // own paste, which loads the pictures the selection's HTML names).
    MouseArea {
      anchors.fill: parent
      enabled: !textEdit.readOnly
      acceptedButtons: Qt.MiddleButton
      onClicked: function(mouse) { block.editor.pastePrimary(block, mouse.x, mouse.y) }
    }

    // Ctrl+click opens a link; Ctrl+hover shows it can.
    HoverHandler {
      id: hover
      cursorShape: (hover.point.modifiers & Qt.ControlModifier) && textEdit.linkAt(hover.point.position.x, hover.point.position.y) !== ""
        ? Qt.PointingHandCursor : Qt.IBeamCursor
    }
    TapHandler {
      acceptedModifiers: Qt.ControlModifier
      onTapped: function(eventPoint) {
        var link = textEdit.linkAt(eventPoint.position.x, eventPoint.position.y)
        if (link) block.editor.openLink(link)
      }
    }
  }

  // Checked items are crossed off, one stroke per line.
  Item {
    id: strikes
    visible: block.type === "check" && block.checked && block.editor.strikeDone
    x: textEdit.x
    y: textEdit.y
    property var spans: []

    function refresh() {
      if (!(block.type === "check" && block.checked)) { if (spans.length) spans = []; return }
      var out = []
      for (var i = 0; i < textEdit.lineCount && i < 60; i++) {
        var y = i * block.lineHeight + block.lineHeight * 0.6
        var a = textEdit.positionToRectangle(textEdit.positionAt(0, y))
        var b = textEdit.positionToRectangle(textEdit.positionAt(textEdit.width + 10, y))
        if (b.x - a.x > 2) out.push({ x: a.x, w: b.x - a.x, y: i * block.lineHeight + block.lineHeight * 0.8 - block.st.size * 0.3 })
      }
      spans = out
    }

    Repeater {
      model: strikes.spans
      delegate: Shape {
        required property var modelData
        x: modelData.x - 2
        y: modelData.y - 3
        width: modelData.w + 4
        height: 6
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
          strokeColor: Qt.alpha(block.editor.ink, 0.62)
          strokeWidth: 1.4
          fillColor: "transparent"
          capStyle: ShapePath.RoundCap
          startX: 0; startY: 3.6
          PathQuad { x: modelData.w + 4; y: 2.4; controlX: (modelData.w + 4) * 0.5; controlY: 2.2 }
        }
      }
    }
  }

  onCheckedChanged: strikes.refresh()
  onTypeChanged: strikes.refresh()

  // What an empty block of a template is for, written faintly.
  Text {
    textFormat: Text.PlainText
    visible: block.isText && block.hint !== "" && textEdit.length === 0 && textEdit.preeditText === ""
    x: textEdit.x
    y: block.textBaseline - baselineOffset
    width: textEdit.width
    elide: Text.ElideRight
    horizontalAlignment: textEdit.horizontalAlignment
    text: block.hint
    font: textEdit.font
    color: Qt.alpha(block.editor.ink, 0.3)
  }

  // ---- time slots ----------------------------------------------------------------

  // The time (or the day) in the margin, and a rule between it and the text:
  // slots one under another make a schedule. Click the time to change it.
  Rectangle {
    visible: block.type === "time"
    x: block.indentX + block.markerW - Math.round(block.pitch * 0.3)
    width: 1
    height: block.height
    color: Qt.alpha(block.editor.accent, 0.35)
  }

  TextInput {
    id: labelInput
    visible: block.type === "time"
    enabled: visible && !block.editor.readOnly
    x: block.indentX
    width: block.markerW - Math.round(block.pitch * 0.55)
    y: block.textBaseline - baselineOffset
    horizontalAlignment: TextInput.AlignRight
    text: block.label
    maximumLength: 12
    selectByMouse: true
    font.family: block.editor.family
    font.pixelSize: Math.round(block.st.size * 0.8)
    font.features: { "tnum": 1 }
    color: Qt.alpha(block.editor.ink, 0.62)
    selectionColor: block.editor.selectionColor
    selectedTextColor: block.editor.ink
    onEditingFinished: block.editor.setLabel(block.uid, text)
    Keys.onPressed: function(e) {
      if (e.key === Qt.Key_Escape) {
        e.accepted = true
        labelInput.text = Qt.binding(function() { return block.label })
        block.editor.focusBlock(block.uid, -1)
      } else if (e.key === Qt.Key_Return || e.key === Qt.Key_Enter || e.key === Qt.Key_Tab) {
        e.accepted = true
        block.editor.setLabel(block.uid, labelInput.text)
        block.editor.focusBlock(block.uid, -1)
      }
    }

    Text {
      textFormat: Text.PlainText
      visible: labelInput.text === "" && !labelInput.activeFocus
      anchors.right: parent.right
      text: "\u2013:\u2013\u2013"
      font: labelInput.font
      color: Qt.alpha(block.editor.ink, 0.25)
    }
    HoverHandler { cursorShape: Qt.IBeamCursor }
  }

  // ---- habits --------------------------------------------------------------------

  // A circle for each day of the week, Monday first: ticked when it's done.
  Row {
    id: habitDays
    visible: block.type === "habit"
    x: block.width - block.daysW
    y: block.textBaseline - block.st.size * 0.32 - block.dot / 2
    spacing: block.dotGap
    Repeater {
      model: block.type === "habit" ? 7 : 0
      delegate: Item {
        id: day
        required property int index
        readonly property bool done: block.days.charAt(index) === "1"
        width: block.dot
        height: block.dot
        Rectangle {
          anchors.fill: parent
          radius: width / 2
          color: day.done ? Qt.alpha(block.editor.accent, 0.16) : dayHover.hovered ? Qt.alpha(block.editor.ink, 0.06) : "transparent"
          border.width: 1.4
          border.color: day.done ? Qt.alpha(block.editor.accent, 0.8) : Qt.alpha(block.editor.ink, 0.38)
          Behavior on color { ColorAnimation { duration: 140 } }
        }
        Text {
          textFormat: Text.PlainText
          anchors.centerIn: parent
          visible: !day.done
          text: Qt.locale().dayName((day.index + 1) % 7, Locale.NarrowFormat)
          font.family: block.editor.uiFamily
          font.pixelSize: Math.max(9, Math.round(block.dot * 0.46))
          color: Qt.alpha(block.editor.ink, 0.5)
        }
        Shape {
          id: dayTick
          anchors.fill: parent
          anchors.margins: -block.dot * 0.08
          preferredRendererType: Shape.CurveRenderer
          opacity: day.done ? 1 : 0
          scale: day.done ? 1 : 0.4
          Behavior on opacity { NumberAnimation { duration: 140 } }
          Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
          ShapePath {
            strokeColor: block.editor.accent
            strokeWidth: Math.max(1.8, block.dot * 0.13)
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            startX: dayTick.width * 0.24; startY: dayTick.height * 0.54
            PathQuad { x: dayTick.width * 0.43; y: dayTick.height * 0.74; controlX: dayTick.width * 0.34; controlY: dayTick.height * 0.62 }
            PathQuad { x: dayTick.width * 0.78; y: dayTick.height * 0.26; controlX: dayTick.width * 0.58; controlY: dayTick.height * 0.44 }
          }
        }
        HoverHandler { id: dayHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
          margin: block.dotGap / 2
          onTapped: block.editor.toggleDay(block.uid, day.index)
        }
      }
    }
  }

  // ---- dividers --------------------------------------------------------------------

  Item {
    visible: block.type === "divider"
    anchors.fill: parent

    // A line drawn across, thinning out at both ends.
    Rectangle {
      visible: block.dstyle === "line"
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -block.pitch * 0.08
      x: parent.width * 0.06
      width: parent.width * 0.88
      height: 1.5
      gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0.0; color: Qt.alpha(block.editor.ink, 0) }
        GradientStop { position: 0.2; color: Qt.alpha(block.editor.ink, 0.45) }
        GradientStop { position: 0.8; color: Qt.alpha(block.editor.ink, 0.45) }
        GradientStop { position: 1.0; color: Qt.alpha(block.editor.ink, 0) }
      }
    }

    Text {
      textFormat: Text.PlainText
      visible: block.dstyle === "dots"
      anchors.horizontalCenter: parent.horizontalCenter
      y: block.textBaseline - baselineOffset
      text: "\u2022   \u2022   \u2022"
      font.family: block.editor.family
      font.pixelSize: block.st.size
      color: Qt.alpha(block.editor.ink, 0.55)
    }

    Shape {
      visible: block.dstyle === "wave"
      anchors.verticalCenter: parent.verticalCenter
      anchors.verticalCenterOffset: -block.pitch * 0.08
      x: parent.width * 0.3
      width: parent.width * 0.4
      height: 8
      preferredRendererType: Shape.CurveRenderer
      ShapePath {
        strokeColor: Qt.alpha(block.editor.ink, 0.5)
        strokeWidth: 1.6
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        startX: 0; startY: 4
        PathCubic { x: parent.width * 0.25; y: 4; control1X: parent.width * 0.08; control1Y: 0; control2X: parent.width * 0.17; control2Y: 8 }
        PathCubic { x: parent.width * 0.5; y: 4; control1X: parent.width * 0.33; control1Y: 0; control2X: parent.width * 0.42; control2Y: 8 }
        PathCubic { x: parent.width * 0.75; y: 4; control1X: parent.width * 0.58; control1Y: 0; control2X: parent.width * 0.67; control2Y: 8 }
        PathCubic { x: parent.width; y: 4; control1X: parent.width * 0.83; control1Y: 0; control2X: parent.width * 0.92; control2Y: 8 }
      }
    }
  }

  // ---- a month's calendar -----------------------------------------------------------

  // The month's name, the days of the week, and the dates, Monday first,
  // each on a rule. Today has a dot of color; click a date to circle it.
  Item {
    id: calendar
    visible: block.type === "calendar"
    width: block.width
    height: block.height
    readonly property real colW: width / 7
    readonly property var first: new Date(Number(block.month.slice(0, 4)), Number(block.month.slice(5, 7)) - 1, 1)
    readonly property var now: new Date()
    readonly property int today: block.type === "calendar" && now.getFullYear() === first.getFullYear() && now.getMonth() === first.getMonth() ? now.getDate() : 0
    readonly property real numberSize: Math.round(block.st.size * 0.86)
    readonly property var markList: block.marks === "" ? [] : block.marks.split(",").map(Number).filter(function(d) { return d <= block.cal.days })

    function dayAt(x, y) {
      var row = Math.floor(y / block.pitch) - 2
      var col = Math.floor(x / colW)
      if (row < 0 || col < 0 || col > 6) return 0
      var d = row * 7 + col - block.cal.offset + 1
      return d >= 1 && d <= block.cal.days ? d : 0
    }
    function centerX(d) { return ((d - 1 + block.cal.offset) % 7 + 0.5) * colW }
    function baseY(d) { return (2 + Math.floor((d - 1 + block.cal.offset) / 7)) * block.pitch + block.textBaseline }

    Text {
      textFormat: Text.PlainText
      x: calendar.colW * 0.5 - block.dot * 0.3
      y: block.textBaseline - baselineOffset
      text: block.type === "calendar" ? Qt.formatDate(calendar.first, "MMMM yyyy") : ""
      font.family: block.editor.uiFamily
      font.pixelSize: Math.max(10, Math.round(block.st.size * 0.7))
      font.capitalization: Font.AllUppercase
      font.letterSpacing: 1.2
      font.weight: Font.DemiBold
      color: Qt.alpha(block.editor.ink, 0.6)
    }

    // Earlier and later months, while the pointer is over it.
    Row {
      anchors.right: parent.right
      y: block.textBaseline - block.st.size * 0.32 - height / 2
      visible: (calHover.hovered || block.selected) && !block.editor.readOnly
      spacing: 2
      Repeater {
        model: [[-1, "\u{f0141}", "The month before"], [1, "\u{f0142}", "The month after"]]
        delegate: Rectangle {
          required property var modelData
          width: block.pitch * 0.9
          height: block.pitch * 0.9
          radius: width / 2
          color: arrowHover.hovered ? Qt.alpha(block.editor.ink, 0.08) : "transparent"
          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: modelData[1]
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: Math.round(block.pitch * 0.6)
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
        width: calendar.colW
        y: block.pitch + block.textBaseline - baselineOffset
        horizontalAlignment: Text.AlignHCenter
        text: Qt.locale().dayName((index + 1) % 7, Locale.NarrowFormat)
        font.family: block.editor.uiFamily
        font.pixelSize: Math.max(10, Math.round(block.st.size * 0.66))
        font.letterSpacing: 0.6
        color: Qt.alpha(block.editor.ink, index >= 5 ? 0.42 : 0.55)
      }
    }

    // Today.
    Rectangle {
      visible: calendar.today > 0
      width: block.pitch * 0.84
      height: width
      radius: width / 2
      x: calendar.centerX(calendar.today) - width / 2
      y: calendar.baseY(calendar.today) - calendar.numberSize * 0.36 - height / 2
      color: Qt.alpha(block.editor.accent, 0.2)
    }

    Repeater {
      model: block.type === "calendar" ? block.cal.days : 0
      delegate: Text {
        required property int index
        readonly property int day: index + 1
        textFormat: Text.PlainText
        x: calendar.centerX(day) - calendar.colW / 2
        width: calendar.colW
        y: calendar.baseY(day) - baselineOffset
        horizontalAlignment: Text.AlignHCenter
        text: day
        font.family: block.editor.family
        font.pixelSize: calendar.numberSize
        font.features: { "tnum": 1 }
        font.bold: day === calendar.today
        color: day === calendar.today ? block.editor.accent
          : Qt.alpha(block.editor.ink, (day - 1 + block.cal.offset) % 7 >= 5 ? 0.6 : 0.85)
      }
    }

    // Circled days: a pen's loop, a little wider than tall, around the date.
    Repeater {
      model: calendar.markList
      delegate: Shape {
        id: loop
        required property var modelData
        width: block.pitch * 1.12
        height: block.pitch * 0.9
        x: calendar.centerX(modelData) - width / 2
        y: calendar.baseY(modelData) - calendar.numberSize * 0.36 - height / 2
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

    HoverHandler { id: calHover }
    HoverHandler {
      cursorShape: calendar.dayAt(point.position.x, point.position.y) > 0 ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
    TapHandler {
      onTapped: function(eventPoint) {
        var d = calendar.dayAt(eventPoint.position.x, eventPoint.position.y)
        if (d > 0 && !block.editor.readOnly) block.editor.toggleMark(block.uid, d)
        else block.editor.selectBlocks(block.uid, block.uid)
      }
    }
  }

  // ---- pictures ------------------------------------------------------------------------

  Item {
    id: pictureFrame
    visible: block.type === "image"
    width: block.picW
    height: block.picH
    y: block.pitch * 0.35
    x: block.align === "left" ? 0 : block.align === "right" ? block.width - width : (block.width - width) / 2

    // A soft shadow, as if the photo lay on the page.
    Rectangle {
      anchors.fill: parent
      anchors.topMargin: 3
      anchors.leftMargin: 2
      anchors.rightMargin: -2
      anchors.bottomMargin: -4
      radius: 4
      color: Qt.rgba(0, 0, 0, block.editor.dark ? 0.35 : 0.14)
    }

    Rectangle {
      anchors.fill: parent
      radius: 3
      color: block.editor.dark ? "#2a2c31" : "#ffffff"
      clip: true
      Image {
        id: picture
        anchors.fill: parent
        anchors.margins: 4
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
    }

    // Two strips of washi tape hold it down.
    Repeater {
      model: 2
      delegate: Rectangle {
        required property int index
        width: Math.min(64, pictureFrame.width * 0.28)
        height: 17
        x: index === 0 ? -width * 0.28 : pictureFrame.width - width * 0.72
        y: -5
        rotation: index === 0 ? -34 : 31
        color: Qt.alpha(index === 0 ? "#f3c6a5" : "#b9d7c9", 0.78)
        antialiasing: true
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

    // Drag the corner to size it.
    Rectangle {
      id: grip
      visible: block.selected && !block.editor.readOnly
      width: 14
      height: 14
      radius: 7
      x: parent.width - 7
      y: parent.height - 7
      color: block.editor.accent
      border.width: 2
      border.color: "white"
      DragHandler {
        id: sizer
        target: null
        cursorShape: Qt.SizeFDiagCursor
        property real startWidth: 0
        onActiveChanged: {
          if (active) {
            startWidth = block.imgWidth
            block.editor.beginResize(block.uid)
          } else {
            block.editor.endResize(block.uid)
          }
        }
        onTranslationChanged: {
          if (!active) return
          var factor = block.align === "center" ? 2 : 1
          var next = startWidth + translation.x * factor / Math.max(1, block.editor.contentWidth)
          block.editor.resizeImage(block.uid, Math.max(0.15, Math.min(1, next)))
        }
      }
    }
  }

  // A picked picture or divider: how it sits, or out it goes (a picture:
  // large, copied, a copy saved). Its buttons are there while it shows.
  Rectangle {
    id: blockBar
    visible: block.selected && !block.isText && block.editor.selectedList.length === 1 && !block.editor.readOnly
    z: 10
    width: barRow.implicitWidth + 12
    height: 34
    radius: 17
    x: block.type === "image" ? Math.max(0, Math.min(block.width - width, pictureFrame.x + (pictureFrame.width - width) / 2)) : (block.width - width) / 2
    y: block.type === "image" ? pictureFrame.y - height - 8 : -height - 4
    color: Qt.rgba(0.12, 0.12, 0.14, 0.92)
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)

    Row {
      id: barRow
      anchors.centerIn: parent
      spacing: 2
      Repeater {
        model: !blockBar.visible ? [] : block.type === "image"
          ? [["left", "\u{f0262}", "Left"], ["center", "\u{f0260}", "Centered"], ["right", "\u{f0263}", "Right"], ["open", "\u{f05da}", "Open it"],
            ["copy", "\u{f018f}", "Copy"], ["save", "\u{f01da}", "Save a copy\u2026"], ["remove", "\u{f0a7a}", "Remove"]]
          : block.type === "calendar"
          ? [["earlier", "\u{f0141}", "The month before"], ["now", "\u{f00f6}", "This month"], ["later", "\u{f0142}", "The month after"], ["remove", "\u{f0a7a}", "Remove"]]
          : [["line", "\u{f0374}", "A line"], ["dots", "\u{f01d8}", "Dots"], ["wave", "\u{f095b}", "A wave"], ["remove", "\u{f0a7a}", "Remove"]]
        delegate: Rectangle {
          required property var modelData
          readonly property bool on: modelData[0] === block.align || modelData[0] === block.dstyle
          width: 28
          height: 28
          radius: 14
          color: on ? Qt.rgba(1, 1, 1, 0.16) : optHover.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
          Text {
            textFormat: Text.PlainText
            anchors.centerIn: parent
            text: modelData[1]
            font.family: "JetBrainsMono Nerd Font"
            font.pixelSize: 15
            color: modelData[0] === "remove" ? "#ff8a80" : "#f2f2f2"
          }
          HoverHandler { id: optHover; cursorShape: Qt.PointingHandCursor }
          ToolTip.visible: optHover.hovered
          ToolTip.delay: 600
          ToolTip.text: modelData[2]
          // (The click is the button's alone: what's picked stays picked.)
          TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: {
              var what = modelData[0]
              if (what === "remove") block.editor.removeBlocks([block.uid])
              else if (what === "open") block.editor.openPicture(block.src)
              else if (what === "copy") block.editor.copyPicture(block.src)
              else if (what === "save") block.editor.savePicture(block.src)
              else if (block.type === "calendar") block.editor.shiftMonth(block.uid, what === "earlier" ? -1 : what === "later" ? 1 : 0)
              else if (block.type === "image") block.editor.setImageAlign(block.uid, what)
              else block.editor.setDivider(block.uid, what)
            }
          }
        }
      }
    }
  }

  // Dividers and pictures are picked with a click (a calendar picks itself
  // where there's no date).
  TapHandler {
    enabled: !block.isText && block.type !== "calendar"
    onTapped: block.editor.selectBlocks(block.uid, block.uid)
    onDoubleTapped: if (block.type === "image") block.editor.openPicture(block.src)
  }
}
