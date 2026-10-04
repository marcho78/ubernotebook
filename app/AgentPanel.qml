import QtQuick
import QtQuick.Effects

// Your agent at work, in a panel on the page (Claude Code, Grok or Codex,
// without a terminal): what you asked, each step as it takes it (reading the page,
// writing on it...), its answer as it's written, and how it ended. Stop ends
// it: what it already changed stays, each change a step you can undo. When
// it couldn't work here, it says why, and Open in a terminal starts it the
// usual way.
Item {
  id: panel

  property var theme: null
  property string agentLabel: ""
  // The model and effort it works with ("Grok 4.7 Fast · Low"), or, once it
  // says, the model it started with.
  property string choiceText: ""
  property string request: ""
  // "" (nothing yet), "working", "done", "stopped" or "failed".
  property string status: ""
  property var steps: []
  property string answer: ""
  // Its answer as it's being written.
  property string live: ""
  property string failure: ""
  // What it wasn't allowed to do (tools' names).
  property var denied: []
  property real seconds: 0
  property real startedAt: 0
  property real now: 0
  property real maxHeight: 520
  readonly property bool working: status === "working"
  readonly property int elapsed: Math.max(0, Math.round((now - startedAt) / 1000))

  signal stopRequested()
  signal terminalRequested()

  objectName: "agentPanel"
  visible: false
  width: 400
  height: Math.min(head.height + body.implicitHeight + 1, maxHeight)

  function begin(label, req, choice) {
    agentLabel = label
    choiceText = choice || ""
    request = req
    status = "working"
    steps = []
    answer = ""
    live = ""
    failure = ""
    denied = []
    seconds = 0
    startedAt = Date.now()
    now = startedAt
    visible = true
    flick.contentY = 0
  }

  // What the agent said (Agent.fromClaude): a step, more of its answer, its
  // answer whole, how it ended.
  function take(ev) {
    if (!ev || status !== "working") return
    if (ev.kind === "start" && ev.model && (choiceText === "" || choiceText === "Default model")) choiceText = ev.model
    else if (ev.kind === "step") steps = steps.concat([ev.text])
    else if (ev.kind === "typing") live = ev.fresh ? ev.text : live + ev.text
    else if (ev.kind === "answer") { answer = ev.text; live = "" }
    else if (ev.kind === "done") {
      if (ev.text) answer = ev.text
      live = ""
      denied = ev.denied || []
      seconds = ev.seconds || Math.round((Date.now() - startedAt) / 100) / 10
      status = "done"
    } else if (ev.kind === "failed") {
      failure = ev.text
      live = ""
      status = "failed"
    }
    Qt.callLater(scrollDown)
  }

  // It's over (code -1: stopped); if it didn't say how, why.
  function end(code, why) {
    if (status !== "working") return
    live = ""
    if (code === -1) { status = "stopped"; return }
    failure = why
    status = "failed"
    Qt.callLater(scrollDown)
  }

  function close() { if (!working) visible = false }
  function scrollDown() { flick.contentY = Math.max(0, flick.contentHeight - flick.height) }

  Timer { interval: 1000; repeat: true; running: panel.working; onTriggered: panel.now = Date.now() }

  Rectangle { id: plate; anchors.fill: parent; radius: 12; color: panel.theme.surface; border.width: 1; border.color: panel.theme.line; visible: false }
  MultiEffect { source: plate; anchors.fill: plate; shadowEnabled: true; shadowColor: panel.theme.shadow; shadowBlur: 0.8; shadowVerticalOffset: 8; autoPaddingEnabled: true }

  // Who's working, how it's going; Stop, or close.
  Item {
    id: head
    width: parent.width
    height: 46
    Rectangle {
      id: dot
      x: 16
      anchors.verticalCenter: parent.verticalCenter
      width: 8
      height: 8
      radius: 4
      color: panel.status === "failed" ? panel.theme.urgent : panel.working ? panel.theme.accent : panel.theme.muted
      SequentialAnimation on opacity {
        running: panel.working
        loops: Animation.Infinite
        NumberAnimation { to: 0.25; duration: 650 }
        NumberAnimation { to: 1; duration: 650 }
        onStopped: dot.opacity = 1
      }
    }
    Text {
      id: who
      x: 32
      anchors.verticalCenter: parent.verticalCenter
      textFormat: Text.PlainText
      text: panel.agentLabel
      font.family: panel.theme.uiFont
      font.pixelSize: 14
      font.weight: Font.DemiBold
      color: panel.theme.text
    }
    Text {
      id: choiceLine
      objectName: "agentPanelChoice"
      anchors.left: who.right
      anchors.leftMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      width: Math.min(implicitWidth, Math.max(0, tools.x - x - 90))
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: panel.choiceText
      font.family: panel.theme.uiFont
      font.pixelSize: 12
      color: panel.theme.faint
    }
    Text {
      objectName: "agentPanelStatus"
      anchors.left: choiceLine.right
      anchors.leftMargin: 8
      anchors.right: tools.left
      anchors.rightMargin: 8
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: panel.working ? "working" + (panel.elapsed > 1 ? " · " + panel.elapsed + "s" : "…")
        : panel.status === "done" ? "done in " + panel.seconds + "s"
        : panel.status === "stopped" ? "stopped"
        : panel.status === "failed" ? "didn't finish" : ""
      font.family: panel.theme.uiFont
      font.pixelSize: 12
      color: panel.theme.muted
    }
    Row {
      id: tools
      anchors.right: parent.right
      anchors.rightMargin: 10
      anchors.verticalCenter: parent.verticalCenter
      TextButton {
        objectName: "agentPanelStop"
        visible: panel.working
        theme: panel.theme
        text: "Stop"
        onClicked: panel.stopRequested()
      }
      IconButton {
        objectName: "agentPanelClose"
        visible: !panel.working
        theme: panel.theme
        icon: panel.theme.icons.close
        size: 30
        iconSize: 14
        tip: "Close"
        onClicked: panel.close()
      }
    }
    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: panel.theme.line; opacity: 0.7 }
  }

  // What you asked, its steps, its answer, how it ended.
  Flickable {
    id: flick
    y: head.height
    width: parent.width
    height: parent.height - y
    contentHeight: body.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds

    Column {
      id: body
      x: 16
      width: flick.width - 32
      topPadding: 12
      bottomPadding: 14
      spacing: 6

      Text {
        width: parent.width
        maximumLineCount: 2
        elide: Text.ElideRight
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: "“" + panel.request + "”"
        font.family: panel.theme.uiFont
        font.pixelSize: 12
        color: panel.theme.muted
      }

      Item { width: 1; height: 2 }

      Text {
        visible: panel.working && panel.steps.length === 0 && panel.live === "" && panel.answer === ""
        textFormat: Text.PlainText
        text: "Starting " + panel.agentLabel + "…"
        font.family: panel.theme.uiFont
        font.pixelSize: 12
        color: panel.theme.faint
      }

      // Each step it took; the one it's on, while it works.
      Repeater {
        model: panel.steps
        delegate: Row {
          id: stepRow
          required property string modelData
          required property int index
          readonly property bool current: panel.working && index === panel.steps.length - 1 && panel.live === ""
          objectName: "agentPanelStep"
          readonly property string text: modelData
          width: parent.width
          spacing: 8
          Icon {
            anchors.verticalCenter: parent.verticalCenter
            theme: panel.theme
            text: stepRow.current ? panel.theme.icons.more : panel.theme.icons.check
            size: 12
            color: panel.theme.faint
          }
          Text {
            width: parent.width - 20
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: stepRow.modelData
            font.family: panel.theme.uiFont
            font.pixelSize: 12
            color: stepRow.current ? panel.theme.text : panel.theme.muted
          }
        }
      }

      // Its answer, as it's written, then whole.
      Text {
        objectName: "agentPanelAnswer"
        visible: text !== ""
        width: parent.width
        topPadding: panel.steps.length ? 6 : 0
        wrapMode: Text.Wrap
        textFormat: Text.MarkdownText
        text: panel.live !== "" ? panel.live : panel.answer
        font.family: panel.theme.uiFont
        font.pixelSize: 13
        lineHeight: 1.2
        color: panel.theme.text
      }

      Text {
        visible: panel.status === "done" && panel.denied.length > 0
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: "It wasn't allowed to use: " + panel.denied.join(", ") + "."
        font.family: panel.theme.uiFont
        font.pixelSize: 11
        color: panel.theme.faint
      }

      // It couldn't: why, and the usual way instead.
      Text {
        objectName: "agentPanelFailure"
        visible: panel.status === "failed"
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: panel.failure
        font.family: panel.theme.uiFont
        font.pixelSize: 12
        color: panel.theme.urgent
      }
      TextButton {
        objectName: "agentPanelTerminal"
        visible: panel.status === "failed"
        theme: panel.theme
        text: "Open in a terminal instead"
        onClicked: { panel.visible = false; panel.terminalRequested() }
      }

      Text {
        visible: panel.status === "stopped"
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: "Stopped. What it already changed stays: undo it like anything else."
        font.family: panel.theme.uiFont
        font.pixelSize: 12
        color: panel.theme.muted
      }
    }
  }
}
