#!/usr/bin/env bash
#
# One look at a page, to decide what kind of site it is BEFORE writing anything.
#
#   scripts/probe.sh <url> [more urls]
#
# It asks the way the app does (the same phone user agent) and prints: the status, the content type, the size, the
# title, and which of the known markers the page carries. Use it on the home page, a series page and a chapter page.
# It saves each answer to /tmp/manga-probe/ so you can read the markup with jq, grep or a browser.

set -uo pipefail
ua='Mozilla/5.0 (iPhone; CPU iPhone OS 18_7 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148'
out=/tmp/manga-probe
mkdir -p "$out"
[ $# -ge 1 ] || { echo "usage: probe.sh <url> [url...]" >&2; exit 2; }

mark() { grep -qi -- "$2" "$1" && echo "  yes  $3"; }

for url in "$@"; do
  file="$out/$(echo "$url" | tr -c 'A-Za-z0-9\n' '_' | cut -c1-80)"
  code="$(curl -sS -m 25 -L --max-redirs 0 -A "$ua" -o "$file" -w '%{http_code} %{content_type} %{size_download} bytes, redirect: %{redirect_url}' "$url" 2>&1)" || { echo "$url"; echo "  could not be reached: $code"; continue; }
  echo "$url"
  echo "  $code"
  echo "  saved: $file"
  if jq -e . "$file" > /dev/null 2>&1; then
    echo "  this is JSON. Top level: $(jq -c 'if type=="object" then keys else "list of \(length)" end' "$file" | cut -c1-200)"
    continue
  fi
  echo "  title: $(grep -io '<title>[^<]*' "$file" | head -1 | sed 's/<title>//')"
  echo "  markers:"
  mark "$file" 'cf-chl\|cf_chl_opt\|just a moment\|attention required' "A CHECK PAGE (Cloudflare or similar): the app cannot pass it. Stop here."
  mark "$file" 'captcha' "the word captcha (a check, or only a comment form: look)"
  mark "$file" '__NEXT_DATA__' "Next.js: the data is JSON inside script#__NEXT_DATA__ (see templates/source-next-data.json)"
  mark "$file" 'ts_reader' "MangaStream reader: pages are in the ts_reader.run({...}) script (see templates/source-mangastream.json)"
  mark "$file" 'wp-manga\|madara' "Madara (WordPress): try extends madara (see templates/source-extends-madara.json)"
  mark "$file" 'class="bsx"\|mangareader\|ts-post-image' "MangaStream cards (div.bsx)"
  mark "$file" 'chapter-protector\|wpmangaprotectornonce' "Madara chapter protector: pages are encrypted (see templates/source-encrypted-pages.json)"
  mark "$file" 'noscript' "noscript tags: images inside them are NOT readable (the parser skips them): look for a script blob"
  mark "$file" 'application/ld+json' "JSON-LD data in the page"
  mark "$file" 'data-src\|data-lazy-src' "lazy images: read data-src|data-lazy-src|src"
  mark "$file" 'rel="next"\|nextpostslink\|next page-numbers' "a next link the list can use as next"
  imgs="$(grep -o '<img' "$file" | wc -l | tr -d ' ')"
  echo "  <img> tags in the HTML: $imgs (a chapter page with none means the pages come from a script or an API)"
done
