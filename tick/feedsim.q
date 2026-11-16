/ =====================================================================
/ feedsim.q - synthetic market data feed in q (the C++ feed in cpp/ does the same, faster).
/ Geometric Brownian motion mids per sym, quotes around the mid, trades at the touch.
/ Usage: q tick/feedsim.q [-tp 5010] [-ms 100] [-n 50]
/   every -ms milliseconds publish -n quotes and ~n/5 trades
/ =====================================================================
.fs.args:.Q.opt .z.x
.fs.opt:{[k;d] $[k in key .fs.args; first .fs.args k; d]}
.fs.h:hopen `$"::",.fs.opt[`tp;"5010"]
.fs.n:"J"$.fs.opt[`n;"50"]

.fs.syms:`AAPL`MSFT`GOOG`AMZN`NVDA`META`TSLA`JPM
.fs.mid:.fs.syms!190 410 170 180 120 500 250 200f
.fs.sigma:0.0004                                   / per-tick volatility

/ standard normals via Box-Muller
.fs.nrm:{sqrt[-2f*log 1f-x?1f]*cos 2f*acos[-1f]*x?1f}

.z.ts:{
  / evolve every mid by one GBM step
  .fs.mid*:exp .fs.sigma*.fs.nrm count .fs.syms;
  / quotes
  s:.fs.n?.fs.syms; m:.fs.mid s;
  hs:0.01*1+.fs.n?5;                               / half-spread 1..5 cents
  neg[.fs.h] (`upd; `quote; (s; m-hs; m+hs; 100*1+.fs.n?20; 100*1+.fs.n?20));
  / trades: buys at the ask, sells at the bid
  k:1|.fs.n div 5;
  s:k?.fs.syms; m:.fs.mid s; side:k?"BS";
  px:m+?[side="B";1f;-1f]*0.01*1+k?3;
  neg[.fs.h] (`upd; `trade; (s; px; 100*1+k?10; side));
  }

system "t ",.fs.opt[`ms;"100"];
-1 "feed publishing to TP every ",.fs.opt[`ms;"100"],"ms";
