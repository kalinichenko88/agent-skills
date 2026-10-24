#!/usr/bin/env bash
# Finds the clones of 15 lines or more in the code files of a checkout with
# jscpd, and prints them longest first as a Markdown table: each file from the
# checkout's root, with its lines.
#
#   clones.sh <tree> [path]
#
# <tree> is a checkout made only to be read, and the path is from its root;
# without one, the whole tree. jscpd reads a copy of the text files that git
# tracks there, less the data of measure.sh's rule and SQL: so a document or a
# fixture cannot pair with a code file and hide its clone, and no .jscpd.json
# or .gitignore of the project is read. The copy is in a new temporary
# directory, and the runner and the parser run there, not in <tree>: a
# project's .npmrc or bunfig.toml can run its code. npx gets that directory as
# its --prefix, so that npm reads no .npmrc above it; bun reads a bunfig.toml
# only where it runs. The runner is npx with node, else bunx with bun.
#
# jscpd is pinned to the version that wrote tests/fixtures/debt/jscpd-report.json:
# a new one runs here only on purpose, with the report recorded again.
#
# Needs bash and git, and npx or bunx.

set -euo pipefail
unset CDPATH
jscpd=jscpd@5.4.2

[ $# -ge 1 ] && [ $# -le 2 ] || {
  echo 'usage: clones.sh <tree> [path]' >&2
  exit 2
}
data=$(<"$(dirname "$0")/data.ere")
tree=$(cd "$1" && pwd -P)
path=${2:-.}

# A template, because macOS's mktemp -d alone does not read TMPDIR.
run=$(mktemp -d "${TMPDIR:-/tmp}/clones.XXXXXX")
trap 'rm -rf "$run"' EXIT
run=$(cd "$run" && pwd -P)
if command -v npx >/dev/null; then
  runner=(npx --prefix "$run" --yes)
  js=node
elif command -v bunx >/dev/null; then
  runner=(bunx)
  js=bun
else
  echo 'clones.sh: needs npx or bunx' >&2
  exit 3
fi

# ponytail: a path with a quote, a backslash, a tab or a newline comes out
# quoted, so the data rule does not see its end; -z and NUL records if one
# turns up.
git -c core.quotePath=false -C "$tree" grep -I -l '' -- "$path" >"$run/text" || [ $? -eq 1 ]
grep -Ev "$data|\.sql\$" "$run/text" >"$run/files" || [ $? -eq 1 ]
[ -s "$run/files" ] || {
  echo "No code files under $path." >&2
  exit 1
}
GIT_LFS_SKIP_SMUDGE=1 git -C "$tree" checkout-index --prefix="$run/code/" --stdin <"$run/files"
(cd "$run" && "${runner[@]}" "$jscpd" --min-lines 15 --no-gitignore --absolute --reporters json --output . code >/dev/null)

# jscpd gives real paths, as pwd -P does: a path outside the copy stops the
# run, so that no local path reaches an issue.
# shellcheck disable=SC2016 # the ${...} are JavaScript's
(cd "$run" && ROOT=$run/code/ "$js" -e '
  const { duplicates, statistics } = JSON.parse(require("fs").readFileSync("jscpd-report.json", "utf8"));
  if (!statistics.total.sources) throw new Error("jscpd read no file");
  const rel = (name) => {
    if (!name.startsWith(process.env.ROOT)) throw new Error(`not in the copy: ${name}`);
    return name.slice(process.env.ROOT.length);
  };
  const rows = duplicates
    .sort((a, b) => b.lines - a.lines || (a.firstFile.name < b.firstFile.name ? -1 : a.firstFile.name > b.firstFile.name ? 1 : 0))
    .map((d) => `| ${d.lines} | ${[d.firstFile, d.secondFile].map((f) => `\`${rel(f.name)}\` ${f.start}-${f.end}`).join(" | ")} |`);
  console.log(rows.length ? ["| Lines | File | Other file |", "| ---: | --- | --- |", ...rows].join("\n") : "No clones of 15 lines or more in code files.");
')
