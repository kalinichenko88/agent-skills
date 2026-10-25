#!/usr/bin/env bash
# Adds a finding to an open issue, its host: appends the section to the body,
# sets the new title, adds the label and leaves a one-line comment.
#
#   add-finding.sh <n> <section-file> <title> [label]
#
# The section file starts with the line "## Also: <the problem>". The host must
# be an open issue that nobody else works on (collect.sh status says taken: no)
# and that holds fewer than two added findings. All of this is read again just
# before the write. Otherwise it prints why and exits 1, and writes nothing.
# Run it for one host at a time: it reads the body and writes it back whole.
# When the comment or the label fails, run the same command again. A body that
# holds the section already skips the check for a full host and stays as it
# is: the rerun sets the title and the label again and comments.
#
# DRY_RUN=1 prints the commands that would write, and runs none. It keeps the
# new body in the file that the printed command names.
# Needs only bash and gh: every filter is gh's own --jq.

set -euo pipefail

[ $# -eq 3 ] || [ $# -eq 4 ] || {
  echo 'usage: add-finding.sh <n> <section-file> <title> [label]' >&2
  exit 2
}
n=${1#\#} section=$2 title=$3 label=${4:-}

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

host=$(bash "$(dirname "$0")/collect.sh" status "$n")
# A pull request gives the state: line only.
{ read -r _ state; read -r _ status; read -r _ also; read -r _ taken; } <<<"$host" || true

[ "$state" = open ] || refuse "it is $state"
[ "$taken" = no ] || refuse "someone works on it: $status"

tmp=${TMPDIR:-/tmp}
body=$(mktemp "${tmp%/}/body.XXXXXX")
# bash 3.2 runs this trap with $? at 0 when set -u stops the script, so a run
# passes only when it set finished at its end.
clean() {
  local code=$?
  [ "$code" != 0 ] || [ -n "${finished:-}" ] || code=1
  # A dry run that finished keeps the new body to be read.
  if [ "${DRY_RUN:-}" != 1 ] || [ "$code" != 0 ]; then rm -f "$body"; fi
  exit "$code"
}
finished=
trap clean EXIT
gh issue view "$n" --json body --jq .body >"$body"

args=(issue edit "$n" --title "$title")
# A body that holds the section already is a rerun after a failed comment or
# label: gh writes the label apart from the body. The title and the label are
# set again, and the body stays.
if ! grep -qxF "## Also: $problem" "$body"; then
  [ "$also" -lt 2 ] || refuse "it holds $also added findings already"
  { echo; cat "$section"; } >>"$body"
  args+=(--body-file "$body")
fi
[ -z "$label" ] || args+=(--add-label "$label")
run gh "${args[@]}"
run gh issue comment "$n" --body "Added to the body: $problem."
finished=1
