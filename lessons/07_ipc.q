/ =====================================================================
/ Lesson 07 - IPC: the backbone of every kdb+ system
/ Open two terminals:
/   terminal A:  q -p 5099            (a server)
/   terminal B:  q                    (paste the client lines below)
/ =====================================================================

/ ---------------- CLIENT SIDE (terminal B) ----------------------------------
h:hopen `::5099                  / or `:host:port, `:host:port:user:pass; hopen (`::5099;1000) = 1s timeout
h "1+1"                          / SYNC, string: parsed + evaluated on the server.   Avoid in production.
h (`sum;1 2 3)                   / SYNC, functional form: (function; args...). No parsing, safer, faster.
h ({x*y};6;7)                    / you can even ship a lambda
neg[h] (`set;`a;42)              / ASYNC: fire and forget (negative handle). Returns immediately.
neg[h][]                         / flush the async queue (block until written to the socket)
h "a"                            /=> 42
/ Async + callback pattern (the client exposes a function the server calls back):
cb:{[r] -1 "got: ",.Q.s1 r}
neg[h] ({neg[.z.w] (`cb; x*2)}; 21)   / .z.w on the server = handle of the caller
hclose h

/ ---------------- SERVER SIDE (terminal A): message handlers ------------------
/ .z.po[h]  connection opened         .z.pc[h]  connection closed
/ .z.pg[x]  sync message ("get")      .z.ps[x]  async message ("set")
/ .z.pw[u;p] authenticate (return 1b to accept)
/ .z.ws    websocket messages          .z.ph / .z.pp  HTTP GET / POST
/ Override them to log, authorise, throttle or route. Example - an audit log:
/   .z.pg:{[x] -1 string[.z.p]," ",string[.z.u]," sync ",.Q.s1 x; value x}
/   .z.po:{[h] -1 "open ",string h}
/   .z.pc:{[h] -1 "close ",string h}
/ Restrict to an API (no arbitrary code):
/   .api.allowed:`getVwap`getBars
/   .z.pg:{[x] if[not (first x) in .api.allowed; '"not allowed"]; value x}

/ ---------------- Timers ------------------------------------------------------
/   \t 1000            fire .z.ts every 1000ms
/   .z.ts:{-1 string .z.p}
/   \t 0               stop

/ ---------------- Deferred sync (-30!): the async gateway pattern ----------------
/ A gateway's .z.pg can return immediately with -30!(::) ("I'll answer later"),
/ fan the request out ASYNC to RDB/HDB, then answer the original client with
/   -30!(clientHandle; 0b; result)     (or 1b and an error string)
/ so one slow HDB query doesn't block every other user. See exercises/ex05.

/ ---------------- Serialisation -----------------------------------------------
-8!`a`b!1 2                      / serialise to the wire format (byte vector)
-9!-8!`a`b!1 2                   / deserialise
-18!til 100000                   / serialise with compression (what IPC does for large msgs to remote hosts)

/ ---------------- Multithreading ---------------------------------------------------
/ q -s 8      -> 8 secondary threads; 'peach' parallelises each across them
/   {sum x*x} peach 8#enlist 10000000?1f
/ q -p -5099  -> negative port = multithreaded input: each sync query on its own thread (read-only)
/ Inside one q process the main thread is single-threaded: messages are processed one by one.
/ This is a FEATURE: no locks in the tickerplant/RDB. Scale out with processes, not threads.
