import QtQuick
import QtQuick.Controls

// A gallery on a page in Pages (/gallery): pictures side by side, 2, 3 or 4
// to a row, each with its caption if it has one. A click on one shows it
// here, large, the others a key away. Under the pointer, a picture moves
// earlier or later, gets a caption, or goes; Add pictures (or drop them on
// it) puts more in; its bottom edge drags to make them taller or shorter (a
// double-click: as they were); how many to a row and its colors are at its
// corner. Its colors are Pages' or your own: the captions', and behind it.
DataCard {
  id: gb
  kind: "gallery"

  readonly property var images: look.images || info.images || []
  readonly property int cols: info.columns || 3
  readonly property real pad: look.background ? 12 : 0
  readonly property real gap: 8
  readonly property real tileW: Math.max(40, (width - 2 * pad - (cols - 1) * gap) / cols)
  // While its bottom edge is dragged: how tall a picture is then.
  property real dragH: -1
  readonly property real tileH: dragH > 0 ? dragH : info.height > 0 ? info.height : Math.round(tileW * 0.75)
  readonly property bool hasCaptions: images.some(function(x) { return x.caption !== "" }) || editing >= 0
  readonly property real captionH: hasCaptions ? 24 : 0
  // The picture whose caption is being written (-1: none).
  property int editing: -1

  function sample() { return "Gallery" }
  function colorSubject() { return "Gallery" }

  function setImages(list) { change({ images: list }) }
  function move(i, step) {
    var l = JSON.parse(JSON.stringify(info.images))
    var j = i + step
    if (j < 0 || j >= l.length) return
    var x = l[i]; l[i] = l[j]; l[j] = x
    setImages(l)
  }
  function remove(i) {
    var l = JSON.parse(JSON.stringify(info.images))
    l.splice(i, 1)
    setImages(l)
  }
  function setCaption(i, text) {
    editing = -1
    var l = JSON.parse(JSON.stringify(info.images))
    if (!l[i] || l[i].caption === text.trim()) return
    l[i].caption = text.trim()
    setImages(l)
  }
  function fitHeight() { if (info.height > 0) change({ height: 0 }) }

  width: available
  height: card.height

  Rectangle {
    id: card
    width: gb.width
    height: gb.images.length ? grid.height + 2 * gb.pad + (gb.readOnly ? 0 : 26) : 120
    radius: 10
    color: gb.look.background ? gb.fill : "transparent"
    border.width: gb.images.length && !gb.look.background ? 0 : 1
    border.color: Qt.alpha(gb.words, gb.pointerIn ? 0.2 : 0.11)

    // None yet: add some.
    Column {
      visible: gb.images.length === 0
      anchors.centerIn: parent
      spacing: 6
      Text {
        anchors.horizontalCenter: parent.horizontalCenter
        textFormat: Text.PlainText
        text: gb.theme ? gb.theme.icons.grid : ""
        font.family: gb.theme ? gb.theme.iconFont : ""
        font.pixelSize: 22
        color: gb.faint
      }
      Text {
        textFormat: Text.PlainText
        text: gb.readOnly ? "A gallery, no pictures yet" : "Add pictures, or drop them here"
        font.family: gb.editor ? gb.editor.uiFamily : ""
        font.pixelSize: 14
        color: gb.faint
      }
    }
    TapHandler { enabled: gb.images.length === 0 && !gb.readOnly; onTapped: gb.act("pick", null) }
    HoverHandler { enabled: gb.images.length === 0 && !gb.readOnly; cursorShape: Qt.PointingHandCursor }

    Grid {
      id: grid
      visible: gb.images.length > 0
      x: gb.pad
      y: gb.pad
      columns: gb.cols
      columnSpacing: gb.gap
      rowSpacing: gb.gap
      Repeater {
        model: gb.images
        delegate: Item {
          id: tile
          required property var modelData
          required property int index
          objectName: "galleryTile"
          width: gb.tileW
          height: gb.tileH + gb.captionH
          Rectangle {
            id: frame
            width: parent.width
            height: gb.tileH
            radius: 6
            color: Qt.alpha(gb.ink, gb.dark ? 0.08 : 0.05)
            clip: true
            Image {
              anchors.fill: parent
              source: gb.editor ? gb.editor.assetUrl(tile.modelData.src) : ""
              sourceSize.width: Math.round(gb.tileW * 2)
              fillMode: Image.PreserveAspectCrop
              asynchronous: true
              smooth: true
              mipmap: true
            }
            HoverHandler { id: tileHover; cursorShape: Qt.PointingHandCursor }
            TapHandler {
              onTapped: function(point) {
                // (A click on its tools, or the corner's over it, is theirs:
                // where it is, since they may have gone by now.)
                var x = point.position.x, y = point.position.y
                if (!gb.readOnly && (tools.contains(tools.mapFromItem(frame, x, y)) || bar.contains(bar.mapFromItem(frame, x, y)))) return
                gb.act("view", tile.index)
              }
            }
            // Under the pointer: earlier, later, a caption, out.
            Rectangle {
              id: tools
              objectName: "galleryTools"
              visible: !gb.readOnly && tileHover.hovered
              anchors.right: parent.right
              anchors.top: parent.top
              anchors.margins: 6
              width: toolRow.implicitWidth + 8
              height: 28
              radius: 14
              color: Qt.rgba(0.08, 0.08, 0.1, 0.82)
              Row {
                id: toolRow
                anchors.centerIn: parent
                Repeater {
                  model: [["earlier", "left", tile.index > 0], ["later", "right", tile.index < gb.images.length - 1], ["caption", "edit", true], ["remove", "close", true]]
                  delegate: Rectangle {
                    required property var modelData
                    objectName: "gallery_" + modelData[0]
                    width: 24
                    height: 24
                    radius: 12
                    opacity: modelData[2] ? 1 : 0.35
                    color: toolHover.hovered && modelData[2] ? Qt.rgba(1, 1, 1, 0.16) : "transparent"
                    Text {
                      anchors.centerIn: parent
                      textFormat: Text.PlainText
                      text: gb.theme ? gb.theme.icons[parent.modelData[1]] : ""
                      font.family: gb.theme ? gb.theme.iconFont : ""
                      font.pixelSize: 13
                      color: parent.modelData[0] === "remove" ? "#ff8a80" : "#f2f2f2"
                    }
                    HoverHandler { id: toolHover; cursorShape: parent.modelData[2] ? Qt.PointingHandCursor : Qt.ArrowCursor }
                    TapHandler {
                      onTapped: {
                        var what = parent.modelData[0]
                        if (!parent.modelData[2]) return
                        if (what === "earlier") gb.move(tile.index, -1)
                        else if (what === "later") gb.move(tile.index, 1)
                        else if (what === "remove") gb.remove(tile.index)
                        else { gb.editing = tile.index; Qt.callLater(function() { captionEdit.text = tile.modelData.caption; captionEdit.forceActiveFocus(); captionEdit.selectAll() }) }
                      }
                    }
                  }
                }
              }
            }
          }
          // Its caption, or written in.
          Text {
            objectName: "galleryCaption"
            visible: gb.editing !== tile.index && tile.modelData.caption !== ""
            y: gb.tileH + 4
            width: parent.width
            elide: Text.ElideRight
            textFormat: Text.PlainText
            text: tile.modelData.caption
            font.family: gb.editor ? gb.editor.uiFamily : ""
            font.pixelSize: 12
            color: gb.look.color ? gb.accent : gb.faint
          }
          TextInput {
            id: captionEdit
            objectName: "galleryCaptionEdit"
            visible: gb.editing === tile.index
            y: gb.tileH + 4
            width: parent.width
            clip: true
            maximumLength: 200
            selectByMouse: true
            font.family: gb.editor ? gb.editor.uiFamily : ""
            font.pixelSize: 12
            color: gb.words
            onAccepted: gb.setCaption(tile.index, text)
            onActiveFocusChanged: if (!activeFocus && gb.editing === tile.index) gb.setCaption(tile.index, text)
            Keys.onEscapePressed: gb.editing = -1
            Text {
              visible: captionEdit.text === ""
              textFormat: Text.PlainText
              text: "A caption"
              font: captionEdit.font
              color: gb.faint
            }
          }
        }
      }
    }

    // More pictures, under them.
    Row {
      objectName: "galleryAdd"
      visible: !gb.readOnly && gb.images.length > 0
      x: gb.pad
      y: gb.pad + grid.height + 5
      spacing: 6
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: gb.theme ? gb.theme.icons.plus : ""
        font.family: gb.theme ? gb.theme.iconFont : ""
        font.pixelSize: 12
        color: addHover.hovered ? gb.words : gb.faint
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: "Add pictures"
        font.family: gb.editor ? gb.editor.uiFamily : ""
        font.pixelSize: 12
        color: addHover.hovered ? gb.words : gb.faint
      }
      HoverHandler { id: addHover; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: gb.act("pick", null) }
    }

    // At its corner, under the pointer: how many to a row, its colors.
    Rectangle {
      id: bar
      objectName: "galleryBar"
      visible: !gb.readOnly && gb.images.length > 0 && (gb.pointerIn || gb.trying !== null)
      z: 4
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.margins: gb.pad + 6
      width: barRow.implicitWidth + 8
      height: 28
      radius: 14
      color: Qt.rgba(0.08, 0.08, 0.1, 0.82)
      Row {
        id: barRow
        anchors.centerIn: parent
        spacing: 2
        Repeater {
          model: [2, 3, 4]
          delegate: Rectangle {
            required property int modelData
            objectName: "galleryColumns" + modelData
            width: 24
            height: 24
            radius: 12
            color: gb.cols === modelData ? Qt.rgba(1, 1, 1, 0.2) : colHover.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: String(parent.modelData)
              font.family: gb.editor ? gb.editor.uiFamily : ""
              font.pixelSize: 12
              font.weight: Font.DemiBold
              color: "#f2f2f2"
            }
            HoverHandler { id: colHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: if (gb.cols !== parent.modelData) gb.change({ columns: parent.modelData }) }
          }
        }
        Rectangle { width: 1; height: 16; anchors.verticalCenter: parent.verticalCenter; color: Qt.rgba(1, 1, 1, 0.25) }
        Rectangle {
          id: paint
          objectName: "galleryColors"
          width: 24
          height: 24
          radius: 12
          color: paintHover.hovered ? Qt.rgba(1, 1, 1, 0.1) : "transparent"
          Text {
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: gb.theme ? gb.theme.icons.palette : ""
            font.family: gb.theme ? gb.theme.iconFont : ""
            font.pixelSize: 13
            color: "#f2f2f2"
          }
          HoverHandler { id: paintHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: gb.askColors(paint) }
        }
      }
    }

    // Its bottom edge: dragged, the pictures taller or shorter; a
    // double-click, as they were (three quarters as tall as wide).
    Item {
      objectName: "galleryEdge"
      visible: !gb.readOnly && gb.images.length > 0
      anchors.bottom: parent.bottom
      anchors.bottomMargin: -4
      z: 3
      width: parent.width
      height: 10
      Rectangle {
        anchors.centerIn: parent
        width: 44
        height: 4
        radius: 2
        color: Qt.alpha(gb.ink, edgeHover.hovered || edgeDrag.active ? 0.45 : 0.18)
        visible: gb.pointerIn || edgeDrag.active
      }
      HoverHandler { id: edgeHover; cursorShape: Qt.SizeVerCursor }
      DragHandler {
        id: edgeDrag
        target: null
        cursorShape: Qt.SizeVerCursor
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        property real from: 0
        property int rows: 1
        onActiveChanged: {
          if (active) {
            from = gb.tileH
            rows = Math.max(1, Math.ceil(gb.images.length / gb.cols))
            gb.dragH = from
            return
          }
          var h = Math.round(gb.dragH)
          gb.dragH = -1
          if (h !== (gb.info.height || 0)) gb.change({ height: h })
        }
        // (Each row grows by its share of the drag.)
        onTranslationChanged: if (active) gb.dragH = Math.max(80, Math.min(800, from + translation.y / rows))
      }
      TapHandler { onDoubleTapped: gb.fitHeight() }
      ToolTip.visible: edgeHover.hovered && !edgeDrag.active
      ToolTip.delay: 700
      ToolTip.text: "Drag to make the pictures taller or shorter"
    }
  }
}
