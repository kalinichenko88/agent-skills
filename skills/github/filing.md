# Filing an issue

The global prompt says when a finding becomes an issue; this file says how.
Read `tracker.md`, next to this file, before the search below: it runs the
scripts and reads the tracker. `<dir>` is this skill's base directory.

**In the task's module and clear: it goes into this PR instead** — the Boy
Scout Rule. Check each condition against the diff you would write:

- **Same module** — it changes a file the task changes, or a file next to them
  in the same module. The module is the one that the project's instruction
  file or a conventions skill draws, as a feature or a package; with neither,
  the directory of a file the task changes. For a test, that is the directory
  of the code it tests; a test helper gives no directory. A test belongs only
  to the module of the code it tests, wherever it lives; a test of several
  modules, or a helper that tests of several modules share, belongs to none.
- **Clear** — there is only one way to fix it, and nothing outside the module
  relies on what it changes.
- **Smaller** — its share of the diff is smaller than the task's own diff will
  be.
- **Separable** — dropping it leaves the task whole.

A bug brings its own test, as the global prompt says. List each fix in the PR
description under **Also fixed**, one line per item. Total them each time one
joins: when the new one makes all of them together not smaller than the task's
own diff will be, the new one is an issue, filed as below. The issues that ride
along have their own total, in `take-in.md`. Fails any condition — a file in
another module, a bug that shows outside the module too, a design choice, a
question on business logic (what the product should do where its docs, tests
and names do not say it; a bug is code that crashes or does not do what they
say), a change that code outside the module relies on — and it is an issue,
however small it looks.

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
  or a full one it refuses, and writes nothing. When `gh` stops it with an
  error, the step is not done: report the error and stop, as `tracker.md`
  says. In the report, give the `add-finding.sh` command and the path of the
  section file too. Keep the section file, and do not change it. A rerun waits
  until the person asks for it and the cause of the error is gone. If the
  error says that the label is not found, correct the label in the command or
  remove it. Then run the command again, with the same section file. The rerun
  finishes the step. When the body holds the section already, the rerun
  does not check for a full host and does not change the body or the title.
  It adds the label, if the command names one, and leaves the one-line
  comment. Run it for one host at a time, never two at once: it reads the body
  and writes it back whole.
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
section says how. The plugin is the global prompt, the hooks, the
`kalinichenko:` skills and their scripts. The global prompt is `rules.md` and
the hooks are in `hooks/`, at the plugin root: two directories above this
skill's base directory. Its tracker is
`github.com/kalinichenko88/agent-skills`. Every `gh` call below names it with
its host, so the project's remote and `GH_HOST` do not matter. Only this
section and *Public repositories* in `SKILL.md` apply: the sections above,
`tracker.md` and its scripts work on the checkout's tracker. In a checkout of
`agent-skills` itself, this section does not apply: the sections above apply.

**Make sure the plugin is wrong.** Read the rule or the script again, all of
it. These are defects:

- A script fails, or prints a wrong result, on valid input.
- Two rules say opposite things for the same case.
- A rule, followed as written, gives a wrong result.
- A rule names a file, a script, a flag or a command that does not exist.

These are not defects:

- A step you skipped or read wrong. Go back and do it as written.
- A bug in the person's project.
- A bug in another plugin, in Claude Code or in Codex.

**A subagent files nothing.** It names the defect in its report. The agent that
sent it asks the person.

**Read the files on `main`.** The copy that runs can be older than `main`:

```bash
gh api --hostname github.com -H "Accept: application/vnd.github.raw" \
  repos/kalinichenko88/agent-skills/contents/<path>
```

When `gh` prints `HTTP 404`, `main` has no file at that path. Find the file
that holds the rule or the script now in this list, and read it there:

```bash
gh api --hostname github.com \
  "repos/kalinichenko88/agent-skills/git/trees/main?recursive=1" \
  --jq '.tree[].path'
```

When no file on `main` holds the rule or the script, `main` does not have the
defect. When the read fails in any other way, skip this step and the search,
and go on to *Write the issue*.

