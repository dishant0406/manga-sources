# The format (schema 1)

Everything a definition can say, and what the engine does with it. The code is `desktop/manga/src/def.rs` (the shapes), `source.rs` (what happens), `theme.rs` (themes) and `repo.rs` (the index). Where this file says "refused", the engine's `validate` rejects the definition when it is loaded, before any site is asked.

## Contents

1. [A whole source at a glance](#a-whole-source-at-a-glance)
2. [Top level](#top-level)
3. [Requests](#requests)
4. [Holes](#holes)
5. [Lists: popular, latest, search](#lists-popular-latest-search)
6. [detail](#detail)
7. [chapters](#chapters)
8. [pages](#pages)
9. [prepare and vars](#prepare-and-vars)
10. [filters](#filters)
11. [settings](#settings)
12. [auth: signing in](#auth-signing-in)
13. [Themes and extends](#themes-and-extends)
14. [The index and the repository files](#the-index-and-the-repository-files)
15. [Limits in one table](#limits-in-one-table)
16. [What the app gets back](#what-the-app-gets-back)

## A whole source at a glance

```json
{
  "schema": 1,
  "id": "my-site",
  "name": "My Site",
  "version": 1,
  "lang": ["en"],
  "nsfw": false,
  "base_url": "https://www.example.com",
  "mirrors": [],
  "rate_per_second": 2,
  "page_size": 20,
  "popular":  { "request": {}, "format": "html", "rows": "", "card": {}, "next": "" },
  "latest":   { "...": "same shape as popular" },
  "search":   { "...": "same shape, and may use {term} and the filters" },
  "filters":  [],
  "settings": [],
  "detail":   { "request": {}, "title": "" },
  "chapters": { "request": {}, "rows": "", "chapter": {} },
  "pages":    { "request": {}, "images": "" }
}
```

That block shows the *places* things go, not a working file. For working files, open `templates/`.

A source asks the site six questions, and each one is a section:

| Question | Section | Needed |
| --- | --- | --- |
| What is popular? | `popular` | at least one of `popular`, `latest`, `search` |
| What is new? | `latest` | (see above) |
| Which series match this? | `search` | (see above) |
| Tell me about this series | `detail` | yes |
| List its chapters | `chapters` | yes |
| Give me the pages of this chapter | `pages` | yes |

## Top level

| Field | Type | Default | Meaning |
| --- | --- | --- | --- |
| `schema` | number | required | Must be `1`. A higher number is refused: the app says it reads schema 1. |
| `id` | text | required | Lower case letters, digits and dashes. Not empty. The file is `sources/<id>.json`. Not more than 64 characters in the index. |
| `name` | text | required | What the person sees. |
| `version` | whole number | required | Raise it on every change. A higher version is what makes an installed copy update. |
| `lang` | list of text | `[]` | Language codes, for the list screen and filters (`["en"]`). |
| `nsfw` | true/false | `false` | Marks an adult source so the app can hide or gate it. Set it honestly. |
| `base_url` | text | required | An `http` or `https` address with a host. Every request starts from it. |
| `mirrors` | list of text | `[]` | Other addresses of the same site, tried in turn **only when one cannot be reached at all**. A mirror must be an `http(s)` address too. |
| `rate_per_second` | number | no limit | At most this many requests a second to this source. Must be above `0` and at most `20`. Use `1` or `2` for a small site. |
| `headers` | map of text | `{}` | Sent with every request. A request's own `headers` win. Values may hold holes. |
| `user_agent` | text | a phone browser | Sent instead of the browser one, for a source that asks clients to say who they are. The default is an iPhone Safari string, because most sites turn away anything that says it is a script. |
| `page_size` | whole number | `20` | How many titles a list page holds. From `1` to `500`. Used for `{offset}` (`(page - 1) * page_size`) and for `total`. |
| `settings` | list | `[]` | Choices the person makes for this source. See [settings](#settings). |
| `auth` | object | none | Signing in to a source that has paid or private titles. See [auth](#auth-signing-in). |
| `filters` | list | `[]` | Ways to narrow a search. See [filters](#filters). |
| `min_app` | text | none | Not read by the engine. The index copies it so an old app can refuse the source. Write the oldest app version that can run the definition (`"0.1.25"`). |
| `extends` | text | none | The id of a theme. See [themes](#themes-and-extends). |

## Requests

Every section has a `request`:

| Field | Meaning |
| --- | --- |
| `url` | **Must start with `{base}`.** A source can only ask its own address. The rest may hold holes. |
| `method` | `GET` (default) or `POST`. Nothing else is accepted. Case does not matter. |
| `form` | A map. Sent as a form (`application/x-www-form-urlencoded`). A field whose hole has no value is **left out**, not sent empty. |
| `json` | Any JSON value, sent as the body. Strings inside are filled. In an object, a key whose value has an empty hole is **dropped**. An empty hole inside a list makes the whole request fail. |
| `headers` | A map. Added to the source's `headers`. The same header name in the request replaces the source's, whatever its case. |

`format` says how to read the answer: `html` (the default) or `json`. It is on each section, because one site often mixes them (an HTML list and a JSON chapter list).

Rules that bite:

- **A POST that is redirected loses its body.** The site answers the redirect, the engine follows it as a GET, and you silently get the wrong page. Put the host that answers *without* redirecting in `base_url` and the other in `mirrors`. The recorded case was `3asq.org`, which answered `301` to `3asq.online`. Probe a mirror pair before you write either address, because the failure is silent.
- `{base}` is the host that is answering (the first one that could be reached), not always `base_url`. That matters in `abs` and in templates, and it is why a source that works through a mirror still reads images from the mirror.
- The body of an answer may not be larger than 8 MB.
- A request times out after 30 seconds (connect: 10 seconds). Redirects are followed.
- Only a site that cannot be reached at all (no network, the name does not resolve, a refused connection) moves on to the next mirror. A site that answers with an error status, or with a check page, **is not retried elsewhere**.
- A site that answers with a check page (Cloudflare "Just a moment", a captcha) makes the call fail with `wants a check before it answers`. The app then says the site is not supported from here. See `engine.md`.
- A status that is not a success (404, 500) fails the call with `<url> answered <status>`.

## Holes

A hole is `{name}` in a url, form, json, header or template. It is replaced by a value, **percent-encoded** in a url. `{name:raw}` is not encoded: use it for an id that is a path (`/series/{id:raw}`). Form, json and header values are not percent-encoded by the engine (a form is encoded when it is sent).

`{? ... ?}` is a **group**: it vanishes, with everything inside, when any hole inside it has no value. This is how an optional part is written:

```text
{base}/series?offset={offset}{?&q={term}?}{?&genre={genre}?}
```

With no term and no genre, the url is `.../series?offset=0`.

**A bare hole with no value fails the whole request**, with: `this source cannot answer that: its definition asks for a value the app had none of ... That is a mistake in the source's definition`. The most common cause is a bare `{term}`. A search can run with no term (the home screen's genre chips do that), so always write `{? ... {term} ... ?}`. The same goes for `{genre}` and every filter.

| Hole | Where it has a value | What it is |
| --- | --- | --- |
| `{base}` | everywhere | The host being asked (`https://www.example.com`, no trailing slash). |
| `{page}` | lists, and the chapter list when `repeat` is set | The page number, starting at `1`. In a chapter list with `repeat` it is `offset / size + 1`. |
| `{page0}` | lists | `{page}` minus one, for a site that counts from `0`. |
| `{offset}` | lists, chapters | In a list: `(page - 1) * page_size`. In a chapter list with `repeat`: the number of chapters already asked for. |
| `{term}` | `search` only | What the person typed. |
| `{id}` | detail, chapters, pages | In `detail` and `chapters`: the series id (a card's `id`). In `pages`: the **chapter** id. |
| `{series}` | chapters, pages | The series id. In `pages` it is the series, while `{id}` is the chapter. |
| a filter's id | `search` only | The person's choice, or the filter's `default`. Nothing if neither. |
| a setting's id | every section | The person's choice, or the setting's `default`. |
| a session value (`{access}`, `{refresh}`, `{user}`, ...) | every section and `image_headers`, while signed in | What signing in gave. See [auth](#auth-signing-in). |
| an `auth` field's id (`{email}`, `{password}`) | the `auth.login` request only | What the person typed. |
| a var's name | the section that reads it, and the sections after a `prepare` that set it | A value read from an earlier answer. See [prepare and vars](#prepare-and-vars). |

A var, a filter, a setting and a session value share one namespace after `page`, `page0`, `offset`, `term`, `id` and `series`. A var wins over a filter, a filter over a setting, and a setting over a session value. Do not reuse a name.

In an expression's `template` step there are two more: `{value}` is the node being read, and `{^.path}` is a value in the **row the expression started from** (JSON only). See `expressions.md`.

## Lists: popular, latest, search

```json
"popular": {
  "request": { "url": "{base}/series?page={page}" },
  "format": "html",
  "rows": "div.card",
  "card": {
    "id":       [{ "css": "a" }, { "attr": "href" }, { "regex": "/series/([^/]+)/?$" }],
    "title":    "h3",
    "cover":    [{ "css": "img" }, { "attr": "data-src|src" }, "abs"],
    "chapters": ".count"
  },
  "next": "a[rel=\"next\"]"
}
```

| Field | Needed | Meaning |
| --- | --- | --- |
| `request` | yes | See [requests](#requests). |
| `format` | no | `html` (default) or `json`. |
| `rows` | yes | The nodes that are one card each. HTML: a CSS selector. JSON: a path (`"data"`, or `[{"path":"*"}]` for the whole answer). |
| `card.id` | yes | The series id: what `{id}` will be in `detail` and `chapters`. It is any text. Often a slug cut out of a link with `regex`. |
| `card.title` | yes | The title. |
| `card.cover` | no | The cover image. Made absolute against the host, and a `data:` address is dropped. |
| `card.chapters` | no | How many chapters, or the newest chapter's number (`"Ch. 120"`, `"120 chapters"`). The **first number in the text** is taken and the card shows "120 chapters". No number shows nothing. |
| `next` | no | An expression over the whole answer. A next page follows when it gives **something**. |
| `total` | no | An expression over the whole answer that gives how many titles the source has. A next page follows when `page * page_size < total`. |
| `prepare`, `vars` | no | See [prepare and vars](#prepare-and-vars). |

Rows that give no `id` or no `title` are **skipped**. A repeated `id` is kept once. Order is the answer's order.

**How the app knows another page follows**, in this order:

1. If `total` is set, `page * page_size < total`. `total` must count what a page holds, so `page_size` must be what the site really returns per page. A site that hands back 25 rows a page cannot be described by `total` unless `page_size` is `25`.
2. Else if `next` is set, a next page follows when `next` gives something. `"next": "a.nextpostslink"` reads the site's own next link.
3. Else a next page follows **whenever the answer had rows**. Cards dropped for having no id do not end the list. This is a fine default for a site that returns an empty page at the end.

Do not build `next` out of the request's own holes (`{"template": "{page}"}`): those are always set, so it would say a page follows for ever.

`latest` has the same shape, and it has no `{term}`. `search` is where `{term}` and the filters go. A source needs at least one of the three. A source with only `search` is valid (`flamecomics` is one): the engine reports which of the three it has, so the app knows what to offer.

## detail

```json
"detail": {
  "request": { "url": "{base}/series/{id}/" },
  "title": "h1",
  "cover": [{ "css": ".cover img" }, { "attr": "data-src|src" }, "abs"],
  "description": ".summary",
  "authors": ".author a",
  "tags": ".genres a",
  "status": [{ "css": ".status" }, "text", { "map": [["ongoing", "ongoing"]] }, { "default": "unknown" }]
}
```

| Field | Needed | Gives |
| --- | --- | --- |
| `title` | yes | A text. If it gives nothing the call fails: `the page has no title: has the site changed?` |
| `cover` | no | A text, made absolute. |
| `description` | no | A text. Blocks (paragraphs, `<br>`, list items) come out on their own lines. If the field holds markup in JSON, add `plain_text`. |
| `authors` | no | **Every** text the expression gives, as a list. Authors and artists can both go here. |
| `tags` | no | Every text, as a list. |
| `status` | no | One text. It is read as a word: it counts as `hiatus` if it contains "hiatus"; `cancelled` if it contains "cancel", "dropped" or "discontinued"; `completed` if it contains "complete", "finished" or "ended"; `ongoing` if it contains "ongoing", "publishing", "updating" or "releasing". Anything else, and a missing field, is `unknown`. The checks run in that order. |

Because the engine does that reading, you rarely need a `map` for English status words. A `map` is for another language, or for words the list above does not cover ("on hold" → `hiatus`). **Map to one of the four words**: any other value, even `"upcoming"`, reads as `unknown`.

A site that never fills a field (Status and Author are `<i></i>` or `n/a` on every page) gives `unknown` and `[]`. That is the truth. Do not invent a value. Keep the `default` or `non_empty` guard.

`detail` has no `{term}`. Its holes are `{id}`, settings and vars.

## chapters

```json
"chapters": {
  "request": { "url": "{base}/series/{id}/" },
  "rows": "ul.chapters li",
  "chapter": {
    "id":      [{ "css": "a" }, { "attr": "href" }, { "regex": "/series/[^/]+/([^/]+)/?$" }],
    "number":  "span.num",
    "title":   "a",
    "date":    [{ "css": ".date" }, "text", { "date": ["MMMM d, yyyy", "relative"] }],
    "scanlator": ".group",
    "locked": "is_premium"
  },
  "order": "newest-first",
  "repeat": { "size": 100, "total": "meta.total" }
}
```

| Field | Needed | Meaning |
| --- | --- | --- |
| `rows` | yes | One node per chapter. |
| `chapter.id` | yes | What `{id}` will be in `pages`. A row that gives no id is skipped, and a repeated id is kept once. |
| `chapter.number` | no | A number. If the text is not a plain number, the engine looks for one after "chapter", "ch.", "episode", "ep." or "#", then takes the first number. |
| `chapter.title` | no | The title. If there is no `number`, the number is read from the title the same way. |
| `chapter.date` | no | **Milliseconds since 1970 as text.** Use the `date` step to make that. A text that is not a whole number is ignored. |
| `chapter.scanlator` | no | The group. |
| `chapter.locked` | no | Whether the chapter needs an account (paid, early access). Any text counts as yes except `false`, `0`, `no` and `null`, and nothing counts as no. So a JSON `true`, `"yes"` or `1` locks it and `false` does not. While the person is signed out the apps show a lock in place of the read mark. A signed-in person sees it as any chapter (the site decides what an account may read). See `locked_label` and `locked_action` below. For a date such as `early_access_until`, end the expression with `{"date": ["iso"]}` and `"in_future"`: the chapter is locked only while the date is ahead. |
| `locked_label` | no | The source's own word for a locked chapter (`"Members only"`, `"Early access"`). It replaces the small line above the chapter's title while the chapter is locked. Without it the line says what it always says and the lock mark alone tells the person. |
| `locked_action` | no | What a tap on a locked chapter does while signed out: `sign_in` (default: ask them to sign in first when the source has `auth`, then open the chapter) or `none` (open it as any chapter; the lock is only shown). |
| `order` | no | `newest-first` (default) or `oldest-first`. The engine returns newest first whatever the site does, so say `oldest-first` when the site lists oldest first and the engine reverses it. |
| `repeat` | no | For a chapter list that comes in several requests. |

The chapter list has `{id}` **and** `{series}`, both the series id. Its request is often the same as `detail` (`{base}/series/{id}/`), because many sites put the chapters in the series page. **The chapters must come in the answer.** If the page has `0` chapter rows because a script fills the list after load, the source cannot work (see `from-a-website.md`).

### repeat

`"repeat": { "size": 500, "total": "total" }` asks again with `{offset}` raised by `size`, until:

- `total` (an expression over each answer) says there are no more: `offset >= total`, or
- a page has **no rows**, or
- a page brings **no chapter not already seen**.

`{page}` is set as well, raised by one each time (`offset / size + 1`), for a site that numbers its pages (`?t={page}`) instead of counting rows. Put `{page}` or `{offset}` in the url, or every request is the same one.

- `total` counts **chapters**. A site that only says how many **pages** it has (`"total_pages": 6`) must leave `total` out. Asking then stops when a page brings nothing new. A screenshot of the same list repeated on every page makes that the safer stop anyway.
- **`size` must equal what the site really sends per request.** `{offset}` goes up by `size`, so a `size` of `500` against a site that sends `100` skips rows.
- `size` is from `1` to `1000`.
- One chapter list may take at most **60 requests**. A source with more than `60 * size` chapters in all must ask for a bigger `size`. Running out is **reported as an error**, never returned as a short list that looks complete.
- With no `total`, there is always one more request than there are pages of chapters: the last one comes back empty and ends the loop. A recorded fixture must hold that empty answer. The `json-api` worked example shows it (`chapters-2.json`).

## pages

```json
"pages": {
  "request": { "url": "{base}/series/{series}/{id}/" },
  "images": [{ "css": "div.reader img" }, { "attr": "data-src|data-lazy-src|src" }],
  "reading": "longstrip",
  "image_headers": { "referer": "" }
}
```

| Field | Needed | Meaning |
| --- | --- | --- |
| `images` | yes | Every text the expression gives is one page, in order. Each is made absolute against the host. A `data:` address is dropped. No page at all fails the call with `the chapter has no pages: has the site changed?` |
| `reading` | no | `longstrip` (webtoon, scroll), `paged` (left to right) or `paged_rtl` (right to left, manga). Anything else is refused. Left out, the app decides. Manhwa and webtoons are `longstrip`; Japanese manga is `paged_rtl`. |
| `image_headers` | no | Headers for every image request. A `referer` of the host is sent when none is given. **A header whose value is empty is left out**, so `"referer": ""` removes it (some image servers refuse a referer from another site). Values may hold holes. |

In `pages`, `{id}` is the **chapter** and `{series}` is the series.

## prepare and vars

Some sites need one request before the real one, or tell you in the answer where the next request goes.

- **`vars`**, on any section: a map of name to expression. After the section's request is answered, each expression is read from the answer and becomes a hole `{name}` in that section's expressions. Use it for the image server an answer names, or a nonce that sits in the page you are already reading. Names are lower case letters, digits, dashes and underscores.
- **`prepare`**, on any section: a list of requests made **first**. Each has a `request`, a `format` and its own `vars`. What they read becomes holes for the later requests (the section's own request, and the next `prepare` steps).

```json
"chapters": {
  "request": { "method": "POST", "url": "{base}/wp-admin/admin-ajax.php",
               "form": { "action": "load_chapters", "series": "{id}", "nonce": "{nonce}" } },
  "prepare": [
    { "request": { "url": "{base}/title/{id}/" },
      "vars": { "nonce": [{ "css": "script#page-data" }, "html", { "regex": "nonce\"\\s*:\\s*\"([a-f0-9]+)\"" }] } }
  ],
  "rows": "li.chapter", "chapter": { "id": "a@href" }
}
```

A `prepare` request costs a real request every time the section runs, and counts against the rate limit. For a paged chapter list the `prepare` runs **once**, before the loop.

## filters

A filter narrows a search. Its value fills the hole named by its `id` in the **`search`** request only.

```json
"filters": [
  { "id": "genre", "name": "Genre", "kind": "select", "default": "action",
    "options": [ { "value": "action", "name": "Action" }, { "value": "romance", "name": "Romance" } ] },
  { "id": "author", "name": "Author", "kind": "text" }
]
```

| Field | Meaning |
| --- | --- |
| `id` | Lower case letters, digits, dashes, underscores. It is the hole's name. |
| `name` | What the person sees. |
| `kind` | `select` (one of the options) or `text` (free text). |
| `options` | For `select`: `value` is what fills the hole, `name` is what is shown. A `select` needs at least one. A `text` filter has none. |
| `default` | Used when the person has not chosen: a select's option value (must be one of the options), or a text. |

Always write a filter's hole inside a group: `{?&genre={genre}?}`. A filter with no choice and no default has no value, and a bare hole would fail the request.

Prove a filter works against the live site before you ship it. Ask for two different values and check that the lists differ. A site can accept a parameter and ignore it, and a filter that does nothing is worse than none.

Filters are **parsed and passed to the request**. There is no filter screen yet; the home screen's genre chips search with only a filter set.

## settings

A setting is a choice the person makes **for this source**: a language, a content rating, a server. It appears as a picker on the source's page. Its value fills the hole named by its `id` in **every** section.

```json
"settings": [
  { "id": "lang", "name": "Language", "default": "en",
    "options": [ { "value": "en", "name": "English" }, { "value": "fr", "name": "French" } ] }
]
```

- `default` must be one of the options' `value`s, or the definition is refused.
- `{rating:raw}` is not percent-encoded, for an option whose value is a piece of query (`safe&contentRating[]=suggestive`).
- The difference from a filter: a setting is remembered per source and applies everywhere (lists, detail, chapters, pages). A filter is chosen per search.

## auth: signing in

For a site with free titles and paid or private ones. The person types an account in the app, the engine signs in, and the **session** (what the site answers) goes on every later request. **Nothing in the definition is a secret**: it says how the sign-in request looks and where the session is in the answer. The app keeps only the session, never the password.

```json
"auth": {
  "fields": [
    { "id": "email",    "name": "Email" },
    { "id": "password", "name": "Password", "secret": true }
  ],
  "login": {
    "request": { "method": "POST", "url": "{base}/auth/login",
                 "json": { "email": "{email}", "password": "{password}" } },
    "format": "json",
    "vars": { "access": "data.access_token", "refresh": "data.refresh_token", "user": "data.user.display_name" }
  },
  "refresh": {
    "request": { "method": "POST", "url": "{base}/auth/refresh", "json": { "refresh_token": "{refresh}" } },
    "format": "json",
    "vars": { "access": "data.access_token", "refresh": "data.refresh_token" }
  },
  "logout": { "method": "POST", "url": "{base}/auth/logout", "json": { "refresh_token": "{refresh}" } },
  "headers": { "authorization": "Bearer {access}" }
}
```

| Field | Needed | Meaning |
| --- | --- | --- |
| `fields` | yes | What the person types. `id` is lower case letters, digits, dashes, underscores (not `base`, `page`, `page0`, `offset`, `term`, `id`, `series`), unique. `name` is the label. `secret: true` hides it as it is typed. At least one. |
| `login` | no | The request that signs in: a `request`, a `format`, and `vars` (required, not empty). The `vars` read the **session** from the answer. The fields are holes in this request only (`{email}`). **Without `login`, what the person typed is the session** (a token pasted in: one field `access`, and `headers` that use it). |
| `refresh` | no | Asked **once**, when a request is refused with `401` while signed in, then the refused request is asked again. Its `vars` replace the session values they name and keep the rest. Needs `login`. A refresh that fails ends the session: "sign in again". |
| `logout` | no | A request made when the person signs out, best effort. The session is forgotten either way. |
| `headers` | no | Added to **every request to `base_url`** while signed in. Holes are session values. While signed out the header is left off. |

Rules:

- **The session is the `vars` of the login answer.** Any names. `access`, `refresh` and `user` are the usual ones. `user` is what the app shows as "signed in as".
- **Session values are holes everywhere**: in urls, forms, json bodies, headers, `image_headers` (for a CDN that checks a token) and templates. A hole with no value (signed out) fails a request that needs it outside a `{? ?}` group. Wrap an optional use in a group.
- **The session goes only to `base_url`.** The login, refresh and logout requests, and the `headers`, are never sent to a mirror. A mirror that has to answer a signed-in request answers it anonymously. Auth requests never go to another host (every url starts with `{base}`, as everywhere).
- **A 401 on a signed-in request** (and only 401) triggers one refresh when `refresh` is defined. Two requests refused at once refresh once. A site that answers `403`, or a check page, is not retried.
- **A refused sign-in** (400, 401, 403, 404 or 422) is reported as "`<source>` did not accept that sign-in: is the account right?". The password is never in an error.
- **An answer with none of the `vars`** is an error ("holds no session"): a wrong account that the site answers with 200, or a changed site.
- **Sign-in is per source** and the session is the app's to keep: the engine hands every change to the app's `SessionKeeper` (`save`) and asks it for the saved one when the source loads (`load`). The apps keep it in the Keychain or the Keystore, never in the database.
- **A source with `auth` still works signed out.** The free titles load. Only what needs the session fails.

Only **password to token** and **a pasted token** are supported. Not supported: a sign-in that needs a web page (OAuth with a redirect, "Sign in with Google"), a captcha or Turnstile token, a code sent by email or text, a signed request. See `engine.md`.

Test with made-up accounts only: `fixtures.json` has the calls `sign_in` (with `fields`, fake values) and `sign_out`. Their expected answers are the user name (`{"user": "Reader"}`) and `{"signed_in": false}`. **Never record a real sign-in**: `record` would save the real tokens into the fixtures. `templates/worked-examples/login/` is the pattern.

## Themes and extends

Many sites run the same CMS (Madara, MangaStream). A **theme** is a base definition and a site is a few lines that extend it.

A theme is `themes/<id>.json` with `"theme": true` and a `"version"`. It is a partial definition: it need not have an `id`, `name` or `base_url`.

A source says `"extends": "<theme id>"` and gives its own fields. The rule for merging:

- **Objects merge key by key**, so a source can change one selector inside `chapters.chapter` and keep the rest.
- **Anything else is replaced**: a list, a text, a number. A source that gives `lang` replaces the theme's `lang`. A source that gives `pages.images` replaces the whole expression, not a step of it.
- A theme may extend another theme. A circle is refused.
- The source's own `id`, `name` and `version` always win.

```json
{ "extends": "madara", "id": "my-site", "name": "My Site", "version": 1, "lang": ["en"], "base_url": "https://www.example.com" }
```

What the app stores when a source that extends is installed by hand (Add a source): the theme is **merged in at that moment** and the stored copy stands alone, with `extends` and `theme` removed. It keeps working without the theme. A source installed from a repository **follows the theme's updates**: the index lists the theme in the source's `requires`, and installs it with the source.

A source that extends a theme that is not installed fails with: `the definition extends a theme called madara, which is not installed: add the repository that has it, then paste this again (a source does not bring its own theme)`.

The checker scripts pass this repo's `themes/` folder, so `extends` just works there.

When you change a theme, **raise its `version`** and re-run the fixtures of **every source that extends it** (`scripts/check-all.sh` does).

## The index and the repository files

```text
repo.json              {"name": "..."}: the repository's name (required, at most 80 characters)
index.json             the index (generated by scripts/index.sh)
index.json.sig         optional: a signature over index.json
themes/<id>.json       a theme ("theme": true and a "version")
sources/<id>.json      a source (the file is named after its id)
examples/<id>.json     sources used only to test the engine: not in the index
fixtures/<id>/         recorded pages and fixtures.json for a source or an example
voices/<id>.json       a reading-aloud voice model: a different kind of file, see below
```

```json
{
  "schema": 1,
  "name": "Akidev sources",
  "key": "<public key hex, only if signed>",
  "sources": [
    { "id": "example", "name": "Example", "version": 1, "path": "sources/example.json",
      "sha256": "...", "lang": ["en"], "nsfw": false, "min_app": "0.1.25", "requires": ["madara"] }
  ],
  "themes": [ { "id": "madara", "version": 1, "path": "themes/madara.json", "sha256": "..." } ],
  "voices": []
}
```

You do **not write the index**. `scripts/index.sh` does, from the files: the id, name, version, `lang`, `nsfw` and `min_app` of a source, the id and version of a theme, every SHA-256, and `requires` from `extends`. The checks (made when an app adds the repository, and by CI):

- `schema` is `1`. The name is not empty and at most 80 characters.
- At most 500 sources, 100 themes and 200 voices.
- Ids are lower case letters, digits and dashes, at most 64 characters, and not listed twice.
- A `path` stays inside the repository: relative, no `..`, no `://`, no backslash.
- A `sha256` is 64 hex digits, and the file's content must hash to it.
- Every `requires` names a theme the index lists.
- A file may be at most 2 MB. The index may be at most 1 MB.
- A source's file must be named `<id>.json` after its id.

`voices/` holds reading-aloud models and has its own format (`desktop/manga/src/voice.rs`). This repository has none. Do not put a voice here unless that is the task.

## Limits in one table

| What | Limit |
| --- | --- |
| `schema` | `1` |
| `rate_per_second` | above `0`, at most `20` |
| `page_size` | `1` to `500` |
| `chapters.repeat.size` | `1` to `1000` |
| Requests for one chapter list | `60` |
| An answer's body | 8 MB |
| A request | 10 s to connect, 30 s in all |
| A source or theme file | 2 MB |
| `index.json` | 1 MB |
| Sources in an index | 500 |
| Themes in an index | 100 |
| A repository name | 80 characters |
| An id (source, theme) | lower case letters, digits, dashes; at most 64 |
| A filter or setting id | lower case letters, digits, dashes, underscores; at most 64 |
| A var name | lower case letters, digits, dashes, underscores |
| An `auth` field id | lower case letters, digits, dashes, underscores |

## What the app gets back

For the cases where you need to know what the final shape is:

| Call | Result |
| --- | --- |
| `popular`, `latest`, `search` | `{ "items": [ { "id", "title", "cover"?, "chapters"? } ], "has_next": true/false }` |
| `details` | `{ "title", "cover"?, "description"?, "authors": [], "tags": [], "status": "ongoing" \| "completed" \| "hiatus" \| "cancelled" \| "unknown" }` |
| `chapters` | `[ { "id", "number"?, "title"?, "date_ms"?, "scanlator"?, "locked"? } ]`, newest first (`locked` is left out when false) |
| `pages` | `{ "images": [], "reading": "long_strip" \| "paged" \| "paged_rtl" \| "unknown", "headers": {} }` |

`headers` in a page list is what the app sends with each image: a `referer` of the host, plus your `image_headers`. These are exactly the shapes `fixtures.json` expects.
