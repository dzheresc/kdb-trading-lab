/ =====================================================================
/ Lesson 08 - Performance and memory: thinking like the interpreter
/ Rule 1: the interpreter overhead is per OPERATION, not per element.
/         One op over 10M elements is fast; 10M ops over 1 element is slow.
/ =====================================================================
\S 3
n:10000000
x:n?100f
y:n?100f

/ --- 1. Timing: \t (ms) and \ts (ms; bytes) ; \t:N repeats N times ----------------
\t sum x*y                       / vectorised: ~tens of ms
\t {x*y}'[x;y]                   / each over scalars: much slower (per-element interpretation)
\ts x wsum y                     / fused primitive: less time, no temporary

/ --- 2. Prefer primitives that fuse or avoid temporaries ---------------------
/ wsum / wavg instead of sum x*y; 'within' instead of (x>=a)&x<=b; 'in' for set membership
\t (x>=10)&x<=20
\t x within 10 20

/ --- 3. Attributes change complexity, not constants ---------------------------
s:n?`4                            / 10M random 4-char syms (high cardinality)
\t:10 s=`abcd                     / linear scan
g:`g#s
\t:10 where g=`abcd               / still a scan for '='...
\t:10 g?`abcd                     / ...but find (?) uses the index
t:([] s:g; v:x)
\t:10 select from t where s=`abcd / qSQL uses the attribute for '=' and 'in' in where clauses

/ --- 4. Memory -------------------------------------------------------------
.Q.w[]                            / used, heap, peak, wmax, mmap, syms ...
-22!x                             / serialised size of an object (approx memory)
delete x, y from `.
.Q.gc[]                           / return freed memory to the OS
/ Vectors are refcounted; assignment does not copy. Amending a shared vector copies-on-write.
/ Symbols are interned FOREVER: never create symbols from unbounded data (order ids, uuids).
/ Use strings or GUIDs (type 2h) for those. Sym-file bloat is a classic production incident.

/ --- 5. Parallelism -------------------------------------------------------------
/ Start with:  q -s 8
/ chunks:{(y*til x) _ til x*y}
/ \t {sum x*x} peach 8#enlist 1000000?1f
/ For partitioned HDB queries, q automatically maps over partitions using secondary threads.

/ --- 6. Profiling checklist ---------------------------------------------------
/ * Is the date (partition) constraint first? Is sym second and attribute-backed?
/ * Are you pulling more columns than needed? Columnar => select only what you use.
/ * Any 'each' over large vectors? Replace with vector ops or a scan/over.
/ * Joins: is the right table of aj sorted/`p#? Is the lj table keyed and small?
/ * Is data crossing IPC that could be aggregated server-side first? (move the code to the data)
