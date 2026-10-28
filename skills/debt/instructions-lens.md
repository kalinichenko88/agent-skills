# The review of the instruction files

You read the instruction files of a project and its architecture file, and
find where they repeat each other, contradict each other, or say what no
agent needs. You do not review the code. Your prompt gives the tree. Change
no file, and run no code of the project.

1. List the instruction files:
   `git -C <tree> ls-files -s ':(glob)**/CLAUDE.md' ':(glob)**/AGENTS.md'`.
   A file of mode `120000` is a symlink, as `AGENTS.md -> CLAUDE.md`: it is
   the file that it points to, not a second one.
2. Read each of them whole, all of them. Read the architecture file,
   `docs/ARCHITECTURE.md` or `ARCHITECTURE.md` at the root, and the ADRs that
   it links.
3. Compare each file with each other one, and report:
   - **Repeat.** A rule or a fact that two files state: an instruction file
     and the architecture file, in either direction, or two instruction
     files. It is a repeat only when the other place holds the same fact. A
     nested file that adds a detail of its folder to a rule of the root
     repeats nothing. The root `CLAUDE.md` or `.claude/CLAUDE.md` and the
     root `AGENTS.md`, or the `CLAUDE.md` and the `AGENTS.md` of one folder,
     repeat nothing between them: two hosts each read one of them. A
     finding on one of such a pair holds for the other: its place names
     both.
   - **Contradiction.** Two texts that give different rules or facts for one
     case: other paths, other exceptions, another way to do one kind of work,
     a list that lacks an item. A claim that one file makes about another,
     as "this file does not repeat the instruction files", counts too.
   - **Redundancy.** A rule that a linter or a guard script already enforces
     with its own message: name the line of its config. History, as dates,
     incidents and task ids, next to a rule that stands without it. A section
     that states again a document that it links to.
4. For each repeat and each contradiction, name the place that keeps the
   text. The architecture file keeps what its parts hold: the codemap, the
   modules, the layers and the direction of imports, the patterns, the
   invariants and the limits. An instruction file keeps how to work, as the
   commands and the environment, and the nested file of a folder keeps a
   detail inside that folder, as its own layout. For a contradiction, also
   name the text that is true, from the code, or say that a person must
   choose. When that choice is architectural, it is an ADR through
   `kalinichenko:architecture`.
5. For each section that the fix moves or removes, find its citations:
   `git -C <tree> grep -n -F` for the file's name and for the heading, in the
   whole tree.

Return one line per finding,
`<kind> | <place> | <other place> | the claim | the place that keeps it`,
where a place is `path § heading`, or the path alone for text before the
first heading, with no line number. For redundancy, the other place is the
config line or the linked document, or `-`. Then one line per citation,
`citation | path:line | the section it cites`, then a last line `count: N`,
the number of findings. No finding is a valid answer.
