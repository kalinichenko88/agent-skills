#!/usr/bin/env bash
# Runs the Makefile's test target on test scripts it writes, each with the
# harness of the real ones: set -eu, an EXIT trap and check. Under bash 3.2 a
# script that set -u stops exits 0 when it has an EXIT trap, so make test must
# fail a script that does not print its ok line.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

fail() { printf 'FAIL: %s\n%s\n' "$1" "$2"; exit 1; }

# script <name> <check call> [after]: tests/<name>_test.sh, which makes one
# check, prints its ok line, then runs after.
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
  printf '%s\necho %s\n%s\n' "$2" "'$1_test: ok'" "${3:-}" >>"$tmp/tests/$1_test.sh"
  chmod +x "$tmp/tests/$1_test.sh"
}
script pass "check 'same' 'a' 'a'"
script differ "check 'differ' 'a' 'b'"
# No space between the last two strings gives check two arguments: $3 is unbound.
script unbound "check 'name' 'want''got'"
# Bash 5 exits 1 on the unbound variable above. This script exits 0 before its
# ok line on any bash, as bash 3.2 does above.
script early "check 'same' 'a' 'a'; exit 0"
script late "check 'same' 'a' 'a'" 'exit 3'
script after "check 'same' 'a' 'a'" "echo 'FAIL: later'"
script note "check 'same' 'a' 'a'; echo 'note_test: one check not run'"

run() { make -s -C "$tmp" -f "$root/Makefile" test TESTS="$1" >"$tmp/out" 2>&1; }
run pass || fail 'make test fails a test that passes' "$(cat "$tmp/out")"
run note || fail 'make test fails a test that prints a note before its ok line' "$(cat "$tmp/out")"
run differ && fail 'make test passes a test whose check fails' "$(cat "$tmp/out")"
run unbound && fail 'make test passes a test that an unbound variable stops' "$(cat "$tmp/out")"
run early && fail 'make test passes a test that exits 0 before its ok line' "$(cat "$tmp/out")"
run late && fail 'make test passes a test that exits 3 after its ok line' "$(cat "$tmp/out")"
run after && fail 'make test passes a test whose ok line is not its last' "$(cat "$tmp/out")"
run 'unbound pass' && fail 'make test passes when an earlier test stops' "$(cat "$tmp/out")"

# The debt test skips clones.sh when there is no node, and must still pass.
# Run that path where /usr/bin and /bin hold no node.
if [ ! -x /usr/bin/node ] && [ ! -x /bin/node ]; then
  PATH=/usr/bin:/bin make -s -C "$root" test TESTS=debt_scripts >"$tmp/out" 2>&1 ||
    fail 'make test fails the debt test without node' "$(cat "$tmp/out")"
fi
echo 'makefile_test: ok'
