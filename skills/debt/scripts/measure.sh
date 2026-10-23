#!/usr/bin/env bash
# Ranks the code files of the default branch by their lines × the commits that
# touched them in 60 days, highest first, and prints the top 15 as a Markdown
# table, then the ref and the SHA it read, and the paths the window moved.
#
#   measure.sh [path]
#
# The path is from the repository's root; without one, the whole tree. It reads
# origin/HEAD when the clone has it, else HEAD, through git, so it runs from any
# directory of any checkout. Documents, lockfiles, fixtures and other data are
# not code and are left out.
#
# Needs only bash, git and awk.

set -euo pipefail

[ $# -le 1 ] || {
  echo 'usage: measure.sh [path]' >&2
  exit 2
}
path=${1:-.}
top=$(git rev-parse --show-toplevel)
ref=$(git -C "$top" rev-parse --abbrev-ref --verify -q origin/HEAD || echo HEAD)
data='\.(md|txt|rst|json|ya?ml|toml|csv|svg|snap|lock)$|(^|/)(fixtures|testdata|vendor|__snapshots__)/|(^|/)(go\.sum|package-lock\.json|pnpm-lock\.yaml)$'

# ponytail: renames are not followed, so a file moved inside the window counts
# its commits from the move; git log --follow per file if a hotspot hides
# behind one.
rows=$({
  git -C "$top" grep -I -c '' "$ref" -- "$path" || true
  echo '== log'
  git -C "$top" log --since=60.days --format= --name-only "$ref" -- "$path"
} | awk -v ref="$ref:" -v data="$data" '
  $0 == "== log" { inlog = 1; next }
  !inlog {
    # ref:path:count; the path can hold a colon, the count cannot.
    n = $0; sub(/.*:/, "", n)
    f = substr($0, length(ref) + 1, length($0) - length(ref) - length(n) - 1)
    if (f !~ data) lines[f] = n
    next
  }
  $0 in lines { commits[$0]++ }
  END { for (f in lines) printf "%d\t%d\t%d\t%s\n", lines[f] * commits[f], lines[f], commits[f], f }
' | sort -t $'\t' -k1,1nr -k2,2nr)

[ -n "$rows" ] || {
  echo "No code files under $path on $ref." >&2
  exit 1
}
echo '| File | Lines | Commits in 60 days | Score |'
echo '| --- | ---: | ---: | ---: |'
head -n 15 <<<"$rows" | awk -F'\t' '{ printf "| `%s` | %d | %d | %d |\n", $4, $2, $3, $1 }'
echo
echo "Measured on \`$ref\` at $(git -C "$top" rev-parse --short "$ref"), $(grep -c . <<<"$rows") code files."
moved=$(git -C "$top" log --since=60.days -M --diff-filter=R --name-only --format= "$ref" -- "$path" | grep -c . || true)
[ "$moved" -eq 0 ] || echo "Paths moved in 60 days: $moved. Their commits count from the move."
