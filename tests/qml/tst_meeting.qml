import QtQuick
import QtTest
import "../.." as UberNotebook
import "../../app"
import "../../Workspace.js" as Workspace
import "../../Docs.js" as Docs

// Meetings in Pages (voxtype's meeting mode, FakeMeetings.qml here): "/meeting"
// starting one, pausing and stopping it, its transcript into the block when
// voxtype's done, speakers named, meeting mode turned on, one voxtype
// recorded brought in, the agent asked to summarize, its colors, Markdown,
// the meeting button at the top, and the bar on another page.
Item {
  id: root
  width: 1320
  height: 900

  FakeFiles { id: files }
  FakeService { id: service; user: ({ sounds: false }) }
  Theme { id: th }
  UberNotebook.Workspace { id: ws; files: files }
  property string lastToast: ""

  DocView {
    id: view
    anchors.fill: parent
    theme: th
    workspace: ws
    service: service
    onToast: function(text) { root.lastToast = text }
  }

  TestCase {
    name: "Meetings"
    when: windowShown

    readonly property var mt: service.meetings

    function fresh() {
      files.reset()
      view.page = null
      ws.welcomed = false
      ws.written = ({})
      ws.load()
      tryCompare(ws, "ready", true, 2000)
      view.activate()
      tryVerify(function() { return view.page !== null }, 2000)
      view.editor.readOnly = false
      mt.status = "idle"
      mt.meetingId = ""
      mt.finishing = ""
      mt.enabled = true
      mt.available = true
      mt.starts = []
      mt.fetched = []
      view.meetingOwners = ({})
      view.meetingTried = ({})
      root.lastToast = ""
      wait(0)
    }
    function type(text) {
      for (var i = 0; i < text.length; i++) keyClick(text.charAt(i) === " " ? Qt.Key_Space : text.charAt(i))
    }
    function find(item, test) {
      if (!item) return null
      if (item.visible && test(item)) return item
      for (var i = 0; i < item.children.length; i++) {
        var hit = find(item.children[i], test)
        if (hit) return hit
      }
      return null
    }
    function findAll(item, test, out) {
      if (!item) return out
      if (item.visible && test(item)) out.push(item)
      for (var i = 0; i < item.children.length; i++) findAll(item.children[i], test, out)
      return out
    }
    function named(item, name) { return find(item, function(it) { return it.objectName === name }) }
    function win() { return root.Window.window.contentItem }
    function meetingAt(i) { return view.editor.serialize()[i].meeting }
    function indexOfType(t) { return view.editor.serialize().map(function(b) { return b.type }).indexOf(t) }
    function click(item) { verify(item !== null); wait(150); mouseClick(item) }
    function slashMeeting() {
      var e = view.editor
      e.focusBlock(e.uidAt(e.model.count - 1), 0)
      type("/meeting")
      tryVerify(function() { return e.slash !== null && e.slashItems.length > 0 }, 1000)
      compare(e.slashItems[0].id, "meeting")
      keyClick(Qt.Key_Return)
      var at = indexOfType("meeting")
      verify(at >= 0, "a meeting on the page")
      var uid = e.uidAt(at)
      tryVerify(function() { return e.items[uid] && e.items[uid].meetingView }, 1000)
      return { at: at, uid: uid, view: e.items[uid].meetingView }
    }
    function tile(test) {
      var t = null
      tryVerify(function() { t = find(win(), test); return t !== null }, 1000, "the color is on screen")
      wait(250)
      return find(win(), test)
    }

    function test_1_started_paused_stopped_written_out() {
      fresh()
      var sync = ws.createPage({ parent: "", title: "Weekly sync" })
      view.open(sync.id)
      tryVerify(function() { return view.page && view.page.id === sync.id }, 2000)
      wait(50)
      var m = slashMeeting()
      tryCompare(mt, "status", "recording", 1000, "it starts")
      compare(mt.starts[0], "Weekly sync", "named for the page")
      tryVerify(function() { return meetingAt(m.at).id === mt.nextId }, 1000, "the block is that meeting")
      verify(meetingAt(m.at).startedAt !== "")
      tryVerify(function() { return named(m.view, "meetingStop") !== null }, 1000)
      verify(named(m.view, "meetingHeadline").text.indexOf("Recording") === 0, named(m.view, "meetingHeadline").text)
      // Paused, and on again.
      click(named(m.view, "meetingPause"))
      tryCompare(mt, "status", "paused", 1000)
      tryVerify(function() { return named(m.view, "meetingHeadline").text.indexOf("Paused") === 0 }, 1000)
      click(named(m.view, "meetingPause"))
      tryCompare(mt, "status", "recording", 1000)
      // Stopped: voxtype writes it out; then it's in the block.
      click(named(m.view, "meetingStop"))
      tryVerify(function() { return meetingAt(m.at).segments.length === 3 }, 2000, "written out, in the block")
      compare(mt.fetched[0], mt.nextId)
      var me = meetingAt(m.at)
      compare(me.duration, 95)
      compare(me.title, "Weekly sync")
      var chips = []
      tryVerify(function() { chips = findAll(m.view, function(it) { return it.objectName === "speakerChip" }, []); return chips.length === 3 }, 1000, "a turn each")
      compare(chips.map(function(c) { return c.speaker }).join(), "You,Remote,You")
      verify(named(m.view, "meetingSummarize") !== null)
      // Kept in the page's file, and found by search.
      view.commit()
      var page = ws.readPageNow(view.page.id)
      var kept = Workspace.flatten(page).filter(function(b) { return b.type === "meeting" })[0]
      compare(kept.meeting.segments.length, 3)
      verify(Workspace.pageText(page).indexOf("The release notes are done.") >= 0)
      // Undo: before it was written out.
      view.editor.undo()
      tryVerify(function() { return meetingAt(m.at).segments.length === 0 && meetingAt(m.at).id !== "" }, 1000)
      view.editor.redo()
      tryVerify(function() { return meetingAt(m.at).segments.length === 3 }, 1000)
    }

    function test_2_speakers_named_summarized_colored_and_markdown() {
      fresh()
      var e = view.editor
      e.insertBlocksAt(0, [{ type: "meeting", indent: 0, meeting: { id: mt.nextId, title: "Weekly sync", startedAt: "2026-10-02T09:30:00Z", duration: 95,
        segments: [{ start: 1000, end: 4000, speaker: "You", text: "Morning." }, { start: 5000, end: 9000, speaker: "Remote", text: "The release notes are done." }] } }])
      var uid = e.uidAt(0)
      tryVerify(function() { return e.items[uid] && e.items[uid].meetingView }, 1000)
      var mv = e.items[uid].meetingView
      waitForRendering(mv)
      // "Remote" is Sam.
      var remote = null
      tryVerify(function() { remote = find(mv, function(it) { return it.objectName === "speakerChip" && it.speaker === "Remote" }); return remote !== null }, 1000)
      click(remote)
      var field = null
      tryVerify(function() { field = named(win(), "speakerName"); return field !== null }, 1000, "who's this?")
      wait(200)
      field.text = "Sam"
      keyClick(Qt.Key_Return)
      tryVerify(function() { return meetingAt(0).names.Remote === "Sam" }, 1000)
      // Summarized by the agent.
      click(named(mv, "meetingSummarize"))
      tryVerify(function() { return files.launched.length === 1 }, 1000)
      verify(files.launched[0].indexOf("Summarize this meeting") >= 0)
      verify(files.launched[0].indexOf(uid) >= 0, "the meeting block, for the agent")
      // Its colors.
      mouseMove(mv, 120, 20)
      var colors = null
      tryVerify(function() { colors = named(mv, "meetingColors"); return colors !== null }, 1000)
      click(colors)
      mouseClick(tile(function(it) { return it.entry !== undefined && it.entry && it.entry.id === "blue" && it.back === true }))
      tryVerify(function() { return meetingAt(0).background === "blue" }, 1000)
      compare(String(mv.fill), String(Qt.color(Docs.colorEntry("blue").background[th.dark ? 1 : 0])))
      wait(200)
      // As Markdown.
      view.copyMarkdown()
      verify(files.copied.indexOf("**Sam** (0:05): The release notes are done.") > 0, files.copied)
      // Hidden.
      click(named(mv, "meetingTranscript"))
      tryVerify(function() { return meetingAt(0).open === false }, 1000)
    }

    function test_3_meeting_mode_turned_on_and_one_brought_in() {
      fresh()
      mt.enabled = false
      var m = slashMeeting()
      wait(100)
      compare(mt.status, "idle", "not started: meeting mode is off")
      var on = null
      tryVerify(function() { on = named(m.view, "meetingEnable"); return on !== null }, 1000)
      click(on)
      tryVerify(function() { return mt.enabled }, 1000)
      compare(mt.enables, 1)
      tryVerify(function() { return named(m.view, "meetingStart") !== null }, 1000, "now it can start")
      // One voxtype recorded, brought in.
      click(named(m.view, "meetingImport"))
      var choice = null
      tryVerify(function() { choice = find(win(), function(it) { return it.objectName === "meetingChoice" && it.text === "Design review" }); return choice !== null }, 1000)
      wait(200)
      mouseClick(choice)
      tryVerify(function() { return meetingAt(m.at).id === "11111111-2222-3333-4444-555555555555" && meetingAt(m.at).segments.length === 3 }, 2000)
    }

    function test_4_the_button_at_the_top_and_another_page() {
      fresh()
      var e = view.editor
      var first = view.page.id
      e.focusBlock(e.uidAt(0), -1)
      click(named(win(), "meetingButton"))
      tryCompare(mt, "status", "recording", 1000)
      var at = indexOfType("meeting")
      verify(at >= 0)
      tryVerify(function() { return meetingAt(at).id === mt.nextId }, 1000)
      // Again: it's here.
      click(named(win(), "meetingButton"))
      compare(root.lastToast, "It's recording, on this page")
      // Another page: the bar at the foot, to stop it there.
      view.commit()
      var other = ws.createPage({ parent: "", title: "Elsewhere" })
      view.open(other.id)
      tryVerify(function() { return view.page && view.page.id === other.id }, 2000)
      var bar = null
      tryVerify(function() { bar = named(win(), "meetingBar"); return bar !== null }, 1000, "the bar")
      click(find(bar, function(it) { return it.objectName === "recordingDone" }))
      tryVerify(function() {
        var p = ws.readPageNow(first)
        var b = Workspace.flatten(p).filter(function(x) { return x.type === "meeting" })[0]
        return b && b.meeting.segments.length === 3
      }, 2000, "written out into its page")
      // A meeting that ended unseen: its block asks voxtype for it.
      e.insertBlocksAt(0, [{ type: "meeting", indent: 0, meeting: { id: "22222222-3333-4444-5555-666666666666", title: "Unseen" } }])
      tryVerify(function() { return meetingAt(0).segments.length === 3 }, 2000, "fetched by itself")
    }
  }
}
