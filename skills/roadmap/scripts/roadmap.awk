# Prints the roadmap from the records of read.sh, after graph.awk. With
# -v only=<milestone number>, it prints that milestone alone, with the open
# issues it waits on in other places.

END {
  init()
  print "# Roadmap of " repo
  print ""
  if (only != "") {
    section(only, 1)
    exit
  }
  if (msn == 0) {
    print "No open milestones."
    print ""
  }
  for (i = 1; i <= msn; i++) section(mslist[i], 0)
  c = 0
  for (i = 1; i <= isn; i++) if (!ems(islist[i])) none[++c] = islist[i] + 0
  if (c) {
    sortnum(none, c)
    s = "#" none[1]
    for (i = 2; i <= c; i++) s = s ", #" none[i]
    print "## No milestone"
    print c " open: " s
  }
}

function section(m, single,   c, i, j, in_m, member, done, left, best, ok, k, e, t) {
  print "## " mstitle[m]
  # A milestone that opened between the reads has no count.
  print (mscur[m] ? "current, " : "") (m in msclosed ? msclosed[m] " of " (msopen[m] + msclosed[m]) " closed" : "not counted")
  print ""
  if (mdlines[m] != "") {
    print mdlines[m]
    print ""
  }
  c = 0
  for (i = 1; i <= isn; i++) if (ems(islist[i]) == m) { in_m[islist[i]] = 1; member[++c] = islist[i] }
  if (single) {
    closure(in_m)
    for (i = 1; i <= isn; i++) if ((islist[i] in in_m) && ems(islist[i]) != m) member[++c] = islist[i]
  }
  # Dependency order: the lowest number whose issues in the list are all
  # printed; in a cycle, the lowest number left.
  for (left = c; left > 0; left--) {
    best = ""
    for (k = 1; k <= c; k++) {
      j = member[k]
      if (j in done) continue
      ok = 1
      t = split(edges[j], e, " ")
      for (i = 1; i <= t; i++) if ((e[i] in in_m) && !(e[i] in done)) ok = 0
      if (ok && (best == "" || j + 0 < best + 0)) best = j
    }
    if (best == "") for (k = 1; k <= c; k++) if (!(member[k] in done) && (best == "" || member[k] + 0 < best + 0)) best = member[k]
    done[best] = 1
    if (mslater[m] && !single) print "- #" best " " istitle[best]
    else print "- #" best " " istitle[best] where(best, m) ": " state(best)
  }
  print ""
}

# For an issue listed under milestone m that sits elsewhere.
function where(n, m,   e) {
  e = ems(n)
  if (e == m) return ""
  return " (" (e ? mstitle[e] : "no milestone") ")"
}
