<task>
Use the imagegen skill with the built-in image_gen tool (not the CLI fallback). Draw one image per <image> block below, one image_gen call each, and save each in the current directory under its file name. Do not edit or delete any existing file. The attached images are style references only: copy their look, not their content.

Audience: a developer who has never heard of this skill. Someone shows them one picture. In ten seconds they must understand what the skill is for, when it starts, and what they get. Pictures with many arrows, script names, command flags and small labels fail this test.
</task>

<style>
- Look: a blue illustrated recipe magazine. Deep rich blue background with a very subtle diagonal diamond pattern; flat isometric illustrations with controlled soft shading; clean white sans-serif text. Few big elements, spacious composition, generous margins.
- Two recurring characters, drawn the same way on every image, both acting in every scene; no other characters:
  - YOU: a young adult developer with short thick wavy dark-brown hair, a light blue open-collar shirt over a white T-shirt, at a silver laptop on a simple light wooden desk. YOU may be smaller, behind the main action.
  - THE AGENT: one small friendly robot with a rounded cream-white head and body, a glossy black face panel with two simple bright eyes, round teal ear discs, teal arms, hands and feet.
  - Label them "YOU" and "THE AGENT" once per image, in scene 1 only.
- Landscape overview: a broad title and subtitle at the top; three equally wide columns read left to right, each with a large bold scene title, one clear illustration and its caption; one thin rightward arrow across the column gutters; a small bottom line; the footer.
- Portrait scenario: a header band with the scenario label and title; a trigger box; four numbered rows read top to bottom, each with one illustration on the left (about 40% of the width) and a bold title and the caption on the right; fine horizontal dividers; numbers 1 to 4 in bright blue roundels; a full-width green result box; the footer. No arrows, no flowchart.
- Type sizes at 1024 px width: title about 65 px, scene titles about 40 px, captions about 28 px (never less than half a scene title), footer about 16 px. Wrap lines only at spaces; no hyphenation.
- Text: render every quoted string verbatim, and nothing more: no extra labels, invented words, invented ticket numbers, fake UI text or lorem ipsum. A ticket or card with no quoted text stays blank; a few grey lines on it are allowed. No command flags, script names or file paths, except the quoted strings.
- No logos, no GitHub Octocat, no trademarks, no watermark.
- Footer left on every image: "kalinichenko/agent-skills · kalinichenko:roadmap skill". Footer right: "Drawn with Codex".
</style>

<image file="00-overview.png">
Canvas: landscape, the largest landscape size the tool offers (at least 1536x1024).
Title: "The roadmap skill"
Subtitle: "Your AI agent plans the project with you and keeps the plan in GitHub. Ask it what to take next at any time."
1. Title "START". Scene: THE AGENT reads a stack of blank documents and sets three boxes in a row, labelled "M1", "M2" and "Later"; YOU nod at the laptop. Caption: "The agent reads your project's docs and proposes stages, tasks and their order. Nothing is written until you approve."
2. Title "DURING THE WORK". Scene: YOU type "What can I take now?" into a chat bubble at the laptop; THE AGENT hands YOU ticket "#21" from a short row of blank tickets. Caption: "Ask what to take next. You get one free task and why it is first, or the tasks that can run in parallel."
3. Title "FINISH". Scene: THE AGENT closes the lid of box "M1", which has a large green check, and opens box "M2"; YOU look pleased. Caption: "Ask what is left to close M1. When it is done, the agent plans the next stage with you."
Bottom line, small: "Also: a task that can wait moves to Later, and a project board shows the plan."
</image>

<image file="01-plan.png">
Canvas: portrait, the largest portrait size the tool offers (at least 1024x1536).
Header: label "SCENARIO 1 OF 4", title "Plan the roadmap".
Trigger box: "WHEN: you ask the agent to plan the roadmap."
1. "Read the project" — THE AGENT reads a stack of blank documents on the desk; YOU watch. Caption: "The agent reads your docs, the README and the open issues. Then it asks about what they leave open."
2. "Stages, tasks and links" — THE AGENT shows YOU a large sheet with three columns labelled "M1", "M2" and "Later", blank tickets in each, and two tickets joined by a short chain. Caption: "Each stage ends in a result you can show. Each task fits one PR. A task that waits on another is linked to it."
3. "One approval" — YOU give a thumbs-up; THE AGENT holds the same sheet. Caption: "Nothing is written until you say yes. One yes covers the whole plan."
4. "The plan is in GitHub" — THE AGENT puts blank tickets into three boxes labelled "M1", "M2" and "Later", next to a small board with three columns of blank cards. Caption: "Milestones, issues and their links go into GitHub. A project board shows them."
Result box: "YOU GET: a plan you agreed to, kept in GitHub where it cannot go stale."
</image>

