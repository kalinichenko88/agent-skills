#!/bin/bash
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

[ $# -eq 2 ] || {
  echo 'usage: keep-open.sh <pr> <n>' >&2
  exit 2
}
pr=${1#\#} n=${2#\#}

run() { if [ "${DRY_RUN:-}" = 1 ]; then echo "dry run:$(printf ' %q' "$@")"; else "$@"; fi; }

# The pull request's id and the issue's, when the pull request closes it.
# shellcheck disable=SC2016 # GraphQL and jq, not shell
ids=$(N=$n gh api graphql -F owner='{owner}' -F name='{repo}' -F pr="$pr" -f query='
  query($owner: String!, $name: String!, $pr: Int!) {
    repository(owner: $owner, name: $name) { pullRequest(number: $pr) {
      id closingIssuesReferences(first: 50) { nodes { id number } }
    } }
  }' --jq '.data.repository.pullRequest | .id as $pr | .closingIssuesReferences.nodes[]
    | select(.number == ($ENV.N | tonumber)) | "\($pr) \(.id)"')
if [ -z "$ids" ]; then
  echo "PR #$pr does not close #$n: nothing to do"
  exit 0
fi
# shellcheck disable=SC2016
run gh api graphql --silent -f pr="${ids% *}" -f issue="${ids#* }" \
  -f query='mutation($pr: ID!, $issue: ID!) { removeCloseIssueReferences(input: {issueId: $issue, pullRequestIds: [$pr]}) { clientMutationId } }'
[ "${DRY_RUN:-}" = 1 ] || echo "PR #$pr no longer closes #$n"
