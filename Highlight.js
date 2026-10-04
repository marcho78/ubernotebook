// Highlight.js - code in Pages, colored for its language. A code block's text
// is stored plain; this gives the HTML its editor shows, with comments,
// strings, numbers, keywords, and the names of types, functions, tags and
// keys in their colors. It reads just enough of each language for that, and
// never changes the text: what's shown is every character of what's stored,
// in the same places.
//
// Shared by the editor (app/Editor.qml) and tests/highlight.test.cjs, so keep
// it plain JavaScript with no QML or Node APIs.
.pragma library

// ---- colors ---------------------------------------------------------------------------

var PALETTES = {
  light: {
    comment: "#8a8c91", string: "#3d7a2f", number: "#b0561a", keyword: "#9a3cb0", literal: "#0b7a8a",
    type: "#9c6a00", func: "#2b62c2", tag: "#c03a33", attr: "#b0561a", meta: "#71747b", property: "#c03a33",
    variable: "#0b7a8a", heading: "#c03a33", inserted: "#3d7a2f", deleted: "#c03a33"
  },
  dark: {
    comment: "#7f848e", string: "#98c379", number: "#d19a66", keyword: "#c678dd", literal: "#56b6c2",
    type: "#e5c07b", func: "#61afef", tag: "#e06c75", attr: "#d19a66", meta: "#9aa1ad", property: "#e06c75",
    variable: "#56b6c2", heading: "#e06c75", inserted: "#98c379", deleted: "#e06c75"
  }
}

// ---- the languages ----------------------------------------------------------------------

function wordSet(text) {
  var o = {}
  String(text || "").split(/\s+/).forEach(function(w) { if (w) o[w] = true })
  return o
}

var JS_KEYWORDS = "var let const function return if else for while do switch case default break continue new delete typeof " +
  "instanceof in of try catch finally throw class extends import export from as async await yield static get set void with debugger"
var JS_LITERALS = "true false null undefined NaN Infinity this super"
var C_KEYWORDS = "if else for while do switch case default break continue return goto typedef struct union enum sizeof " +
  "static extern const volatile register inline auto signed unsigned restrict"
var C_TYPES = "void char short int long float double bool size_t ssize_t ptrdiff_t uint8_t uint16_t uint32_t uint64_t " +
  "int8_t int16_t int32_t int64_t uintptr_t intptr_t wchar_t FILE"

// How each language is read, by the names it goes by (lowercased):
//   line, block    its comments: ["//"], [["/*", "*/"]]
//   strings        its quote marks; multi: the ones whose strings go on over lines
//   triple         """ and ''' strings; longBrackets: Lua's [[...]]; indented: Nix's ''...''
//   verbatim       C#'s @"..."; chars: Rust's 'c' (and 'lifetimes')
//   keywords, literals (true, null...), types, builtins (colored as functions)
//   lineWords      keywords only at the start of a line (a Dockerfile's FROM, RUN...)
//   capitals       a Capitalized name is a type, an ALL_CAPS one a constant; allCaps: only the latter
//   ci             keywords in any case (SQL, Dockerfile)
//   preprocessor   # lines (C); attributes: Rust's #[...]; decorators: @name
//   vars           $name, ${...} (shell, PHP, Perl); makeVars: $(...) too; atVars: Ruby's @name
//   atBuiltins     Zig's @import; symbols: Ruby's :name; macros: Rust's name!
//   props          a name and ":" starting a line is a key (QML, JavaScript objects)
//   prefixes       Python's f"...", r"..."; hashAfterSpace: # starts a comment only after a space (shell)
//   calls          a name before "(" is a function (unless false); ident: what a name is made of
//   mode           markup, css, json, yaml, toml, markdown or diff, read their own way
var LANGS = {}

function def(names, d) {
  ["keywords", "literals", "types", "builtins", "lineWords"].forEach(function(k) { d[k] = wordSet(d[k]) })
  if (!d.line) d.line = []
  if (!d.block) d.block = []
  if (d.strings === undefined) d.strings = "\"'"
  if (!d.multi) d.multi = ""
  if (!d.ident) d.ident = /[A-Za-z0-9_]/
  names.split("|").forEach(function(n) { LANGS[n] = d })
  return d
}

var C_LIKE = { line: ["//"], block: [["/*", "*/"]] }
function withC(extra) {
  var d = { line: C_LIKE.line, block: C_LIKE.block }
  for (var k in extra) d[k] = extra[k]
  return d
}

