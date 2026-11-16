/ =====================================================================
/ Lesson 03 - Dictionaries, tables, keyed tables
/ Key insight: a table IS a flipped dictionary of equal-length column
/ vectors. kdb+ is a column store all the way down, in memory and on disk.
/ =====================================================================

/ --- 1. Dictionaries: key!value -------------------------------------------
d:`a`b`c!1 2 3
d`b                   /=> 2
d`b`c                 /=> 2 3
key d                 /=> `a`b`c
value d               /=> 1 2 3
d[`z]:26              / upsert
d+10                  / arithmetic goes through to values
d?2                   /=> `b   reverse lookup

/ --- 2. Tables ------------------------------------------------------------
t:([] sym:`AAPL`MSFT`AAPL; px:190.1 410.5 190.3; sz:100 200 300)
cols t                /=> `sym`px`sz
meta t                / column name, type char, foreign key, attribute
count t               /=> 3
t 0                   / a row is a dictionary: `sym`px`sz!(`AAPL;190.1;100)
t`px                  / a column is a vector
t[1;`px]              /=> 410.5
flip `a`b!(1 2;3 4)   / build a table by flipping a column dict
flip t                / and back again: column dict

/ --- 3. Adding rows -------------------------------------------------------
t,:(`GOOG;170.2;50)           / append a row (types must match)
`t insert (`IBM;220.0;10)     / insert by name -> returns new row indices
`t insert ([] sym:`A`B; px:1 2f; sz:1 2)  / insert a whole table
/ empty typed schema: what the tickerplant uses
trade:([] time:`timestamp$(); sym:`symbol$(); px:`float$(); sz:`long$())
meta trade

/ --- 4. Keyed tables: a dictionary from a table of keys to a table of values ---
ref:([sym:`AAPL`MSFT`GOOG] sector:`tech`tech`tech; lot:100 100 50)
ref`AAPL                       / row lookup by key
ref[`AAPL;`lot]                /=> 100
`ref upsert (`JPM;`fin;100)    / insert-or-update by key
key ref; value ref
0!ref                          / unkey
`sym xkey t                    / key by column (1!t also keys first column)

/ --- 5. Column-wise modification ------------------------------------------
@[t;`px;*;1.01]                / functional amend: multiply column px by 1.01 (returns copy)
@[`t;`sz;2*]                   / amend in place (pass the name)
t:`sym xasc t                  / sort by sym
`px xdesc t
`sz`px xcols t                 / reorder columns
`price`size xcol `px`sz xcols t   / rename leading columns ... (try it)

/ --- 6. Enumerations (how symbols are stored on disk) ---------------------
u:`AAPL`MSFT`GOOG
e:`u$`AAPL`GOOG`AAPL           / enumerate against u: stores int indices into u
type e                          /=> 20h (an enumeration)
`int$e                          /=> 0 2 0

/ --- Try it --------------------------------------------------------------
/ 1. Build a 5-row quote table with sym, bid, ask. Add a mid column by flipping to a dict,
/    adding a key, and flipping back:  flip (flip q),enlist[`mid]!enlist 0.5*q[`bid]+q`ask
/    (lesson 04 shows the one-word way: update)
/ 2. Join ref onto t:  t lj ref   (preview of lesson 05)
