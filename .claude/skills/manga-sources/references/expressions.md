# Expressions: how a value is read

Every field that reads something from an answer (`rows`, `card.id`, `chapter.date`, `pages.images`, a var, ...) is an **expression**. The code is `desktop/manga/src/eval.rs` and `def.rs`.

## Contents

1. [The idea: a list of nodes](#the-idea-a-list-of-nodes)
2. [Short forms](#short-forms)
3. [The steps](#the-steps)
4. [Dates and numbers](#dates-and-numbers)
5. [Templates](#templates)
6. [Decrypting](#decrypting)
7. [The traps](#the-traps)

## The idea: a list of nodes

An expression is read against a **node**, and gives a **list of nodes**.

- A node is an HTML element, a JSON value, or a text.
- The expression starts with one node: the whole answer for `rows` (and `next`, `total`, vars), or **one row** for the fields of a card or chapter.
- A **pipe** is a list of steps. Each step turns the list before it into a new list.
- At the end, a field wants **text**. If the expression gives several nodes, the **first non-empty text** is taken (`title`, `cover`, `id`). A few fields take **all of them** as a list (`authors`, `tags`, `pages.images`). `rows` takes all the nodes as rows.
- Text is **trimmed**, and an empty text counts as nothing.

An element's text puts each block (a paragraph, `<br>`, a list item, a heading) on its own line and squashes runs of spaces. `<p>One.</p><p>Two.</p>` reads as two lines, not `One.Two.`.

## Short forms

A short form is a plain text. What it means depends on the section's `format` and on whether it is a `rows` expression or a field.

### HTML sections (`"format": "html"`, the default)

| You write | In | Means |
| --- | --- | --- |
| `"div.card"` | `rows` | the elements matching this CSS selector |
| `"h3"` | a field | the text of the match |
| `"img@data-src\|src"` | a field | an attribute of the match, the first one in the list that is not empty |
| `"@href"` | a field | an attribute of **the row itself** (the row is the link) |

A field's short form is split at the **last** `@`. So `"a.name@href"` is selector `a.name`, attribute `href`.

### JSON sections (`"format": "json"`)

| You write | Means |
| --- | --- |
| `"data"` | the value at `data` (a list is read element by element) |
| `"series.title"` | a dotted path |
| `"series.genres.*.name"` | `*` is every value of an object or list, then `name` in each |
| `"chapters.0.title"` | a number is an index |

A path read through a **list** reads the key in each element: `"data.slug"` on `{"data":[{"slug":"a"},{"slug":"b"}]}` gives `a` and `b`. A list found at the end is read element by element.

Booleans and numbers become text (`true`, `179`). Null, an object, and an empty text give nothing.

### Anything else is a pipe

A pipe is a JSON list of steps. A step is either an object (`{"css": "a"}`) or, for steps with no argument, a bare text (`"text"`).

```json
[{ "css": ".cover img" }, { "attr": "data-src|src" }, "abs"]
```

**A single step still needs its list.** `{ "path": "token" }` on its own is not an expression. Write `[{ "path": "token" }]`.

## The steps

| Step | Written | Does |
| --- | --- | --- |
| css | `{"css": "a.title"}` | The elements matching the selector, **below** each node. Also works on a text that holds HTML (an ajax answer, a JSON field that holds markup): it is parsed first. |
| attr | `{"attr": "data-src\|src"}` | An attribute of each element. With `\|`, the first that is not empty. Elements without it are dropped. |
| text | `"text"` | The text of each node (blocks on their own lines). |
| html | `"html"` | An element's inner HTML. See the trap below before you use it on a `<script>`. |
| path | `{"path": "a.*.b"}` | Into JSON, with the path syntax above. Non-JSON nodes are dropped. |
| json | `"json"` | A text parsed as JSON (a `<script>` blob). A text that is not JSON is dropped. |
| regex | `{"regex": "/manga/([^/]+)/?$"}` | The **first capture group** (or the whole match with no group). A node that does not match is **dropped**. |
| replace | `{"replace": {"from": "^/", "to": ""}}` | Replaces **every** match of a regex. `to` may use `$1`. |
| trim | `"trim"` | Trims each text. |
| lower | `"lower"` | Lower-cases each text. |
| template | `{"template": "{base}/x/{value}"}` | Builds a text. See [Templates](#templates). A node whose template has an unfilled hole is dropped. |
| abs | `"abs"` | Makes a link absolute against the host. |
| date | `{"date": ["MMMM d, yyyy", "iso", "relative"]}` | Milliseconds since 1970. See [Dates](#dates-and-numbers). |
| number | `"number"` | The chapter number in a text (`"Ch. 12.5 - Name"` gives `12.5`). |
| first | `"first"` | Only the first node. |
| last | `"last"` | Only the last node. |
| nth | `{"nth": 2}` | Only the node at this index (from `0`). |
| join | `{"join": ", "}` | All the non-empty texts as one. |
| split | `{"split": ","}` | Splits each text and keeps the non-empty trimmed pieces. |
| const | `{"const": "x"}` | A fixed text, whatever came before. |
| default | `{"default": "unknown"}` | This text **when there is nothing** (or only empty texts). |
| non_empty | `"non_empty"` | Drops empty texts. |
| exists | `"exists"` | The text `true` when there is anything, nothing otherwise. A test, for `next`. |
| map | `{"map": [["ongoing", "ongoing"], ["on hold", "hiatus"]]}` | For each text: the value of the **first key it contains** (compared lower case). A text that contains no key is dropped. |
| coalesce | `{"coalesce": [ex, ex]}` | The first expression that gives something. Each is a short form or a pipe, run from the same starting nodes. |
| where | `{"where": {"path": "type", "equals": "Series"}}` | Keeps the JSON nodes whose value at `path` passes. See below. |
| unique | `"unique"` | Drops texts already seen. |
| sort | `"sort"` | Orders texts the way file names read: runs of digits by value (`p2` before `p10`). |
| plain_text | `"plain_text"` | HTML inside a text, as plain text: tags gone, blocks on their own lines. |
| aes_cbc | `{"aes_cbc": {"passphrase": "{nonce}"}}` | Decrypts. See [Decrypting](#decrypting). |

### where

Keeps the JSON nodes whose value at `path` passes **all** the tests given:

| Test | Passes when |
| --- | --- |
| `"equals": "Series"` | the value is exactly this |
| `"not_equals": "Hidden"` | the value is not this |
| `"in": ["a", "b"]` | the value is one of these |
| `"absent": true` | nothing is there (or it is null). `false` keeps nodes with something there. |

A wanted value may hold a hole: `"equals": "{id}"` picks the row for the id being asked about.

```json
[{ "path": "tags" }, { "where": { "path": "type", "equals": "Series" } }, { "path": "permalink" }]
```

(From `dynastyscans`: of the tags a chapter has, keep the one whose type is Series, and read its permalink.)

### css selectors

The selector language is CSS as the `scraper` crate reads it: tags, classes, ids, attribute selectors (`a[rel="next"]`, `[data-id]`), descendant and child (`>`), `:nth-of-type(2)`, `:first-child`, `:not(...)`, and comma lists (`h3 a, h5 a, .post-title a`). A bad selector is refused when the definition loads.

## Dates and numbers

`{"date": [...]}` tries each format **in order** and gives milliseconds since 1970 (as text, which is what `chapter.date` wants). A text no format can read gives nothing, and the chapter has no date.

| Format | Reads |
| --- | --- |
| `"iso"` | `2024-02-29T10:00:00+00:00`, or anything with `yyyy-mm-dd` in it |
| `"relative"` | `3 days ago`, `an hour ago`, `yesterday`, `today`, `just now`, `2 weeks ago`. Units: second, minute, hour, day, week, month (30 days), year. Relative to **now**. |
| a pattern | letters stand for parts, anything else is literal |

Pattern letters: `yyyy` (4-digit year), `yy` (2-digit year), `MMMM` (month name), `MMM` (month name, 3 or more letters), `MM` / `M` (month number), `dd` / `d` (day, and it accepts `1st`, `2nd`, `3rd`, `4th`). **A pattern needs a year**, or it is refused: it could never read a date.

Examples: `"MMMM d, yyyy"` reads `March 5th, 2024`; `"MMM dd, yyyy"` reads `Jan 07, 2023`; `"dd/MM/yy"` reads `07/01/23`.

Put the formats a site uses in one list, most specific first, and `relative` last: `["MMMM d, yyyy", "MMM d, yyyy", "relative"]`. A site that says "2 days ago" for recent chapters and a date for old ones needs both.

Month names are English only. A site in another language needs a `replace`/`map` step first, or no date.

**Chapter numbers.** `chapter.number` may be a plain number, or a text the engine reads: a number after `chapter`, `ch.`, `ch`, `episode`, `ep.`, `ep` or `#` wins, otherwise the first number. With no `number` expression at all, the title is read the same way. `"Solo Leveling 2 Ch. 40"` gives `40`, not `2`.

## Templates

`{"template": "..."}` builds a text from the node and the request:

| Hole | Is |
| --- | --- |
| `{value}` | the node being read (its text) |
| `{^.path}` | a value in the **row the expression started from**, JSON rows only (`{^.id}` is the row's `id`) |
| `{base}` | the host |
| `{id}`, `{series}`, `{page}`, `{term}`, a var, a setting, a filter | the request's holes |
| `{value:raw}` | not needed: a template's output is not percent-encoded |

`{? ... ?}` groups work inside a template too.

```json
[{ "path": "image" }, { "template": "https://cdn.example.com/series/{^.id}/{value}" }]
```

Reads a card's `image` and builds a cover address that also uses the card's `id`. Use `{^.path}` when a value you need is in the row but not in the node you are reading now.

## Decrypting

Some sites send the chapter's pages as a blob their own script decrypts. `aes_cbc` undoes it. Only AES-CBC is supported. It is the only step that touches cryptography: no definition can ask for an encryption, a signature or a hash of its own.

| Field | Meaning |
| --- | --- |
| `passphrase` | A passphrase, stretched with a salt the payload carries. May hold a hole (`"{nonce}"`). |
| `salt` | Only when a site uses one fixed salt, as hex. Without it, the salt comes from the payload (`s`). |
| `key` and `iv` | A key already known, as hex: 32 bytes for AES-256 (64 hex digits) or 16 for AES-128, and a 16-byte `iv` (32 hex digits). Use **instead of** `passphrase`, never together. Both are needed. |
| `hex` | `true` when the ciphertext itself is hex. The default reads base64. |

The input is the payload: an object with `ct` (the ciphertext) and usually `s` (salt, hex) and `iv`, or the JSON text of one. A bare text is taken as the ciphertext. The key derivation is `MD5(previous ++ passphrase ++ salt)` repeated to 48 bytes (32 for the key, 16 for the IV), which is what the Madara "chapter protector" script does. A payload that carries its own `iv` uses that.

```json
"images": [
  { "css": "script#chapter-protector-data" }, "html",
  { "replace": { "from": "\\\\/", "to": "/" } },
  { "regex": "(?s)var\\s+chapter_data\\s*=\\s*'(\\{.*?\\})';" },
  { "aes_cbc": { "passphrase": "{nonce}" } },
  "json", { "path": "*" }
],
"vars": { "nonce": [ { "css": "script#chapter-protector-data" }, "html",
                     { "replace": { "from": "\\\\", "to": "" } },
                     { "regex": "var\\s+wpmangaprotectornonce\\s*=\\s*'([^']*)';" } ] }
```

`templates/source-encrypted-pages.json` is this, and `examples/madara-protected.json` runs it against a recorded payload. A fixed key looks like `{"aes_cbc": {"key": "<64 hex>", "iv": "<32 hex>"}}`.

A definition that can never decrypt is refused when it loads: it needs a passphrase, or a key and an iv; not both a passphrase and a key. A payload that looks like one but has no `ct` is an error that says the site may have changed.

## The traps

Each one was found against a live site.

**1. `"html"` on a `<script>` escapes `& < >`.** The step gives the element's inner HTML as the serializer writes it, and that **escapes** `&`, `<` and `>` in a script's text. A JSON string that held `<p>Hi</p>` comes out as `&lt;p&gt;Hi&lt;/p&gt;`, so `plain_text` after it shows the tags as text, and `Tom & Jerry` comes out as `Tom &amp;amp; Jerry`. **For a script blob, use `"text"`**: `[{"css": "script#__NEXT_DATA__"}, "text", "json", ...]`. (`text` squashes runs of spaces inside a line, which JSON does not care about. `flamecomics` still uses `html` and is fine only because its values have none of those three characters.)

**2. `noscript` content is invisible.** The HTML parser skips what is inside `<noscript>`. A reader that wraps each page image in a `<noscript>` fallback (MangaStream's `#readerarea`) gives `#readerarea img` nothing. Read the script blob instead (`ts_reader.run({...})`), which is the canonical image list.

**3. After `json`, a short form reads as CSS.** Once a pipe has gone through `"json"`, the nodes are JSON, but the **section's format is still `html`**, so a short-form field (`"token"`) is read as a CSS selector and silently gives nothing. Write the path explicitly: `[{ "path": "token" }]`.

**4. A JSON object iterated with `*` comes out in key order.** Keys are text, so `"0".."22"` read `0, 1, 10, 11, ..., 19, 2, 20`. Add `"sort"` before the step that builds the address, or the pages come out of order. `sort` orders as a person reads file names, so it fixes `p2` before `p10` as well. (It sorts by the **text** of the nodes at that point, so put it where the text is the file name.)

**5. A bare `{term}` breaks genre browsing.** Always `{?&q={term}?}`. See `format.md`.

**6. `regex` drops a node that does not match.** That is useful (it filters), and it is also how a card silently disappears when a site changes its link shape. If a list is suddenly short, check the regex first.

**7. `default` runs on what is in front of it.** `[{"css": ".status"}, "text", {"default": "unknown"}]` gives `unknown` when `.status` is missing or empty. But a `map` **before** the `default` that matches nothing also gives nothing, so the `default` fires. Put `map` first and `default` last, as the templates do.

**8. `first` of a list of links.** A row with two links (a title and a "latest chapter") reads the first `a` for the id. If the first link is not the series, select the right one: `.post-title a`, not `a`.

**9. Relative links.** A `cover` or an image that is a path (`/img/a.jpg`) is made absolute against the host automatically. You only need `abs` when a *different* field is a link (a field you template yourself), or to be explicit. A `data:` address is dropped, which is how a lazy-loading placeholder disappears; read `data-src|data-lazy-src|src`, in that order.

**10. `{base}` in a template is the host that answered.** For a source with mirrors, an address you build from `{base}` follows the mirror that worked.

**11. Spaces and entities.** The text of an element is squashed. An attribute is trimmed. Neither is HTML-decoded again: what the parser decoded once is what you get.

**12. Keys that contain a dot.** A path splits on `.`, so a JSON key like `"a.b"` cannot be reached with `path`. Read the parent as JSON and use a different route, or tell the user the source needs a code change.
