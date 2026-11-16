/ =====================================================================
/ hdb_seed.q - build N past business days of synthetic trade + quote history
/ so the HDB and gateway have something to query from the first minute.
/ Usage: q tick/hdb_seed.q [-hdbdir hdb] [-days 10] [-quotes 2000000] -q
/ Each day is built in memory and written with .Q.dpft (sorted by sym, `p# applied).
/ =====================================================================
\l tick/schema.q
\S 11
.sd.args:.Q.opt .z.x
.sd.opt:{[k;d] $[k in key .sd.args; first .sd.args k; d]}
.sd.dir:hsym `$.sd.opt[`hdbdir;"hdb"]
.sd.days:"J"$.sd.opt[`days;"10"]
.sd.nq:"J"$.sd.opt[`quotes;"2000000"]
.sd.syms:`AAPL`MSFT`GOOG`AMZN`NVDA`META`TSLA`JPM
.sd.px0:.sd.syms!190 410 170 180 120 500 250 200f

/ last N weekdays before today (2000.01.01 was a Saturday: d mod 7 -> 0 Sat, 1 Sun)
.sd.dates:{[n] d:.z.d-1+til 3*n; n#d where not ((`int$d) mod 7) in 0 1} .sd.days

.sd.nrm:{sqrt[-2f*log 1f-x?1f]*cos 2f*acos[-1f]*x?1f}

.sd.day:{[d]
  nq:.sd.nq; nt:nq div 10;
  / quotes: per-sym GBM path sampled at random times within 13:30-20:00 UTC (US session)
  qt:([] time:d+0D13:30+asc nq?0D06:30; sym:nq?.sd.syms);
  qt:update mid:.sd.px0[first sym]*exp sums 0.0003*.sd.nrm count i by sym from qt;
  qt:update bid:mid-hs, ask:mid+hs, bsize:100*1+nq?20, asize:100*1+nq?20 from update hs:0.01*1+nq?5 from qt;
  / trades: at the touch of the prevailing quote
  tr:([] time:d+0D13:30+asc nt?0D06:30; sym:nt?.sd.syms; side:nt?"BS"; size:100*1+nt?10);
  tr:aj[`sym`time; tr; select time, sym, bid, ask from `sym`time xasc qt];
  tr:update price:?[side="B";ask;bid] from tr;
  trade::cols[trade] xcols select time, sym, price, size, side from tr where not null price;
  quote::cols[quote] xcols select time, sym, bid, ask, bsize, asize from qt;
  .Q.dpft[.sd.dir;d;`sym;`trade];
  .Q.dpft[.sd.dir;d;`sym;`quote];
  -1 (string d)," trades=",(string count trade)," quotes=",string count quote;
  }

system "mkdir -p ",1_string .sd.dir;
.sd.day each asc .sd.dates;
-1 "seeded ",(string count .sd.dates)," days into ",1_string .sd.dir;
exit 0
