#!/bin/bash
# Checks out the branch of an issue in a worktree of its own, links the branch
# to the issue, and prints the path to work in as its last line.
#
#   worktree.sh <n> <branch>
#
# A branch already linked to the issue wins over <branch>. A branch already
# checked out somewhere is worked on there. A session already in a worktree,
# as one started with claude --worktree or codex --worktree, checks the branch
# out where it is.
#
# DRY_RUN=1 prints the commands that would write, and runs none.

set -euo pipefail

[ $# -eq 2 ] || {
  echo 'usage: worktree.sh <n> <branch>' >&2
  exit 2
}
n=$1 branch=$2

run() { if [ "${DRY_RUN:-}" = 1 ]; then echo "dry run:$(printf ' %q' "$@")"; else "$@"; fi; }

linked=$(gh issue develop --list "$n" | cut -f1 | sed -n 1p)
if [ -n "$linked" ] && [ "$linked" != "$branch" ]; then
  echo "#$n is linked to the branch $linked already: using it"
  branch=$linked
fi

path=$(git for-each-ref --format='%(worktreepath)' "refs/heads/$branch")
if [ -n "$path" ]; then
  echo "$branch is checked out already"
  echo "$path"
  exit 0
fi

common=$(git rev-parse --path-format=absolute --git-common-dir)
if [ "$(git rev-parse --path-format=absolute --git-dir)" != "$common" ]; then
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
