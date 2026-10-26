#!/usr/bin/env bash
# Keeps an issue open when a pull request merges: removes the pull request's
# link that would close it. A pull request from a branch that worktree.sh
# linked to the issue gets that link when it opens, whatever its description
# says: see Pull requests in SKILL.md.
#
#   keep-open.sh <pr> <n>
#
# DRY_RUN=1 prints the command that would write, and runs none.
# Needs only bash and gh: every filter is gh's own --jq.

set -euo pipefail

[ $# -eq 2 ] && [[ ${1#\#} =~ ^[0-9]+$ && ${2#\#} =~ ^[0-9]+$ ]] || {
  sed -n "s/^#   ${0##*/}/usage: ${0##*/}/p" "$0" >&2
  exit 2
}
pr=${1#\#} n=${2#\#}

run() { if [ "${DRY_RUN:-}" = 1 ]; then echo "dry run:$(printf ' %q' "$@")"; else "$@"; fi; }

# The pull request's id and the issue's, when the pull request closes that
# issue of this repository.
closing() {
  # shellcheck disable=SC2016 # GraphQL and jq, not shell
  N=$n gh api graphql -F owner='{owner}' -F name='{repo}' -F pr="$pr" -f query='
    query($owner: String!, $name: String!, $pr: Int!) {
      repository(owner: $owner, name: $name) { id pullRequest(number: $pr) {
        id closingIssuesReferences(first: 100) { nodes { id number repository { id } } }
      } }
    }' --jq '.data.repository | .id as $repo | .pullRequest | .id as $pr | .closingIssuesReferences.nodes[]
      | select(.number == ($ENV.N | tonumber) and .repository.id == $repo) | "\($pr) \(.id)"'
}
# GitHub adds a linked branch's link about a second after the pull request
# opens, so an empty answer is read again, for about ten seconds.
# KEEP_OPEN_TRIES is for the tests.
for ((try = ${KEEP_OPEN_TRIES:-6}; ; try--)); do
  ids=$(closing)
  [ -z "$ids" ] && [ "$try" -gt 1 ] || break
  sleep 2
done
if [ -z "$ids" ]; then
  echo "PR #$pr does not close #$n: nothing to do"
  exit 0
fi
# shellcheck disable=SC2016 # GraphQL, not shell
run gh api graphql --silent -f pr="${ids% *}" -f issue="${ids#* }" \
  -f query='mutation($pr: ID!, $issue: ID!) { removeCloseIssueReferences(input: {issueId: $issue, pullRequestIds: [$pr]}) { clientMutationId } }'
[ "${DRY_RUN:-}" = 1 ] || echo "PR #$pr no longer closes #$n"
