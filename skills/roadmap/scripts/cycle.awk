# Finds the cycle that a new link would make, from the records of read.sh,
# after graph.awk:
#
#   awk -F'\t' -v act=block|sub -v a=<n> -v b=<n> -f graph.awk -f cycle.awk
#
# block a b: a waits on b, and so does every loaded descendant of a.
# sub a b: a waits on its new sub-issue b, and b and its descendants wait on
# the open blockers of a. It adds every such edge, then, for each added edge
# u -> v in turn, prints the chain #u → #v → … → #u when v reaches u. Nothing
# printed: no cycle.

END {
  init()
  c = 0
  add(a, b)
  if (act == "block") {
    k = family(a, d)
    for (i = 2; i <= k; i++) add(d[i], b)
  } else {
    nw = waits(a, w)
    k = family(b, d)
    for (i = 1; i <= k; i++) for (j = 1; j <= nw; j++)
      if (w[j] ~ /^#/ && (substr(w[j], 2) in istitle)) add(d[i], substr(w[j], 2))
  }
  for (i = 1; i <= c; i++) {
    split("", seen)
    chain = ""
    if (path(ev[i], eu[i], seen)) {
      print "#" eu[i] " → #" ev[i] chain
      exit
    }
  }
}

function add(u, v) { eu[++c] = u; ev[c] = v; edges[u] = edges[u] " " v }

# Fills out with n and its loaded descendants, n first; returns the count.
function family(n, out,   t, h, i) {
  split("", out)
  t = 1
  out[1] = n
  for (h = 1; h <= t; h++) for (i = 1; i <= isn; i++) if (ispar[islist[i]] == out[h]) out[++t] = islist[i]
  return t
}

# 1 when a chain of edges leads from one issue to the other, and it leaves
# the steps after from in chain. The caller empties seen first; it stops a
# cycle.
function path(from, to, seen,   k, i, e) {
  if (from in seen) return 0
  seen[from] = 1
  k = split(edges[from], e, " ")
  for (i = 1; i <= k; i++) if (e[i] == to || path(e[i], to, seen)) { chain = " → #" e[i] chain; return 1 }
  return 0
}
