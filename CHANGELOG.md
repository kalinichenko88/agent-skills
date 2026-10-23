# Changelog

Every release of the kalinichenko plugin, newest first. A line is one commit on
`main`: its subject without the type, and the PR number when it has one. The
`/release` skill writes the section; pull requests leave this file alone.

## 0.5.1 - 2026-10-23

### Changed

- Say in the conventions READMEs that rules.md starts them before the first write (#45)
- Show every scenario picture in the github and roadmap READMEs (#44)
- Give each skill a README with its pictures (#43)

### Fixed

- typescript: show that the brace rule covers a JSX .map callback (#49)
- rules: make subagents invoke the TypeScript and React conventions before they write (#42)
- release: stop the release when its tag is not on the remote (#39)

## 0.5.0 - 2026-10-23

### Added

- react: add a react-conventions skill and a typescript-conventions rule on checking items (#32)
- roadmap: add a PM skill that plans milestones on GitHub (#35)

### Changed

- roadmap: draw the scenario pictures for the roadmap skill (#37)
- Replace a private repository's name in the github fixtures and tests (#36)

### Fixed

- Keep LF in a Windows checkout and find bash on PATH (#34)
- release: keep positional-argument text out of the release-notes command (#30)

## 0.4.1 - 2026-10-19

### Changed

- Add a changelog and publish a GitHub release from the release skill (#29)

## 0.4.0 - 2026-10-19

### Added

- docs: draw the scenario pictures from a brief with an infographic skill (#28)
- rules: hand the payload count and the docs sweep to a Haiku subagent (#27)
- github: check the path:line citations in issues with a scout job (#24)
- github: move the skill's steps with one correct result into scripts (#9)
- github: read the tracker with a Haiku scout, add findings to open issues (#4)

### Changed

- github: split SKILL.md into a file per moment (#12)

### Fixed

- github: make the citations scout answer none when no issue has an entry (#26)
- github: keep a Part of PR's issue open: remove the link GitHub adds from a linked branch (#21)
- github: stop collect.sh's file at about 150 KB and list the bodies it leaves out (#15)
- github: leave the bodies of label-only bug and debt issues out of the take-in file (#13)

## 0.3.0 - 2026-10-14

### Added

- typescript: put a blank line before return (#3)
- rules: write prose in Simplified Technical English (#2)

## 0.2.0 - 2026-10-04

### Added

- github: take a named issue into work: close its duplicates, open a named worktree (#1)

## 0.1.0 - 2026-09-27

### Added

- Add the kalinichenko plugin for Claude Code and Codex

### Changed

- rules: rewrap the GitHub paragraph split mid-sentence
- Drop what Codex already discovers on its own
