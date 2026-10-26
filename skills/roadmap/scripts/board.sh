#!/usr/bin/env bash
# Sets up the GitHub Project that shows the plan: finds the project titled
# "<repository> roadmap", or creates it under the repository's owner; links
# it to the repository; adds the open issues it does not hold yet; creates
# its saved views. Then it prints the two settings the API cannot make.
#
#   board.sh
#
# It looks among the projects linked to the repository first, then among the
# owner's. It takes no project of another title: views would land on a board
# that someone else owns. Running it again only adds what is missing.
#
# Needs the project scope on the gh token: gh auth refresh -s project.
# DRY_RUN=1 prints the commands that would write, and runs none.
# Needs only bash, gh and awk: every filter of gh's JSON is gh's own --jq.

# shellcheck disable=SC2016 # the single-quoted $ are jq's and GraphQL's
set -euo pipefail

[ $# -eq 0 ] || {
  sed -n "s/^#   ${0##*/}/usage: ${0##*/}/p" "$0" >&2
  exit 2
}
run() { if [ "${DRY_RUN:-}" = 1 ]; then echo "dry run:$(printf ' %q' "$@")"; else "$@"; fi; }

repo=$(gh api 'repos/{owner}/{repo}' --jq .full_name)
owner=${repo%/*} name=${repo#*/}
export TITLE="$name roadmap" REPO=$repo

found=$(gh api graphql -F owner='{owner}' -F name='{repo}' -f query='
  query($owner: String!, $name: String!) {
    repository(owner: $owner, name: $name) { projectsV2(first: 100) { nodes { number title url closed } } }
  }' --jq '.data.repository.projectsV2.nodes[] | select((.closed | not) and .title == $ENV.TITLE) | "\(.number)\t\(.url)"')
link=''
if [ -z "$found" ]; then
  found=$(gh project list --owner "$owner" --limit 1000 --format json \
    --jq '.projects[] | select((.closed | not) and .title == $ENV.TITLE) | "\(.number)\t\(.url)"')
  link=1
fi
found=${found%%$'\n'*}
if [ -z "$found" ]; then
  if [ "${DRY_RUN:-}" = 1 ]; then
    run gh project create --owner "$owner" --title "$TITLE" --format json
    run gh project link NEW --owner "$owner" --repo "$name"
    echo 'dry run: no project yet, so no items and no views'
    url='the new project'
  else
    found=$(gh project create --owner "$owner" --title "$TITLE" --format json --jq '"\(.number)\t\(.url)"' 2>&1) || {
      echo "cannot create a project under $owner: $found"
      exit 1
    }
  fi
fi

if [ -n "$found" ]; then
  number=${found%%$'\t'*} url=${found#*$'\t'}
  echo "project: $url"
  if [ -n "$link" ]; then
    run gh project link "$number" --owner "$owner" --repo "$name"
    echo "linked $repo"
  fi

  held=$(gh project item-list "$number" --owner "$owner" --limit 1000 --format json \
    --jq '.items[].content | select(.repository == $ENV.REPO) | .number')
  missing=$(gh issue list --state open --limit 1000 --json number,url --jq '.[] | "\(.number)\t\(.url)"' |
    awk -F'\t' 'NR == FNR { held[$1] = 1; next } !($1 in held) { print $2 }' <(printf '%s\n' "$held") -)
  echo "issues to add: $(grep -c . <<<"$missing" || true)"
  for u in $missing; do run gh project item-add "$number" --owner "$owner" --url "$u"; done

  id=$(gh project view "$number" --owner "$owner" --format json --jq .id)
  views=$(gh api graphql -f id="$id" -f query='
    query($id: ID!) { node(id: $id) { ... on ProjectV2 { views(first: 20) { nodes { id name filter } } } } }' \
    --jq '.data.node.views.nodes[] | "\(.name)\t\(.id)\t\(.filter // "")"')
  while IFS='|' read -r view layout filter; do
    # A view there keeps its filter; one without a filter, as after a run that
    # stopped between the two writes, gets it.
    vid=$(awk -F'\t' -v v="$view" '$1 == v { print $2 "\t" $3; exit }' <<<"$views")
    if [ -n "${vid#*$'\t'}" ]; then
      echo "view $view: there"
      continue
    elif [ -n "$vid" ]; then
      echo "view $view: no filter"
      vid=${vid%%$'\t'*}
    else
      echo "view $view: missing"
      create=(gh api graphql -f project="$id" -f name="$view" -f layout="$layout" -f query='
        mutation($project: ID!, $name: String!, $layout: ProjectV2ViewLayout!) {
          createProjectV2View(input: {projectId: $project, name: $name, layout: $layout}) { projectV2View { id } } }')
      if [ "${DRY_RUN:-}" = 1 ]; then
        run "${create[@]}"
        vid=VIEW_ID
      else
        vid=$("${create[@]}" --jq .data.createProjectV2View.projectV2View.id)
      fi
    fi
    run gh api graphql --silent -f view="$vid" -f filter="$filter" -f query='
      mutation($view: ID!, $filter: String!) {
        updateProjectV2View(input: {viewId: $view, filter: $filter}) { projectV2View { id } } }'
  done <<'EOF'
Unassigned|BOARD_LAYOUT|is:issue is:open no:assignee -milestone:Later
By milestone|TABLE_LAYOUT|is:issue is:open
EOF
fi

cat <<EOF
Two settings the API cannot make. Open $url:
1. In the view "By milestone", group by Milestone.
2. Under Workflows, turn on "Auto-add to project" for $repo with the filter is:issue is:open.
EOF
