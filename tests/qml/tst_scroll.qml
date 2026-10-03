import QtQuick
import QtTest
import "../../app"

// Scrolling a page (SmoothScroll.qml): a trackpad moves it as the fingers
// do, at once; lifted while moving, it glides on and slows to a stop (with
// the trackpad saying so, or a pause); stopped first, it doesn't; a wheel's
// notches add up; a glide stops at the end, or when something else moves it.
Item {
  id: root
  width: 600
  height: 400

  Flickable {
    id: flick
    anchors.fill: parent
    contentHeight: 6000
    interactive: false
    Behavior on contentY { enabled: scroller.animate; NumberAnimation { duration: 120 } }
    Rectangle { width: 10; height: 6000; color: "gray" }
  }
  SmoothScroll { id: scroller; flick: flick; step: 90; notchMs: 120; accelerate: false }

  TestCase {
    name: "Scroll"
    when: windowShown

    function pad(dy, phase) { return { pixelDelta: { y: dy }, angleDelta: { y: dy * 2 }, phase: phase === undefined ? Qt.ScrollUpdate : phase } }
    function reset() {
      scroller.stop()
      scroller.touching = false
      scroller.phases = false
      scroller.samples = []
      flick.contentY = 0
      wait(200)
      compare(flick.contentY, 0)
    }

    function test_1_the_fingers_and_a_glide() {
      reset()
      scroller.wheel(pad(0, Qt.ScrollBegin))
      for (var i = 0; i < 8; i++) {
        scroller.wheel(pad(-20))
        compare(flick.contentY, (i + 1) * 20, "as the fingers move: at once, no lag")
        wait(10)
      }
      scroller.wheel(pad(0, Qt.ScrollEnd))
      verify(scroller.gliding, "lifted while moving: it glides on")
      var at = flick.contentY
      wait(150)
      verify(flick.contentY > at + 20, "still going " + flick.contentY)
      tryVerify(function() { return !scroller.gliding }, 3000, "and slows to a stop")
      verify(flick.contentY > 300, "a good way on: " + flick.contentY)
    }

    function test_2_no_word_from_the_trackpad_a_pause_says_it() {
      reset()
      for (var i = 0; i < 6; i++) { scroller.wheel(pad(-25, Qt.NoScrollPhase)); wait(10) }
      compare(flick.contentY, 150)
      tryVerify(function() { return scroller.gliding }, 500, "the pause: lifted")
      tryVerify(function() { return !scroller.gliding }, 3000)
      verify(flick.contentY > 150)
    }

    function test_3_stopped_first_no_glide() {
      reset()
      scroller.wheel(pad(0, Qt.ScrollBegin))
      for (var i = 0; i < 4; i++) { scroller.wheel(pad(-20)); wait(10) }
      wait(200)
      scroller.wheel(pad(0, Qt.ScrollEnd))
      verify(!scroller.gliding)
      compare(flick.contentY, 80)
    }

    function test_4_a_wheel_its_notches_add_up() {
      reset()
      scroller.wheel({ pixelDelta: { y: 0 }, angleDelta: { y: -120 }, phase: Qt.NoScrollPhase })
      scroller.wheel({ pixelDelta: { y: 0 }, angleDelta: { y: -120 }, phase: Qt.NoScrollPhase })
      verify(scroller.animate, "a notch glides")
      tryCompare(flick, "contentY", 180, 1000, "two notches, both")
    }

    // Faster strokes go further (as on a MacBook); Settings' speed scales it.
    function test_6_quicker_strokes_go_further() {
      reset()
      scroller.accelerate = true
      var slow = 2 * scroller.gain(2)
      var fast = 30 * scroller.gain(30)
      verify(slow > 2 && slow < 4, "a slow stroke, about as it is: " + slow)
      verify(fast / 30 > 2 * (slow / 2), "a fast one, much further: " + fast)
      verify(scroller.gain(500) <= 5, "and no more than five times")
      scroller.wheel(pad(-30))
      compare(flick.contentY, Math.round(30 * scroller.gain(30)))
      scroller.speed = "faster"
      verify(scroller.gain(30) > 30 * 0 + fast / 30)
      scroller.speed = "slower"
      verify(scroller.gain(30) < fast / 30)
      scroller.speed = "normal"
      scroller.accelerate = false
      scroller.touching = false
      scroller.samples = []
    }

    function test_5_a_glide_stops_at_the_end_or_when_moved() {
      reset()
      flick.contentY = 5550
      wait(200)
      scroller.wheel(pad(0, Qt.ScrollBegin))
      for (var i = 0; i < 6; i++) { scroller.wheel(pad(-40)); wait(10) }
      scroller.wheel(pad(0, Qt.ScrollEnd))
      tryVerify(function() { return !scroller.gliding }, 2000)
      compare(flick.contentY, 5600, "at the end, stopped")
      // Moved by something else (the cursor): the glide stops.
      flick.contentY = 1000
      wait(200)
      scroller.wheel(pad(0, Qt.ScrollBegin))
      for (var k = 0; k < 6; k++) { scroller.wheel(pad(-40)); wait(10) }
      scroller.wheel(pad(0, Qt.ScrollEnd))
      verify(scroller.gliding)
      flick.contentY = 300
      wait(50)
      verify(!scroller.gliding, "stopped")
      compare(flick.contentY, 300)
    }
  }
}
