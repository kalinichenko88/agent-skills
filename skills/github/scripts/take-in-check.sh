#!/bin/bash
# Says whether an issue can be taken into work: prints "take #<n>" and exits 0,
# or prints each reason to wait or stop and exits 1. It only reads.
#
#   take-in-check.sh <n or URL>
#
# The reasons: an issue in another repository than this checkout's, a closed
# issue, an assignee who is not you, and an open pull request that closes the
# issue and that someone else wrote.
#
# Needs only bash and gh: every filter is gh's own --jq.

set -euo pipefail

[ $# -eq 1 ] || {
  echo 'usage: take-in-check.sh <n or URL>' >&2
  exit 2
}
repo=$(gh api 'repos/{owner}/{repo}' --jq .full_name)
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

case $1 in
  http*/issues/*)
    there=${1#*://*/}
    there=${there%%/issues/*}
    n=${1##*/issues/}
    n=${n%%[!0-9]*}
    if [ "$(lower "$there")" != "$(lower "$repo")" ]; then
      echo "#$n is in $there, and this checkout is $repo: stop"
      exit 1
    fi
    ;;
  *) n=${1#\#} ;;
esac
case $n in '' | *[!0-9]*)
  echo "take-in-check.sh: not an issue number or URL: $1" >&2
  exit 2
  ;;
esac

# shellcheck disable=SC2016 # GraphQL and jq, not shell
reasons=$(gh api graphql -f owner="${repo%/*}" -f name="${repo#*/}" -F n="$n" -f query='
  query($owner: String!, $name: String!, $n: Int!) {
    viewer { login }
    repository(owner: $owner, name: $name) { issue(number: $n) {
      state
      assignees(first: 10) { nodes { login } }
      closedByPullRequestsReferences(first: 10) { nodes { number state author { login } } }
    } }
  }' --jq '.data.viewer.login as $me | .data.repository.issue
    | (select(.state != "OPEN") | "closed"),
      (.assignees.nodes[] | select(.login != $me) | "assigned to \(.login)"),
      (.closedByPullRequestsReferences.nodes[]
        | select(.state == "OPEN" and .author.login != $me)
        | "PR #\(.number) by \(.author.login // "ghost") is open and closes it")')

if [ -z "$reasons" ]; then
  echo "take #$n"
  exit 0
fi
while IFS= read -r reason; do echo "#$n: $reason"; done <<<"$reasons"
exit 1
