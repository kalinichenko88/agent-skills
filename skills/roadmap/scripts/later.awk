# Prints, one per line, the open issues outside Later that wait on issue n
# directly, from the records of read.sh, after graph.awk:
#
#   awk -F'\t' -v n=<n> -f graph.awk -f later.awk
#
# A task in Later is never offered, so each of them would wait for good.

END {
  init()
  for (i = 1; i <= isn; i++) {
    j = islist[i]
    if (j == n || mslater[ems(j)]) continue
    k = split(edges[j], e, " ")
    for (x = 1; x <= k; x++) if (e[x] == n) { print j; break }
  }
}
