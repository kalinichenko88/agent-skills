#!/usr/bin/env bash
# Runs the Check: lines of a project's architecture file, docs/ARCHITECTURE.md
# or ARCHITECTURE.md at the root, and prints one line per invariant: PASS,
# FAIL or review only, with what each check found under it.
#
#   invariants.sh [--new-since <base>] [ref]
#
# Without a ref, it reads the working tree, with the untracked files that git
# does not ignore; with one, that commit. It runs from any directory of the
# checkout. With --new-since, it also runs the checks of the base's own
# architecture file on the base, and puts the word new before each hit that the
# base does not have with the same status, a hit that fails or a debt hit: a
# grep line that the base has fewer times in the file, by its path before a
# rename that git sees; a file with no such hit at the base, or a smaller one;
# a folder the same, by its path. An invariant is compared with the one of the
# same id and kind of check at the base; with none there, each of its hits is
# new. So it is when the script does not read that one whole in the base's
# file, or its check cannot run there: stderr says so, after "at <base>:".
# The syntax of a Check: line is in the skill's first-file.md. No text of the
# file runs as a command: a pattern and each path go to git grep as their own
# arguments, after -e and --, as literal pathspecs. Documents and other data
# are not code and are left out, by the debt skill's data rule.
#
# Exit 0 when no invariant fails, 1 when one fails, and 2 when a check of the
# ref or the working tree cannot run, also when an invariant fails. A check
# that cannot run stops only its invariant: it gets no line, each of its
# causes goes to stderr, and the other checks run. Any other cause, as a wrong
# call or a line that the script cannot read in the file it checks, stops the
# run before the first check, with exit 2.
#
# Needs only bash, git and awk, and the debt skill's data.ere beside this skill.

set -euo pipefail

