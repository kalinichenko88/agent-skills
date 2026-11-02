# 0001 GitHub only, until a project on another host needs more

- Status: accepted
- Level: project
- Date: 2026-11-02

## Decision

We will reach the tracker and the forge only through GitHub. On GitLab or
Bitbucket, the skills that read any git repository work, and the github and
roadmap skills skip their steps and say so. #185 waits in Later with its
plan.

## Rests on

- No user of craft has a project on another host. On 2026-11-02, the origin
  of each of the author's 59 local repositories is on github.com. #185 has 3
  comments, all by the author, and 0 reactions.
- A GitLab copy of the github skill is about 1,900 lines. It would follow
  about 7 commits a week: 35 of 123 commits from 2026-09-26 to 2026-11-02
  touched `skills/github/`. 39 lines call `gh api`, 13 of them with GraphQL
  on GitHub's own schema.
- Its tests need payloads recorded from a real GitLab project (I-7, and
  *The input comes from the source* in `rules.md`). No such project exists.
- GitLab's blocking links, which the roadmap's graph is built on, are in the
  Premium and Ultimate tiers only:
  https://docs.gitlab.com/user/project/issues/related_issues/
- Bitbucket has no official CLI like `gh` or `glab`: Atlassian's `acli`
  covers Jira and admin.
  https://developer.atlassian.com/cloud/acli/reference/commands/

## Revisit when

A real project on GitLab or Bitbucket needs the plugin: one of the author's,
or an issue or a comment from another person that asks for it.

## Options considered

- Defer, and keep #185 as the record: no cost now.
- Defer, and add a README line that sends a user on another host to the
  `gitlab` plugin of Anthropic's marketplace: about an hour. Left for when
  the condition comes.
- Build the plan of #185 now: about 1,900 lines copied, and fixtures with no
  real source to record them from.
- Close #185: a later request would start from nothing.

## Links

#185, ADR 0002, `docs/ARCHITECTURE.md` I-6, I-7, I-8
