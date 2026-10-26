#!/usr/bin/env bash
# Names a Claude Code session after the issue that it takes in: when the prompt
# is only an issue, as #91 or its URL, the title becomes "#91 <issue title>".
# Codex marks a hook run as failed when its output has a field that Codex does
# not know, as sessionTitle. So the hook prints only for a Claude Code input:
# prompt_id, which Claude Code sends, and no turn_id, which only Codex sends.
# Parsed and escaped in bash, so the hook needs no jq.

input=$(cat)
[[ $input == *'"prompt_id":'* && $input != *'"turn_id":'* ]] || exit 0
# Claude Code does not trim the prompt. The URL forms are take-in-check.sh's.
re='"prompt":"( |\\[nr])*(#[0-9]+|https?://[^/"]+/[^/"]+/[^/"]+/issues/[0-9]+)( |\\[nr])*"'
[[ $input =~ $re ]] || exit 0
issue=${BASH_REMATCH[2]#\#}

title=$(gh issue view "$issue" --json number,title --jq '"#\(.number) \(.title)"' 2>/dev/null) || exit 0
title=${title//[[:cntrl:]]/ }
title=${title//\\/\\\\}
title=${title//\"/\\\"}
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","sessionTitle":"%s"}}\n' "$title"