def("javascript|js|jsx|mjs|cjs|node", withC({
  strings: "\"'`", multi: "`", ident: /[A-Za-z0-9_$]/, keywords: JS_KEYWORDS, literals: JS_LITERALS, capitals: true, props: true,
  builtins: "console require"
}))
def("typescript|ts|tsx", withC({
  strings: "\"'`", multi: "`", ident: /[A-Za-z0-9_$]/, capitals: true, props: true, decorators: true,
  keywords: JS_KEYWORDS + " type interface enum implements private public protected readonly declare namespace module abstract keyof infer is asserts satisfies override",
  literals: JS_LITERALS, types: "string number boolean any unknown never object symbol bigint", builtins: "console require"
}))
def("qml", withC({
  strings: "\"'`", multi: "`", ident: /[A-Za-z0-9_$]/, capitals: true, props: true,
  keywords: JS_KEYWORDS + " property signal readonly required alias component pragma default on",
  literals: JS_LITERALS + " parent", types: "int real double bool string var list url color date point rect size variant"
}))
def("python|py|python3", {
  line: ["#"], triple: true, prefixes: true, decorators: true, capitals: true,
  keywords: "and as assert async await break class continue def del elif else except finally for from global if import in is " +
    "lambda nonlocal not or pass raise return try while with yield match case",
  literals: "True False None self cls",
  types: "int float str bool list dict set tuple bytes bytearray object type complex frozenset range",
  builtins: "print len open input isinstance issubclass enumerate zip map filter sorted reversed sum min max abs any all " +
    "iter next super getattr setattr hasattr repr hash id format round divmod pow vars dir help"
})
def("bash|sh|shell|zsh|console|shellscript|fish|ksh", {
  line: ["#"], hashAfterSpace: true, strings: "\"'`", multi: "\"'`", vars: true, calls: false,
  keywords: "if then else elif fi case esac for select while until do done in function return break continue exit " +
    "local export readonly declare typeset set unset shift source alias eval exec trap time",
  literals: "true false",
  builtins: "echo printf read cd pwd test pushd popd mkdir rm cp mv ls cat grep sed awk find xargs sudo chmod chown ln " +
    "touch tee sort uniq head tail cut tr wc curl wget git"
})
def("c|h", withC({ preprocessor: true, allCaps: true, keywords: C_KEYWORDS, types: C_TYPES, literals: "NULL true false" }))
def("c++|cpp|cc|cxx|hpp|hh", withC({
  preprocessor: true, allCaps: true,
  keywords: C_KEYWORDS + " class namespace template typename public private protected virtual override final new delete " +
    "this operator using friend explicit mutable constexpr consteval constinit noexcept try catch throw static_cast " +
    "dynamic_cast reinterpret_cast const_cast decltype concept requires co_await co_return co_yield",
  types: C_TYPES + " std string vector map set unordered_map unique_ptr shared_ptr optional auto",
  literals: "NULL nullptr true false"
}))
def("c#|csharp|cs", withC({
  preprocessor: true, verbatim: true, capitals: true,
  keywords: "abstract as base break case catch checked class const continue default delegate do else enum event explicit " +
    "extern finally fixed for foreach goto if implicit in interface internal is lock namespace new operator out override " +
    "params private protected public readonly ref return sealed sizeof stackalloc static struct switch this throw try " +
    "typeof unchecked unsafe using virtual volatile while async await var get set init record yield when where",
  types: "bool byte char decimal double float int long object sbyte short string uint ulong ushort void dynamic",
  literals: "true false null"
}))
def("java", withC({
  decorators: true, capitals: true,
  keywords: "abstract assert break case catch class const continue default do else enum extends final finally for goto if " +
    "implements import instanceof interface native new package private protected public return static strictfp super " +
    "switch synchronized this throw throws transient try volatile while var record sealed permits yield",
  types: "boolean byte char double float int long short void", literals: "true false null"
}))
def("kotlin|kt|kts", withC({
  triple: true, decorators: true, capitals: true,
  keywords: "package import class interface fun val var if else when for while do return break continue object companion " +
    "data sealed enum open abstract override private protected public internal in out is as by init constructor " +
    "typealias suspend inline reified lateinit try catch finally throw this super",
  literals: "true false null"
}))
def("swift", withC({
  strings: "\"", triple: true, decorators: true, capitals: true,
  keywords: "import class struct enum protocol extension func var let if else guard switch case default for in while " +
    "repeat return break continue fallthrough where throw throws rethrows try catch do defer init deinit super static " +
    "private fileprivate public internal open mutating override final lazy weak unowned inout associatedtype " +
    "typealias subscript async await some any is as",
  literals: "true false nil self Self"
}))
def("go|golang", withC({
  strings: "\"'`", multi: "`",
  keywords: "break case chan const continue default defer else fallthrough for func go goto if import interface map " +
    "package range return select struct switch type var",
  types: "bool byte complex64 complex128 error float32 float64 int int8 int16 int32 int64 rune string uint uint8 uint16 " +
    "uint32 uint64 uintptr any",
  literals: "true false nil iota",
  builtins: "append cap clear close complex copy delete imag len make max min new panic print println real recover"
}))
def("rust|rs", withC({
  strings: "\"", multi: "\"", chars: true, attributes: true, macros: true, capitals: true,
  keywords: "as async await break const continue crate dyn else enum extern fn for if impl in let loop match mod move mut " +
    "pub ref return static struct super trait type unsafe use where while",
  types: "i8 i16 i32 i64 i128 isize u8 u16 u32 u64 u128 usize f32 f64 bool char str",
  literals: "true false self Self None Some Ok Err"
}))
def("php", withC({
  line: ["//", "#"], vars: true, capitals: true,
  keywords: "abstract and array as break callable case catch class clone const continue declare default do echo else " +
    "elseif empty enddeclare endfor endforeach endif endswitch endwhile extends final finally fn for foreach function " +
    "global goto if implements include include_once instanceof insteadof interface isset list match namespace new or " +
    "print private protected public readonly require require_once return static switch throw trait try unset use var " +
    "while xor yield",
  literals: "true false null TRUE FALSE NULL"
}))
def("ruby|rb", {
  line: ["#"], atVars: true, symbols: true, capitals: true,
  keywords: "alias and begin break case class def defined? do else elsif end ensure for if in module next not or redo " +
    "rescue retry return super then undef unless until when while yield",
  literals: "true false nil self",
  builtins: "puts print p require require_relative attr_accessor attr_reader attr_writer private protected public include extend raise lambda proc"
})
def("lua", {
  line: ["--"], block: [["--[[", "]]"]], longBrackets: true,
  keywords: "and break do else elseif end for function goto if in local not or repeat return then until while",
  literals: "true false nil self",
  builtins: "print pairs ipairs require type tostring tonumber setmetatable getmetatable pcall error assert select next"
})
def("sql|mysql|postgresql|postgres|psql|sqlite|plsql", withC({
  line: ["--"], strings: "'\"`", ci: true,
  keywords: "select from where and or not in is as join inner left right outer full cross on group by order having limit " +
    "offset insert into values update set delete create table view index drop alter add column primary key foreign " +
    "references unique default check constraint distinct union all exists between like ilike case when then else end " +
    "begin commit rollback transaction with recursive returning asc desc if replace trigger procedure function returns " +
    "declare cascade grant revoke language",
  types: "int integer bigint smallint serial bigserial decimal numeric real float double precision char varchar text " +
    "boolean bool date time timestamp timestamptz interval json jsonb uuid blob bytea",
  literals: "true false null"
}))
def("dockerfile|docker|containerfile", {
  line: ["#"], strings: "\"'", vars: true, ci: true, calls: false,
  lineWords: "from run cmd label maintainer expose env add copy entrypoint volume user workdir arg onbuild stopsignal healthcheck shell",
  keywords: "as"
})
def("makefile|make|mk|gnumakefile", {
  line: ["#"], strings: "\"'", vars: true, makeVars: true, makeLines: true, calls: false,
  keywords: "ifeq ifneq ifdef ifndef else endif include define endef export override unexport vpath"
})
def("nix", {
  line: ["#"], block: [["/*", "*/"]], strings: "\"", multi: "\"", indented: true, calls: false,
  keywords: "let in with rec inherit if then else assert or",
  literals: "true false null",
  builtins: "import builtins derivation fetchurl fetchTarball fetchGit mkDerivation callPackage"
})
def("zig", {
  line: ["//"], atBuiltins: true,
  keywords: "const var fn pub return if else while for break continue switch defer errdefer try catch orelse struct " +
    "enum union error test comptime inline export extern packed align usingnamespace async await suspend resume " +
    "unreachable and or",
  types: "i8 i16 i32 i64 i128 u8 u16 u32 u64 u128 isize usize f16 f32 f64 f128 bool void anyerror anytype type noreturn",
  literals: "true false null undefined"
})
def("json|jsonc|json5|geojson", { mode: "json" })
def("css|scss|sass|less", { mode: "css" })
def("html|xml|svg|xhtml|htm|vue", { mode: "markup" })
def("markdown|md|mdx", { mode: "markdown" })
def("yaml|yml", { mode: "yaml" })
def("toml|ini|conf|cfg|properties", { mode: "toml" })
def("diff|patch", { mode: "diff" })
// Equations and diagrams (drawn under what's written: Equations.js, Diagram.js).
def("math|latex|tex|katex", { mode: "tex" })
def("mermaid", { mode: "mermaid" })

