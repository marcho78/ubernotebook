---
title: Writing in Uber Notebook
icon: ✍️
parent: welcome
order: 1
---
Everything on a page is a **block**: a line of text, a heading, a to-do, a picture, even another page. Blocks can hold other blocks, and move with everything inside them.

::toc

## Try these

- [ ] Hover over a block and drag **⋮⋮** beside it to move it. Drag it to the right to put it inside the block above
- [ ] Click **⋮⋮** for a block's menu: turn it into another kind, color it, duplicate it, move it to another page
- [ ] Select a few words: a toolbar comes up to make them bold, a link or a color
- [ ] Type `**bold**`, `*italic*`, `` `code` `` or `~~struck~~` as you write
- [ ] Start a line with `# `, `- `, `1. ` or `[] ` for a heading, a list or a to-do
- [ ] Type **:** and a name for an emoji: `:rocket` gives 🚀
- [ ] **Tab** puts a block inside the one above it, **Shift+Tab** takes it out

## Text

Text can be **bold**, *italic*, ~~struck through~~, `code`, ==highlighted== or a [link to a website](https://omarchy.org). A link to another page looks like this: [[Staying organized]]. A date looks like this: {{date:+1}}.

> Quotes stand apart from the text around them.

### Lists

1. Numbered lists count themselves
   1. and nest, with letters
      1. and then numerals
2. Drag an item to reorder it

- Bulleted lists
  - nest as deep as you like
- [x] To-dos tick off
- [ ] with a click, or **Ctrl+Enter**

## Callouts

> [!NOTE] A callout holds what matters. Click its emoji for another one.

> [!TIP] Blocks inside a callout take its color.

> [!WARNING] Notes, tips and warnings each come in their own color.

## Toggles

<details>
<summary>Click the arrow to open this toggle</summary>

Toggles fold away what's inside them, to keep a page short. **Ctrl+Enter** opens and closes the one you're in.

</details>

<details>
<summary>Toggles can hold anything</summary>

- [ ] Even to-dos
- [ ] and lists

</details>

## Code

```python
def greet(name):
    return f"Hello, {name}!"

print(greet("Omarchy"))
```

Code is colored for its language (30 of them, from Bash to Zig), and Copy copies it.

## Side by side

::columns
**Columns** sit side by side. Drag a block up the right side of another to make them, or type `/2 columns`.
::next
Drag the gap between two columns to share the width differently.
::end

---

Next: [[Staying organized]].
