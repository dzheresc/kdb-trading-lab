/ =====================================================================
/ Lesson 06 - On-disk storage: splayed and partitioned tables, attributes
/ This is where "large-scale historical market data" lives.
/ Run from the repo root: q lessons/06_storage_hdb.q
/ =====================================================================
\S 1
dbroot:`:/tmp/kdblab_db
system "rm -rf /tmp/kdblab_db"

/ --- 1. Serialise any object to a file ----------------------------------
`:/tmp/kdblab_obj set til 10
get `:/tmp/kdblab_obj

/ --- 2. Splayed table: one file per column (+ a .d file with column order) ----
/ Symbols must be ENUMERATED against a sym file first (.Q.en). On disk a sym
/ column becomes a vector of int indices into dbroot/sym.
t:([] sym:10?`AAPL`MSFT; px:10?100f; sz:10?1000)
(` sv dbroot,`ref`) set .Q.en[dbroot] t      / trailing ` in the path = splay
/ ls /tmp/kdblab_db/ref  ->  .d  px  sym  sz

/ --- 3. Partitioned table: one directory per date, each holding a splayed table ----
/ Layout:  db/sym   db/2026.11.02/trade/{.d,time,sym,price,size}   db/2026.11.03/trade/...
mkday:{[d;n]
  ([] time:d+0D09:30+asc n?0D06:30; sym:n?`AAPL`MSFT`GOOG`AMZN`NVDA;
      price:100+n?50f; size:100*1+n?10)}
days:2026.11.02+til 5
{[d] trade::mkday[d;200000]; .Q.dpft[dbroot;d;`sym;`trade]} each days
/ .Q.dpft = (d)irectory, (p)artition, (f)ield to sort+part by, (t)able name.
/ It enumerates syms, sorts by sym and applies the parted attribute `p# to sym.
delete trade from `.

/ --- 4. Load and query the HDB ---------------------------------------------
system "l /tmp/kdblab_db"         / maps the db; tables appear with a virtual 'date' column
tables[]
select count i by date from trade
/ ALWAYS constrain the partition column first: it prunes directories (no I/O for others)
select vwap:size wavg price by sym from trade where date=2026.11.04
select from trade where date within 2026.11.03 2026.11.04, sym=`AAPL, time within (2026.11.03D10:00;2026.11.03D10:05)
/ The query with sym first and date second scans every partition. Measure it:
\t select count i from trade where date=2026.11.04, sym=`AAPL
\t select count i from trade where sym=`AAPL, date=2026.11.04
meta trade                         / see `p on sym

/ .Q helpers worth knowing
.Q.pv                               / partition values
.Q.PD                               / partition directories (for segmented dbs)
.Q.qp trade                         / 1b if partitioned
count trade                         / row count across all partitions (cheap: uses .d metadata)

/ --- 5. Attributes: how kdb+ gets index-like speed -----------------------------
/ `s# sorted   -> binary search for =, within, aj         (like a sorted std::vector)
/ `u# unique   -> hash map lookup                          (std::unordered_set)
/ `p# parted   -> contiguous blocks per value + start offsets  (on disk: the HDB standard)
/ `g# grouped  -> hash map value -> index list             (RDB standard; costs memory)
v:10000000?1000
\t:100 v?999
v2:`g#v
\t:100 v2?999
s:asc v                              / asc returns with `s#
\t:100 s?999

/ --- 6. Compression -------------------------------------------------------
/ .z.zd: (logicalBlockSize; algorithm; level). algo 2=gzip, 3=snappy, 4=lz4hc, 5=zstd (4.0+)
/ Set it before writing and every write is compressed transparently:
/   .z.zd:17 2 6
/ or per file:  (`:/tmp/x;17;2;6) set til 1000000
/ -21!`:path  shows compression stats.

/ --- 7. Writing partitions efficiently in production ---------------------------
/ For very large days you do NOT build the day in memory and call .Q.dpft once.
/ You append chunks to the partition:  `:db/2026.11.02/trade/ upsert .Q.en[`:db] chunk
/ then sort and apply `p# at the end:  `sym xasc `:db/2026.11.02/trade ; @[`:db/2026.11.02/trade;`sym;`p#]
/ That is the "intraday write-down" pattern (WDB) used when the RDB can't hold a day in RAM.

/ --- Try it ----------------------------------------------------------------
/ 1. Add a quote table to the same HDB for the same days, then aj trades to quotes for one date.
/ 2. Write a function that adds a new column (default null) to EVERY partition of trade.
/    Real-life schema migration. hint: dbmaint.q from KxSystems/kdb does this; write your own first.
/ 3. Compare file sizes with and without .z.zd compression (du -sh).
