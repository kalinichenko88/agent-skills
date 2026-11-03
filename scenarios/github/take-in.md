# Take a task into work

The person names one task as the whole message: "#91", "take #91", or the
link of the task. The run checks whether the task is free, tells the person
the gist of the task, closes its duplicates, and starts the work on a branch
linked to the task.

Not covered yet:

- the other tasks on the same code that the work takes along;
- a duplicate that tells only the failure that was seen, which waits for a
  reproduction of the failure;
- the correction of the places in the code that a task names, as a file and
  a line;
- a task whose text holds added problems;
- the person's message that asks for a branch only, or for no new branch;
- the person's own task with an open pull request whose branch the
  workspace has;
- a linked branch in another repository only, and a branch in the
  workspace that has the name of the new branch;
- a read of the task that fails after the check, and an earlier run on the
  same task that still waits.

## A free task

Given:
- task #91 is open, with no assignee, no linked branch and no pull request
When: the person writes "#91"
Then:
- the first message about #91 tells its gist
- the gist comes before any change to the tracker or the workspace
- #91 is assigned to the person
- a branch `<type>/91-<two to four words>` exists, where `<type>` is one of
  feat, fix, refactor, docs, test, ci, chore
- that branch is made from the default branch
- that branch is linked to #91
Never:
- #91 gets a second linked branch

## A closed task

Given:
- task #91 is closed
When: the person writes "#91"
Then:
- the first message about #91 tells its gist
- the person is told that #91 is closed
- the run waits
Never:
- the state of #91 changes
- the assignees of #91 change
- a branch for #91 is created

## A task that another person is assigned to

Given:
- task #91 is open, assigned to another person
When: the person writes "#91"
Then:
- the first message about #91 tells its gist
- the person is told that #91 is assigned to another person
- the run waits
Never:
- the assignees of #91 change
- a branch for #91 is created

## A task with another person's pull request

Given:
- task #91 is open, with no assignee
- pull request #96 of another person is open and closes #91
When: the person writes "#91"
Then:
- the first message about #91 tells its gist
- the person is told that #96 of another person closes #91
- the run waits
Never:
- the assignees of #91 change
- a branch for #91 is created

## A task with the person's pull request

Given:
- task #91 is open, with no assignee
- pull request #96 of the person is open and closes #91
When: the person writes "#91"
Then:
- the first message about #91 tells its gist
- the person is told that the work on #91 has pull request #96
- the run stops
Never:
- the assignees of #91 change
- a branch for #91 is created

## A task assigned to the person, with no branch

Given:
- task #91 is open, assigned to the person, with no linked branch and no
  pull request
When: the person writes "#91"
Then:
- the first message about #91 tells its gist
- the person is told that #91 is assigned to the person already
- the person is asked whether the work on #91 runs somewhere else or
  continues here
- the run waits
Never:
- a branch for #91 is created
- the assignees of #91 change

## The work on the person's task continues here

Given:
- task #91 is open, assigned to the person, with no linked branch and no
  pull request
- an earlier run asked whether the work on #91 runs somewhere else or
  continues here
When: the person answers that it continues here
Then:
- #91 stays assigned to the person
- a branch for #91 exists, as in A free task
- that branch is made from the default branch
- that branch is linked to #91
Never:
- #91 gets a second linked branch

## The work on the person's task runs somewhere else

Given:
- task #91 is open, assigned to the person, with no linked branch and no
  pull request
- an earlier run asked whether the work on #91 runs somewhere else or
  continues here
When: the person answers that it runs somewhere else
Then:
- the run stops
Never:
- a branch for #91 is created
- the assignees of #91 change

## A linked branch with no assignee

Given:
- task #91 is open, with no assignee
- branch `fix/91-typo` is linked to #91
When: the person writes "#91"
Then:
- the first message about #91 tells its gist
- the person is told that `fix/91-typo` is linked to #91
- the person is asked whose branch `fix/91-typo` is
- the run waits
Never:
- the assignees of #91 change
- a branch for #91 is created

## The person's work is in the workspace

Given:
- task #91 is open, assigned to the person
- branch `fix/91-typo` is linked to #91, and no pull request closes #91
- the workspace has `fix/91-typo`, with the same last commit as the
  repository
When: the person writes "#91"
Then:
- the first message about #91 tells its gist
- the person is told in one line that the work on #91 continues on
  `fix/91-typo`
- the work goes on, on `fix/91-typo`
Never:
- the person is asked whether the work runs somewhere else
- #91 gets a second linked branch
- the assignees of #91 change

## The person's branch moved on somewhere else

Given:
- task #91 is open, assigned to the person
- branch `fix/91-typo` is linked to #91, and no pull request closes #91
- the repository's `fix/91-typo` has a commit that the workspace's
  `fix/91-typo` does not have
When: the person writes "#91"
Then:
- the first message about #91 tells its gist
- the person is told that #91 is assigned to the person
- the person is told that `fix/91-typo` is linked to #91
- the person is asked whether the work on #91 runs somewhere else or
  continues here
- the run waits
Never:
- a branch for #91 is created
- the workspace's `fix/91-typo` changes

## A task of another repository

Given:
- task #91 is open in another repository, with no assignee
When: the person writes the link of #91
Then:
- the first message about #91 tells its gist
- the person is told that #91 is in another repository
- the run stops
Never:
- the assignees of #91 change
- a branch for #91 is created

## The tracker does not answer

Given:
- task #91 is open, with no assignee
- the tracker answers each read with an error
When: the person writes "#91"
Then:
- the person is told that the tracker could not be read, with its error
- the run stops
Never:
- the person is told a gist of #91 that the run did not read
- the assignees of #91 change
- a branch for #91 is created

## A free duplicate

Given:
- task #91 is open, with no assignee
- task #95 is open, with no assignee, and reports the same thing as #91 in
  other words; it names the same file as #91, and its text has a stack trace
  that #91 does not have
When: the person writes "#91"
Then:
- a comment on #91 holds the stack trace of #95
- #95 is closed as a duplicate of #91
- the comment on #91 comes before #95 closes
- #95 closes before the work starts
- the last message names #95 as closed
- the outcomes of A free task hold for #91
Never:
- #91 closes

## A busy duplicate

Given:
- task #91 is open, with no assignee
- task #95 is open, assigned to another person, and reports the same thing
  as #91 in other words; it names the same file as #91
When: the person writes "#91"
Then:
- #95 stays open
- the person is told that #95 stays open because it is busy
- the outcomes of A free task hold for #91
Never:
- #95 closes
- the assignees of #95 change
