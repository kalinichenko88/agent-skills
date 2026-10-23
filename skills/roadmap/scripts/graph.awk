# Loads the records of read.sh and gives the graph of the open issues to the
# awk program that runs after it:
#
#   awk -F'\t' -f graph.awk -f <program>.awk
#
# The program calls init() first in its END. An issue "waits on" its open
# blockers, the open blockers of its ancestors, and its open sub-issues: the
# edges j -> i of edges[j], for the issues that read.sh loaded.

$1 == "repo" { repo = $2 }
$1 == "me" { me = $2 }
$1 == "ms" {
  msorder[$2] = $3; mscur[$2] = $4; mslater[$2] = $5
  msopen[$2] = $6; msclosed[$2] = $7; mstitle[$2] = $8
  mslist[++msn] = $2
}
$1 == "md" { mdlines[$2] = ($2 in mdlines) ? mdlines[$2] "\n" $3 : $3 }
$1 == "is" {
  isms[$2] = $3; isbug[$2] = $4; isbusy[$2] = $5; isblk[$2] = $6
  ispar[$2] = $7; isparms[$2] = $8; issubs[$2] = $9; istitle[$2] = $10
  islist[++isn] = $2
}
$1 == "br" { isbr[$2] = ($2 in isbr) ? isbr[$2] "," $3 : $3 }

function init(   i, j, k, c, w, b) {
  for (i = 1; i <= isn; i++) {
    j = islist[i]
    if (ispar[j] in istitle) edges[ispar[j]] = edges[ispar[j]] " " j
    c = waits(j, w)
    for (k = 1; k <= c; k++) {
      b = substr(w[k], 2)
      if (w[k] ~ /^#/ && (b in istitle)) edges[j] = edges[j] " " b
    }
  }
}

# The effective milestone: the first open one of the issue's own, its
# parent's, and so on up; 0 when none. A closed milestone has no order.
function ems(n,   d) {
  for (d = 0; d < 8; d++) {
    if (isms[n] in msorder) return isms[n]
    if (isparms[n] in msorder) return isparms[n]
    if (!(ispar[n] in istitle)) return 0
    n = ispar[n]
  }
  return 0
}

# Fills out[1..count] with the open blockers of n and of its loaded
# ancestors, as read.sh wrote them (#19, other/repo#3), and returns the count.
function waits(n, out,   c, d, k, i, b, seen) {
  split("", out)
  c = 0
  for (d = 0; d < 8 && (n in istitle); d++) {
    if (isblk[n] != "-") {
      k = split(isblk[n], b, ",")
      for (i = 1; i <= k; i++) if (!(b[i] in seen)) { seen[b[i]] = 1; out[++c] = b[i] }
    }
    n = ispar[n]
  }
  return c
}

# Fills out[1..count] with the loaded open sub-issues of n.
function kids(n, out,   i, c) {
  split("", out)
  c = 0
  for (i = 1; i <= isn; i++) if (ispar[islist[i]] == n) out[++c] = islist[i]
  return c
}

function isfree(n,   w) {
  return isbusy[n] == "-" && waits(n, w) == 0 && issubs[n] == 0 && !mslater[ems(n)]
}

# 1 when a chain of edges leads from one issue to the other. The caller
# empties seen first; it stops a cycle.
function reaches(from, to, seen,   k, i, e) {
  if (from in seen) return 0
  seen[from] = 1
  k = split(edges[from], e, " ")
  for (i = 1; i <= k; i++) if (e[i] == to || reaches(e[i], to, seen)) return 1
  return 0
}

function order_of(n,   e) {
  e = ems(n)
  return e ? msorder[e] : 500000000
}

# What holds the issue: its busy text, its blockers, its open sub-issues.
function state(n,   s, w, c, k, b) {
  s = isbusy[n] == "-" ? "" : isbusy[n]
  c = waits(n, w)
  if (c) {
    b = w[1]
    for (k = 2; k <= c; k++) b = b ", " w[k]
    s = s (s == "" ? "" : "; ") "blocked by " b
  }
  if (issubs[n] > 0) s = s (s == "" ? "" : "; ") "open sub-issues: " issubs[n]
  return s == "" ? "free" : s
}
