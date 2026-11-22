#!/usr/bin/env bash
#
# Rewrites index.json: every file's version and SHA-256. Run it after ANY change to a file in sources/ or themes/,
# and commit index.json with the change. An app refuses a file whose hash is not the index's.
#
#   scripts/index.sh                      unsigned
#   scripts/index.sh --key secret.key     signed (index.json.sig is written too; keep secret.key OUT of the repo)
#
# Make a key once with: cd <code repo>/desktop && cargo run -q -p akidev-manga --bin akidev-manga-cli -- keygen secret.key

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_cli.sh"

args=()
while [ $# -gt 0 ]; do
  case "$1" in
    --key) args+=(--key "$(absolute "$2")"); shift 2 ;;
    *) echo "usage: index.sh [--key secret.key]" >&2; exit 2 ;;
  esac
done
cli index "$repo" ${args[@]+"${args[@]}"}
