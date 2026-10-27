#!/usr/bin/env bash
# Assigns an issue to you, checks out its branch in a worktree of its own (or,
# with --here, in the current checkout), links the branch to the issue, and
# prints the path to work in as its last line.
#
#   worktree.sh <n> <branch> [--here]
#
# An issue with a linked branch in this repository and no assignee gets a
# warning instead: the branch can be someone else's.
#
# A branch linked to the issue in this repository wins over a <branch> that is
# not linked there: the first such branch that gh lists. When every linked
# branch is in another repository, as a fork's, the script stops before it
# writes. A branch already checked out somewhere is worked on there. A session
# already in a worktree, as one started with claude --worktree or codex
# --worktree, checks the branch out where it is; --here does the same in any
# checkout, for "a branch only".
#
# DRY_RUN=1 prints the commands that would write, and runs none.
# Needs only bash, gh, git and awk.

set -euo pipefail

[ $# -eq 2 ] || { [ $# -eq 3 ] && [ "$3" = --here ]; } || {
  sed -n "s/^#   ${0##*/}/usage: ${0##*/}/p" "$0" >&2
  exit 2
}
n=$1 branch=$2 here=${3:-}

run() { if [ "${DRY_RUN:-}" = 1 ]; then echo "dry run:$(printf ' %q' "$@")"; else "$@"; fi; }

# Without --branch-repo, gh makes a new branch of a linked branch's name in
# this repository, so only this repository's linked branches count. When every
# linked branch is in another repository, the script stops and the person
# decides.
list=$(gh issue develop --list "$n")
linked=''
if [ -n "$list" ]; then
  repo=$(gh api 'repos/{owner}/{repo}' --jq .full_name)
  linked=$(awk -F'\t' -v r="/$repo/tree/" '{ s = r $1 } substr($2, length($2) - length(s) + 1) == s { print $1 }' <<<"$list")
  if [ -z "$linked" ]; then
    echo "#$n is linked only to branches in another repository:" >&2
    cut -f2 <<<"$list" >&2
    exit 1
  fi
fi

# When the issue has an assignee, its linked branch counts as yours:
# take-in-check.sh stops on every assignee, and the take-in goes on only when
# the only assignee is you and the person says that the work continues here.
# GitHub does not say whose a branch is: one that is linked while nobody is
# assigned can be someone else's, so you decide.
# Read outside the if, so that a failed read stops the script.
assignees=1
if [ -n "$linked" ]; then
  assignees=$(gh issue view "$n" --json assignees --jq '.assignees | length')
fi
if [ "$assignees" = 0 ]; then
  echo "warning: #$n has a linked branch and nobody is assigned: it can be someone else's."
  echo "It is not assigned to you. If the branch is yours: gh issue edit $n --add-assignee @me"
else
  run gh issue edit "$n" --add-assignee @me
fi
case $'\n'$linked$'\n' in
  *$'\n'"$branch"$'\n'* | $'\n\n') ;;
  *)
    branch=${linked%%$'\n'*}
    echo "#$n is linked to the branch $branch already: using it"
    ;;
esac

path=$(git for-each-ref --format='%(worktreepath)' "refs/heads/$branch")
if [ -n "$path" ]; then
  echo "$branch is checked out already"
  echo "$path"
  exit 0
fi

common=$(git rev-parse --path-format=absolute --git-common-dir)
if [ -n "$here" ] || [ "$(git rev-parse --path-format=absolute --git-dir)" != "$common" ]; then
  run gh issue develop "$n" --name "$branch" --checkout
  git rev-parse --show-toplevel
  exit 0
fi

path="$(git rev-parse --show-toplevel)/.claude/worktrees/$branch"
case $(gh issue develop --help) in
  *--worktree*)
    run gh issue develop "$n" --name "$branch" --checkout --worktree "$path"
    ;;
  *) # gh older than 2.99
    run gh issue develop "$n" --name "$branch"
    run git fetch origin "$branch"
    run git worktree add "$path" "$branch"
    ;;
esac

# Keeps git add -A in the main checkout from recording the worktree as an
# embedded repository.
exclude=$common/info/exclude
if ! grep -qxF .claude/worktrees/ "$exclude" 2>/dev/null; then
  if [ "${DRY_RUN:-}" = 1 ]; then
    echo "dry run: echo .claude/worktrees/ >>$exclude"
  else
    mkdir -p "$common/info"
    echo .claude/worktrees/ >>"$exclude"
  fi
fi
echo "$path"
