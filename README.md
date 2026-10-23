# agent-skills

One plugin, `kalinichenko`, for both Claude Code and Codex: an always-on base
prompt of engineering rules, plus the skills those rules lean on.

- **`rules.md`** — the base prompt: run the repository's own check before
  calling work done, ship every bug fix with its test, use the platform before
  a dependency, keep code and commits in English, write prose in Simplified
  Technical English, move docs with the change, verify review findings before
  acting on them and load the review loop before the first review of a change,
  load the TypeScript conventions before the first write to a TypeScript file
  and the React conventions before the first write to a React component or
  hook. In Claude Code a Haiku subagent does the
  reading for two of them: it counts the real payloads before a bug fix, and
  finds the docs a change made false. A plugin has no slot for a `CLAUDE.md` or `AGENTS.md`, so
  `hooks/rules.sh` injects it at the start of every session and every subagent.
- **[`kalinichenko:github`](skills/github/README.md)** — commits, pull
  requests, issues and Actions.

  ![The GitHub skill: start a task, find something outside it, finish it](docs/github/00-overview.webp)
- **[`kalinichenko:roadmap`](skills/roadmap/README.md)** — a project manager on
  top of GitHub.

  ![The roadmap skill: plan the roadmap, pick the next task, close a milestone](docs/roadmap/00-overview.webp)
- **[`kalinichenko:review-loop`](skills/review-loop/README.md)** — a review
  that ends: rounds that read only the last fixes, one last pass over the
  whole branch when the loop needed more than one round, a security review,
  and a summary of what was decided and fixed.
- **[`kalinichenko:debt`](skills/debt/README.md)** — a map of the technical
  debt: hotspots, broken layer rules and copies, filed as at most three `debt`
  issues a run.
- **[`kalinichenko:docker`](skills/docker/README.md)** — the newest stable
  image, pinned exactly, on the smallest base that runs the app.
- **[`kalinichenko:typescript-conventions`](skills/typescript-conventions/README.md)**
  — house TypeScript style.
- **[`kalinichenko:react-conventions`](skills/react-conventions/README.md)** —
  layer and feature boundaries in a React app, request state as one union, and
  no `ref.current` in render.

Each skill's README says when it starts and what you get. The github and
roadmap READMEs show each scenario as a picture.

The repository is its own marketplace for both tools.

## Install

Claude Code:

```sh
claude plugin marketplace add kalinichenko88/agent-skills
claude plugin install kalinichenko@kalinichenko
```

Codex:

```sh
codex plugin marketplace add kalinichenko88/agent-skills
codex plugin add kalinichenko@kalinichenko
```

Then run `codex`, open `/hooks` and trust the plugin's two hooks. Codex skips
plugin hooks until you do, so without that the skills load but the rules do
not. Editing `rules.md` does not need a new trust; changing `hooks/hooks.json`
does.

The hook is plain bash with no other dependency. The github and roadmap skills'
scripts are bash too, and they also need `gh`. The debt skill's script needs
only bash, git and awk. On native Windows, Claude Code runs
them in Git Bash, so install [Git for Windows](https://git-scm.com/downloads/win):
without it, Claude Code runs the hook in PowerShell, and the rules do not load.
Codex on native Windows is not tested: run it in WSL.

The roadmap skill's board needs the `project` scope on the `gh` token. Run
once on each machine:

```sh
gh auth refresh -s project
```

## Update

Claude Code tracks commits: the plugin carries no `version`, so every push is a
new one. Background auto-update is off for third-party marketplaces; turn it on
under `/plugin` → Marketplaces → `kalinichenko`, or update by hand:

```sh
claude plugin update kalinichenko@kalinichenko
```

Codex installs the plugin under the `version` in `.codex-plugin/plugin.json` and
reinstalls it when a release moves that field. It upgrades the marketplace in
the background at startup; to upgrade now:

```sh
codex plugin marketplace upgrade kalinichenko
```

## Develop

`make check` validates the manifests, runs shellcheck and replays `rules.md`
through the hook to prove the JSON it prints carries the file byte for byte and
stays within Claude Code's 10,000-character cap on hook context. It checks that
a checkout with `core.autocrlf=true`, the Git for Windows default, keeps every
text file in LF, that the hook still gives the rules from a CRLF `rules.md`, and
that every script starts with `#!/usr/bin/env bash`. It also runs the github and
roadmap skills' scripts against a fake `gh` that answers from payloads recorded
in `tests/fixtures/github/` and `tests/fixtures/roadmap/`, all from public
repositories, and the debt skill's `measure.sh` on a repository the test builds.

To try a script that writes on a real tracker without writing to it, set
`DRY_RUN=1`. `GH_REPO=<owner/repo>` points `collect.sh`, `take-in-check.sh`,
`add-finding.sh` and the roadmap scripts at another repository than the
checkout's.

To try an edit in Claude Code without installing: `claude --plugin-dir .`.

`tests/skill_load_eval.sh` counts the Haiku subagents that load the conventions
skills, and the files they write with an implicit return in a method callback,
as `.map((x) => (`. `tests/review_loop_eval.sh` counts the review rounds and
what each one reads; run it after a change to `skills/review-loop` or to its
section in `rules.md`. Both call the model, so they are not part of
`make check`.

The pictures in `docs/` are drawn by Codex from the brief next to them, as
`docs/github/brief.md`. To change a picture, change its brief and run
`/infographic` in Claude Code from this repository. Like `/release`, it lives
in `.claude/skills/` and does not ship with the plugin.

## Release

Pull requests leave `version` alone. Once the work is on `main`, run `/release`
in Claude Code from this repository, or `/release minor` to pick the level. It
bumps `.codex-plugin/plugin.json`, writes the `CHANGELOG.md` section, tags
`vX.Y.Z`, pushes both and publishes a GitHub release with that section as its
notes. The skill lives in `.claude/skills/`, not `skills/`, so it does not ship
with the plugin.
