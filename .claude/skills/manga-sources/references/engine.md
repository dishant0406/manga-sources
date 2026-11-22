# The engine: what the app does with a definition, and what it cannot do

The engine is the `akidev-manga` crate in the code repo (`desktop/manga/`). The apps (iOS SwiftUI, Android) call it through a facade. A definition is **data**: the engine reads it, makes the requests it says, and reads the answers the way it says. This file is about the edges.

Files worth knowing, all under `desktop/manga/src/`:

| File | Holds |
| --- | --- |
| `def.rs` | The shapes of a definition (plain data), and every step. |
| `source.rs` | The six calls, holes, `prepare`/`vars`, `repeat`, and `validate` (every rule that rejects a definition at load). |
| `eval.rs` | Reading values: the steps, `aes_cbc`, `where`, `sort`. |
| `template.rs` | Filling `{holes}` and `{? ?}` groups. |
| `date.rs` | Dates, relative dates and chapter numbers. |
| `fetch.rs` | Requests: the rate, the user agent, cookies, check-page detection (`Challenge`), refused statuses (`Rejected`), the recorded stand-in for tests. |
| `theme.rs` | `extends` and merging. |
| `repo.rs` | The index, hashes, signing, the repository checks. |
| `check.rs`, `bin/cli.rs` | Fixtures, and the command line the scripts call. |
| `crypt.rs` | The AES-CBC used by `aes_cbc`. |

Planning documents (in the code repo): `pipeline/MANGA_PLAN.md` (why it is built this way) and `pipeline/MANGA_SOURCES_PORT_PLAN.md` (what was probed and what works).

## What the app does

