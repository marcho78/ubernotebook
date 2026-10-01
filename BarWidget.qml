import QtQuick
import qs.Ui
import "Settings.js" as Settings

// Omanote's notebook in the Omarchy bar. Click it to open or close your
// notebooks; right-click to jot a quick note.
//
// For Omarchy this icon is also Omanote's on switch: a third-party plugin is
// on while its entry is in the bar. To keep Omanote but lose the icon, turn
// off "Show Omanote in the top bar" in its settings; the icon then takes no
// space.
BarWidget {
  id: root
  moduleName: "marcho78.omanote"

  readonly property var service: bar && bar.shell && typeof bar.shell.serviceFor === "function"
    ? bar.shell.serviceFor("marcho78.omanote") : null
  readonly property bool wanted: !service || !service.settings || service.settings.barIcon !== false
  readonly property string shortcut: service && service.settings ? Settings.shortcutLabel(service.settings.shortcut) : ""

  visible: wanted
  implicitWidth: wanted ? button.implicitWidth : 0
  implicitHeight: wanted ? button.implicitHeight : 0

  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Material Design "notebook".
    text: String.fromCodePoint(0xf082e)
    tooltipText: "Omanote" + (root.shortcut ? " · " + root.shortcut : "") + " · right-click for a quick note"
    onPressed: function(button) {
      if (!root.service) return
      if (button === Qt.RightButton) root.service.quick("")
      else root.service.toggle({})
    }
  }
}
