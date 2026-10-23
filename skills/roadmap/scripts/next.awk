# Ranks the free tasks per track and lists the work in progress, from the
# records of read.sh, after graph.awk. Mixed into its output are the want
# lines, which next.sh turns into the overlap file:
#
#   want cand <n> <title> <track> <milestone title>
#   want wip  <n> <title> <busy> <files of its open PRs|-> <its branches|->
#   want pr   <n> <author> <files|->
#
# The main set is every open non-bug issue of the current milestones and every
# open issue it waits on, through any chain; its free issues are the main path.
# Bugs and secondary are the free issues outside it. A track ranks by the
# effective order (the lowest milestone order among the issue and the issues
# that wait on it), then by how many issues wait on it, then by number.

$1 == "pr" {
  prlist[++prn] = $2; prauthor[$2] = $3; prcloses[$2] = $4; prfiles[$2] = $5
}

END {
  init()
  for (j in edges) {
    k = split(edges[j], e, " ")
    for (i = 1; i <= k; i++) redges[e[i]] = redges[e[i]] " " j
  }
  last = 0
  titles = ""
  for (i = 1; i <= msn; i++) if (mscur[mslist[i]]) {
    cur[mslist[i]] = 1
    titles = titles (titles == "" ? "" : "; ") mstitle[mslist[i]]
    last = i
  }
  print "current: " (titles == "" ? "none" : titles)
  if (mainset(cur) == 0 && last) {
    for (i = last + 1; i <= msn; i++) if (!mslater[mslist[i]]) break
    if (i <= msn) {
      split("", cur)
      cur[mslist[i]] = 1
      gsub(/; /, ", ", titles)
      print "note: nothing free in " titles "; the main path is from " mstitle[mslist[i]]
      mainset(cur)
    }
  }
  nm = nb = ns = 0
  for (i = 1; i <= isn; i++) {
    j = islist[i]
    if (!isfree(j)) continue
    if (j in main) mp[++nm] = j
    else if (isbug[j]) bugs[++nb] = j
    else sec[++ns] = j
  }
  track("main path", mp, nm, nm)
  track("bugs", bugs, nb, 5)
  track("secondary", sec, ns, 5)

  print "== in progress"
  c = 0
  for (i = 1; i <= isn; i++) if (isbusy[islist[i]] != "-") busy[++c] = islist[i] + 0
  sortnum(busy, c)
  for (i = 1; i <= c; i++) {
    j = busy[i]
    print "#" j " " istitle[j] ": " isbusy[j]
    f = ""
    for (k = 1; k <= prn; k++) if (closes(prlist[k], j) && prfiles[prlist[k]] != "-")
      f = f (f == "" ? "" : ",") prfiles[prlist[k]]
    print "want\twip\t" j "\t" istitle[j] "\t" isbusy[j] "\t" (f == "" ? "-" : f) "\t" ((j in isbr) ? isbr[j] : "-")
  }
  for (k = 1; k <= prn; k++) {
    p = prlist[k]
    if (prcloses[p] != "-") continue
    print "PR #" p " by " prauthor[p] ": closes no issue"
    print "want\tpr\t" p "\t" prauthor[p] "\t" prfiles[p]
    c++
  }
  if (!c) print "none"
}

# Fills main with the open non-bug issues of the milestones in cur and every
# issue they wait on; returns how many of them are free.
function mainset(cur,   i, j, q, h, t, k, e, free) {
  split("", main)
  t = 0
  for (i = 1; i <= isn; i++) {
    j = islist[i]
    if (!isbug[j] && (ems(j) in cur)) { main[j] = 1; q[++t] = j }
  }
  for (h = 1; h <= t; h++) {
    k = split(edges[q[h]], e, " ")
    for (i = 1; i <= k; i++) if (!(e[i] in main)) { main[e[i]] = 1; q[++t] = e[i] }
  }
  free = 0
  for (j in main) if (isfree(j)) free++
  return free
}

# Prints a track's top shown issues and fills the want lines of the issues
# the overlap file takes: every one shown.
function track(name, a, n, shown,   i, j, k, m) {
  for (i = 1; i <= n; i++) { rank(a[i]); key[a[i]] = sprintf("%012d %06d %08d", eff[a[i]], 999999 - ups[a[i]], a[i]) }
  for (i = 2; i <= n; i++) for (j = i; j > 1 && key[a[j - 1]] > key[a[j]]; j--) { k = a[j]; a[j] = a[j - 1]; a[j - 1] = k }
  print "== " name
  if (!n) print "none"
  for (i = 1; i <= n && i <= shown; i++) {
    j = a[i]
    m = ems(j) ? mstitle[ems(j)] : "no milestone"
    print "#" j " " istitle[j] " (" m "), unblocks " ups[j]
    print "want\tcand\t" j "\t" istitle[j] "\t" name "\t" m
  }
  if (n > shown) print "and " n - shown " more"
}

# eff and ups of n: walks the issues that wait on it, through any chain.
function rank(n,   seen, q, h, t, k, e, i, o) {
  eff[n] = order_of(n)
  ups[n] = 0
  t = 1
  q[1] = n
  seen[n] = 1
  for (h = 1; h <= t; h++) {
    k = split(redges[q[h]], e, " ")
    for (i = 1; i <= k; i++) if (!(e[i] in seen)) {
      seen[e[i]] = 1
      q[++t] = e[i]
      ups[n]++
      o = order_of(e[i])
      if (o < eff[n]) eff[n] = o
    }
  }
}

function closes(p, n,   k, c, i) {
  k = split(prcloses[p], c, ",")
  for (i = 1; i <= k; i++) if (c[i] == n) return 1
  return 0
}

function sortnum(a, n,   i, j, t) {
  for (i = 2; i <= n; i++) for (j = i; j > 1 && a[j - 1] > a[j]; j--) { t = a[j]; a[j] = a[j - 1]; a[j - 1] = t }
}
