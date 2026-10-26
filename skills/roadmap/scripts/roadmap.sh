#!/usr/bin/env bash
# Prints the roadmap, read from GitHub now: each open milestone in order, with
# its progress, its description and its open issues in dependency order, each
# with its state. Later shows titles only. Issues with no milestone show as a
# count with their numbers.
#
#   roadmap.sh [milestone]
#
# With a milestone (M1, Later, a whole title), it prints that milestone alone,
# with the open issues it waits on in other milestones.
#
# Needs only bash, gh and awk.

set -euo pipefail

[ $# -le 1 ] || {
  sed -n "s/^#   ${0##*/}/usage: ${0##*/}/p" "$0" >&2
  exit 2
}
dir=$(dirname "$0")

only=''
if [ $# -eq 1 ]; then
  only=$(bash "$dir/read.sh" milestone "$1")
  only=${only%%$'\t'*}
fi
# Each read stops the script when it fails: a part of the plan is a false plan.
list=$(bash "$dir/read.sh" milestones)
counts=$(bash "$dir/read.sh" counts)
issues=$(bash "$dir/read.sh" issues)
printf '%s\n%s\n%s\n' "$list" "$counts" "$issues" | awk -F'\t' -v only="$only" -f "$dir/graph.awk" -f "$dir/roadmap.awk"
