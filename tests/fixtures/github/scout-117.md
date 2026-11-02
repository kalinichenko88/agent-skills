Related to #102.

**Where.** `rules.md`, *Code review*, after the fix of #102: "In `superpowers:subagent-driven-development`, the review after each task stays as that skill sets it. Invoke review-loop after the last task, in place of the final review." In superpowers 7.0.0, two steps of that skill sit around its final review:

- The ledger's deferred minor findings. The skill says to "point the final whole-branch review at that list" (`subagent-driven-development/SKILL.md:362`), so that the final reviewer triages them (`:455`). Round 1 of review-loop is `/code-review` on a range, and it takes no list.
- `superpowers:finishing-a-development-branch` after the final review (`:120`, `:487`). It offers to merge locally, push and open a pull request, keep the branch, or discard it. `superpowers:executing-plans` ends with it too.

**How it shows up.**

- For an issue taken into work, *The pull request* of `skills/review-loop/SKILL.md` already pushes, opens the pull request and asks the merge question: in a worktree, merge and clean up, merge only, or do not merge (#175). Then the plan skill sends the agent to `finishing-a-development-branch`, which offers the same choices again, a local merge among them.
- The deferred minor findings reach nobody: the final reviewer that triaged them no longer runs.

**Decision needed.**

- Proposal: two sentences in `skills/review-loop/SKILL.md`, because `rules.md` had 49 characters left under the 10,000 cap after #101. After #208 it has 337 left, so the second option below fits too. First: the ledger's deferred minor findings go through *The findings*. Second: when *The pull request* opens the pull request, `finishing-a-development-branch` does not run. When it does not open one, `finishing-a-development-branch` runs as that skill sets it.
- Or the same in `rules.md`, if the cap allows it.

**Why out of scope in #102.** #102 decided which skill runs the review. These two steps come before and after the review, and the decision did not cover them.

**Found by** the review of the branch for #102, against the installed superpowers 7.0.0. Read from the text; no run has shown it yet.





Related to #174: the end of the work after the merge — a list of what the PR changed, and the removal of the worktree and the local branch. Both change the end of the same flow; one PR can close both.




-- comment by kalinichenko88

The room under the rules.md cap that this issue needs is now tracked in #151. After #101, 49 characters are left, not about 120.

-- comment by kalinichenko88

After #163, `rules.md` has 436 characters left under the cap, not 49; the proposal now says so.

-- comment by kalinichenko88

Related to #174, which adds the step after the merge that removes the worktree and the branch; the body now says so.

-- comment by kalinichenko88

After #175, *The pull request* asks one merge question with three answers in a worktree, and *Cleanup* removes the worktree and the branch; the body now says so.

-- comment by kalinichenko88

Related: #205 asks how to split rules.md, which would free the room under the 10,000-character cap that this issue needs.

-- comment by kalinichenko88

After #208, `rules.md` has 337 characters left under the cap, not 436; the proposal now says so.
