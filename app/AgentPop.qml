import QtQuick
import QtQuick.Controls
import "../Agent.js" as Agent

// Ask your agent (Ctrl+J, "/agent", a block's menu, the toolbar over selected
// words, the page's ⋯ menu): what you'd like done with this page, the blocks
// you picked, the words you selected, or the line you're on. Omarchy's
// default coding agent does it (whichever `omarchy default agent` chose), in
// its own terminal, through Uber Notebook's commands, so what it changes shows up
// here as it goes.
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
  // What it's asked about: { scope, blocks, words, line } (Agent.prompt).
  property var ask: ({ scope: "page", blocks: [], words: "", line: "" })
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

  width: Math.min(560, (parent ? parent.width : 560) - 40)
  padding: 14
  modal: true
  Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, pop.theme && pop.theme.dark ? 0.4 : 0.2) }

  function start(context) {
    ask = context
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
      Rectangle {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: scopeText.implicitWidth + 18
        height: 24
        radius: 12
        color: Qt.alpha(pop.theme.accent, 0.14)
        Text {
          id: scopeText
          textFormat: Text.PlainText
          anchors.centerIn: parent
          text: Agent.scopeLabel(pop.ask.scope, (pop.ask.blocks || []).length)
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
      placeholder: "What would you like it to do?"
      onAccepted: pop.send(field.text)
      onEscaped: pop.close()
    }

    Column {
      width: parent.width
      spacing: 2
      Repeater {
        model: Agent.suggestions(pop.ask.scope)
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
            width: 240
            contentItem: Column {
              spacing: 2
              Text {
                textFormat: Text.PlainText
                leftPadding: 10
                topPadding: 2
                bottomPadding: 4
                text: "Your agent (Omarchy's default too)"
                font.family: pop.theme.uiFont
                font.pixelSize: 11
                font.weight: Font.DemiBold
                color: pop.theme.muted
              }
              Repeater {
                model: pop.agents
                delegate: MenuRow {
                  required property var modelData
                  width: parent.width
                  theme: pop.theme
                  icon: pop.theme.icons.agent
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
        ? Agent.name(pop.agent) + " works here, in a panel on the page, through Uber Notebook's commands: what it changes shows up as it goes, each change a step you can undo."
        : "It opens in a terminal and works through Uber Notebook's commands: what it changes shows up here, each change a step you can undo."
      font.family: pop.theme.uiFont
      font.pixelSize: 11
      color: pop.theme.faint
    }
  }
}
