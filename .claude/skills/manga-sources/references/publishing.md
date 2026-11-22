# Publishing

A repository is a folder of plain files that an app reads over https. Publishing is: change files, raise versions, rewrite the index, push. Nothing is built, and nothing is deployed: GitHub serves the files.

## Contents

1. [The loop](#1-the-loop)
2. [Versions](#2-versions)
3. [The index](#3-the-index)
4. [Signing](#4-signing)
5. [CI](#5-ci)
6. [Adding the repository to the app](#6-adding-the-repository-to-the-app)
7. [Installing one source without a repository](#7-installing-one-source-without-a-repository)
8. [Removing, renaming, and breaking changes](#8-removing-renaming-and-breaking-changes)
9. [Before you push](#9-before-you-push)

## 1. The loop

```bash
# edit sources/<id>.json (and fixtures/<id>/ if the answers changed)
scripts/check.sh sources/<id>.json fixtures/<id>      # the definition still reads its fixtures
# raise "version" in the file
scripts/index.sh                                       # rewrite index.json
scripts/check-all.sh                                   # what CI does
git add sources fixtures themes index.json
git commit -m "<id> v<N>: <what changed and why>"
git push
```

Apps pick up the new version at their next start. There is no deploy step and no cache to clear beyond GitHub's own (a minute or two for `raw.githubusercontent.com`).

Commit messages: say what changed on the **site or in the definition** and why, in plain words (`arenascans v4: page through the site's canonical path URLs`). Never mention AI. One logical change per commit, and the version bump and the index go **in the same commit** as the change.

## 2. Versions

- `version` is a whole number in each source and theme. Start at `1`. **Raise it on every change** that should reach people, including a selector fix.
- An app updates an installed source when the repository's version is **higher** than the installed one. The same version with different content is **never** picked up, and the hash check then refuses a file that does not match the index.
- You cannot go down. To undo a bad change, fix the file and publish it with a higher version.
- A theme has its own `version`. Changing a theme moves its hash in the index. A source installed from the repository follows its theme's updates (the README's rule; the code repo's plan notes this was only tested at first install, so check it in the app). Re-run the fixtures of every source that extends it (`scripts/check-all.sh`). A source that extends a theme does **not** need its own version raised when only the theme changed, but raise it if the source's own file changed too.
- `min_app` (optional, in the source file): the oldest app version that can run the definition. Write it when you use a field an old app does not know. An old app ignores an unknown *field*, but it may fail on a new *step*, so say so. The index copies it.
- `schema` stays `1`. A higher number makes every current app refuse the file. Do not raise it unless the engine does.

## 3. The index

`index.json` is **generated**. Never edit it by hand.

```bash
scripts/index.sh
```

It reads `repo.json` (the repository's name), every `themes/*.json` (needs `"version"`) and `sources/*.json` (needs `id`, `name`, `version`, and the file must be named `<id>.json`), and writes each one's version, path and **SHA-256**, a source's `lang`, `nsfw`, `min_app`, and `requires` (from `extends`).

Why the hash: an app refuses any file whose hash is not the index's. So **a stale index breaks installs**: someone edits a source, forgets the index, and every install says the file is not what the index lists. CI fails on a stale index for that reason.

Run `scripts/index.sh` **after the last edit** to any source or theme. If you edit a file again after indexing, index again.

`examples/` is not indexed (it is for tests only), and neither are `fixtures/`.

If CI says the index is stale and you did not touch a source, the CLI's output may have changed with an engine update. Rewrite and commit it. (The `voices` list appeared this way.)

## 4. Signing

Optional. A signature lets an app notice if a repository **changes hands**. It does not prove the content is safe: trust in the content comes from the person who adds the repository.

```bash
# once: make a key (the secret stays OUT of the repository)
cd ../akidev/desktop
cargo run -q -p akidev-manga --bin akidev-manga-cli -- keygen ~/keys/manga-sources.key
# prints the public key, and writes the secret

# every time you publish:
scripts/index.sh --key ~/keys/manga-sources.key
git add index.json index.json.sig
```

`index.json` then carries `"key": "<public key hex>"` and `index.json.sig` is a signature over it. Both must be committed together, and indexing without `--key` removes the signature file.

What the app does: it **remembers the key the first time** a signed repository is added, and refuses the repository later if it names a different key (the person has to remove it and add it again to trust a new key). A repository that was signed and is then published unsigned is refused too, and so is one whose signature does not match.

**Never commit the secret key.** If it leaks, make a new one: every person who added the repository will have to remove and re-add it.

The repository today is **unsigned**. Do not start signing without the user's decision: a new key later breaks everyone who pinned the first.

## 5. CI

`.github/workflows/check.yml` runs on every push to `main` and on every pull request:

1. It checks out this repo and the code repo (`dishant0406/akidev`), and builds the checker (`akidev-manga-cli`).
2. For every file in `sources/` and `examples/`, it runs `check <def> fixtures/<id> --themes themes`: every call in `fixtures.json` must return exactly the `expect` recorded there.
3. It rewrites the index and fails if it differs from the committed one.

`scripts/check-all.sh` does the same locally. Green locally means green in CI, **as long as the code repo you built is the same as `main`**. The CI builds the **current** engine from the code repo's `main`, so an engine change can turn this repo red with no change here (the index's `voices` field did). Fix by re-indexing, or by updating the definitions the engine change affects.

CI uses **recorded** answers. It never contacts the site. A site that changed does not turn CI red: your fixtures still pass. Only a re-record shows the change. That is why `scripts/run-live.sh` matters.

## 6. Adding the repository to the app

In the app: **Sources tab, Add a repository**, paste the address:

- `github.com/<owner>/<repo>` (the `main` branch),
- `github.com/<owner>/<repo>/tree/<branch>/<folder>` when the repository is in a folder,
- a raw link, or any https folder that holds an `index.json`. Plain `http` is accepted only for this machine, for development.

The app reads `raw.githubusercontent.com/<owner>/<repo>/<branch>/index.json`. **Adding installs nothing.** The repository page lists its sources, each with **Install** or **Update**, and a note on whether it is signed. Install writes the theme the source requires first, then the source, then checks the file is the one the index lists.

The repository for these definitions is `dishant0406/manga-sources`.

To test a change before you push, serve the folder on this machine and add it by address:

```bash
python3 -m http.server 8770 --directory .       # then in the app: Add a repository, http://127.0.0.1:8770/
```

(The iOS simulator reaches the Mac at `127.0.0.1`. A real phone needs the Mac's address, and `http` to anything but this machine is refused: use a branch pushed to GitHub instead.)

## 7. Installing one source without a repository

**Sources tab, Add a source**, paste the definition. It is checked before it is kept, and the app shows its name, languages and version first. A definition that extends a theme has the theme **merged in at that moment** and is stored that way, so it keeps working without the theme. A definition pasted this way **does not update itself**: raise its `version` and paste it again, or put it in a repository.

A source that extends a theme that is not installed is refused with a message that says to add the repository that has it.

This is the quickest way to try a source on a phone: paste the file. No repository, no index.

## 8. Removing, renaming, and breaking changes

- **Removing a source**: delete `sources/<id>.json` and `fixtures/<id>/`, run `scripts/index.sh`, remove its row from the README's table. An installed copy keeps working until the site breaks it. The repository page stops listing it.
- **Renaming an id** is a **new source**. A person's library, history and settings are stored under the old id. Prefer fixing the old one. If you must, publish the new id, keep the old for a while, and tell the user.
- **Changing how an id is built** (a card's `id` regex, or what `{id}` means in the chapters request) breaks every saved library entry and every unread chapter marker for that source. Treat it as a breaking change: say so, and prefer a new source id.
- **Changing a chapter id** has the same effect on read progress.
- **A theme change** reaches every source that extends it. Re-run all their fixtures before you push.

## 9. Before you push

- [ ] `version` raised in every changed source and theme.
- [ ] `scripts/index.sh` run **after** the last edit, and `index.json` is in the commit.
- [ ] `scripts/check-all.sh` exits `0`.
- [ ] Fixtures were recorded from a clean network and the `expect`s were **read**.
- [ ] The README's "What is in it" table lists every source in `sources/`.
- [ ] No secret, key, cookie or personal address anywhere in the diff (`git diff --cached`).
- [ ] The commit message says what changed and why, with no mention of AI.
- [ ] The user asked you to push.

After the push, check the index is served: `curl -s https://raw.githubusercontent.com/dishant0406/manga-sources/main/index.json | jq '.sources | map({id, version})'`. And check CI went green: `gh run list --repo dishant0406/manga-sources --limit 1`.
