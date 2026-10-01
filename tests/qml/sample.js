// Sample pages for tests and the dev harness.
.pragma library

var trip = {
  title: "Lisbon, in October",
  blocks: [
    { type: "h2", html: "Before we go" },
    { type: "check", html: "Book the <span style=\" font-weight:700;\">flat in Alfama</span>", checked: true },
    { type: "check", html: "Renew passport", checked: true },
    { type: "check", html: "Ask Ana about the <span style=\" background-color:#fff27a;\">tram 28</span> times" },
    { type: "p", html: "" },
    { type: "h2", html: "Places" },
    { type: "bullet", html: "Miradouro da Senhora do Monte, <span style=\" font-style:italic;\">at sunset</span>" },
    { type: "bullet", html: "LX Factory" },
    { type: "bullet", html: "Sunday market", indent: 1 },
    { type: "number", html: "Pastéis de Belém first" },
    { type: "number", html: "then the <a href=\"https://www.mnaa.gov.pt\">Ancient Art museum</a>" },
    { type: "quote", html: "Saudade: a longing for something you love and have lost." },
    { type: "callout", html: "Trains from the airport stop at <span style=\" font-weight:700;\">Oriente</span>; take the red line.", tone: "yellow" },
    { type: "code", html: "ssh pi@home.lan<br />sudo apt update" },
    { type: "divider", style: "line" },
    { type: "p", html: "Budget: <span style=\" color:#1e4fa3;\">€ 1,200</span> for the week, <span style=\" text-decoration: line-through;\">€ 1,500</span>." }
  ]
}
