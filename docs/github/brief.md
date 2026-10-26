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
- Footer left on every image: "kalinichenko/agent-skills · kalinichenko:github skill". Footer right: "Drawn with Codex".
</style>

<image file="00-overview.png">
Canvas: landscape, the largest landscape size the tool offers (at least 1536x1024).
Title: "The GitHub skill"
Subtitle: "Your AI agent works with GitHub issues like a careful teammate. It keeps the tracker true from the first message to the merge."
1. Title "START". Scene: YOU type "#91" into a chat bubble at the laptop; THE AGENT picks up a paper ticket "#91". Caption: "You name an issue. The agent checks it is free, closes its duplicates and opens its own branch."
2. Title "DURING THE WORK". Scene: THE AGENT finds one small insect at the edge of the desk and puts it on a blank ticket. Caption: "The agent finds a problem outside the task. It fixes a small one in place, or files it so nothing is lost."
3. Title "FINISH". Scene: THE AGENT drops one neat card into a box labelled "main"; ticket "#91" has a large green check; YOU look pleased. Caption: "One clear commit, a PR with your name on it, the issues closed and up to date."
Bottom line, small: "Also: commit messages and GitHub Actions versions follow the same rules."
</image>

<image file="01-start.png">
Canvas: portrait, the largest portrait size the tool offers (at least 1024x1536).
Header: label "SCENARIO 1 OF 3", title "Start a task".
Trigger box: "WHEN: you write \"#91\" or paste the issue link." (keep the double quotation marks around #91)
1. "Is it free?" — THE AGENT examines ticket "#91" with a green check. Caption: "Open, not assigned to someone else, no one else's PR. If taken, the agent tells you and waits."
2. "Close the duplicates" — THE AGENT moves notes from two similar blank tickets into ticket "#91"; one blank ticket goes into a small bin. Caption: "The same report in other words is closed. What it adds moves into #91."
3. "Own branch, own folder" — THE AGENT sets up a separate folder and a branch sign "fix/91-short-name"; the developer's main desk stays tidy. Caption: "The issue is assigned to you. The work gets its own branch and worktree."
4. "What else is on this code?" — THE AGENT shows two blank extra tickets next to ticket "#91". Caption: "It reads the linked issues and PRs, and finds open bugs this PR can close too."
Result box: "YOU GET: a free issue, no duplicates, a clean branch, and a list of what rides along."
</image>

<image file="02-during.png">
Canvas: portrait, the largest portrait size the tool offers (at least 1024x1536).
Header: label "SCENARIO 2 OF 3", title "Found something outside the task".
Trigger box: "WHEN: while working on #91, the agent sees another problem."
1. "Near the task and clear? Fix it now." — THE AGENT corrects a blank card with a small brush, using simple line strokes. Caption: "A typo or a small bug next to the task, with one clear fix: fixed in this PR and listed under Also fixed."
2. "Already known?" — THE AGENT looks through a drawer of blank tickets with a large magnifier. Caption: "It searches the tracker by file and function name, open and closed. Known already: nothing new is filed."
3. "Same code as an open issue?" — THE AGENT clips a blank note onto an existing ticket "#12". Caption: "The finding goes into that issue, if no one else is working on it."
4. "New problem? New issue." — THE AGENT pins a fresh ticket "#97" to a small board. Caption: "One issue per finding: where it is, how it shows, why it is not part of this task."
Result box: "YOU GET: nothing lost in the chat. The final report lists every issue number."
</image>

<image file="03-finish.png">
Canvas: portrait, the largest portrait size the tool offers (at least 1024x1536).
Header: label "SCENARIO 3 OF 3", title "Finish the task".
Trigger box: "WHEN: the code is ready."
1. "A clear commit" — THE AGENT holds a card whose only text is "fix(auth): stop the session expiring early", with a few grey list lines under it. Caption: "One sentence that says what changed, and a short list under it."
2. "A PR with an owner" — THE AGENT clips a name tag "you" onto a plain card, with tickets "#91" and "#15" attached. Caption: "The PR and every issue it closes are assigned to you."
3. "One commit on main" — THE AGENT presses several blank small cards into one card that drops into a box labelled "main". Caption: "Squash merge with one summary. The branch is deleted."
4. "The tracker tells the truth" — tickets "#91" and "#15" have green checks; THE AGENT corrects a third ticket "#12", which has no check, with a pencil. Caption: "The PR closes only the issues it finishes. Other issues the change made wrong are corrected."
Result box: "YOU GET: a clean history on main and a tracker that matches the code."
</image>

<verification_loop>
After each image, open it with view_image and compare every quoted string with this brief, letter by letter. Also check: no text that is not in this brief (the tool tends to add ticket numbers), and no quoted string missing (a box label, a sign). If anything is wrong, edit that image with one targeted fix, the image as the reference, and change nothing else. At most two retries per image; keep the best one.
</verification_loop>

<compact_output_contract>
One line per image: file name, pixel size, and "text OK" or the exact strings that are still wrong.
</compact_output_contract>
