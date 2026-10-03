// Defaults.js - Omanote's settings: their defaults, and what each may be.
//
// Code rather than a JSON file, so Omanote reads no settings file of its own.
// Settings are stored on Omanote's entry in shell.json (by the Omarchy shell),
// holding only what differs from DEFAULTS; Settings.merge() validates them
// against SCHEMA before anything uses them.

var DEFAULTS = {
  barIcon: true,
  // Opens and closes the notebook, and jots a quick note from anywhere.
  shortcut: "SUPER + N",
  quickShortcut: "SUPER + ALT + N",
  // Where the notebooks live: "" is ~/Documents/Omanote (or ~/Omanote when
  // there is no Documents folder). The open profile's folder.
  folder: "",
  // Profiles: notes kept apart (personal, business, the demo...), each a
  // folder of its own: [{ id, name, folder, demo, saved }], `saved` its own
  // settings while another is open (Profiles.js). `profile`: the one open.
  profiles: [],
  profile: "",
  // The notebook floats in the middle of the screen, like a notebook on a
  // desk, at this size; off, it tiles like any other window.
  floating: true,
  width: 1320,
  height: 900,
  // What a new notebook starts with: the choices of the last one you made
  // (each notebook, and each page, can change them).
  pen: "sans",
  paper: "ruled",
  paperColor: "ivory",
  spacing: "regular",
  cover: "navy",
  material: "leather",
  binding: "spiral",
  // A soft paper sound when a notebook opens and a page turns.
  sounds: true,
  // Fade instead of the cover swinging open and the pages turning.
  reduceMotion: false,
  // How fast a page scrolls with a trackpad or a wheel: slower, normal, faster
  // (a trackpad's quicker strokes go further, as on a MacBook, whichever).
  scrollSpeed: "normal",
  // Draw a line through checked items, like crossing them off.
  strikeDone: true,
  // Where the last session left off, so the notebook opens there again.
  lastNotebook: "",
  zoom: 100,
  // Notebooks or Pages: which one Omanote opens in (the one you were in), and
  // the page you were on in Pages.
  space: "notebooks",
  lastPage: "",
  // The Inbox in Pages: where pages agents and scripts add go (Api.qml).
  inbox: "",
  // Where an export goes: "ask" (a folder picker each time) or "folder"
  // (the Exports folder in the notebooks folder).
  exportTo: "ask",
  // Colors of your own you picked last, newest first ("#ff8800,#1e66f5").
  recentColors: "",
  // Where a quick note goes: "notebook" (a page in the Quick notes notebook)
  // or "pages" (a page in the Pages Inbox, its text read as Markdown).
  quickTo: "notebook",
  // A Markdown copy of every page (Pages and notebooks), kept up to date in a
  // folder for Obsidian, git or any editor: off, or on, in `mirrorFolder`
  // ("" is a Markdown folder in the notes folder).
  mirror: false,
  mirrorFolder: "",
  // How the sidebar lists tags: by name ("name") or by color ("color").
  tagSort: "name",
  // The calendar's view, as it was last: month, week, agenda or compact (a
  // small month and the days from the one picked).
  calendarView: "month",
  // How People shows everyone: a list beside the one picked ("list"), or cards.
  peopleLayout: "list",
  // Appearance: colors of your own ("#1e1e2e"), or "" to follow the Omarchy
  // theme: the sidebar, the page (and desk) behind everything, the sections
  // and cards (the sidebar's sections, cards, menus), and the text.
  colorSidebar: "",
  colorPage: "",
  colorCards: "",
  colorText: "",
  // An audio note written out (by voxtype) as soon as it's recorded.
  audioTranscribe: true,
  // The microphone audio notes and dictation record from: a PipeWire
  // source's name ("" is the default one).
  audioInput: "",
  // A voice evened out and made loud enough (a quiet laptop microphone).
  audioBoost: true,
  // Backups (Backups.js): the folder they go in ("" is ~/Documents/Omanote
  // Backups); automatic ones of every profile ("off", "daily", "weekly"),
  // and how many of those are kept (the oldest go to the trash).
  backupFolder: "",
  backupEvery: "off",
  backupKeep: 10,
  // Whether Omanote asks GitHub, once a day, if there's a newer version
  // (Updates.qml); off, only when you ask.
  checkUpdates: true
}

var SCHEMA = {
  types: {
    barIcon: "bool",
    shortcut: "shortcut",
    quickShortcut: "shortcut",
    folder: "folder",
    profiles: "profiles",
    profile: "id",
    floating: "bool",
    width: "int",
    height: "int",
    pen: "string",
    paper: "string",
    paperColor: "string",
    spacing: "string",
    cover: "string",
    material: "string",
    binding: "string",
    sounds: "bool",
    reduceMotion: "bool",
    scrollSpeed: "string",
    strikeDone: "bool",
    lastNotebook: "id",
    zoom: "int",
    space: "string",
    lastPage: "id",
    inbox: "id",
    exportTo: "string",
    recentColors: "string",
    quickTo: "string",
    mirror: "bool",
    mirrorFolder: "folder",
    tagSort: "string",
    calendarView: "string",
    peopleLayout: "string",
    colorSidebar: "string",
    colorPage: "string",
    colorCards: "string",
    colorText: "string",
    audioTranscribe: "bool",
    audioInput: "string",
    audioBoost: "bool",
    backupFolder: "folder",
    backupEvery: "string",
    backupKeep: "int",
    checkUpdates: "bool"
  },
  choices: {
    pen: ["sans", "serif", "hand", "print", "typewriter", "mono", "duo"],
    paper: ["blank", "ruled", "grid", "dots", "graph", "legal"],
    paperColor: ["white", "ivory", "cream", "yellow", "kraft", "gray", "night", "blueprint", "theme"],
    spacing: ["compact", "regular", "roomy"],
    cover: ["navy", "black", "forest", "burgundy", "mustard", "sky", "coral", "lavender", "sage", "sand", "charcoal", "accent"],
    material: ["leather", "linen", "kraft", "plain", "composition"],
    binding: ["spiral", "stitched", "hardcover"],
    space: ["notebooks", "pages"],
    exportTo: ["ask", "folder"],
    quickTo: ["notebook", "pages"],
    tagSort: ["name", "color"],
    calendarView: ["month", "week", "agenda", "compact"],
    peopleLayout: ["list", "cards"],
    scrollSpeed: ["slower", "normal", "faster"],
    backupEvery: ["off", "daily", "weekly"],
    backupKeep: [3, 5, 10, 20, 50]
  },
  ranges: {
    width: [640, 5000],
    height: [480, 4000],
    zoom: [60, 200]
  }
}
