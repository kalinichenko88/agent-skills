TESTS = $(patsubst tests/%_test.sh,%,$(wildcard tests/*_test.sh))

.PHONY: check test
check:
	claude plugin validate .
	jq empty .codex-plugin/plugin.json hooks/hooks.json
	shellcheck hooks/*.sh tests/*.sh skills/github/scripts/*.sh skills/roadmap/scripts/*.sh skills/debt/scripts/*.sh
	@$(MAKE) --no-print-directory test

# A test passes only when it exits 0 and its last line is its ok line: under
# bash 3.2 a script that set -u stops exits 0 when it has an EXIT trap.
test:
	@for t in $(TESTS); do \
	  echo "./tests/$${t}_test.sh"; \
	  out=$$(./tests/$${t}_test.sh); code=$$?; printf '%s\n' "$$out"; \
	  [ $$code = 0 ] && [ "$$(printf '%s\n' "$$out" | tail -n 1)" = "$${t}_test: ok" ] || exit 1; \
	done