function langOf(name) {
  var k = String(name || "").trim().toLowerCase()
  return Object.prototype.hasOwnProperty.call(LANGS, k) ? LANGS[k] : null
}

// Whether code in the language is colored.
function knows(name) { return langOf(name) !== null }

// ---- reading it -------------------------------------------------------------------------

// Tokens as they're found, the same kind next to each other joined.
function emitter() {
  var list = []
  return {
    list: list,
    add: function(text, kind) {
      if (!text) return
      var k = kind || ""
      var last = list[list.length - 1]
      if (last && last.kind === k) last.text += text
      else list.push({ text: text, kind: k })
    }
  }
}

// Where a string that starts at `from` (its quote) ends: after its closing
// quote, or at the end of its line unless it can go on (multi).
function stringEnd(src, from, quote, multi, escapes) {
  var n = src.length
  var j = from + 1
  while (j < n) {
    var c = src.charAt(j)
    if (escapes && c === "\\") { j += 2; continue }
    if (c === quote) return j + 1
    if (c === "\n" && !multi) return j
    j++
  }
  return n
}

var NUMBER = /^(?:0[xX][0-9a-fA-F_]+|0[bB][01_]+|0[oO][0-7_]+|(?:\d[\d_]*(?:\.\d[\d_]*)?|\.\d[\d_]*)(?:[eE][+-]?\d+)?)[A-Za-z0-9_]*/
var KEY = /^[A-Za-z_$][\w$.]*(?=[ \t]*:(?!:))/

