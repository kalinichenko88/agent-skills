TESTS = rules github_scripts roadmap_scripts debt_scripts makefile

.PHONY: check lint test
check: lint test

lint:
	claude plugin validate .
	jq empty .codex-plugin/plugin.json hooks/hooks.json
	shellcheck hooks/*.sh tests/*.sh skills/github/scripts/*.sh skills/roadmap/scripts/*.sh skills/debt/scripts/*.sh

# A test passes only when it prints its ok line: under bash 3.2 a script that
# set -u stops exits 0 when it has an EXIT trap.
test:
	@for t in $(TESTS); do echo "./tests/$${t}_test.sh"; ./tests/$${t}_test.sh | tee /dev/stderr | grep -qx "$${t}_test: ok" || exit 1; done
