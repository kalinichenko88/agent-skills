#!/usr/bin/env bash
# Runs the Makefile's test target on test scripts it writes, each with the
# harness of the real ones: set -eu, an EXIT trap and check. Under bash 3.2 a
# script that set -u stops exits 0 when it has an EXIT trap, so make test must
# fail a script that does not print its ok line.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() {
  printf 'FAIL: %s\n' "$1"
  [ -z "${2:-}" ] || printf '%s\n' "$2"
  exit 1
}

# script <name> <check call>: tests/<name>_test.sh, which makes one check.
mkdir "$tmp/tests"
script() {
  cat >"$tmp/tests/$1_test.sh" <<'EOF'
#!/usr/bin/env bash
set -eu
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT
fail() { printf 'FAIL: %s\n' "$1"; exit 1; }
check() { [ "$2" = "$3" ] || fail "$1"; }
EOF
  printf '%s\necho %s\n' "$2" "'$1_test: ok'" >>"$tmp/tests/$1_test.sh"
  chmod +x "$tmp/tests/$1_test.sh"
}
script pass "check 'same' 'a' 'a'"
script differ "check 'differ' 'a' 'b'"
# No space between the last two strings gives check two arguments: $3 is unbound.
script unbound "check 'name' 'want''got'"

run() { make -s -C "$tmp" -f "$root/Makefile" test TESTS="$1" >"$tmp/out" 2>&1; }
run pass || fail 'make test fails a test that passes' "$(cat "$tmp/out")"
run differ && fail 'make test passes a test whose check fails' "$(cat "$tmp/out")"
run unbound && fail 'make test passes a test that an unbound variable stops' "$(cat "$tmp/out")"
run 'pass unbound' && fail 'make test passes when a later test stops' "$(cat "$tmp/out")"
echo 'makefile_test: ok'
