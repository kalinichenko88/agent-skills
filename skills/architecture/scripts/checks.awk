# Reads an architecture file and prints one record per invariant, its fields
# separated by \036 and the items of a list by \037: id, kind (grep, lines,
# files or review), arg, in, except, debt. On a line that it cannot read, it
# prints the cause on stderr and exits 2.
#
#   awk -f checks.awk

function stop(msg) {
  print "invariants.sh: " msg > "/dev/stderr"
  failed = 1
  exit 2
}
function bad() { stop(id ": cannot read: " line) }
# Splits s into tok[1..ntok]: a `quoted` item, or a bare word. Spaces and
# commas separate them; a last bare "." ends the line.
function tokenize(s,   i, rest) {
  ntok = 0
  while (s != "") {
    if (match(s, /^[ \t,]+/)) { s = substr(s, RLENGTH + 1); continue }
    if (substr(s, 1, 1) == "`") {
      rest = substr(s, 2)
      i = index(rest, "`")
      if (i == 0) bad()
      tok[++ntok] = substr(rest, 1, i - 1); quoted[ntok] = 1
      s = substr(rest, i + 1)
      continue
    }
    match(s, /^[^ \t,`]+/)
    tok[++ntok] = substr(s, 1, RLENGTH); quoted[ntok] = 0
    s = substr(s, RLENGTH + 1)
  }
  if (ntok && !quoted[ntok] && tok[ntok] == ".") ntok--
}
# Adds the quoted items from tok[t] on to list[name]; returns the next t.
function items(t, name,   n) {
  n = 0
  for (; t <= ntok && quoted[t]; t++) {
    if (tok[t] == "") bad()
    list[name] = list[name] (list[name] != "" ? "\037" : "") tok[t]
    n++
  }
  if (!n) bad()
  return t
}
function check(   t) {
  tokenize(substr(line, 7))
  if (ntok < 4 || quoted[1]) bad()
  kind = tok[1]; arg = tok[2]
  if (kind == "grep") { if (!quoted[2] || arg == "") bad() }
  else if (kind == "lines" || kind == "files") { if (quoted[2] || arg !~ /^[0-9]+$/) bad() }
  else bad()
  if (quoted[3] || tok[3] != "in") bad()
  t = items(4, "in")
  if (t <= ntok && !quoted[t] && tok[t] == "except") t = items(t + 1, "except")
  if (t <= ntok && !quoted[t] && tok[t] == "debt") t = items(t + 1, "debt")
  if (t <= ntok) bad()
}
function flush() {
  if (id != "") printf "%s\036%s\036%s\036%s\036%s\036%s\n", id, kind, arg, list["in"], list["except"], list["debt"]
  id = ""
}
# ind: the column where the text starts. A tab moves to the next multiple
# of 4, as in Markdown.
{
  sub(/\r$/, ""); line = $0; sub(/^[ \t]+/, "", line)
  ind = 0
  for (c = 1; c <= length($0) - length(line); c++) ind = substr($0, c, 1) == "\t" ? ind + 4 - ind % 4 : ind + 1
}
# A fenced block of backticks or tildes ends at a line of the same
# character, as long or longer, with nothing but spaces or tabs after it,
# indented up to 3 past the margin of the list item that holds the fence.
# The script does not know that margin. A fence at column 0 is in no list
# item, so its margin is 0. For an indented fence, a closing line at its
# indent closes it, one 1 to 3 past it is an error, and one 4 or more past
# it is a line of code. A non-blank line indented less, as at the end of
# that list item, is an error too: the lines that the fence hides could hold
# a check.
fence != "" {
  if (index(line, fence) == 1 && line ~ /^(`+|~+)[ \t]*$/ && ind >= indent && ind < indent + 4) {
    if (ind > indent && indent > 0) stop("a code fence at line " opened " has a closing line indented past it, at line " NR)
    fence = ""
  } else if (line != "" && ind < indent) stop("a code fence at line " opened " does not close before line " NR)
  next
}
# A line that starts with neither a space nor a tab ends the invariant.
/^[^ \t]/ { flush() }
# A run of backticks with another backtick later on the line is inline
# code, not a fence.
line ~ /^(```+[^`]*$|~~~)/ {
  indent = ind; opened = NR
  match(line, /^(`+|~+)/); fence = substr(line, 1, RLENGTH)
  next
}
/^- \*\*I-[0-9]+\.\*\*/ {
  id = $0; sub(/^- \*\*/, "", id); sub(/\.\*\*.*/, "", id)
  # A finding cites an invariant by its number, and --new-since finds the
  # invariant at the base by it.
  if (id in ids) stop(id ": a second invariant with this number, at line " NR)
  ids[id] = 1
  kind = "review"; arg = ""; split("", list); seen = more = 0
  next
}
# A list line starts with an `item`, or with the word in, except or debt and
# an `item`: a debt line, or the rest of a Check: line. Prose that starts
# with one of these words is not one.
{ listed = line ~ /^((in|except|debt)[ \t,]*)?`/ }
id == "" {
  # A Check: or debt line that no invariant holds would never be read.
  if (line ~ /^Check:[ \t]*(grep|lines|files)([ \t]|$)/) stop("a Check: line outside an invariant: " line)
  if (listed && line ~ /^debt/) stop("a debt line outside an invariant: " line)
  next
}
{
  if (line ~ /^Check:/) {
    if (seen) bad()
    seen = more = 1
    check()
  } else if (listed && line ~ /^debt/) {
    # A debt line adds to the debt list of the Check: line of its block.
    if (!seen) bad()
    tokenize(line)
    if (items(2, "debt") <= ntok) bad()
    more = 1
  } else if (more && listed) {
    # A Check: or debt line is one line: one that wraps would lose its rest.
    bad()
  } else more = 0
}
END {
  # A fence that does not close would hide each invariant below it.
  if (!failed && fence != "") stop("a code fence that does not close, at line " opened)
  if (failed) exit 2
  flush()
}
