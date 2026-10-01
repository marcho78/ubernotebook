// Checks code colored for its language in Pages.
// Usage (from the plugin directory): node tests/highlight.test.cjs

const assert = require("node:assert/strict");
const { load, plain } = require("./load.cjs");

const H = load("Highlight.js");
const Docs = load("Docs.js");
const Html = load("Html.js");
let passed = 0;
function check(name, fn) { fn(); passed++; }

const kinds = (text, lang) => plain(H.tokens(text, lang)).filter((t) => t.kind).map((t) => `${t.kind}:${t.text}`);

const SAMPLES = {
  JavaScript: "const x = 42; // hi\nfunction foo(a) { return \"s\" + `t${a}\n` }\nconsole.log(Foo.BAR, null, .5)",
  TypeScript: "interface A { n: number }\n@Component()\nexport type B = A | null",
  Python: "def f(x):\n    \"\"\"doc\n    more\"\"\"\n    return f\"{x}\" + r'a' # c\n@dec\nclass A(Base): pass",
  C: "#include <stdio.h>\nint main(void) { printf(\"%d\\n\", 0x1F); /* c */ return EXIT_SUCCESS; }",
  "C++": "template <typename T> class V { std::vector<T> v; };",
  "C#": "var s = @\"C:\\path\"\"x\"; // c\n#region r",
  Bash: "echo \"$HOME\" ${x} $1 # c\nif [ -f a#b ]; then ls; fi\nx='unterminated",
  Rust: "fn main<'a>(x: &'a str) { println!(\"hi\"); let c = '\\n'; #[derive(Debug)] }",
  Go: "func main() {\n\tfmt.Println(`raw\nstring`, len(x), nil)\n}",
  Java: "@Override public String toString() { return \"x\"; }",
  Kotlin: "val s = \"\"\"a\nb\"\"\"\nfun f() = null",
  Swift: "guard let x = y else { return nil }",
  PHP: "<?php $a = ['k' => 1]; # c\necho $a;",
  Ruby: "class A < B\n  attr_reader :name\n  def ok?; @x; end\nend",
  Lua: "local x = [[long\nstring]] -- c\n--[[ block ]]\nfunction f() return nil end",
  SQL: "SELECT id FROM users WHERE age > 18 -- adults\nAND status = 'ok';",
  JSON: "{\n  \"name\": \"x\", \"n\": -1.5e3, \"ok\": true\n}",
  CSS: "a:hover, .btn > #id { color: #fff; margin: 0 4px !important; }\n@media (max-width: 600px) { .a { display: none } }",
  HTML: "<!-- c --><div class=\"a\" hidden data-x=1>Hi &amp; bye</div>\n<script>let a = 1 < 2</script><style>p { color: red }</style>",
  YAML: "# c\nname: app # tail\nlist:\n  - one\n  - \"two\"\nscript: |\n  echo hi\nnext: ~",
  TOML: "[server]\nhost = \"x\" # tail\nmulti = \"\"\"\nline\n\"\"\"\n[[bins]]",
  Markdown: "# Title\n> quote\n- [ ] task with `code` and [link](http://x)\n```js\nlet a\n```",
  Makefile: "CC := gcc\nall: main.o\n\t$(CC) -o $@ $^ # link",
  Dockerfile: "FROM alpine:3.19 AS build\nRUN apk add git # tools\nENV PATH=$PATH:/x",
  Nix: "{ pkgs ? import <nixpkgs> {} }:\nlet x = ''\n  multi\n''; in x # c",
  QML: "Rectangle {\n  id: root\n  anchors.fill: parent\n  onClicked: foo()\n}",
  Zig: "const std = @import(\"std\");\npub fn main() void {}",
  Diff: "--- a/x\n+++ b/x\n@@ -1 +1 @@\n-old\n+new\n same",
};

check("every language on the menu is colored", () => {
  for (const lang of plain(Docs.LANGUAGES)) {
    if (lang === "Plain text") assert.equal(H.knows(lang), false);
    else assert.ok(H.knows(lang), lang);
  }
  assert.ok(H.knows("js") && H.knows("yml") && H.knows("golang"), "and the names they go by");
  assert.equal(H.knows("Haskell"), false);
});

