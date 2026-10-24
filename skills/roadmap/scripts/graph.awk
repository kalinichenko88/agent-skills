# Loads the records of read.sh and gives the graph of the open issues to the
# awk program that runs after it:
#
#   awk -F'\t' -f graph.awk -f <program>.awk
#
# The program calls init() first in its END. An issue "waits on" its open
# blockers, the open blockers of its ancestors, and its open sub-issues: the
# edges j -> i of edges[j], for the issues that read.sh loaded.

$1 == "repo" { repo = $2 }
$1 == "ms" {
  msorder[$2] = $3; mscur[$2] = $4; mslater[$2] = $5; mstitle[$2] = $6; msdue[$2] = $7
  mslist[++msn] = $2
}
$1 == "mc" { msopen[$2] = $3; msclosed[$2] = $4 }
# Returns the list s with v added, after sep when s is not empty. Not an in
# test on the key: mawk makes the element before it reads the right side, so
# the test is always true. An empty v would add only sep, and no caller passes
# one: description lines, branches, file lists, titles and state parts all
# have text.
function append(s, sep, v) { return s (s == "" ? "" : sep) v }
$1 == "md" { mdlines[$2] = append(mdlines[$2], "\n", $3) }
$1 == "is" {
  isms[$2] = $3; isbug[$2] = $4; isbusy[$2] = $5; isblk[$2] = $6
  ispar[$2] = $7; isparms[$2] = $8; issubs[$2] = $9; istitle[$2] = $10
  islist[++isn] = $2
}
$1 == "br" { isbr[$2] = append(isbr[$2], ",", $3) }

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
  # needed: the issues outside Later, and every issue they wait on. A task in
  # Later that an issue outside it waits on is needed, however it got there.
  for (i = 1; i <= isn; i++) if (!mslater[ems(islist[i])]) needed[islist[i]] = 1
  closure(needed)
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

function isfree(n,   w) {
  return isbusy[n] == "-" && waits(n, w) == 0 && issubs[n] == 0 && (n in needed)
}

# Adds to set every issue that an issue in set waits on, through any chain.
function closure(set,   q, h, t, k, e, i, j) {
  t = 0
  for (j in set) q[++t] = j
  for (h = 1; h <= t; h++) {
    k = split(edges[q[h]], e, " ")
    for (i = 1; i <= k; i++) if (!(e[i] in set)) { set[e[i]] = 1; q[++t] = e[i] }
  }
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
    s = append(s, "; ", "blocked by " b)
  }
  if (issubs[n] > 0) s = append(s, "; ", "open sub-issues: " issubs[n])
  return s == "" ? "free" : s
}

function sortnum(a, n,   i, j, t) {
  for (i = 2; i <= n; i++) for (j = i; j > 1 && a[j - 1] > a[j]; j--) { t = a[j]; a[j] = a[j - 1]; a[j - 1] = t }
}
