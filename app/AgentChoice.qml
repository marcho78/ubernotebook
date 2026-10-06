import QtQuick
import "../Agent.js" as Agent

// The model and the effort an agent works with in Uber Notebook (Claude
// Code, Grok, Codex): two buttons, each a list to pick from. The models are
// the agent's own (Agent.models); Default is as the agent is set up. The
// efforts follow the model: a model that doesn't take the effort picked
// before goes back to its default.
Row {
  id: ac

  property var theme: null
  property string agentLabel: ""
  property var models: []
  property string model: ""
  property string effort: ""
  // A name for each button, for tests (modelButton, effortButton).
  property string namePrefix: "agentChoice"
  signal picked(string model, string effort)

  readonly property var efforts: Agent.efforts(models, model)
  readonly property var current: models.filter(function(m) { return m.id === ac.model })[0] || null
  // A menu of them all the way open (its opening done): for a click on it.
  readonly property bool menuOpened: modelMenu.opened || effortMenu.opened

  spacing: 6

  function pickModel(id) {
    modelMenu.close()
    var keep = Agent.efforts(models, id).some(function(e) { return e.id === ac.effort })
    picked(id, keep ? effort : "")
  }
  function pickEffort(id) {
    effortMenu.close()
    picked(model, id)
  }

  component DropButton: Rectangle {
    id: drop
    property string text: ""
    signal clicked()
    width: Math.min(220, dropText.implicitWidth + 36)
    height: 28
    radius: 8
    color: dropHover.hovered ? ac.theme.hover : "transparent"
    border.width: 1
    border.color: ac.theme.line
    Text {
      id: dropText
      x: 10
      width: parent.width - 30
      anchors.verticalCenter: parent.verticalCenter
      elide: Text.ElideRight
      textFormat: Text.PlainText
      text: drop.text
      font.family: ac.theme.uiFont
      font.pixelSize: 12
      color: ac.theme.text
    }
    Icon {
      theme: ac.theme
      anchors.right: parent.right
      anchors.rightMargin: 7
      anchors.verticalCenter: parent.verticalCenter
      text: ac.theme.icons.down
      size: 13
      color: ac.theme.muted
    }
    HoverHandler { id: dropHover; cursorShape: Qt.PointingHandCursor }
    TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: drop.clicked() }
  }

  DropButton {
    id: modelButton
    objectName: ac.namePrefix + "Model"
    text: ac.current ? ac.current.name : ac.model ? ac.model : "Default model"
    onClicked: modelMenu.opened ? modelMenu.close() : modelMenu.open()
    Pop {
      id: modelMenu
      theme: ac.theme
      focus: false
      width: 320
      y: modelButton.height + 6
      contentItem: Column {
        spacing: 2
        MenuRow {
          objectName: ac.namePrefix + "ModelDefault"
          width: parent.width
          theme: ac.theme
          icon: ac.theme.icons.agent
          text: "Default"
          hint: "as " + ac.agentLabel + " is set up"
          checked: ac.model === ""
          onClicked: ac.pickModel("")
        }
        Repeater {
          model: ac.models
          delegate: MenuRow {
            required property var modelData
            objectName: ac.namePrefix + "Model_" + modelData.id
            width: parent.width
            theme: ac.theme
            icon: ac.theme.icons.agent
            text: modelData.name
            hint: modelData.description
            checked: ac.model === modelData.id
            onClicked: ac.pickModel(modelData.id)
          }
        }
      }
    }
  }

  DropButton {
    id: effortButton
    objectName: ac.namePrefix + "Effort"
    visible: ac.efforts.length > 0
    text: ac.effort ? Agent.effortLabel(ac.effort) + " effort" : "Default effort"
    onClicked: effortMenu.opened ? effortMenu.close() : effortMenu.open()
    Pop {
      id: effortMenu
      theme: ac.theme
      focus: false
      width: 200
      y: effortButton.height + 6
      contentItem: Column {
        spacing: 2
        MenuRow {
          objectName: ac.namePrefix + "EffortDefault"
          width: parent.width
          theme: ac.theme
          icon: ac.theme.icons.time
          text: "Default"
          hint: ac.current && ac.current.effort ? Agent.effortLabel(ac.current.effort) : ""
          checked: ac.effort === ""
          onClicked: ac.pickEffort("")
        }
        Repeater {
          model: ac.efforts
          delegate: MenuRow {
            required property var modelData
            objectName: ac.namePrefix + "Effort_" + modelData.id
            width: parent.width
            theme: ac.theme
            icon: ac.theme.icons.time
            text: modelData.label
            checked: ac.effort === modelData.id
            onClicked: ac.pickEffort(modelData.id)
          }
        }
      }
    }
  }
}
