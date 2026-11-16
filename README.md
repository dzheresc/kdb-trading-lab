# kdb-trading-lab

A self-built, end-to-end kdb+/q market-data platform, plus a structured path to learn the
language. It was written as a study and portfolio project by a C++ engineer learning kdb+.

```
                     +-------------------+
  C++ feed handler --|                   |-- async pub --> RDB (today, in memory, `g#sym)
  (k.h, columnar,    |  Tickerplant      |                   |  EOD: .Q.dpft -> HDB partition
   async, batched)   |  stamp, journal,  |                   v
  q feed simulator --|  publish, EOD     |                 HDB (history, mmap'd, date-partitioned, `p#sym)
                     +-------------------+                   ^
                            | journal (replay on restart)    |
                            v                                |
                         tplogs/                   Gateway (whitelisted API, routes + merges RDB/HDB)
                                                            ^
                                      q client / C++ query_client / any IPC client
```

## What this demonstrates

| Job requirement (Kdb+/Q Engineer, trading) | Where in this repo |
|---|---|
| High-performance kdb+/q platforms for real-time research and streaming analytics | `tick/tp.q`, `tick/rdb.q` — tickerplant with journalling, sym-filtered pub/sub, zero-latency and batch modes, gap-free recovery |
| Large-scale market data, time-series analytics | `analytics/analytics.q` — VWAP, OHLCV bars, realised vol, as-of-join TCA, mark-outs (adverse selection), time-weighted spreads, book imbalance |
| Historical data at scale | `tick/hdb.q`, `tick/hdb_seed.q`, `lessons/06` — date-partitioned HDB, enumeration, `p#`, partition pruning, compression, write-down patterns |
| Distributed computing | `tick/gw.q` — gateway that routes and merges across processes; `exercises/ex05` — deferred-sync async gateway, chained TP, WDB |
| Python / Java / C++ | `cpp/` — C++17 feed handler and query client over the kdb+ C API (RAII wrapper), C++ UDFs loaded into q via `2:`, unit tests |
| Linux, operational best practice | `bin/` start/stop/reset scripts, journals, crash-recovery drill, `.z.pg` API whitelisting and audit log, `tests/test.q`, `bench/bench.q` |

## Quick start

**1. Install kdb+.** KDB-X Community Edition is free for personal and commercial use (Linux x86_64,
16 GB RAM cap for q). Sign up at the KX Developer Center and run the install command it gives you.
Check that `q` starts and `1+1` returns `2`.

**2. Build the C++ parts (optional at first)**
```bash
bin/get_c_api.sh                      # fetches k.h + c.o from github.com/KxSystems/kdb
cd cpp && cmake -S . -B build && cmake --build build -j && ./build/test_qudf && cd ..
```

**3. Run the tests**
```bash
q tests/test.q -q
```

**4. Run the stack**
```bash
bin/start.sh --seed                   # seed 10 days of history, start TP, HDB, RDB, GW and the q feed
# or: bin/start.sh --seed --cpp-feed  # use the C++ feed handler instead (2000 quotes/s, batches of 100)
q tick/client_demo.q                  # VWAP, bars, vol, TCA, mark-outs through the gateway
cpp/build/query_client localhost 5013 tca AAPL,MSFT,NVDA 3
bin/stop.sh                           # bin/reset.sh also wipes the data
```
Process logs go to `logs/`. Ports: TP 5010, RDB 5011, HDB 5012, GW 5013.

## Layout
```
lessons/     8 annotated q scripts, run line by line: basics -> iterators -> tables -> qSQL ->
             joins/time series -> on-disk storage -> IPC -> performance
exercises/   6 sets, from vector thinking to an async gateway and an order book; solutions/
tick/        schema, tickerplant, RDB, HDB, HDB seeder, gateway, q feed simulator, demo client
analytics/   pure analytics functions shared by RDB/HDB/GW and the tests
cpp/         kdb_conn.hpp (RAII over k.h), feed_handler, query_client, qudf (2: UDFs), tests
tests/       test.q - small test framework and analytics/TP tests
bench/       bench.q - q scan vs built-in vs C++ UDF, attributes, peach
docs/        study plan, q for C++ engineers, interview prep
bin/         start / stop / reset / get_c_api
```

## Status and honesty notes
* The C++ code builds cleanly against the real `k.h`/`c.o` and its unit tests pass. The feed
  handler's wire format was checked against a stub IPC server.
* The q code has been reviewed but **you must run it yourself**: running it, fixing what breaks
  and understanding why it broke is a big part of learning. Start with `q tests/test.q -q`.
* The tickerplant is my own minimal implementation for learning. In production, the standard
  pattern is KX's `kdb+tick` (`tick.q`/`u.q`). Comparing the two is a good exercise.
