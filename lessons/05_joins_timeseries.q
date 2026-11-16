/ =====================================================================
/ Lesson 05 - Joins and time-series analytics (the heart of the job)
/ aj (as-of join) and wj (window join) are why trading desks use kdb+.
/ =====================================================================
\S 7
syms:`AAPL`MSFT`GOOG
nq:300000; nt:50000
/ quotes: random walk mid per sym, 1-cent spread minimum
quote:([] time:asc 09:30:00.000+nq?23400000; sym:nq?syms)
quote:update mid:100+sums -0.5+count[i]?1.0 by sym from quote   / per-sym random walk
quote:update bid:mid-0.01*1+nq?3, ask:mid+0.01*1+nq?3 from quote
quote:delete mid from quote
trade:([] time:asc 09:30:00.000+nt?23400000; sym:nt?syms; sz:100*1+nt?10; side:nt?"BS")

/ --- 1. Reference joins ----------------------------------------------------
ref:([sym:syms] sector:`tech`tech`tech; tick:0.01 0.01 0.01)
trade lj ref                    / left join on the key of ref (keyed table on the right)
trade ij ([sym:`AAPL`GOOG] x:1 2)   / inner join
(1#trade) uj ([] sym:`ZZ; extra:1b) / union join: union of columns, nulls where missing

/ --- 2. aj: as-of join -------------------------------------------------------
/ For each trade, take the most recent quote at or before trade time, per sym.
/ Equivalent C++ thinking: per sym, std::upper_bound on quote times, minus one.
/ Requirement: the quote table must be time-ascending within each sym.
tq:aj[`sym`time; trade; quote]
/ fill trade prices from the prevailing quote (buys lift the ask, sells hit the bid)
tq:update px:?[side="B";ask;bid] from tq
/ Effective spread / slippage vs mid in basis points:
select avgSlipBps:avg 1e4*?[side="B";px-mid;mid-px]%mid by sym from update mid:0.5*bid+ask from tq
/ Performance: for large quote tables apply `p# (parted) on sym after sorting by sym,time,
/ or `g# (grouped) for in-memory RDB tables.
quoteP:update `p#sym from `sym`time xasc quote
\t aj[`sym`time; trade; quote]
\t aj[`sym`time; trade; quoteP]

/ --- 3. wj: window join ------------------------------------------------------
/ For each trade, aggregate quotes in [time-1s, time]: e.g. max ask and min bid seen.
w:-1000 0+\:trade`time          / two vectors: window starts and ends
wj[w; `sym`time; trade; (quoteP; (max;`ask); (min;`bid); (count;`ask))]
/ wj1 only considers quotes INSIDE the window; wj also takes the prevailing quote at window start.

/ --- 4. Bars, returns, rolling windows ------------------------------------
bars:select o:first px, h:max px, l:min px, c:last px, v:sum sz by sym, bar:1 xbar time.minute from tq
bars:update ret:-1+c%prev c, lr:log c%prev c by sym from 0!bars
update ma20:20 mavg c, sd20:20 mdev c, hi20:20 mmax c by sym from bars
update ewm:ema[0.1;c] by sym from bars
/ annualised realised vol from 1-minute log returns (390 minutes per day, 252 days)
select rvol:sqrt[252*390]*dev lr by sym from bars where not null lr

/ --- 5. Time-weighted average spread (TWAS) -----------------------------------
/ weight each quote by how long it was alive
/ quote k lives from time[k] to time[k+1]; inside 'by sym' everything is per sym
select twas:(1_deltas `long$time) wavg -1_ask-bid by sym from quote

/ --- 6. Gaps and fills ------------------------------------------------------
x:1 0N 0N 4 0N 6
fills x                         /=> 1 1 1 4 4 6   forward fill
0^x                             /=> 1 0 0 4 0 6   fill with value
/ align irregular data to a regular 1-minute grid (per sym) using aj:
grid:([] sym:raze 390#'syms; time:raze 3#enlist 09:30:00.000+60000*til 390)
aj[`sym`time; grid; quote]

/ --- Try it ----------------------------------------------------------------
/ 1. Mark-out analysis: for each trade, mid 1s, 5s, 30s later minus mid at trade (side-signed, bps).
/    hint: aj on trade with time shifted forward:  aj[`sym`time; update time:time+5000 from trade; quote]
/ 2. 5-minute VWAP vs TWAP per sym from tq.
/ 3. Using wj, count quote updates in the 100ms before each trade (quote "flicker" before prints).
