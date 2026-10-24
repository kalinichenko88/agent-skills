#!/usr/bin/env bash
# Finds the clones of 8 lines or more in the code files of a checkout with the
# newest jscpd, and prints them longest first as a Markdown table: each file
# from the checkout's root, with its lines.
#
#   clones.sh <tree> [path]
#
# <tree> is a checkout made only to be read, and the path is from its root;
# without one, the whole tree. The runner is bunx when <tree> has a bun.lock,
# else npx. jscpd runs in a new temporary directory, not in <tree>: npm reads
# the .npmrc of the nearest directory with a package.json, and a project's
# .npmrc can run the project's code. So jscpd reads no .jscpd.json of the
# project either, and its settings are the same in every project. Documents,
# lockfiles and fixtures are left out, by the data rule of measure.sh.
#
# Needs bash, and the node or bun that the runner brings.

set -euo pipefail

[ $# -ge 1 ] && [ $# -le 2 ] || {
  echo 'usage: clones.sh <tree> [path]' >&2
  exit 2
}
data=$(<"$(dirname "$0")/data.ere")
tree=$(cd "$1" && pwd -P)
path=${2:-.}
if [ -e "$tree/bun.lock" ] || [ -e "$tree/bun.lockb" ]; then
  runner=(bunx)
  js=bun
else
  runner=(npx --yes)
  js=node
fi

run=$(mktemp -d)
trap 'rm -rf "$run"' EXIT
(cd "$run" && "${runner[@]}" jscpd@latest --min-lines 8 --absolute --reporters json --output . "$tree/$path" >/dev/null)

# jscpd gives real paths, as pwd -P does: a path outside <tree> stops the run,
# so that no local path reaches an issue.
# shellcheck disable=SC2016 # the ${...} are JavaScript's
DATA=$data TREE=$tree/ "$js" -e '
  const { duplicates } = JSON.parse(require("fs").readFileSync(0, "utf8"));
  const data = new RegExp(process.env.DATA);
  const rel = (name) => {
    if (!name.startsWith(process.env.TREE)) throw new Error(`not in the tree: ${name}`);
    return name.slice(process.env.TREE.length);
  };
  const rows = duplicates
    .map((d) => ({ lines: d.lines, files: [d.firstFile, d.secondFile].map((f) => ({ ...f, name: rel(f.name) })) }))
    .filter((d) => d.files.every((f) => !data.test(f.name)))
    .sort((a, b) => b.lines - a.lines || a.files[0].name.localeCompare(b.files[0].name))
    .map((d) => `| ${d.lines} | ${d.files.map((f) => `\`${f.name}\` ${f.start}-${f.end}`).join(" | ")} |`);
  console.log(rows.length ? ["| Lines | File | Other file |", "| ---: | --- | --- |", ...rows].join("\n") : "No clones of 8 lines or more in code files.");
' <"$run/jscpd-report.json"