check("the text is never changed", () => {
  const odd = ["", "\n", "\n\n x", "'", "\"", "/*", "<!--", "<a", "```", "\"\"\"", "${", "@", "#", "--[[", "x = '''", "\t\ta\r\nb", "<script>", "a: |", "[[", "''"];
  for (const lang of Object.keys(SAMPLES).concat(["Plain text", "Haskell"])) {
    for (const text of [SAMPLES[lang] || "x = 1"].concat(odd, Object.values(SAMPLES))) {
      const tokens = plain(H.tokens(text, lang));
      assert.equal(tokens.map((t) => t.text).join(""), text, `${lang}: ${JSON.stringify(text)}`);
      assert.ok(tokens.every((t) => t.text.length > 0));
      // (Stored code has no \r: Html.plainText, where it comes from, drops it.)
      const stored = text.replace(/\r/g, "");
      assert.equal(Html.plainText(H.html(stored, lang, false)), stored, `${lang} as HTML: ${JSON.stringify(text)}`);
    }
  }
});

check("what's colored", () => {
  const js = kinds(SAMPLES.JavaScript, "JavaScript");
  for (const k of ["keyword:const", "number:42", "comment:// hi", "func:foo", "string:\"s\"", "string:`t${a}\n`", "type:Foo", "literal:BAR", "literal:null", "number:.5"]) {
    assert.ok(js.includes(k), `JavaScript ${k} in ${js.join(" ")}`);
  }
  const py = kinds(SAMPLES.Python, "Python");
  for (const k of ["keyword:def", "string:\"\"\"doc\n    more\"\"\"", "string:f\"{x}\"", "string:r'a'", "comment:# c", "meta:@dec", "type:Base"]) {
    assert.ok(py.includes(k), `Python ${k} in ${py.join(" ")}`);
  }
  const sh = kinds(SAMPLES.Bash, "Bash");
  assert.ok(sh.includes("variable:${x}") && sh.includes("variable:$1") && sh.includes("comment:# c"));
  assert.ok(!sh.some((k) => k === "comment:#b ]; then ls; fi"), "a # in a word isn't a comment");
  assert.deepEqual(kinds("\"a\": 1, \"b\": \"c\"", "JSON"), ["property:\"a\"", "number:1", "property:\"b\"", "string:\"c\""], "a key isn't a value");
  const html = kinds(SAMPLES.HTML, "HTML");
  assert.ok(html.includes("attr:class") && html.includes("string:\"a\"") && html.includes("literal:&amp;"));
  assert.ok(html.includes("keyword:let") && html.includes("property:color"), "and what's in <script> and <style>");
  const yaml = kinds(SAMPLES.YAML, "YAML");
  assert.ok(yaml.includes("property:name") && yaml.includes("comment:# tail") && yaml.includes("string:  echo hi") && yaml.includes("literal:~"));
  const rust = kinds(SAMPLES.Rust, "Rust");
  assert.ok(rust.includes("type:'a") && rust.includes("string:'\\n'") && rust.includes("func:println!") && rust.includes("meta:#[derive(Debug)]"));
  assert.ok(kinds("SELECT 1 from t", "SQL").includes("keyword:from"), "SQL in any case");
  assert.deepEqual(kinds(SAMPLES.Diff, "Diff").slice(-2), ["deleted:-old", "inserted:+new"]);
  assert.deepEqual(kinds("x = 1", "Haskell"), [], "a language it doesn't know is plain");
});

check("as HTML", () => {
  const light = H.html("let a = \"<b>\"\n// x", "JavaScript", false);
  assert.equal(light, `<span style="color:${H.PALETTES.light.keyword};">let</span> a = <span style="color:${H.PALETTES.light.string};">"&lt;b&gt;"</span><br /><span style="color:${H.PALETTES.light.comment}; font-style:italic;">// x</span>`);
  const dark = H.html("let", "JavaScript", true);
  assert.ok(dark.includes(H.PALETTES.dark.keyword));
  assert.equal(H.html("a\n\nb", "Plain text", false), "a<br /><br />b");
  for (const p of [H.PALETTES.light, H.PALETTES.dark]) assert.deepEqual(Object.keys(p).sort(), Object.keys(H.PALETTES.light).sort());
});

console.log(`highlight: ${passed} checks passed`);
