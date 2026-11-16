/ =====================================================================
/ bench.q - measure, don't guess. Run from repo root: q bench/bench.q -s 4
/ Requires cpp/build/libqudf.so (cd cpp && cmake -B build && cmake --build build)
/ =====================================================================
\S 5
n:10000000
x:100+sums -0.5+n?1.0
.b.res:([] case:`symbol$(); ms:`long$(); bytes:`long$())
.b.run:{[name;f] r:system "ts:5 ",f; `.b.res insert (name;r 0;r 1);}

/ EWMA: interpreted scan vs built-in ema vs C++ UDF
ewmaQ:{[a;x] {[a;p;c] (a*c)+(1-a)*p}[a]\[x]}
.b.run[`ewma_q_scan;   "ewmaQ[0.1;x]"]
.b.run[`ewma_builtin;  "ema[0.1;x]"]
ewmaC:@[`:cpp/build/libqudf 2:;(`ewma;2);{-2 "UDF not built: ",x; ::}]
if[not (::)~ewmaC; .b.run[`ewma_cpp_udf; "ewmaC[0.1;x]"]]

/ Max drawdown: one-liner vector q vs C++ single pass
.b.run[`mdd_q;         "max 1-x%maxs x"]
mddC:@[`:cpp/build/libqudf 2:;(`maxDrawdown;1);{::}]
if[not (::)~mddC; .b.run[`mdd_cpp_udf; "mddC x"]]

/ Attribute effect on lookups
s:n?`4; g:`g#s; t:([] s:s; v:x); tg:([] s:g; v:x)
.b.run[`select_eq_nogrp; "select from t where s=`abcd"]
.b.run[`select_eq_grp;   "select from tg where s=`abcd"]

/ peach (start q with -s N to see an effect)
chunks:(n div 8) cut x                 / 8 chunks
.b.run[`sumsq_each;  "{sum x*x} each chunks"]
.b.run[`sumsq_peach; "{sum x*x} peach chunks"]

show .b.res
exit 0
