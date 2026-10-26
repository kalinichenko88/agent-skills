#!/usr/bin/env bash
# Runs the Check: lines of a project's architecture file, docs/ARCHITECTURE.md
# or ARCHITECTURE.md at the root, and prints one line per invariant: PASS,
# FAIL or review only, with what each check found under it.
#
#   invariants.sh [--new-since <base>] [ref]
#
# Without a ref, it reads the working tree, with the untracked files that git
# does not ignore; with one, that commit. It runs from any directory of the
# checkout. With --new-since, it runs the same checks on the base too, and puts
# the word new before each hit that the base does not have: a grep line that
# the base has fewer times in the file, by its path before a rename; a file
# with no hit at the base, or a smaller one; a folder the same, by its path.
# The syntax of a Check: line is in the skill's first-file.md. No
# text of the file runs as a command: a pattern and each path go to git grep
# as their own arguments, after -e and --, as literal pathspecs. Documents and
# other data are not code and are left out, by the debt skill's data rule.
#
# Exit 0 when no invariant fails, 1 when one fails, and 2 for a wrong call or a
# check that cannot run.
#
# Needs only bash, git and awk.

set -euo pipefail

usage() {
  echo 'usage: invariants.sh [--new-since <base>] [ref]' >&2
  exit 2
}
die() {
  echo "invariants.sh: $1" >&2
  exit 2
}

since=
if [ "${1:-}" = --new-since ]; then
  [ $# -ge 2 ] && [ -n "$2" ] || usage
  since=$2
  shift 2
fi
[ $# -le 1 ] || usage
ref=${1:-}
case $since in -*) usage ;; esac
case $ref in -*) usage ;; esac
# The data rule of measure.sh and clones.sh. It goes to awk through ENVIRON,
# because awk -v turns \. into any character.
data_file=$(dirname "$0")/../../debt/scripts/data.ere
[ -r "$data_file" ] || die "the debt skill's data.ere is not beside this skill"
data=$(<"$data_file")
top=$(git rev-parse --show-toplevel 2>/dev/null) || die 'not in a git repository'
cd "$top"

sha=
where=(--untracked)
if [ -n "$ref" ]; then
  sha=$(git rev-parse --verify -q "$ref^{commit}") || die "not a commit: $ref"
  where=("$sha")
fi
# git grep names a file of a commit as <sha>:<path>.
prefix=${sha:+$sha:}
base=
if [ -n "$since" ]; then
  base=$(git rev-parse --verify -q "$since^{commit}") || die "not a commit: $since"
fi

if [ -n "$sha" ]; then
  text=$(git show "$sha:docs/ARCHITECTURE.md" 2>/dev/null) ||
    text=$(git show "$sha:ARCHITECTURE.md" 2>/dev/null) || {
    echo "No architecture file at $ref."
    exit 0
  }
elif [ -f docs/ARCHITECTURE.md ]; then
  text=$(<docs/ARCHITECTURE.md)
elif [ -f ARCHITECTURE.md ]; then
  text=$(<ARCHITECTURE.md)
else
  echo 'No architecture file in the working tree.'
  exit 0
fi

