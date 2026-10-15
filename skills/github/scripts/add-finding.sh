#!/bin/bash
# Adds a finding to an open issue, its host: appends the section to the body,
# sets the new title, adds the label and leaves a one-line comment.
#
#   add-finding.sh <n> <section-file> <title> [label]
#
# The section file starts with the line "## Also: <the problem>". The host must
# be open, free or assigned only to you, and hold fewer than two added
# findings; all three are read again just before the write. Otherwise it
# prints why and exits 1, and writes nothing.
#
# DRY_RUN=1 prints the commands that would write, and runs none. It keeps the
# new body in the file that the printed command names.
# Needs only bash and gh: every filter is gh's own --jq.

set -euo pipefail

[ $# -eq 3 ] || [ $# -eq 4 ] || {
  echo 'usage: add-finding.sh <n> <section-file> <title> [label]' >&2
  exit 2
}
n=$1 section=$2 title=$3 label=${4:-}

run() { if [ "${DRY_RUN:-}" = 1 ]; then echo "dry run:$(printf ' %q' "$@")"; else "$@"; fi; }
refuse() {
  echo "#$n: $1: file a new issue that says Related to #$n, and comment on #$n"
  exit 1
}

problem=$(sed -n '1s/^## Also: //p' "$section")
[ -n "$problem" ] || {
  echo "add-finding.sh: $section must start with \"## Also: <the problem>\"" >&2
  exit 2
}

me=$(gh api user --jq .login)
host=$(bash "$(dirname "$0")/collect.sh" status "$n")
{ read -r _ state; read -r _ status; read -r _ also; } <<<"$host"

[ "$state" = open ] || refuse "it is $state"
[ "$status" = free ] || [ "$status" = "assigned to $me" ] || refuse "someone works on it: $status"
[ "$also" -lt 2 ] || refuse "it holds $also added findings already"

tmp=${TMPDIR:-/tmp}
body=$(mktemp "${tmp%/}/body.XXXXXX")
# A dry run keeps the new body to be read.
[ "${DRY_RUN:-}" = 1 ] || trap 'rm -f "$body"' EXIT
gh issue view "$n" --json body --jq .body >"$body"
{ echo; cat "$section"; } >>"$body"

args=(issue edit "$n" --title "$title" --body-file "$body")
[ -z "$label" ] || args+=(--add-label "$label")
run gh "${args[@]}"
run gh issue comment "$n" --body "Added to the body: $problem."
