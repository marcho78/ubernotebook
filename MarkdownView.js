// MarkdownView.js - Markdown someone else wrote (an agent's answer, a
// release's notes), shown as rich text that Qt draws without fetching or
// running anything. It's read as a page's Markdown is (Import.js): a picture
// becomes a link to it, HTML in it is left out (its words kept), links go
// only to the web or an email address, and every run's look is one Uber
// Notebook writes itself (Html.sanitize). Headings are bold and bigger, lists
// keep their bullets and numbers, to-dos their boxes; quotes are in italics,
// code in a fixed-width font, tables a line a row.
//
// Shared by app/AgentPanel.qml, app/ReleaseNotes.qml and
// tests/markdownview.test.cjs, so keep it plain JavaScript with no QML or
// Node APIs.
.pragma library
.import "Import.js" as Import
.import "Html.js" as Html

// The most of it that's shown (characters); past that, "…".
var MAX = 200000

function linkOnly(href) {
  return /^(https?:\/\/|mailto:)/i.test(String(href || "")) ? String(href) : ""
}

// Rich text for Markdown, `size` the text's size in px.
function rich(markdown, size) {
  var text = String(markdown || "").replace(/\r\n?/g, "\n")
  if (text.length > MAX) text = text.slice(0, MAX) + "\n\n…"
  var px = Math.max(8, Math.min(40, Number(size) || 13))
  var blocks = []
  try {
    blocks = Import.fromMarkdown(text, { image: function() { return "" }, link: linkOnly, wiki: function() { return "" } }).blocks || []
  } catch (e) {
    return "<p>" + Html.escapeText(text).replace(/\n/g, "<br />") + "</p>"
  }
  var out = []
  var counts = []
  blocks.forEach(function(b) {
    var depth = Math.max(0, Math.min(8, Math.floor(Number(b.indent) || 0)))
    var pad = depth ? " style=\"margin-left:" + depth * 18 + "px;\"" : ""
    var inner = typeof b.html === "string" ? Html.sanitize(b.html, true) : ""
    counts.length = depth + 1
    if (b.type !== "number") counts[depth] = 0
    if (b.type === "h1" || b.type === "h2" || b.type === "h3") {
      var scale = b.type === "h1" ? 1.4 : b.type === "h2" ? 1.2 : 1.05
      out.push("<p" + pad + "><span style=\"font-weight:700; font-size:" + Math.round(px * scale) + "px;\">" + inner + "</span></p>")
    } else if (b.type === "bullet") {
      out.push("<p" + pad + ">•&nbsp;" + inner + "</p>")
    } else if (b.type === "number") {
      counts[depth] = (counts[depth] || 0) + 1
      out.push("<p" + pad + ">" + counts[depth] + ".&nbsp;" + inner + "</p>")
    } else if (b.type === "check") {
      out.push("<p" + pad + ">" + (b.checked ? "☑" : "☐") + "&nbsp;" + inner + "</p>")
    } else if (b.type === "quote" || b.type === "callout") {
      out.push("<p" + pad + "><i>" + inner + "</i></p>")
    } else if (b.type === "code") {
      out.push("<pre>" + Html.escapeText(Html.plainText(b.html || "")) + "</pre>")
    } else if (b.type === "divider") {
      out.push("<p" + pad + ">———</p>")
    } else if (b.type === "table" && b.table && Array.isArray(b.table.rows)) {
      b.table.rows.slice(0, 500).forEach(function(row) {
        var cells = (Array.isArray(row) ? row : []).slice(0, 50).map(function(c) { return Html.sanitize(String(c || ""), true) })
        out.push("<p" + pad + ">" + cells.join(" │ ") + "</p>")
      })
    } else if (inner) {
      out.push("<p" + pad + ">" + inner + "</p>")
    }
  })
  return out.join("")
}
