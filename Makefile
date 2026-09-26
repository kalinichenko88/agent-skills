.PHONY: check
check:
	claude plugin validate .
	jq empty .codex-plugin/plugin.json .agents/plugins/marketplace.json hooks/hooks.json
	shellcheck hooks/*.sh tests/*.sh
	./tests/rules_test.sh
