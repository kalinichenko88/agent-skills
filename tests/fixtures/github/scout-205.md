## Where

`rules.md` has 9,663 of the 10,000 characters that Claude Code allows for hook context (the count of `tests/rules_test.sh`). 337 are left.

Its sections fall into two kinds:

- **General habits, about 6,200 characters:** *The repository's own gate*, *A bug fix ships with its test*, *Use the platform before reaching past it*, *Code speaks English*, *Plain technical prose*, *Docs move with the change*, *The Boy Scout Rule*. They do not depend on a skill of this plugin.
- **Wiring to the plugin's skills, about 3,000 characters:** *Code review* (review-loop), *Code conventions* (the two conventions skills), *GitHub* (the github skill).

## How it shows up

Each new rule that must fire with no skill loaded competes for the 337 characters. PR #208 (#161) took 99 of the 436 that were left before it. Open issues that want room in `rules.md`: #117 (two sentences, "if the cap allows it"), #185 (a host-selection line), and #200 (one line that sends the skeptical analyst at the start of a feature). #87, decision 4, already bars a new always-on rule because of the cap. #151 freed room once (PR #163); the next rule takes it again.

## Options (needs a decision)

1. **Move the general habits into skills** of this plugin. Each habit then loads by its description, not on every session. Risk: a habit that must hold in every turn, as *Plain technical prose* or *Code speaks English*, fires only when its description matches.
2. **Move what is personal to a separate dotfiles project**, as the style of the prose and the language of the code, into the user's own `~/.claude/CLAUDE.md` or `AGENTS.md`. `rules.md` keeps the wiring and the habits that the skills rely on. Risk: other users of the plugin lose those habits, and the skills that name them (github, review-loop, the conventions) name a text that is not there.
3. **Shorten in place**, as #151 did: cut the text that a skill repeats. Frees less, and the cap comes back.

The test of PR #84 decides what stays: a trigger stays in `rules.md` when it must fire while no skill thinks about it. The moved text keeps what PRs #27 (the Haiku subagent for the count and the docs sweep) and #113 (the module scope of the Boy Scout Rule) set.

## To find out first

- Which skills, READMEs and tests name each general habit by its heading (`grep` for the heading and its anchor), so that a move does not leave a dangling name.
- Whether a habit moved into a skill still holds: the habit's own failing case, run with the habit in `rules.md` and in a skill, as #190 and #192 measured the conventions rules.

Related to #151, #161, #117, #185, #200, #87.



-- comment by kalinichenko88

After #208, `rules.md` has 337 characters left under the cap, not 435, and #161 no longer waits for room; the title and the body now say so.
