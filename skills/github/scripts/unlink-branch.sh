#!/bin/bash
# Removes the link between an issue and a branch, so that a pull request from
# the branch leaves the issue open when it merges. The branch stays.
#
#   unlink-branch.sh <n> <branch>
#
# Run it before gh pr create for a Part of PR: see Pull requests in SKILL.md.
#
# DRY_RUN=1 prints the command that would write, and runs none.
# Needs only bash and gh: every filter is gh's own --jq.

set -euo pipefail

[ $# -eq 2 ] || {
  echo 'usage: unlink-branch.sh <n> <branch>' >&2
  exit 2
}
n=${1#\#} branch=$2

run() { if [ "${DRY_RUN:-}" = 1 ]; then echo "dry run:$(printf ' %q' "$@")"; else "$@"; fi; }

# shellcheck disable=SC2016 # GraphQL and jq, not shell
links=$(gh api graphql -F owner='{owner}' -F name='{repo}' -F n="$n" -f query='
  query($owner: String!, $name: String!, $n: Int!) {
    repository(owner: $owner, name: $name) { issue(number: $n) {
      linkedBranches(first: 100) { nodes { id ref { name } } }
    } }
  }' --jq '.data.repository.issue.linkedBranches.nodes[] | "\(.id) \(.ref.name // "")"')

id=$(awk -v b="$branch" '$2 == b { print $1 }' <<<"$links")
if [ -z "$id" ]; then
  echo "#$n has no link to $branch: nothing to do"
  exit 0
fi
# shellcheck disable=SC2016
run gh api graphql --silent -f id="$id" \
  -f query='mutation($id: ID!) { deleteLinkedBranch(input: {linkedBranchId: $id}) { clientMutationId } }'
[ "${DRY_RUN:-}" = 1 ] || echo "#$n is no longer linked to $branch"