- **No source of its own.** The app is a renderer. It ships with no source and no default repository. The person adds a repository by address (Sources tab, **Add a repository**) or pastes one definition (**Add a source**).
- **Sources tab**: Installed and Repositories. A repository page lists its sources with **Install** or **Update**. Installing writes the theme the source requires first, then the source, then checks that the file is the one the index lists.
- **Updates**: the app checks for newer versions at start. A newer `version` in the index updates the installed copy. Settings a person chose are kept.
- **Browse** shows the lists a source has (`popular`, `latest`, `search`), then a series page (`detail`, `chapters`), then the reader (`pages`).
- **Settings** (`settings`) appear as a picker on the source's page.
- **Filters** are passed to the search request. There is no filter screen yet. The home screen's genre chips search with only a filter set.
- **The reader** uses `pages.reading` (long strip, paged, paged right-to-left) and sends `pages.image_headers` with every image.
- **Cards** use `card.chapters` for the "120 chapters" line.
- **A check page** reaches the screen as the card "This site checks visitors first", with what to do instead.
- **Rate**: each source is limited to `rate_per_second`, however many requests are asked at once.
- **Cookies**: the engine can carry cookies and a user agent, but the app does not collect them from anywhere. A definition cannot ask for one.
- **Signing in** (`auth`): the engine signs in, keeps the session, adds it to requests to `base_url`, and refreshes it on a 401. The engine part is built and tested (`manga/tests/auth.rs`). The iPhone and Android apps draw the sign-in sheet from `auth.fields` (the source's settings page, **Account** row) and keep the session in the Keychain or the Keystore through a small `SessionKeeper` interface the engine calls (`load` when a source loads, `save` on every change). An older app ignores `auth`, so the source works signed out there.

## Rules the engine enforces on every definition

- Every request starts with `{base}`: a source can **only ask its own address** (and its mirrors). Not another host, not an IP, not a different scheme.
- Methods are `GET` and `POST` only.
- A response is capped at 8 MB. A request has a 30 second limit.
- At most 60 requests for one chapter list.
- A session is sent to `base_url` only, never to a mirror, and the login request never carries an old session.
- No code runs. A definition cannot make a hash, a signature, a time-based value or a random number of its own. The one thing that touches cryptography is decrypting (`aes_cbc`), and it cannot be turned into an oracle for something else.
- A definition is validated when it is loaded. A bad selector, regex, date format, setting or filter is refused before a site is asked (`format.md` and `debugging.md` list them).
- The images a page list names can be on **any host** (the engine does not restrict image hosts): that is why the repository warning matters, and why only sources you trust belong in a repository.

## Not supported

Say these plainly to the user. Do not bend the JSON to fake them.

| Not supported | Why, and what to do |
| --- | --- |
| **A site behind a check** (Cloudflare "Just a moment", a captcha, a JavaScript challenge) | The app has **no web view** and no way to pass a check; that is what a check is for. It was a decision (`MANGA_PLAN.md` §15): about a quarter of popular sources need one, and they are not supported. The call fails with `wants a check before it answers`. If the site has an official API or a feed, use that. |
| **A sign-in that is not a plain request** | `auth` covers a password that is posted and answered with a token, and a pasted token. Not covered: OAuth with a redirect and "Sign in with Google" (they need a browser, and the app has no web view), a captcha or Turnstile token, a code sent by email or text, a request that must be signed or hashed. For a site that offers only those, the answer is no. A partner can be given a plain token endpoint or a pasted API key. |
| **A cookie to copy** | The app collects none, and a definition cannot ask for one. |
| **A secret in a definition** | A repository is public. The person types the account in the app. |
| **Text novels** (chapters that are words, not pictures) | A chapter's `pages` must be image addresses. Asura's novels (`/api/novel-series/<slug>`, text in `content_html`, locked by `is_locked` and a `shard_cost`) cannot be read by the manga app, only the comic of the same title (`/api/series/<slug>`). The Books tab reads EPUB and OPDS, not this. |
| **Pages or chapters filled in by JavaScript** | There is no script engine. The engine reads the HTML or JSON the request returns. If the page has `0` chapter rows or `0` image addresses and no API behind it, the site cannot be read. (A script **blob** that holds the data as JSON, such as `__NEXT_DATA__` or `ts_reader.run({...})`, can be read: it is text in the answer.) |
| **Tile descrambling** | The image arrives cut in tiles with a permutation saying which cell goes where. Undoing it needs a codec in the engine and a call the app makes instead of showing the address. The only source that had it (Asura) stopped sending the permutation (verified against its live API on 2026-10-22: every page is `{url, width, height}`), so it has not been built. It gets built when a source actually sends one. |
| **`xor` steps, other ciphers, other key derivations** | Only AES-CBC, with the passphrase-and-salt derivation or a stated key and iv. |
| **A script or WebAssembly layer** | Planned as a possible third layer (`MANGA_PLAN.md` §5.1) and decided against for v1. About 40% of popular sites stay out because of that. A site that needs signed urls computed in code, or custom auth, is a code change in the engine. |
| **Requests to another host** | `{base}` only. A site whose pages come from another host is fine (the image addresses can be anywhere), but an API on a different host than `base_url` needs its own source with that host as `base_url`. |
| **Methods other than GET and POST**, or a body that is not a form or JSON | Not accepted. |
| **A number in a JSON body that is built from a hole** | A hole gives a string. An API that insists on a number needs engine support. |
| **A JSON key that contains a dot** | A path splits on `.`. |
| **XML or RSS as a format** | Only `html` and `json`. The HTML parser reads loose markup, so a simple XML answer can sometimes be read with CSS selectors, but that is not a supported format. |
| **Sorting or filtering a list in the definition** | A list is in the answer's order. Ask the site to sort (`?order=`). |
| **Filter screens** | Parsed and passed to the request only. |
| **Reading from a page's JavaScript variables by running it** | You can match text with `regex`. You cannot run code. |
| **Anything per person** (a library, a history, a tracker login) | That is the app's database, not a source. A source's own sign-in is `auth`. |

When the user asks for one of these, the answer is: "this needs a change in `desktop/manga/<file>`", with the file from the table above, and a short description of what the change would be. Do not write a source that pretends.

## What makes a site cheap to add

A source is worth shipping when the site is **reachable**, **gives its chapters in the answer** and **gives its pages in the answer**. Cheapest first:

1. **A JSON API** (Asura, Dynasty, MangaDex-style). Stable, no markup.
2. **A themed site** (Madara, MangaStream) with a theme already in the repo: a source is five lines.
3. **A site with its data in the page** (Next.js `__NEXT_DATA__`, a `ts_reader` blob).
4. **A plain HTML site**: works until the markup changes.
5. **Encrypted pages** with the passphrase in the page (the Madara protector).

And what fails: a check page, a login, chapters or pages filled by script, tiles, a parked domain.

## The probe results behind this

From a clone-and-read of the live Paperback extension ecosystem and live probing, 2026-10-22: of 96 base addresses in 14 repositories, most were parked, dead or behind a check. Four families failed the three-things test for different reasons: the Guya family (`<img>` with no `src`, filled by a script), proxy-blocked Madara (`0` chapter rows, a POST body needed), `manga1st.online` (295 chapter rows but zero image addresses in the page), and `toonily.com` (no longer Madara). The finding: **classify from the live page, never from an extension's metadata.**

Sources that were written and then removed are recoverable from the **code repo's** history (that is where these files lived before this repository existed): `manhuaplus`, `3asq` and `tcbscans` in `git show 75a1a53` (run in `dishant0406/akidev`), and `mangadex` as `git show 74f6723^:manga-sources/sources/mangadex.json`. Re-adding one is a checkout and a re-record, not a port. Re-probe first: the site may have changed.
