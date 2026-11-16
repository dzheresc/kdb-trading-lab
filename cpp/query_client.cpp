// query_client.cpp - call the gateway API synchronously and print the resulting table.
//
// Usage: query_client <host> <port> <api> [sym1,sym2,...] [lookback_days] [bar_minutes]
//   query_client localhost 5013 vwap AAPL,MSFT 1
//   query_client localhost 5013 bars AAPL 3 5
//   query_client localhost 5013 tca  AAPL,MSFT,NVDA 3
//
// Shows how to: build typed arguments (symbol vector, timestamps, long), make a sync call,
// detect q errors, and walk a table (type 98 = flip of a dict of column names -> column vectors).
#include "kdb_conn.hpp"

#include <chrono>
#include <cstdio>
#include <ctime>
#include <sstream>
#include <string>
#include <vector>

namespace {

std::vector<std::string> split(const std::string& s, char sep) {
    std::vector<std::string> out;
    std::stringstream ss_(s);
    for (std::string item; std::getline(ss_, item, sep);) if (!item.empty()) out.push_back(item);
    return out;
}

// Render one cell of column c at row i.
std::string cell(K c, J i) {
    char buf[64];
    switch (c->t) {
        case KS: return kS(c)[i];
        case KF: std::snprintf(buf, sizeof buf, "%.4f", kF(c)[i]); return buf;
        case KJ: return kJ(c)[i] == nj ? "0N" : std::to_string(kJ(c)[i]);
        case KI: return std::to_string(kI(c)[i]);
        case KC: return std::string(1, kC(c)[i]);
        case KP: {  // timestamp: ns since 2000.01.01 -> print as Unix-epoch seconds.nanos UTC
            J ns = kJ(c)[i] + kdb::kKdbEpochOffsetNs;
            std::time_t secs = ns / 1000000000;
            std::tm tm{};
            gmtime_r(&secs, &tm);
            std::strftime(buf, sizeof buf, "%Y-%m-%dT%H:%M:%S", &tm);
            char out[80];
            std::snprintf(out, sizeof out, "%s.%03lld", buf, (long long)((ns / 1000000) % 1000));
            return out;
        }
        default: std::snprintf(buf, sizeof buf, "<t%d>", c->t); return buf;
    }
}

void printTable(K t) {
    if (t->t == XD) {  // keyed table: dict of key-table -> value-table. Ask the server for 0! instead.
        std::puts("(keyed table: unkey it server-side with 0!)");
        return;
    }
    if (t->t != XT) { std::printf("result type %d (not a table)\n", t->t); return; }
    K dict = t->k;            // flip -> underlying dictionary
    K names = kK(dict)[0];    // symbol vector of column names
    K columns = kK(dict)[1];  // general list of column vectors
    J rows = columns->n ? kK(columns)[0]->n : 0;
    for (J j = 0; j < names->n; ++j) std::printf("%-26s", kS(names)[j]);
    std::puts("");
    for (J i = 0; i < rows && i < 50; ++i) {
        for (J j = 0; j < names->n; ++j) std::printf("%-26s", cell(kK(columns)[j], i).c_str());
        std::puts("");
    }
    if (rows > 50) std::printf("... %lld rows total\n", (long long)rows);
}

}  // namespace

int main(int argc, char** argv) {
    if (argc < 4) {
        std::fprintf(stderr, "usage: %s host port vwap|bars|tca|rvol|markouts|spread [syms] [days] [barMins]\n", argv[0]);
        return 1;
    }
    try {
        kdb::Connection gw(argv[1], std::stoi(argv[2]));
        const std::string api = argv[3];
        auto syms = split(argc > 4 ? argv[4] : "AAPL,MSFT", ',');
        int days = argc > 5 ? std::stoi(argv[5]) : 1;
        long barMins = argc > 6 ? std::stol(argv[6]) : 5;

        K s = ktn(KS, (J)syms.size());
        for (size_t i = 0; i < syms.size(); ++i) kS(s)[i] = ss(const_cast<S>(syms[i].c_str()));
        auto now = std::chrono::system_clock::now();
        K st = kdb::timestamp(now - std::chrono::hours(24 * days));
        K et = kdb::timestamp(now);

        const std::string fn = ".api." + api;
        auto t0 = std::chrono::steady_clock::now();
        kdb::KPtr r = (api == "bars" || api == "rvol")
                          ? gw.call(fn.c_str(), s, st, et, kj(barMins))
                          : gw.call(fn.c_str(), s, st, et);
        auto us = std::chrono::duration_cast<std::chrono::microseconds>(std::chrono::steady_clock::now() - t0).count();
        printTable(r.get());
        std::printf("round trip %lld us\n", (long long)us);
    } catch (const std::exception& e) {
        std::fprintf(stderr, "%s\n", e.what());
        return 2;
    }
    return 0;
}