<image file="02-next.png">
Canvas: portrait, the largest portrait size the tool offers (at least 1024x1536).
Header: label "SCENARIO 2 OF 4", title "Pick the next task".
Trigger box: "WHEN: you ask \"What can I take now?\" or what can run in parallel." (keep the double quotation marks around the question)
1. "Only free tasks" — THE AGENT sorts blank tickets: tickets with a small padlock or a name tag go to one side, plain ones stay in front. Caption: "Not assigned, no open PR, not blocked by an open issue. Other people's work is never offered."
2. "Main path first" — THE AGENT lines up blank tickets in a row, the first one the largest. Caption: "The current milestone comes first. Then the tasks that more issues wait on, then the oldest."
3. "One task and why" — THE AGENT hands YOU ticket "#21" with a small tag "M1"; a smaller ticket "#18" with a small insect on it waits beside. Caption: "#21 is in M1, and two issues wait on it. The top bug, #18, is the alternative."
4. "What can run in parallel?" — THE AGENT puts ticket "#21" and ticket "#25" on two separate small desks, with clear space between them. Caption: "The agent reads the code and picks tasks that do not change the same functions."
Result box: "YOU GET: the right task to take now, and the tasks that can run beside it without conflicts."
</image>

<image file="03-close.png">
Canvas: portrait, the largest portrait size the tool offers (at least 1024x1536).
Header: label "SCENARIO 3 OF 4", title "Close a milestone".
Trigger box: "WHEN: you ask \"What is left to close M1?\"" (keep the double quotation marks around the question)
1. "What is left?" — THE AGENT takes a short column of blank tickets out of box "M1": one with a green dot, one with a name tag, one with a small padlock. Caption: "The open tasks of M1 in the order they must be done: free, in progress, or blocked and by what."
2. "Can it wait? Later." — YOU nod; THE AGENT moves ticket "#30" from box "M1" into box "Later". Caption: "When you agree, the task moves to Later. If a planned task still waits on it, the agent names it and asks you."
3. "M1 is done" — box "M1" has a large green check; THE AGENT closes its lid. Caption: "When no task is left, the agent offers to close the milestone. You decide."
4. "Plan the next stage" — THE AGENT opens box "M2" and puts new blank tickets in it; YOU give a thumbs-up. Caption: "M2 is planned again from what M1 taught. One approval, as at the start."
Result box: "YOU GET: a clear path to the end of M1, and the next stage ready when it closes."
</image>

<image file="04-triage.png">
Canvas: portrait, the largest portrait size the tool offers (at least 1024x1536).
Header: label "SCENARIO 4 OF 4", title "Triage new issues".
Trigger box: "WHEN: you ask the agent to triage the new issues."
1. "Which issues are new?" — THE AGENT takes three tickets, "#36", "#37" and "#38", out of a tray labelled "New"; the tickets have no tags; YOU watch. Caption: "Open issues with no label or no milestone. Nobody has checked their reports yet."
2. "Duplicates close first" — THE AGENT clips ticket "#37" behind ticket "#36" and puts a grey stamp with no text on "#37". Caption: "#37 is the same report as #36. It closes, and what it adds is copied to #36."
3. "A verdict for each" — THE AGENT looks at ticket "#36" through a large magnifying glass; beside it, ticket "#38" has a small speech bubble with "?"; YOU watch from the laptop. Caption: "The agent reproduces each report or finds it in the code. A false one closes; an unclear one gets a question."
4. "Label and milestone" — YOU give a thumbs-up; THE AGENT puts ticket "#36", with a small tag "bug", into box "M1"; ticket "#38" waits beside the box. Caption: "Each issue gets a label, and its importance picks the milestone. One approval, then it all goes into GitHub."
Result box: "YOU GET: every new issue checked, and each confirmed one labelled and in a milestone."
</image>

<verification_loop>
After each image, open it with view_image and compare every quoted string with this brief, letter by letter. Also check: no text that is not in this brief (the tool tends to add ticket numbers), and no quoted string missing (a box label, a sign). If anything is wrong, edit that image with one targeted fix, the image as the reference, and change nothing else. At most two retries per image; keep the best one.
</verification_loop>

<compact_output_contract>
One line per image: file name, pixel size, and "text OK" or the exact strings that are still wrong.
</compact_output_contract>
