#!/bin/bash
# Reads the plan from GitHub and prints it as tab-separated records, one per
# line, for the awk programs next to it.
#
#   read.sh issues [bug-label]   the open issues (the label defaults to bug)
#   read.sh milestones           the open milestones, in order
#   read.sh milestone <name>     the number and title of one open milestone
#   read.sh prs                  the open pull requests
#
# The records:
#
#   repo  <owner/name>
#   me    <login>
#   is    <n> <milestone|0> <bug 1|0> <busy|-> <open blockers|-> <parent|0>
#         <parent's milestone|0> <open sub-issues> <title>
#   br    <n> <linked branch>
#   ms    <n> <order> <current 1|0> <later 1|0> <open> <closed> <title>
#   md    <n> <description line>
#   pr    <n> <author|you> <closed issues|-> <files|-> <file count>
#
# Busy is in collect.sh's words: "assigned to <login>", "branch <name>", "PR #<n>
# by <login>", with you for the account gh is logged in as. A blocker or a
# parent in another repository is written <owner/repo>#<n>, and its parent as 0.
# The order of a milestone is <k> for a title M<k>, 100000 + its number for
# another title, and 1000000000 for Later. A milestone is current when a line
# of its description reads Current.; when none does, the first one that is not
# Later is.
#
# Needs only bash and gh: every filter is gh's own --jq, which runs on each
# page. So the records go to awk, which sees every page.

# shellcheck disable=SC2016 # the single-quoted $ are jq's and GraphQL's
set -euo pipefail

usage() {
  echo 'usage: read.sh issues [bug-label] | milestones | milestone <name> | prs' >&2
  exit 2
}
[ $# -ge 1 ] || usage

# The one page of open milestones, with their order and current mark.
# ponytail: 100 open milestones at most; paginate if a project ever has more.
milestones='def later: .title | ascii_downcase == "later";
def order: if later then 1000000000
  elif (.title | test("^M[0-9]+([^0-9]|$)")) then (.title | capture("^M(?<k>[0-9]+)").k | tonumber)
  else 100000 + .number end;
def lines: (.description // "") | gsub("\r"; "") | split("\n") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != ""));
map(. + {order: order, later: later, lines: lines})
| map(.marked = ((.later | not) and any(.lines[]; . == "Current.")))
| sort_by(.order)'

case $1 in
  issues)
    [ $# -le 2 ] || usage
    query='query($owner: String!, $name: String!, $endCursor: String) {
  viewer { login }
  repository(owner: $owner, name: $name) {
    nameWithOwner
    issues(states: OPEN, first: 100, after: $endCursor) {
      pageInfo { hasNextPage endCursor }
      nodes {
        number title
        labels(first: 20) { nodes { name } }
        milestone { number }
        assignees(first: 10) { nodes { login } }
        linkedBranches(first: 10) { nodes { ref { name } } }
        closedByPullRequestsReferences(first: 10) { nodes { number state author { login } } }
        blockedBy(first: 50) { nodes { number state repository { nameWithOwner } } }
        parent { number milestone { number } repository { nameWithOwner } }
        subIssuesSummary { total completed }
      }
    }
  }
}'
    BUG=${2:-bug} gh api graphql --paginate -F owner='{owner}' -F name='{repo}' -f query="$query" --jq '
      .data.viewer.login as $me | .data.repository.nameWithOwner as $repo
      | def who: if . == null then "ghost" elif .login == $me then "you" else .login end;
        def dash: if . == "" then "-" else . end;
      (["repo", $repo] | @tsv), (["me", $me] | @tsv),
      (.data.repository.issues.nodes[] | . as $i
        | ([(.assignees.nodes[] | "assigned to " + (. | who)),
            (.linkedBranches.nodes[] | select(.ref) | "branch " + .ref.name),
            (.closedByPullRequestsReferences.nodes[] | select(.state == "OPEN") | "PR #\(.number) by " + (.author | who))]
           | join(", ") | dash) as $busy
        | ([.blockedBy.nodes[] | select(.state == "OPEN")
            | (if .repository.nameWithOwner == $repo then "" else .repository.nameWithOwner end) + "#\(.number)"]
           | join(",") | dash) as $blockers
        | (.parent != null and .parent.repository.nameWithOwner == $repo) as $local
        | (["is", .number, (.milestone.number // 0), (if any(.labels.nodes[]; .name == $ENV.BUG) then 1 else 0 end),
            $busy, $blockers, (if $local then .parent.number else 0 end),
            (if $local then .parent.milestone.number // 0 else 0 end),
            (.subIssuesSummary.total - .subIssuesSummary.completed), .title] | @tsv),
          (.linkedBranches.nodes[] | select(.ref) | ["br", $i.number, .ref.name] | @tsv))'
    ;;
  milestones)
    [ $# -eq 1 ] || usage
    gh api 'repos/{owner}/{repo}/milestones?state=open&per_page=100' --jq "$milestones"'
      | (any(.[]; .marked)) as $any | (map(select(.later | not)) | .[0].number) as $first
      | (.[] | ["ms", .number, .order, (if .marked or (($any | not) and .number == $first) then 1 else 0 end),
          (if .later then 1 else 0 end), .open_issues, .closed_issues, .title] | @tsv),
        (.[] | .number as $n | .lines[] | select(. != "Current.") | ["md", $n, .] | @tsv)'
    ;;
  milestone)
    [ $# -eq 2 ] || usage
    found=$(NAME=$2 gh api 'repos/{owner}/{repo}/milestones?state=open&per_page=100' --jq "$milestones"'
      | ($ENV.NAME | ascii_downcase) as $q
      | .[] | (.title | ascii_downcase) as $t
      | select($t == $q or (($q | test("^m[0-9]+$")) and ($t | startswith($q)) and ($t | .[($q | length):] | test("^([^0-9]|$)"))))
      | [.number, .title] | @tsv')
    [ -n "$found" ] || {
      echo "read.sh: no open milestone matches $2" >&2
      exit 1
    }
    echo "${found%%$'\n'*}"
    ;;
  prs)
    [ $# -eq 1 ] || usage
    query='query($owner: String!, $name: String!, $endCursor: String) {
  viewer { login }
  repository(owner: $owner, name: $name) {
    nameWithOwner
    pullRequests(states: OPEN, first: 50, after: $endCursor) {
      pageInfo { hasNextPage endCursor }
      nodes {
        number
        author { login }
        closingIssuesReferences(first: 20) { nodes { number repository { nameWithOwner } } }
        files(first: 100) { totalCount nodes { path } }
      }
    }
  }
}'
    gh api graphql --paginate -F owner='{owner}' -F name='{repo}' -f query="$query" --jq '
      .data.viewer.login as $me | .data.repository.nameWithOwner as $repo
      | def dash: if . == "" then "-" else . end;
      (["me", $me] | @tsv),
      (.data.repository.pullRequests.nodes[]
        | ["pr", .number, (if .author == null then "ghost" elif .author.login == $me then "you" else .author.login end),
           ([.closingIssuesReferences.nodes[] | select(.repository.nameWithOwner == $repo) | .number | tostring] | join(",") | dash),
           ([.files.nodes[].path] | join(",") | dash), .files.totalCount] | @tsv)'
    ;;
  *) usage ;;
esac
