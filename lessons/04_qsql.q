/ =====================================================================
/ Lesson 04 - qSQL: select / exec / update / delete, by, fby, functional form
/ =====================================================================
\S 42
n:1000000
syms:`AAPL`MSFT`GOOG`AMZN`NVDA
trade:([] time:asc 09:30:00.000+n?23400000; sym:n?syms; px:100+n?50.0; sz:100*1+n?10; side:n?"BS")

/ --- 1. select ------------------------------------------------------------
select from trade where sym=`AAPL
select time, px from trade where sym=`AAPL, sz>500   / ',' = AND, applied SEQUENTIALLY
/ Put the most selective (or attribute-backed) constraint first: each clause
/ only sees rows that survived the previous one.
select from trade where i<5                          / i = virtual row index

/ --- 2. Aggregation with by (returns a keyed table) -----------------------
select n:count i, vwap:sz wavg px, hi:max px, lo:min px by sym from trade
select vol:sum sz by sym, side from trade
/ time bucketing with xbar: 5-minute OHLC bars
select o:first px, h:max px, l:min px, c:last px, v:sum sz by sym, bar:5 xbar time.minute from trade

/ --- 3. exec: returns vectors/dicts instead of tables -----------------------
exec px from trade where sym=`AAPL      / a float vector
exec sum sz by sym from trade           / a dictionary

/ --- 4. update / delete (return a copy unless you pass the table name) -------
update notional:px*sz from trade
update rel:px%avg px by sym from trade         / 'by' in update = window function per group
update cumvol:sums sz by sym from trade        / running volume per sym
update notional:px*sz from `trade             / in-place: pass the NAME `trade
delete from trade where sz<200                 / returns copy
delete side from trade                         / drop a column

/ --- 5. fby: filter by a per-group aggregate (SQL HAVING / window in WHERE) ---
select from trade where px=(max;px) fby sym              / the max-price trade(s) per sym
select from trade where sz>(avg;sz) fby sym              / above-average size per sym

/ --- 6. Functional form: ?[t;where;by;select]  ![t;where;by;cols] ------------
/ Needed when column names or tables are parameters. Learn to read it via parse:
parse "select vwap:sz wavg px by sym from trade where sz>500"
?[trade;enlist(>;`sz;500);(enlist`sym)!enlist`sym;(enlist`vwap)!enlist(wavg;`sz;`px)]
/ GOTCHA: inside a parse tree a symbol is a COLUMN reference; enlist it to mean the value:
f:{[t;s] ?[t;enlist(in;`sym;enlist s);0b;()]}
f[trade;`AAPL`MSFT]

/ --- 7. Sorting and ranking ---------------------------------------------------
`sym`time xasc trade
select [10] from `px xdesc trade                   / top 10 by price ([n] limits rows)
select [-5] from trade                             / last 5 rows

/ --- 8. Joins preview: lj with reference data -----------------------------
ref:([sym:syms] sector:`tech`tech`tech`retail`semis)
select vol:sum sz by sector from trade lj ref

/ --- Try it ------------------------------------------------------------------
/ 1. Per sym: count of buys, count of sells, and buy/sell volume imbalance (B-S)%(B+S).
/ 2. The 3 largest trades by notional per sym (hint: idesc + fby, or `notional xdesc then select [3] by sym... think).
/ 3. Rewrite query 2 in functional form, with the bar size as a function parameter.
