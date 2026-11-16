/ =====================================================================
/ analytics.q - pure functions over trade/quote tables. Loaded by RDB, HDB, GW and tests.
/ All take plain (unkeyed) tables with columns:
/   trade: time sym price size side      quote: time sym bid ask bsize asize
/ and return unkeyed tables (easier to ship over IPC and to C++ clients).
/ =====================================================================

/ VWAP, volume, trade count per sym
.an.vwap:{[tr] 0!select vwap:size wavg price, volume:sum size, trades:count i by sym from tr}

/ OHLCV bars of m minutes
.an.bars:{[tr;m]
  0!select open:first price, high:max price, low:min price, close:last price,
           volume:sum size, vwap:size wavg price, trades:count i
    by sym, bar:(m*0D00:01) xbar time from tr}

/ Annualised realised volatility from m-minute bar closes (6.5h session, 252 days)
.an.rvol:{[tr;m]
  b:.an.bars[tr;m];
  0!select rvol:sqrt[252*390%m]*dev 1_log ratios close, bars:count i by sym from b}

/ Transaction cost analysis: as-of join each trade to the prevailing quote.
/ slippage is side-signed vs mid, in basis points (positive = paid away)
.an.tcaDetail:{[tr;qt]
  t:aj[`sym`time; tr; select time, sym, bid, ask from qt];
  t:update mid:0.5*bid+ask from t;
  update slipBps:1e4*?[side="B"; price-mid; mid-price]%mid, spreadBps:1e4*(ask-bid)%mid from t}

.an.tca:{[tr;qt]
  t:.an.tcaDetail[tr;qt];
  0!select trades:count i, avgSlipBps:avg slipBps, volWSlipBps:size wavg slipBps,
           avgSpreadBps:avg spreadBps, noQuote:sum null mid
    by sym from t}

/ Mark-outs: side-signed mid move h after each trade, for each horizon in hs (timespans), in bps.
/ Measures adverse selection: are we trading right before the market moves against us?
.an.markouts:{[tr;qt;hs]
  q:select time, sym, mid:0.5*bid+ask from qt;
  base:aj[`sym`time; tr; q];
  sgn:?[base[`side]="B";1f;-1f];
  r:{[base;q;sgn;h]
      fut:aj[`sym`time; update time:time+h from select time, sym from base; q];
      1e4*sgn*(fut[`mid]-base`mid)%base`mid
    }[base;q;sgn] each hs;
  t:base,'flip (`$"mo_",/:string (`long$hs) div 1000000)!r;   / one column per horizon in ms, e.g. mo_1000
  mc:cols[t] where cols[t] like "mo_*";
  0!?[t;();(enlist`sym)!enlist`sym;(`trades,mc)!(enlist (count;`i)),{(avg;x)} each mc]}

/ Quoted spread stats, time-weighted: each quote counts for as long as it was live
.an.spread:{[qt]
  0!select twSpreadBps:(1_deltas `long$time) wavg -1_1e4*(ask-bid)%0.5*bid+ask,
           avgSpreadBps:avg 1e4*(ask-bid)%0.5*bid+ask,
           quotes:count i
    by sym from qt}

/ Top-of-book size imbalance, averaged per m-minute bucket: (bsize-asize)%(bsize+asize)
.an.imbalance:{[qt;m]
  0!select imb:avg (bsize-asize)%bsize+asize by sym, bar:(m*0D00:01) xbar time from qt}
