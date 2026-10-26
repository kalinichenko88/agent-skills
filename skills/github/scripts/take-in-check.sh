#!/usr/bin/env bash
# Says whether an issue can be taken into work: prints "take #<n>" and exits 0,
# or prints each reason why not and exits 1. It only reads.
#
#   take-in-check.sh <n or URL>
#
# The reasons: an issue in another repository than this checkout's, a closed
# issue, an assignee, a linked branch, and an open pull request that closes the
# issue. Your own assignee and pull request are reasons too, with the login
# "you": another session of yours, on this computer or on another one, can work
# on the issue.
#
# Needs only bash and gh: every filter is gh's own --jq.

set -euo pipefail

[ $# -eq 1 ] || {
  echo 'usage: take-in-check.sh <n or URL>' >&2
  exit 2
}
repo=$(gh api 'repos/{owner}/{repo}' --jq .full_name)
shopt -s nocasematch # GitHub's owner and repository names ignore case

case $1 in
  http*/issues/*)
    there=${1#*://*/}
    there=${there%%/issues/*}
    n=${1##*/issues/}
    n=${n%%[!0-9]*}
    if [[ $there != "$repo" ]]; then
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
    repository(owner: $owner, name: $name) {
      defaultBranchRef { name }
      issue(number: $n) {
        state
        assignees(first: 10) { nodes { login } }
        linkedBranches(first: 10) { nodes { ref {
          name
          target { ... on Commit { committedDate } }
          compare(headRef: "HEAD") { behindBy }
        } } }
        closedByPullRequestsReferences(first: 10) { nodes { number state author { login } } }
      }
    }
  }' --jq '.data.viewer.login as $me | .data.repository.defaultBranchRef.name as $main
    | def who: if . == $me then "you" else . // "ghost" end;
    .data.repository.issue
    | (select(.state != "OPEN") | "closed"),
      (.assignees.nodes[] | "assigned to \(.login | who)"),
      (.linkedBranches.nodes[].ref | select(.)
        | "branch \(.name), \(.compare.behindBy) commits ahead of \($main), last commit \(.target.committedDate)"),
      (.closedByPullRequestsReferences.nodes[] | select(.state == "OPEN")
        | "PR #\(.number) by \(.author.login | who) is open and closes it")')

if [ -z "$reasons" ]; then
  echo "take #$n"
  exit 0
fi
while IFS= read -r reason; do echo "#$n: $reason"; done <<<"$reasons"
exit 1
