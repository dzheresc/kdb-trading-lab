# Exercises

Do them in order. Attempt each one before opening `solutions/`. If a solution takes
you more than 3 lines of q, look for the primitive you're missing — that is usually the lesson.

## ex01 — Thinking in vectors (lessons 01–02)
1. `fib[n]`: first n Fibonacci numbers, no loops.
2. Running drawdown of a price vector `p` (each point's distance below its running peak), and the max drawdown as a fraction.
3. Given prices `p`, return basis-point moves vs the first price, as a projection `bps:{...}[first p]` you can reuse.
4. Run-length encode a boolean vector: `rle 0011101b` → `(0 1 0 1b; 2 3 1 1)`.
5. Without `each`: for a list of strings, return the index of the longest one.

## ex02 — qSQL (lesson 04)
Using the `trade` table from lesson 04:
1. Per sym: buy count, sell count, and volume imbalance `(B-S)%(B+S)`.
2. The 3 largest trades by notional per sym.
3. A function `bars[t;m]` returning OHLCV with bar size `m` minutes, written in **functional form**.
4. Per sym, the time of the day's high and the time of the day's low.

## ex03 — Time series (lesson 05)
1. 5-minute VWAP vs TWAP (time-weighted price) per sym.
2. With `wj`, count quote updates in the 100 ms before each trade.
3. Fill a 1-second grid of mids for one sym between 14:00 and 14:10 from irregular quotes.
4. Pair trading prep: correlation of 1-minute log returns between every pair of syms (hint: `cor`, `exec ... by`).

## ex04 — Storage (lesson 06)
1. Add a `quote` table to the lesson-06 HDB and `aj` one day's trades against it.
2. `addCol[db;table;col;default]` that adds a column to every partition (update `.d` too). This is a real production chore.
3. Measure the same query with the `date` constraint first vs last. Explain the difference in one sentence.

## ex05 — Distributed systems (tick/)
1. **Async gateway.** Rewrite `tick/gw.q` so `.z.pg` returns immediately with `-30!(::)`, sends the
   RDB and HDB queries **asynchronously**, collects both replies with a callback, then answers the
   client with `-30!(clientHandle;0b;result)`. Handle backend errors (`-30!(h;1b;"msg")`) and a dead backend.
2. **Chained tickerplant.** Write `ctp.q`: subscribes to the TP, batches every 1s, republishes to its own
   subscribers. Why do real systems do this?
3. **Recovery test.** Kill the RDB mid-day, restart it, prove (with counts) it recovered every message.
   Then corrupt the last bytes of the journal (`truncate -s -10`) and make the recovery handle it (`-11!(-2;file)`).
4. **Intraday write-down (WDB).** Change the RDB to flush to a temp partition every N rows, and at EOD
   sort + `p#` + move into the HDB. When is this necessary?

## ex06 — C++ (cpp/)
1. **C++ subscriber.** Write `cpp/subscriber.cpp`: connect to the TP, call `.tp.sub[`trade;`AAPL]`
   synchronously, then loop on `k(h,(S)0)` (blocks for the next incoming message) and keep a live VWAP.
2. **Latency histogram.** Add a `srcTime` column stamped in the feed handler; in the RDB compute
   p50/p99/p99.9 of `time - srcTime` per batch size. Plot batch size vs throughput vs latency.
3. **Order book.** Extend the feed to send L2 deltas `(sym; side; level; price; size)`; in q,
   reconstruct top-5 book snapshots per sym at 1-second intervals. (A favourite interview take-home.)
