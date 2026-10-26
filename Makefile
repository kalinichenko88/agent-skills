TESTS = $(patsubst tests/%_test.sh,%,$(wildcard tests/*_test.sh))

.PHONY: check lint test
.NOTPARALLEL:
check: lint test

lint:
	claude plugin validate .
	jq empty .codex-plugin/plugin.json hooks/hooks.json
	! grep -n '^- ' CHANGELOG.md | grep -v '^[0-9]*:- ([a-z][a-z, -]*) '
	shellcheck hooks/*.sh tests/*.sh skills/github/scripts/*.sh skills/roadmap/scripts/*.sh skills/debt/scripts/*.sh skills/review-loop/scripts/*.sh skills/architecture/scripts/*.sh tests/fixtures/debt/*.sh

# A test passes only when it exits 0 and its last non-empty line on stdout is
# its ok line: under bash 3.2 a script that set -u stops exits 0 when it has an
# EXIT trap.
test:
	@for t in $(TESTS); do \
	  echo "./tests/$${t}_test.sh"; \
	  out=$$(./tests/$${t}_test.sh); code=$$?; printf '%s\n' "$$out"; \
	  last=$$(printf '%s\n' "$$out" | tail -n 1); \
	  [ $$code = 0 ] && [ "$$last" = "$${t}_test: ok" ] || \
	    { echo "FAIL: ./tests/$${t}_test.sh exited $$code with the last line '$$last', not 0 with '$${t}_test: ok'"; exit 1; }; \
	done
