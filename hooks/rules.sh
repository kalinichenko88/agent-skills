#!/usr/bin/env bash
# Injects rules.md as the base prompt. A plugin has no slot for a CLAUDE.md or
# AGENTS.md, and hookSpecificOutput.additionalContext is the one shape Claude
# Code and Codex both read on SessionStart and SubagentStart; Claude drops plain
# stdout on SubagentStart. Escaped in bash so the hook needs no jq.
# Each host caps one additionalContext, so hooks.json runs the hook once per
# part: part 1 is the text before the marker line, part 2 the text after it
# (ADR 0004).

rules=$(<"$(dirname "$0")/../rules.md")
rules=${rules//$'\r'/} # a clone made before .gitattributes keeps CRLF
marker=$'\n\n<!-- rules.sh splits the rules here: each part stays under 10,000 characters -->\n\n'
case ${2:-} in
1) rules=${rules%%"$marker"*} ;;
2) rules=${rules#*"$marker"} ;;
*) echo "usage: rules.sh <event> 1|2" >&2; exit 1 ;; # the whole file is over the cap
esac
rules=${rules//\\/\\\\}
rules=${rules//\"/\\\"}
rules=${rules//$'\n'/\\n}
printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' \
  "$1" "$rules"
