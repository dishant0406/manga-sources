#!/usr/bin/env bash
#
# Asks the LIVE site for the calls you name and saves its answers as fixtures in fixtures/<id>/.
#
#   scripts/record.sh <definition.json> popular details=<series> chapters=<series> pages=<series>,<chapter>
#   scripts/record.sh <definition.json> latest search=<term>
#
# Calls: popular, latest, search=TERM, details=ID, chapters=ID, pages=SERIES,CHAPTER.
# The definition id names the folder. Read fixtures/<id>/fixtures.json before you commit it: the expected answers
# are whatever the definition returned, right or wrong. A call that fails is skipped and printed as SKIPPED.
# Record from a machine with a clean network: a filtered network records its block page, not the site.

set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/_cli.sh"
[ $# -ge 2 ] || { echo "usage: record.sh <definition.json> <call>..." >&2; exit 2; }

def="$(absolute "$1")"; shift
id="$(jq -r .id "$def")"
mkdir -p "$repo/fixtures/$id"
cli record "$def" "$repo/fixtures/$id" "$@" --themes "$repo/themes"
