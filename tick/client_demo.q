/ =====================================================================
/ client_demo.q - walk through the system end to end from a q client.
/ Run while the stack is up:  q tick/client_demo.q
/ =====================================================================
gw:hopen `::5013
tp:hopen `::5010
rdb:hopen `::5011

show "--- tickerplant stats"
show tp ".tp.stats[]"

now:.z.p; today:.z.d
show "--- today's VWAP so far (RDB via gateway)"
show gw (`.api.vwap; `AAPL`MSFT`NVDA; `timestamp$today; now)

show "--- 5-minute bars across history + today (HDB + RDB merged by the gateway)"
show 10#gw (`.api.bars; `AAPL; now-7D; now; 5)

show "--- realised vol from 5-minute bars, last 7 days"
show gw (`.api.rvol; `AAPL`MSFT`GOOG`NVDA; now-7D; now; 5)

show "--- TCA: slippage vs prevailing mid (as-of join)"
show gw (`.api.tca; `AAPL`MSFT`GOOG`NVDA; now-3D; now)

show "--- mark-outs (adverse selection) at 1s/5s/30s, bps"
show gw (`.api.markouts; `AAPL`MSFT; now-3D; now)

show "--- the gateway refuses arbitrary code:"
show @[gw; "til 10"; {"refused: ",x}]

show "--- crash recovery demo: count in RDB, then restart RDB and watch it replay the journal"
show rdb "count each (trade;quote)"
show "Run: kill $(cat logs/rdb.pid); q tick/rdb.q -p 5011 -tp 5010 -hdb 5012 -hdbdir hdb"
show "--- EOD demo (writes today to the HDB as a new partition):  tp \".tp.forceEod[]\""
