# Recipes: patterns that work

Each recipe says what the site looks like, which template to start from, and the traps. The working files are in `templates/` and the real sources in `sources/`. Always replace the placeholder hosts, selectors and paths with what you found on the real site.

## Contents

1. [A JSON API](#1-a-json-api)
2. [A plain HTML site](#2-a-plain-html-site)
3. [A MangaStream / WordPress `mangareader` site](#3-a-mangastream--wordpress-mangareader-site)
4. [A Next.js site that ships its data in the page](#4-a-nextjs-site-that-ships-its-data-in-the-page)
5. [A Madara (WordPress) site](#5-a-madara-wordpress-site)
6. [A chapter list that comes in pieces](#6-a-chapter-list-that-comes-in-pieces)
7. [A request that needs a value from another page (nonce, token)](#7-a-request-that-needs-a-value-from-another-page-nonce-token)
8. [POST, forms, JSON bodies and GraphQL](#8-post-forms-json-bodies-and-graphql)
9. [Encrypted page lists](#9-encrypted-page-lists)
10. [Filters and settings](#10-filters-and-settings)
11. [Mirrors](#11-mirrors)
12. [Ids that are paths, and sites with more than one kind of title](#12-ids-that-are-paths-and-sites-with-more-than-one-kind-of-title)
13. [Covers and images that need building](#13-covers-and-images-that-need-building)
14. [A source with only search](#14-a-source-with-only-search)
15. [Writing a new theme](#15-writing-a-new-theme)

## 1. A JSON API

**Looks like:** the site has an address that answers JSON for lists, a series, its chapters and a chapter's pages. Often a separate host (`api.example.com`). The best case: stable, fast, and nobody parses markup.

**Start from:** `templates/source-json-api.json`. Real example: `sources/asurascans.json`.

How to find the API: open the site's pages and watch what the page itself asks for. The browser's network tab (filter by Fetch/XHR) shows it, and so does `curl` on the page and `grep` for `api.`, `/api/`, `graphql`, `_next/data`. Then confirm with `scripts/probe.sh` on the API url.

Things to get right:

- Every section has `"format": "json"`.
- `rows` is the path to the list (`"data"`). `card.id` is the field a later call will use (`"slug"` if the detail url takes a slug).
- A list that says `has_more` is `"next": "meta.has_more"`. A list that says how many in all is `"total": "meta.total"` (and set `page_size` to the real page size). A list that does neither can leave both out: a next page follows when there were rows.
- An API that pages by offset uses `{offset}` (`(page - 1) * page_size`) and a `per_page` that **equals `page_size`**. An API that pages by number uses `{page}`.
- The chapters usually come in pages: `"repeat": {"size": 100}` with `{page}` or `{offset}` in the url (see recipe 6).
- A description that holds HTML needs `plain_text`.
- Status: if the API gives a word, the engine's own reading usually works. Add a `map` for another language.
- Cover addresses that are full URLs work as they are. A path is made absolute against the host that answered, which is the API host, **not** the CDN. If the cover lives on another host, use a `template` (recipe 13).

## 2. A plain HTML site

**Looks like:** server-rendered pages. A list page with a card per series, a series page with a chapter list, a chapter page with `<img>` tags.

**Start from:** `templates/source-html-site.json`. Real example: `sources/dynastyscans.json` (the search part).

Things to get right:

- `rows` is the selector for **one card**. Pick the smallest repeating element that holds both the link and the title.
- `card.id` is almost always a slug cut out of the link: `[{"css":"a"},{"attr":"href"},{"regex":"/series/([^/]+)/?$"}]`. The `$` and the optional `/?` matter: they stop a regex from matching a chapter link (`/series/x/chapter-1/`) when you want the series.
- Use the link that is the **series**. A card often has two links (the title and the "latest chapter"). Select `.title a`, not `a`.
- Lazy-loaded images carry the real address in `data-src` or `data-lazy-src`, and `src` is a placeholder (`data:image/gif...`). Read `data-src|data-lazy-src|src`: the first non-empty wins, and a `data:` address is dropped anyway.
- A chapter page whose images are in `<noscript>` shows `0` images to the parser. See recipe 3.
- `next`: a next link (`a[rel="next"]`, `a.next`, `a.nextpostslink`). With no pagination markup, leave `next` out.
- Dates: read the date element's text and give `date` a list of the formats the site uses, then `relative`.

## 3. A MangaStream / WordPress `mangareader` site

**Looks like:** WordPress with the `mangareader` theme (the MangaStream / ThemeSans family). Cards are `div.bsx` with `img.ts-post-image` and `.tt`. The catalogue sorts with `?order=popular` and `?order=update`. The reader is `<div id="readerarea">`.

**Start from:** `templates/source-mangastream.json`. Real example: `sources/arenascans.json`.

The facts, each proven against a live site:

- The only server-side sorts are `?order=popular` and `?order=update`. The on-page "order" tabs are client-side and change nothing.
- Search is `{base}/page/{page}/?s={term}`. It **filters by genre** with `?s=&genre=<slug>`, and that returns a genuinely different list. Write it as `?s={?{term}?}{?&genre={genre}?}`.
- **The reader hides its images.** `<div id="readerarea">` wraps every page image in `<noscript>` (the no-JS fallback) and the parser skips `noscript`, so `#readerarea img` finds nothing. The pages are in a script:
  ```json
  "images": [ {"css": "script"}, "text", {"regex": "(?s)ts_reader\\.run\\((\\{.*?\\})\\);"}, "json", {"path": "sources.0.images.*"} ]
  ```
  That blob is the canonical image list (every page, no tiles, no crypto). `arenascans` anchors the regex to the end of the script (`...\\}\\);?\\s*$`) and ends with `"unique"`. If your first regex grabs the wrong script, do the same.
- **The site never fills Status / Author / Artist.** The markup is `<i></i>` or `n/a` even on the most popular title. So `status` reads `unknown` and `authors` reads `[]`. That is truthful. Keep the `default` / `non_empty` guards instead of inventing a value:
  ```json
  "authors": [ {"css": ".imptdt"}, "text", {"regex": "(?i)Author\\s+(.+)$"}, {"replace": {"from": "(?i)^n/a\\s*$", "to": ""}}, "non_empty", "first" ]
  ```
- The chapter list is `#chapterlist li` in the series page, with `.chapternum`, `.chapterdate` (`October 19, 2026`) and a template row `{{date}}` that a `li[data-num]` selector skips.
- **Pagination was got wrong twice, so prove it.** `arenascans` v3 paged with `?page=N` (the site's own next link points there). v4 found that `?page=N` is **silently ignored**: page 2 returned page 1's exact cards, so the app's id de-duplication swallowed it and "Show more" looked dead while `has_next` stayed true. The site paginates by path: `/manga/page/{page}/?order=...` for browsing and `/page/{page}/?s=...` for search. Page 2 and later could not be recorded at the time (the relay looped every listing to page 1), so **that rule is not fixture-verified**. Before you believe any paging rule, ask the live site for page 1 and page 2 and check the cards differ.

## 4. A Next.js site that ships its data in the page

**Looks like:** no list markup at all. The catalogue lives in `<script id="__NEXT_DATA__" type="application/json">` that the page's own JavaScript reads.

**Start from:** `templates/source-next-data.json`. Real example: `sources/flamecomics.json`.

The expression to reach the data is the same prefix every time:

```json
[ {"css": "script#__NEXT_DATA__"}, "text", "json", {"path": "props.pageProps.series.title"} ]
```

Things to get right:

- **Use `"text"`, not `"html"`**, on the script. `html` escapes `& < >` (see `expressions.md`, trap 1). `flamecomics` uses `html` and gets away with it only because its values have none of those characters.
- The blob is HTML, so the section **keeps `format: html`**. After `json`, nodes are JSON, but the section is still `html`, so a short form reads as CSS. **Write `{ "path": ... }` inside a list.**
- A JSON **object** iterated with `*` comes out in key order, which is text order: `0, 1, 10, 11, ..., 19, 2`. For page images add `"sort"` before the `template` that builds the address.
- Next.js sites often build image addresses from a CDN path plus fields (`{series}/{chapter}/{name}`). Use `template` (recipe 13).
- `/_next/data/<build id>/...json` also exists, but the build id changes on every deploy. Read the page instead.
- A site's own `/api/...` is sometimes there too (flamecomics' search is `/api/series`). Use it for search when it exists: it is JSON, not a blob.

## 5. A Madara (WordPress) site

**Looks like:** WordPress with the Madara theme. `div.page-item-detail` cards, `/manga/<slug>/` series pages, `li.wp-manga-chapter` chapters loaded by a POST to `.../ajax/chapters/`, `div.page-break img` pages.

**Start from:** `templates/source-extends-madara.json`. The theme is `themes/madara.json`, and `examples/madara-example.json` is how it reads recorded markup.

```json
{ "extends": "madara", "id": "my-site", "name": "My Site", "version": 1,
  "lang": ["en"], "nsfw": false, "base_url": "https://www.example.com" }
```

What the theme gives you: popular and latest (`?m_orderby=views` / `latest`), search (`?s=&post_type=wp-manga`), detail, chapters (POST to `{base}/manga/{id}/ajax/chapters/`), pages. What a site usually changes:

- **A different series path.** Some sites do not use `/manga/`. Override the `card.id` regex and the `detail`/`chapters`/`pages` urls.
- **`pages` markup.** Override `pages.images` for a site whose images are in `.reading-content` or encrypted (recipe 9).
- **The chapter list must come in the answer.** Some Madara sites put the list in the series page, not behind the POST. Override `chapters.request` to the series page, a `GET`. A site whose series page has `0` chapter rows and whose list needs a POST is fine, as long as the POST is not redirected (recipe 11). A site that fills the list with JavaScript and has no POST either cannot be read.
- **Status words in another language.** The theme's `map` already covers Arabic. Add yours by replacing `detail.status` (a list is replaced, not merged).

Objects **merge**, anything else is **replaced**: to change only `chapters.request.url`, write `{"chapters": {"request": {"url": "..."}}}` and keep the theme's rows. To change `pages.images`, give the whole expression.

Run `scripts/check.sh` with the theme: the scripts pass `themes/`, so `extends` resolves. Record real fixtures with `scripts/record.sh`. Do not copy the hand-written madara examples: they prove the theme, not your site.

Madara sites of the "Hentai"/adult kind need `"nsfw": true`.

## 6. A chapter list that comes in pieces

**Looks like:** the chapter request has `page`, `offset` or `limit`, or the answer says `total`.

**Start from:** `templates/source-paged-chapters.json`. Worked example: `templates/worked-examples/paged-chapters/` (its own `definition.json`, with `size` 2 so the fixtures stay small).

```json
"chapters": {
  "request": { "url": "{base}/titles/{id}/chapters?offset={offset}&limit=500" },
  "format": "json", "rows": "items",
  "chapter": { "id": "id", "number": "number" },
  "repeat": { "size": 500, "total": "total" }
}
```

Rules (full detail in `format.md`):

- **`size` is what the site really returns per request**, and it is the step of `{offset}`. Set it to the request's `limit` or `per_page`.
- `total` counts **chapters**. If the site only says how many **pages** there are, **leave `total` out**. Asking then stops when a page brings no new chapter. That needs one extra, empty answer in the fixtures.
- For a site that numbers its pages, put `{page}` in the url. For one that counts rows, put `{offset}`. With neither, every request is the same one and you get the first page again and again, then stop.
- At most 60 requests. A series with more chapters than `60 * size` needs a bigger `size`. Running out is an **error**, not a short list.
- A site whose last page is shorter than the others is fine. A site that repeats the **whole list** on every page ends the loop on the first repeat, because nothing new arrived.
- `order`: say `oldest-first` if the site lists oldest first (`dynastyscans` does).

## 7. A request that needs a value from another page (nonce, token)

**Looks like:** the chapter POST fails with `0` or `-1`, or `403`, unless it carries a nonce that sits in the series page. Or the page list needs the image server an earlier answer names.

**Start from:** `templates/source-prepare-nonce.json`. Worked example: `templates/worked-examples/prepare-nonce/`.

- **`prepare`** makes an earlier request and reads `vars` from it. Those become holes (`{nonce}`) in the real request.
- **`vars`** on a section reads values out of **that section's own answer** and makes them holes in that section's expressions. Use it when the value is in the page you are already reading (the image server a chapter page names).
- A `prepare` is a real request each time. For a paged chapter list it runs once, before the loop.
- A nonce expires. Do not record a fixture's nonce into the definition: the definition reads it from the page, and the fixture's page holds the one that was live.

## 8. POST, forms, JSON bodies and GraphQL

**Start from:** `templates/source-post-json.json`.

- `"method": "POST"` with `form` (a map of text) or `json` (any JSON).
- A form field with an empty hole is left out. In a `json` object, a key with an empty hole is dropped. An empty hole in a JSON list fails the request.
- GraphQL: one `POST` with a `json` body that has `query` and `variables`. Keep the query text in the definition. The variables use holes (`"q": "{term}"`, `"page": "{page}"`). The answer is JSON under `data`.
- Add `headers` the site wants (`"x-requested-with": "XMLHttpRequest"`, an `accept`). A source-level `headers` goes on every request.
- **A POST that is redirected loses its body.** See recipe 11.
- Numbers in a `json` body: a string hole gives a string. If the API insists on a number (`"page": 2`), you cannot get one from a hole. Check whether it accepts `"2"`. If not, tell the user it needs engine support.

## 9. Encrypted page lists

**Looks like:** the chapter page has a `<script>` with a blob (`chapter_data = '{"ct":"...","s":"...","iv":"..."}'`) and a nonce, and no `<img>`. The Madara "chapter protector" is the known case.

**Start from:** `templates/source-encrypted-pages.json`. Real run: `examples/madara-protected.json` (a recorded payload).

- The passphrase is a **variable read from the same page** (`vars.nonce`), so the definition never holds a secret.
- Un-escape the blob first (`replace` `\\/` to `/`), cut the object out with `regex`, decrypt with `aes_cbc`, parse with `json`, take the values with `{"path":"*"}`.
- A site with **one fixed key** states it: `{"aes_cbc": {"key": "<64 hex>", "iv": "<32 hex>"}}`. A key that is **in the page** is data. A key that you had to *find in the site's JavaScript* is still the site's published key, but think about whether you are bypassing a protection the site meant to keep (rule 4 in `SKILL.md`). If it is the site's own reader script doing the decryption for every visitor, reading the same list is what the reader does. If the user is unsure, ask.
- Only AES-CBC. Other ciphers, a different key derivation, or an extra layer (xor, base64 twice with a shuffle) are code: see `engine.md`.
- Tile-scrambled images (the picture arrives cut in pieces) are **not supported**.

## 10. Filters and settings

**Start from:** `templates/source-settings-filters.json`. Worked example: `templates/worked-examples/settings-filters/`.

- A **filter** narrows one search: a genre, an order, an author. It fills `{id}` in `search` only. Always inside a group: `{?&genre={genre}?}`.
- A **setting** is per source and fills `{id}` in every section: a language, a content rating. Its default must be one of its options.
- A `select` filter's options are `value` (goes in the url) and `name` (what people read). Copy the values from the site's own filter form, do not guess slugs.
- **Prove a filter works** against the live site: two different values, two different lists. If both return the same list, the site ignores the parameter, and the filter must not ship.
- A filter with a `default` always has a value, so the request always carries it (`order=popular`). A filter without a default has no value until the person chooses, which is why the hole sits in a group.
- To order a list differently (popular, latest), prefer two sections (`popular` and `latest`) over a filter. They become the home screen's lists.
- `{rating:raw}` for an option that is a piece of query (`safe&contentRating[]=suggestive`).

## 11. Mirrors

A site often has several addresses. `mirrors` are tried **in turn only when the first cannot be reached at all**. A site that answers with an error is not retried.

- Put the address that answers **without redirecting** in `base_url`. A redirect turns a POST into a GET and drops the body: you get the wrong page and no error. `3asq.org` answered `301` to `3asq.online`, so `.online` had to be `base_url` and `.org` the mirror, even though the extension that led there named `.org`.
- **Probe both** (`scripts/probe.sh https://a https://b`) before writing either. Look at the redirect field.
- Mirrors should serve the same markup. If they differ, they are different sources.
- `{base}` and `abs` follow the host that answered, so image addresses follow the working mirror.
- Metadata goes stale: a site listed in an old extension repository is often parked or dead. Probe the live address, never trust a list.

## 12. Ids that are paths, and sites with more than one kind of title

An id is any text. It does not have to be a slug:

- **A path as an id**: `dynastyscans` uses `series/<permalink>` and `doujins/<permalink>` as ids, so one source covers two kinds of title. The urls are `{base}/{id:raw}.json`. `:raw` keeps the slash from being percent-encoded.
- **A number**: `"id": "id"` from JSON, used as `{id}`.
- **A compound id**: build it with `template` (`"{^.kind}/{^.slug}"`).
- Ids the app stores must stay stable. If you change how an id is built, every saved library entry for that source breaks. Raise the version, tell the user, and prefer a new source id.

`{id}` in `pages` is the **chapter** id, `{series}` the series id: a site whose chapter url holds both (`/series/{series}/{id}`) uses both.

When a chapter id is a path too, use `{id:raw}` there as well (`flamecomics` pages: `{base}/series/{series}/{id:raw}`).

## 13. Covers and images that need building

When the data gives a file name and the CDN is another host:

```json
"cover": [ {"path": "image"}, {"template": "https://cdn.example.com/series/{^.id}/{value}"} ]
```

`{value}` is the field read, `{^.id}` is the `id` of the **row** (the card). Use `{^.path}` for anything in the row that is not the node you are on. It works for JSON rows only.

For page images that need the series and chapter in the address: `{series}` and `{id}` are in every template, and `{id:raw}` if the chapter id holds a slash.

When the images need a header (a referer the CDN checks, or none): `image_headers`. An empty value removes a header: `"referer": ""`.

## 14. A source with only search

`flamecomics` has only `search`. The engine reports which of popular, latest and search a source has, and a source needs at least one. A `search` with no term (`{?{term}?}`) is how a catalogue is listed when there is no popular endpoint. Write the search url so an empty term returns everything.

## 15. Writing a new theme

Write a theme when **two or more sites** run the same CMS and differ only in address and small details. One site is a source, not a theme.

**Start from:** `templates/theme.json`. Real example: `themes/madara.json`.

1. Write the first site as a full source and get it right, with real fixtures.
2. Move what is shared into `themes/<id>.json`: add `"theme": true` and a `"version"`, remove `id`, `name`, `base_url`, `lang`, `nsfw`.
3. Turn the first site into `{ "extends": "<id>", ... }` with only what differs.
4. Re-run its fixtures. The answers **must not change**.
5. Add the second site as another `extends`, with its own recorded fixtures.
6. `scripts/index.sh`, then `scripts/check-all.sh`.

A theme is a partial definition and is not validated on its own. It is validated when a source resolves it. So always test a theme through a source that extends it.

Raise the theme's `version` when you change it, and re-run **every** source that extends it. The sources' own files do not change, so the index shows only the theme's hash move: the app updates the theme, and every installed source that extends it follows.

An example that is only there to test the theme goes in `examples/` and is not in the index (`madara-example`).
