import QtQuick
import QtQuick.Controls

// An index tab on this page, sticking out of the notebook's edge: pick its
// color and write a word on it.
Pop {
  id: pop

  property var view: null
  readonly property var tabColors: ["#f2c14e", "#f28c6b", "#e76f93", "#a57ee0", "#6aa9e9", "#59c3a6", "#9bc46b", "#c9c2b3"]

  width: 300
  padding: 14

  onOpened: {
    var tab = view.page ? view.page.tab : null
    label.text = tab ? tab.label : ""
    label.focusField()
  }

  function apply(color) {
    var tab = view.page ? view.page.tab : null
    view.setTab({ color: color || (tab ? tab.color : tabColors[0]), label: label.text.trim().slice(0, 24) })
  }

  contentItem: Column {
    spacing: 10
    Field {
      id: label
      theme: pop.theme
      width: parent.width
      placeholder: "A word for the tab"
      maximumLength: 24
      onAccepted: { pop.apply(""); pop.close() }
      onEscaped: pop.close()
    }
    Flow {
      width: parent.width
      spacing: 2
      Repeater {
        model: pop.tabColors
        delegate: Swatch {
          required property var modelData
          theme: pop.theme
          color: modelData
          checked: pop.view.page && pop.view.page.tab && pop.view.page.tab.color === modelData
          onClicked: pop.apply(modelData)
        }
      }
    }
    Row {
      spacing: 6
      Chip { theme: pop.theme; text: "Done"; checked: true; onClicked: { pop.apply(""); pop.close() } }
      Chip { theme: pop.theme; text: "Remove tab"; visible: pop.view.page && pop.view.page.tab; onClicked: { pop.view.setTab(null); pop.close() } }
    }
  }
}
