# Changelog

Every release of the kalinichenko plugin, newest first. A line is one commit on
`main`: the skill or area it changed in parentheses, its subject without the
type, and the PR number when it has one. The `/release` skill writes the
section; pull requests leave this file alone.

## 1.3.0 - 2026-10-29

### Added

- (react) give the app root and each route an error boundary (#199)
- (react) let a project's consistent layout win over the folder and index rules (#198)
- (architecture, debt, review-loop) keep each rule of the instruction files and ARCHITECTURE.md in one place (#194)

## 1.2.1 - 2026-10-28

### Fixed

- (review-loop) run /security-review in a subagent, so its report does not end the turn (#188)
- (typescript) move a constant of over 15 lines to constants.ts, and name constants CONSTANT_CASE

## 1.2.0 - 2026-10-28

### Added

- (github) continue your own work on an issue, and stop taking others' issues or old branches (#181)
- (review-loop) say what the PR changed, and clean up the worktree and the branch after the merge

### Fixed

- (review-loop) judge an exit 2 of the architecture review by what the range changes (#182)
- (github) run the merge in the branch's checkout, so gh does not remove its worktree unchecked

## 1.1.0 - 2026-10-27

### Added

- (review-loop) review a branch against the architecture file and the ADRs, beside round 1 (#166)

### Changed

- (architecture) measure the skill in four arms, and compare the lens on Codex (#169)
- (hooks) check the bare number and the URL prompts as rows of the prompt table (#160)

### Fixed

- (rules) keep only the GitHub triggers in rules.md, and add the zero count's security exception (#163)
- (review-loop) keep a change to a test file off low, and rerun a round that read no file (#162)

## 1.0.0 - 2026-10-27

### Added

- (review-loop) start a round only for a defect that real use reaches
- (review-loop) give a change to documents only one round, one Codex read and no security review (#157)
- (review-loop) read a superpowers spec with Fable and Codex, and check its plan against it (#154)
- (review-loop) review the tests of the whole branch once, when the rounds end (#149)
- (debt) check the invariants of docs/ARCHITECTURE.md in step 2 (#142)
- (hooks) name a Claude Code session after the issue it takes in

### Changed

- (codex) trust the hooks again in /hooks (breaking)
- (tests) name each fixture folder after the tests that read it (#139)

### Fixed

- (github) count your own entries as busy on the duplicate, neighbour and host paths
- (hooks) keep the first part of the issue title whole in the session name (#146)
- (architecture) run each invariant at the base by the base's own Check: line in --new-since (#145)
- (hooks) name the session after a short form of the issue title (#143)

## 0.10.0 - 2026-10-26

### Added

- (github) tell the person what the issue asks before take-in goes on (#138)
- (react) give each of a component's two jobs a hook of its own (#126)
- (architecture) add the architecture skill, with checked invariants in docs/ARCHITECTURE.md (#116)

### Changed

- (architecture) run invariants.sh in make check, so a broken invariant fails CI (#136)
- (plugin) print every script's usage from its header, and name awk where a script calls it (#135)
- (github) give the reason for the shellcheck disables in collect.sh and keep-open.sh (#130)
- (plugin) add docs/ARCHITECTURE.md, with nine invariants, and point agents to it (#128)
- (roadmap) draw the triage scenario picture, and number the scenarios out of four (#111)

### Fixed

- (github) create the debt label for a debt finding, so it never gets bug or none (#137)
- (architecture) give the patterns that step 2 proposes a place in the parts of a first file (#132)
- (architecture) never close a code fence in invariants.sh that Markdown keeps open (#129)
- (github) stop take-in-check on an issue that is yours already (#124)
- (rules) take a clear fix in the task's module, smaller than the task, into its PR (#113)
- (rules) put review-loop over the superpowers review skills, and keep the per-task review (#118)

## 0.9.0 - 2026-10-26

### Added

- (roadmap) triage new issues: a verdict, a label and a milestone for each, after one approval (#110)

### Fixed

- (github) count only this repository's linked branches in worktree.sh, and stop at a fork's (#109)
- (review-loop) add a Docs item to the summary, as rules.md asks before the work is done (#107)
- (rules) tell every read-only subagent, a review one included, to file nothing (#106)

## 0.8.0 - 2026-10-25

### Added

- (review-loop) run Codex as a second reviewer once per review at xhigh (#93)

### Fixed

- (github) make a rerun of add-finding.sh after a failed comment or label add the section once (#94)
- (debt) resolve the ref to one SHA in measure.sh, so a fetch during a run cannot mix two commits (#95)

## 0.7.0 - 2026-10-25

### Added

- (github) file a defect in this plugin in its own tracker, after the person says yes (#84)

### Changed

- (release) put the scope in parentheses at the start of every changelog line (#92)
- (skill-load) run the eval checks on a recorded run in make check, and count a Bash write

### Fixed

- (review-loop) review a skill's or a prompt's text as a document, not with /code-review (#88)

## 0.6.0 - 2026-10-24

### Added

- (react, typescript) put a feature's files where they belong: a part's own files in its folder, models in models/, schemas in schemas/
- (debt) find duplicated code with jscpd on a private copy of the code files
- (roadmap) rename a milestone and set its due date with plan.sh (#67)
- (github) keep private data out of text written to a public repository
- (debt) add a skill that maps technical debt and files it as debt issues
- (review-loop, rules) add a review-loop skill that stops review rounds and ends with a summary

### Changed

- (ci, roadmap) run make check and a gitleaks scan on every pull request and push to main (#80)
- (review-loop) let the eval's step 4 stop happen, and fail a count past three rounds
- (review-loop) give the eval fixture an origin and count the security review

### Fixed

- (review-loop) go on to the pull request after the review, not stop at the security report (#83)
- (roadmap) read the M of a milestone's order in any case (#78)
- (scripts) exit non-zero when set -u stops a skill script that has an EXIT trap
- (tests) pass a test in make check only when it exits 0 with its ok line last
- (roadmap) refuse a second milestone with one `M<n>`, and stop M1 when it names two (#70)
- (roadmap) count only issues in a milestone's progress line
- (typescript) show that helpers and constants go below the primary export

## 0.5.1 - 2026-10-23

### Changed

- (react, typescript) say in the conventions READMEs that rules.md starts them before the first write (#45)
- (github, roadmap) show every scenario picture in the github and roadmap READMEs (#44)
- (plugin) give each skill a README with its pictures (#43)

### Fixed

- (typescript) show that the brace rule covers a JSX .map callback (#49)
- (rules) make subagents invoke the TypeScript and React conventions before they write (#42)
- (release) stop the release when its tag is not on the remote (#39)

## 0.5.0 - 2026-10-23

### Added

- (react) add a react-conventions skill and a typescript-conventions rule on checking items (#32)
- (roadmap) add a PM skill that plans milestones on GitHub (#35)

### Changed

- (roadmap) draw the scenario pictures for the roadmap skill (#37)
- (github) replace a private repository's name in the github fixtures and tests (#36)

### Fixed

- (github, hooks) keep LF in a Windows checkout and find bash on PATH (#34)
- (release) keep positional-argument text out of the release-notes command (#30)

## 0.4.1 - 2026-10-19

### Changed

- (release) add a changelog and publish a GitHub release from the release skill (#29)

## 0.4.0 - 2026-10-19

### Added

- (docs) draw the scenario pictures from a brief with an infographic skill (#28)
- (rules) hand the payload count and the docs sweep to a Haiku subagent (#27)
- (github) check the path:line citations in issues with a scout job (#24)
- (github) move the skill's steps with one correct result into scripts (#9)
- (github) read the tracker with a Haiku scout, add findings to open issues (#4)

### Changed

- (github) split SKILL.md into a file per moment (#12)

### Fixed

- (github) make the citations scout answer none when no issue has an entry (#26)
- (github) keep a Part of PR's issue open: remove the link GitHub adds from a linked branch (#21)
- (github) stop collect.sh's file at about 150 KB and list the bodies it leaves out (#15)
- (github) leave the bodies of label-only bug and debt issues out of the take-in file (#13)

## 0.3.0 - 2026-10-14

### Added

- (typescript) put a blank line before return (#3)
- (rules) write prose in Simplified Technical English (#2)

## 0.2.0 - 2026-10-04

### Added

- (github) take a named issue into work: close its duplicates, open a named worktree (#1)

## 0.1.0 - 2026-09-27

### Added

- (plugin) add the kalinichenko plugin for Claude Code and Codex

### Changed

- (rules) rewrap the GitHub paragraph split mid-sentence
- (codex, hooks) drop what Codex already discovers on its own
