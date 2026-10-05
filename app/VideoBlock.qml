import QtQuick
import QtQuick.Controls
import QtMultimedia
import "../Files.js" as Files
import "../Audio.js" as Audio

// A video on a page in Pages (a file copied into Pages/assets): it plays
// here, with play and pause, where it is (a click or a drag on the bar goes
// there), the time, and the sound on or off; its name under it, and Open
// (in your video player). Not added yet, it asks for one. Its colors (the
// controls', the card's) are Pages' or your own.
DataCard {
  id: vb
  kind: "video"

  readonly property bool has: info.src !== ""
  function sample() { return info.name || "Video" }

  readonly property bool playing: player.playbackState === MediaPlayer.PlayingState
  readonly property real ratio: {
    var r = output.sourceRect
    if (r.width > 0 && r.height > 0) return r.width / r.height
    return still.implicitWidth > 0 && still.implicitHeight > 0 ? still.implicitWidth / still.implicitHeight : 16 / 9
  }
  readonly property real videoH: Math.min(560, (width - 20) / ratio)

  function toggle() {
    if (!has) return
    if (player.source.toString() === "") player.source = editor.assetUrl(info.src)
    if (playing) player.pause()
    else {
      if (editor) editor.playingUid = uid
      player.play()
    }
  }
  function seekTo(f) {
    if (player.source.toString() === "") player.source = editor.assetUrl(info.src)
    player.position = Math.round(Math.max(0, Math.min(1, f)) * player.duration)
  }
  Connections {
    target: vb.editor
    function onPlayingUidChanged() { if (vb.editor.playingUid !== vb.uid && vb.playing) player.pause() }
  }

  MediaPlayer {
    id: player
    videoOutput: output
    audioOutput: AudioOutput { id: sound }
  }

  width: available
  height: card.height

  Rectangle {
    id: card
    width: vb.width
    height: vb.has ? stage.height + caption.height + 20 : 54
    radius: 10
    color: vb.fill
    border.width: 1
    border.color: Qt.alpha(vb.words, vb.pointerIn ? 0.14 : 0.08)

    // Not added yet.
    Item {
      visible: !vb.has
      anchors.fill: parent
      Rectangle {
        id: badge
        x: 10
        anchors.verticalCenter: parent.verticalCenter
        width: 36
        height: 36
        radius: 8
        color: Qt.alpha(vb.accent, 0.14)
        Text { anchors.centerIn: parent; textFormat: Text.PlainText; text: vb.theme ? vb.theme.icons.video : ""; font.family: vb.theme ? vb.theme.iconFont : ""; font.pixelSize: 19; color: vb.accent }
      }
      Text {
        x: badge.x + badge.width + 12
        anchors.verticalCenter: parent.verticalCenter
        textFormat: Text.PlainText
        text: vb.readOnly ? "A video, not added" : "Add a video (or drop one on the page)"
        font.family: vb.editor ? vb.editor.uiFamily : ""
        font.pixelSize: 14
        color: vb.faint
      }
      HoverHandler { cursorShape: vb.readOnly ? Qt.ArrowCursor : Qt.PointingHandCursor }
      TapHandler { enabled: !vb.readOnly; onTapped: vb.act("pick", null) }
    }

    // The video.
    Rectangle {
      id: stage
      objectName: "videoScreen"
      visible: vb.has
      x: 10
      y: 10
      width: parent.width - 20
      height: vb.videoH
      radius: 6
      color: "black"
      clip: true
      VideoOutput {
        id: output
        anchors.fill: parent
        fillMode: VideoOutput.PreserveAspectFit
      }
      // Its still, until it plays.
      Image {
        id: still
        anchors.fill: parent
        visible: !vb.playing && player.position === 0 && status === Image.Ready
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        source: vb.info.poster && vb.editor ? vb.editor.assetUrl(vb.info.poster) : ""
        // (Decoded no bigger than the block can show.)
        sourceSize.width: 1920
        sourceSize.height: 1920
      }
      // Paused or not started: a big play button.
      Rectangle {
        visible: !vb.playing
        anchors.centerIn: parent
        width: 64
        height: 64
        radius: 32
        color: Qt.rgba(0, 0, 0, 0.55)
        Text { anchors.centerIn: parent; anchors.horizontalCenterOffset: 2; textFormat: Text.PlainText; text: vb.theme ? vb.theme.icons.play : ""; font.family: vb.theme ? vb.theme.iconFont : ""; font.pixelSize: 34; color: "white" }
      }
      HoverHandler { id: screenHover; cursorShape: Qt.PointingHandCursor }
      TapHandler { onTapped: vb.toggle() }
      // The controls, while the pointer's over it (or it's paused part way).
      Rectangle {
        id: controls
        visible: screenHover.hovered || (!vb.playing && player.position > 0)
        anchors.bottom: parent.bottom
        width: parent.width
        height: 40
        gradient: Gradient {
          GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0) }
          GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.7) }
        }
        Row {
          x: 10
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: 4
          spacing: 10
          Text {
            objectName: "videoPlay"
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: vb.theme ? (vb.playing ? vb.theme.icons.pause : vb.theme.icons.play) : ""
            font.family: vb.theme ? vb.theme.iconFont : ""
            font.pixelSize: 20
            color: "white"
            TapHandler { onTapped: vb.toggle() }
          }
          // Where it is: a click or a drag goes there.
          Item {
            id: bar
            objectName: "videoBar"
            anchors.verticalCenter: parent.verticalCenter
            width: controls.width - 150
            height: 14
            Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 4; radius: 2; color: Qt.rgba(1, 1, 1, 0.3) }
            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: player.duration > 0 ? parent.width * player.position / player.duration : 0
              height: 4
              radius: 2
              color: vb.look.color ? vb.accent : "white"
            }
            TapHandler { onTapped: function(p) { vb.seekTo(p.position.x / bar.width) } }
            DragHandler { target: null; onCentroidChanged: if (active) vb.seekTo(centroid.position.x / bar.width) }
          }
          Text {
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: Audio.clock(player.position / 1000) + " / " + Audio.clock(player.duration / 1000)
            font.family: vb.editor ? vb.editor.uiFamily : ""
            font.pixelSize: 11
            font.features: { "tnum": 1 }
            color: "white"
          }
          Text {
            objectName: "videoMute"
            anchors.verticalCenter: parent.verticalCenter
            textFormat: Text.PlainText
            text: vb.theme ? (sound.muted ? vb.theme.icons.micOff : vb.theme.icons.volume) : ""
            font.family: vb.theme ? vb.theme.iconFont : ""
            font.pixelSize: 16
            color: "white"
            TapHandler { onTapped: sound.muted = !sound.muted }
          }
        }
      }
      Text {
        visible: player.error !== MediaPlayer.NoError
        anchors.centerIn: parent
        anchors.verticalCenterOffset: 50
        textFormat: Text.PlainText
        text: "The video couldn't be played"
        font.family: vb.editor ? vb.editor.uiFamily : ""
        font.pixelSize: 13
        color: "white"
      }
    }

    // Its name, and Open.
    Item {
      id: caption
      visible: vb.has
      x: 12
      y: stage.y + stage.height + 2
      width: parent.width - 20
      height: vb.has ? 34 : 0
      Text {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width - tools.width - 8
        elide: Text.ElideMiddle
        textFormat: Text.PlainText
        text: vb.info.name + "  \u00b7  " + Files.sizeLabel(vb.info.size)
        font.family: vb.editor ? vb.editor.uiFamily : ""
        font.pixelSize: 12
        color: vb.faint
      }
      Row {
        id: tools
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        IconButton {
          id: colorButton
          objectName: "videoColors"
          visible: !vb.readOnly && (vb.pointerIn || vb.trying !== null)
          theme: vb.theme; icon: vb.theme ? vb.theme.icons.palette : ""; size: 28; iconSize: 14; tint: vb.words
          tip: "Its colors"
          onClicked: vb.askColors(colorButton)
        }
        IconButton {
          objectName: "videoOpen"
          theme: vb.theme; icon: vb.theme ? vb.theme.icons.openExternal : ""; size: 28; iconSize: 14; tint: vb.words
          tip: "Open it in your video player"
          onClicked: vb.act("open", null)
        }
      }
    }
  }
}
