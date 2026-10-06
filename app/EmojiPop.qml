import QtQuick
import QtQuick.Controls
import "../Docs.js" as Docs

// An emoji for a page's icon or a callout's: a few hundred by kind, a random
// one, or none.
Pop {
  id: pop

  // Whether "Remove" is offered (a callout always has an icon).
  property bool removable: true

  signal picked(string emoji)
  signal removed()

  width: 10 * 34 + 2 * padding
  height: 360
  padding: 10

  contentItem: Column {
    spacing: 8
    Row {
      spacing: 6
      Chip {
        theme: pop.theme
        text: "Random"
        icon: pop.theme.icons.random
        onClicked: { pop.close(); pop.picked(Docs.randomEmoji()) }
      }
      Chip {
        visible: pop.removable
        theme: pop.theme
        text: "Remove"
        icon: pop.theme.icons.trash
        onClicked: { pop.close(); pop.removed() }
      }
    }
    Flickable {
      width: parent.width
      height: pop.height - 2 * pop.padding - 38 - 8
      contentHeight: groups.height
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      Column {
        id: groups
        width: parent.width
        spacing: 6
        Repeater {
          model: Docs.EMOJI
          delegate: Column {
            required property var modelData
            width: groups.width
            spacing: 2
            Text {
              textFormat: Text.PlainText
              text: modelData.label
              font.family: pop.theme.uiFont
              font.pixelSize: 11
              font.weight: Font.DemiBold
              color: pop.theme.muted
            }
            Flow {
              width: parent.width
              Repeater {
                model: modelData.list.split(" ")
                delegate: Rectangle {
                  required property var modelData
                  width: 34
                  height: 34
                  radius: 6
                  color: emojiHover.hovered ? pop.theme.hover : "transparent"
                  Text {
                    textFormat: Text.PlainText
                    anchors.centerIn: parent
                    text: modelData
                    font.family: "Noto Color Emoji"
                    font.pixelSize: 20
                  }
                  HoverHandler { id: emojiHover; cursorShape: Qt.PointingHandCursor }
                  TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: { pop.close(); pop.picked(modelData) } }
                }
              }
            }
          }
        }
      }
    }
  }
}
