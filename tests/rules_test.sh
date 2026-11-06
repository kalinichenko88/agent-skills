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
for part in 1 2; do
  [ "$("$crlf/hooks/rules.sh" SessionStart $part)" = "$("$root/hooks/rules.sh" SessionStart $part)" ] || {
    echo "FAIL: the hook does not give part $part of the rules from a CRLF rules.md"
    exit 1
  }
done
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

# hooks.json runs the hook once per part, and each part is one context. The
# two parts and the marker line between them rebuild rules.md (ADR 0004).
grep -c '^<!-- rules.sh splits' "$root/rules.md" | grep -qx 1 || {
  echo "FAIL: rules.md must hold one marker line where rules.sh splits it"
  exit 1
}
marker=$(grep '^<!-- rules.sh splits' "$root/rules.md")
if "$root/hooks/rules.sh" SessionStart >/dev/null 2>&1; then
  echo "FAIL: the hook with no part gives output, and the whole file passes the cap"
  exit 1
fi
for event in SessionStart SubagentStart; do
  for part in 1 2; do
    output=$("$root/hooks/rules.sh" "$event" $part)
    [ "$(jq -r .hookSpecificOutput.hookEventName <<<"$output")" = "$event" ] || {
      echo "FAIL: $event $part: wrong hookEventName"
      exit 1
    }
    # Claude Code moves additionalContext over 10,000 characters to a file and
    # shows only a 2,000-character preview.
    chars=$(jq -r '.hookSpecificOutput.additionalContext | length' <<<"$output")
    [ "$chars" -le 10000 ] || {
      echo "FAIL: $event $part: context is $chars characters, the cap is 10000"
      exit 1
    }
    jq -r .hookSpecificOutput.additionalContext <<<"$output" >"$crlf/part$part"
  done
  diff <(printf '%s\n\n%s\n\n%s\n' "$(<"$crlf/part1")" "$marker" "$(<"$crlf/part2")") \
    "$root/rules.md" || {
    echo "FAIL: $event: the two parts and the marker line differ from rules.md"
    exit 1
  }
done
# Every rule handler in hooks.json names a part, and each part has one.
for event in SessionStart SubagentStart; do
  parts=$(jq -r --arg e "$event" \
    '.hooks[$e][].hooks[].command | select(test("rules\\.sh")) | split(" ") | last' \
    "$root/hooks/hooks.json" | sort | tr '\n' ' ')
  [ "$parts" = "1 2 " ] || {
    echo "FAIL: hooks.json: $event runs rules.sh with parts '$parts', not '1 2 '"
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
#   A project with no real source to sample has nothing to count: both rules
#   say that the count then stops nothing, and name the input of the test
#   (#161).
# - Run from another checkout, gh 2.103 removes the branch's linked worktree
#   and its local branch at the merge, with no check of Cleanup. The merge
#   runs in the checkout that holds the branch, and review-loop asks that
#   checkout, not the session's directory, whether there is a worktree (#176).
#   18 of 19 recorded sessions that moved into a worktree from the main
#   checkout did it with cd, and #173's session then read itself as one that
#   started there: it gave the person the commands of Cleanup. A session
#   leaves the way it came in, and only one that started there hands them
#   over (#195).
# - After a merge, #117, #205 and #213 still quoted the room left in rules.md,
#   and no citation of theirs showed it. *Finishing* gives the scout a
#   Decision line for each number that the PR changed, counted again in the
#   merged code, and the scout reads the title and the body against them
#   (#211). #220 changed rules.md, and its description gave no count: a
#   size that a check caps gets a Decision line anyway. 4 of 20 PRs merged
#   with the branch behind main, so the scout reads a new checkout of the
#   default branch, not the branch's worktree. A merge that fixes some
#   problems of an issue leaves it open.
#   tests/github_scout_eval.sh tests the scout, not these lines.
# - Another plugin's SubagentStart rule told Haiku subagents to reuse the
#   project's pattern and keep the work short. On an edit of an existing React
#   project, 5 of 10 invoked the conventions skills before the first write;
#   with "No pattern to copy …" after the conventions rule, 16 of 20 did. The
#   runs and their fixture are in the description of the PR that closes #196.
while IFS='|' read -r f phrase; do
  sed 's/^#//' "$root/$f" | tr -s '[:space:]' ' ' | grep -qF "$phrase" || {
    echo "FAIL: $f: no \"$phrase\""
    exit 1
  }
done <<'EOF'
rules.md|`craft:review-loop` replaces `superpowers:requesting-code-review` and `superpowers:receiving-code-review`.
rules.md|. In `superpowers:subagent-driven-development`, the review after each task stays as that skill sets it, without `craft:review-loop`. Invoke review-loop after the last task, in place of the final review.
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
rules.md|With no real source to sample, the count stops nothing, and the test uses the input of the report.
skills/review-loop/SKILL.md|With no real source to sample, the count declines nothing, and the test of the fix uses the input of the finding.
skills/github/SKILL.md|Run the merge in the checkout that holds the branch, whatever directory the session is in: `(cd <path> && gh pr merge …)`, where `<path>` is what `git for-each-ref --format='%(worktreepath)' refs/heads/<branch>` prints.
skills/github/SKILL.md|`ExitWorktree` does nothing for a session that moved there in any other way, as with `cd` after `worktree.sh`: that session runs both commands itself, each with `git -C <the main checkout>`. Only a session that started in the worktree, as with `claude --worktree` or `codex --worktree`, cannot leave it: give the person the two commands below, to run after the session ends.
skills/review-loop/SKILL.md|When `git for-each-ref --format='%(worktreepath)' refs/heads/<branch>` prints nothing or the first path of `git worktree list`, the branch has no linked worktree
skills/github/SKILL.md|and a number that it changed, as a count or a size that an issue can quote.
skills/github/SKILL.md|Count again each number that the merged code holds: a description can be older than the last fix. When a check sets its limit, count it as that check counts it.
skills/github/SKILL.md|For each changed file with a size limit of its own, as a cap on its characters that a test sets, or on the `debt` list of a size check, add a decision with its new size and the check's limit, also when the description does not give them.
skills/github/SKILL.md|*Finishing* reads the merged code in a new checkout, outside every checkout. The branch's worktree is not the merged code when the default branch moved after the branch's last push.
skills/github/SKILL.md|git worktree add --detach <the mktemp path> origin/<the default branch>
skills/github/SKILL.md|Remove it when *Finishing* ends or stops, with `git worktree remove --force <the mktemp path>`.
skills/github/SKILL.md|A problem marked `Done in #<PR>.` needs no other correction, and an issue with a problem left in it stays open.
skills/github/scout.md|Then read the title and the whole body of each issue against them, the sentences with no citation too.
rules.md|`craft:react-conventions` too. A subagent invokes them itself. No pattern to copy and no rule to keep the work short skips these calls.
EOF
echo 'rules_test: ok'
