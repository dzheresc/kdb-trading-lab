/ =====================================================================
/ Lesson 02 - Functions, projections, iterators (the q "loop")
/ =====================================================================

/ --- 1. Lambdas. Implicit params x y z, or explicit [a;b] (max 8) -------
sq:{x*x}
sq 4                  /=> 16
sq 1 2 3              /=> 1 4 9     vectorised for free
add:{[a;b] a+b}
add[2;3]              /=> 5

/ --- 2. Projection = partial application (std::bind_front) -------------
inc:add[1]
inc 10                /=> 11
add[;100] 5           /=> 105 (fix the 2nd argument)

/ --- 3. Control flow ------------------------------------------------------
/ $[cond;a;b] is an expression (ternary). It can chain: $[c1;a;c2;b;default]
sgn:{$[x>0;1;x<0;-1;0]}
sgn -5                /=> -1
/ ':' alone returns early.  if[] / do[] / while[] exist but are rarely idiomatic.
clamp:{[lo;hi;x] if[x<lo; :lo]; $[x>hi; hi; x]}
/ Idiomatic vector version: | is max, & is min
clampv:{[lo;hi;x] lo|hi&x}
clampv[0;10] -5 3 42  /=> 0 3 10
/ Vector conditional: ?[mask;a;b]  (like a SIMD blend)
?[1 0 1b;1 2 3;10 20 30]  /=> 1 20 3

/ --- 4. Iterators: replace almost every loop you would write in C++ --------
/ each  '      map                      std::transform
count each ("ab";"cde";"")       /=> 2 3 0
/ over  /      fold                     std::accumulate
(+/) 1 2 3 4                     /=> 10
{x*y}/[1 2 3 4]                  /=> 24
/ scan  \      running fold             std::partial_sum (with any binary op)
(+\) 1 2 3 4                     /=> 1 3 6 10
{x|y}\[3 1 4 1 5]                /=> 3 3 4 4 5   running max
/ each-prior ':                          std::adjacent_difference
(-':) 1 4 9 16                   /=> 1 3 5 7
/ each-left \:  and each-right /:  (outer-product style)
1 2 3 +\: 10 20                  /=> (11 21;12 22;13 23)
/ each-both '   zip
("ab";"cd") ,' ("x";"y")         /=> ("abx";"cdy")

/ Iterate n times / until a condition, keeping or not keeping history
{2*x}/[5;1]                      /=> 32
{2*x}\[5;1]                      /=> 1 2 4 8 16 32
{2*x}/[{x<100};1]                /=> 128
/ Converge (fixed point): f/[x] on a unary f repeats until result stops changing
{floor x%2}\[100]                /=> 100 50 25 12 6 3 1 0

/ --- 5. A classic: EWMA with scan --------------------------------------
/ Recurrence s[i] = a*x[i] + (1-a)*s[i-1]: a sequential dependency, so use scan.
ewma:{[a;x] {[a;p;c] (a*c)+(1-a)*p}[a]\[x]}
ewma[0.5;1 2 3 4f]               /=> 1 1.5 2.25 3.125
/ Built-in since 3.6:  ema[0.5;1 2 3 4f]

/ --- 6. Errors ------------------------------------------------------------
/ signal with ' ; trap with @[f;arg;handler] (unary) or .[f;args;handler] (multi-arg)
safeDiv:{[a;b] if[b=0; '"div by zero"]; a%b}
.[safeDiv;(1;0);{"caught: ",x}]  /=> "caught: div by zero"
@[{'"boom"};::;{`err}]           /=> `err

/ --- 7. Namespaces --------------------------------------------------------
.math.cube:{x*x*x}
.math.cube 3                     /=> 27
key `.math                       / list a namespace's contents

/ --- 8. Function types and 'value' ---------------------------------------
type sq                          /=> 100h lambda
value "1+2"                      /=> 3    eval a string (be careful with untrusted input)
get `sq                          / fetch a global by name
parse "1+2*3"                    / see the parse tree (useful for functional qSQL later)

/ --- Try it --------------------------------------------------------------
/ 1. Write fib:{...} returning the first n Fibonacci numbers using an iterator, no loops.
/    hint: {x,sum -2#x}/[n-2;1 1]
/ 2. Running drawdown of a price series p:  p - maxs p   ('maxs' = running max)
/ 3. Write a projection that converts prices to basis-point moves vs the first price.
