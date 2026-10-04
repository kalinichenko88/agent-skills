# agent-skills

One plugin, `kalinichenko`, for both Claude Code and Codex: an always-on base
prompt of engineering rules, plus the skills those rules lean on.

- **`rules.md`** — the base prompt: run the repository's own check before
  calling work done, ship every bug fix with its test, use the platform before
  a dependency, keep code and commits in English, move docs with the change,
  verify review findings before acting on them. A plugin has no slot for a
  `CLAUDE.md` or `AGENTS.md`, so `hooks/rules.sh` injects it at the start of
  every session and every subagent.
- **`kalinichenko:github`** — commits, pull requests, issues and Actions. An
  issue named on its own — `#91` or its URL — starts the work in a worktree.
- **`kalinichenko:docker`** — the newest stable image, pinned exactly, on the
  smallest base that runs the app.
- **`kalinichenko:typescript-conventions`** — house TypeScript style.

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

The hook is plain bash with no other dependency.

## Update

Claude Code tracks commits: the plugin carries no `version`, so every push is a
new one. Background auto-update is off for third-party marketplaces; turn it on
under `/plugin` → Marketplaces → `kalinichenko`, or update by hand:

```sh
claude plugin update kalinichenko@kalinichenko
```

Codex caches the plugin by the `version` in `.codex-plugin/plugin.json`, so a
release for Codex bumps that field. Users then run:

```sh
codex plugin marketplace upgrade kalinichenko
```

## Develop

`make check` validates the manifests, runs shellcheck and replays `rules.md`
through the hook to prove the JSON it prints carries the file byte for byte.

To try an edit in Claude Code without installing: `claude --plugin-dir .`.
