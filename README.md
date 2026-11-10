# albench — Agentic Language Benchmark

Automated compile-time benchmark comparing **Go**, **Rust**, **Zig**, and **C++** from zero to a standalone single binary for a standardized cloud-native API webserver (OpenAPI 3.0 + structured JSON logging + Prometheus metrics).

## Benchmark Environment
- **OS**: Linux
- **Kernel**: 6.18.26.1-microsoft-standard-WSL2
- **CPU**: x86_64
- **Date**: 2026-11-10 04:43:34 UTC

## Compilation Benchmark Results

| Language | Cold Build from Zero (s) | Warm Clean Mean (s) | Warm Clean Median (s) | StdDev (s) | Incremental (s) | Peak RSS (MB) | Binary Size (MB) | Stripped Size (MB) |
|---|---|---|---|---|---|---|---|---|
| **Go (CGO=0)** | 10.52 | 0.300 | 0.300 | ±0.000 | 0.350 | 123.9 | 5.91 | 5.91 |
| **Go (CGO=1)** | 9.03 | 0.325 | 0.325 | ±0.007 | 0.400 | 121.5 | 5.95 | 5.95 |
| **Rust** | 18.05 | 6.845 | 6.845 | ±0.290 | 5.330 | 319.8 | 1.56 | 1.19 |
| **Zig** | 13.62 | 15.555 | 15.555 | ±1.025 | 12.600 | 388.1 | 2.25 | 0.28 |
| **C++** | 14.98 | 14.590 | 14.590 | ±0.806 | 14.690 | 552.5 | 0.54 | 0.4 |

## Relative Compilation Performance (vs Go = 1.0x)

| Language | Cold Build from Zero | Warm Clean Build | Incremental Rebuild | Memory Usage (Peak RSS) | Binary Size |
|---|---|---|---|---|---|
| **Go (CGO=0)** | **1.0x (baseline, 10.52s)** | **1.0x (baseline, 0.300s)** | **1.0x (baseline, 0.350s)** | **123.9 MB (baseline)** | 5.91 MB (baseline) |
| **Go (CGO=1)** | -14.2% (1.2x faster) | +8.3% (1.1x slower) | +14.3% (1.1x slower) | -1.9% (1.0x less) | +0.7% (1.0x larger) |
| **Rust** | +71.6% (1.7x slower) | +2181.7% (22.8x slower) | +1422.9% (15.2x slower) | +158.2% (2.6x more) | -73.6% (3.8x smaller) |
| **Zig** | +29.5% (1.3x slower) | +5085.0% (51.9x slower) | +3500.0% (36.0x slower) | +213.3% (3.1x more) | -61.9% (2.6x smaller) |
| **C++** | +42.4% (1.4x slower) | +4763.3% (48.6x slower) | +4097.1% (42.0x slower) | +346.0% (4.5x more) | -90.9% (10.9x smaller) |

### Compiler Resource Footprint
- **Memory Footprint (RAM)**: Go requires only **123.9 MB** peak RSS. In comparison, C++, Rust, and Zig consume significantly more RAM during compilation. On resource-constrained CI/CD runners (1–2 GB RAM), heavy template expansion and LLVM backend pipelines can cause Out-Of-Memory (OOM) failures under parallel jobs.
- **Disk Artifacts & Build Cache**: Rust's `target/` directory balloons to **>600 MB** across intermediate files for an API service. Go's build cache footprint remains minimal, avoiding heavy I/O overhead.
- **CPU Overhead**: Go's compiler is engineered for linear single-pass parsing without template/macro expansion. In contrast, C++ and Rust saturate CPU cores with deep template metaprogramming, monomorphization, borrow checking, and aggressive LLVM optimization passes.

### Key Takeaways
- **Compile Speed**: Both Go configurations (`CGO=0` and `CGO=1`) compile in ~0.3s on warm clean builds, outperforming Rust (~6.8s) by >20x, and Zig (~15s) / C++ (~14s) by >40x.
- **Incremental Rebuilds**: Go provides near-instantaneous (<0.4s) developer feedback loops on single-file edits.
- **CGO Impact**: `CGO_ENABLED=0` produces a completely standalone static binary (5.91 MB) without glibc runtime linkage dependencies, while `CGO_ENABLED=1` produces a dynamically linked binary (5.95 MB).
- **Binary Footprint**: C++ produces the most compact binary footprint (~0.5 MB), followed by Rust (~1.6 MB) and Zig (~2.3 MB). Go bundles its runtime and GC at ~5.9 MB.

## Implementations Overview
- **Go** (`implementations/go`): Standard library `net/http` + `log/slog` structured JSON + Prometheus `/metrics` exposition (evaluated under both `CGO_ENABLED=0` and `CGO_ENABLED=1`).
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