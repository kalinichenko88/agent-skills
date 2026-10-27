#!/usr/bin/env bash
# Gives tests/review_loop_lens_eval.sh a wrong call, with stubs of claude and
# codex first on PATH: an argument too many, as `3 --codex`, and `--codex` with
# a codex that is not logged in. The eval must exit 2 before it starts a paid
# run. The counter has no offline test yet (#168).

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)
cd "$root"

stub=$(mktemp -d)
trap 'rm -rf "$stub"' EXIT
# claude records each call; codex records each exec, and fails `login status`.
cat >"$stub/claude" <<'EOF'
#!/usr/bin/env bash
touch "$(dirname "$0")/called"
EOF
cat >"$stub/codex" <<'EOF'
#!/usr/bin/env bash
[ "$1" != exec ] || touch "$(dirname "$0")/called"
exit 1
EOF
chmod +x "$stub/claude" "$stub/codex"
for tool in claude codex; do
  found=$(PATH="$stub:$PATH" command -v "$tool" || true)
  [ "$found" = "$stub/$tool" ] || {
    echo "FAIL: $tool is '$found', not the stub $stub/$tool"
    exit 1
  }
done

# refused <message> <argument>...: the eval must exit 2 with <message> on
# stderr and run neither claude nor codex exec.
refused() {
  local message=$1 code=0 err
  shift
  rm -f "$stub/called"
  err=$(PATH="$stub:$PATH" TMPDIR="$stub" tests/review_loop_lens_eval.sh "$@" 2>&1 >/dev/null) || code=$?
  if [ "$code" != 2 ] || [ "${err#*"$message"}" = "$err" ] || [ -e "$stub/called" ]; then
    echo "FAIL: '$*' exited $code with '$err': it must exit 2 with '$message' and start no run"
    exit 1
  fi
}
refused usage: 3 --codex
refused usage: --codex 3 4
refused 'not logged in' --codex
echo 'review_loop_lens_checks_test: ok'
