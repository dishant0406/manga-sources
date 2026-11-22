---
name: manga-sources
description: "Write, change, test, debug and publish source definitions for the Akidev manga app: give it a manga or comics website, an API or an idea and it writes the complete JSON source (popular, latest, search, filters, settings, detail, chapters, pages) or a theme for a whole family of sites, records fixtures from the live site, checks them with the real engine and delivers it. Covers the format, every expression step, themes, paged chapter lists, nonce and POST chains, encrypted page lists, mirrors, the repository index and signing, and what a definition cannot do."
---

# Manga sources

You are working in the `manga-sources` repo, or on something that reads it. This skill is the whole guide: the format, the recipes, the publishing flow and the debugging steps. This file is the map and the rules. The references hold the details.

## What this repo is

- It is a **repository of source plugins** for the Akidev manga app (`manga-app/`, and the Android app). The app has no source of its own. It is a renderer: it installs whatever definitions a repository lists and reads them.
- A **source** is one JSON file, `sources/<id>.json`. It says which requests to make to a site and how to read each answer. **Nothing in it is code.**
- A **theme** is a base definition for sites that run the same CMS, `themes/<id>.json`. A source can `extend` it and only say what differs.
- `index.json` is what an app reads first. It lists every file with its version and SHA-256. It is **generated**, and a stale one breaks installs.
- `fixtures/<id>/` holds pages recorded from the live site, and `fixtures.json` with the answers the definition must return. CI replays them.
- The engine is in the other repo, `dishant0406/akidev`, under `desktop/manga/` (`src/source.rs`, `src/eval.rs`, `src/def.rs`). In this skill `<code repo>` means a checkout of it. The usual layout is two folders side by side: `.../akidev` and `.../manga-sources`. The scripts here find it as `../akidev`, or take `CODE_REPO`.

## The golden rules

1. **Raise `version` on every change to a source or theme.** An installed copy updates only when the repository's version is higher.
2. **Run `scripts/index.sh` after every change** to a file in `sources/` or `themes/`, and commit `index.json` with it. An app refuses a file whose hash is not the index's. CI fails on a stale index.
3. **Only add a site that is legal to read.** A public API that welcomes third-party readers, or work released under an open licence. Never a site that republishes copyrighted chapters without the publisher's leave. When in doubt, ask the user before writing anything. See `references/from-a-website.md` (the legal gate).
4. **Never get around a protection.** If the site answers with a check page (Cloudflare, a captcha), a login wall or a paywall, stop and tell the user. The app has no web view and no way past a check. Do not look for one.
5. **Record fixtures from the live site, not by hand.** Hand-written fixtures prove the engine reads a shape, not that the site matches it. The only hand-written ones in this repo are the two Madara examples and the worked examples in this skill.
6. **Read the blessed answers before you commit them.** `--bless` writes whatever the definition returned, right or wrong. An empty `authors` list on a site that shows authors is a bug that `--bless` will happily save.
7. **Test the real site by hand too.** Fixtures freeze one day. Run `scripts/run-live.sh` before you call it done, and again for a chapter in the middle of the list.
8. **Keep the file formatted**: 2-space JSON, ids lower case. A source id is lower case letters, digits and dashes, and the file is named after it.
9. **Do not mention AI** in commit messages or anywhere else in this repo.
10. **Never publish (commit and push) unless the user asks.** Editing, recording and testing are free. Pushing changes what every app that follows this repository does.

## Decide what kind of job it is

| The user wants | It is | Read |
| --- | --- | --- |
| **"Add this website / API"**, or "write me a source for X" | The whole job: investigate, classify, write, record, bless, verify, deliver | **`references/from-a-website.md`** (start here) |
| A source for a site on a known CMS (Madara, MangaStream, Next.js) | A **source that extends a theme**, or a copy of a template | `references/recipes.md` |
| Several sites that run the same CMS | A new **theme** | `references/recipes.md` (themes), `references/format.md` (themes) |
| A field is empty or wrong, a list stops early, pages are missing | **Debugging** | `references/debugging.md` |
| A value must be cut, joined, decoded, dated or decrypted | An **expression** | `references/expressions.md` |
| Genres, sorts, a language or rating choice | **Filters** or **settings** | `references/format.md` (filters, settings), `references/recipes.md` |
| Ship it, version it, sign the index, add the repo to the app | **Publishing** | `references/publishing.md` |
| Tile descrambling, a check page, scripting, a login | **Not supported** | `references/engine.md` (say so plainly) |

