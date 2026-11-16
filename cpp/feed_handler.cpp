// feed_handler.cpp - synthetic market-data feed handler publishing to the tickerplant.
//
// What a real feed handler does: decode an exchange/vendor protocol, normalise to the house
// schema, batch, and publish asynchronously to the TP. Here the "exchange" is a GBM simulator,
// but the kdb+ side (columnar batching, async publish, reconnect, back-pressure) is the real thing.
//
// Usage: feed_handler <host> <port> <msgs_per_sec> <batch_size> [seconds]
//   e.g. feed_handler localhost 5010 200000 500 60
//
// Design notes (the interview talking points):
//  * Publish COLUMNS, not rows: one K vector per column = one memcpy-friendly block per batch,
//    and the TP/RDB can insert it with a single vector append per column.
//  * Async (negative handle): the feed never waits on the TP. Use neg-handle + periodic flush.
//  * Batch size trades latency for throughput. Measure both (see bench/ notes in README).
//  * Symbols are interned once (ss) and reused.
#include "kdb_conn.hpp"

#include <array>
#include <chrono>
#include <cmath>
#include <csignal>
#include <cstdio>
#include <random>
#include <string>
#include <thread>
#include <vector>

namespace {

volatile std::sig_atomic_t g_stop = 0;
void on_signal(int) { g_stop = 1; }

struct Instrument {
    const char* name;
    double mid;
    S interned = nullptr;  // pointer into kdb's symbol pool
};

class MarketSim {
public:
    explicit MarketSim(std::uint64_t seed) : rng_(seed) {
        for (auto& i : inst_) i.interned = ss(const_cast<S>(i.name));
    }

    // Fill one columnar quote batch: (sym; bid; ask; bsize; asize)
    K quoteBatch(int n) {
        K s = ktn(KS, n), b = ktn(KF, n), a = ktn(KF, n), bs = ktn(KJ, n), as = ktn(KJ, n);
        for (int i = 0; i < n; ++i) {
            Instrument& in = step();
            double half = 0.01 * (1 + tick_(rng_));
            kS(s)[i] = in.interned;
            kF(b)[i] = in.mid - half;
            kF(a)[i] = in.mid + half;
            kJ(bs)[i] = 100 * (1 + size_(rng_));
            kJ(as)[i] = 100 * (1 + size_(rng_));
        }
        return knk(5, s, b, a, bs, as);  // knk takes ownership of the columns
    }

    // Fill one columnar trade batch: (sym; price; size; side)
    K tradeBatch(int n) {
        K s = ktn(KS, n), p = ktn(KF, n), z = ktn(KJ, n), sd = ktn(KC, n);
        for (int i = 0; i < n; ++i) {
            Instrument& in = pick();
            bool buy = coin_(rng_);
            double half = 0.01 * (1 + tick_(rng_));
            kS(s)[i] = in.interned;
            kF(p)[i] = buy ? in.mid + half : in.mid - half;
            kJ(z)[i] = 100 * (1 + size_(rng_));
            kC(sd)[i] = buy ? 'B' : 'S';
        }
        return knk(4, s, p, z, sd);
    }

private:
    Instrument& pick() { return inst_[idx_(rng_)]; }
    Instrument& step() {
        Instrument& in = pick();
        in.mid *= std::exp(kSigma * norm_(rng_));  // geometric Brownian motion, zero drift
        return in;
    }

    static constexpr double kSigma = 0.0002;
    std::array<Instrument, 8> inst_{{{"AAPL", 190}, {"MSFT", 410}, {"GOOG", 170}, {"AMZN", 180},
                                     {"NVDA", 120}, {"META", 500}, {"TSLA", 250}, {"JPM", 200}}};
    std::mt19937_64 rng_;
    std::normal_distribution<double> norm_{0.0, 1.0};
    std::uniform_int_distribution<int> idx_{0, 7};
    std::uniform_int_distribution<int> tick_{0, 4};
    std::uniform_int_distribution<int> size_{0, 19};
    std::bernoulli_distribution coin_{0.5};
};

}  // namespace

int main(int argc, char** argv) {
    if (argc < 5) {
        std::fprintf(stderr, "usage: %s host port msgs_per_sec batch_size [seconds]\n", argv[0]);
        return 1;
    }
    const std::string host = argv[1];
    const int port = std::stoi(argv[2]);
    const long rate = std::stol(argv[3]);
    const int batch = std::stoi(argv[4]);
    const long seconds = argc > 5 ? std::stol(argv[5]) : 0;  // 0 = run until Ctrl-C

    std::signal(SIGINT, on_signal);
    std::signal(SIGTERM, on_signal);

    // Standalone C API programs must initialise the memory system before creating K objects
    // if they haven't opened a connection yet (we intern symbols before connecting).
    khp(const_cast<S>(""), -1);
    MarketSim sim(42);
    using clock = std::chrono::steady_clock;
    const auto start = clock::now();
    // one batch = `batch` quotes + batch/5 trades; pace batches to hit the requested quote rate
    const auto interval = std::chrono::nanoseconds(static_cast<long long>(1e9 * batch / rate));

    while (!g_stop) {
        try {
            kdb::Connection tp(host, port);
            std::fprintf(stderr, "connected to TP %s:%d, %ld quotes/s in batches of %d\n",
                         host.c_str(), port, rate, batch);
            long batches = 0;
            auto next = clock::now();
            while (!g_stop) {
                tp.send("upd", kdb::sym("quote"), sim.quoteBatch(batch));
                tp.send("upd", kdb::sym("trade"), sim.tradeBatch(std::max(1, batch / 5)));
                ++batches;
                if (batches % 1000 == 0) {
                    double el = std::chrono::duration<double>(clock::now() - start).count();
                    std::fprintf(stderr, "%ld batches, %.0f quotes/s actual\n", batches, batches * batch / el);
                }
                if (seconds && clock::now() - start > std::chrono::seconds(seconds)) g_stop = 1;
                next += interval;
                std::this_thread::sleep_until(next);
            }
        } catch (const std::exception& e) {
            std::fprintf(stderr, "%s - retrying in 1s\n", e.what());
            std::this_thread::sleep_for(std::chrono::seconds(1));
        }
    }
    return 0;
}
