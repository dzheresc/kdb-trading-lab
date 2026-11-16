# Interview prep: questions to be able to answer out loud

## Language
- Why is `2*3+4` 14? What is the type of `` `a`b!1 2 ``? Of `([] a:1 2)`?
- Difference between `each`, `peach`, `over`, `scan`, `each-prior`. Write a running max without `maxs`.
- `select` vs `exec` vs functional `?[...]`. When do you have to use the functional form?
- What does `fby` do? Write "trades above their sym's average size" two ways.
- What are `lj`, `ij`, `uj`, `aj`, `wj` for? What must be true of the right table for `aj` to be correct and fast?
- How do you trap errors? What happens to an unhandled error in a `.z.ps` handler?

## Storage
- Splayed vs partitioned vs segmented. Why enumerate symbols? What is in the `sym` file?
- The four attributes: what each costs and what it speeds up. Which one does the HDB use on `sym` and why?
- Why must the date constraint come first? What happens to a query with no date constraint on a 5-year HDB?
- How do you add a column to a 2,000-partition HDB safely? How do you fix a corrupted partition?
- Compression: what's the trade-off, and when does it make queries faster?

## Architecture (tick)
- Walk through a message's path from exchange to a researcher's query. Where can it be lost?
- What is the TP journal for? How does an RDB recover after a crash without gaps or duplicates?
- Zero-latency vs batched TP: trade-offs. When do you add a chained TP?
- The RDB runs out of memory by 2pm. What are your options? (WDB, more RDBs by sym, fewer columns, `g#` cost...)
- A gateway: sync vs deferred-sync vs async. How do you stop one user's 10-minute query hurting everyone?
- What happens at EOD, step by step, and what happens if the HDB reload fails?
- How do you handle late or out-of-order data? Corrections?

## Performance
- A query is slow: walk through your diagnosis (`\ts`, `.Q.w[]`, column count, attributes, constraint order, IPC volume).
- Why is `{x*y}'[a;b]` slow and `a*b` fast? When is a C UDF worth it? (See `bench/bench.q`.)
- Symbol bloat: how does it happen and how do you fix it?

## Talk through this repo (have a 2-minute version ready)
- Why columnar batches from the C++ feed? Async vs sync publish? What batch size did you choose and why (show numbers)?
- Why does `.tp.subAll` return the journal position in the same call as the subscription?
- What would you change to run this in production across regions?
