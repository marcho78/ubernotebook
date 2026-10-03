import QtQuick

// A page's scrolling by trackpad and mouse wheel, for a Flickable that
// doesn't take drags (a drag selects text): a trackpad moves it just as the
// fingers do, and when they lift it glides on, slowing down, as on a
// MacBook; a wheel's notch glides a step, and a wheel spun fast adds its
// steps up. `animate` says when the Flickable's own short animation of
// contentY may run (a wheel's notch, a jump to the cursor): not while the
// fingers or a glide move it.
Item {
  id: ss

  property var flick: null
  // A wheel's notch, in pixels.
  property real step: 90
  // How fast, from Settings ("slower", "normal", "faster").
  property string speed: "normal"
  readonly property real speedFactor: speed === "slower" ? 0.65 : speed === "faster" ? 1.6 : 1
  // A trackpad's quicker strokes go further (as on a MacBook): its slow ones
  // as they are, a little more; its fast ones up to five times as far.
  // (Omarchy's Hyprland sends a trackpad's movement at 0.4 of it.)
  property bool accelerate: true
  function gain(dy) { return (accelerate ? Math.min(5, 1.6 + 0.12 * Math.abs(dy)) : 1) * speedFactor }
  // How long the Flickable's animation of a notch takes (ms), to add steps up within it.
  property int notchMs: 120

  readonly property bool animate: !touching && !glide.running
  readonly property bool gliding: glide.running
  property bool touching: false
  // The trackpad says when the fingers lift (ScrollEnd); some don't, and then
  // a pause says it.
  property bool phases: false
  property real velocity: 0
  property var samples: []
  property real notchTarget: 0
  property real notchAt: 0
  property real lastY: 0

  function maxY() { return flick ? Math.max(0, flick.contentHeight - flick.height) : 0 }
  function clamp(y) { return Math.max(0, Math.min(maxY(), y)) }
  function stop() { glide.running = false; velocity = 0 }

  function wheel(event) {
    if (!flick) return
    var pd = event.pixelDelta ? event.pixelDelta.y : 0
    var ad = event.angleDelta ? event.angleDelta.y : 0
    var phase = event.phase !== undefined ? event.phase : Qt.NoScrollPhase
    if (phase !== Qt.NoScrollPhase) phases = true
    // A trackpad (pixels, or a notch in small pieces): as the fingers move.
    if (pd !== 0 || (ad !== 0 && Math.abs(ad) < 120) || (phase !== Qt.NoScrollPhase && ad === 0)) {
      stop()
      if (phase === Qt.ScrollEnd) { release(); return }
      var raw = pd !== 0 ? pd : ad / 120 * step
      if (raw === 0) return
      var dy = raw * gain(raw)
      touching = true
      flick.contentY = Math.round(clamp(flick.contentY - dy))
      var now = Date.now()
      samples = samples.filter(function(s) { return now - s.t < 120 }).concat([{ t: now, dy: dy }])
      if (!phases) pause.restart()
      return
    }
    // A wheel's notch: a step, glided (spun fast, from where the last one goes).
    if (ad === 0) return
    stop()
    touching = false
    var t = Date.now()
    var from = t - notchAt < notchMs ? notchTarget : flick.contentY
    notchTarget = Math.round(clamp(from - ad / 120 * step * speedFactor))
    notchAt = t
    flick.contentY = notchTarget
  }

  // The fingers lifted: on at the speed they went (if they were moving), slowing.
  function release() {
    if (!touching) return
    touching = false
    var now = Date.now()
    var recent = samples.filter(function(s) { return now - s.t < 90 })
    samples = []
    if (recent.length < 2) return
    var sum = recent.reduce(function(a, s) { return a + s.dy }, 0)
    var span = Math.max(16, now - recent[0].t)
    velocity = sum / span * 1000
    if (Math.abs(velocity) < 120) { velocity = 0; return }
    lastY = flick.contentY
    glide.running = true
  }

  Timer { id: pause; interval: 70; onTriggered: ss.release() }

  FrameAnimation {
    id: glide
    onTriggered: {
      // Moved by something else meanwhile (the cursor, a jump): it stops.
      if (Math.abs(ss.flick.contentY - ss.lastY) > 1) { ss.stop(); return }
      var dt = Math.min(0.05, frameTime)
      var y = ss.clamp(ss.flick.contentY - ss.velocity * dt)
      ss.flick.contentY = y
      ss.lastY = y
      // Slowing as a MacBook's does (most of its speed gone in about a second).
      ss.velocity *= Math.pow(0.997, dt * 1000)
      if (Math.abs(ss.velocity) < 15 || y <= 0 || y >= ss.maxY()) ss.stop()
    }
  }
}
