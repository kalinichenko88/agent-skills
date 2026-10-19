# Scripts and the tracker

`take-in.md` and `filing.md` send you here before they read the tracker.

## Scripts

The steps with one correct result are scripts in `scripts/`, next to this
file. Run each one as `bash <dir>/scripts/<name>.sh`, where `<dir>` is this
skill's base directory: a plugin packager can drop the executable bit. They
need only `bash` and `gh`. A script that writes takes `DRY_RUN=1`: it prints
its write commands and runs none.

A script can stop with an error, from `gh` or from its own usage check. Then
its step is not done: report the error and stop at that step. Do not do the
step by hand with `gh`: that skips the checks the script makes. A refusal from
`take-in-check.sh` or `add-finding.sh` is not an error; `take-in.md` and
`filing.md` say what to do with it.

## Reading the tracker

`collect.sh` reads the tracker into one file, and prints its path and size. The
file stops at about 150 KB: past that, it gives no body to the hits that the
fewest names found, and lists them for the reader to add.

```bash
bash <dir>/scripts/collect.sh take-in 91 bug,debt src/main/lanes.ts spawnLane lane
bash <dir>/scripts/collect.sh filing src/parser.ts verify_target
```

Give it every file and symbol that the issue or the findings name, any you
know the work touches, and the one or two words they use for what the person
sees — `lane`, `error alert`. For take-in, the second argument is the
repository's names for bug and debt in `gh label list`, comma-separated, or
`''`. One run covers every finding you have at that moment.

In Claude Code, a file of 20 KB or more goes to a scout, a small model that
reads it in a context of its own and returns only the candidates. The size
that `collect.sh` prints first decides; the reader adds the bodies it needs
later, and the file often grows to three times that size. Send one `Agent`
call with `model: "haiku"` and this prompt:

```
Read <dir>/scout.md and do what it says.
Job: take-in #91.
File: <the path collect.sh printed>.
Collector: bash <dir>/scripts/collect.sh
```

For findings, the `Job:` line is `Job: filing.`, and under it one line per
finding with its `path:line`.

For citations, the `Job:` line is `Job: citations #91.`, or `Job: citations.`
for the open issues that have an entry in the file, and under it `Tree: <the
worktree>`. In
Claude Code this job goes to a scout whatever the size of the file: the
reading it saves is in the code, not in the file.

For take-in and filing, read a smaller file yourself: it costs less than a
subagent's start and its report. In Codex, do every job yourself. Follow
`scout.md` — its *The file*, *Read*, *Sort*, *Citations* and the entry shape in
its *Return* — write its groups and entries as your notes, and go back to the
file that sent you here.

The scout only reads. Every close, edit, comment and new issue is yours, and
so is every verdict. Its lists include doubtful candidates on purpose: drop
each one that is wrong, and read in full each issue before you act on it. Its
report replaces your own search of the tracker: for a name it did not get, run
`collect.sh filing <name>` yourself.

An open issue's `status:` is `free`, or it names who works on it: `assigned to
<login>`, `branch <name>`, `PR #<n> by <login>`, with `you` for your own
account. One entry that is not yours makes the issue **someone else's work**.
GitHub does not say whose a linked branch is: it counts as yours when the
issue is assigned to you alone, as `worktree.sh` leaves it.