When `main` does not have the defect, file nothing. Tell the person that `main`
does not have the defect. Give the file and the line of the defect in the copy
that runs. Give the link
`https://github.com/kalinichenko88/agent-skills#update`, and say that it is for
an installed plugin.

**Search**, by the name of the script, the skill or the rule's heading:

```bash
gh issue list --repo github.com/kalinichenko88/agent-skills --state all \
  --limit 200 --search "<name>" --json number,title,state,stateReason
gh pr list --repo github.com/kalinichenko88/agent-skills --state all \
  --limit 200 --search "<name>" --json number,title,state
```

A title alone does not show whether the report is the same. Read the whole of
each issue that can match, with its comments, and the diff of each pull
request that can match:

```bash
gh issue view <n> --repo github.com/kalinichenko88/agent-skills \
  --json title,body,comments
gh pr diff <n> --repo github.com/kalinichenko88/agent-skills
```

- An open issue has the same report: file nothing. The same defect can be in
  another file of the plugin, or you can have a new reproduction. Then write
  it as a comment, as *Write the issue* below says. Ask before you write it,
  as *Ask the person* below says.
- An open pull request fixes it: file nothing. Give the person its number.
- A pull request closed without a merge does not decide the case. Name it in
  the issue you file.
- A closed issue has the same report, and its `stateReason` is `NOT_PLANNED`:
  file nothing. It was decided. Give the person its number.
- A closed issue with the `stateReason` `DUPLICATE`: judge the issue that it
  duplicates by these bullets instead. This call gives its repository, number
  and state:

  ```bash
  gh api --hostname github.com graphql -f query='{ repository(owner:
    "kalinichenko88", name: "agent-skills") { issue(number: <n>) {
    duplicateOf { number state stateReason
    repository { nameWithOwner } } } } }'
  ```

  When `nameWithOwner` is not `kalinichenko88/agent-skills`, the report is in
  another tracker. File nothing. Give the person that issue's repository and
  number. When `duplicateOf` is `null`, or the call fails, the issue does
  not decide the case: name it in the issue you file.
- `main` has the defect again, and a closed issue with `COMPLETED` or a
  merged pull request fixed it before: file a new issue. Its body starts
  `Regression of #12`.

**Write the issue.** The tracker is public. Take the person's project as a
private source, whatever its visibility, and apply *Public repositories* in
`SKILL.md` to it. Write the case again as the smallest reproduction, with
neutral names. Paths inside the plugin, as
`skills/github/scripts/collect.sh:42`, stay as they are. The title states the
problem and starts with the part of the plugin: the skill, as `github:`,
`rules:` for the global prompt, `hooks:` for a hook. The body says:

- The plugin version. In Claude Code, this skill's base directory ends in
  `<version>/skills/github`, as `a5b733322e79/skills/github`. A plugin that
  runs from a checkout, as with `claude --plugin-dir`, has the version
  `git rev-parse --short=12 HEAD` of that checkout. In Codex, it is `version`
  in the plugin's `.codex-plugin/plugin.json`. Write the version, not the path.
- The tool: Claude Code or Codex.
- The file and the line in the plugin, and what the rule or the script says.
- What happened, and what you expected.
- The steps that show it again.

Put no label on it and assign nobody: only a person with access to the
repository can set them.

**Ask the person** at the end of the task, or at once when the defect blocks
it. Show the full text: the title and the body of an issue, or the body of a
comment. Say that the repository is public. Write only after a yes for this
text: a changed text needs a new yes. A no, or no answer, writes nothing; put
the draft in the final report. After the yes, save the body to a file outside
the checkout and run one of:

```bash
gh issue create --repo github.com/kalinichenko88/agent-skills \
  --title "<title>" --body-file "$body_file"
gh issue comment <n> --repo github.com/kalinichenko88/agent-skills \
  --body-file "$body_file"
```

When `gh` is not installed, `gh auth status --hostname github.com` fails or the
call fails, give the person the draft and the link: for an issue,
`https://github.com/kalinichenko88/agent-skills/issues/new`; for a comment,
`https://github.com/kalinichenko88/agent-skills/issues/<n>`.

List the issue number in the final report.
