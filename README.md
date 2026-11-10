# albench — Agentic Language Benchmark

Automated compile-time benchmark comparing **Go**, **Rust**, **Zig**, and **C++** from zero to a standalone single binary for a standardized cloud-native API webserver (OpenAPI 3.0 + structured JSON logging + Prometheus metrics).

## Benchmark Environment
- **OS**: Linux
- **Kernel**: 6.18.26.1-microsoft-standard-WSL2
- **CPU**: x86_64
- **Date**: 2026-11-10 04:38:18 UTC

## Compilation Benchmark Results

| Language | Cold Build from Zero (s) | Warm Clean Mean (s) | Warm Clean Median (s) | StdDev (s) | Incremental (s) | Peak RSS (MB) | Binary Size (MB) | Stripped Size (MB) |
|---|---|---|---|---|---|---|---|---|
| **Go** | 10.92 | 0.320 | 0.320 | ±0.042 | 0.400 | 123.6 | 5.91 | 5.91 |
| **Rust** | 18.57 | 6.830 | 6.830 | ±0.849 | 5.150 | 319.7 | 1.56 | 1.19 |
| **Zig** | 13.09 | 14.030 | 14.030 | ±1.895 | 9.820 | 387.9 | 2.25 | 0.28 |
| **C++** | 10.22 | 13.805 | 13.805 | ±0.375 | 13.470 | 552.7 | 0.54 | 0.4 |

## Relative Compilation Performance (vs Go = 1.0x)

| Language | Cold Build from Zero | Warm Clean Build | Incremental Rebuild | Memory Usage (Peak RSS) | Binary Size |
|---|---|---|---|---|---|
| **Go** | **1.0x (baseline, 10.92s)** | **1.0x (baseline, 0.320s)** | **1.0x (baseline, 0.400s)** | **123.6 MB (baseline)** | 5.91 MB (baseline) |
| **Rust** | +70.1% (1.7x slower) | +2034.4% (21.3x slower) | +1187.5% (12.9x slower) | +158.7% (2.6x more) | -73.6% (3.8x smaller) |
| **Zig** | +19.9% (1.2x slower) | +4284.4% (43.8x slower) | +2355.0% (24.6x slower) | +213.9% (3.1x more) | -61.9% (2.6x smaller) |
| **C++** | -6.4% (1.1x faster) | +4214.1% (43.1x slower) | +3267.5% (33.7x slower) | +347.3% (4.5x more) | -90.9% (10.9x smaller) |

### Compiler Resource Footprint
- **Memory Footprint (RAM)**: Go requires only **123.6 MB** peak RSS. In comparison, C++, Rust, and Zig consume significantly more RAM during compilation. On resource-constrained CI/CD runners (1–2 GB RAM), heavy template expansion and LLVM backend pipelines can cause Out-Of-Memory (OOM) failures under parallel jobs.
- **Disk Artifacts & Build Cache**: Rust's `target/` directory balloons to **>600 MB** across intermediate files for an API service. Go's build cache footprint remains minimal, avoiding heavy I/O overhead.
- **CPU Overhead**: Go's compiler is engineered for linear single-pass parsing without template/macro expansion. In contrast, C++ and Rust saturate CPU cores with deep template metaprogramming, monomorphization, borrow checking, and aggressive LLVM optimization passes.

### Key Takeaways
- **Compile Speed**: Go demonstrates an order-of-magnitude faster warm clean compilation (~0.3s) compared to Rust (~6.8s), Zig (~14s), and C++ (~13.8s).
- **Incremental Rebuilds**: Go provides near-instantaneous (<0.5s) developer feedback loops on single-file edits.
- **Binary Footprint & Linkage**: C++ produces the most compact binary footprint (~0.5 MB), followed by Rust (~1.6 MB) and Zig (~2.3 MB). Go bundles its static runtime and GC metadata at ~5.9 MB with `CGO_ENABLED=0`.

## Implementations Overview
- **Go** (`implementations/go`): Standard library `net/http` + `log/slog` structured JSON + Prometheus `/metrics` exposition (`CGO_ENABLED=0` static binary).
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