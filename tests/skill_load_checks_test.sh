#!/usr/bin/env bash
# Runs the checks of tests/skill_load_eval.sh, without the model, on
# tests/fixtures/skill_load: the subagents' tool calls and the files they
# wrote, in the layout an eval run leaves. ts-1, react-1, feature-1, the log of
# order-2 and the tree of order-1 are one recorded run, trimmed to what the
# checks read. comments-1, its log and its tree, is a later run with the rule
# on one hook per job. decline-1, its log and its tree, is a run without the
# rule on long literals, and decline-2 is a tree of a run with it. The other
# runs change them into a case that a check must fail or must pass. order-3,
# decline-2, decline-3, feature-2 to feature-5 and comments-2 have no log:
# count reads only the logs, and the other checks read only the trees. In
# react-1 and react-2, `await fetch(…)` and `await response.json()` are one
# request that hooks must pass.
#   ts-2       the Skill call after the first Write; `.filter((item) => item…`
#   react-2    no react-conventions; `{results.map((result) => (`
#   order-1    every file written through Bash, as `cat > <file> <<'EOF'`
#   order-2    the four models in src/order.ts; order-summary.ts opens with
#              its Intl constant
#   order-3    Order and OrderLine in one file in models/; the recorded
#              discount.ts of a run without the rule on a union's file, which
#              exports both variants above the union
#   decline-1  the 30-line message table below the export of
#              decline-message.ts
#   decline-3  decline-2 with the short fallback message moved to constants.ts
#   feature-2  the panel's hook at the feature root, and no schemas/ folder
#   feature-3  the panel's hook in src/shared/hooks; a second schema beside
#              the fetch
#   feature-4  what nested must pass: src/shared/reuse-cache.ts, a
#              src/shared/use-cases/ folder, a hook in a shared/ folder inside
#              the feature
#   feature-5  what nested must pass: the page's own use-products.ts at the
#              feature root, which products-page.tsx imports
#   comments-2 a run without the rule: the comments load in an effect and a
#              new one is sent in a handler, both in the component body
# A change to a check that moves a verdict changes the output and fails here.
# Last, it gives the eval an argument too many, as `--check <folder> extra` and
# `3 --check <folder>`, with a stub claude: the eval must refuse before it
# starts a paid run.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

# A function, not $(cat <<'EOF'): bash 3.2 does not parse the apostrophes of a
# here-document inside $().
expected() {
  cat <<'EOF'
typescript-conventions: 8 of 9 subagents invoked it before the first write
react-conventions: 3 of 4 subagents invoked it before the first write
tests/fixtures/skill_load/ts-2/src/cart-total.ts:20:    .filter((item) => item.unitPriceCents > limitCents)
tests/fixtures/skill_load/react-2/src/search-panel.tsx:68:          {results.map((result) => (
brace rule: 2 of 4 written files have no implicit arrow return
tests/fixtures/skill_load/order-2/src/order-summary.ts: const money = new Intl.NumberFormat('en-US', { style: 'currency', currency: 'USD' });
export first: 5 of 6 order and decline runs open every file with an export
tests/fixtures/skill_load/order-2/src/order.ts
tests/fixtures/skill_load/order-3/src/orders/models/order.ts
models: 1 of 3 order runs keep each model in a file of its own in models/
tests/fixtures/skill_load/order-3/src/orders/models/discount.ts: export type PercentDiscount = {
union first: 2 of 3 order runs declare Discount above its variants
tests/fixtures/skill_load/decline-1/src/decline-message.ts
tests/fixtures/skill_load/decline-3/src/constants.ts
constants: 1 of 3 decline runs keep the table in constants.ts and the fallback beside its use
tests/fixtures/skill_load/feature-2/src/features/products/use-filter-draft.ts
tests/fixtures/skill_load/feature-3/src/shared/hooks/use-filter-draft.ts
own folder: 3 of 5 feature runs keep the panel's hook out of the feature root and shared
no schemas/ folder: tests/fixtures/skill_load/feature-2
tests/fixtures/skill_load/feature-3/src/features/products/products-api.ts
schemas: 3 of 5 feature runs declare their zod schemas only in schemas/
tests/fixtures/skill_load/comments-2/src/comments-section.tsx: export function CommentsSection({ postId }: { postId: string }) {
one job: 8 of 9 React runs hold at most one async call in each component and hook
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

stub=$(mktemp -d)
old=$(mktemp -d)
trap 'rm -rf "$stub" "$old"' EXIT

# The logs of an older eval have no log of a later task, as comments: the
# checks must still run, and name the log that is not there.
cp -R tests/fixtures/skill_load/. "$old"
rm -r "$old"/comments-*
code=0
out=$(tests/skill_load_eval.sh --check "$old" 2>&1) || code=$?
case $out in *"no log: $old/comments-*.jsonl"*"logs: $old") ;; *) code="$code, no 'no log:' line" ;; esac
[ "$code" = 1 ] || {
  printf 'FAIL: --check on logs with no comments run exited %s, not 1\n%s\n' "$code" "$out"
  exit 1
}

# refused <argument>...: the eval must exit 2 with its usage and start no run.
# The claude on PATH is a stub that records each call, so a broken guard costs
# no tokens, and the logs of such a run go into the stub's folder.
cat >"$stub/claude" <<'EOF'
#!/usr/bin/env bash
touch "$(dirname "$0")/called"
EOF
chmod +x "$stub/claude"
# A folder that cannot run the stub, or a claude function, leaves the real
# claude in its place.
found=$(PATH="$stub:$PATH" command -v claude || true)
[ "$found" = "$stub/claude" ] || {
  echo "FAIL: claude is '$found', not the stub $stub/claude"
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
