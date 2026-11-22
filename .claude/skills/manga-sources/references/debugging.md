# Debugging

Start with the **message** or the **symptom**, find the cause, apply the fix. Always reproduce with the scripts, never by guessing:

```bash
scripts/check.sh sources/<id>.json                          # the rules that need no site
scripts/check.sh sources/<id>.json fixtures/<id>            # the recorded answers
scripts/run-live.sh sources/<id>.json <call> [args]         # the live site
scripts/probe.sh <url>                                      # what the site sends now
```

## Contents

1. [Errors the engine gives when it loads a definition](#1-errors-when-the-definition-loads)
2. [Errors from a call](#2-errors-from-a-call)
3. [Symptoms with no error](#3-symptoms-with-no-error)
4. [Fixture and CI failures](#4-fixture-and-ci-failures)
5. [A routine for "it stopped working"](#5-a-routine-for-it-stopped-working)

## 1. Errors when the definition loads

These come from `validate` and need no site. `scripts/check.sh <def>` shows them.

| Message | Cause | Fix |
| --- | --- | --- |
| `schema N is not one this app reads (it reads 1)` | `schema` is not `1` | Write `"schema": 1`. |
| `the id must be lowercase letters, digits and dashes` | An underscore, a capital or a space in `id` | Rename. Also rename the file. |
| `base_url must be an http(s) address` | No scheme, a typo, no host | `https://www.example.com`, no trailing path needed. |
| `mirror X must be an http(s) address` | Same, for a mirror | Fix the mirror. |
| `rate_per_second must be above 0 and at most 20` | `0`, negative, or more than 20 | Use `1` or `2`. |
| `page_size must be from 1 to 500` | Out of range | Use the site's real page size. |
| `a source needs at least one of popular, latest and search` | None of the three | Add one. |
| `<section>: a request's url must start with {base} (a source can only ask its own address)` | A url that starts with `https://...` or a hole | Start with `{base}`. For another host, build the address in a `template` (for images) or use a mirror. A request can **never** go to another host. |
| `<section>: the method must be GET or POST` | `PUT`, `HEAD`, a typo | Use `GET` or `POST`. |
| `bad selector "...": ...` | A CSS selector that does not parse | Fix it. Quote attribute values: `a[rel="next"]`. |
| a regex error (`regex parse error`) | A bad pattern | Escape for JSON: `\\d` in the file is `\d` to the regex. |
| `the date format "X" can never read a date (it needs a year)` | A `date` pattern with no `yyyy` or `yy` | Add the year. `"MMMM d"` alone cannot work. |
| `setting X: the default is not one of its options` | `default` is not an option's `value` | Make it one. |
| `filter X: a select needs options` | A `select` with no options | Add them, or use `"kind": "text"`. |
| `filter X: the default is not one of its options` | Same, for a filter | Fix. |
| `filter X: a text filter has no options` | `options` on a text filter | Remove them. |
| `a filter's id is lowercase letters, digits, dashes and underscores` | A capital or a space in a filter or setting id | Rename. |
| `X: a var's name is lowercase letters, digits, dashes and underscores` | Same, for a var | Rename. |
| `pages.reading must be longstrip, paged or paged_rtl` | A typo (`long_strip`, `rtl`) | Use one of the three. |
| `chapters.repeat.size must be from 1 to 1000` | Out of range | Fix. |
| `aes_cbc needs a passphrase, or a key and an iv` | Neither given | Give one. |
| `aes_cbc needs both a key and an iv` | One of the two | Give both. |
| `aes_cbc takes a passphrase or a key, not both` | Both given | Remove one. |
| `unknown variant ...` or `data did not match any variant of untagged enum Ex` (from the JSON reader) | A step name that does not exist, or a step object with two keys, or a bare object where a list is needed | Check the spelling against `expressions.md`. A step is **one** key. A single step still needs its list: `[{"path": "x"}]`. |
| `missing field ...` | A required field is absent (`card`, `rows`, `images`, `chapter`, ...) | Add it. |
| `X is not JSON` | A trailing comma, a comment, an unquoted key | Validate with `jq . file`. |
| `the definition extends a theme called X, which is not installed` | `extends` names a theme that is not in `themes/` (or not installed in the app) | Add the theme to the repo, or write the source stand-alone. A source does not bring its own theme. |
| `themes extend each other in a circle: X` | Theme A extends B extends A | Break the circle. |

**An unknown key is not an error.** A misspelled field (`uploaded` for `date`, `descripton`, `cover_img`) is **silently ignored**, and the value reads as if the site had none. This is the most common reason a field is empty. Read your keys against `format.md`.

## 2. Errors from a call

| Message | Cause | Fix |
| --- | --- | --- |
| `this source cannot answer that: its definition asks for a value the app had none of (in <url>)` | A hole with no value, outside a `{? ?}` group. Almost always a bare `{term}`, `{genre}` or a filter's id. Or `{term}` in `latest`, or `{id}` where there is none. | Put it in a group: `{?&q={term}?}`. Check which section it is in: `{term}` and filters exist only in `search`. |
| `<url> wants a check before it answers (status N)` | The site sent a check page (Cloudflare, a captcha) | **Not fixable in a definition.** Tell the user the site is not supported from here. Do not look for a way around. |
| `could not reach <url>: <reason>` | No network, the name does not resolve, a refused connection, a timeout | Try another network. If the site is down for good, the source is dead. With `mirrors`, the next is tried first. |
| `<url> answered 404 Not Found` (or 500, 403) | The url is wrong, the id is wrong, or the site blocks the request | Open the same url with `curl -A '<phone UA>'`. Check the id you passed is the one an earlier call gave. 403 with a normal page may be a missing header: add `headers` the site's own pages send (a `referer`, an `x-requested-with`). |
| `the answer is not JSON` | `"format": "json"` but the site answered HTML (an error page, a redirect to login, a check) | `curl` the url and read the first lines. Fix the url, the method, or the headers. |
| `the response is too large` | An answer above 8 MB | A different, smaller request. |
| `the page has no title: has the site changed?` | `detail.title` gave nothing | The selector or path no longer matches, or the id is wrong. Probe the series page and re-read the markup. |
| `the chapter has no pages: has the site changed?` | `pages.images` gave nothing | The chapter page changed, the images are in `<noscript>` (read the script blob), or the page is a login or check page. |
| `<name> gave chapters for 60 requests without ending: raise chapters.repeat.size` | A chapter list that never ends: `repeat` with `{offset}` or `{page}` missing from the url, or a `total` that never stops it, or a series with more than `60 * size` chapters | Put `{offset}` or `{page}` in the url. Check `total` counts chapters. Raise `size`, up to the request's real limit. |
| `no recorded answer for GET <url> (have: ...)` | A fixture run asked for a url that was not recorded | The request changed (a hole, an order of query parameters) or the fixtures are old. Re-record. Note the url **must match exactly**, including the query order. |
| `aes_cbc needs a salt: none was stated and the payload has none` | The payload has no `s` and the definition has no `salt` | Give a `salt` (hex), or check you cut the right object out. |
| `the salt is not hexadecimal` / `the IV is not hexadecimal` | A non-hex salt or iv | Fix, or the payload shape changed. |
| `the value to decrypt is not base64` (or `hexadecimal`) | The text you passed to `aes_cbc` is not the ciphertext | Check the steps before it: the regex that cuts out the object, the unescape step. Use `"hex": true` if the ciphertext is hex. |
| `the payload is not JSON: has the site changed?` / `the payload has no ciphertext (ct): has the site changed?` | The cut-out text is not the payload | Print the text before `aes_cbc` (record the page and read the script). |
| a decryption that gives garbage | A wrong passphrase, a wrong salt, or a different key derivation | The nonce read from the page must be the one for **that** page. Confirm the derivation matches (`MD5` stretched to 48 bytes). A different scheme is code: `engine.md`. |
| `<name> has no popular list` (or `latest list`, `search`) | The app asked for a section the source does not have | Add the section, or leave it: the app knows from `can_popular`, `can_latest`, `can_search`. |

## 3. Symptoms with no error

| Symptom | Cause | Fix |
| --- | --- | --- |
| A list is **empty** | `rows` matches nothing (wrong selector, or the site sent a different page to a script) | `scripts/probe.sh` the url, open the saved file, `grep` for the card's class. If the page is mostly empty, the list is filled by a script: a different request (an API) may exist. |
| **Fewer cards than the page shows** | `card.id` or `card.title` gives nothing for some rows, so they are skipped. Or `regex` does not match some links. | Test the id and title expressions on a row that is dropped. Loosen the regex. |
| **The same cards on every page**, "Show more" does nothing | The site ignores the paging parameter (page 2 returns page 1, and the app drops repeated ids), while `has_next` stays true | Ask the live site for page 1 and page 2 and compare. Find the real paging rule (a path like `/page/2/`, a different parameter name). `arenascans` shipped this bug. |
| **Paging stops too early** or **never stops** | `next` or `total` is wrong. `total` with a `page_size` that is not the site's. A `next` built from the request's own holes. | See `format.md` (lists). Prefer the site's own next link. |
| A **field is empty** | A misspelled key (silently ignored). A selector that gives nothing. A `default` hiding it. | Check the key's spelling. Run the expression step by step: cut the pipe to its first steps, run, add one more. |
| **Authors / status are always empty or `unknown`** | The site never fills them (`<i></i>`, `n/a`) | That is the truth. Leave it. |
| **Dates are `null`** | The field is misspelled (`uploaded`), the date format does not match the text, or `date` is missing | Check the key is `date`. Print the text the expression reads and compare it with the format. Put `relative` and `iso` in the list. |
| **Dates are wrong by a day** | A format with no time reads midnight UTC | Accept it. A site that gives only a date has no time. |
| **Chapters are in the wrong order** | The site lists oldest first | `"order": "oldest-first"`. |
| **Chapter numbers are wrong** (`2` instead of `40`) | The first number in the title is not the chapter (`"Solo Leveling 2 Ch. 40"`) | Give `chapter.number` an expression, or make the title contain `Ch.`. The engine prefers a number after chapter/ch./episode/ep./#. |
| **Fewer chapters than the site has** | `rows` matches only some `li`s. Or `repeat.size` is bigger than what the site sends per request (so rows are skipped). Or `total` is pages, not chapters. | Count rows against the page. Set `size` to the real request size. Leave `total` out if it counts pages. |
| **Chapters are duplicated or missing** | The ids repeat (two rows give the same id, kept once) or are built wrong | Check the id regex on every row type (a "new" badge row, a template row such as `{{date}}`). |
| **Pages are missing** | The images are in `<noscript>`, or lazy attributes are different (`data-src`, `data-lazy-src`, `data-original`), or some pages are in another script | Probe the chapter page. Read the attribute list. Use the script blob. |
| **Pages are out of order** (`1, 10, 11, 2`) | A JSON object read with `*` comes out in key order | Add `"sort"` before the template. |
| **Pages load as broken images in the app** | The CDN wants a `referer` (or refuses one) | `image_headers`. Test with `curl -I -e <referer> <image>`. |
| **A cover is missing** | The real address is in `data-src` and `src` is a placeholder, or the CDN host differs | `data-src\|data-lazy-src\|src`. A path is made absolute against the **answering host**, not the CDN: use a template. |
| **A cover is a tiny placeholder** | The first match is an icon | A tighter selector (`img.ts-post-image`, `.thumb img`). |
| **HTML tags appear in the description** | The field holds markup in JSON | `plain_text`. After a `"html"` step on a script, use `"text"` instead (see `expressions.md`, trap 1). |
| **`&amp;` or `&lt;` appear** | `"html"` on a script escaped `& < >` | Use `"text"` on script elements. |
| A **search returns the home list** | The term is not applied (a wrong parameter name, or in a group that vanished) | Open the live search url with `curl`, compare with and without the term. |
| A **genre filter does nothing** | The site ignores the parameter | Ask with two values and compare. If the lists are identical, drop the filter. |
| **Search with only a genre fails** | A bare `{term}` | `{?&q={term}?}`. |
| A **POST gives the wrong page** | The POST was redirected and lost its body | Put the host that answers **without** redirecting in `base_url`. `curl -sI -X POST <url>` to see the `301`/`302`. |
| **Works through one mirror, not the other** | The mirrors are different sites | Make them different sources, or drop one. |
| **Worked yesterday, empty today** | The site changed its markup | `scripts/probe.sh` the same page, compare the saved file with `fixtures/<id>/r*.html`. Re-record. |
| **Works on this machine, not in CI or the app** | A filtered network recorded a block page, a header differs, or the site blocks by region | Re-record from a clean network. Read the first lines of a fixture file: if it is not the site, it is a block page. |
| **The fixture check passes, the app fails** | The fixtures hold one day. Or the app's `{lang}`/rating setting differs from the default the fixtures ran with. | `run-live.sh` the real call. Remember settings fill holes with the person's choice. |
| **A new source never appears in the app** | The index is stale or the source is not listed | `scripts/index.sh`, commit it, check the repo's `raw.githubusercontent.com/.../index.json`. |
| **An installed source never updates** | `version` was not raised | Raise it, re-index. |

## 4. Fixture and CI failures

**`FAIL <call>` with `expected ... got ...`.** The definition now returns something different from what the fixture expects. Read the diff:

- You changed the definition on purpose: re-bless (`--bless`), **read the new expects**, commit.
- You did not mean to: the change broke something. Fix the definition.

**CI says `index.json is stale`.** A file in `sources/` or `themes/` changed (or the CLI's output format changed) since `index.json` was written. Run `scripts/index.sh`, commit `index.json`. Note: after an engine change the CLI may write a field the committed index lacks (the `voices` list was one). The fix is the same: rewrite and commit.

**CI fails for a source you did not touch.** A theme it extends changed, or the engine changed. Run `scripts/check-all.sh` locally to see which.

**`cannot read fixtures/<id>/fixtures.json`.** The folder is named after the **source id** (or the example's id). `record.sh` makes it.

**A recorded url does not match.** The key of a recorded answer is `METHOD url` with the query exactly as the engine builds it. If you change the order of query parameters or add a parameter, the old recording no longer matches (`no recorded answer for ...`). Re-record that call.

**The fixtures contain a block page.** Open `r1.html`. If it says "Web Page Blocked", "Just a moment", or is a few hundred bytes of nothing, the machine that recorded it was filtered. Delete the folder and record from a clean network.

## 5. A routine for "it stopped working"

1. `scripts/run-live.sh sources/<id>.json <the call that fails> ...` and read the **error**. Most are in the tables above.
2. `scripts/probe.sh <the url that call asks>` and read the saved file. Does it still look like the fixture?
3. If a check page, a login or `403`: stop, the site changed its protection. Say so.
4. If the markup moved: find the new selector in the saved file. Change **one** field at a time and re-run the call.
5. `scripts/record.sh` the calls again, `--bless`, **diff** `fixtures.json` (`git diff`): the changes should be the ones you expect, no more.
6. Raise `version`, `scripts/index.sh`, `scripts/check-all.sh`.
7. Tell the user what changed on the site and what you changed.

If the site is gone for good (parked, redirected to an unrelated site, a `410`), say so and propose **removing** the source. Delete `sources/<id>.json` and `fixtures/<id>/`, re-index, and update the README's table. An installed copy on a phone keeps working until the site breaks it; the app's repository page just stops listing it.
