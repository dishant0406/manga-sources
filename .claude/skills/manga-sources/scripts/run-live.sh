#!/usr/bin/env bash
#
# Runs one call against the LIVE site and prints what the app would get, as JSON. Nothing is saved.
#
#   scripts/run-live.sh <definition.json> popular
#   scripts/run-live.sh <definition.json> latest
#   scripts/run-live.sh <definition.json> search "solo leveling"
#   scripts/run-live.sh <definition.json> details <series-id>
#   scripts/run-live.sh <definition.json> chapters <series-id>
#   scripts/run-live.sh <definition.json> pages <series-id> <chapter-id>
#
# The ids are the ones an earlier call printed: a card's id for details and chapters, then a chapter's id for pages.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_cli.sh"
[ $# -ge 2 ] || { echo "usage: run-live.sh <definition.json> <call> [args]" >&2; exit 2; }

def="$(absolute "$1")"; shift
cli run "$def" "$@" --themes "$repo/themes"
