# Shared by the other scripts (sourced, not run). Finds the two repos and defines `cli`.
#
#   CODE_REPO   a checkout of dishant0406/akidev (default: ../akidev, next to this repo)
#
# `cli ARGS` runs akidev-manga-cli from the code repo, with the working directory left where it was.

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
repo="$(cd "$here/../../../.." && pwd)"
code="${CODE_REPO:-$repo/../akidev}"
[ -d "$code/desktop/manga" ] || { echo "Set CODE_REPO to a checkout of dishant0406/akidev (not found: $code)" >&2; exit 2; }
code="$(cd "$code" && pwd)"

cli() {
  (cd "$code/desktop" && cargo run -q -p akidev-manga --bin akidev-manga-cli -- "$@")
}

# A path as an absolute one, because `cli` runs from another folder.
absolute() { echo "$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"; }
