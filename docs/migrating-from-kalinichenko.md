# Moving from `kalinichenko` to `craft`

The plugin `kalinichenko` is now `craft`. The repository
`kalinichenko88/agent-skills` is now `kalinichenko88/craft-skills`. The
marketplace keeps its name: `kalinichenko`.

What changes for you:

- A skill call reads `craft:github`, not `kalinichenko:github`.
- You install `craft@kalinichenko`.
- The marketplace no longer lists `kalinichenko`, so that plugin gets no more
  updates.

The old URL still works: GitHub sends it to the new one. So the marketplace
that you added needs no change.

## Claude Code

```sh
claude plugin marketplace update kalinichenko
claude plugin uninstall kalinichenko@kalinichenko
claude plugin install craft@kalinichenko
```

## Codex

```sh
codex plugin marketplace upgrade kalinichenko
codex plugin remove kalinichenko@kalinichenko
codex plugin add craft@kalinichenko
```

Then run `codex`, open `/hooks`, and trust the three hooks of `craft`. Codex
skips the hooks of a plugin until you trust them. Without this step, the
skills load, but the rules do not.

## Your own files

Your instruction files, skills and hooks can call a skill by its old name.
Find them:

```sh
grep -rln 'kalinichenko:' ~/.claude/CLAUDE.md ~/.claude/settings.json ~/.claude/skills ~/.claude/hooks ~/.codex/AGENTS.md ~/.codex/config.toml ~/.codex/skills ~/.agents CLAUDE.md AGENTS.md .claude .codex .agents 2>/dev/null
```

Run it in each project where you use the plugin. In each file that it lists,
replace the old name:

```sh
perl -pi -e 's/kalinichenko:/craft:/g' <file>
```

## Optional: the new URL

To add the marketplace by its new URL, do it in place of the first command,
before the install.

Claude Code:

```sh
claude plugin marketplace remove kalinichenko
claude plugin marketplace add kalinichenko88/craft-skills
```

Codex:

```sh
codex plugin marketplace remove kalinichenko
codex plugin marketplace add kalinichenko88/craft-skills
```

## Last

Start a new session. The skills now load as `craft:<skill>`.
