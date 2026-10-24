#!/usr/bin/env bash
# Writes into $1 the tree that jscpd-report.json was recorded from: a code clone
# of 30 lines and one of 20, copies of the code in a README, a fixture, a
# committed node_modules and SQL, and a binary file; clones.sh gives jscpd none
# of these.
#
# To record the report again: run this, git init and git add -f the tree, put an
# npx first on PATH that runs the real one and keeps jscpd-report.json, run
# clones.sh on the tree, and put @ROOT@ in place of the copy's path.
set -eu
t=$1
mkdir -p "$t/src/sub" "$t/tests/fixtures" "$t/migrations" "$t/node_modules/lib"
gen() { for i in $(seq "$1"); do echo "export const $2$i = ($i * 7) + ($i % 3);"; done; }
gen 30 v >"$t/src/a.ts"
cp "$t/src/a.ts" "$t/src/sub/e.ts"
cp "$t/src/a.ts" "$t/tests/fixtures/x.ts"
cp "$t/src/a.ts" "$t/node_modules/lib/index.ts"
{ echo '# Notes'; echo; echo '```ts'; cat "$t/src/a.ts"; echo '```'; } >"$t/README.md"
gen 20 w >"$t/src/short1.ts"
cp "$t/src/short1.ts" "$t/src/short2.ts"
printf 'PNG\0\0\0\0binary\n' >"$t/src/logo.png"
for n in 001 002; do
  for i in $(seq 16); do echo "CREATE TABLE t$i (id integer primary key, name text not null);"; done >"$t/migrations/$n.sql"
done
