# Changelog

Every release of the kalinichenko plugin, newest first. A line is one commit on
`main`: its subject without the type, and the PR number when it has one. The
`/release` skill writes the section; pull requests leave this file alone.

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
