#!/bin/bash
# Injects rules.md as the base prompt. A plugin has no slot for a CLAUDE.md or
# AGENTS.md, and hookSpecificOutput.additionalContext is the one shape Claude
# Code and Codex both read on SessionStart and SubagentStart; Claude drops plain
# stdout on SubagentStart. Escaped in bash so the hook needs no jq.

rules=$(<"$(dirname "$0")/../rules.md")
rules=${rules//\\/\\\\}
rules=${rules//\"/\\\"}
rules=${rules//$'\t'/\\t}
rules=${rules//$'\r'/\\r}
rules=${rules//$'\n'/\\n}
printf '{"hookSpecificOutput":{"hookEventName":"%s","additionalContext":"%s"}}\n' \
  "$1" "$rules"
