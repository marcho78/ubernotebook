import QtQuick
import QtQuick.Controls
import QtQuick.Effects

// What's new: a newer version's release notes (or, up to date, the notes of
// the one running, from CHANGELOG.md), read here in Omanote. With a newer
// one: Update now (Omanote installed from git updates itself with `omarchy
// plugin update`, and starts again), or the command to run, to copy.
Popup {
  id: rn

  property var theme: null
  property var service: null
  readonly property var updates: service && service.updates ? service.updates : null
  property var shown: ({ title: "", markdown: "", url: "" })

  objectName: "releaseNotes"
  anchors.centerIn: Overlay.overlay
  width: Math.min(640, (parent ? parent.width : 640) - 48)
  height: Math.min(620, (parent ? parent.height : 620) - 48)
  modal: true
  focus: true
  padding: 0
  closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

  Overlay.modal: Rectangle { color: Qt.rgba(0, 0, 0, rn.theme && rn.theme.dark ? 0.5 : 0.3) }

  // What's new (`own`: what's in the version you have).
  property bool own: false
  function show(mine) {
    if (!updates) return
    own = mine === true
    shown = updates.notes(own)
    copied = false
    open()
    notesFlick.contentY = 0
    contentItem.forceActiveFocus()
  }
  property bool copied: false
  // When the newest came out: " Released 2 Nov 2026."
  readonly property string released: {
    var r = updates && updates.latest ? updates.latest : null
    var t = r && r.date ? Date.parse(r.date) : NaN
    return isNaN(t) ? "" : " " + (updates.newer.length === 1 ? "It came out " : "The newest came out ") + Qt.formatDate(new Date(t), "d MMMM yyyy") + "."
  }

  background: Item {
    Rectangle { id: plate; anchors.fill: parent; radius: 16; color: rn.theme.surface; border.width: 1; border.color: rn.theme.line; visible: false }
    MultiEffect { source: plate; anchors.fill: plate; shadowEnabled: true; shadowColor: rn.theme.shadow; shadowBlur: 1.0; shadowVerticalOffset: 14; autoPaddingEnabled: true }
  }

  contentItem: Item {
    // The heading: what's new, and the version you have.
    Column {
      id: head
      x: 28
      y: 24
      width: parent.width - 80
      spacing: 4
      Text {
        objectName: "releaseNotesTitle"
        width: parent.width
        elide: Text.ElideRight
        textFormat: Text.PlainText
        text: rn.shown.title
        font.family: rn.theme.uiFont
        font.pixelSize: 20
        font.weight: Font.DemiBold
        color: rn.theme.text
      }
      Text {
        width: parent.width
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: rn.updates ? (rn.updates.available && !rn.own ? "You have " + rn.updates.current + "." + rn.released : "Omanote " + rn.updates.current + (rn.updates.status === "current" ? ", the newest." : rn.updates.available ? "; " + rn.updates.latest.version + " is available." : ".")) : ""
        font.family: rn.theme.uiFont
        font.pixelSize: 13
        color: rn.theme.muted
      }
    }
    IconButton {
      anchors.right: parent.right
      anchors.rightMargin: 14
      y: 16
      theme: rn.theme
      icon: rn.theme.icons.close
      onClicked: rn.close()
    }
    Rectangle { y: head.y + head.height + 18; width: parent.width; height: 1; color: rn.theme.line }

    // The notes.
    Flickable {
      id: notesFlick
      x: 28
      y: head.y + head.height + 19
      width: parent.width - 56
      height: foot.y - y - 1
      contentHeight: notesText.height + 40
      clip: true
      boundsBehavior: Flickable.StopAtBounds
      ScrollBar.vertical: ScrollBar { policy: notesFlick.contentHeight > notesFlick.height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff }
      Text {
        id: notesText
        objectName: "releaseNotesText"
        y: 18
        width: notesFlick.width - 12
        wrapMode: Text.Wrap
        // (Release notes come without pictures or HTML: nothing in them is fetched.)
        textFormat: Text.MarkdownText
        text: rn.shown.markdown
        font.family: rn.theme.uiFont
        font.pixelSize: 14
        lineHeight: 1.25
        color: rn.theme.text
        linkColor: rn.theme.accent
        onLinkActivated: function(link) { if (/^https?:/.test(link) && rn.service && rn.service.store) rn.service.store.openUrl(link) }
        HoverHandler { cursorShape: notesText.hoveredLink ? Qt.PointingHandCursor : Qt.ArrowCursor }
      }
    }

    // Update now (or how), the release on GitHub, close.
    Item {
      id: foot
      anchors.bottom: parent.bottom
      width: parent.width
      height: footRow.height + 32 + (problemText.visible ? problemText.height + 8 : 0)
      Rectangle { width: parent.width; height: 1; color: rn.theme.line }
      Text {
        id: problemText
        objectName: "releaseNotesProblem"
        visible: rn.updates !== null && rn.updates.installing !== "" && rn.updates.installing !== "running"
        x: 28
        y: 14
        width: parent.width - 56
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        text: rn.updates ? rn.updates.installing : ""
        font.family: rn.theme.uiFont
        font.pixelSize: 12
        color: rn.theme.urgent
      }
      Row {
        id: footRow
        x: 28
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 16
        spacing: 8
        // Not from git: the command, to copy.
        Rectangle {
          visible: rn.updates !== null && rn.updates.available && !rn.updates.managed && !rn.own
          anchors.verticalCenter: parent.verticalCenter
          width: Math.min(300, commandText.implicitWidth + 24)
          height: 32
          radius: 8
          color: Qt.alpha(rn.theme.text, 0.05)
          border.width: 1
          border.color: rn.theme.line
          Text {
            id: commandText
            x: 12
            width: parent.width - 24
            anchors.verticalCenter: parent.verticalCenter
            elide: Text.ElideMiddle
            textFormat: Text.PlainText
            text: rn.updates ? rn.updates.updateCommand : ""
            font.family: rn.theme.monoFont
            font.pixelSize: 12
            color: rn.theme.text
          }
        }
        TextButton {
          objectName: "releaseNotesCopy"
          visible: rn.updates !== null && rn.updates.available && !rn.updates.managed && !rn.own
          anchors.verticalCenter: parent.verticalCenter
          theme: rn.theme
          icon: rn.copied ? rn.theme.icons.check : rn.theme.icons.copy
          text: rn.copied ? "Copied" : "Copy"
          onClicked: { if (rn.service && rn.service.store) rn.service.store.copyText(rn.updates.updateCommand); rn.copied = true }
        }
        TextButton {
          objectName: "releaseNotesUpdate"
          visible: rn.updates !== null && rn.updates.available && rn.updates.managed && !rn.own
          anchors.verticalCenter: parent.verticalCenter
          theme: rn.theme
          primary: true
          text: rn.updates && rn.updates.installing === "running" ? "Updating…" : "Update now"
          onClicked: if (rn.updates.installing !== "running") rn.updates.install()
        }
        TextButton {
          objectName: "releaseNotesGitHub"
          visible: rn.shown.url !== ""
          anchors.verticalCenter: parent.verticalCenter
          theme: rn.theme
          icon: rn.theme.icons.openExternal
          text: "On GitHub"
          onClicked: if (rn.service && rn.service.store) rn.service.store.openUrl(rn.shown.url)
        }
      }
      TextButton {
        anchors.right: parent.right
        anchors.rightMargin: 28
        anchors.verticalCenter: footRow.verticalCenter
        theme: rn.theme
        text: "Close"
        onClicked: rn.close()
      }
    }
  }
}
