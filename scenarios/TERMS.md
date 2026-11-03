# Terms

The scenarios use only these words for these things. A term means what its
row says, and nothing more: an implementation keeps a task, asks a question
or holds a branch in its own way. A word in the last column is not used for
the thing. A new term gets its row here before a scenario uses it. The `ru`
column gives the name that a person who reads Russian sees.

| Term | Meaning: what a scenario relies on | ru | Do not use |
| --- | --- | --- | --- |
| the person | The human who works with the agent. The tracker and the repository know the person's account. | человек | user, operator |
| another person | Any account other than the person's. | другой человек | someone, a teammate |
| the person's language | The language of the person's messages, or the language that the person set. | язык человека | locale |
| task | A unit of work in the tracker: an id, a title, a text, a state (open or closed), assignees, comments and linked branches. | задача | issue, ticket, card |
| task id | The number of a task, as the person writes it: `#91`. | номер задачи | |
| link | The web address of a task, which names its repository and its id. | ссылка | URL |
| tracker | The place where the tasks of one repository live. | трекер | board, backlog |
| repository | The git repository of the code, with its default branch, on GitHub. | репозиторий | repo, project |
| default branch | The branch that the work of the repository merges into. | основная ветка | main, master |
| branch | A git branch of the repository. | ветка | |
| linked branch | A branch that a task records as its own: whoever opens the task sees it. | связанная ветка | |
| pull request | A request to merge a branch into the default branch. It closes a task when it names the task with a closing word. | pull request | merge request, PR |
| assignee | An account that a task names as the one who does it. A task is assigned to the person when the person's account is an assignee. | исполнитель | owner |
| busy | A task with an assignee, a linked branch or an open pull request that closes it. | занята | taken, claimed |
| duplicate | A task that reports the same thing as another task, about the same place, in the same words or not. When it closes, it closes as a duplicate of the other task, and the other task stays as it is. | дубликат | copy |
| comment | A text added to a task after its own text. | комментарий | note, reply |
| workspace | The place where the run reads and changes the code: a copy of the repository with its branches. | рабочая копия | checkout, worktree, clone |
| the work | What a task asks for: the changes to the code in the workspace. Checking the task, assigning it and making its branch are not the work. | работа | implementation |
| the run | The handling of one message of the person, until it waits or stops. The run that takes a task goes on into the work. | прогон | session, turn |
| message | One text that the run gives the person. The person reads the messages of a run in their order. | сообщение | reply, output |
| gist | What a message tells about a task: its id, its title as the task has it, and two or three sentences in the person's language on what is wanted and what must be true for the work to be done. | суть | summary |
| tell | Give the person a message that needs no answer. | сказать | show, notify |
| ask | Give the person a question. The run then waits for the answer and changes nothing until it comes. | спросить | confirm, prompt |
| wait | End the run with nothing more changed. The next message of the person goes on with the same task. | ждать | pause |
| stop | End the run with nothing more changed. The run does not take the task: a next message that names it starts again. | остановиться | abort, quit |
