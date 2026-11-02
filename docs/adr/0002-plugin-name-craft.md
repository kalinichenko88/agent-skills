# 0002 The plugin is named craft

- Status: accepted
- Date: 2026-11-02

## Context

The plugin had the name of its author, so every skill call read
`<author>:github`, `<author>:review-loop`. The name was long to type, and it
said who wrote the plugin, not what it does. The plugin will also hold skills
outside development, for content and against AI slop, and the name must
cover them too (#214).

A skill call takes its prefix from the plugin name only. The marketplace
name is a separate name: it shows only where a person adds, installs and
updates the plugin.

## Options considered

- Keep the author's name: no work, and the prefix keeps saying nothing about
  the plugin.
- `craft`: covers code and writing, is the opposite of slop, and is five
  letters.
- `crafting`: the -ing form names one step, as `brainstorming` does. The
  plugin name is a namespace before the colon, and `crafting:github` reads
  as an action on github.
- `jig`, `atelier`, `whittle`, `guild`: workshop words. Each one is less
  clear than `craft` to a reader who does not know the image, or covers a
  team but not a solo developer.
- `adept`, `rite`, `stc`: words of a game universe. `rite` reads as a ritual
  done without thought, and `stc` is an acronym that only fans know.

## Decision

We will name the plugin `craft`, so a skill call reads `craft:github`. The
repository takes the name `kalinichenko88/craft-skills`: a bare `craft`
does not say what the repository holds. The marketplace keeps its name, so
the install command is `claude plugin install craft@kalinichenko`.

## Consequences

Good: the prefix is short, and it says what the plugin does. `rules.md` gets
56 characters back under its cap.

Bad: every install moves by hand, by
[the guide](../migrating-from-kalinichenko.md). An open branch or an issue
written before the rename can bring the old prefix back.

## Invariants

None.

## Confirmation

The lint target of the `Makefile` fails on a skill name with the old prefix
outside the history and the guide.
