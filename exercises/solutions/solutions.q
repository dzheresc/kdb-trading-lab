/ =====================================================================
/ Solutions for ex01-ex03 (load lessons/04 and 05 first for the tables)
/ There are always several right answers: these aim for idiomatic, not clever.
/ =====================================================================

/ ---------------- ex01 ----------------------------------------------------
fib:{[n] n#{x,sum -2#x}/[0|n-2;1 1]}
fib 10                                  /=> 1 1 2 3 5 8 13 21 34 55

p:100 120 90 110 60 130f
dd:p-maxs p                             / 0 0 -30 -10 -60 0
mdd:max 1-p%maxs p                      / 0.5

bps:{[p0;p] 1e4*(p-p0)%p0}
f:bps[first p]
f p                                     / 0 2000 -1000 1000 -4000 3000

/ run-length encoding: value at each run start, and run lengths
rle:{[b] s:where differ b; (b s; deltas (1_s),count b)}
rle 0011101b                            /=> (0101b; 2 3 1 1)

/ index of longest string: count each is fine here (it's an each over strings, not scalars)
longest:{first idesc count each x}
longest ("ab";"abcd";"a")               /=> 1

/ ---------------- ex02 (trade from lessons/04: time sym px sz side) ---------------
/ 1. buy/sell counts and imbalance
select nB:sum side="B", nS:sum side="S",
       imb:(sum[sz*side="B"]-sum sz*side="S")%sum sz
  by sym from trade

/ 2. top 3 by notional per sym. Sort once, then take the first 3 rows of each group with i-within-group:
t2:`sym`notional xdesc update notional:px*sz from trade
select from t2 where 3>({til count x};i) fby sym   / rank within group
/ alternative: ungroup select 3#... by sym -- also fine:
ungroup select 3#time, 3#px, 3#sz by sym from `notional xdesc update notional:px*sz from trade

/ 3. functional bars with a parameter
bars:{[t;m]
  a:`o`h`l`c`v!((first;`px);(max;`px);(min;`px);(last;`px);(sum;`sz));
  b:`sym`bar!(`sym;(xbar;m;($;enlist`minute;`time)));   / `minute$time
  ?[t;();b;a]}
bars[trade;15]

/ 4. time of high and low per sym
select hiTime:time px?max px, loTime:time px?min px by sym from trade
/ (px?max px finds the first index of the max inside each group; index time with it)

/ ---------------- ex03 (tables from lessons/05: trade, quote, tq) ----------------
/ 1. 5-minute VWAP vs TWAP. TWAP weights each price by how long it stood.
select vwap:sz wavg px,
       twap:(`long$next[time]-time) wavg px
  by sym, bar:5 xbar time.minute from tq
/ note: 'next' is evaluated per group inside 'by', so the last trade in each bucket gets null weight

/ 2. quote updates in the 100ms before each trade
qp:update `p#sym from `sym`time xasc quote
wj1[-100 0+\:trade`time; `sym`time; trade; (qp; (count;`bid))]

/ 3. 1-second grid of mids, one sym
g:([] sym:`AAPL; time:14:00:00.000+1000*til 601)
aj[`sym`time; g; select time, sym, mid:0.5*bid+ask from quote where sym=`AAPL]

/ 4. correlation matrix of 1-minute log returns
r:0!select c:last px by sym, 1 xbar time.minute from tq     / 1-minute closes
m:exec 1_log ratios c by sym from r      / dict: sym -> close-to-close log returns
c:{x cor/:\: x} value m                  / matrix (assumes every sym trades every minute)
([] sym:key m),'flip (key m)!c           / as a table
