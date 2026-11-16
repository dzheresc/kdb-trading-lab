/ =====================================================================
/ tp.q - a minimal tickerplant, written from scratch for study.
/ Responsibilities (same as the classic kdb+tick u.q/tick.q):
/   1. receive updates from feed handlers:   upd[`trade; data]
/   2. timestamp them
/   3. append them to a journal (log) file   -> crash recovery via replay
/   4. publish them to subscribers (RDB, CEP engines, ...), optionally filtered by sym
/   5. at end of day: tell subscribers, roll the journal
/ Usage (from repo root):
/   q tick/tp.q -p 5010 [-logdir tplogs] [-batch 0|ms]
/   -batch 0   : zero-latency mode, publish every message immediately
/   -batch 100 : buffer and publish/log every 100ms (higher throughput)
/ =====================================================================
\l tick/schema.q

.tp.args:.Q.opt .z.x
.tp.opt:{[k;d] $[k in key .tp.args; first .tp.args k; d]}
.tp.logdir:hsym `$.tp.opt[`logdir;"tplogs"]
.tp.batchMs:"J"$.tp.opt[`batch;"0"]
.tp.tables:tables`.
.tp.w:.tp.tables!(count .tp.tables)#enlist ()   / table -> list of (handle; syms) ; ` = all syms

/ ---------------- journal --------------------------------------------------
.tp.logfile:{[d] ` sv .tp.logdir,`$"tp_",(string d),".log"}
.tp.openLog:{[d]
  .tp.L:.tp.logfile d;
  if[()~key .tp.L; .[.tp.L;();:;()]];            / create an empty journal
  r:-11!(-2;.tp.L);                               / count valid messages (validates the file)
  .tp.i:$[0>type r; r; first r];
  if[0<=type r; -2 "WARN: journal ",(string .tp.L)," has a corrupt tail after msg ",string .tp.i];
  .tp.l:hopen .tp.L;
  -1 "journal ",(string .tp.L)," msgs=",string .tp.i}

/ ---------------- subscriptions ------------------------------------------------
/ Called SYNC by a subscriber. Returns the empty schema table so the subscriber
/ can create it.  s: ` for all syms, or a symbol list.
.tp.sub:{[t;s]
  if[not t in .tp.tables; '"unknown table: ",string t];
  .tp.unsub[t;.z.w];
  .tp.w[t],:enlist (.z.w;s);
  (t;0#value t)}                         / empty schema (in batch mode the TP holds buffered rows)
/ Subscribe to all tables and get the journal position in ONE sync call.
/ The TP is single-threaded, so nothing can be published between the two:
/ the subscriber replays exactly .tp.i messages and then receives live updates. No gap, no dupes.
.tp.subAll:{[s] (.tp.sub[;s] each .tp.tables; (.tp.i; .tp.L))}
.tp.unsub:{[t;h] .tp.w[t]:.tp.w[t] where not h=first each .tp.w[t]}
.z.pc:{[h] .tp.unsub[;h] each .tp.tables;}

/ ---------------- publish ------------------------------------------------------
.tp.pub:{[t;x]
  {[t;x;w]
    x:$[(w 1)~`; x; select from x where sym in w 1];
    if[count x; neg[first w] (`upd; t; x)]
  }[t;x] each .tp.w t;}

/ ---------------- normalise incoming data to a table with a time column -----------
/ Accepts: a table; a list of column vectors (without time); or a single row (without time)
.tp.norm:{[t;x]
  if[98h=type x; :$[`time in cols x; x; ([] time:(count x)#.z.p),'x]];
  if[0>type first x; x:enlist each x];             / single row -> columns
  c:cols value t;
  if[(count x)<count c; x:(enlist (count first x)#.z.p),x];
  flip c!x}

/ ---------------- the entry point feeds call -------------------------------------
upd:{[t;x]
  if[not t in .tp.tables; '"unknown table: ",string t];
  x:.tp.norm[t;x];
  $[.tp.batchMs>0; t insert x; .tp.emit[t;x]];}
.u.upd:upd                                           / compatibility with kdb+tick-style feeds

.tp.emit:{[t;x]
  .tp.l enlist (`upd;t;x);                           / journal FIRST, then publish
  .tp.i+:1;
  .tp.pub[t;x]}

.tp.flush:{
  {[t] if[count value t; .tp.emit[t;value t]; @[`.;t;0#]]} each .tp.tables;}

/ ---------------- end of day -----------------------------------------------------
.tp.eod:{
  .tp.flush[];
  d:.tp.d;
  -1 "EOD ",string d;
  {[d;h] neg[h] (`eod; d)}[d] each distinct raze {first each x} each value .tp.w;
  hclose .tp.l;
  .tp.d+:1;
  .tp.openLog .tp.d;}
/ Force an EOD for demos (otherwise it happens at midnight): h ".tp.forceEod[]"
.tp.forceEod:{.tp.eod[]}

.z.ts:{
  if[.tp.batchMs>0; .tp.flush[]];
  if[.z.d>.tp.d; .tp.eod[]];}

/ ---------------- stats for monitoring ----------------------------------------------
.tp.stats:{([] tab:.tp.tables; subs:count each .tp.w .tp.tables; buffered:count each value each .tp.tables)}

/ ---------------- start ------------------------------------------------------------
system "mkdir -p ",1_string .tp.logdir;
.tp.d:.z.d
.tp.openLog .tp.d
system "t ",string $[.tp.batchMs>0; .tp.batchMs; 1000];
-1 "tickerplant up on port ",(string system "p"),"  batch(ms)=",string .tp.batchMs;
