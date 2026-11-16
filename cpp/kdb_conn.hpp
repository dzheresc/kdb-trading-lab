// kdb_conn.hpp - small RAII layer over the kdb+ C API (k.h).
//
// The C API in one paragraph:
//   * Every q value is a K: pointer to a refcounted struct {m,a,t(type),u,r(refcount), union{atom | n,data[]}}.
//   * Constructors: ki/kj/kf/ks/ktj(atoms), ktn(type,n) vectors, knk(n,...) general lists, xT/xD tables & dicts.
//   * Accessors: kJ(x)[i], kF(x)[i], kS(x)[i], kC(x)[i], kK(x)[i]; x->n is the length, x->t the type.
//   * Ownership: k(handle, "fn", args..., (K)0) CONSUMES the args (decrements their refcount).
//     A sync call returns a new K you must r0(). Type -128 means a q error; message in x->s.
//   * Symbols must be interned with ss() before being stored in a KS vector.
//   * Timestamps (type KP=12) are int64 nanoseconds since 2000.01.01.
#pragma once
#define KXVER 3
#include "k.h"

#include <chrono>
#include <cstdint>
#include <memory>
#include <stdexcept>
#include <string>

namespace kdb {

// Owning smart pointer for K objects.
struct KDeleter { void operator()(K x) const noexcept { if (x) r0(x); } };
using KPtr = std::unique_ptr<std::remove_pointer_t<K>, KDeleter>;

class Error : public std::runtime_error { using std::runtime_error::runtime_error; };

// Throws if x is a q error object; otherwise returns ownership wrapper.
inline KPtr check(K x, const char* what) {
    if (!x) throw Error(std::string(what) + ": network error");
    if (x->t == -128) {
        std::string msg = x->s ? x->s : "unknown";
        r0(x);
        throw Error(std::string(what) + ": q error '" + msg);
    }
    return KPtr(x);
}

// Nanoseconds between the Unix epoch and the kdb+ epoch (2000.01.01).
constexpr std::int64_t kKdbEpochOffsetNs = 946684800LL * 1000000000LL;

inline std::int64_t to_kdb_ns(std::chrono::system_clock::time_point tp) {
    using namespace std::chrono;
    return duration_cast<nanoseconds>(tp.time_since_epoch()).count() - kKdbEpochOffsetNs;
}
inline K timestamp(std::chrono::system_clock::time_point tp) { return ktj(-KP, to_kdb_ns(tp)); }

inline K sym(const std::string& s) { return ks(const_cast<S>(s.c_str())); }

class Connection {
public:
    Connection(const std::string& host, int port, const std::string& userpass = "", int timeoutMs = 2000) {
        h_ = khpun(const_cast<S>(host.c_str()), port, const_cast<S>(userpass.c_str()), timeoutMs);
        if (h_ <= 0)
            throw Error("cannot connect to " + host + ":" + std::to_string(port) +
                        (h_ == 0 ? " (auth rejected)" : " (connection failed)"));
    }
    ~Connection() { if (h_ > 0) kclose(h_); }
    Connection(const Connection&) = delete;
    Connection& operator=(const Connection&) = delete;

    // Sync call: fn(args...). Args are consumed. Returns the result (owned).
    template <class... Args>
    KPtr call(const char* fn, Args... args) {
        return check(k(h_, const_cast<S>(fn), args..., (K)0), fn);
    }
    // Async call: fire and forget. Args are consumed. Throws on a dead socket.
    template <class... Args>
    void send(const char* fn, Args... args) {
        K r = k(-h_, const_cast<S>(fn), args..., (K)0);
        if (!r) throw Error(std::string(fn) + ": async send failed (connection lost)");
    }
    int handle() const { return h_; }

private:
    int h_ = -1;
};

}  // namespace kdb
