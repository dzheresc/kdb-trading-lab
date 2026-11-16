// qudf.cpp - C++ functions loaded INTO the q process as a shared library (q's 2: operator).
//
// Build: see CMakeLists.txt (target qudf -> libqudf.so). Do NOT link c.o: the symbols
// (ktn, krr, ...) are resolved from the running q binary.
// Load in q:
//   ewma:`:cpp/build/libqudf 2:(`ewma;2)       / name and arity
//   ewma[0.1; 1000000?100f]
//
// When is this worth it? When the computation is inherently sequential (a recurrence) or
// branchy, so q's vector primitives can't express it without an interpreted scan.
// Compare against q's scan/ema in bench/bench.q.
#define KXVER 3
#include "k.h"

#include <cmath>

extern "C" {

// ewma[alpha; x]  -> float vector.  s[0]=x[0]; s[i] = alpha*x[i] + (1-alpha)*s[i-1]
K ewma(K alpha, K x) {
    if (alpha->t != -KF) return krr(const_cast<S>("type: alpha must be a float atom"));
    if (x->t != KF) return krr(const_cast<S>("type: x must be a float vector"));
    const double a = alpha->f;
    K r = ktn(KF, x->n);
    if (x->n == 0) return r;
    const double* in = kF(x);
    double* out = kF(r);
    out[0] = in[0];
    for (J i = 1; i < x->n; ++i) out[i] = a * in[i] + (1.0 - a) * out[i - 1];
    return r;
}

// maxDrawdown[prices] -> float atom: largest peak-to-trough fall as a fraction of the peak.
// One pass, O(1) memory. In q: max 1-x%maxs x  (also one line - benchmark both!)
K maxDrawdown(K x) {
    if (x->t != KF) return krr(const_cast<S>("type: x must be a float vector"));
    double peak = -INFINITY, mdd = 0.0;
    for (J i = 0; i < x->n; ++i) {
        const double p = kF(x)[i];
        if (p > peak) peak = p;
        if (peak > 0) mdd = std::fmax(mdd, 1.0 - p / peak);
    }
    return kf(mdd);
}

// hawkesIntensity[beta; times] -> float vector: self-exciting decay sum
//   lambda[i] = sum_{j<i} exp(-beta*(t_i - t_j))  computed recursively in O(n).
// A typical "order-flow clustering" feature. times: float seconds, ascending.
K hawkesIntensity(K beta, K t) {
    if (beta->t != -KF || t->t != KF) return krr(const_cast<S>("type"));
    const double b = beta->f;
    K r = ktn(KF, t->n);
    double s = 0.0;
    for (J i = 0; i < t->n; ++i) {
        if (i) s = std::exp(-b * (kF(t)[i] - kF(t)[i - 1])) * (1.0 + s);
        kF(r)[i] = s;
    }
    return r;
}

}  // extern "C"
