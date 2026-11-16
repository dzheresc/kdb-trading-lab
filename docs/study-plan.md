# 8-week study plan (about 8–10 hours a week)

| Week | Read / do | Output |
|---|---|---|
| 1 | Install KDB-X. Lessons 01–02. *Q for Mortals* (Jeffry Borror, free on code.kx.com) ch. 1–6 | ex01 done without looking |
| 2 | Lesson 03–04, QfM ch. 7–9 (tables, qSQL) | ex02. Rewrite 2 queries in functional form |
| 3 | Lesson 05, QfM ch. 9 joins. KX docs: `aj`, `wj` reference pages | ex03. `tests/test.q` passes |
| 4 | Lesson 06, QfM ch. 14 (database). KX white paper on partitioning and segmentation | ex04. HDB with 10 days, measured queries |
| 5 | Lesson 07, run the whole `tick/` stack, read KX's `kdb+tick` source (`tick.q`, `u.q`, `r.q`) | Write `docs/tick-vs-mine.md`: what the standard version does that mine doesn't |
| 6 | `cpp/`: build, run the C++ feed, bench batch sizes. KX C API reference | ex06.1 (C++ subscriber) + ex06.2 latency histogram |
| 7 | ex05.1 async gateway, ex05.3 recovery drill. Lesson 08, `bench/bench.q` | A results table in the README with your own numbers |
| 8 | ex06.3 order book. Polish, push to GitHub. Do the interview questions out loud | Public repo + a 2-minute talk-through of the architecture |

**Daily habit:** 20 minutes of small puzzles in the REPL. Rewrite any loop you write as a vector expression.

**Resources**
* code.kx.com: reference card, *Q for Mortals*, white papers (tick architecture, partitioning, IPC, C API)
* KX Academy: free courses and certifications
* github.com/KxSystems: `kdb` (C API, tick), `kdb-tick`, examples
* Community: KX Slack, the KX forum, StackOverflow `[kdb]` tag
