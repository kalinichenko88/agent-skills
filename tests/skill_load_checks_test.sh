#!/usr/bin/env bash
# Runs the checks of tests/skill_load_eval.sh, without the model, on
# tests/fixtures/skill_load: the subagents' tool calls and the files they
# wrote, in the layout an eval run leaves. ts-1, react-1, feature-1, the log of
# order-2 and the tree of order-1 are one recorded run, trimmed to what the
# checks read. The other runs change it into a case that a check must fail or
# must pass. order-3 and feature-2 to feature-4 have no log: count reads only
# the logs, and the other checks read only the trees.
#   ts-2       the Skill call after the first Write; `.filter((item) => item…`
#   react-2    no react-conventions; `{results.map((result) => (`
#   order-1    every file written through Bash, as `cat > <file> <<'EOF'`
#   order-2    the four models in src/order.ts; order-summary.ts opens with
#              its Intl constant
#   order-3    Order and OrderLine in one file in models/
#   feature-2  the panel's hook at the feature root, and no schemas/ folder
#   feature-3  the panel's hook in src/shared/hooks; a second schema beside
#              the fetch
#   feature-4  what nested must pass: src/shared/reuse-cache.ts, a
#              src/shared/use-cases/ folder, a hook in a shared/ folder inside
#              the feature
# A change to a check that moves a verdict changes the output and fails here.
# Last, it gives the eval an argument too many, with a stub claude: the eval
# must refuse before it starts a paid run.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

# A function, not $(cat <<'EOF'): bash 3.2 does not parse the apostrophes of a
# here-document inside $().
expected() {
  cat <<'EOF'
typescript-conventions: 6 of 7 subagents invoked it before the first write
react-conventions: 2 of 3 subagents invoked it before the first write
tests/fixtures/skill_load/ts-2/src/cart-total.ts:20:    .filter((item) => item.unitPriceCents > limitCents)
tests/fixtures/skill_load/react-2/src/search-panel.tsx:68:          {results.map((result) => (
brace rule: 2 of 4 written files have no implicit arrow return
tests/fixtures/skill_load/order-2/src/order-summary.ts: const money = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });
export first: 2 of 3 order runs open every file with an export
tests/fixtures/skill_load/order-2/src/order.ts
tests/fixtures/skill_load/order-3/src/orders/models/order.ts
models: 1 of 3 order runs keep each model in a file of its own in models/
tests/fixtures/skill_load/feature-2/src/features/products/use-filter-draft.ts
tests/fixtures/skill_load/feature-3/src/shared/hooks/use-filter-draft.ts
own folder: 2 of 4 feature runs keep the panel's hook out of the feature root and shared
no schemas/ folder: tests/fixtures/skill_load/feature-2
tests/fixtures/skill_load/feature-3/src/features/products/products-api.ts
schemas: 2 of 4 feature runs declare their zod schemas only in schemas/
logs: tests/fixtures/skill_load
EOF
}

# The folder ends in a slash: the paths in the output must still have none
# doubled.
code=0
out=$(tests/skill_load_eval.sh --check tests/fixtures/skill_load/ 2>&1) || code=$?
[ "$code" = 1 ] || {
  printf 'FAIL: --check exited %s, not 1\n%s\n' "$code" "$out"
  exit 1
}
[ "$out" = "$(expected)" ] || {
  echo 'FAIL: --check gives other verdicts on the fixture (- expected, + got)'
  diff <(expected) <(printf '%s\n' "$out") || true
  exit 1
}

# refused <argument>...: the eval must exit 2 with its usage and start no run.
# The claude on PATH is a stub that records each call, so a broken guard costs
# no tokens, and the logs of such a run go into the stub's folder.
stub=$(mktemp -d)
trap 'rm -rf "$stub"' EXIT
cat >"$stub/claude" <<'EOF'
#!/usr/bin/env bash
touch "$(dirname "$0")/called"
EOF
chmod +x "$stub/claude"
# A folder that cannot run the stub, or a claude function, leaves the real
# claude in its place.
[ "$(PATH="$stub:$PATH" command -v claude)" = "$stub/claude" ] || {
  echo "FAIL: claude is not the stub $stub/claude"
  exit 1
}
refused() {
  local code=0 err
  err=$(PATH="$stub:$PATH" TMPDIR="$stub" tests/skill_load_eval.sh "$@" 2>&1 >/dev/null) || code=$?
  if [ "$code" != 2 ] || [ "${err#usage:}" = "$err" ] || [ -e "$stub/called" ]; then
    echo "FAIL: '$*' exited $code with '$err': it must exit 2 with the usage and not run claude"
    exit 1
  fi
}
refused --check tests/fixtures/skill_load extra
refused 3 --check tests/fixtures/skill_load
echo 'skill_load_checks_test: ok'
