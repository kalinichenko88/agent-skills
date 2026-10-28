#!/usr/bin/env bash
# Says whether an issue can be taken into work: prints "take #<n>" and exits 0,
# or prints each reason why not and exits 1, unless the reasons show that the
# work continues on this computer (below). It only reads.
#
#   take-in-check.sh <n or URL>
#
# The reasons: an issue in another repository than this checkout's, a closed
# issue, an assignee, a linked branch, and an open pull request that closes the
# issue. Your own login prints as "you": another session of yours, on this
# computer or on another one, can work on the issue.
#
# When every reason is your own work on this computer, it prints them, then
# "continue #<n> on <branch>", and exits 0. That is: the issue is assigned to
# you, and its one branch, linked or the branch of your open pull request, is a
# local branch here that has the branch's last commit on GitHub.
#
# Needs only bash, gh and git: every filter is gh's own --jq.

set -euo pipefail

[ $# -eq 1 ] || {
  sed -n "s/^#   ${0##*/}/usage: ${0##*/}/p" "$0" >&2
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

# Each line is a reason, a tab, and whose it is: "you", "other", or, for a
# branch of yours in this repository, "branch", its name and its last commit on
# GitHub. When a pull request opens, GitHub moves the branch's link to it, so
# the branch of your open pull request counts as the issue's branch.
# shellcheck disable=SC2016 # GraphQL and jq, not shell
reasons=$(gh api graphql -f owner="${repo%/*}" -f name="${repo#*/}" -F n="$n" -f query='
  query($owner: String!, $name: String!, $n: Int!) {
    viewer { login }
    repository(owner: $owner, name: $name) {
      nameWithOwner
      defaultBranchRef { name }
      issue(number: $n) {
        state
        assignees(first: 10) { nodes { login } }
        linkedBranches(first: 10) { nodes { ref {
          name
          repository { nameWithOwner }
          target { oid ... on Commit { committedDate } }
          compare(headRef: "HEAD") { behindBy }
        } } }
        closedByPullRequestsReferences(first: 10) { nodes {
          number state author { login }
          headRefName headRefOid headRepository { nameWithOwner }
        } }
      }
    }
  }' --jq '.data.viewer.login as $me | .data.repository.nameWithOwner as $repo
    | .data.repository.defaultBranchRef.name as $main
    | def who: if . == $me then "you" else . // "ghost" end;
    .data.repository.issue
    | (select(.state != "OPEN") | "closed\tother"),
      (.assignees.nodes[] | (.login | who) as $who
        | "assigned to \($who)\t\(if $who == "you" then "you" else "other" end)"),
      (.linkedBranches.nodes[].ref
        | "branch \(.name), \(.compare.behindBy) commits ahead of \($main), last commit \(.target.committedDate)\t"
          + (if .repository.nameWithOwner == $repo then "branch\t\(.name)\t\(.target.oid)" else "other" end)),
      (.closedByPullRequestsReferences.nodes[] | select(.state == "OPEN")
        | (.author.login | who) as $who
        | "PR #\(.number) by \($who) is open and closes it\t"
          + (if $who == "you" and .headRepository.nameWithOwner == $repo
            then "branch\t\(.headRefName)\t\(.headRefOid)" else "other" end))')

if [ -z "$reasons" ]; then
  echo "take #$n"
  exit 0
fi
# The work continues on this computer when every reason is yours, the issue is
# assigned to you, and they name one branch whose local copy has its last
# commit on GitHub: no other session pushed to it since.
yours='' branch='' here=1
while IFS=$'\t' read -r reason whose name oid; do
  echo "#$n: $reason"
  case $whose in
    you) yours=1 ;;
    branch)
      [ -z "$branch" ] || [ "$branch" = "$name" ] || here=''
      branch=$name
      git merge-base --is-ancestor "$oid" "refs/heads/$name" 2>/dev/null || here=''
      ;;
    *) here='' ;;
  esac
done <<<"$reasons"
if [ -n "$yours" ] && [ -n "$branch" ] && [ -n "$here" ]; then
  echo "continue #$n on $branch"
  exit 0
fi
exit 1
