/ =====================================================================
/ Lesson 01 - Atoms, lists, types, evaluation order
/ Run line by line in the REPL (recommended) or: q lessons/01_basics.q
/ Convention: "/=>" shows the expected result.
/ =====================================================================

/ --- 1. Evaluation is RIGHT-TO-LEFT. There is no operator precedence. ---
2*3+4                 /=> 14   (3+4 evaluated first)
(2*3)+4               /=> 10
10-2-1                /=> 9    (10-(2-1)) -- the classic trap

/ --- 2. Atoms and type numbers (negative = atom, positive = vector) -----
type 42               /=> -7h  long (int64_t) - the default integer
type 42i              /=> -6h  int  (int32_t)
type 3.14             /=> -9h  float (double)
type 1b               /=> -1h  boolean
type 0x2a             /=> -4h  byte
type "a"              /=> -10h char
type `AAPL            /=> -11h symbol: an interned string (pointer into a global pool)
type 2026.11.10       /=> -14h date   (days since 2000.01.01)
type 12:30:00.000     /=> -19h time   (ms since midnight)
type 2026.11.10D12:30:00.000000000   /=> -12h timestamp (ns since 2000.01.01)
type 0D00:00:01       /=> -16h timespan (ns)

/ C++ mental model: a q value is a refcounted K object { type; attr; refcount; union{atom | n + data[]} }.
/ Every vector is a contiguous typed array -> this is why q is fast: everything is SIMD-friendly arrays.

/ --- 3. Simple lists (vectors) --------------------------------------
v:1 2 3 4 5
type v                /=> 7h
count v               /=> 5
v+10                  /=> 11 12 13 14 15   atoms extend over vectors
v*v                   /=> 1 4 9 16 25      element-wise
v>2                   /=> 00111b
"hello"               / a string is just a char vector (type 10h)
`AAPL`MSFT`GOOG       / symbol vector (type 11h)

/ --- 4. General (mixed) lists: vector of K pointers --------------------
g:(1;`a;"xyz";2.5)
type g                /=> 0h
count g               /=> 4

/ --- 5. Indexing == function application ------------------------------
v 0                   /=> 1
v 1 3                 /=> 2 4
v[1 3]                / same
v@2                   /=> 3
first v               /=> 1
last v                /=> 5
v 10                  /=> 0N   out-of-range index returns null, NOT an error
2#v                   /=> 1 2  take
-2#v                  /=> 4 5
2_v                   /=> 3 4 5 drop
reverse v
v where v>2           /=> 3 4 5   'where' turns a boolean mask into indices
where 00111b          /=> 2 3 4

/ --- 6. Generating data --------------------------------------------------
til 5                 /=> 0 1 2 3 4
5?10                  / 5 random longs in [0,10)
5?1.0                 / 5 random floats in [0,1)
3?`AAPL`MSFT          / 3 random picks from a list
-5?10                 / 5 DISTINCT values (deal)
\S 42                 / set the random seed (system command)

/ --- 7. Nulls and infinities ----------------------------------------------
0N 0n 0Nd 0Np         / null long, float, date, timestamp: typed nulls
null 1 0N 3           /=> 010b
0W -0W                / long +/- infinity
1%0                   /=> 0w  (float division always returns float)
7 div 2               /=> 3   integer division
7 mod 2               /=> 1

/ --- 8. Casting: type$value ----------------------------------------------
`float$1 2 3          /=> 1 2 3f
"f"$1 2 3             / same, using type char
"j"$3.7               /=> 4    rounds, does not truncate
`$"abc"               /=> `abc string -> symbol
string `abc           /=> "abc"
"D"$"2026.11.10"      / upper-case char = parse from string
`date$2026.11.10D13:00 /=> 2026.11.10
`minute$12:34:56.789  /=> 12:34

/ --- 9. Assignment vs equality --------------------------------------------
x:10                  / ':' is assignment
x+:5                  / x is now 15 (like +=)
1 2 3=1 5 3           /=> 101b  '=' is element-wise comparison
1 2 3~1 2 3           /=> 1b    '~' is match (whole-object equality)
"abc"~"abc"           /=> 1b
/ <> is not-equal, <= and >= exist; 'not' negates

/ --- 10. Aggregates and uniform functions ----------------------------------
sum v                 /=> 15
avg v                 /=> 3f
max v; min v; med v; dev v; var v
sums v                /=> 1 3 6 10 15    running sum (uniform: same length out)
deltas v              /=> 1 1 1 1 1
prev v                /=> 0N 1 2 3 4
ratios 100 110 99f    /=> 100 1.1 0.9
distinct 1 1 2 3 3    /=> 1 2 3
group `a`b`a`c        /=> `a`b`c!(0 2;1;3)   value -> indices (like unordered_map<T,vector<size_t>>)
asc 3 1 2             /=> `s#1 2 3   note the sorted attribute `s#
iasc 3 1 2            /=> 1 2 0    argsort
any v>4               /=> 1b
all v>0               /=> 1b

/ --- Try it ----------------------------------------------------------------
/ 1. Why does  2*til 5+1  return 2 4 6 8 10 ?
/ 2. Compute the mean of the squares of 1..100 in one expression.
/ 3. What does  v where 0=v mod 2  return?
