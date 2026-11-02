**Where.** `tests/github_scripts_test.sh` has 551 lines on `main` at 0d57b7d, after #181 (434 at 1176564). `docs/ARCHITECTURE.md:186`, I-8: "A code file MUST have at most 330 lines." The file is on the I-8 debt list at `docs/ARCHITECTURE.md:187`, so `invariants.sh` passes and prints `new debt tests/github_scripts_test.sh`.

**How it shows up.** The file holds the tests of all five scripts of the github skill: `collect.sh`, `take-in-check.sh`, `worktree.sh`, `add-finding.sh` and `keep-open.sh`. It grows with each fix of one of them: #131 recorded it at 433 lines. No issue covers its split, and the `debt` label has no open issue.

**What the split needs to decide.** Each new file needs the fake `gh` and the helpers of lines 14-69 (`fail`, `check`, `answer`, `writes`). Two ways:

- A shared helper that each test file sources, as `tests/github_fake.sh`. The Makefile finds a test only as `tests/<name>_test.sh` (I-9), so a helper with another name does not run as a test.
- A copy of the fake in each file. It is shorter to read, but the copies drift.

**Why out of scope.** Found by the architecture review of the branch for #153 and #164. That branch fixes `worktree.sh`; the split moves the tests of every script of the skill.

Related to #131: the same rule on `tests/architecture_scripts_test.sh`.


