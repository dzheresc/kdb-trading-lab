# q for C++ engineers

## The mental model
| C++ | q |
|---|---|
| `std::vector<double>` | float vector (`type 9h`); every column of every table is one of these |
| `std::vector<std::any>` | general list (`0h`), a vector of K pointers |
| `std::shared_ptr` | every K object is refcounted; assignment shares, amend is copy-on-write |
| `std::unordered_map` | dictionary `k!v` (linear by default; `` `u# ``/`` `g# `` make it hashed) |
| struct-of-arrays | table = `flip` of a dictionary of columns |
| interned `std::string_view` | symbol. Never intern unbounded data (order ids): the pool never shrinks |
| `std::transform` / `accumulate` / `partial_sum` / `adjacent_difference` | `'` / `/` / `\` / `':` |
| `std::bind_front` | projection `f[x;]` |
| `std::lower_bound` on a sorted vector | `` `s# `` attribute, `bin`, and `aj` |
| exceptions | `'"msg"` to signal, `@[f;x;handler]` / `.[f;args;handler]` to trap |
| event loop (single-threaded) | each q process: messages are handled one at a time. No locks. Scale with processes |
| shared library plugin | `` `:lib 2:(`fn;arity) `` loads C/C++ into q |

## The five things that trip up experienced programmers
1. **Right-to-left evaluation, no precedence.** `2*3+4` is 14. Read expressions right to left.
2. **Loops are a code smell.** If you write `do`/`while`/`each` over scalars, look for a vector primitive or an iterator.
3. **Everything is a function application.** Indexing `v 3`, dict lookup `d`k`, and calls `f x` are the same thing.
4. **Overloading by arity and type.** `?` is find, random, vector-conditional and select depending on its arguments. `#` is take and reshape. `_` is drop and cut. Learn them in context.
5. **Nulls are typed and out-of-range indexing returns a null, not an error.** This silently hides bugs: test with real data shapes.

## Where performance comes from
* Columnar layout + typed vectors = tight loops in C over contiguous memory, often SIMD.
* Interpreter cost is per *operation*, not per element: one op over 10M elements is cheap.
* On disk, columns are files, memory-mapped. A query that touches 3 of 30 columns reads 10% of the bytes.
* Attributes turn scans into binary search (`s#`), hashing (`u#`, `g#`) or block offsets (`p#`).
* Partition pruning: a constraint on the partition column first means other dates are never touched.
