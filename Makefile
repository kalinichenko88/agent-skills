.PHONY: check
check:
	claude plugin validate .
	jq empty .codex-plugin/plugin.json hooks/hooks.json
	shellcheck hooks/*.sh tests/*.sh skills/github/scripts/*.sh skills/roadmap/scripts/*.sh skills/debt/scripts/*.sh tests/fixtures/debt/*.sh
	./tests/rules_test.sh
	./tests/github_scripts_test.sh
	./tests/roadmap_scripts_test.sh
	./tests/debt_scripts_test.sh
