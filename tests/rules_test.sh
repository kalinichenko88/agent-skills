#!/usr/bin/env bash
# The hook hand-escapes rules.md into JSON. Both Claude Code and Codex drop
# context that does not parse, so the real file must come back byte for byte.

set -eu

root=$(cd "$(dirname "$0")/.." && pwd)

# Git for Windows checks out with core.autocrlf=true by default. bash reads a CR
# as part of the command, so that checkout must keep LF too: the hook, and every
# script the skills run.
crlf=$(mktemp -d)
trap 'rm -rf "$crlf"' EXIT
git -C "$root" -c core.autocrlf=true checkout-index -a --prefix="$crlf/"
if grep -rIl $'\r' "$crlf"; then
  echo "FAIL: a core.autocrlf=true checkout has CRLF in the files above"
  exit 1
fi
# A clone made before .gitattributes keeps rules.md in CRLF: an update rewrites
# only the files it changes. The hook must still give the rules.
cp "$root/hooks/rules.sh" "$crlf/hooks/"
sed 's/$/\r/' "$root/rules.md" >"$crlf/rules.md"
[ "$("$crlf/hooks/rules.sh" SessionStart)" = "$("$root/hooks/rules.sh" SessionStart)" ] || {
  echo "FAIL: the hook does not give the rules from a CRLF rules.md"
  exit 1
}
# NixOS has no /bin/bash: every script must find bash on PATH.
for script in $(git -C "$root" ls-files '*.sh'); do
  [ "$(head -1 "$root/$script")" = '#!/usr/bin/env bash' ] || {
    echo "FAIL: $script: the shebang must be #!/usr/bin/env bash"
    exit 1
  }
done
# Each script prints its usage from the call lines of its header (ADR 0001).
# shellcheck disable=SC2016 # the line as the scripts hold it
usage='sed -n "s/^#   ${0##*/}/usage: ${0##*/}/p" "$0" >&2'
for script in $(git -C "$root" ls-files 'skills/*/scripts/*.sh'); do
  if ! grep -qF "$usage" "$root/$script" || ! grep -q "^#   ${script##*/}" "$root/$script"; then
    echo "FAIL: $script: usage must print the '#   ${script##*/}' lines of its header"
    exit 1
  fi
done

for event in SessionStart SubagentStart; do
  output=$("$root/hooks/rules.sh" "$event")
  [ "$(jq -r .hookSpecificOutput.hookEventName <<<"$output")" = "$event" ] || {
    echo "FAIL: $event: wrong hookEventName"
    exit 1
  }
  diff <(jq -r .hookSpecificOutput.additionalContext <<<"$output") \
    "$root/rules.md" || {
    echo "FAIL: $event: context differs from rules.md"
    exit 1
  }
  # Claude Code moves additionalContext over 10,000 characters to a file and
  # shows only a 2,000-character preview.
  chars=$(jq -r '.hookSpecificOutput.additionalContext | length' <<<"$output")
  [ "$chars" -le 10000 ] || {
    echo "FAIL: $event: context is $chars characters, the cap is 10000"
    exit 1
  }
done
# A review subagent gets these rules too, as the loop above proves, and
# *Out-of-scope findings* tells it to file an issue without asking. One
# sentence must tell every read-only subagent, a review one included, to file
# nothing.
tr '\n' ' ' <"$root/rules.md" | grep -qE 'read-only subagent[^.]* review[^.]* files nothing' || {
  echo "FAIL: SubagentStart: no sentence tells a read-only review subagent to file nothing"
  exit 1
}
# A fix outside the task goes into its PR or into an issue by one scope: the
# task's module. Each place that draws that line names the module, and none
# keeps the three tests without it (#103).
for f in rules.md skills/github/filing.md skills/github/take-in.md \
  skills/github/SKILL.md skills/github/README.md; do
  text=$(tr -s '[:space:]' ' ' <"$root/$f")
  grep -qE "(same|task's) module" <<<"$text" || {
    echo "FAIL: $f: a fix goes into the task's PR with no module scope"
    exit 1
  }
  if grep -qi 'small, safe' <<<"$text"; then
    echo "FAIL: $f: a fix goes into the PR by size and safety alone, with no module"
    exit 1
  fi
done
# Sentences that must stay, word for word. Each line loses one leading #, so a
# phrase can span a script's comment lines.
# - superpowers' review skills start at the same moments as review-loop and
#   give other steps, and subagent-driven-development's per-task reviewer is a
#   review subagent too. The rules must say which skill wins, keep review-loop
#   out of the per-task review, and invoke review-loop after the last task: the
#   review there is not the first review of the change, so the trigger in
#   rules.md does not fire.
# - The checks of a spec and a plan are not a review of a change, so the
#   trigger above does not fire there. The steps live in review-loop, and only
#   this sentence starts it (#101).
# - architecture and review-loop file a debt issue through filing.md. With no
#   `debt` label in the repository, "never invent a new label" left it `bug` or
#   unlabelled (#133). Each place that gives the labels rule, for a new issue or
#   for a host, names the exception.
# - The GitHub section keeps the headings of its two rules that must fire with
#   no skill loaded (#151). With no GitHub remote, an agent that finds
#   something out of scope may never load the github skill, so rules.md keeps
#   the fallback too. The
#   ask for a plugin defect shows the text that filing.md writes, so its check
#   of the defect runs before the person is asked.
# - A zero count stops a fix, but an attacker can make the input of data loss
#   or a security hole: the rule for a person's report, in rules.md, and the
#   rule for a review finding, in review-loop, each name that exception (#151).
while IFS='|' read -r f phrase; do
  sed 's/^#//' "$root/$f" | tr -s '[:space:]' ' ' | grep -qF "$phrase" || {
    echo "FAIL: $f: no \"$phrase\""
    exit 1
  }
done <<'EOF'
rules.md|`kalinichenko:review-loop` replaces `superpowers:requesting-code-review` and `superpowers:receiving-code-review`.
rules.md|. In `superpowers:subagent-driven-development`, the review after each task stays as that skill sets it, without `kalinichenko:review-loop`. Invoke review-loop after the last task, in place of the final review.
rules.md|In Claude Code, invoke it also in place of the builder check of `superpowers:brainstorming`, and after the self-review of `superpowers:writing-plans`.
skills/github/filing.md|The one exception is debt: a file or a folder to split,
skills/github/filing.md|create `debt` first: `gh label create debt --description "Structural debt to refactor" --color 5319e7`
skills/github/filing.md|For a debt finding, when the repository has no debt label, create `debt` first.
skills/github/filing.md|A debt finding keeps its debt label: when the repository has none, create `debt`
skills/github/scripts/add-finding.sh|A debt finding keeps its debt label: when the repository has none, create `debt`
skills/roadmap/triage.md|except `debt` for a debt issue
skills/roadmap/triage.md|when a row's label is `debt` and the repository has no debt label, create `debt`
skills/roadmap/planning.md|except `debt` for a debt issue
rules.md|**Out-of-scope findings become issues.**
rules.md|Where there is no GitHub remote or `gh auth status` fails, name the finding in the final report instead of filing it.
rules.md|**A defect in this plugin goes to its tracker, after the person says yes.**
rules.md|Unlike the rule above, ask the person first: show the text that the github skill's `filing.md` writes.
rules.md|For a report of data loss or a security hole, a zero count does not stop the fix. An attacker can make the input, so the test of that fix uses the input of the report.
skills/review-loop/SKILL.md|A zero count does not decline a finding of data loss or a security hole: an attacker can make the input, and the test of its fix uses the input of the finding.
EOF
echo 'rules_test: ok'
