#!/usr/bin/env bash
# Names a Claude Code session after the issue that it takes in: when the prompt
# is only an issue, as #91 or its URL, the title becomes "#91 <issue title>".
# Codex marks a hook run as failed when its output has a field that Codex does
# not know, as sessionTitle. So the hook prints only for a Claude Code input:
# prompt_id, which Claude Code sends, and no turn_id, which only Codex sends.
# Parsed and escaped in bash, so the hook needs no jq.

input=$(cat)
[[ $input == *'"prompt_id":'* && $input != *'"turn_id":'* ]] || exit 0
# Claude Code does not trim the prompt. Only github.com: gh sends a token to
# the host of a URL, as GH_ENTERPRISE_TOKEN to any host but github.com.
re='"prompt":"( |\\[nrt])*(#[0-9]+|https://github\.com/[^/"]+/[^/"]+/issues/[0-9]+)( |\\[nrt])*"'
[[ $input =~ $re ]] || exit 0
issue=${BASH_REMATCH[2]#\#}

title=$(gh issue view "$issue" --json number,title --jq '"#\(.number) \(.title)"' 2>/dev/null) || exit 0
title=${title//[[:cntrl:]]/ }
title=${title//\\/\\\\}
title=${title//\"/\\\"}
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","sessionTitle":"%s"}}\n' "$title"
