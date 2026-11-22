#!/usr/bin/env bash
#
# Checks a source definition with the engine's real rules.
#
#   scripts/check.sh <definition.json>                 only the rules that need no site: the file is JSON, the
#                                                      schema is right, every selector, regex and date format
#                                                      compiles, every request starts with {base}, settings and
#                                                      filters are well formed
#   scripts/check.sh <definition.json> <fixtures-dir>  also runs every call in the fixtures and compares the answer
#                                                      with the one the fixtures expect
#   scripts/check.sh <definition.json> <fixtures-dir> --bless
#                                                      writes what the definition returns as the expected
#                                                      answers. Read them before you commit them.
#
# A definition that has "extends" gets the themes in this repo's themes/ folder. Exit 0 means accepted.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_cli.sh"
[ $# -ge 1 ] || { echo "usage: check.sh <definition.json> [fixtures-dir] [--bless]" >&2; exit 2; }

def="$(absolute "$1")"; shift
if [ $# -ge 1 ] && [ "$1" != "--bless" ]; then
  fixtures="$(cd "$1" && pwd)"; shift
else
  # No fixtures: an empty set is enough to make the engine load and validate the definition.
  fixtures="$(mktemp -d)"
  trap 'rm -rf "$fixtures"' EXIT
  echo '{"now_ms": 0, "responses": {}, "calls": []}' > "$fixtures/fixtures.json"
fi
cli check "$def" "$fixtures" --themes "$repo/themes" "$@"
