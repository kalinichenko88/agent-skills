#!/bin/bash
# Removes the link between an issue and a branch, so that a pull request from
# the branch leaves the issue open when it merges. The branch stays.
#
#   unlink-branch.sh <n> <branch>
#
# Run it before gh pr create, for a pull request that says Part of #<n> and
# comes from a branch that worktree.sh linked to #<n>. When the pull request
# opens, GitHub turns the branch's link into a link of the pull request, which
# closes the issue on merge whatever the description says. No API removes
# that link.
#
# DRY_RUN=1 prints the command that would write, and runs none.
# Needs only bash and gh: every filter is gh's own --jq.

set -euo pipefail

[ $# -eq 2 ] || {
  echo 'usage: unlink-branch.sh <n> <branch>' >&2
  exit 2
}
n=${1#\#} branch=$2
case $n in '' | *[!0-9]*)
  echo "unlink-branch.sh: not an issue number: $1" >&2
  exit 2
  ;;
esac

run() { if [ "${DRY_RUN:-}" = 1 ]; then echo "dry run:$(printf ' %q' "$@")"; else "$@"; fi; }

repo=$(gh api 'repos/{owner}/{repo}' --jq .full_name)
# shellcheck disable=SC2016 # GraphQL and jq, not shell
links=$(gh api graphql -f owner="${repo%/*}" -f name="${repo#*/}" -F n="$n" -f query='
  query($owner: String!, $name: String!, $n: Int!) {
    repository(owner: $owner, name: $name) { issue(number: $n) {
      linkedBranches(first: 100) { nodes { id ref { name } } }
    } }
  }' --jq '.data.repository.issue.linkedBranches.nodes[] | "\(.id) \(.ref.name // "")"')

id=''
while read -r link name; do
  if [ "$name" = "$branch" ]; then id=$link; fi
done <<<"$links"
if [ -z "$id" ]; then
  echo "#$n has no link to $branch: nothing to do"
  exit 0
fi
# shellcheck disable=SC2016
run gh api graphql --silent -f id="$id" \
  -f query='mutation($id: ID!) { deleteLinkedBranch(input: {linkedBranchId: $id}) { clientMutationId } }'
[ "${DRY_RUN:-}" = 1 ] || echo "#$n is no longer linked to $branch"
