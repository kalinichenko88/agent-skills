#!/usr/bin/env bash
# Names a Claude Code session after the issue that it takes in: when the prompt
# is only an issue, as #91 or its URL, the title becomes "#91 <issue title>".
# Codex marks a hook run as failed when its output has a field that Codex does
# not know, as sessionTitle; only Codex sends turn_id, so there it prints
# nothing. Parsed and escaped in bash, so the hook needs no jq.

IFS= read -r -d '' input || true
[[ $input != *'"turn_id":'* ]] || exit 0
re='"prompt":"(#[0-9]+|https://github\.com/[^/"]+/[^/"]+/issues/[0-9]+)"'
[[ $input =~ $re ]] || exit 0
issue=${BASH_REMATCH[1]#\#}

title=$(gh issue view "$issue" --json number,title --jq '"#\(.number) \(.title)"' 2>/dev/null) || exit 0
[ -n "$title" ] || exit 0
title=${title//\\/\\\\}
title=${title//\"/\\\"}
title=${title//$'\t'/ }
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","sessionTitle":"%s"}}\n' "$title"
