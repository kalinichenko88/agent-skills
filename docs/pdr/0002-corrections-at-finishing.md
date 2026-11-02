# 0002 A correction of a plugin step goes to the tracker at Finishing, with no tool of its own

- Status: accepted
- Level: feature
- Date: 2026-11-02

## Decision

We will send a defect in this plugin to its tracker, not to Claude Code's
`SendFeedback`. A step of the plugin that the person has to point out is a
defect. The agent does the step at once and asks nothing. After the merge,
*Finishing* of the github skill reads the session for the person's
corrections and the failed scripts of the plugin: in Claude Code through a
Haiku subagent that reads the transcript, in Codex from the agent's own
context. The agent shows all the drafts in one question. The plugin ships no
tool of its own for this.

## Rests on

- In the author's sessions from 2026-09-27 to 2026-10-29, 4 of 11
  `SendFeedback` drafts were about a skill of this plugin. 1 of the 4 went
  only to Anthropic (#213).
- A plugin's MCP tools can load deferred, by name only: on 2026-11-02, each
  `mcp__plugin_playwright_*` tool of the author's session was deferred. A
  tool of our own would not have its description in the context, as
  `SendFeedback` has.
- The plugin is text and bash (`docs/ARCHITECTURE.md`). An MCP server needs
  a JSON-RPC runtime, and I-2 forbids `jq`.
- Claude Code 2.1.309 keeps the transcript at
  `~/.claude/projects/*/$CLAUDE_CODE_SESSION_ID.jsonl`, also after the
  session enters a worktree. A message sent during a turn is an attachment
  with `"type":"queued_command"`.
- On one recorded session with a correction of a plugin step, the Haiku
  subagent found the correction and both failed calls in 3 of 3 runs.
- In `claude -p`, Claude Code 2.1.309 gives no `SendFeedback` and no
  `AskUserQuestion`: a headless run cannot count `SendFeedback` drafts.

## Revisit when

A Claude Code session reaches *Finishing* with a correction of a plugin step
in its transcript, and shows no draft for this tracker; or a host lets a
plugin ship a tool whose description always loads.

## Options considered

- The transcript read at *Finishing*: one Haiku call after each merge, and
  nothing to do at the moment of the mistake.
- A script that the agent calls to queue a note at the moment: about 30
  lines and a test, and its trigger is text that may not be loaded then.
- An MCP tool of the plugin, as `SendFeedback`: a new runtime and a config
  for each host, and a description that can be deferred.
- One sentence at the moment that asks the person: the question stops the
  task.
- A full audit of the session at *Finishing*: the same model looks for its
  own mistakes with no signal from the person, and more private text sits
  next to a draft for a public tracker.

## Links

#213, #64, #183, #205, `skills/github/filing.md` *A defect in this plugin*
