import QtQuick
import QtQuick.Effects

// Your agent at work, in a panel on the page (Claude Code, Grok or Codex,
// without a terminal): what you asked, each step as it takes it (reading the page,
// writing on it...), its answer as it's written, and how it ended. Then a
// reply, at its foot, goes on with it in the same conversation (what you said
// before, and it, above). Stop ends a turn: what it already changed stays,
// each change a step you can undo. When it couldn't work here, it says why,
// and Open in a terminal starts it the usual way. Closing it puts it away:
// the conversation's kept with its page, to go back to (show); New chat
// starts another.
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
  // What was said before, in this conversation: [{ request, steps, answer,
  // status, failure }], oldest first.
  property var history: []
  // A reply can go on with it (the view says).
  property bool canReply: false
  // What goes with your next message, said over the reply box ("2 blocks
  // you picked go with it").
  property string contextNote: ""
  // Gone back to (show): it says nothing of how long it took, then.
  property bool revived: false
  readonly property bool working: status === "working"
  readonly property int elapsed: Math.max(0, Math.round((now - startedAt) / 1000))

  signal stopRequested()
  signal terminalRequested()
  // What you said back, to go on with it.
  signal replied(string text)
  // Another conversation, instead of this one.
  signal newChatRequested()
  // Closed (not for a terminal instead).
  signal dismissed()

  objectName: "agentPanel"
  visible: false
  width: 400
  height: Math.min(head.height + body.implicitHeight + 1 + replyBar.height, maxHeight)

  function begin(label, req, choice) {
    agentLabel = label
    choiceText = choice || ""
    history = []
    replyField.text = ""
    contextNote = ""
    start(req)
    flick.contentY = 0
  }
  // A conversation gone back to: what was said (`turns`, oldest first: {
  // request, steps, answer, status, failure }), the last one as it ended,
  // and the reply box ready.
  function show(label, choice, turns) {
    var list = turns || []
    if (!list.length) return
    agentLabel = label
    choiceText = choice || ""
    replyField.text = ""
    history = list.slice(0, -1)
    var last = list[list.length - 1]
    request = last.request
    steps = last.steps || []
    answer = last.answer || ""
    failure = last.failure || ""
    status = last.status || "done"
    live = ""
    denied = []
    seconds = 0
    revived = true
    visible = true
    Qt.callLater(scrollDown)
  }
  // What was said, as it's kept: what went before, and this one as it is.
  function transcript() {
    return history.concat([{ request: request, steps: steps, answer: live !== "" ? live : answer, status: status, failure: failure }])
  }
  // (Only focused, nothing selected: a call that comes late can't take what
  // you've begun typing.)
  function focusReply() { if (replyBar.shown && !working && !replyField.input.activeFocus) replyField.input.forceActiveFocus() }
  // At work on this turn again (its conversation was lost, and it's asked
  // anew, told what was said).
  function again() {
    if (status === "working") return
    status = "working"
    failure = ""
    live = ""
  }
  // A reply: what was said so far goes above, and it's at work again.
  function next(req) {
    history = history.concat([{ request: request, steps: steps, answer: answer, status: status, failure: failure }])
    start(req)
    Qt.callLater(scrollDown)
  }
  function start(req) {
    revived = false
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
  }
  function sendReply() {
    var t = replyField.text.trim()
    if (!t || working) return
    // (Sent from its box: back in it when it's done, unless you're writing
    // somewhere else by then.)
    talking = replyField.input.activeFocus
    replyField.text = ""
    contextNote = ""
    replied(t)
  }
  property bool talking: false
  onWorkingChanged: {
    if (working || !talking) return
    talking = false
    var w = panel.Window.window
    var elsewhere = w && w.activeFocusItem && !panel.contains(panel.mapFromItem(w.activeFocusItem, 0, 0)) && typeof w.activeFocusItem.cursorPosition === "number"
    if (!elsewhere) focusReply()
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

  function close() {
    if (working || !visible) return
    visible = false
    dismissed()
  }
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
        : panel.revived ? ""
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
        objectName: "agentPanelNew"
        visible: !panel.working
        theme: panel.theme
        icon: panel.theme.icons.edit
        size: 30
        iconSize: 15
        tip: "New chat"
        onClicked: panel.newChatRequested()
      }
      IconButton {
        objectName: "agentPanelClose"
        visible: !panel.working
        theme: panel.theme
        icon: panel.theme.icons.close
        size: 30
        iconSize: 14
        tip: "Close  (Ctrl+J brings it back)"
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
    height: parent.height - y - replyBar.height
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

      // What was said before: each time, what you said, how many steps, its
      // answer.
      Repeater {
        model: panel.history
        delegate: Column {
          id: turn
          required property var modelData
          objectName: "agentPanelTurn"
          readonly property string request: modelData.request
          readonly property string answer: modelData.answer
          width: parent.width
          spacing: 6
          Text {
            width: parent.width
            maximumLineCount: 2
            elide: Text.ElideRight
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: "\u201c" + turn.modelData.request + "\u201d"
            font.family: panel.theme.uiFont
            font.pixelSize: 12
            color: panel.theme.muted
          }
          Text {
            visible: turn.modelData.steps.length > 0
            textFormat: Text.PlainText
            text: turn.modelData.steps.length + (turn.modelData.steps.length === 1 ? " step" : " steps")
            font.family: panel.theme.uiFont
            font.pixelSize: 11
            color: panel.theme.faint
          }
          Text {
            visible: text !== ""
            width: parent.width
            wrapMode: Text.Wrap
            textFormat: Text.MarkdownText
            text: turn.modelData.answer
            font.family: panel.theme.uiFont
            font.pixelSize: 13
            lineHeight: 1.2
            color: panel.theme.text
          }
          Text {
            visible: text !== ""
            width: parent.width
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: turn.modelData.status === "failed" ? turn.modelData.failure : turn.modelData.status === "stopped" ? "Stopped." : ""
            font.family: panel.theme.uiFont
            font.pixelSize: 12
            color: turn.modelData.status === "failed" ? panel.theme.urgent : panel.theme.muted
          }
          Item { width: 1; height: 4 }
          Rectangle { width: parent.width; height: 1; color: panel.theme.line; opacity: 0.6 }
          Item { width: 1; height: 4 }
        }
      }

      Text {
        objectName: "agentPanelRequest"
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

  // A reply, once it's done (or stopped, or couldn't finish): it goes on in
  // the same conversation. There all along (waiting while it works). Not
  // focused by itself: you may be writing on the page when it's done.
  Item {
    id: replyBar
    readonly property bool shown: panel.canReply && panel.status !== ""
    readonly property real noteHeight: panel.contextNote !== "" ? 20 : 0
    anchors.bottom: parent.bottom
    width: parent.width
    height: shown ? 52 + noteHeight : 0
    visible: shown
    Rectangle { width: parent.width; height: 1; color: panel.theme.line; opacity: 0.7 }
    Text {
      objectName: "agentPanelContext"
      visible: panel.contextNote !== ""
      x: 16
      y: 8
      width: parent.width - 32
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: panel.contextNote
      font.family: panel.theme.uiFont
      font.pixelSize: 11
      color: panel.theme.faint
    }
    Field {
      id: replyField
      objectName: "agentPanelReply"
      theme: panel.theme
      x: 12
      y: 9 + replyBar.noteHeight
      width: parent.width - 24 - sendButton.width - 6
      height: 34
      fontSize: 13
      maximumLength: 4000
      enabled: !panel.working
      opacity: enabled ? 1 : 0.55
      placeholder: panel.working ? panel.agentLabel + " is working\u2026" : "Reply to " + panel.agentLabel + "\u2026"
      onAccepted: panel.sendReply()
      onEscaped: text = ""
    }
    IconButton {
      id: sendButton
      objectName: "agentPanelSend"
      anchors.right: parent.right
      anchors.rightMargin: 12
      y: 10 + replyBar.noteHeight
      theme: panel.theme
      icon: panel.theme.icons.send
      size: 32
      iconSize: 16
      tip: "Send  Enter"
      active: !panel.working && replyField.text.trim() !== ""
      onClicked: panel.sendReply()
    }
  }
}
