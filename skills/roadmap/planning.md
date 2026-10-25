# Planning a roadmap

You plan with the person, in the conversation. Nothing is written to GitHub
until the person approves the whole plan. One approval covers the whole list.

## Start

1. **Read the project.** List `docs/` and read what describes the product: its
   users, its goals, its competitors, its limits. The folder has no fixed
   format and no fixed file names: choose by content, not by name. Read the
   README and the project's instruction file (`CLAUDE.md`, `AGENTS.md`) too.
   Run `roadmap.sh` to see the open issues and milestones that exist already,
   so nothing is filed twice.
2. **Talk it through.** Ask about what the documents leave open: the order of
   the stages, what is out of scope, what must be there for the first demo.
3. **Propose, in the chat, before any write:**
   - the milestones in order, each with its goal, its `Done when` and a due
     date if the person wants one, plus `Later`;
   - per milestone, its tasks: a title, and a body that says what and why and
     cites the document it came from. Each task fits one PR. A larger one is a
     parent with sub-issues;
   - the "blocked by" links: which task waits on which;
   - which milestones are current.
4. **After the approval, write**, in this order. `<dir>` is this skill's base
   directory.
   - Each milestone that exists already with a title outside the
     `M<n> · <name>` format, when the plan keeps it: rename it with
     `bash <dir>/scripts/plan.sh rename '<title>' 'M1 · First demo'`, and give
     it its description with `plan.sh describe`. Its issues stay in it.
   - Each new milestone with
     `bash <dir>/scripts/plan.sh create 'M1 · First demo' description.md`. Its
     description file holds the goal and the `Done when` sentence:

     ```
     A user can sign in and see their own data.

     Done when a new user signs in on the staging site and sees an empty
     dashboard.
     ```

   - Each issue through the `kalinichenko:github` skill's `filing.md`: a search
     first, existing labels only. Put it into its milestone with
     `gh issue edit <n> --milestone '<title>'`, the title as
     `bash <dir>/scripts/read.sh milestone M1` prints it.
   - Each link with `plan.sh block <issue> <blocker>`, and each sub-issue with
     `plan.sh sub <parent> <child>`. A refusal names the cycle, or the
     issues that would wait on a task in `Later`: change the plan with the
     person, not the check.
   - The due dates with `plan.sh due <milestone> <YYYY-MM-DD>`.
   - The current marks with `plan.sh current <milestone>`.
   - Last, `board.sh` (`SKILL.md`, *The board*).

5. Show `roadmap.sh` as the result.

## Re-planning

When a milestone has no open issues left, or the person asks:

1. Run `roadmap.sh <milestone>` and show it.
2. Propose:
   - to close it, with `plan.sh close`; this is the person's call;
   - where each issue left in it goes: another milestone, `Later`
     (`plan.sh later <n>`), or none (`gh issue edit <n> --remove-milestone`);
   - the next milestone's issues and links, planned again from what the
     closed one taught;
   - the triage of each open issue that has no milestone, by `triage.md`,
     with its rows in this one approval;
   - the new current marks: `plan.sh current` and `plan.sh not-current`.
3. After one approval, write as at the start. `plan.sh describe <milestone>
   <file>` changes a description and keeps its current mark. `plan.sh rename`
   changes a title, and `plan.sh due` a due date; `none` removes it. A rename
   into a number that another open milestone has is refused. To give stages
   higher numbers, as M2 to M3 and M3 to M4, start from the highest. To give
   them lower numbers, start from the lowest. To swap two, give one of them a
   free number first.
