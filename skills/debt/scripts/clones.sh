#!/usr/bin/env bash
# Finds the clones of 15 lines or more in the code files of a checkout with the
# newest jscpd, and prints them longest first as a Markdown table: each file
# from the checkout's root, with its lines.
#
#   clones.sh <tree> [path]
#
# <tree> is a checkout made only to be read, and the path is from its root;
# without one, the whole tree. jscpd reads a copy of the files that git tracks
# there, less the data of measure.sh's rule and SQL: so a document or a fixture
# cannot pair with a code file and hide its clone, and no .jscpd.json of the
# project is read. The copy is in a new temporary directory, and the runner and
# the parser run there, not in <tree>: npm reads the .npmrc of the nearest
# directory above with a package.json, bun reads a bunfig.toml, and either can
# run the project's code. The runner is npx, else bunx; node, else bun, reads
# the report.
#
# Needs bash and git, and npx with node or bunx with bun.

set -euo pipefail
unset CDPATH

[ $# -ge 1 ] && [ $# -le 2 ] || {
  echo 'usage: clones.sh <tree> [path]' >&2
  exit 2
}
data=$(<"$(dirname "$0")/data.ere")
tree=$(cd "$1" && pwd -P)
path=${2:-.}

if command -v npx >/dev/null; then
  runner=(npx --yes)
elif command -v bunx >/dev/null; then
  runner=(bunx)
else
  echo 'clones.sh: needs npx or bunx' >&2
  exit 3
fi
js=$(command -v node || command -v bun)

# A template, because macOS's mktemp -d alone does not read TMPDIR.
run=$(mktemp -d "${TMPDIR:-/tmp}/clones.XXXXXX")
trap 'rm -rf "$run"' EXIT
run=$(cd "$run" && pwd -P)
dir=$run
while [ "$dir" != / ]; do
  dir=$(dirname "$dir")
  for f in package.json node_modules bunfig.toml; do
    [ ! -e "$dir/$f" ] || {
      echo "clones.sh: $dir/$f is above the temporary directory; set TMPDIR to another one" >&2
      exit 1
    }
  done
done

# ponytail: a path with a quote, a backslash, a tab or a newline comes out
# quoted, so the data rule does not see its end; -z and NUL records if one
# turns up.
git -c core.quotePath=false -C "$tree" ls-files -- "$path" | grep -Ev "$data|\.sql\$" >"$run/files" || true
[ -s "$run/files" ] || {
  echo "No code files under $path."
  exit 0
}
GIT_LFS_SKIP_SMUDGE=1 git -C "$tree" checkout-index --prefix="$run/code/" --stdin <"$run/files"
(cd "$run" && "${runner[@]}" jscpd@latest --min-lines 15 --absolute --reporters json --output . code >/dev/null)

# jscpd gives real paths, as pwd -P does: a path outside the copy stops the
# run, so that no local path reaches an issue.
# shellcheck disable=SC2016 # the ${...} are JavaScript's
(cd "$run" && ROOT=$run/code/ "$js" -e '
  const { duplicates } = JSON.parse(require("fs").readFileSync("jscpd-report.json", "utf8"));
  const rel = (name) => {
    if (!name.startsWith(process.env.ROOT)) throw new Error(`not in the copy: ${name}`);
    return name.slice(process.env.ROOT.length);
  };
  const span = (name) => `\`${name.replaceAll("|", "\\|")}\``;
  const rows = duplicates
    .sort((a, b) => b.lines - a.lines || (a.firstFile.name < b.firstFile.name ? -1 : a.firstFile.name > b.firstFile.name ? 1 : 0))
    .map((d) => `| ${d.lines} | ${[d.firstFile, d.secondFile].map((f) => `${span(rel(f.name))} ${f.start}-${f.end}`).join(" | ")} |`);
  console.log(rows.length ? ["| Lines | File | Other file |", "| ---: | --- | --- |", ...rows].join("\n") : "No clones of 15 lines or more in code files.");
')
