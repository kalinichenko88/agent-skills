# Filing an issue

The global prompt says when a finding becomes an issue; this file says how.
Read `tracker.md`, next to this file, before the search below: it runs the
scripts and reads the tracker. `<dir>` is this skill's base directory.

**Small, safe and needs no decision: it goes into this PR instead** — the Boy
Scout Rule. Check all three against the diff you would write: it stays within a
few lines, it changes nothing another caller or user relies on, and there is
only one way to do it. Fix it in its own commit if it touches a file the task
does not, and list it in the PR description under **Also fixed**, one line per
item. Fails any of the three — a design choice, a behaviour change, a fix that
needs its own test — and it is an issue, however small it looks.

**Search by identifier, not by your title.** A search for the symbol finds
every issue that names it; the prose you were about to write finds only issues
someone happened to phrase your way — and on a tracker written in another
language, nothing at all. Closed counts too: a finding already filed and
rejected does not need filing again. `collect.sh filing` runs these searches;
run it, and read its file, before you file.

**Add to an open issue before you open a new one.** Two issues on one piece of
code become two PRs that edit the same lines, and the tracker grows faster
than it closes. Per finding, the scout's groups decide:

- **Already decided** or **Already filed** — file nothing. If an open issue has
  the same report and the finding adds something — a surface, a reproduction —
  add that as a comment.
- **Fixed before** — a pull request fixed this before, and the finding shows it
  again. File a new issue that starts `Regression of #12`, name the pull
  request that fixed it, and name the commit or the run that shows it again.
  The scout checks **Already decided** first, so a behaviour kept on purpose
  never comes here.
- **Open work** — an open pull request already changes this code. Read it
  before you file: it may fix the finding. If it does not, name it in what you
  file, so its author sees the overlap.
- **A host** — an open issue whose fix changes the same code, or that decides
  something about the same function. It takes the finding only if it is not
  someone else's work (`tracker.md`) and holds fewer than two added findings,
  its `also:`. One PR must still close every problem in it. Write the section
  to a file outside the checkout. It starts `## Also: <the problem>`, then says
  where it is (`path:line`), how it shows up, and why it was out of scope here.
  Then:

  ```bash
  bash <dir>/scripts/add-finding.sh 12 "$section_file" "<a title that names every problem in it>" [label]
  ```

  `[label]` is the finding's label from `gh label list`, if one fits and the
  host does not have it. The script reads `status:` and `also:` again just
  before it writes, so the findings you added in this run count too. It adds
  the section to the end of the body, sets the title, adds the label, and
  leaves a one-line comment, because a body edit notifies nobody. A busy host
  or a full one it refuses, and writes nothing. Run it for one host at a time,
  never two at once: it reads the body and writes it back whole.
- **No free host** — file a new issue:
  - One issue per finding. Title states the problem, body says where it is
    (`path:line`), how it shows up, and why it was out of scope here.
  - Label it from the labels the repository already has — `gh label list`
    first, then `--label` with the ones that fit. Never invent a new label; if
    nothing fits, file it unlabelled.
  - A host that someone works on, or that holds two added findings: write
    `Related to #12` in the new body, and leave a one-line comment on the host
    that names the new issue. Do not edit its body.

List every issue you filed or added to, with its number, in the final report.

## Filing one next to an existing issue

*Docs move with the change* applies to the tracker. An issue goes stale the
moment the code moves under it, and GitHub does not notice: it backlinks a
reference automatically, but nothing corrects the text on either side.

Name the relation in the body — `Related to #12`, `Blocks #12`, `Supersedes
#12` — and fix the other side in the same breath: edit its body so the next
agent reads something true, and leave a one-line comment saying what moved and
why. GitHub keeps the edit history, so nothing is lost by correcting the text
in place. A duplicate is closed against the survivor, never left standing as a
second opinion. When the other side is a host that someone works on, or that
holds two added findings, it gets the one-line comment only: its body stays as
it is.

## A defect in this plugin

The global prompt says when a defect in this plugin becomes an issue; this
section says how. The plugin is the global prompt, the `kalinichenko:` skills,
their scripts and the hooks. Its tracker is `kalinichenko88/agent-skills`, and
every `gh` call below names it with `--repo`.

**Make sure the plugin is wrong.** Read the rule or the script again, all of
it. These are defects:

- A script fails, or prints a wrong result, on valid input.
- Two rules say opposite things for the same case.
- A rule, followed as written, gives a wrong result.
- A rule names a file, a script, a flag or a command that does not exist.

These are not: a step you skipped or read wrong — go back and do it as written;
a bug in the person's project; a bug in another plugin, in Claude Code or in
Codex.

**In a checkout of `agent-skills` itself**, the defect is an ordinary finding:
file it by the sections above, without the question.

**A subagent files nothing.** It names the defect in its report. The agent that
sent it asks the person.

**Search first**, by the name of the script, the skill or the rule's heading:

```bash
gh issue list --repo kalinichenko88/agent-skills --state all --search "<name>"
gh pr list --repo kalinichenko88/agent-skills --state merged --search "<name>"
```

- An open issue has the same report: file nothing. If the defect adds a surface
  or a reproduction, that goes in a comment, after the same question.
- A merged pull request fixed it after the installed version: file nothing.
  Tell the person to update the plugin.
- A merged pull request fixed it, and the installed version has the fix: the
  new issue starts `Regression of #12`.

**Write the issue.** The tracker is public, and the person's project is a
private source: *Public repositories* in `SKILL.md` applies in full. Write the
case again as the smallest reproduction, with neutral names. Paths inside the
plugin, as `skills/github/scripts/collect.sh:42`, stay as they are. The title
starts with the skill, as `github: collect.sh ...`, and states the problem. The
body says:

- The plugin version. In Claude Code, it is the name of the folder that holds
  `skills/` in this skill's base directory, as `a5b733322e79`. In Codex, it is
  `version` in the plugin's `.codex-plugin/plugin.json`. Write the version, not
  the path.
- The tool: Claude Code or Codex.
- The file and the line in the plugin, and what the rule or the script says.
- What happened, and what you expected.
- The steps that show it again.

Label it `bug`. Assign nobody.

**Ask the person** at the end of the task, or at once when the defect blocks
it. Show the full title and body, and say that the repository is public. File
only after a yes for this text: a changed text needs a new yes. A no, or no
answer, files nothing; put the draft in the final report. After the yes, write
the body to a file outside the checkout and run:

```bash
gh issue create --repo kalinichenko88/agent-skills --title "<title>" --body-file "$body_file" --label bug
```

When `gh` cannot write — it is not installed, or `gh auth status` fails — give
the person the draft and the link
`https://github.com/kalinichenko88/agent-skills/issues/new`.

List the issue number in the final report.
