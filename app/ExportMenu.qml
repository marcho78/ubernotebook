import QtQuick
import QtQuick.Controls

// Export… in a page's menu: the page as a PDF, a Word file or Markdown, and
// whether the pages inside it go too (when it has some).
Pop {
  id: menu

  property var view: null
  // (Kept while Pages is open: the last you chose.)
  property bool withPages: false

  focus: false
  width: 270
  padding: 8

  readonly property bool hasPages: { var r = view && view.workspace ? view.workspace.revision : 0; return !!(view && view.page && view.hasChildPages(view.page.id)) }
  readonly property var tools: view && view.exporter ? view.exporter.tools : null

  // (Looked for again while one's missing: installed since, it's offered.)
  onAboutToShow: if (view && view.exporter) view.exporter.probe(function() {}, "any")

  contentItem: Column {
    spacing: 4
    MenuRow {
      objectName: "exportPdf"
      width: parent.width; theme: menu.theme; icon: menu.theme.icons.pdf
      text: "PDF"
      hint: menu.tools && !menu.tools.browser ? "needs Chromium" : ""
      active: !menu.tools || !!menu.tools.browser
      onClicked: { menu.close(); menu.view.exportAs("pdf", menu.hasPages && menu.withPages) }
    }
    MenuRow {
      objectName: "exportWord"
      width: parent.width; theme: menu.theme; icon: menu.theme.icons.word
      text: "Word (.docx)"
      hint: menu.tools && !menu.tools.office ? "needs LibreOffice" : ""
      active: !menu.tools || !!menu.tools.office
      onClicked: { menu.close(); menu.view.exportAs("docx", menu.hasPages && menu.withPages) }
    }
    MenuRow {
      objectName: "exportMarkdown"
      width: parent.width; theme: menu.theme; icon: menu.theme.icons.markdown
      text: "Markdown"
      hint: "a folder, with its pages"
      onClicked: { menu.close(); menu.view.exportPage() }
    }
    Rectangle { visible: menu.hasPages; width: parent.width; height: 1; color: menu.theme.line }
    MenuRow {
      objectName: "exportWithPages"
      visible: menu.hasPages
      width: parent.width; theme: menu.theme; icon: menu.theme.icons.tree
      text: "With the pages inside it"
      checked: menu.withPages
      onClicked: menu.withPages = !menu.withPages
    }
  }
}
