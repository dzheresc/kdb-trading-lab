/ =====================================================================
/ gw.q - query gateway: one entry point for clients (q, C++, Python, ...).
/ Routes by time range to HDB (history) and RDB (today), then merges.
/ Exposes a whitelisted API only (no arbitrary code from clients).
/ Usage: q tick/gw.q -p 5013 [-rdb 5011] [-hdb 5012]
/ This version is SYNCHRONOUS: one slow query blocks other users.
/ exercises/ex05 asks you to rewrite it with deferred sync (-30!) and async backends.
/ =====================================================================
\l analytics/analytics.q

.gw.args:.Q.opt .z.x
.gw.opt:{[k;d] $[k in key .gw.args; first .gw.args k; d]}
.gw.ports:`rdb`hdb!"J"$(.gw.opt[`rdb;"5011"]; .gw.opt[`hdb;"5012"])
.gw.h:`rdb`hdb!0N 0Ni                                  / int handles

.gw.connect:{[p] .gw.h[p]:@[hopen;(`$"::",string .gw.ports p;2000);0Ni]; .gw.h p}
.gw.handle:{[p] $[null h:.gw.h p; .gw.connect p; h]}
.z.pc:{[h] .gw.h:@[.gw.h; where .gw.h=h; :; 0Ni];}       / drop dead backend handles

/ Raw selection across RDB + HDB.  t: `trade|`quote ; s: sym(s) ; st/et: timestamps
/ The HDB is always asked: date-partition pruning makes it ~free when no historical
/ date is in range, and it also covers a forced intraday EOD (today's partition on disk).
/ The RDB is only asked if the range reaches today. No duplicates: the RDB is emptied at EOD.
.gw.sel:{[t;s;st;et]
  s:(),s; r:();
  if[null h:.gw.handle`hdb; '"HDB unavailable"];
  x:h (`.hdb.sel; t; s; st; et);
  if[count x; r,:enlist delete date from x];
  if[.z.d<=`date$et;
    if[null h:.gw.handle`rdb; '"RDB unavailable"];
    r,:enlist h (`.rdb.sel; t; s; st; et)];
  $[count r; raze r; ()]}

/ ---------------- public API -------------------------------------------------
.api.trades:{[s;st;et] .gw.sel[`trade;s;st;et]}
.api.quotes:{[s;st;et] .gw.sel[`quote;s;st;et]}
.api.vwap:{[s;st;et] .an.vwap .gw.sel[`trade;s;st;et]}
.api.bars:{[s;st;et;m] .an.bars[.gw.sel[`trade;s;st;et];m]}
.api.rvol:{[s;st;et;m] .an.rvol[.gw.sel[`trade;s;st;et];m]}
.api.tca:{[s;st;et] .an.tca[.gw.sel[`trade;s;st;et]; .gw.sel[`quote;s;st;et]]}
.api.markouts:{[s;st;et] .an.markouts[.gw.sel[`trade;s;st;et]; .gw.sel[`quote;s;st;et]; 0D00:00:01 0D00:00:05 0D00:00:30]}
.api.spread:{[s;st;et] .an.spread .gw.sel[`quote;s;st;et]}
.api.list:{1_key .api}

/ Only allow (`.api.fn; args...) calls. Strings and lambdas are rejected.
.gw.allowed:{` sv/: `.api,/:x} 1_key .api
.z.pg:{[x]
  if[10h=type x; '"string queries not allowed: use (`.api.fn;args...)"];
  f:first x; if[10h=type f; f:`$f];        / C API k(h,"fn",args...) sends the name as a string
  if[not f in .gw.allowed; '"not an API function: ",.Q.s1 f];
  -1 string[.z.p]," ",string[.z.u]," ",.Q.s1 x;
  value x}
.z.ps:{[x] '"async not supported"}

.gw.connect each `rdb`hdb;
-1 "gateway up on port ",(string system "p"),"  backends ",.Q.s1 .gw.h;
