/ =====================================================================
/ test.q - a tiny test framework + tests for analytics and the TP normaliser.
/ Run from repo root:  q tests/test.q -q      (exit code 0 = all passed)
/ =====================================================================
\l analytics/analytics.q

.t.pass:0; .t.fail:0
.t.ok:{[name;cond] $[cond; .t.pass+:1; [.t.fail+:1; -2 "FAIL: ",name]];}
.t.eq:{[name;exp;act] .t.ok[name; exp~act]; if[not exp~act; -2 "  expected ",.Q.s1[exp],"\n  actual   ",.Q.s1 act];}
.t.near:{[name;exp;act] .t.ok[name; all 1e-9>abs exp-act]}
.t.throws:{[name;f;arg] .t.ok[name; @[{f x; 0b}[f];arg;{1b}]]}

/ ---------------- fixtures: small, hand-checkable ------------------------
D:2026.11.02
tr:([] time:D+0D14:00:00 0D14:00:30 0D14:02:00 0D14:06:00; sym:`A`A`B`A;
       price:10 11 20 12f; size:100 300 50 100; side:"BSBB")
qt:([] time:D+0D13:59:00 0D14:00:10 0D14:01:00 0D14:05:00 0D14:06:05;
       sym:`A`A`B`A`A; bid:9.9 10.9 19.9 11.9 12.1; ask:10.1 11.1 20.1 12.1 12.3;
       bsize:100 100 100 300 100; asize:100 300 100 100 100)

/ ---------------- vwap --------------------------------------------------
v:.an.vwap tr
/ (10*100 + 11*300 + 12*100) % 500 = 11  -- careful: in q that expression would evaluate RIGHT-TO-LEFT
.t.near["vwap A"; 11f; first exec vwap from v where sym=`A]
.t.eq["volume B"; 50; first exec volume from v where sym=`B]
.t.eq["unkeyed"; 98h; type v]

/ ---------------- bars --------------------------------------------------
b:.an.bars[tr;5]
.t.eq["A has 2 five-minute bars"; 2; count select from b where sym=`A]
.t.eq["first A bar OHLC"; 10 11 10 11f; raze value first select open,high,low,close from b where sym=`A]
.t.eq["bar boundary"; D+0D14:05; last exec bar from b where sym=`A]

/ ---------------- tca: as-of join semantics -------------------------------
d:.an.tcaDetail[tr;qt]
/ trade 1 (14:00:00, A) -> quote at 13:59 (10.0 mid); trade 2 (14:00:30) -> quote at 14:00:10 (11.0 mid)
.t.near["aj picks prevailing quote"; 10 11f; 2#exec mid from d where sym=`A]
/ trade 4 at 14:06:00 must NOT see the 14:06:05 quote (no look-ahead)
.t.near["no look-ahead"; 12f; last exec mid from d where sym=`A]
/ buy at 10 vs mid 10 -> 0 bps ; sell at 11 vs mid 11 -> 0 ; buy at 12 vs mid 12 -> 0
.t.near["slippage zero at mid"; 0 0 0f; exec slipBps from d where sym=`A]
.t.near["spread bps"; 1e4*0.2%10; first exec spreadBps from d]

/ ---------------- markouts ---------------------------------------------------
m:.an.markouts[tr;qt;enlist 0D00:00:10]
/ A buy at 14:00:00, mid 10 -> mid at 14:00:10 is 11 -> +1000 bps
.t.eq["markout columns"; `sym`trades`mo_10000; cols m]

/ ---------------- spread (time-weighted) --------------------------------------
s:.an.spread qt
.t.eq["spread rows"; `A`B; exec sym from s]

/ ---------------- TP normaliser (load tp functions without starting the TP) ---------
\l tick/schema.q
.tp.norm:{[t;x]
  if[98h=type x; :$[`time in cols x; x; ([] time:(count x)#.z.p),'x]];
  if[0>type first x; x:enlist each x];
  c:cols value t;
  if[(count x)<count c; x:(enlist (count first x)#.z.p),x];
  flip c!x}
/ NOTE: keep this copy in sync with tick/tp.q (or refactor tp.q to load it from a lib - exercise!)
r:.tp.norm[`trade; (`AAPL;101.5;100;"B")]
.t.eq["single row -> 1-row table"; (1;cols trade); (count r; cols r)]
r:.tp.norm[`trade; (`AAPL`MSFT; 101.5 200.0; 100 200; "BS")]
.t.eq["columns -> table with time"; 12h; type r`time]
.t.eq["row count"; 2; count r]

/ ---------------- report -----------------------------------------------------------
-1 "passed: ",(string .t.pass),"  failed: ",string .t.fail;
exit $[.t.fail; 1; 0]
