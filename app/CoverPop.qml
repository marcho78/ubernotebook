import QtQuick
import QtQuick.Controls
import "../Docs.js" as Docs

// A page's cover: one of Uber Notebook's gradients, a picture of your own, or none.
Pop {
  id: pop

  signal picked(string cover)
  signal uploadRequested()

  width: 4 * 96 + 3 * 8 + 2 * padding
  padding: 12

  contentItem: Column {
    spacing: 10
    Grid {
      columns: 4
      spacing: 8
      Repeater {
        model: Docs.COVERS
        delegate: Rectangle {
          required property var modelData
          required property int index
          width: 96
          height: 54
          radius: 6
          border.width: coverHover.hovered ? 2 : 0
          border.color: pop.theme.accent
          gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0.0; color: modelData[0] }
            GradientStop { position: modelData.length > 2 ? 0.5 : 1.0; color: modelData[1] }
            GradientStop { position: 1.0; color: modelData[modelData.length - 1] }
          }
          HoverHandler { id: coverHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: { pop.close(); pop.picked("gradient:" + index) } }
        }
      }
    }
    Row {
      spacing: 6
      Chip { theme: pop.theme; text: "A picture\u2026"; icon: pop.theme.icons.image; onClicked: { pop.close(); pop.uploadRequested() } }
      Chip { theme: pop.theme; text: "Remove"; icon: pop.theme.icons.trash; onClicked: { pop.close(); pop.picked("") } }
    }
  }
}
