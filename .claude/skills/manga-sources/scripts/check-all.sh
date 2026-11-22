#!/usr/bin/env bash
#
# What CI does: every definition in sources/ and examples/ against its fixtures, then the index freshness check.
#
#   scripts/check-all.sh
#
# Exit 0 means a push would be green.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_cli.sh"
cd "$repo"

for def in sources/*.json examples/*.json; do
  id="$(basename "$def" .json)"
  echo "== $id"
  cli check "$repo/$def" "$repo/fixtures/$id" --themes "$repo/themes"
done

cp index.json /tmp/manga-index.committed.json
cli index "$repo" > /dev/null
if diff -q /tmp/manga-index.committed.json index.json > /dev/null; then
  echo "index.json is fresh"
else
  echo "index.json was stale. It is rewritten now: commit it with your change. (CI would have failed.)" >&2
  exit 1
fi
