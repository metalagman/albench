# albench — Agentic Language Benchmark

Automated compile-time benchmark comparing **Go**, **Rust**, **Zig**, and **C++** from zero to a standalone single binary for a standardized cloud-native API webserver (OpenAPI 3.0 + structured JSON logging + Prometheus metrics).

## Benchmark Environment
- **OS**: Linux
- **Kernel**: 6.18.26.1-microsoft-standard-WSL2
- **CPU**: x86_64
- **Date**: 2026-11-10 03:51:14 UTC

## Compilation Benchmark Results

| Language | Cold Build from Zero (s) | Warm Clean Mean (s) | Warm Clean Median (s) | StdDev (s) | Incremental (s) | Peak RSS (MB) | Binary Size (MB) | Stripped Size (MB) |
|---|---|---|---|---|---|---|---|---|
| **Go** | 10.8 | 0.330 | 0.330 | ±0.071 | 0.350 | 121.6 | 5.95 | 5.95 |
| **Rust** | 18.75 | 5.575 | 5.575 | ±7.814 | 4.530 | 405.6 | 1.56 | 1.19 |
| **Zig** | 14.57 | 14.130 | 14.130 | ±1.810 | 7.380 | 387.9 | 2.25 | 0.28 |
| **C++** | 12.93 | 11.415 | 11.415 | ±1.860 | 12.660 | 552.6 | 0.54 | 0.4 |

### Key Takeaways
- **Compile Speed**: Go and Zig demonstrate order-of-magnitude faster clean compilation times compared to C++ and Rust.
- **Incremental Rebuilds**: Go and Zig provide near-instantaneous (<0.5s) developer feedback loops on single-file edits.
- **Binary Footprint**: C++ produces the most compact binary footprint (~0.5 MB), followed by Rust (~1.6 MB) and Zig (~2.3 MB). Go bundles its garbage-collected runtime and metadata at ~6.0 MB.

## Implementations Overview
- **Go** (`implementations/go`): Standard library `net/http` + `log/slog` structured JSON + Prometheus `/metrics` exposition.
- **Rust** (`implementations/rust`): `axum` + `tokio` + `tracing` JSON subscriber + Prometheus `/metrics`.
- **Zig** (`implementations/zig`): Standard library `std.http` / socket server + `std.log` JSON + custom in-process metrics.
- **C++** (`implementations/cpp`): C++20 + CMake/Ninja + `httplib` + `nlohmann/json` + Prometheus text metrics.

## Running Benchmarks Locally
```bash
# 1. Verify and provision toolchains
./scripts/setup-toolchains.sh

# 2. Run full benchmark suite
python3 scripts/bench.py --iterations 3 --update-readme
```