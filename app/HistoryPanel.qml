import QtQuick
import QtQuick.Controls
import QtQuick.Effects
import "../Workspace.js" as Workspace

// A page's history (the page's ⋯ menu): the versions Uber Notebook kept of it,
// newest first, and the one picked shown as it was. "Restore this version"
// puts it back (the page as it is now is kept first, and Undo takes it back
// too). Versions are kept every ten minutes while you write, and before an
// agent or a command changes the page (Workspace.qml).
Popup {
  id: panel

  property var theme: null
  property var workspace: null
  // The view (DocView), for the page's look and putting a version back.
  property var view: null

  property string pageId: ""
  property var versions: []
  // What each says (when it was kept), and why it was kept, once it's read.
  readonly property var labels: Workspace.versionLabels(versions, new Date())
  property var whys: ({})
  property int current: -1
  // The version shown: { kept, why, page }.
  property var shown: null
  property bool listing: false
  property bool reading: false

  signal restoreRequested(var page, string label)

  readonly property alias previewEditor: preview

  anchors.centerIn: Overlay.overlay
  width: Math.min(1080, (parent ? parent.width : 1080) - 64)
  height: Math.min(760, (parent ? parent.height : 760) - 48)
  modal: true
  focus: true
  padding: 0
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, panel.theme && panel.theme.dark ? 0.5 : 0.3) }

  enter: Transition {
    ParallelAnimation {
      NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 120 }
      NumberAnimation { property: "scale"; from: 0.98; to: 1; duration: 150; easing.type: Easing.OutCubic }
    }
  }
  exit: Transition { NumberAnimation { property: "opacity"; from: 1; to: 0; duration: 90 } }

  function openFor(id) {
    pageId = id
    whys = ({})
    versions = []
    current = -1
    shown = null
    preview.load([])
    listing = true
    open()
    list.forceActiveFocus()
    workspace.listVersions(id, function(got) {
      if (panel.pageId !== id) return
      panel.listing = false
      panel.versions = got
      if (got.length) panel.pick(0)
      panel.readWhys(id, got)
    })
  }

  function pick(i) {
    if (i < 0 || i >= versions.length) return
    current = i
    var id = pageId
    var name = versions[i].name
    reading = true
    workspace.readVersion(id, name, function(v) {
      if (panel.pageId !== id || panel.current < 0 || panel.versions[panel.current].name !== name) return
      panel.reading = false
      panel.shown = v
      if (v) { var w = Object.assign({}, panel.whys); w[name] = v.why; panel.whys = w }
      preview.load(v ? Workspace.flatten(v.page) : [])
      previewScroll.contentY = 0
    })
  }

  // Why each was kept, for the list (read in the background, newest first).
  function readWhys(id, list) {
    var names = list.slice(0, 100).map(function(v) { return v.name })
    function next() {
      if (panel.pageId !== id || names.length === 0) return
      var name = names.shift()
      if (panel.whys[name] !== undefined) { next(); return }
      panel.workspace.readVersion(id, name, function(v) {
        if (panel.pageId !== id) return
        // (A new object: the same one again wouldn't tell the list.)
        var w = Object.assign({}, panel.whys)
        w[name] = v ? v.why : ""
        panel.whys = w
        Qt.callLater(next)
      })
    }
    next()
  }

  function labelOf(i) { return i >= 0 && i < labels.length ? labels[i] : "" }

  function restore() {
    if (!shown || (view && view.locked)) return
    var page = shown.page
    var label = labelOf(current)
    close()
    restoreRequested(page, label)
  }

  background: Item {
    Rectangle { id: plate; anchors.fill: parent; radius: 14; color: panel.theme.surface; border.width: 1; border.color: panel.theme.line; visible: false }
    MultiEffect { source: plate; anchors.fill: plate; shadowEnabled: true; shadowColor: panel.theme.shadow; shadowBlur: 1.0; shadowVerticalOffset: 12; autoPaddingEnabled: true }
  }

  contentItem: Item {
    // ---- the versions ----------------------------------------------------------------------------
    Item {
      id: side
      width: 270
      height: parent.height

      Column {
        id: head
        x: 18
        y: 18
        width: parent.width - 36
        spacing: 4
        Text {
          textFormat: Text.PlainText
          text: "Page history"
          font.family: panel.theme.uiFont
          font.pixelSize: 15
          font.weight: Font.DemiBold
          color: panel.theme.text
        }
        Text {
          textFormat: Text.PlainText
          width: parent.width
          wrapMode: Text.Wrap
          text: "Kept every ten minutes while you write, and before an agent changes the page."
          font.family: panel.theme.uiFont
          font.pixelSize: 11
          color: panel.theme.faint
        }
      }

      ListView {
        id: list
        x: 8
        y: head.y + head.height + 12
        width: parent.width - 16
        height: parent.height - y - 8
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        model: panel.versions
        currentIndex: panel.current
        keyNavigationEnabled: false
        Keys.onUpPressed: panel.pick(Math.max(0, panel.current - 1))
        Keys.onDownPressed: panel.pick(Math.min(panel.versions.length - 1, panel.current + 1))
        Keys.onReturnPressed: panel.restore()
        delegate: Rectangle {
          id: row
          required property var modelData
          required property int index
          readonly property bool picked: index === panel.current
          width: list.width
          readonly property string why: Workspace.versionWhy(panel.whys[modelData.name] || "")
          height: rowText.implicitHeight + 18
          radius: 8
          color: picked ? Qt.alpha(panel.theme.accent, 0.14) : rowHover.hovered ? panel.theme.hover : "transparent"
          Column {
            id: rowText
            x: 12
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width - 24
            spacing: 2
            Text {
              width: parent.width
              textFormat: Text.PlainText
              text: panel.labelOf(row.index)
              elide: Text.ElideRight
              font.family: panel.theme.uiFont
              font.pixelSize: 13
              font.weight: row.picked ? Font.DemiBold : Font.Normal
              color: row.picked ? panel.theme.accent : panel.theme.text
            }
            Text {
              visible: row.why !== ""
              width: parent.width
              textFormat: Text.PlainText
              text: row.why
              elide: Text.ElideRight
              font.family: panel.theme.uiFont
              font.pixelSize: 11
              color: panel.theme.muted
            }
          }
          HoverHandler { id: rowHover; cursorShape: Qt.PointingHandCursor }
          TapHandler { onTapped: { list.forceActiveFocus(); panel.pick(row.index) } }
        }
      }

      Text {
        visible: !panel.listing && panel.versions.length === 0
        x: 18
        y: list.y + 6
        width: parent.width - 36
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: "No earlier versions of this page yet. Uber Notebook keeps one every ten minutes while you write, and one before an agent or a command changes it."
        font.family: panel.theme.uiFont
        font.pixelSize: 12
        lineHeight: 1.2
        color: panel.theme.muted
      }

      Rectangle { anchors.right: parent.right; width: 1; height: parent.height; color: panel.theme.line }
    }

    // ---- the version picked, as it was ------------------------------------------------------------
    Item {
      id: main
      x: side.width
      width: parent.width - side.width
      height: parent.height

      Rectangle {
        anchors.fill: parent
        anchors.margins: 1
        radius: 13
        color: panel.theme.background
      }
      Rectangle { x: 1; width: 14; height: parent.height - 2; y: 1; color: panel.theme.background }

      Item {
        id: top
        x: 28
        width: parent.width - 56
        height: 64
        Column {
          anchors.verticalCenter: parent.verticalCenter
          width: parent.width - restoreButton.width - 120
          spacing: 2
          Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            text: panel.shown ? (panel.shown.page.icon ? panel.shown.page.icon + "  " : "") + (panel.shown.page.title || "Untitled") : ""
            font.family: panel.theme.uiFont
            font.pixelSize: 15
            font.weight: Font.DemiBold
            color: panel.theme.text
          }
          Text {
            textFormat: Text.PlainText
            width: parent.width
            elide: Text.ElideRight
            text: panel.shown ? panel.labelOf(panel.current) + (Workspace.versionWhy(panel.shown.why) ? "  \u00b7  " + Workspace.versionWhy(panel.shown.why) : "") : ""
            font.family: panel.theme.uiFont
            font.pixelSize: 12
            color: panel.theme.muted
          }
        }
        Row {
          anchors.right: parent.right
          anchors.verticalCenter: parent.verticalCenter
          spacing: 8
          IconButton { theme: panel.theme; label: "Cancel"; onClicked: panel.close() }
          Rectangle {
            id: restoreButton
            readonly property bool can: panel.shown !== null && !(panel.view && panel.view.locked)
            width: restoreLabel.implicitWidth + 32
            height: 34
            radius: 17
            opacity: can ? 1 : 0.45
            color: restoreTap.pressed && can ? Qt.darker(panel.theme.accent, 1.15) : panel.theme.accent
            Text {
              id: restoreLabel
              textFormat: Text.PlainText
              anchors.centerIn: parent
              text: "Restore this version"
              font.family: panel.theme.uiFont
              font.pixelSize: 13
              font.weight: Font.DemiBold
              color: panel.theme.accent.hslLightness > 0.6 ? "#14161c" : "white"
            }
            HoverHandler { cursorShape: restoreButton.can ? Qt.PointingHandCursor : Qt.ArrowCursor }
            TapHandler { id: restoreTap; enabled: restoreButton.can; onTapped: panel.restore() }
          }
        }
        Rectangle { anchors.bottom: parent.bottom; x: -28; width: parent.width + 56; height: 1; color: panel.theme.line }
      }

      Flickable {
        id: previewScroll
        x: 1
        y: top.height
        width: parent.width - 2
        height: parent.height - top.height - 1
        clip: true
        contentWidth: width
        contentHeight: preview.height + 80
        boundsBehavior: Flickable.StopAtBounds
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Editor {
          id: preview
          x: Math.max(40, (previewScroll.width - width) / 2)
          y: 28
          width: Math.min(720, previewScroll.width - 80)
          height: implicitHeight
          layout: "doc"
          readOnly: true
          enabled: true
          contentWidth: width
          family: panel.view ? panel.view.family : panel.theme.uiFont
          monoFamily: panel.theme.monoFont
          uiFamily: panel.theme.uiFont
          ink: panel.theme.text
          muted: panel.theme.muted
          accent: panel.theme.accent
          linkColor: panel.theme.accent
          selectionColor: Qt.alpha(panel.theme.accent, 0.3)
          dark: panel.theme.dark
          paper: panel.theme.background
          smallText: panel.view ? panel.view.small : false
          assetUrl: function(src) { return panel.workspace ? panel.workspace.assetUrl(src) : "" }
          pageInfo: function(id) { return panel.workspace ? panel.workspace.pageMeta(id) : null }
          pagesRevision: panel.workspace ? panel.workspace.revision : 0
        }
      }

      Text {
        visible: panel.reading && panel.shown === null
        anchors.centerIn: previewScroll
        textFormat: Text.PlainText
        text: "Reading\u2026"
        font.family: panel.theme.uiFont
        font.pixelSize: 13
        color: panel.theme.faint
      }
    }
  }
}
