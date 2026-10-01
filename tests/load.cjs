// Loads one of the plugin's plain-JS files (Html.js, Blocks.js, ...) the way
// QML does: as a script whose top-level functions become the module. A
// `.import "Other.js" as Other` line loads that file too, as QML would.
const fs = require("node:fs");
const path = require("node:path");
const vm = require("node:vm");

const root = path.join(__dirname, "..");
const cache = new Map();

function load(file) {
  if (cache.has(file)) return cache.get(file);
  const context = {};
  vm.createContext(context);
  let source = fs.readFileSync(path.join(root, file), "utf8");
  source = source.replace(/^\.pragma library\s*$/m, "");
  source = source.replace(/^\.import\s+"([^"]+)"\s+as\s+(\w+)\s*$/gm, (_, dep, name) => {
    context[name] = load(path.join(path.dirname(file), dep));
    return "";
  });
  vm.runInContext(source, context, { filename: file });
  cache.set(file, context);
  return context;
}

// Copies a value out of a vm context so deepEqual sees ordinary objects.
function plain(value) {
  return JSON.parse(JSON.stringify(value));
}

module.exports = { load, plain, root };
