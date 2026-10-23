# Prints, one per line, the open issues outside Later that wait on issue n or
# on a sub-issue that goes into Later with it, from the records of read.sh,
# after graph.awk:
#
#   awk -F'\t' -v n=<n> [-v parent=<p>] -f graph.awk -f later.awk
#
# A sub-issue with no milestone of its own takes its parent's, so it goes too.
# With parent, n is to become a sub-issue of p: n goes into Later only when p
# is in Later and n has no milestone of its own. A task in Later that an issue
# outside Later waits on is still offered, so each issue printed means the
# move would not put n off.

END {
  init()
  if (parent != "" && (!mslater[ems(parent)] || (isms[n] in msorder))) exit
  going[n] = 1
  for (more = 1; more; ) {
    more = 0
    for (i = 1; i <= isn; i++) {
      j = islist[i]
      if (!(j in going) && (ispar[j] in going) && !(isms[j] in msorder)) { going[j] = 1; more = 1 }
    }
  }
  for (i = 1; i <= isn; i++) {
    j = islist[i]
    if ((j in going) || mslater[ems(j)]) continue
    k = split(edges[j], e, " ")
    for (x = 1; x <= k; x++) if (e[x] in going) { print j; break }
  }
}