If the request needs something a definition cannot say, tell the user plainly that it needs a change in `<code repo>/desktop/manga`, and name the file (see `references/engine.md`). Do not bend the JSON to fake it.

## When the user gives you a website, an API or an idea

This is the main job. **Read `references/from-a-website.md` and follow it.** In short:

1. **Gate it.** Is it legal to read? Does it need a login or answer with a check page? If yes to either problem, stop and tell the user.
2. **Probe it** with `scripts/probe.sh <url>` on the home page, a series page and a chapter page. It says if the answer is JSON, Next.js, MangaStream, Madara, encrypted, or a check page.
3. **Apply the three-things test.** A source is worth writing only when the site is **reachable**, **gives its chapters in the answer** and **gives its pages in the answer**. Chapters or pages that a script fills in after the page loads cannot be read. Say so and stop.
4. **Start from a template** in `templates/`. Do not write from nothing. The templates are `source-json-api`, `source-html-site`, `source-mangastream`, `source-next-data`, `source-extends-madara`, `source-prepare-nonce`, `source-paged-chapters`, `source-encrypted-pages`, `source-settings-filters`, `source-post-json` and `theme`. Each one is validated by the real engine, and six have a worked example with fixtures in `templates/worked-examples/`.
5. **Write the six questions one at a time**, and run `scripts/check.sh <file>` after each. It catches bad selectors, bad regexes, bad date formats, a url that does not start with `{base}` and more, without touching the site.
6. **Record** with `scripts/record.sh <file> popular details=<series> chapters=<series> pages=<series>,<chapter>` (also `latest`, `search=TERM`). **Bless** with `scripts/check.sh <file> fixtures/<id> --bless`. **Read the answers.**
7. **Try the live site** with `scripts/run-live.sh`: a search, a series with many chapters, a chapter from the middle, one with unusual characters in its id.
8. **Deliver**: raise `version`, run `scripts/index.sh`, run `scripts/check-all.sh`, and tell the user what you built and what you could not verify. Commit only if asked.

## What is in the references

| File | What it holds |
| --- | --- |
| `references/from-a-website.md` | The investigate-to-deliver workflow, the legal gate, the three-things test, a checklist per section |
| `references/format.md` | Every field of a definition: top level, requests, holes, the six sections, filters, settings, themes, the index, all limits |
| `references/expressions.md` | How a value is read: short forms, every step with an example, what the nodes are, the traps |
| `references/recipes.md` | Working patterns: JSON API, plain HTML, MangaStream, Next.js, Madara, paged chapters, nonce, POST, encrypted pages, mirrors |
| `references/debugging.md` | Each error message and symptom, its cause and its fix |
| `references/publishing.md` | Versioning, the index, signing, CI, adding the repository to the app |
| `references/engine.md` | What the app does with a definition, the limits, and what is not supported |

## Scripts

All of them need the code repo (`CODE_REPO`, or `../akidev`) and a Rust toolchain (the first run builds the engine).

| Script | Does |
| --- | --- |
| `scripts/probe.sh <url>...` | One look at a page: status, type, markers that say which kind of site it is. Saves the answers in `/tmp/manga-probe/`. |
| `scripts/check.sh <def>` | Validates a definition with no site and no fixtures. |
| `scripts/check.sh <def> <fixtures-dir> [--bless]` | Replays the fixtures. `--bless` writes the answers as expected. |
| `scripts/record.sh <def> <call>...` | Asks the live site and saves its answers as fixtures in `fixtures/<id>/`. |
| `scripts/run-live.sh <def> <call> [args]` | One live call, printed as JSON. Nothing saved. |
| `scripts/index.sh [--key f]` | Rewrites `index.json` (and signs it with `--key`). |
| `scripts/check-all.sh` | What CI does: every definition against its fixtures, then the index freshness check. |

## Templates

`templates/` has one file per kind of site and `templates/worked-examples/<name>/` has hand-made answers for six of them, so you can run the whole loop with no network:

```bash
scripts/check.sh templates/source-json-api.json templates/worked-examples/json-api
```

Replace the example host, selectors and paths with what you found on the real site. Every value in a template is a placeholder for something you must look up. Never ship a template unchanged.
