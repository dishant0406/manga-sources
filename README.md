# Akidev manga sources

This repo is a **repository of source plugins** for the Akidev manga app. The app has no source of its own: it is a renderer. It reads whatever a definition says, and a definition says which requests to make to a site and how to read the answers.

Nothing in a definition is code. It is one JSON file. The engine that reads it is `desktop/manga` in the code repo (`dishant0406/akidev`, mainly `src/source.rs`, `src/eval.rs` and `src/def.rs`). The reasoning is in that repo's `pipeline/MANGA_PLAN.md`.

The short version of this file:

- **Want to add a site?** Skip to [Let an agent write a source for you](#let-an-agent-write-a-source-for-you). Give it the site and it does the whole job.
- **Want to write one yourself?** Read [How a source works](#how-a-source-works) and [Writing a source by hand](#writing-a-source-by-hand).
- **Want to know what is supported, to the last field?** Read [Everything a definition can say](#everything-a-definition-can-say), then the full reference in `.claude/skills/manga-sources/references/`.
- **Want to know what is NOT supported?** [What is not supported](#what-is-not-supported).

## What is in this repo

```text
repo.json              {"name": "..."}: the repository's name
index.json             the index (generated: see Publishing), what an app reads first
index.json.sig         optional, a signature over index.json (not used today)
themes/<id>.json       a base definition for sites that run the same CMS ("theme": true, with a "version")
sources/<id>.json      a source (the file is named after its id)
examples/<id>.json     sources used only to test the engine: not in the index
fixtures/<id>/         recorded pages and fixtures.json for a source or an example
.claude/skills/manga-sources/   the skill that writes sources, with the full reference and templates
.github/workflows/check.yml     CI: every definition against its fixtures, and a fresh index
```

### The sources

Five sources, each with fixtures recorded from the live site, and one theme:

| Source | Site | How it reads the site |
| --- | --- | --- |
| `arenascans` | arenascan.com | a WordPress `mangareader` (MangaStream-family) site: `.bsx` cards, `?order=popular`/`update`, search filters by `genre`; pages come from the `ts_reader.run({...})` script blob's `sources.0.images` |
| `demonicscans` | demonicscans.org | a plain PHP site with three different endpoints: popular is its `advanced.php` catalogue sorted `orderby=VIEWS DESC`, latest is `lastupdates.php`, and search is the AJAX suggest `search.php?manga=`, capped at ~20 with no pagination and no filters (the site has no text-filterable list search — `advanced.php` filters by `genre[]`/`status` but ignores the term). Series slugs are double-encoded (`%2527` in the href is the literal slug); the detail path decodes them twice, so `{id}` re-encoding is harmless. Chapter ids are the numbers in the `chaptered.php?...&chapter=` hrefs; the reader is `/title/{series}/chapter/{id}/1`, which puts every page on one answer behind `img.imgholder` — a relative `/img/free_ads.jpg` ad rides in the same class and is dropped by a regex that keeps only absolute URLs. Both `demoniclibs.com` and `cdn2.demoniclibs.com` serve pages |
| `asurascans` | api.asurascans.com | its own JSON API: `data`, `meta.has_more`, `series`, `data.chapter.pages.*.url` |
| `dynastyscans` | dynasty-scans.com | its own JSON API, for series and for one-shots; an id is `series/<p>` or `doujins/<p>` |
| `flamecomics` | flamecomics.xyz | a Next.js site: reads `script#__NEXT_DATA__` as JSON for detail, chapters and pages; search is its `/api/series` |

No shipped source extends `madara` any more. The theme stays: `examples/madara-example.json` and `examples/madara-protected.json` are what keep it honest, and the family is still the cheapest place to add sources from. Earlier ports of `manhuaplus`, `3asq` and `tcbscans` live in the code repo's history (`git show 75a1a53`, run in `dishant0406/akidev`), and the findings they produced (the mirror trap, the per-site `pages` override, the chapter list that must ride in the detail page) are why those sites are cheap whenever they are wanted again.

### What belongs here

A source is worth shipping when the site is **reachable, gives its chapters in the answer, and gives its pages in the answer**. Most sites in the ecosystem fail at least one of the three. The probe behind that, and why each family fails, is in the code repo's `pipeline/MANGA_SOURCES_PORT_PLAN.md` §3b, and in `.claude/skills/manga-sources/references/from-a-website.md`.

And only sources that are **legal to read** belong here: a public API that welcomes third-party readers, or work released under an open licence. Nothing that republishes copyrighted chapters without the publisher's leave.

## Adding this repository to the app

Sources tab, **Add a repository**, paste the address: `github.com/<owner>/<repo>`, or `github.com/<owner>/<repo>/tree/<branch>/<folder>` when the repository is in a folder. The app reads `raw.githubusercontent.com/<owner>/<repo>/<branch>/index.json`. Any other https folder with an `index.json` works too. Plain http is accepted only for this machine, for development.

Adding installs nothing. The repository page lists its sources, each with **Install** or **Update**. The app checks for newer versions at start.

### Adding one source without a repository

Sources tab, **Add a source**, paste the definition. It is checked before it is kept, and the app shows its name, languages and version first. A definition that extends a theme has the theme merged into it at that moment and is stored that way, so it keeps working on its own: the theme it borrowed does not have to stay installed. A source from a repository still follows its theme's updates.

A definition pasted this way does not update itself. Raise its `version` and paste it again, or put it in a repository.

## Let an agent write a source for you

This repo carries a Claude skill, `manga-sources`, in `.claude/skills/manga-sources/`. Open this repo in Claude Code, Cursor, or anything that reads skills, and say what you want:

> Add a source for https://example.com

It follows the same steps this README describes, and does them for you:

1. Checks the site may be read at all (legal to read, no login, no check page). If not, it stops and tells you why.
2. Probes the home, a series and a chapter page, and works out what kind of site it is (a JSON API, Next.js, MangaStream, Madara, plain HTML, encrypted pages).
3. Applies the three-things test: reachable, chapters in the answer, pages in the answer.
4. Starts from the matching template and writes the six sections, checking after each one with the real engine.
5. Records fixtures from the live site, blesses them, and **reads** them.
6. Tries the live site by hand, including page 2, a filter, and a chapter from the middle.
7. Raises the version, rewrites the index, runs everything CI runs, and tells you what it built, what it tested, and what it could not.

It does not commit or push unless you ask. The skill's files:

```text
.claude/skills/manga-sources/
  SKILL.md                      the map and the rules
  references/
    from-a-website.md           the whole workflow, the legal gate, the three-things test
    format.md                   every field, every hole, every limit
    expressions.md              every step, dates, templates, decrypting, the traps
    recipes.md                  patterns that work: API, HTML, MangaStream, Next.js, Madara, paging, nonce, POST, encryption
    debugging.md                every error message and symptom, with the fix
    publishing.md               versions, the index, signing, CI, adding the repo
    engine.md                   what the app does, the limits, what is not supported
  templates/                    one working template per kind of site, and worked examples with fixtures
  scripts/                      probe, check, record, run-live, index, check-all
```

You need the code repo next to this one (`../akidev`, or set `CODE_REPO`) and a Rust toolchain. The first script run builds the engine.

## How a source works

A source asks the site **six questions**. Each question is a section of the file.

| Question | Section | What the app shows |
| --- | --- | --- |
| What is popular? | `popular` | the Popular list on Browse |
| What is new? | `latest` | the Latest list |
| Which series match this? | `search` | search results, and the genre chips |
| Tell me about this series | `detail` | the series page: cover, description, authors, tags, status |
| List its chapters | `chapters` | the chapter list |
| Give me the pages of this chapter | `pages` | the reader |

A source needs `detail`, `chapters`, `pages`, and at least one of `popular`, `latest`, `search`.

Each section is a **request** (which url, which method) and a way to **read** the answer. Here is a whole, small source for a made-up JSON API:

```json
{
  "schema": 1,
  "id": "my-api-site",
  "name": "My API Site",
  "version": 1,
  "lang": ["en"],
  "nsfw": false,
  "base_url": "https://api.example.com",
  "rate_per_second": 2,

  "popular": {
    "request": { "url": "{base}/series?offset={offset}&per_page=20&sort=popular" },
    "format": "json",
    "rows": "data",
    "card": { "id": "slug", "title": "title", "cover": "cover", "chapters": "chapter_count" },
    "next": "meta.has_more"
  },

  "detail": {
    "request": { "url": "{base}/series/{id}" },
    "format": "json",
    "title": "series.title",
    "cover": "series.cover",
    "description": [{ "path": "series.description" }, "plain_text"],
    "authors": "series.author",
    "tags": "series.genres.*.name"
  },

  "chapters": {
    "request": { "url": "{base}/series/{id}/chapters?page={page}&per_page=100" },
    "format": "json",
    "rows": "data",
    "chapter": {
      "id": "slug",
      "number": "number",
      "date": [{ "path": "published_at" }, { "date": ["iso"] }]
    },
    "repeat": { "size": 100 }
  },

  "pages": {
    "request": { "url": "{base}/series/{series}/chapters/{id}" },
    "format": "json",
    "images": "data.pages.*.url",
    "reading": "longstrip"
  }
}
```

Read it top to bottom:

- `{base}` is the site's address. **Every url must start with it.** A source can only ask its own address.
- `{offset}`, `{page}`, `{id}`, `{series}` are **holes**. The engine fills them: the page number, the series a card named, the chapter.
- `rows` is where the cards are. `card` says how to read one: `"slug"` is a path into one row of JSON.
- `next` says another page follows when `meta.has_more` has a value.
- `repeat` says the chapter list comes in pieces: ask again, 100 further on, until a page brings nothing new.
- `"plain_text"` turns HTML in a text into plain text.
- `{series}` is the series id, and `{id}` is the chapter's, because it is the `pages` section.

The `id` a card gives is passed to `detail` and `chapters` as `{id}`. The `id` a chapter gives is passed to `pages` as `{id}`, with `{series}` the series. An id is any text. It does not have to be a slug.

### Reading HTML

If the site gives HTML, the same idea uses CSS selectors:

```json
"popular": {
  "request": { "url": "{base}/series?sort=popular&page={page}" },
  "rows": "div.series-card",
  "card": {
    "id":    [{ "css": "a" }, { "attr": "href" }, { "regex": "/series/([^/]+)/?$" }],
    "title": "h3",
    "cover": [{ "css": "img" }, { "attr": "data-src|data-lazy-src|src" }, "abs"]
  },
  "next": "a[rel=\"next\"]"
}
```

`"div.series-card"` is a selector, one card per match. In a card, `[{ "css": "a" }, { "attr": "href" }, { "regex": "..." }]` is a **pipe**: find the link, take its `href`, cut the slug out of it. Each step turns the list before it into a new list.

## Writing a source by hand

You do not need the agent. This is the loop, and the scripts do the hard parts.

```bash
# 0. See what kind of site it is
.claude/skills/manga-sources/scripts/probe.sh https://www.example.com/ https://www.example.com/series/x/ https://www.example.com/series/x/chapter-1/

# 1. Start from the template that matches
cp .claude/skills/manga-sources/templates/source-json-api.json sources/my-site.json
#    edit id, name, base_url, then each section against what the probe saved in /tmp/manga-probe/

# 2. Check as you go (no network, no fixtures: only the rules that need no site)
.claude/skills/manga-sources/scripts/check.sh sources/my-site.json

# 3. Try the live site
.claude/skills/manga-sources/scripts/run-live.sh sources/my-site.json popular
.claude/skills/manga-sources/scripts/run-live.sh sources/my-site.json chapters <series-id>

# 4. Record real answers as fixtures, then write down what the definition returns
.claude/skills/manga-sources/scripts/record.sh sources/my-site.json popular details=<series-id> chapters=<series-id> pages=<series-id>,<chapter-id>
.claude/skills/manga-sources/scripts/check.sh sources/my-site.json fixtures/my-site --bless
#    READ fixtures/my-site/fixtures.json. --bless saves whatever came back, right or wrong.

# 5. Index and run what CI runs
.claude/skills/manga-sources/scripts/index.sh
.claude/skills/manga-sources/scripts/check-all.sh
```

The scripts are thin wrappers over the engine's command line, `akidev-manga-cli` (in the code repo, `desktop/manga/src/bin/cli.rs`). The raw commands, if you prefer them:

```bash
cd ../akidev/desktop
cargo run -p akidev-manga --bin akidev-manga-cli -- check ../../manga-sources/sources/<id>.json ../../manga-sources/fixtures/<id> --themes ../../manga-sources/themes
cargo run -p akidev-manga --bin akidev-manga-cli -- check ... --bless          # write what the definition returns as the expected answers
cargo run -p akidev-manga --bin akidev-manga-cli -- run ../../manga-sources/sources/<id>.json popular     # live
cargo run -p akidev-manga --bin akidev-manga-cli -- record <def> <fixtures-dir> popular details=<series> chapters=<series> pages=<series>,<chapter>   # also: latest, search=TERM
cargo run -p akidev-manga --bin akidev-manga-cli -- index ../../manga-sources
cargo run -p akidev-manga --bin akidev-manga-cli -- keygen secret.key
```

A definition is also **validated when it is loaded**: selectors and patterns compile, every request starts with `{base}`, date formats have a year, settings and filters are well formed. A bad one is refused before any site is asked.

### Templates

In `.claude/skills/manga-sources/templates/`. Each one is checked by the real engine. Replace every host, selector and path with what you found on the real site.

| Template | For a site that is |
| --- | --- |
| `source-json-api.json` | a JSON API (Asura-like) |
| `source-html-site.json` | server-rendered HTML |
| `source-mangastream.json` | WordPress with the `mangareader` theme (Arena-like) |
| `source-next-data.json` | Next.js, data in `script#__NEXT_DATA__` (Flame-like) |
| `source-extends-madara.json` | Madara (five lines, on top of `themes/madara.json`) |
| `source-prepare-nonce.json` | one that needs a value from another page first (a nonce) |
| `source-paged-chapters.json` | one whose chapter list comes in pieces |
| `source-encrypted-pages.json` | one whose page list is encrypted (the Madara protector) |
| `source-settings-filters.json` | one with a language or rating choice, a genre or text filter |
| `source-post-json.json` | one that wants a POST with a JSON body (GraphQL) |
| `theme.json` | a new theme for a family of sites |

In `templates/worked-examples/` six of them have hand-made answers and a `fixtures.json`, so you can run the whole loop with no network: `scripts/check.sh templates/source-json-api.json templates/worked-examples/json-api`.

## Everything a definition can say

This is the complete list at a glance. The details, with every rule and trap, are in `.claude/skills/manga-sources/references/format.md` and `expressions.md`.

### Top level

| Field | Meaning |
| --- | --- |
| `schema` | `1` |
| `id`, `name`, `version` | the id (lower case letters, digits, dashes), the name, a whole number raised on every change |
| `lang`, `nsfw` | language codes, and whether the source is adult |
| `base_url`, `mirrors` | the address, and other addresses tried in turn **only when one cannot be reached at all** |
| `rate_per_second` | at most this many requests a second (above 0, at most 20) |
| `headers`, `user_agent` | sent on every request, and a user agent to send instead of the phone browser one |
| `page_size` | titles on a list page, 1 to 500, default 20 (for `{offset}` and `total`) |
| `settings`, `filters` | choices for the person (below) |
| `popular`, `latest`, `search` | the lists |
| `detail`, `chapters`, `pages` | the series, its chapters, a chapter's pages |
| `min_app` | the oldest app version that can run it (copied to the index) |
| `extends` | the id of a theme |

### Requests

`url` (must start with `{base}`), `method` (`GET` or `POST`), `form`, `json`, `headers`. A section's `format` is `html` (the default) or `json`.

Holes: `{page}`, `{page0}`, `{offset}`, `{term}` (search only), `{id}`, `{series}`, `{base}`, a filter's id (search only), a setting's id, a var's name. `{name:raw}` is not percent-encoded (for an id that is a path). `{? ... ?}` vanishes when a hole inside is empty.

**Put `{term}` inside a `{? ... ?}` group, never bare.** A search can run with no term (the home screen's genre chips search with only a filter set), and a bare `{term}` then has nothing to fill it, so the whole request fails with "needs a value this call does not have". `...?q={term}` breaks genre browsing. `...{?&q={term}?}` does not. The same goes for any hole a call might not set.

A site that answers a `POST` (the chapter list) through a redirect loses the body, which silently returns the wrong page. Put the host that answers without redirecting in `base_url` and the other in `mirrors`. The recorded case was `3asq.org`, which answers `301` to `3asq.online`: `.online` had to be `base_url` and `.org` the mirror, even though the extension that led there named `.org`. Probe a mirror pair before writing either address, because the failure is silent.

### Lists (`popular`, `latest`, `search`)

`request`, `format`, `rows`, `card`, `next`, `total`, `prepare`, `vars`.

A card is `{"id": ex, "title": ex, "cover": ex, "chapters": ex}`. Only `id` and `title` are required. `chapters` is optional: when the list shows how many chapters a series has (or its newest chapter, "Ch. 120"), the first number in the text is read and the app shows "120 chapters" on the card, so the person need not open the series to see it. No number, or no field, shows nothing.

How the app knows another page follows:

1. `total` is set: a page follows while `page * page_size < total`. It has to count what a page holds, so a site that hands back 25 rows a page cannot be described by `total` unless `page_size` is 25 too.
2. Otherwise `next` is set: a page follows when `next` gives something. `"next": "a.nextpostslink"` reads the site's own next link.
3. Otherwise a page follows whenever the answer had **rows**. Cards dropped for having no id do not end the list.

Do not build `next` out of the request's own holes (`{"template": "{page}"}`): those are always set, so it would say every page follows for ever.

### detail

`title` (required), `cover`, `description`, `authors`, `tags`, `status`. Authors and tags are lists (every text the expression gives). Status is read as a word: it counts as `hiatus` if it contains "hiatus", `cancelled` for "cancel", "dropped" or "discontinued", `completed` for "complete", "finished" or "ended", `ongoing` for "ongoing", "publishing", "updating" or "releasing", and anything else is `unknown`. So a `map` only matters for another language or for words the list misses (map to one of those four words).

### chapters

`rows`, `chapter` (`id` required; `number`, `title`, `date`, `scanlator`), `order`, `repeat`, `prepare`, `vars`.

Chapters come back **newest first** whatever order the site lists them in. Say `"order": "oldest-first"` if the site lists them oldest first. A chapter's number is read from its title when no `number` is given. `date` must end up as milliseconds since 1970: use the `date` step.

`repeat`: `{"size": 500, "total": "total"}` asks again with `{offset}` raised by `size` until `total` is reached. `{page}` is also set, raised by one each time, for a site that numbers its pages (`?t={page}`) instead of counting rows, so put `{page}` in the request's url, or every request is the same one. `total` counts **chapters**; a site that only says how many **pages** it has (`"total_pages": 6`) must leave `total` out. Asking then stops when a page brings no chapter not already seen. Screenshots of the same list can repeat across pages, so that is the safer stop either way. `size` must be what the site really sends per request. One list may take at most **60** requests, so a source with more chapters than `60 * size` in all asks for a bigger `size`; running out is reported, never returned as a short list that looks complete.

### pages

`images` (every text is a page, in order, made absolute), `reading` (`longstrip`, `paged` or `paged_rtl`), `image_headers`, `prepare`, `vars`. A `referer` of the source's address is sent with every image when none is given. A header with an empty value is left out (`"referer": ""`).

### Chains: `prepare` and `vars`

- `vars`, on any section: `{"server": "baseUrl"}` reads values out of that section's answer and makes them holes in its expressions (the image server an answer names).
- `prepare`, on any section: requests made first, each with its own `vars`, which later requests use as holes (a page that holds a nonce, a lookup that says which server to ask).

### Filters and settings

- `filters`: `{"id", "name", "kind": "select" | "text", "options": [{"value", "name"}], "default"}`. The value fills the hole named by the filter's id, in `search` only. There is no filter screen yet: filters are passed through to the request.
- `settings`: `{"id", "name", "default", "options": [{"value", "name"}]}`. The person's choice (the default until then) fills the hole with the same name as the setting's id (a setting with id `lang` fills `{lang}`), in every section. `{rating:raw}` is not percent-encoded, for an option that is a piece of query. The app shows each setting as a picker on the source's page.

### Expressions

A value is read by an expression. Short forms: HTML `"h3"` (the text of the match), `"img@data-src|src"` (an attribute, the first that is not empty), `"@href"` (an attribute of the row); JSON `"a.b.c"` (a path, `*` for every value). For anything else, a list of steps:

| step | does |
| --- | --- |
| `{"css": sel}` | elements below each node (also in a text that is HTML, for an ajax answer) |
| `{"attr": "a\|b"}`, `"text"`, `"html"` | an attribute, the text (blocks on their own lines), inner HTML |
| `{"path": "a.*.b"}`, `"json"` | into JSON; text parsed as JSON (a `<script>` blob) |
| `{"regex": p}`, `{"replace": {"from": p, "to": t}}` | first capture group (a node that does not match is dropped); replace all |
| `{"template": "{base}/x/{value}"}` | text with the node and the request holes |
| `"abs"` | a link made absolute against the source |
| `{"date": ["MMMM d, yyyy", "iso", "relative"]}` | milliseconds; formats tried in order; `relative` reads "3 days ago" |
| `"number"` | the chapter number in a text ("Ch. 12.5 - Name") |
| `"first"`, `"last"`, `{"nth": n}`, `{"join": ", "}`, `{"split": ","}` | pick, join or split |
| `{"const": t}`, `{"default": t}`, `"non_empty"`, `"exists"`, `{"map": [["ongoing","ongoing"]]}` | constants and tests |
| `{"coalesce": [ex, ex]}` | the first expression that gives something |
| `{"where": {"path": p, "equals"/"not_equals"/"in"/"absent": ...}}` | keeps the JSON nodes whose value at `path` passes (a related item of one type, a row that is not external) |
| `"unique"`, `"sort"` | drops texts already seen; orders texts the way file names read (`p2` before `p10`) |
| `"plain_text"` | HTML inside a text (a JSON field that holds markup) as plain text |
| `"trim"`, `"lower"` | trims, lower-cases |
| `{"aes_cbc": {"passphrase": "{nonce}"}}` | decrypts a payload a site hands over encrypted (below) |

`"where"` values may hold holes (`"equals": "{id}"` picks the row for the id asked about). `{base}` is the source's address. `{value}` in a template is the node being read; `{^.path}` is a value in the row the expression started from (`"{^.id}"` in a cover address); `{name}` is a hole of the request, a setting or a var.

A single step still needs its list: `[{ "path": "token" }]`, never a bare `{ "path": "token" }`.

Dates: patterns use `yyyy`, `yy`, `MMMM`, `MMM`, `MM`, `M`, `dd`, `d` (a day may carry `st`, `nd`, `rd`, `th`). A pattern needs a year. `relative` reads "3 days ago", "an hour ago", "yesterday", "just now". `iso` reads `2024-02-29T10:00:00+00:00`. Month names are English only.

### A MangaStream / WP `mangareader` site

`arenascans` is the working pattern for the WordPress `mangareader` theme (the ThemeSans / MangaStream family). Cards are `div.bsx` (cover `img.ts-post-image`, title `.tt`); the catalogue sorts by `?order=popular` / `?order=update` (the only server-side sorts: the on-page "order" tabs are client-side and change nothing); search filters by `?s=&genre=<slug>`, proven to return a genuinely different list. Two traps, each proven against the live site:

- The reader's `<div id="readerarea">` wraps every page image in a `<noscript>` (the no-JS fallback), and the HTML parser skips `noscript` contents, so `#readerarea img` finds nothing. The pages are read instead from the `ts_reader.run({...})` script blob: `css: "script"` → `text` → regex out the `{...}` argument → `json` → `path: "sources.0.images.*"`. The blob is the canonical image list (173 pages, no tiles, no crypto).
- The site **never fills** its Status / Author / Artist metadata (`<i></i>` or `n/a` even on its most popular title), so `status` reads `unknown` and `authors` reads `[]`. That is truthful; keep the `default`/`non_empty` guards rather than inventing a value.

Its paging was got wrong twice before it was right. `?page=N` is silently ignored by the site (page 2 came back as page 1, and the app's id de-duplication swallowed it, so "Show more" looked dead). It pages by path: `/manga/page/{page}/?order=...` and `/page/{page}/?s=...`. Page 2 and later could not be recorded then, so that part is not fixture-verified. Always ask the live site for page 1 and page 2 and compare.

### A Next.js (or similar) site that ships its data as JSON in the page

Some sites render no list markup at all: the catalogue lives in a `<script>` blob the page's own JavaScript reads. `flamecomics` (Next.js, `script#__NEXT_DATA__`) is the working pattern. The blob is HTML, so the section keeps `format: html` and the expression is `[{ "css": "script#__NEXT_DATA__" }, "text", "json", { "path": … }]`. Four things that bite:

- Once the expression has gone through `"json"`, the nodes are JSON, but the **section's format is still `html`**, so a short-form field (`"token"`) reads as CSS, not a path, and silently gives nothing. Write the path explicitly: `[{ "path": "token" }]`.
- A JSON **object** iterated with `*` (a chapter's `images`, keyed `"0".."22"`) comes back in the object's key order, which is lexicographic: `…-09, -10, … -19, -02`. Add a `"sort"` step before the `template` that builds the address, or the pages come out of order.
- Use `"text"`, not `"html"`, to take the script's content. `"html"` escapes `&`, `<` and `>`, so a description that holds `<p>` shows its tags as text after `plain_text`, and `Tom & Jerry` comes out as `Tom &amp;amp; Jerry`. (`flamecomics` still uses `html`; it gets away with it because its values have none of those characters.)
- A `select` filter, the `next`/`total` rule and the rest behave exactly as on a plain HTML site: the JSON detour changes only how a value is reached, not how lists page or filters fill holes.

### A Madara (WordPress) site

Extend the theme, and give only what differs:

```json
{ "extends": "madara", "id": "my-site", "name": "My Site", "version": 1, "lang": ["en"], "base_url": "https://www.example.com" }
```

Objects merge key by key, anything else is replaced. So `{"chapters": {"request": {"url": "..."}}}` changes one url and keeps the theme's rows, and a source that gives `pages.images` replaces the whole expression. See `themes/madara.json` for what is there, and `examples/madara-example.json` for how it reads recorded markup.

### Encrypted payloads

Some sites do not send a chapter's images at all: they send a blob their own JavaScript decrypts. `aes_cbc` undoes it. Its input is the payload (an object, or the JSON text of one) and the payload usually carries the salt it was made with, so a definition names only the passphrase it read from the same page:

```json
"images": [
  { "css": "script#chapter-protector-data" }, "html",
  { "replace": { "from": "\\\\/", "to": "/" } },
  { "regex": "(?s)var\\s+chapter_data\\s*=\\s*'(\\{.*?\\})';" },
  { "aes_cbc": { "passphrase": "{nonce}" } },
  "json", { "path": "*" }
],
"vars": { "nonce": [{ "css": "script#chapter-protector-data" }, "html", { "replace": { "from": "\\\\", "to": "" } }, { "regex": "var\\s+wpmangaprotectornonce\\s*=\\s*'([^']*)';" }] }
```

(The Madara family's "chapter protector", worked through in `examples/madara-protected.json`.) The key is `MD5(previous ++ passphrase ++ salt)` repeated to 48 bytes (32 for the key, 16 for the IV), which is what the site's script does; a payload that carries its own `iv` uses that instead. A site with one fixed key states it rather than deriving one: `{"aes_cbc": {"key": "…64 hex…", "iv": "…32 hex…"}}` (32-byte key for AES-256, 16 for AES-128). `"hex": true` when the ciphertext itself is hex rather than base64. The salt must be hexadecimal.

Decryption is the only thing in the engine that touches cryptography: no definition can ask for an encryption, a signature or a hash of its own, so this cannot be turned into an oracle for something else.

## What is not supported

Plainly:

- **A site behind a check** (Cloudflare "Just a moment", a captcha, a JavaScript challenge). The app has no web view and no way past a check. The call fails with `wants a check before it answers`, and the app says the site is not supported from here. Do not look for a way around.
- **A login, an account, a paywall.** A definition cannot log in or hold a secret, and this repository is public.
- **Chapters or pages that a script fills in after the page loads.** There is no script engine. A script *blob* that holds the data as JSON (`__NEXT_DATA__`, `ts_reader.run({...})`) can be read, because it is text in the answer.
- **Tile descrambling.** The image arrives with a permutation saying which `tile_cols × tile_rows` cell belongs where, so it has to be undone on the image bytes, which means a codec in the engine and a call the app makes instead of showing the address. The only source that had it (`AsuraScans`) stopped sending the permutation (verified against its live API on 2026-10-22, every page comes back as `{url, width, height}`), so there is nothing to descramble and nothing to test against. It gets built when a source actually sends one; the algorithm is a paragraph, not a research project (see the code repo's `pipeline/MANGA_SOURCES_PORT_PLAN.md` §Phase 4).
- **`xor` steps, other ciphers, other key derivations.** Only AES-CBC.
- **Scripting for sites a definition cannot express.** Decided against for v1 (see `pipeline/MANGA_PLAN.md`).
- **A request to another host, or a method other than GET and POST.**
- **A filter screen.** Filters are parsed and only passed through to a request's holes.

When something needs a change in the engine, the answer is a change in the code repo, `desktop/manga/src/<file>`. See `.claude/skills/manga-sources/references/engine.md` for which file.

## Publishing

1. Edit or add `sources/<id>.json` (raise its `version`) and `themes/<id>.json`.
2. Run the checks. `scripts/check-all.sh` runs every definition against its fixtures (and fails when `index.json` is stale). The raw form is `cargo test -p akidev-manga` in the code repo.
3. Rewrite the index: `scripts/index.sh`, or `cargo run -p akidev-manga --bin akidev-manga-cli -- index manga-sources`. It writes `index.json` with every file's version and SHA-256. Commit it with the rest. An app refuses a file whose hash is not the index's, so a stale index breaks installs, which is why a test guards it.
4. Optional signing: `akidev-manga-cli keygen secret.key` (keep it out of the repository), then `scripts/index.sh --key secret.key` writes `index.json` with the public key and `index.json.sig`. The app remembers the key the first time a signed repository is added and refuses the repository later if it names a different one (the person removes and re-adds it to trust a new key). Nothing here is signed today.
5. Push. Apps see the new version at their next start.

### The index

```json
{ "schema": 1, "name": "Akidev sources", "key": "<public key hex, only if signed>",
  "sources": [ { "id": "example", "name": "Example", "version": 1, "path": "sources/example.json",
                 "sha256": "...", "lang": ["en"], "nsfw": false, "min_app": "0.1.25", "requires": ["madara"] } ],
  "themes":  [ { "id": "madara", "version": 1, "path": "themes/madara.json", "sha256": "..." } ],
  "voices":  [] }
```

Paths stay inside the repository (no `..`, no addresses); ids are lowercase letters, digits and dashes; every `requires` names a listed theme (installed with the source); `min_app` is the oldest app that can run it. You never write the index by hand: the script does.

### CI

`.github/workflows/check.yml` builds the checker from the code repo, replays every definition in `sources/` and `examples/` against its fixtures, and fails if the committed index is not what the CLI would write. CI uses the recorded answers and never contacts a site, so a site that changed does not turn CI red. Only a re-record shows it.

### Fixtures

`record` asks the live site for the calls you name and saves its answers as fixtures in one go:

```bash
scripts/record.sh sources/<id>.json popular details=<series> chapters=<series> pages=<series>,<chapter>        # also: latest, search=TERM
```

`--bless` writes whatever the definition returns: **read the result before committing it.** An empty list, a `null` date or a count that is too small is a bug `--bless` will happily save. `arenascans` shipped with `"date_ms": null` on every chapter because a field was spelled `uploaded` instead of `date`, and **an unknown key is silently ignored**, so a misspelled field just reads as "the site has none".

Fixtures written by hand: `madara-example` (to look like Madara's markup) and `madara-protected` (an encrypted chapter payload), and the worked examples under the skill's `templates/`. Hand-written fixtures prove the engine reads those shapes, not that a real site matches them. A source added later should have fixtures recorded from the live site with `record`, from a clean network (a filtered one records its block page).

## Where to read more

| You want | Read |
| --- | --- |
| The whole workflow for a new site | `.claude/skills/manga-sources/references/from-a-website.md` |
| Every field and limit | `.claude/skills/manga-sources/references/format.md` |
| Every step, dates, the traps | `.claude/skills/manga-sources/references/expressions.md` |
| A pattern for a kind of site | `.claude/skills/manga-sources/references/recipes.md` |
| An error message | `.claude/skills/manga-sources/references/debugging.md` |
| Versions, the index, signing, CI | `.claude/skills/manga-sources/references/publishing.md` |
| What the engine does and cannot do | `.claude/skills/manga-sources/references/engine.md` |
| Why it is built this way | the code repo's `pipeline/MANGA_PLAN.md` and `pipeline/MANGA_SOURCES_PORT_PLAN.md` |
| The engine itself | the code repo's `desktop/manga/src/` (`def.rs`, `source.rs`, `eval.rs`) |