usage() {
  sed -n "s/^#   ${0##*/}/usage: ${0##*/}/p" "$0" >&2
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
# checks.awk reads the architecture file into one record per invariant.
checks_file=$(dirname "$0")/checks.awk
[ -r "$checks_file" ] || die 'checks.awk is not beside this script'
checks=$(<"$checks_file")
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

# file_at <sha>: the architecture file of the commit; it fails when there is none.
file_at() { git show "$1:docs/ARCHITECTURE.md" 2>/dev/null || git show "$1:ARCHITECTURE.md" 2>/dev/null; }

if [ -n "$sha" ]; then
  text=$(file_at "$sha") || {
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
records=$(printf '%s\n' "$text" | AT='' awk "$checks") || exit 2
# olds: the records of the base's own architecture file. A base file that
# cannot be read gives the records that checks.awk printed before it stopped,
# the last one maybe cut off (see its header): the branch can be the one that
# corrects the file.
olds=
if [ -n "$base" ]; then
  if ! text=$(file_at "$base"); then
    echo "invariants.sh: at $since: no architecture file, so each hit is new" >&2
  elif ! olds=$(printf '%s\n' "$text" | AT="at $since: " awk "$checks"); then
    echo "invariants.sh: at $since: each hit of an invariant that the script did not read whole there is new" >&2
  fi
fi

# was: each file that the branch renamed, as new path<TAB>old path, so that
# its hits match those of its old path at the base.
was=
if [ -n "$base" ]; then
  was=$(git -c core.quotePath=false diff --no-color --no-ext-diff -z -M --name-status "$base" ${sha:+"$sha"} | tr '\0' '\n' | awk '
    /^R/ { getline old; getline new; print new "\t" old; next }
    { getline }') || die 'git diff failed'
fi

# For the awk programs below: under(p, e) is true when the path p is the entry
# e or inside it, and with exact only when p is e. under_any(p, list) gives the
# index of the first entry of a \037 list that holds p, or 0.
lib='
  function under(p, e, exact) { sub(/\/+$/, "", e); return exact ? p == e : e == "." || p == e || index(p, e "/") == 1 }
  function under_any(p, list, exact,   n, i, a) {
    n = split(list, a, "\037")
    for (i = 1; i <= n; i++) if (under(p, a[i], exact)) return i
    return 0
  }
'

# ggrep <option>...: git grep with the options over the paths of the check,
# with \036 for its NUL bytes. A status past 1 is an error, not "no match":
# its message starts with $at, which names the base in base_hits.
at=
ggrep() {
  local out code=0
  out=$(git -c core.quotePath=false --literal-pathspecs grep --no-color --no-column --null -I "$@" "${where[@]}" -- "${ins[@]}" | tr '\0' '\036') || code=$?
  [ "$code" -le 1 ] || die "$at$id: git grep failed"
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

# base_hits: the hits of the base's check, $barg in $bin except $bexcept, at
# the base. The base may not have the paths of the check, and is not checked
# for them.
base_hits() {
  local where=("$base") prefix=$base: arg=$barg except_=$bexcept ins at="at $since: "
  IFS=$'\037' read -r -a ins <<<"$bin"
  if [ "$kind" = grep ]; then grep_hits; else listing | size_hits; fi
}

# report: prints the block of one invariant: the hits, the known debt, and the
# debt entries with no hit. Its input is $was, a line \035, the hits at the
# base, a line \035, then the sorted hits. It exits 1 when it fails, that is
# when a hit is not under a debt entry.
report() {
  ID=$id KIND=$kind DEBT=$debt_ BDEBT=$bdebt SINCE=$base awk -F'\t' "$lib"'
    # In a files check, a debt entry is one folder, not its subfolders.
    BEGIN { nd = split(ENVIRON["DEBT"], entry, "\037"); grep = ENVIRON["KIND"] == "grep"; exact = ENVIRON["KIND"] == "files" }
    $0 == "\035" { part++; next }
    !NF { next }
    { t = $0; sub(/^[^\t]*\t[^\t]*\t/, "", t) }
    part == 0 { was[$1] = $2; next }
    # A hit at the base is keyed by its status there, debt or fail, and its path.
    part == 1 {
      p = (under_any($1, ENVIRON["BDEBT"], exact) ? "debt" : "fail") "\t" $1
      if (grep) seen[p "\t" t]++; else size[p] = $2 + 0
      next
    }
    {
      h = grep ? $1 ":" $2 ":" t : $1 " " $2
      known = 0
      for (i = 1; i <= nd; i++) if (under($1, entry[i], exact)) known = held[i] = 1
      # p: the key of the hit at the base. A folder keeps its path.
      p = $1
      if (ENVIRON["KIND"] != "files" && ($1 in was)) p = was[$1]
      p = (known ? "debt" : "fail") "\t" p
      if (ENVIRON["SINCE"] == "") fresh = 0
      else if (grep) fresh = seen[p "\t" t]-- <= 0
      else fresh = !(p in size) || size[p] < $2 + 0
      mark = fresh ? "new " : ""
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
broken=0
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
  files=$(listing) || {
    broken=1
    continue
  }
  missing=$(printf '%s\n' "$files" | ID=$id IN=$in_ EXCEPT=$except_ awk -F'\t' "$lib"'
    NF && !under_any($1, ENVIRON["EXCEPT"]) { code[$1] = 1 }
    END {
      n = split(ENVIRON["IN"], a, "\037")
      for (i = 1; i <= n; i++) {
        found = 0
        for (f in code) if (under(f, a[i])) { found = 1; break }
        if (!found) print "invariants.sh: " ENVIRON["ID"] ": no code file under " a[i]
      }
    }')
  if [ -n "$missing" ]; then
    printf '%s\n' "$missing" >&2
    broken=1
  fi

  # The grep runs also after a missing path, so that it names a pattern that
  # git rejects; its hits do not count then.
  if [ "$kind" = grep ]; then
    hits=$(grep_hits) || {
      broken=1
      continue
    }
  else
    hits=$(printf '%s\n' "$files" | size_hits)
  fi
  [ -z "$missing" ] || continue
  # The same invariant at the base: its id, with a check of the same kind.
  old=
  bdebt=
  rec=
  [ -z "$olds" ] || rec=$(ID=$id KIND=$kind awk -F'\036' '$1 == ENVIRON["ID"] && $2 == ENVIRON["KIND"]' <<<"$olds")
  if [ -n "$rec" ]; then
    IFS=$'\036' read -r _ _ barg bin bexcept bdebt <<<"$rec"
    old=$(base_hits) || {
      old=
      echo "invariants.sh: at $since: each hit of $id is new" >&2
    }
  fi
  {
    printf '%s\n' "$was" $'\035' "$old" $'\035'
    printf '%s\n' "$hits" | LC_ALL=C sort -t $'\t' -k1,1 -k2,2n
  } | report || status=1
done <<<"$records"
[ "$broken" = 0 ] || exit 2
exit "$status"
