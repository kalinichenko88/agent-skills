#!/usr/bin/env bash
# Names a Claude Code session after the issue that it takes in: when the prompt
# is only an issue, as #91 or its github.com URL, the title becomes
# "#91 <a short form of the issue title>".
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

# An issue title is a sentence, as "github: filing.md forbids a new label, so
# a debt issue ...". The session title drops a prefix of one or two words
# before ": " and keeps the words before the next ",", ";", ": " or " — ". The
# number and these words stay whole up to 50 characters, so the name does not
# stop in the middle of a phrase. When they are longer, it cuts the words at a
# word end to 40 characters and drops the small words at the end of the cut.
# Then it drops a "(" that has no ")" after it and a quote that has no pair,
# each with the words after it. gh's --jq counts characters, not bytes, so the
# result stays valid UTF-8.
# ponytail: the small words are English; add a language's words when its
# titles end on them.
# shellcheck disable=SC2016 # the single-quoted $ are jq's
short='"#\(.number) " as $n | (40 - ($n | length)) as $max
  | (50 - ($n | length)) as $whole
  | $n + (.title | sub("^[^ :]+( [^ :]+)?: +"; "") | sub("(,|;|: | — ).*"; "")
  | if length > $whole then .[:$max + 1] | sub(" +[^ ]*$"; "") | .[:$max]
      | sub("( (a|an|and|at|by|for|from|in|of|on|or|the|to|with))+$"; "")
    else . end | sub(" *\\([^)]*$"; "")
  | if ([match("\""; "g")] | length) % 2 == 1 then sub(" *\"[^\"]*$"; "") else . end)'
title=$(gh issue view "$issue" --json number,title --jq "$short" 2>/dev/null) || exit 0
title=${title//[[:cntrl:]]/ }
title=${title//\\/\\\\}
title=${title//\"/\\\"}
printf '{"hookSpecificOutput":{"hookEventName":"UserPromptSubmit","sessionTitle":"%s"}}\n' "$title"
