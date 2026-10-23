---
name: github
description: Use when touching a repository's GitHub surface — writing a commit message, running `gh pr create` or merging a pull request, filing or updating an issue, picking an issue up to work on (including a bare `#91` or issue URL as the whole message), checking whether a finding is already filed, or creating or editing a GitHub Actions workflow.
---

# Working with GitHub

Everything here needs `gh` authenticated against a GitHub remote. Where it is
not — `gh auth status` fails, or the remote is elsewhere — skip the step and say
so in the final report rather than inventing a substitute.

| Moment | What must happen | Read first |
| --- | --- | --- |
| Writing a commit message | `type: one sentence`, at most 5 bullets under it, no `Co-Authored-By:` | *Commits* below |
| `gh pr create` | `--assignee @me`; assign every issue it closes too; `Part of #15`: `keep-open.sh` after it; then read what it closes | *Pull requests* below |
| Merging | `gh pr merge --squash --delete-branch --body` with one bullet list for the whole branch; then *Finishing* | *Pull requests* below |
| Finding something out of scope | Small, safe, needs no decision: fix it in this PR, list it in the description under **Also fixed**. Otherwise add it to an open issue on the same code with `add-finding.sh`, or file a new one | `filing.md` |
| Filing next to an existing issue | Name the relation, and correct the other side | `filing.md` |
| Picking an issue up — `#91` or its URL | `take-in-check.sh`; close its duplicates; unless told otherwise, `worktree.sh` with `fix/91-what-it-does`; read what it is wired to; re-check its `path:line`; check every open bug and debt issue in the same area first; take along settled issues on the same code, and assign each one when it joins | `take-in.md` |
| Editing a workflow | Pin `uses:` to the latest major; runtime ≥ host | *GitHub Actions* below |

A file in the last column sits next to this one, in this skill's base
directory. Read all of it before the first step of that moment: the row above
is its summary, not its rules. `take-in.md` and `filing.md` both send you on to
`tracker.md`, which runs the scripts and reads the tracker.

## Commits

A commit message is a typed subject line, and under it, at most, a short list of
what was done:

```
fix(hooks): make the docs hook read commands, not prose

- Add the newline to the separator class
- Replay two recorded pushes through the hook in tests/hooks_test.sh
```

The subject is `type: sentence` or `type(scope): sentence` — imperative, up to
100 characters, so the whole first sentence fits. The types, and the only ones:

| Type | Use for |
| --- | --- |
| `feat` | a capability the user did not have before |
| `fix` | behaviour that was wrong and is now right |
| `refactor` | a change with no visible behaviour change |
| `docs` | documentation only |
| `test` | tests only |
| `ci` | workflows and pipelines |
| `chore` | anything else: dependencies, tooling, housekeeping |

A change touching several kinds takes the type of the part the reader cares
about; `wip` is not a type and never reaches `main`.

The list, when there is one, comes after a blank line: one to five bullets, one
line each, each naming a thing that was done. The reasoning, the measurements
and the alternatives stay in the PR description. Nothing else goes below the
list.

Commit messages are English, in every repository — see *Code speaks English* in
the global prompt.

Never add a `Co-Authored-By:` trailer: no Claude, no model name, no
`noreply@anthropic.com`.

## Pull requests

Every PR opened with `gh pr create` carries an assignee — always pass
`--assignee @me`, so the authenticated account owns it. An unassigned PR has
nobody's name on it in the list view, which is how review requests get lost.

If the PR closes an issue — `Closes #12`, `Fixes #12` — assign that issue the
same way *before* the PR merges and closes it: `gh issue edit 12 --add-assignee
@me`. Once GitHub closes an issue automatically, nothing goes back to record who
did the work. An issue already assigned to someone else stays theirs: say so,
do not reassign.

Every issue the PR closes beside the task — a ride-along, or a bug or debt the
change removes (`take-in.md`) — gets its own line under **Also closes** in the
description, with its own keyword — `Closes #15` — because GitHub closes only
the numbers a keyword precedes, and the issues linked to the PR. An issue with
`## Also:` sections closes only when every problem in it is fixed; when the
change fixes some of them, the description says `Part of #15` instead of
`Closes #15`.

A `Part of #15` PR still closes #15 on merge when its branch is linked to #15,
and `worktree.sh` links every branch it makes: when the PR opens, GitHub turns
the branch's link into a link of the PR. So right after `gh pr create`, remove
that link: `bash <dir>/scripts/keep-open.sh <PR> 15`, where `<dir>` is this
skill's base directory.

Then read what the merge will close. Read it again after each edit of the
description:

```bash
gh pr view <PR> --json closingIssuesReferences --jq '.closingIssuesReferences[].url'
```

It must print only the issues that the description closes on purpose. A
closing word in the description before a number — `closed #11`, `does not
close #5` — is a keyword too: write that sentence without it. Any other issue
in the list is a link: the branch's, or one made by hand in the issue's
*Development* panel. When the description does not close that issue, run
`keep-open.sh` for it.

The title and description follow the language the project already uses — read
the recent merged PRs and issues before writing, and match them. English is the
default only where there is nothing to match.

Merging is always `gh pr merge --squash --delete-branch`, with `--body` set to
one list in the *Commits* shape — at most five bullets — that sums up every
commit on the branch, not just the first: without it GitHub fills the squash
commit from a repository setting, by default every branch commit's full message
in turn. One commit per PR keeps `main` readable, and the branch has nothing
left to say once it is in. Its subject is the PR title — by default a
one-commit branch gives that commit's subject instead — so both take the same
`type: sentence` shape. A closing word before a number in the title or the
`--body` closes that issue when the commit lands, and `closingIssuesReferences`
does not show it: write both without one.

**Finishing.** An issue goes stale the moment the code moves under it, and
GitHub does not notice: nothing corrects its text. So the PR closes the task,
every ride-along and every issue the change removes; under each problem it
fixed in an issue that stays open, it adds the line `Done in #<PR>.`; an issue
the description says `Part of` and the merge closed anyway — `gh issue view 15
--json state` shows it — is reopened, with a comment that names the PR; a
duplicate still held for the reproduction is closed or commented on, by *Its
duplicates close first* in `take-in.md`; and the same pass updates every
sibling issue whose text the change just falsified.

To find the citations that the change moved, run `collect.sh filing`
(`tracker.md`) with every file that `gh pr diff <PR> --name-only` prints, and
the old path of each file the PR renamed. In Claude Code a scout then checks
the open issues that have an entry in its file: `Job: citations.`, with a
checkout of the merged code as `Tree:`. Check each citation that moved or is
gone, and correct it.

## GitHub Actions

When creating or editing CI workflows, in any project:

1. **Pin every `uses:` to the latest available major.** Don't trust memory —
   verify against the GitHub API:
   `gh api repos/<owner>/<repo>/releases/latest --jq .tag_name`, and confirm the
   floating major tag exists:
   `gh api repos/<owner>/<repo>/git/matching-refs/tags/v --jq '[.[].ref|sub("refs/tags/";"")]|map(select(test("^v[0-9]+$")))'`.
   Pin to the floating major (e.g. `actions/checkout@v7`), not an exact patch.

2. **Never pin a CI language runtime below the host dev machine.** The CI
   version must be **>= the version installed on the current machine** (e.g.
   `node --version`, `bun --version`). Match the host major by default; never go
   lower. Re-check whenever touching workflow runtime versions.

Apply both whenever adding or reviewing CI, even if not explicitly asked.