# One record per invariant, its fields separated by \036 and the items of a
# list by \037: id, kind (grep, lines, files or review), arg, in, except, debt.
records=$(printf '%s\n' "$text" | awk '
  function stop(msg) {
    print "invariants.sh: " msg > "/dev/stderr"
    failed = 1
    exit
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
  { sub(/\r$/, ""); line = $0; sub(/^[ \t]+/, "", line) }
  # A fenced block, indented or not, of backticks or tildes, ends at a line
  # that starts with the same fence.
  fence != "" { if (index(line, fence) == 1) fence = ""; next }
  # A line that starts with neither a space nor a tab ends the invariant.
  /^[^ \t]/ { flush() }
  line ~ /^(```|~~~)/ { fence = substr(line, 1, 3); next }
  /^- \*\*I-[0-9]+\.\*\*/ {
    id = $0; sub(/^- \*\*/, "", id); sub(/\.\*\*.*/, "", id)
    kind = "review"; arg = ""; split("", list); seen = more = 0
    next
  }
  id == "" {
    # A Check: line that no invariant holds would never run.
    if (line ~ /^Check:[ \t]*(grep|lines|files)([ \t]|$)/) stop("a Check: line outside an invariant: " line)
    next
  }
  {
    # A list line holds only `items`, the words in, except and debt, commas
    # and a last ".": a debt line, or the rest of a Check: line. Prose that
    # starts with one of these words is not one.
    listed = line ~ /^((`[^`]*`|in|except|debt)[ \t,]*)+\.?$/
    if (line ~ /^Check:/) {
      if (seen) bad()
      seen = more = 1
      check()
    } else if (listed && line ~ /^debt[ \t`]/) {
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
  END { if (failed) exit 2; flush() }
') || exit 2

# was: each file that the branch renamed, as new path<TAB>old path, so that
# its hits match those of its old path at the base.
was=
if [ -n "$base" ]; then
  was=$(git -c core.quotePath=false diff --no-color --no-ext-diff -z -M --name-status "$base" ${sha:+"$sha"} | tr '\0' '\n' | awk '
    /^R/ { getline old; getline new; print new "\t" old; next }
    { getline }') || die 'git diff failed'
fi

# For the awk programs below: under(p, e) is true when the path p is the entry
# e or inside it, and under_any(p, list) gives the index of the first entry of
# a \037 list that holds p, or 0.
lib='
  function under(p, e) { sub(/\/+$/, "", e); return e == "." || p == e || index(p, e "/") == 1 }
  function under_any(p, list,   n, i, a) {
    n = split(list, a, "\037")
    for (i = 1; i <= n; i++) if (under(p, a[i])) return i
    return 0
  }
'

# ggrep <option>...: git grep with the options over the paths of the check,
# with \036 for its NUL bytes. A status past 1 is an error, not "no match".
ggrep() {
  local out code=0
  out=$(git -c core.quotePath=false --literal-pathspecs grep --no-color --no-column --null -I "$@" "${where[@]}" -- "${ins[@]}" | tr '\0' '\036') || code=$?
  [ "$code" -le 1 ] || die "$id: git grep failed"
  printf '%s\n' "$out"
}

# listing: the code files under the paths of the check, one a line as
# path<TAB>lines. git grep -c leaves out an empty file, and -L gives them: all
# on one line, each path followed by \036.
listing() {
  { ggrep -c -e '' && ggrep -L -e ''; } | DATA=$data PREFIX=$prefix awk -F'\036' '
    function add(f, n) { f = substr(f, length(ENVIRON["PREFIX"]) + 1); if (f !~ ENVIRON["DATA"]) printf "%s\t%s\n", f, n }
    NF && $NF != "" { add($1, $2); next }
    { for (i = 1; i < NF; i++) add($i, 0) }'
}

# grep_hits: the lines that the pattern finds, as path<TAB>line<TAB>text,
# with no data file and no except path.
grep_hits() {
  ggrep -n -E -e "$arg" | DATA=$data EXCEPT=$except_ PREFIX=$prefix awk -F'\036' "$lib"'
    NF {
      f = substr($1, length(ENVIRON["PREFIX"]) + 1)
      if (f ~ ENVIRON["DATA"] || under_any(f, ENVIRON["EXCEPT"])) next
      t = $0; sub(/^[^\036]*\036[^\036]*\036/, "", t)
      printf "%s\t%s\t%s\n", f, $2, t
    }'
}

# size_hits: from the listing on stdin, the files past the limit of a lines
# check, as path<TAB>lines, or the folders past that of a files check, as
# folder<TAB>files, with no except path. A folder counts its own code files,
# not those of its subfolders.
size_hits() {
  KIND=$kind N=$arg EXCEPT=$except_ awk -F'\t' "$lib"'
    !NF || under_any($1, ENVIRON["EXCEPT"]) { next }
    ENVIRON["KIND"] == "lines" { if ($2 + 0 > ENVIRON["N"] + 0) printf "%s\t%s\n", $1, $2; next }
    { d = $1; if (!sub(/\/[^\/]*$/, "", d)) d = "."; count[d]++ }
    END { for (d in count) if (count[d] > ENVIRON["N"] + 0) printf "%s\t%s\n", d, count[d] }'
}

# base_hits: the hits of the same check at the base. The base may not have the
# paths of the check, and is not checked for them.
base_hits() {
  local where=("$base") prefix=$base:
  if [ "$kind" = grep ]; then grep_hits; else listing | size_hits; fi
}

# report: prints the block of one invariant: the hits, the known debt, and the
# debt entries with no hit. Its input is $was, a line \035, the hits at the
# base, a line \035, then the sorted hits. It exits 1 when it fails, that is
# when a hit is not under a debt entry.
report() {
  ID=$id KIND=$kind DEBT=$debt_ SINCE=$base awk -F'\t' "$lib"'
    BEGIN { nd = split(ENVIRON["DEBT"], entry, "\037"); grep = ENVIRON["KIND"] == "grep" }
    $0 == "\035" { part++; next }
    !NF { next }
    { t = $0; sub(/^[^\t]*\t[^\t]*\t/, "", t) }
    part == 0 { was[$1] = $2; next }
    part == 1 { if (grep) seen[$1 "\t" t]++; else size[$1] = $2 + 0; next }
    {
      h = grep ? $1 ":" $2 ":" t : $1 " " $2
      # p: the path of the hit at the base. A folder keeps its path.
      p = $1
      if (ENVIRON["KIND"] != "files" && ($1 in was)) p = was[$1]
      if (ENVIRON["SINCE"] == "") fresh = 0
      else if (grep) fresh = seen[p "\t" t]-- <= 0
      else fresh = !(p in size) || size[p] < $2 + 0
      mark = fresh ? "new " : ""
      known = 0
      for (i = 1; i <= nd; i++) if (under($1, entry[i])) known = held[i] = 1
      if (known) debt[++k] = mark "debt " h; else hit[++n] = mark h
    }
    END {
      print ENVIRON["ID"] " " (n ? "FAIL" : "PASS")
      for (i = 1; i <= n; i++) print "  " hit[i]
      for (i = 1; i <= k; i++) print "  " debt[i]
      for (i = 1; i <= nd; i++) if (!held[i]) { e = entry[i]; sub(/\/+$/, "", e); print "  no longer debt " e }
      exit n ? 1 : 0
    }'
}

status=0
while IFS=$'\036' read -r id kind arg in_ except_ debt_; do
  [ -n "$id" ] || continue
  if [ "$kind" = review ]; then
    echo "$id review only"
    continue
  fi
  IFS=$'\037' read -r -a ins <<<"$in_"

  # A path with no code file outside the except paths is a typo, an empty
  # folder or an except path too wide: a check that reads nothing would pass
  # forever.
  files=$(listing) || exit 2
  missing=$(printf '%s\n' "$files" | IN=$in_ EXCEPT=$except_ awk -F'\t' "$lib"'
    NF && !under_any($1, ENVIRON["EXCEPT"]) { code[$1] = 1 }
    END {
      n = split(ENVIRON["IN"], a, "\037")
      for (i = 1; i <= n; i++) {
        found = 0
        for (f in code) if (under(f, a[i])) { found = 1; break }
        if (!found) { print a[i]; exit }
      }
    }')
  [ -z "$missing" ] || die "$id: no code file under $missing"

  if [ "$kind" = grep ]; then
    hits=$(grep_hits) || exit 2
  else
    hits=$(printf '%s\n' "$files" | size_hits)
  fi
  old=
  [ -z "$base" ] || old=$(base_hits) || exit 2
  {
    printf '%s\n' "$was" $'\035' "$old" $'\035'
    printf '%s\n' "$hits" | LC_ALL=C sort -t $'\t' -k1,1 -k2,2n
  } | report || status=1
done <<<"$records"
exit "$status"
