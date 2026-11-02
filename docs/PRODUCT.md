# Product

The product decisions of `craft`: what its users see, pay or get, and what
the project owes by law or licence. The code's decisions are ADRs, in
[`ARCHITECTURE.md`](ARCHITECTURE.md).

## What it is, and for whom

`craft` is a plugin for Claude Code and Codex. It gives the agent working
rules and skills, so that it works on a project as a careful engineer does.

It is for a solo developer or a small team that keeps its work on GitHub.
The first user is the author.

## Direction

- The rules and the skills are text that a model reads. A rule earns its
  place by a measured run, not by a guess.
- The plugin grows past development: skills for content and against AI slop
  (ADR 0002, #214). One plugin, one namespace `craft:`.
- **Current goal:** M2 · Architecture measured: numbers decide what the
  architecture skill keeps (#87, #99).

## What it will not do

- Reach a forge or a tracker other than GitHub, until a project of a user
  needs one (#185).
- Add a config format of its own: the project's instruction file holds the
  settings.

## Constraints

- **Law and licence:** MIT. Recorded payloads in `tests/fixtures/` come only
  from public repositories.
- **The hosts:** Claude Code caps hook context at 10,000 characters, and
  `rules.md` loads through a hook. Codex runs plugin hooks only after the
  person trusts them.
- **Money:** the plugin is free and earns nothing. Its cost is the user's
  tokens: the panel, the second reviewer and the evals call models.
- **The client:** none. No contract binds the project.

## Open questions

### Q-1 Does the architecture skill stay, shrink to the ADR rules, or go?
- Answers: person, from the eval of #99
- Blocks: #87, M2
- Since: 2026-10-25

## Decisions

- [0001 GitHub only, until a project on another host needs more](pdr/0001-github-only.md) — accepted; revisit when: a real project on GitLab or Bitbucket needs the plugin
- [0002 A correction of a plugin step goes to the tracker at Finishing, with no tool of its own](pdr/0002-corrections-at-finishing.md) — accepted; revisit when: a session reaches Finishing with a correction and shows no draft, or a host lets a plugin tool's description always load
