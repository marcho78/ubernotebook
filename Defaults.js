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
  // there is no Documents folder).
  folder: "",
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
  recentColors: ""
}

var SCHEMA = {
  types: {
    barIcon: "bool",
    shortcut: "shortcut",
    quickShortcut: "shortcut",
    folder: "folder",
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
    strikeDone: "bool",
    lastNotebook: "id",
    zoom: "int",
    space: "string",
    lastPage: "id",
    inbox: "id",
    exportTo: "string",
    recentColors: "string"
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
    exportTo: ["ask", "folder"]
  },
  ranges: {
    width: [640, 5000],
    height: [480, 4000],
    zoom: [60, 200]
  }
}
