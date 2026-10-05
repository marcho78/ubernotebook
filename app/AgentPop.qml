import QtQuick
import QtQuick.Controls
import "../Agent.js" as Agent

// Ask your agent (Ctrl+J, "/agent", a block's menu, the toolbar over selected
// words, the page's ⋯ menu): what you'd like done with this page, the blocks
// you picked, the words you selected, or the line you're on; or a new page
// (the switch at the top; with no page open, Ctrl+J, a new page only), at
// the top of Pages or inside the page you're on. Omarchy's default coding
// agent does it (whichever `omarchy default agent` chose), through Uber
// Notebook's commands, so what it changes shows up here as it goes.
Pop {
  id: pop

  // Store.qml: defaultAgent, listAgents, setDefaultAgent.
  property var files: null
  // The agents installed here, Omarchy's: [{ name, label }].
  property var agents: []
  // The default agent's name as Omarchy keeps it ("claude"...), "" for none,
  // once `known`.
  property string agent: ""
  property bool known: false
  // What it's asked about: { scope, blocks, words, line } (Agent.prompt);
  // scope "new" with no page open.
  property var ask: ({ scope: "page", blocks: [], words: "", line: "" })
  // The page you're on, { id, title, locked }, or null.
  property var onPage: null
  // What you're on ("here") or a new page ("new"); a new page goes at the
  // top of Pages, as Ctrl+N makes one ("top"), or inside the page you're on
  // ("inside").
  property string mode: "here"
  property string place: "top"
  // The service: the model and effort each agent works with here (settings).
  property var service: null
  readonly property var settings: service && service.settings ? service.settings : ({})
  // The models the agent can work with, when it works here.
  property var models: []
  function loadModels() {
    models = []
    if (files && typeof files.agentModels === "function" && Agent.runsHere(agent)) files.agentModels(agent, function(list) { pop.models = list })
  }
  function pickChoice(model, effort) {
    if (!service) return
    service.setSetting(agent + "Model", model)
    service.setSetting(agent + "Effort", effort)
  }

  signal sent(string request)
  // The same, in a terminal instead (Claude Code, Grok and Codex work here;
  // there, your agent runs as you set it up, with all its own controls).
  signal sentToTerminal(string request)

  width: Math.min(560, (parent ? parent.width : 560) - 40)
  padding: 14
  modal: true
  Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, pop.theme && pop.theme.dark ? 0.4 : 0.2) }

  function start(context, current) {
    ask = context
    onPage = current || null
    mode = context.scope === "new" ? "new" : "here"
    place = "top"
    x = ((parent ? parent.width : width) - width) / 2
    y = 70
    field.text = ""
    known = false
    agent = ""
    if (files) {
      files.defaultAgent(function(name) { pop.agent = name; pop.known = true; pop.loadModels() })
      files.listAgents(function(list) { pop.agents = list })
    }
    open()
    field.focusField()
  }

  function shortTitle(t) {
    var s = String(t || "") || "Untitled"
    return s.length > 28 ? s.slice(0, 27) + "\u2026" : s
  }
  function pickMode(m) {
    mode = m
    field.focusField()
  }

  function labelOf(name) {
    for (var i = 0; i < agents.length; i++) if (agents[i].name === name) return agents[i].label
    return Agent.name(name)
  }

  // Your agent, chosen here: Omarchy's default from now on (nothing opens).
  function choose(name) {
    chooser.close()
    files.setDefaultAgent(name, function(ok) {
      if (ok) { pop.agent = name; pop.known = true; pop.loadModels() }
    })
    field.focusField()
  }

  function openChooser() { chooser.open() }

  // With no agent chosen yet, the chooser comes up first.
  function send(request) {
    var r = String(request || "").trim()
    if (!r) return
    if (known && !agent) { chooser.open(); return }
    close()
    sent(r)
  }
  function sendToTerminal(request) {
    var r = String(request || "").trim()
    if (!r) return
    close()
    sentToTerminal(r)
  }

  contentItem: Column {
    spacing: 10

    Item {
      width: parent.width
      height: 28
      Icon {
        id: headIcon
        theme: pop.theme
        text: pop.theme.icons.agent
        size: 18
        color: pop.theme.accent
        anchors.verticalCenter: parent.verticalCenter
      }
      Text {
        textFormat: Text.PlainText
        anchors.left: headIcon.right
        anchors.leftMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        text: "Ask your agent"
        font.family: pop.theme.uiFont
        font.pixelSize: 15
        font.weight: Font.DemiBold
        color: pop.theme.text
      }
      // What it's about: what you're on, or a new page. (With no page
      // open, a new page, said.)
      Rectangle {
        id: modeSwitch
        objectName: "askMode"
        visible: pop.ask.scope !== "new"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: modeRow.implicitWidth + 6
        height: 28
        radius: height / 2
        color: Qt.alpha(pop.theme.text, 0.04)
        border.width: 1
        border.color: pop.theme.line
        Row {
          id: modeRow
          anchors.centerIn: parent
          Repeater {
            model: [{ id: "here", label: Agent.scopeLabel(pop.ask.scope, (pop.ask.blocks || []).length) }, { id: "new", label: Agent.scopeLabel("new") }]
            delegate: Rectangle {
              id: modeOption
              required property var modelData
              readonly property bool on: pop.mode === modelData.id
              objectName: modelData.id === "new" ? "askNew" : "askHere"
              width: modeText.implicitWidth + 20
              height: modeSwitch.height - 6
              radius: height / 2
              color: on ? pop.theme.surfaceHigh : modeHover.hovered ? pop.theme.hover : "transparent"
              border.width: on ? 1 : 0
              border.color: pop.theme.line
              Text {
                id: modeText
                anchors.centerIn: parent
                textFormat: Text.PlainText
                text: modeOption.modelData.label
                font.family: pop.theme.uiFont
                font.pixelSize: 12
                font.weight: modeOption.on ? Font.DemiBold : Font.Normal
                color: modeOption.on ? pop.theme.text : pop.theme.muted
              }
              HoverHandler { id: modeHover; cursorShape: Qt.PointingHandCursor }
              TapHandler { onTapped: pop.pickMode(modeOption.modelData.id) }
            }
          }
        }
      }
      Rectangle {
        visible: pop.ask.scope === "new"
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: newText.implicitWidth + 18
        height: 24
        radius: 12
        color: Qt.alpha(pop.theme.accent, 0.14)
        Text {
          id: newText
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: Agent.scopeLabel("new")
          font.family: pop.theme.uiFont
          font.pixelSize: 12
          color: pop.theme.accent
        }
      }
    }

    Field {
      id: field
      theme: pop.theme
      width: parent.width
      height: 40
      fontSize: 15
      maximumLength: 4000
      placeholder: pop.mode === "new" ? "What should the new page be? A packing list for Lisbon\u2026" : "What would you like it to do?"
      onAccepted: pop.send(field.text)
      onEscaped: pop.close()
    }

    // Where a new page goes (on a page you can change).
    Row {
      visible: pop.mode === "new" && pop.onPage !== null && !pop.onPage.locked
      spacing: 6
      Text {
        anchors.verticalCenter: parent.verticalCenter
        rightPadding: 2
        textFormat: Text.PlainText
        text: "Goes"
        font.family: pop.theme.uiFont
        font.pixelSize: 12
        color: pop.theme.muted
      }
      Chip {
        objectName: "askPlaceTop"
        theme: pop.theme
        text: "At the top of Pages"
        checked: pop.place === "top"
        onClicked: { pop.place = "top"; field.focusField() }
      }
      Chip {
        objectName: "askPlaceInside"
        theme: pop.theme
        text: "Inside \u201c" + pop.shortTitle(pop.onPage ? pop.onPage.title : "") + "\u201d"
        checked: pop.place === "inside"
        onClicked: { pop.place = "inside"; field.focusField() }
      }
    }

    Column {
      width: parent.width
      spacing: 2
      Repeater {
        model: Agent.suggestions(pop.mode === "new" ? "new" : pop.ask.scope)
        delegate: MenuRow {
          required property var modelData
          width: parent.width
          theme: pop.theme
          icon: pop.theme.icons.agent
          text: modelData
          onClicked: pop.send(modelData)
        }
      }
    }

    Rectangle { width: parent.width; height: 1; color: pop.theme.line }

    Item {
      width: parent.width
      height: 30
      Row {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Text {
          textFormat: Text.PlainText
          anchors.verticalCenter: parent.verticalCenter
          text: "Agent"
          font.family: pop.theme.uiFont
          font.pixelSize: 12
          color: pop.theme.muted
        }
        // Your agent: click to choose another.
        Rectangle {
          id: agentButton
          anchors.verticalCenter: parent.verticalCenter
          width: agentRow.implicitWidth + 20
          height: 28
          radius: 14
          color: agentHover.hovered || chooser.opened ? pop.theme.hover : "transparent"
          border.width: 1
          border.color: pop.theme.line
          Row {
            id: agentRow
            anchors.centerIn: parent
            spacing: 6
            Icon { theme: pop.theme; text: pop.theme.icons.agent; size: 13; color: pop.theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: !pop.known ? "\u2026" : pop.agent ? pop.labelOf(pop.agent) : "Choose one"
              font.family: pop.theme.uiFont
              font.pixelSize: 12
              font.weight: Font.DemiBold
              color: pop.theme.text
            }
            Text {
              anchors.verticalCenter: parent.verticalCenter
              textFormat: Text.PlainText
              text: "\u25be"
              font.pixelSize: 11
              color: pop.theme.muted
            }
          }
          HoverHandler { id: agentHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: chooser.opened ? chooser.close() : chooser.open() }

          // The agents installed here.
          Pop {
            id: chooser
            theme: pop.theme
            focus: false
            y: agentButton.height + 6
            width: 380
            contentItem: Column {
              spacing: 2
              Text {
                textFormat: Text.PlainText
                leftPadding: 10
                topPadding: 2
                bottomPadding: 6
                text: "Your agent (Omarchy's default too)"
                font.family: pop.theme.uiFont
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: pop.theme.muted
              }
              // Claude, Grok and Codex first, side by side: they work here.
              AgentTiles {
                id: chooserTiles
                theme: pop.theme
                agents: pop.agents
                agent: pop.agent
                namePrefix: "chooseAgent_"
                width: parent.width
                onPicked: function(name) { pop.choose(name) }
              }
              Text {
                visible: chooserTiles.others().length > 0
                textFormat: Text.PlainText
                leftPadding: 10
                topPadding: 10
                bottomPadding: 2
                text: "In a terminal"
                font.family: pop.theme.uiFont
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: pop.theme.muted
              }
              Repeater {
                model: chooserTiles.others()
                delegate: MenuRow {
                  required property var modelData
                  width: parent.width
                  theme: pop.theme
                  icon: pop.theme.icons.terminal
                  text: modelData.label
                  checked: modelData.name === pop.agent
                  onClicked: pop.choose(modelData.name)
                }
              }
              Text {
                visible: pop.agents.length === 0
                width: parent.width
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                leftPadding: 10
                rightPadding: 10
                text: "No coding agent is installed. Omarchy installs one: omarchy default agent <name>."
                font.family: pop.theme.uiFont
                font.pixelSize: 12
                color: pop.theme.muted
              }
            }
          }
        }
        // The model and effort it works with (when it works here).
        AgentChoice {
          anchors.verticalCenter: parent.verticalCenter
          visible: pop.known && Agent.runsHere(pop.agent) && pop.service !== null
          theme: pop.theme
          namePrefix: "askChoice"
          agentLabel: Agent.name(pop.agent)
          models: pop.models
          model: pop.settings[pop.agent + "Model"] || ""
          effort: pop.settings[pop.agent + "Effort"] || ""
          onPicked: function(m, e) { pop.pickChoice(m, e) }
        }
      }
      IconButton {
        objectName: "agentAskTerminal"
        visible: pop.known && Agent.runsHere(pop.agent)
        anchors.right: askButton.left
        anchors.rightMargin: 6
        anchors.verticalCenter: parent.verticalCenter
        theme: pop.theme
        icon: pop.theme.icons.terminal
        tip: "Ask " + Agent.name(pop.agent) + " in a terminal instead, with all its own controls"
        size: 30
        iconSize: 14
        active: field.text.trim() !== ""
        onClicked: pop.sendToTerminal(field.text)
      }
      IconButton {
        id: askButton
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        theme: pop.theme
        icon: pop.theme.icons.agent
        label: "Ask  \u23ce"
        size: 30
        iconSize: 14
        active: field.text.trim() !== ""
        onClicked: pop.send(field.text)
      }
    }

    Text {
      width: parent.width
      wrapMode: Text.Wrap
      textFormat: Text.PlainText
      text: Agent.runsHere(pop.agent)
        ? Agent.name(pop.agent) + " works here, in a panel on the page, through Uber Notebook's commands: what it changes shows up as it goes, each change a step you can undo. The terminal button beside Ask asks it in a terminal instead, with all its own controls."
        : "It opens in a terminal and works through Uber Notebook's commands: what it changes shows up here, each change a step you can undo."
      font.family: pop.theme.uiFont
      font.pixelSize: 11
      color: pop.theme.faint
    }
  }
}