// A programming language, by its definition.
function code(src, d) {
  var out = emitter()
  var n = src.length
  var i = 0
  var lineStart = true
  var ident = d.ident
  function at(s) { return src.substr(i, s.length) === s }
  function upTo(close, from) { var j = src.indexOf(close, from); return j < 0 ? n : j + close.length }
  function lineEnd(from) { var j = src.indexOf("\n", from); return j < 0 ? n : j }
  function take(end, kind) { out.add(src.slice(i, end), kind); i = end; lineStart = false }
  function prevChar() { return i > 0 ? src.charAt(i - 1) : "" }
  function nextSolid(from) { var j = from; while (j < n && (src.charAt(j) === " " || src.charAt(j) === "\t")) j++; return src.charAt(j) }

  while (i < n) {
    var ch = src.charAt(i)
    var m = null
    if (ch === "\n") { out.add("\n", ""); i++; lineStart = true; continue }
    if (ch === " " || ch === "\t" || ch === "\r") { out.add(ch, ""); i++; continue }
    // Whole lines: C's #include, a Makefile's targets and variables.
    if (lineStart && d.preprocessor && ch === "#") { take(lineEnd(i), "meta"); continue }
    if (lineStart && d.makeLines && (i === 0 || src.charAt(i - 1) === "\n")) {
      if ((m = /^[A-Za-z0-9_]+(?=[ \t]*[:?+!]?=)/.exec(src.substr(i, 120)))) { take(i + m[0].length, "property"); continue }
      if ((m = /^[^\s:#=$][^:#=\n]*(?=:(?!=))/.exec(src.substr(i, 200)))) { take(i + m[0].length, "func"); continue }
    }
    if (d.attributes && (at("#[") || at("#!["))) { take(Math.min(upTo("]", i), lineEnd(i)), "meta"); continue }
    // Comments.
    var done = false
    for (var b = 0; b < d.block.length && !done; b++) {
      if (at(d.block[b][0])) { take(upTo(d.block[b][1], i + d.block[b][0].length), "comment"); done = true }
    }
    for (var l = 0; l < d.line.length && !done; l++) {
      var mark = d.line[l]
      if (at(mark) && !(d.hashAfterSpace && mark === "#" && i > 0 && !/\s/.test(prevChar()))) { take(lineEnd(i), "comment"); done = true }
    }
    if (done) continue
    // Strings.
    if (d.triple && (at("\"\"\"") || at("'''"))) { take(upTo(src.substr(i, 3), i + 3), "string"); continue }
    if (d.longBrackets && at("[[")) { take(upTo("]]", i + 2), "string"); continue }
    if (d.indented && at("''")) { take(upTo("''", i + 2), "string"); continue }
    if (d.verbatim && at("@\"")) { take(stringEnd(src, i + 1, "\"", true, false), "string"); continue }
    if (d.chars && ch === "'") {
      if ((m = /^'(?:\\[^']{1,10}|[^\\'\n])'/.exec(src.substr(i, 14)))) { take(i + m[0].length, "string"); continue }
      if ((m = /^'[A-Za-z_]\w*/.exec(src.substr(i, 40)))) { take(i + m[0].length, "type"); continue }
    }
    if (d.strings.indexOf(ch) >= 0) { take(stringEnd(src, i, ch, d.multi.indexOf(ch) >= 0, true), "string"); continue }
    // Variables, decorators and the like.
    if (d.vars && ch === "$") {
      var v = i
      var next = src.charAt(i + 1)
      if (next === "{" || (d.makeVars && next === "(")) v = upTo(next === "{" ? "}" : ")", i + 2)
      else if ((m = /^\$(?:[A-Za-z_]\w*|\d|[@*#?$!-])/.exec(src.substr(i, 64)))) v = i + m[0].length
      if (v > i + 1) { take(Math.min(v, lineEnd(i)), "variable"); continue }
    }
    if (d.atVars && ch === "@" && (m = /^@@?[A-Za-z_]\w*/.exec(src.substr(i, 64)))) { take(i + m[0].length, "variable"); continue }
    if (d.decorators && ch === "@" && (m = /^@[A-Za-z_][\w.]*/.exec(src.substr(i, 80)))) { take(i + m[0].length, "meta"); continue }
    if (d.atBuiltins && ch === "@" && (m = /^@[A-Za-z_]\w*/.exec(src.substr(i, 64)))) { take(i + m[0].length, "func"); continue }
    if (d.symbols && ch === ":" && /[A-Za-z_]/.test(src.charAt(i + 1)) && !/[\w:]/.test(prevChar())) {
      m = /^:[A-Za-z_]\w*[?!]?/.exec(src.substr(i, 64))
      take(i + m[0].length, "literal")
      continue
    }
    // Numbers.
    if (/[0-9]/.test(ch) || (ch === "." && /[0-9]/.test(src.charAt(i + 1)) && !ident.test(prevChar()))) {
      m = NUMBER.exec(src.substr(i, 80))
      take(i + m[0].length, "number")
      continue
    }
    // Names: a key, a keyword, a type, a function...
    if (/[A-Za-z_]/.test(ch) || (ch === "$" && ident.test(ch))) {
      if (d.props && lineStart && (m = KEY.exec(src.substr(i, 80))) && !d.keywords[m[0]]) { take(i + m[0].length, "property"); continue }
      var j = i + 1
      while (j < n && ident.test(src.charAt(j))) j++
      if (d.symbols && (src.charAt(j) === "?" || src.charAt(j) === "!") && src.charAt(j + 1) !== "=") j++
      var word = src.slice(i, j)
      var key = d.ci ? word.toLowerCase() : word
      var after = src.charAt(j)
      var kind = ""
      if (d.prefixes && /^[rbfuRBFU]{1,2}$/.test(word) && (after === "\"" || after === "'")) kind = "string"
      else if (lineStart && d.lineWords[key]) kind = "keyword"
      else if (d.keywords[key]) kind = "keyword"
      else if (d.literals[key]) kind = "literal"
      else if (d.types[key]) kind = "type"
      else if (d.macros && after === "!" && src.charAt(j + 1) !== "=") { j++; kind = "func" }
      else if (d.builtins[key]) kind = "func"
      else if ((d.capitals || d.allCaps) && word.length > 1 && /^[A-Z][A-Z0-9_]*$/.test(word)) kind = "literal"
      else if (d.capitals && /^[A-Z]/.test(word)) kind = "type"
      else if (d.calls !== false && nextSolid(j) === "(") kind = "func"
      take(j, kind)
      continue
    }
    take(i + 1, "")
  }
  return out.list
}

// JSON: keys, strings, numbers, true, false and null (and comments, for JSONC).
function json(src) {
  var out = emitter()
  var n = src.length
  var i = 0
  var m
  while (i < n) {
    var ch = src.charAt(i)
    if (ch === "\"") {
      var e = stringEnd(src, i, "\"", false, true)
      var j = e
      while (j < n && (src.charAt(j) === " " || src.charAt(j) === "\t")) j++
      out.add(src.slice(i, e), src.charAt(j) === ":" ? "property" : "string")
      i = e
      continue
    }
    if (src.substr(i, 2) === "//") { var le = src.indexOf("\n", i); le = le < 0 ? n : le; out.add(src.slice(i, le), "comment"); i = le; continue }
    if (src.substr(i, 2) === "/*") { var ce = src.indexOf("*/", i + 2); ce = ce < 0 ? n : ce + 2; out.add(src.slice(i, ce), "comment"); i = ce; continue }
    if ((m = /^-?\d+(?:\.\d+)?(?:[eE][+-]?\d+)?/.exec(src.substr(i, 80))) && !/\w/.test(i > 0 ? src.charAt(i - 1) : "")) {
      out.add(m[0], "number"); i += m[0].length; continue
    }
    if ((m = /^(?:true|false|null)\b/.exec(src.substr(i, 8)))) { out.add(m[0], "literal"); i += m[0].length; continue }
    out.add(ch, "")
    i++
  }
  return out.list
}

// CSS (and SCSS, Less): selectors, at-rules, properties and their values.
function css(src) {
  var out = emitter()
  var n = src.length
  var i = 0
  var depth = 0
  var value = false
  function add(end, kind) { out.add(src.slice(i, end), kind); i = end }
  while (i < n) {
    var ch = src.charAt(i)
    var rest = src.substr(i, 160)
    var m = null
    if (rest.indexOf("/*") === 0) { var e = src.indexOf("*/", i + 2); add(e < 0 ? n : e + 2, "comment"); continue }
    if (!value && rest.indexOf("//") === 0) { var le = src.indexOf("\n", i); add(le < 0 ? n : le, "comment"); continue }
    if (ch === "\"" || ch === "'") { add(stringEnd(src, i, ch, false, true), "string"); continue }
    if (ch === "{") { depth++; value = false; add(i + 1, ""); continue }
    if (ch === "}") { depth = Math.max(0, depth - 1); value = false; add(i + 1, ""); continue }
    if (ch === ";") { value = false; add(i + 1, ""); continue }
    if ((m = /^@[\w-]+/.exec(rest))) { add(i + m[0].length, "keyword"); continue }
    if ((m = /^!important\b/i.exec(rest))) { add(i + m[0].length, "keyword"); continue }
    if ((m = /^\$[\w-]+/.exec(rest))) { add(i + m[0].length, "variable"); continue }
    if (depth > 0 && !value && (m = /^-{0,2}[A-Za-z_][\w-]*(?=[ \t]*:)/.exec(rest)) && !/^[ \t]*:[\w-]+[ \t]*[{,]/.test(src.substr(i + m[0].length, 80))) {
      add(i + m[0].length, "property")
      continue
    }
    if (ch === ":") {
      if (depth > 0 && !value) { value = true; add(i + 1, ""); continue }
      if ((m = /^::?[A-Za-z-]+/.exec(rest))) { add(i + m[0].length, "keyword"); continue }
      add(i + 1, "")
      continue
    }
    if (value) {
      if ((m = /^#[0-9a-fA-F]{3,8}\b/.exec(rest))) { add(i + m[0].length, "number"); continue }
      if ((m = /^-?(?:\d+\.?\d*|\.\d+)(?:%|[A-Za-z]+)?/.exec(rest))) { add(i + m[0].length, "number"); continue }
      if ((m = /^--[\w-]+/.exec(rest))) { add(i + m[0].length, "variable"); continue }
      if ((m = /^[A-Za-z_-][\w-]*(?=\()/.exec(rest))) { add(i + m[0].length, "func"); continue }
      if ((m = /^[A-Za-z_-][\w-]*/.exec(rest))) { add(i + m[0].length, "literal"); continue }
    } else {
      if ((m = /^\.[A-Za-z_-][\w-]*/.exec(rest))) { add(i + m[0].length, "type"); continue }
      if ((m = /^#[A-Za-z_-][\w-]*/.exec(rest))) { add(i + m[0].length, "func"); continue }
      if ((m = /^[A-Za-z][\w-]*/.exec(rest))) { add(i + m[0].length, "tag"); continue }
      if ((m = /^\[[^\]\n]*\]/.exec(rest))) { add(i + m[0].length, "attr"); continue }
      if ((m = /^-?(?:\d+\.?\d*|\.\d+)(?:%|[A-Za-z]+)?/.exec(rest))) { add(i + m[0].length, "number"); continue }
    }
    add(i + 1, "")
  }
  return out.list
}

// HTML and XML: tags, their attributes, comments, entities; what's in
// <script> and <style> as JavaScript and CSS.
function markup(src) {
  var out = emitter()
  var n = src.length
  var i = 0
  var lower = null
  var m = null
  function at(s) { return src.substr(i, s.length) === s }
  function upTo(close, from) { var j = src.indexOf(close, from); return j < 0 ? n : j + close.length }
  function add(end, kind) { out.add(src.slice(i, end), kind); i = end }
  while (i < n) {
    if (at("<!--")) { add(upTo("-->", i + 4), "comment"); continue }
    if (at("<![CDATA[")) { add(upTo("]]>", i + 9), "string"); continue }
    if (at("<!") || at("<?")) { add(upTo(">", i + 2), "meta"); continue }
    if ((m = /^<\/?[A-Za-z][\w:.-]*/.exec(src.substr(i, 100)))) {
      var closing = m[0].charAt(1) === "/"
      var name = m[0].replace(/^<\/?/, "").toLowerCase()
      add(i + m[0].length, "tag")
      var afterEquals = false
      while (i < n) {
        var ch = src.charAt(i)
        if (ch === ">") { add(i + 1, "tag"); break }
        if (at("/>")) { add(i + 2, "tag"); name = ""; break }
        if (ch === "<") { name = ""; break }
        if (/\s/.test(ch)) { add(i + 1, ""); continue }
        if (ch === "=") { add(i + 1, ""); afterEquals = true; continue }
        if (ch === "\"" || ch === "'") {
          var q = src.indexOf(ch, i + 1)
          add(q < 0 ? n : q + 1, "string")
          afterEquals = false
          continue
        }
        var a = /^[^\s=>\/"'<]+/.exec(src.substr(i, 200))
        if (a) { add(i + a[0].length, afterEquals ? "string" : "attr"); afterEquals = false; continue }
        add(i + 1, "")
      }
      if (!closing && (name === "script" || name === "style")) {
        if (lower === null) lower = src.toLowerCase()
        var end = lower.indexOf("</" + name, i)
        var stop = end < 0 ? n : end
        var inner = src.slice(i, stop)
        var sub = name === "script" ? code(inner, LANGS.javascript) : css(inner)
        sub.forEach(function(t) { out.add(t.text, t.kind) })
        i = stop
      }
      continue
    }
    if (src.charAt(i) === "&" && (m = /^&(?:#\d+|#x[0-9a-fA-F]+|[A-Za-z][A-Za-z0-9]*);/.exec(src.substr(i, 40)))) {
      add(i + m[0].length, "literal")
      continue
    }
    add(i + 1, "")
  }
  return out.list
}

// A YAML value after its key (or a list's dash): a string, a number, true...
function yamlValue(out, text) {
  var lead = /^[ \t]*/.exec(text)[0]
  out.add(lead, "")
  var rest = text.slice(lead.length)
  if (!rest) return
  var q = rest.charAt(0)
  var value = rest
  var tail = ""
  if (q === "\"" || q === "'") {
    var e = stringEnd(rest, 0, q, false, q === "\"")
    value = rest.slice(0, e)
    tail = rest.slice(e)
    out.add(value, "string")
  } else {
    var h = rest.search(/(^|[ \t])#/)
    if (h >= 0) { value = rest.slice(0, h); tail = rest.slice(h) }
    var trimmed = value.replace(/[ \t]+$/, "")
    var kind = /^(true|false|yes|no|on|off|null|~)$/i.test(trimmed) ? "literal"
      : /^[-+]?(\d[\d_]*(\.\d*)?([eE][-+]?\d+)?|\.inf|\.nan|0x[0-9a-fA-F]+|0o[0-7]+)$/i.test(trimmed) ? "number"
      : /^[&*!]/.test(trimmed) ? "meta"
      : /^[|>][-+0-9]*$/.test(trimmed) ? "keyword"
      : /^[\[{]/.test(trimmed) ? ""
      : "string"
    out.add(trimmed, kind)
    out.add(value.slice(trimmed.length), "")
  }
  var c = tail.search(/#/)
  if (c >= 0) { out.add(tail.slice(0, c), ""); out.add(tail.slice(c), "comment") }
  else out.add(tail, "")
}

function yamlDashes(out, text) {
  text.split(/(-)/).forEach(function(part) { out.add(part, part === "-" ? "keyword" : "") })
}

// YAML, line by line: keys, values, comments, and block text (after | or >).
function yaml(src) {
  var out = emitter()
  var block = -1
  src.split("\n").forEach(function(line, k) {
    if (k > 0) out.add("\n", "")
    var indent = /^[ \t]*/.exec(line)[0].length
    if (block >= 0) {
      if (line.trim() === "" || indent > block) { out.add(line, line.trim() ? "string" : ""); return }
      block = -1
    }
    if (/^[ \t]*#/.test(line)) { out.add(line, "comment"); return }
    if (/^(---|\.\.\.)([ \t]|$)/.test(line)) { out.add(line.slice(0, 3), "meta"); yamlValue(out, line.slice(3)); return }
    var m = /^([ \t]*(?:-[ \t]+)*)("[^"\n]*"|'[^'\n]*'|[^\s#'"{\[\-][^#\n]*?|-[^\s#][^#\n]*?)([ \t]*:)(?=[ \t]|$)/.exec(line)
    if (m) {
      yamlDashes(out, m[1])
      out.add(m[2], "property")
      out.add(m[3], "")
      var rest = line.slice(m[0].length)
      if (/^[ \t]*[|>][-+0-9]*[ \t]*(#.*)?$/.test(rest)) block = indent
      yamlValue(out, rest)
      return
    }
    var dash = /^[ \t]*(?:-(?:[ \t]+|$))*/.exec(line)[0]
    yamlDashes(out, dash)
    yamlValue(out, line.slice(dash.length))
  })
  return out.list
}

var TOML_VALUE = def("toml-value", { line: ["#"], triple: true, calls: false, literals: "true false inf nan" })

// TOML and INI, line by line: [tables], keys, and values.
function toml(src) {
  var out = emitter()
  var open = ""
  function value(text) {
    code(text, TOML_VALUE).forEach(function(t) { out.add(t.text, t.kind) })
    var count = (text.split("#")[0].match(/"""|'''/g) || []).length
    if (count % 2 === 1) open = /"""/.test(text) ? "\"\"\"" : "'''"
  }
  src.split("\n").forEach(function(line, k) {
    if (k > 0) out.add("\n", "")
    if (open) {
      var end = line.indexOf(open)
      if (end < 0) { out.add(line, "string"); return }
      out.add(line.slice(0, end + 3), "string")
      open = ""
      value(line.slice(end + 3))
      return
    }
    if (/^[ \t]*[#;]/.test(line)) { out.add(line, "comment"); return }
    var m = /^([ \t]*)(\[\[?[^\]\n]*\]\]?)(.*)$/.exec(line)
    if (m) { out.add(m[1], ""); out.add(m[2], "type"); value(m[3]); return }
    m = /^([ \t]*)([A-Za-z0-9_.\-"' ]*?[A-Za-z0-9_\-"'])([ \t]*[=:])(.*)$/.exec(line)
    if (m) { out.add(m[1], ""); out.add(m[2], "property"); out.add(m[3], ""); value(m[4]); return }
    value(line)
  })
  return out.list
}

// Markdown's inline parts: `code`, [links](...), <autolinks>.
function markdownInline(out, text) {
  var i = 0
  var n = text.length
  var m = null
  while (i < n) {
    var rest = text.substr(i, 400)
    if (rest.charAt(0) === "`" && (m = /^(`+)[^`][\s\S]*?\1(?!`)/.exec(rest))) { out.add(m[0], "string"); i += m[0].length; continue }
    if ((m = /^!?\[[^\]\n]*\]\([^)\n]*\)/.exec(rest))) {
      var cut = m[0].indexOf("](") + 1
      out.add(m[0].slice(0, cut), "func")
      out.add(m[0].slice(cut), "string")
      i += m[0].length
      continue
    }
    if ((m = /^<(?:https?:\/\/|mailto:)[^>\s]+>/.exec(rest))) { out.add(m[0], "string"); i += m[0].length; continue }
    out.add(text.charAt(i), "")
    i++
  }
}

// Markdown, line by line: headings, quotes, lists, fenced code, rules.
function markdown(src) {
  var out = emitter()
  var fence = ""
  src.split("\n").forEach(function(line, k) {
    if (k > 0) out.add("\n", "")
    var f = /^[ \t]*(`{3,}|~{3,})/.exec(line)
    if (fence) {
      if (f && f[1].charAt(0) === fence.charAt(0) && f[1].length >= fence.length && /^[ \t]*[`~]+[ \t]*$/.test(line)) fence = ""
      out.add(line, fence ? "string" : "meta")
      return
    }
    if (f) { fence = f[1]; out.add(line, "meta"); return }
    if (/^ {0,3}#{1,6}([ \t]|$)/.test(line)) { out.add(line, "heading"); return }
    if (/^ {0,3}>/.test(line)) { out.add(line, "comment"); return }
    if (/^ {0,3}([-*_])([ \t]*\1){2,}[ \t]*$/.test(line)) { out.add(line, "meta"); return }
    var m = /^([ \t]*)([-*+]|\d{1,9}[.)])([ \t]+)(\[[ xX]\][ \t])?/.exec(line)
    if (m) {
      out.add(m[1], "")
      out.add(m[2], "keyword")
      out.add(m[3], "")
      if (m[4]) out.add(m[4], "keyword")
      line = line.slice(m[0].length)
    }
    markdownInline(out, line)
  })
  return out.list
}

// A diff: lines added, taken out, and where.
function diff(src) {
  var out = emitter()
  src.split("\n").forEach(function(line, k) {
    if (k > 0) out.add("\n", "")
    var kind = /^(\+\+\+|---)([ \t]|$)/.test(line) ? "meta"
      : /^@@/.test(line) ? "func"
      : /^\+/.test(line) ? "inserted"
      : /^-/.test(line) ? "deleted"
      : /^(diff|index|similarity|rename|new file|deleted file)\b/.test(line) ? "keyword" : ""
    out.add(line, kind)
  })
  return out.list
}

// LaTeX: \commands, % comments, numbers, & and \\ (between a table's cells and rows).
function tex(src) {
  var out = emitter()
  var re = /(%[^\n]*)|(\\[A-Za-z]+\*?|\\.)|([0-9]+(?:\.[0-9]+)?)|(&)/g
  var last = 0
  var m
  while ((m = re.exec(src)) !== null) {
    if (m.index > last) out.add(src.slice(last, m.index), "")
    out.add(m[0], m[1] ? "comment" : m[2] ? (m[2] === "\\\\" ? "meta" : "keyword") : m[3] ? "number" : "meta")
    last = re.lastIndex
  }
  if (last < src.length) out.add(src.slice(last), "")
  return out.list
}

// Mermaid: its words (flowchart, subgraph, end...), its links (-->, -.->,
// ==>...) and their |text|, quoted words, %% comments.
var MERMAID_WORDS = wordSet("graph flowchart subgraph end direction classDef class style linkStyle click TD TB BT RL LR " +
  "sequenceDiagram classDiagram stateDiagram erDiagram gantt pie mindmap timeline journey gitGraph participant actor loop alt else opt")
function mermaid(src) {
  var out = emitter()
  var re = /(%%[^\n]*)|("[^"\n]*")|(\|[^|\n]*\|)|(<?(?:-->|---|-\.+->|-\.+-|==>|===|--o|--x|~~~)+[>ox]?)|([A-Za-z][A-Za-z-]*)/g
  var last = 0
  var m
  while ((m = re.exec(src)) !== null) {
    var kind = m[1] ? "comment" : m[2] || m[3] ? "string" : m[4] ? "meta" : MERMAID_WORDS[m[5]] ? "keyword" : ""
    if (!kind) continue
    if (m.index > last) out.add(src.slice(last, m.index), "")
    out.add(m[0], kind)
    last = re.lastIndex
  }
  if (last < src.length) out.add(src.slice(last), "")
  return out.list
}

// The text as [{ text, kind }]: every character in one of them, in order,
// and kind "" for plain text. A language it doesn't know is all plain.
function tokens(text, name) {
  var src = String(text || "")
  if (!src) return []
  var d = langOf(name)
  if (!d || d === TOML_VALUE) return [{ text: src, kind: "" }]
  if (d.mode === "json") return json(src)
  if (d.mode === "css") return css(src)
  if (d.mode === "markup") return markup(src)
  if (d.mode === "yaml") return yaml(src)
  if (d.mode === "toml") return toml(src)
  if (d.mode === "markdown") return markdown(src)
  if (d.mode === "diff") return diff(src)
  if (d.mode === "tex") return tex(src)
  if (d.mode === "mermaid") return mermaid(src)
  return code(src, d)
}

// ---- showing it -------------------------------------------------------------------------

function escapeText(text) {
  return text.replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;")
}

// Plain text (\n between lines) as a block's inside in its colors, for the
// dark paper or the light one.
function html(text, name, dark) {
  var colors = dark ? PALETTES.dark : PALETTES.light
  var out = ""
  tokens(text, name).forEach(function(t) {
    var color = t.kind ? colors[t.kind] : ""
    var extra = t.kind === "comment" ? " font-style:italic;" : t.kind === "heading" ? " font-weight:700;" : ""
    t.text.split("\n").forEach(function(part, k) {
      if (k > 0) out += "<br />"
      if (!part) return
      var e = escapeText(part)
      out += color ? "<span style=\"color:" + color + ";" + extra + "\">" + e + "</span>" : e
    })
  })
  return out
}
