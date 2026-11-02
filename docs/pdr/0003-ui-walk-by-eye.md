# 0003 A change to a screen is walked by eye once, before round 1

- Status: accepted
- Level: feature
- Date: 2026-11-02

## Decision

We will walk a change that alters what a user sees or does on a screen once,
before round 1 of the review loop. The agent starts the app, walks the flow
of the task in a browser tool, and looks at a screenshot of each screen: what
moved, what overlaps, what is cut, and what did not load. It reads the
console errors and the failed requests too. When no tool can show the app,
the step is skipped, and the summary says why. The agent writes no e2e test
in place of the walk, and installs nothing.

## Rests on

- One case: a plugin user's UI feature passed its tests and the review, and
  a walk through Playwright after them found UI bugs and a few errors in
  business logic (#212). There is no count beyond it.
- In the author's sessions from 2026-10-21 to 2026-11-02, 18 of 53 ran
  `/code-review`, and none walked the app after the review.
- 0 of the author's 11 local Node projects depend on an e2e framework
  (`@playwright/test`, `cypress`, `puppeteer`, `webdriverio`). An e2e test in
  place of the walk would not run on any of them.
- The UI project of the author with the most reviews is an Electron app. The
  Playwright MCP and Claude in Chrome do not open it. Claude Code 2.1.309
  ships a `run` skill that starts an app by its type, Electron too.
- A page's tree, as the Playwright MCP's snapshot, does not show the layout:
  a button under another block is still in the tree.
- On 2026-11-02, each `mcp__plugin_playwright_*` tool of the author's session
  was deferred, as PDR 0002 records: a step that does not load them sees no
  tool.

## Revisit when

The summaries of 5 reviews with the walk show 0 findings from it.

## Options considered

- A walk by eye, with the platform's tools, and a count in the summary.
- The step of #212 as written: an e2e test when there is no browser tool,
  and the error state too. The e2e branch runs on none of the 11 projects.
- No step: the person asks for a walk by hand. The loop keeps reading only
  the diff.

## Links

#212, PDR 0002, `skills/review-loop/SKILL.md` *The walk*
