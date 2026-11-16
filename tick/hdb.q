/ =====================================================================
/ hdb.q - historical database: memory-maps the partitioned db on disk.
/ Usage: q tick/hdb.q -p 5012 [-hdbdir hdb]
/ Note: loading a db directory makes it the process's working directory.
/ =====================================================================
\l analytics/analytics.q

.hdb.args:.Q.opt .z.x
.hdb.dir:$[`hdbdir in key .hdb.args; first .hdb.args`hdbdir; "hdb"]
system "mkdir -p ",.hdb.dir;
system "l ",.hdb.dir;

.hdb.dates:{@[value;`date;()]}          / the virtual partition list, if any partitions exist
.hdb.reload:{system "l ."; -1 "HDB reloaded: ",.Q.s1 .hdb.dates[]}

/ Query API used by the gateway. Constraint order matters on disk:
/ date (partition pruning) -> sym (`p# attribute) -> time.
.hdb.sel:{[t;s;st;et]
  if[not t in tables[]; :()];
  ?[t;((within;`date;`date$(st;et));(in;`sym;enlist (),s);(within;`time;(st;et)));0b;()]}

-1 "HDB up on port ",(string system "p"),", dates: ",.Q.s1 .hdb.dates[];
