import QtQuick
import QtQuick.Controls
import "../Library.js" as Library

// Pictures to choose, shown as pictures: a folder's (Pictures to start
// with; then the last one), its folders first, the newest pictures first.
// Several at once (a click chooses one, another click lets it go; Shift a
// run of them; Ctrl+A all of them), or one (a click is it). Add (Enter) or
// Cancel (Esc); the desktop's file dialog a click away. Qt's own dialog
// takes one file at a time, and the desktop's would run in the shell.
Rectangle {
  id: pk
  // (Closed as another profile opens: Overlays.js.)
  readonly property bool closesForSwitch: true

  property var theme: null
  // Store.qml (exec, home, isImagePath), or the tests' files.
  property var files: null
  property bool multiple: true
  property string folder: ""
  property string lastFolder: ""
  // [{ dir, name, path, time }]: folders, then pictures.
  property var entries: []
  property var chosen: []
  property int anchorIndex: -1
  property bool loading: false
  property var done: null
  property var fallback: null
  readonly property var pictures: entries.filter(function(e) { return !e.dir })

  objectName: "picturePicker"
  visible: false
  color: Qt.rgba(0, 0, 0, theme && theme.dark ? 0.55 : 0.35)

  readonly property string listScript: Library.LIST_SCRIPT

  function home() { return files && files.home ? files.home : "" }
  function tilde(p) { var h = home(); return h && p.indexOf(h) === 0 ? "~" + p.slice(h.length) : p }
  function choose(many, then, otherwise) {
    multiple = many
    done = then
    fallback = otherwise || null
    chosen = []
    anchorIndex = -1
    visible = true
    forceActiveFocus()
    open(lastFolder || home() + "/Pictures")
  }
  function open(dir) {
    var d = String(dir || home()).replace(/\/+$/, "") || "/"
    folder = d
    loading = true
    files.execText(["/usr/bin/bash", "-c", listScript, "uber-notebook-pictures", d], function(ok, out) {
      if (pk.folder !== d) return
      pk.loading = false
      if (!ok) {
        // (No Pictures folder: home.)
        if (d === pk.home() + "/Pictures") { pk.open(pk.home()); return }
        pk.entries = []
        return
      }
      var dirs = [], pics = []
      String(out || "").split("\n").forEach(function(l) {
        var m = /^([df])\t([0-9.]+)\t(.+)$/.exec(l)
        if (!m) return
        var path = (d === "/" ? "" : d) + "/" + m[3]
        if (m[1] === "d") dirs.push({ dir: true, name: m[3], path: path, time: 0 })
        else if (Library.isImagePath(path)) pics.push({ dir: false, name: m[3], path: path, time: Number(m[2]) || 0 })
      })
      dirs.sort(function(a, b) { return a.name.toLowerCase().localeCompare(b.name.toLowerCase()) })
      pics.sort(function(a, b) { return b.time - a.time || a.name.localeCompare(b.name) })
      pk.entries = dirs.concat(pics)
      grid.contentY = 0
    }, { okCodes: [0, 1], timeoutMs: 8000, maxBytes: 1024 * 1024 })
  }
  function up() { var i = folder.lastIndexOf("/"); if (i > 0) open(folder.slice(0, i)); else if (folder !== "/") open("/") }
  function isChosen(path) { return chosen.indexOf(path) >= 0 }
  function toggle(index, shift) {
    var e = entries[index]
    if (!e || e.dir) return
    if (!multiple) { finish([e.path]); return }
    var list = chosen.slice()
    if (shift && anchorIndex >= 0) {
      var a = Math.min(anchorIndex, index), b = Math.max(anchorIndex, index)
      for (var i = a; i <= b; i++) if (!entries[i].dir && list.indexOf(entries[i].path) < 0) list.push(entries[i].path)
    } else {
      var at = list.indexOf(e.path)
      if (at >= 0) list.splice(at, 1)
      else list.push(e.path)
      anchorIndex = index
    }
    chosen = list
  }
  function allOrNone() { chosen = chosen.length === pictures.length ? [] : pictures.map(function(e) { return e.path }) }
  function finish(paths) {
    var then = done
    lastFolder = folder
    close()
    if (then && paths && paths.length) then(paths)
  }
  function close() { visible = false; done = null; chosen = [] }

  Keys.onPressed: function(e) {
    if (e.key === Qt.Key_Escape) close()
    else if ((e.key === Qt.Key_Return || e.key === Qt.Key_Enter) && chosen.length) finish(chosen)
    else if (e.key === Qt.Key_A && (e.modifiers & Qt.ControlModifier) && multiple) allOrNone()
    else if (e.key === Qt.Key_Backspace) up()
    else return
    e.accepted = true
  }
  // (A click beside it: nothing chosen, it goes.)
  TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: function(p) { if (!panel.contains(panel.mapFromItem(pk, p.position.x, p.position.y))) pk.close() } }

  Rectangle {
    id: panel
    anchors.centerIn: parent
    width: Math.min(920, parent.width - 64)
    height: Math.min(680, parent.height - 64)
    radius: 12
    color: pk.theme ? pk.theme.surface : "white"
    border.width: 1
    border.color: pk.theme ? pk.theme.line : "#ddd"

    // Its name, places, close.
    Item {
      id: head
      x: 18
      y: 14
      width: parent.width - 36
      height: 34
      Text {
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: pk.multiple ? "Choose pictures" : "Choose a picture"
        font.family: pk.theme ? pk.theme.uiFont : ""
        font.pixelSize: 16
        font.weight: Font.DemiBold
        color: pk.theme ? pk.theme.text : "black"
      }
      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 6
        Repeater {
          model: [["Pictures", "/Pictures"], ["Downloads", "/Downloads"], ["Desktop", "/Desktop"], ["Home", ""]]
          delegate: Chip {
            required property var modelData
            objectName: "pickerPlace_" + modelData[0]
            theme: pk.theme
            text: modelData[0]
            checked: pk.folder === pk.home() + modelData[1]
            onClicked: pk.open(pk.home() + modelData[1])
          }
        }
        IconButton { theme: pk.theme; icon: pk.theme ? pk.theme.icons.close : ""; size: 30; iconSize: 15; tip: "Cancel  Esc"; onClicked: pk.close() }
      }
    }
    // Where: up a folder, the folder.
    Row {
      id: where
      x: 14
      anchors.top: head.bottom
      anchors.topMargin: 8
      spacing: 6
      IconButton {
        objectName: "pickerUp"
        theme: pk.theme; icon: pk.theme ? pk.theme.icons.back : ""; size: 28; iconSize: 14
        tip: "Up a folder  Backspace"
        active: pk.folder !== "/"
        onClicked: pk.up()
      }
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: panel.width - 80
        elide: Text.ElideMiddle
        textFormat: Text.PlainText
        text: pk.tilde(pk.folder)
        font.family: pk.theme ? pk.theme.uiFont : ""
        font.pixelSize: 13
        color: pk.theme ? pk.theme.muted : "gray"
      }
    }

    // Folders, then pictures.
    GridView {
      id: grid
      objectName: "pickerGrid"
      anchors.top: where.bottom
      anchors.topMargin: 10
      anchors.bottom: foot.top
      anchors.bottomMargin: 8
      x: 14
      width: panel.width - 28
      clip: true
      readonly property int across: Math.max(2, Math.floor(width / 170))
      cellWidth: Math.floor(width / across)
      cellHeight: Math.round(cellWidth * 0.75) + 30
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }
      model: pk.entries
      delegate: Item {
        id: cell
        required property var modelData
        required property int index
        readonly property bool on: !modelData.dir && pk.isChosen(modelData.path)
        objectName: modelData.dir ? "pickerFolder" : "pickerPicture"
        width: grid.cellWidth
        height: grid.cellHeight
        Rectangle {
          id: thumb
          x: 4
          y: 4
          width: parent.width - 8
          height: parent.height - 34
          radius: 8
          color: pk.theme ? Qt.alpha(pk.theme.text, cellHover.hovered ? 0.1 : 0.05) : "#eee"
          border.width: cell.on ? 2 : 1
          border.color: cell.on ? (pk.theme ? pk.theme.accent : "blue") : (pk.theme ? Qt.alpha(pk.theme.text, 0.08) : "#ddd")
          clip: true
          Image {
            visible: !cell.modelData.dir
            anchors.fill: parent
            anchors.margins: cell.on ? 2 : 1
            source: cell.modelData.dir ? "" : "file://" + cell.modelData.path
            sourceSize.width: 320
            sourceSize.height: 240
            fillMode: Image.PreserveAspectCrop
            asynchronous: true
            cache: true
          }
          Text {
            visible: cell.modelData.dir
            anchors.centerIn: parent
            textFormat: Text.PlainText
            text: pk.theme ? pk.theme.icons.folder : ""
            font.family: pk.theme ? pk.theme.iconFont : ""
            font.pixelSize: 34
            color: pk.theme ? pk.theme.muted : "gray"
          }
          // Chosen: a tick at its corner.
          Rectangle {
            visible: cell.on
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 6
            width: 22
            height: 22
            radius: 11
            color: pk.theme ? pk.theme.accent : "blue"
            Text {
              anchors.centerIn: parent
              textFormat: Text.PlainText
              text: pk.theme ? pk.theme.icons.check : "✓"
              font.family: pk.theme ? pk.theme.iconFont : ""
              font.pixelSize: 12
              color: "white"
            }
          }
        }
        Text {
          x: 6
          y: thumb.y + thumb.height + 6
          width: parent.width - 12
          elide: Text.ElideMiddle
          textFormat: Text.PlainText
          text: cell.modelData.name
          font.family: pk.theme ? pk.theme.uiFont : ""
          font.pixelSize: 12
          color: pk.theme ? (cell.on ? pk.theme.text : pk.theme.muted) : "gray"
        }
        HoverHandler { id: cellHover; cursorShape: Qt.PointingHandCursor }
        TapHandler {
          gesturePolicy: TapHandler.ReleaseWithinBounds
          id: cellTap
          onTapped: {
            if (cell.modelData.dir) pk.open(cell.modelData.path)
            else pk.toggle(cell.index, (cellTap.point.modifiers & Qt.ShiftModifier) !== 0)
          }
        }
      }
      Text {
        visible: !pk.loading && pk.pictures.length === 0
        anchors.centerIn: parent
        anchors.verticalCenterOffset: pk.entries.length ? grid.contentHeight / 2 + 30 : 0
        textFormat: Text.PlainText
        text: "No pictures here"
        font.family: pk.theme ? pk.theme.uiFont : ""
        font.pixelSize: 13
        color: pk.theme ? pk.theme.muted : "gray"
      }
    }

    // How many; the file dialog; Cancel, Add.
    Item {
      id: foot
      x: 18
      width: parent.width - 36
      height: 52
      anchors.bottom: parent.bottom
      Row {
        anchors.verticalCenter: parent.verticalCenter
        spacing: 14
        Text {
          objectName: "pickerAll"
          visible: pk.multiple && pk.pictures.length > 0
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: pk.chosen.length === pk.pictures.length ? "Choose none" : "Select all"
          font.family: pk.theme ? pk.theme.uiFont : ""
          font.pixelSize: 13
          color: allHover.hovered ? pk.theme.text : pk.theme.muted
          HoverHandler { id: allHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: pk.allOrNone() }
        }
        Text {
          visible: pk.multiple
          anchors.verticalCenter: parent.verticalCenter
          textFormat: Text.PlainText
          text: pk.chosen.length ? pk.chosen.length + " chosen  ·  Shift+click for a run of them" : "Click pictures to choose them"
          font.family: pk.theme ? pk.theme.uiFont : ""
          font.pixelSize: 12
          color: pk.theme ? pk.theme.faint : "gray"
        }
      }
      Row {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 8
        Text {
          visible: pk.fallback !== null
          anchors.verticalCenter: parent.verticalCenter
          rightPadding: 6
          textFormat: Text.PlainText
          text: "The file dialog…"
          font.family: pk.theme ? pk.theme.uiFont : ""
          font.pixelSize: 12
          color: dialogHover.hovered ? pk.theme.text : pk.theme.muted
          HoverHandler { id: dialogHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { gesturePolicy: TapHandler.ReleaseWithinBounds; onTapped: { var f = pk.fallback; pk.close(); if (f) f() } }
        }
        TextButton { theme: pk.theme; text: "Cancel"; onClicked: pk.close() }
        TextButton {
          objectName: "pickerAdd"
          visible: pk.multiple
          theme: pk.theme
          primary: true
          opacity: pk.chosen.length ? 1 : 0.45
          text: pk.chosen.length > 1 ? "Add " + pk.chosen.length + " pictures" : "Add picture"
          onClicked: if (pk.chosen.length) pk.finish(pk.chosen)
        }
      }
    }
  }
}
