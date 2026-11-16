/ =====================================================================
/ rdb.q - real-time database: today's data in memory.
/   * subscribes to the tickerplant
/   * on startup replays today's journal (recovery after a crash/restart)
/   * at EOD writes the day to the HDB as a date partition, clears memory,
/     and tells the HDB to reload
/ Usage: q tick/rdb.q -p 5011 [-tp 5010] [-hdb 5012] [-hdbdir hdb]
/ =====================================================================
\l analytics/analytics.q

.rdb.args:.Q.opt .z.x
.rdb.opt:{[k;d] $[k in key .rdb.args; first .rdb.args k; d]}
.rdb.tpPort:"J"$.rdb.opt[`tp;"5010"]
.rdb.hdbPort:"J"$.rdb.opt[`hdb;"5012"]
.rdb.hdbdir:hsym `$.rdb.opt[`hdbdir;"hdb"]

/ ---------------- callbacks invoked by the tickerplant ----------------------
upd:{[t;x] t insert x;}

eod:{[d]
  -1 "RDB: EOD for ",(string d)," rows ",.Q.s1 .rdb.tabs!count each value each .rdb.tabs;
  {[d;t]
    if[count value t; .Q.dpft[.rdb.hdbdir;d;`sym;t]];   / sorts by sym, applies `p#, enumerates
    @[`.;t;0#];                                       / clear, keep schema
    @[t;`sym;`g#];                                    / restore the grouped index
  }[d] each .rdb.tabs;
  .Q.gc[];
  / tell the HDB to pick up the new partition
  h:@[hopen;(`$"::",string .rdb.hdbPort;2000);0Ni];
  if[not null h; neg[h] (`.hdb.reload;::); neg[h][]; hclose h];
  -1 "RDB: EOD done";}

/ ---------------- query API used by the gateway ------------------------------
/ Parameterised table name -> functional select. Time constraint first (data is time-ordered),
/ then sym via the `g# index.
.rdb.sel:{[t;s;st;et] ?[t;((within;`time;(st;et));(in;`sym;enlist (),s));0b;()]}

/ ---------------- startup: subscribe + replay -------------------------------
.rdb.start:{
  .rdb.tp:@[hopen;(`$"::",string .rdb.tpPort;5000);{-2 "RDB: cannot connect to TP: ",x; exit 1}];
  r:.rdb.tp (`.tp.subAll; `);                 / -> ((t;schema)...; (msgCount; journal))
  {[ts] (ts 0) set ts 1} each r 0;           / create empty tables
  .rdb.tabs:first each r 0;
  / replay the journal: evaluates each logged (`upd;t;x) -> calls our upd
  -1 "RDB: replaying ",(string r[1;0])," msgs from ",string r[1;1];
  if[0<r[1;0]; -11!(r[1;0]; r[1;1])];
  {[t] @[t;`sym;`g#]} each .rdb.tabs;
  -1 "RDB: ready ",.Q.s1 .rdb.tabs!count each value each .rdb.tabs;}

.rdb.start[];
