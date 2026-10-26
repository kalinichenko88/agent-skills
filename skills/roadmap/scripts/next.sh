#!/usr/bin/env bash
# Prints the free tasks per track, ranked — main path, bugs, secondary — and
# the work in progress, then writes the overlap file for the lanes.md reader
# and prints its path and size as its last line.
#
#   next.sh [bug-label]
#
# The label defaults to bug. The file holds each candidate's body and the
# paths it cites, and the files of each piece of work in progress: an open
# PR's files (past 100, the whole list from REST), else the compare of each
# linked branch with the default branch; an issue with neither gets "no diff
# yet" and its body.
#
# Needs only bash, gh and awk.

set -euo pipefail

[ $# -le 1 ] || {
  sed -n "s/^#   ${0##*/}/usage: ${0##*/}/p" "$0" >&2
  exit 2
}
dir=$(dirname "$0")

prs=$(bash "$dir/read.sh" prs)
while read -r n; do
  files=$(gh api "repos/{owner}/{repo}/pulls/$n/files?per_page=100" --paginate --jq '.[].filename' | paste -sd, -)
  # Through ENVIRON, not -v, which would read a backslash in a path as an escape.
  prs=$(F=$files awk -F'\t' -v OFS='\t' -v n="$n" '$1 == "pr" && $2 == n { $5 = ENVIRON["F"] } 1' <<<"$prs")
done < <(awk -F'\t' '$1 == "pr" && $6 > 100 { print $2 }' <<<"$prs")
list=$(bash "$dir/read.sh" milestones)
issues=$(bash "$dir/read.sh" issues "${1:-bug}")
out=$(printf '%s\n%s\n%s\n' "$list" "$issues" "$prs" | awk -F'\t' -f "$dir/graph.awk" -f "$dir/next.awk")

# The paths a body cites: tokens with a / that end in .<extension>, URLs left out.
cites() {
  awk '{
    line = $0
    gsub(/https?:\/\/[^ \t)]*/, "", line)
    while (match(line, /[A-Za-z0-9_.\/-]+/)) {
      tok = substr(line, RSTART, RLENGTH)
      line = substr(line, RSTART + RLENGTH)
      sub(/\.+$/, "", tok)
      if (tok ~ /\// && tok ~ /\.[A-Za-z0-9]+$/ && !(tok in seen)) { seen[tok] = 1; all = all (all == "" ? "" : ", ") tok }
    }
  } END { if (all != "") print "cites: " all }'
}
# A body line that starts with == gets a space before it: in the file, == starts
# a section or an entry.
# ponytail: one gh call per body, about a second each; one aliased GraphQL query if the file gets slow.
body() { gh issue view "$1" --json body --jq .body | sed 's/^==/ ==/'; }
default=''
# A branch that cannot be compared, as one in a fork, has no diff yet.
diff_of() {
  local b
  for b in ${1//,/ }; do
    gh api "repos/{owner}/{repo}/compare/$default...$b" --jq '.files[]?.filename' 2>/dev/null || true
  done | awk '!seen[$0]++' | paste -sd, -
}

file=$(mktemp "${TMPDIR:-/tmp}/next.XXXXXX")
{
  echo '== Candidates'
  while IFS=$'\t' read -r _ _ n title track ms; do
    echo "==> #$n $title [$track, $ms]"
    text=$(body "$n")
    cites <<<"$text"
    printf '%s\n' "$text"
  done < <(grep '^want	cand	' <<<"$out" || true)
  echo '== Work in progress'
  # wip: title, busy, files, branches; pr: author, files.
  while IFS=$'\t' read -r _ kind n a b c d; do
    if [ "$kind" = pr ]; then
      echo "==> PR #$n by $a"
      [ "$b" = - ] || echo "files: ${b//,/, }"
      continue
    fi
    echo "==> #$n $a [$b]"
    files=$c
    if [ "$files" = - ] && [ "$d" != - ]; then
      [ -n "$default" ] || default=$(gh api 'repos/{owner}/{repo}' --jq .default_branch)
      files=$(diff_of "$d")
    fi
    if [ -n "$files" ] && [ "$files" != - ]; then
      echo "files: ${files//,/, }"
    else
      echo 'no diff yet'
      body "$n"
    fi
  done < <(grep -E '^want	(wip|pr)	' <<<"$out" || true)
  echo '== end'
} >"$file"

grep -v '^want	' <<<"$out" || true
echo "overlap: $file ($((($(wc -c <"$file") + 1023) / 1024)) KB)"
