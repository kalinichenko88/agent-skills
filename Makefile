.PHONY: check
check:
	claude plugin validate .
	jq empty .codex-plugin/plugin.json hooks/hooks.json
	shellcheck hooks/*.sh tests/*.sh skills/github/scripts/*.sh
	./tests/rules_test.sh
	./tests/github_scripts_test.sh
