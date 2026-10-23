# kalinichenko:github

Commits, pull requests, issues and GitHub Actions, done the same way every
time.

![The GitHub skill: start a task, find something outside it, finish it](../../docs/github/00-overview.webp)

## When it starts

- You write a commit message, open a pull request or merge one.
- You name an issue on its own — `#91` or its URL — to start work on it.
- You find something worth fixing that is outside the task.
- You check whether a finding is already filed.
- You create or edit a GitHub Actions workflow.

## What you get

- **A task starts clean.** Its duplicates close before the work starts. The
  work gets a worktree named for what it does, as `fix/91-what-it-does`. Every
  open bug and debt issue in the same area is checked, so one PR can close
  them with the task.
- **A finding goes to the tracker, not to the chat.** A small, safe fix that
  needs no decision goes into the current PR. Anything else joins an open
  issue on the same code, up to two added findings per issue. Only when no
  issue can take it is a new one filed.
- **A task finishes with a true tracker.** The PR and every issue it closes
  are assigned to you. A PR that fixes only part of an issue keeps that issue
  open. After the merge, the `path:line` citations in open issues are checked
  against the new code.
- **Commits in one shape.** `type(scope): sentence`, at most five bullets
  under it, and no `Co-Authored-By:` trailer. A merge is a squash with one
  list for the whole branch.
- **Actions on the latest major.** Each `uses:` is checked against the GitHub
  API. The language runtime in CI is not older than the one on your machine.

## Each scenario step by step

### Start a task

![Start a task: you get a free issue, no duplicates, a clean branch, and a list of what rides along](../../docs/github/01-start.webp)

### Found something outside the task

![Found something outside the task: you get nothing lost in the chat, and every issue number in the final report](../../docs/github/02-during.webp)

### Finish the task

![Finish the task: you get a clean history on main and a tracker that matches the code](../../docs/github/03-finish.webp)

## How it works

Scripts in `scripts/` do the steps with one correct result. They read the
tracker into one file, check an issue before it is taken, set up its
worktree, add a finding to an issue, and keep an issue open when a PR fixes
only part of it. In Claude Code a Haiku subagent reads a tracker file of
20 KB or more, so the main model gets only the candidates. A Haiku subagent
also checks the `path:line` citations in issues against the code.

## Needs

`bash` and `gh`, authenticated against a GitHub remote. Without them, the
skill skips its GitHub steps and says so.
