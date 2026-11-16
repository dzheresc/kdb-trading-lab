// test_qudf.cpp - unit tests for the UDFs, run outside q by linking c.o for K memory management.
#define KXVER 3
#include "k.h"
#include <cassert>
#include <cmath>
#include <cstdio>
#include <cstring>
#include <initializer_list>

extern "C" { K ewma(K, K); K maxDrawdown(K); K hawkesIntensity(K, K); }

static K fvec(std::initializer_list<double> v) {
    K x = ktn(KF, (J)v.size()); J i = 0; for (double d : v) kF(x)[i++] = d; return x;
}
static bool near(double a, double b) { return std::fabs(a - b) < 1e-12; }

int main() {
    khp(const_cast<S>(""), -1);  // initialise memory system (no connection)
    K a = kf(0.5), x = fvec({1, 2, 3, 4});
    K r = ewma(a, x);
    assert(r->t == KF && r->n == 4);
    assert(near(kF(r)[0], 1) && near(kF(r)[1], 1.5) && near(kF(r)[2], 2.25) && near(kF(r)[3], 3.125));
    r0(r);

    // Type errors: inside q, krr() raises a q error. In c.o (standalone) krr just returns (K)0,
    // so here we only check that the guard fires.
    assert(ewma(a, kj(1)) == (K)0);

    K p = fvec({100, 120, 90, 110, 60, 130});
    K m = maxDrawdown(p);
    assert(m->t == -KF && near(m->f, 0.5));  // 120 -> 60
    r0(m);

    K t = fvec({0, 1, 2});
    K h = hawkesIntensity(kf(1.0), t);
    double e = std::exp(-1.0);
    assert(near(kF(h)[0], 0) && near(kF(h)[1], e) && near(kF(h)[2], e * (1 + e)));
    r0(h);
    std::puts("qudf tests passed");
    return 0;
}
