# From a website to a finished source

The main job. The user gives you a manga or comics site, an API, or an idea. You hand back a source that the real engine accepts, with fixtures recorded from the live site, and an honest list of what you could and could not check.

Work in order. Do not write JSON before step 4.

## Contents

0. [Before you start](#0-before-you-start)
1. [The gate: may this be written at all?](#1-the-gate-may-this-be-written-at-all)
2. [Probe the site](#2-probe-the-site)
3. [The three-things test](#3-the-three-things-test)
4. [Pick the template](#4-pick-the-template)
5. [Write the six sections](#5-write-the-six-sections)
6. [Record, bless, read](#6-record-bless-read)
7. [Try the live site](#7-try-the-live-site)
8. [Deliver](#8-deliver)
9. [A short example, start to end](#9-a-short-example-start-to-end)
10. [What to say when you stop](#10-what-to-say-when-you-stop)

## 0. Before you start

Check the tools and the layout once:

```bash
ls ../akidev/desktop/manga/src/source.rs      # the code repo, next to this one (or set CODE_REPO)
cargo --version                               # a Rust toolchain: the first script run builds the engine
jq --version curl --version
```

Ask the user for anything you cannot find yourself:

- the site (the home page, and one series you know has many chapters),
- whether it is adult (`nsfw`),
- whether the user owns the site or has the right to read it this way (the gate, below).

## 1. The gate: may this be written at all?

A source is a request to a site to read its work. Akidev's rule for this repository: **only sources that are legal to read.** A public API that welcomes third-party readers, or work released under an open licence. Nothing that republishes copyrighted chapters without the publisher's leave.

Ask yourself, and say what you decided:

1. **Is it plainly a pirate aggregator?** Many sites that host scanlations of licensed series are. If the site is that, say so, and do not write it without the user's clear instruction. This repository's README sets the rule (only sources that are legal to read), and the code repo's port plan (`pipeline/MANGA_SOURCES_PORT_PLAN.md`, sections 6 and 7) lists "aggregators in the default repository, or a second one the person adds on purpose" as a decision for the owner. The sources here today are `asurascans` (its own JSON API), `dynastyscans`, `flamecomics` and `arenascans`. Do not treat their presence as a ruling on a new site.
2. **Does it need a login for what the user wants?** Free titles that load without an account are fine: write the source for those. If the paid or private titles are the point, a plain sign-in (a posted email and password that answers a token, or a pasted token) is supported: see recipe 16 and `auth` in `format.md`. A sign-in that needs a captcha, a redirect ("Sign in with Google"), a code by email, or a cookie you would have to copy is **not** supported: stop and say so. A paywall you would have to get around: stop. **Never enter or ask for a real account yourself.** The person signs in in the app, and a test account goes in through the environment (`AKI_AUTH_<FIELD>`), run by the user.
3. **Does it answer with a check page** (`Just a moment...`, a captcha, `cf-chl`)? Stop. The app has no web view and no way past a check. It fails with `wants a check before it answers`, and the app says the site is not supported from here. **Never look for a way around.** Do not suggest an unofficial relay, a clearance cookie or a header trick.
4. **Does the site's own policy or `robots.txt` forbid it?** Read `/robots.txt` and the terms if they exist. A site that says no automated reading means no.
5. **Is it adult?** Set `"nsfw": true`, and say so to the user.

If the answer to 2, 3 or 4 is a problem, finish here with a clear message (section 10). If it is a grey area under 1, ask the user.

## 2. Probe the site

`scripts/probe.sh` looks at pages the way the app does (the same phone user agent) and says what kind of site it is:

```bash
scripts/probe.sh https://www.example.com/ https://www.example.com/series/some-series/ https://www.example.com/series/some-series/chapter-1/
```

Probe **three** pages: the home or list page, one series page, one chapter page. For each it prints the status, the content type, whether it is JSON, the title, and which markers it found. It saves each answer to `/tmp/manga-probe/` so you can read the markup.

Then look at the saved files yourself. `grep`, `jq` and a text editor are enough:

```bash
jq . /tmp/manga-probe/<file> | head -60                      # a JSON answer
grep -o '<a[^>]*href="[^"]*"' /tmp/manga-probe/<file> | head  # the links
grep -n 'data-src\|__NEXT_DATA__\|ts_reader\|nonce' /tmp/manga-probe/<file> | head
```

What each marker means:

| You see | It is | Go to |
| --- | --- | --- |
| The status is `200` and it is JSON | An API | recipe 1 |
| `A CHECK PAGE` marker, or a `403`/`503` with "Just a moment" | Blocked | **stop** (gate, step 3) |
| `Next.js` marker (`__NEXT_DATA__`) | Data in the page | recipe 4 |
| `MangaStream reader` / `div.bsx` markers | MangaStream | recipe 3 |
| `Madara` marker (`wp-manga`) | Madara | recipe 5 |
| `chapter-protector` | Encrypted pages | recipe 9 |
| None, and plenty of `<img>` | Plain HTML | recipe 2 |
| `<img>` count is `0` on a chapter page | Pages come from a script or an API | look for the script blob, or the API (see below) |
| `noscript` marker | Images in `<noscript>` are invisible | find the script blob |

Find the data when the page has none:

- **An API:** view the page's own requests. Fetch the page and `grep` for `api.`, `/api/`, `graphql`, `wp-json`, `_next/data`. A WordPress site has `/wp-json/wp/v2/` too. Try the address with `scripts/probe.sh`.
- **A script blob:** `grep -n '<script' file`, then read the large ones. Look for `ts_reader.run`, `__NEXT_DATA__`, `chapter_data`, `window.__`, `JSON.parse`.
- **The search request:** type a search in a browser, read the address, or look at the search form's `action` and field names in the HTML. Probe it with a term.
- **Pagination:** find the next link, and ask for page 2. **Confirm page 2 differs from page 1.**
- **Filters:** the site's own filter form (field names and option values). Ask with two different values.

Write down, from the live pages, for each of the six questions: the url, the format, the selector or path, and one real sample value. Do not guess a selector you have not seen in a real answer.

## 3. The three-things test

A source is worth writing only when the site is:

1. **Reachable** from a plain network client (no check, no login), and not parked or dead (a parked domain answers a "for sale" page or a few hundred bytes),
2. **gives its chapters in the answer**: the chapter list is in the HTML or JSON that the request returns,
3. **gives its pages in the answer**: the chapter's image addresses are in the HTML or JSON, or in a payload the engine can decrypt.

Most sites in the ecosystem fail at least one. The recorded reasons:

- **Guya family** (`guya.cubari.moe`, `hachirumi.com`, ...): the reader serves `<img />` with no `src` and fills the pages from a script. No browser, no pages.
- **A detail page with `0` chapter rows** where a script fills the list after load, and no POST or API either.
- **A chapter page with no image addresses** in the HTML (a script loads them): `manga1st.online` had 295 chapter rows and zero image addresses.
- **A site that changed**: `toonily.com` stopped being Madara and serves `/serie/<slug>/`, so the selectors of an extension written for it are stale.
- **Metadata that is stale**: of 96 base addresses in the Paperback extension repositories, most were parked or dead. Classify from the live page, never from an extension's metadata or its description.

If it fails: **stop and say which of the three it fails**, with the evidence (the probe's output, a `grep` that found nothing). Do not write a source that "will work if...".

## 4. Pick the template

| The site is | Copy |
| --- | --- |
| a JSON API | `templates/source-json-api.json` |
| server-rendered HTML | `templates/source-html-site.json` |
| WordPress with the `mangareader` theme | `templates/source-mangastream.json` |
| Next.js | `templates/source-next-data.json` |
| Madara | `templates/source-extends-madara.json` (needs `themes/madara.json`) |
| any of the above, with a nonce or token step | add `prepare` from `templates/source-prepare-nonce.json` |
| any of the above, with a paged chapter list | add `repeat` from `templates/source-paged-chapters.json` |
| encrypted pages | `templates/source-encrypted-pages.json` |
| a POST or GraphQL API | `templates/source-post-json.json` |
| free titles plus paid ones behind a plain sign-in | `templates/source-with-login.json` (recipe 16) |
| with a language, rating or genre choice | add from `templates/source-settings-filters.json` |
| two or more sites on one CMS | `templates/theme.json`, then recipe 15 |

```bash
cp .claude/skills/manga-sources/templates/source-json-api.json sources/<id>.json
```

Then change, in this order: `id`, `name`, `base_url`, `lang`, `nsfw`, `rate_per_second`, and then the six sections.

- The id: lower case letters, digits and dashes. Short and the site's name (`mangadex`, `flamecomics`). The file is `sources/<id>.json`.
- `rate_per_second`: `1` for a small site or an API with a limit, `2` for a normal one. Never above what the site tolerates. A rate is a courtesy, and it is the engine's only protection for the site.
- `version`: `1` for a new source.

## 5. Write the six sections

One at a time, **checking after each**:

```bash
scripts/check.sh sources/<id>.json
```

That runs no network and no fixtures. It catches a url that does not start with `{base}`, a bad CSS selector, a bad regex, a date format with no year, a missing filter option, a setting whose default is not an option, a bad `reading`, and more (the list is `validate` in `source.rs`).

Order of work, and what to look at in the saved real answers:

**popular / latest / search.**
- `rows`: count them against the page: the page shows 20 cards, `rows` must find 20.
- `card.id`: the slug or id that the **detail** url takes. Test the regex on three different links.
- `card.title`, `card.cover` (check it is the cover and not a lazy placeholder), `card.chapters` if the card shows a count.
- paging: `next`, `total` or nothing (see `format.md`). Page 2 must differ.
- `search`: the term in a group (`{?...{term}...?}`), the filters in groups, an empty term must still work.

**detail.** `title` (must not be empty), `cover`, `description`, `authors`, `tags`, `status`. A field the site does not fill stays empty. Do not invent.

**chapters.** `rows`, `chapter.id` (what `pages` takes), `number`, `title`, `date`, `order`. Count the rows against the site's number of chapters. If the list comes in pieces, add `repeat`.

**pages.** `images`, `reading`, and `image_headers` if the CDN needs a different referer or none.

When a field comes out wrong, `debugging.md` has the error messages and the usual cause.

Keep the definition **small and obvious**. Short selectors, no step that does nothing, no fallback for a case you did not see. A `coalesce` is for a difference you found in real pages (two cover attributes), not for hope.

## 6. Record, bless, read

Record the live answers for the calls you will test. Pick **real** ids from earlier calls:

```bash
scripts/run-live.sh sources/<id>.json popular                    # note a series id from the output
scripts/run-live.sh sources/<id>.json chapters <series-id>       # note a chapter id
scripts/record.sh sources/<id>.json popular latest search=<term> details=<series-id> chapters=<series-id> pages=<series-id>,<chapter-id>
```

`record.sh` writes `fixtures/<id>/` (the pages as `r1.html`, `r2.json`, ...) and a `fixtures.json` that lists the calls. It prints `SKIPPED <call>: <why>` for a call that failed. **A skipped call is not tested.**

Record from a clean network. A filtered or proxied network records its block page, and the fixtures then prove nothing.

Then bless:

```bash
scripts/check.sh sources/<id>.json fixtures/<id> --bless
```

And **read what it wrote**. Open `fixtures/<id>/fixtures.json` and look at every `expect`:

- the number of cards, a few titles and ids that you can see on the real page,
- the cover addresses are absolute and are images,
- `has_next` is what the page says,
- the details: title, authors, tags, status are what the page shows,
- the chapters: the count, the order (newest first), the numbers, the dates (not `null` when the page shows a date),
- the pages: the count, the order, addresses are absolute, `reading` is right.

A `null`, an empty list, a count that is too small or a date that is `null` is a bug that bless saved. `arenascans` shipped for weeks with `"date_ms": null` on every chapter because a field was spelled `uploaded` instead of `date`. An unknown key is **silently ignored**, so a misspelled field reads as "the site has none". When a field you wrote is empty, check its spelling first.

Prefer **two series** in the fixtures: one small, and one with many chapters (a paged list, a long id). Prefer a chapter from the **middle** of the list.

Then run the plain check:

```bash
scripts/check.sh sources/<id>.json fixtures/<id>
```

## 7. Try the live site

Fixtures freeze one day. Run the real thing, and look:

```bash
scripts/run-live.sh sources/<id>.json search "<a real title>"
scripts/run-live.sh sources/<id>.json details <id>
scripts/run-live.sh sources/<id>.json chapters <id>
scripts/run-live.sh sources/<id>.json pages <series> <chapter>
```

And check the images themselves, because a page address that does not load is a failure the engine cannot see:

```bash
curl -sI -A 'Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X)' -e 'https://www.example.com/' '<first image url>' | head -5
```

Expect `200` and an `image/*` content type. A `403` means the CDN wants a different referer: set `image_headers`. Test **without** the referer as well, if the image works that way, `"referer": ""`.

Things to verify by hand, each one has failed in a real source:

- page 2 of a list differs from page 1,
- a filter changes the list,
- a search with no term and one filter works,
- the chapter count matches the site (a paged list that stops early),
- a chapter whose id has odd characters,
- a series with **no** chapters or no cover does not crash it (the fields are optional, the call still gives an answer).

If you cannot test something (no network, a site that is down), **say so**. Do not mark it as tested.

## 8. Deliver

```bash
scripts/index.sh            # rewrites index.json, with the new file's hash
scripts/check-all.sh        # what CI does: all fixtures, then the index freshness
git status                  # sources/<id>.json, fixtures/<id>/, index.json, (themes/...)
```

Checklist:

- [ ] `version` is higher than before (`1` for new).
- [ ] `index.json` was rewritten **after the last edit** of any source or theme.
- [ ] `scripts/check-all.sh` exits `0`.
- [ ] `fixtures/<id>/fixtures.json` was read, not just blessed.
- [ ] `nsfw` is honest. `lang` is right.
- [ ] Nothing in the file is a secret, a cookie or a personal address.
- [ ] No stray keys: JSON has no comments, and an unknown key is silently ignored, so a misspelled field is invisible.
- [ ] `README.md`'s "What is in it" table has the new source.

If the user asked you to commit, do it (rule 10 in `SKILL.md`: no mention of AI). Pushing is the user's call. After a push, apps that follow the repository see the new version at their next start.

## 9. A short example, start to end

The user says: *"add example-reader.com, it's a Next.js site."* The site is a reader that publishes its own work under an open licence.

```bash
scripts/probe.sh https://example-reader.com/ https://example-reader.com/series/123 https://example-reader.com/series/123/abc
#   -> 200, Next.js marker on all three: recipe 4. No check page. Chapters and pages are in __NEXT_DATA__: test 3 passes.
cp .claude/skills/manga-sources/templates/source-next-data.json sources/example-reader.json
#   edit: id, name, base_url, then the JSON paths found in /tmp/manga-probe/... (props.pageProps.series.title, ...)
scripts/check.sh sources/example-reader.json                    # no errors
scripts/run-live.sh sources/example-reader.json search "hero"   # real cards
scripts/record.sh sources/example-reader.json search=hero details=123 chapters=123 pages=123,abc
scripts/check.sh sources/example-reader.json fixtures/example-reader --bless
#   read the expects: 12 cards, authors filled, 40 chapters, dates not null, 18 images, long_strip
scripts/index.sh && scripts/check-all.sh
```

## 10. What to say when you stop

When you cannot or should not write the source, say it plainly and give the evidence:

> I did not write a source for example.com. It answers every request with a Cloudflare check page ("Just a moment...", status 403, `cf-chl` in the body). The app has no way past a check, so every call would fail with "wants a check before it answers". Nothing about the definition could change that. If the site has an official API or an RSS feed, send it and I will look at that.

> The chapters are not in the series page: it has no chapter rows, and the list is filled by a script after the page loads (the only request I found, `/ajax/chapters`, answers `404`). Without the chapters a source cannot work.

When you wrote it, close with three short lists: **built** (what it does), **tested** (each call, against fixtures and the live site), **not tested or not possible** (a filter you could not prove, page 2 not recorded, a field the site never fills).
