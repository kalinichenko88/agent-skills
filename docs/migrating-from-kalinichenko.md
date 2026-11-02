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

Your instruction files, skills, hooks and memory can call a skill by its old
name. This command lists the text files among them (`.md`, `.toml`,
`settings*.json` and `.sh`), in `~/.claude`, `~/.codex` and `~/.agents`, and
in the folder where you run it. It follows links, and it skips the installed
plugins, the worktrees and `.git`. Check by hand a hook or a script in
another language. Run the command in each project where you use the plugin,
or once in the folder that holds your projects, as `~/Dev`. Do not run it in
your home folder: there it reads all of your files, and it lists the files of
`~/.claude` two times.

```sh
find -L ~/.claude ~/.codex ~/.agents . \( -path '*/.claude/plugins' -o -path '*/.codex/plugins' -o -path '*/.codex/.tmp' -o -name .git -o -name node_modules -o -name worktrees -o -name .worktrees \) -prune -o -type f \( -name '*.md' -o -name '*.toml' -o -name 'settings*.json' -o -name '*.sh' \) -print0 2>/dev/null | xargs -0 grep -lE '(^|[^@])kalinichenko:' 2>/dev/null
```

Read each file that it lists. A record of past work, as an old plan, can keep
the old name. In each other file, replace the name. The command edits the
file that a link points to, so a file from a dotfiles repository stays a link:

```sh
perl -pi -e 's/(?<!@)kalinichenko:/craft:/g' "$(realpath <file>)"
```

A project can turn the plugin on in its own `.claude/settings.json` or
`.claude/settings.local.json`. This command finds such files, in the same
folder as the command above:

```sh
find . -path '*/.claude/settings*.json' -not -path '*/node_modules/*' -print0 2>/dev/null | xargs -0 grep -l '"kalinichenko@kalinichenko"' 2>/dev/null
```

In each file that it lists, change the key `"kalinichenko@kalinichenko"` to
`"craft@kalinichenko"`, and keep its value.

## Optional: the new URL

The old URL works, so this is not needed. To add the marketplace by its new
URL, run these commands in place of the steps for your tool above. The old
plugin goes first, so that it does not stay behind when the marketplace is
removed.

Claude Code:

```sh
claude plugin uninstall kalinichenko@kalinichenko
claude plugin marketplace remove kalinichenko
claude plugin marketplace add kalinichenko88/craft-skills
claude plugin install craft@kalinichenko
```

Codex:

```sh
codex plugin remove kalinichenko@kalinichenko
codex plugin marketplace remove kalinichenko
codex plugin marketplace add kalinichenko88/craft-skills
codex plugin add craft@kalinichenko
```

In Codex, then trust the three hooks of `craft` in `/hooks`, as above.

## Last

Start a new session. The skills now load as `craft:<skill>`.
