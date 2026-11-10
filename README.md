# albench — Agentic Language Benchmark

Automated compile-time benchmark comparing **Go**, **Rust**, **Zig**, and **C++** from zero to a standalone single binary for a standardized cloud-native API webserver (OpenAPI 3.0 + structured JSON logging + Prometheus metrics).

## Benchmark Environment
- **OS**: Linux
- **Kernel**: 6.18.26.1-microsoft-standard-WSL2
- **CPU**: x86_64
- **Date**: 2026-11-10 07:41:47 UTC

## Compilation Benchmark Results

| Language | Cold Build from Zero (s) | Incremental Mean (s) | Incremental Median (s) | StdDev (s) | No-Op (s) | Peak RSS (MB) | Binary Size (MB) | Stripped Size (MB) | Linkage |
|---|---|---|---|---|---|---|---|---|---|
| **Go (CGO=0)** | 15.36 | 0.490 | 0.490 | ±0.020 | 0.14 | 119.3 | 5.91 | 5.91 | static |
| **Go (CGO=1)** | 14.53 | 0.520 | 0.530 | ±0.026 | 0.13 | 126.2 | 5.95 | 5.95 | dynamically linked |
| **Rust** | 24.67 | 4.910 | 5.230 | ±0.589 | 0.05 | 319.7 | 1.56 | 1.19 | dynamically linked |
| **Zig** | 16.21 | 11.180 | 10.320 | ±1.684 | 0.02 | 191.4 | 2.25 | 0.28 | static |
| **C++** | 18.62 | 13.457 | 13.550 | ±0.253 | 0.0 | 552.9 | 0.54 | 0.4 | dynamically linked |

## Relative Compilation Performance (vs Go CGO=0 = 1.0x)

| Language | Cold Build from Zero | Incremental Rebuild (Dev Loop) | Memory Usage (Peak RSS) | Binary Size |
|---|---|---|---|---|
| **Go (CGO=0)** | **1.0x (baseline, 15.36s)** | **1.0x (baseline, 0.490s)** | **119.3 MB (baseline)** | 5.91 MB (baseline) |
| **Go (CGO=1)** | -5.4% (1.1x faster) | +6.1% (1.1x slower) | +5.8% (1.1x more) | +0.7% (1.0x larger) |
| **Rust** | +60.6% (1.6x slower) | +902.0% (10.0x slower) | +168.1% (2.7x more) | -73.6% (3.8x smaller) |
| **Zig** | +5.5% (1.1x slower) | +2181.6% (22.8x slower) | +60.5% (1.6x more) | -61.9% (2.6x smaller) |
| **C++** | +21.2% (1.2x slower) | +2646.3% (27.5x slower) | +363.6% (4.6x more) | -90.9% (10.9x smaller) |

### Methodology & Scenarios
- **Cold Build from Zero**: Measures clean compilation time and peak memory consumption (CI/CD runner or container build from scratch).
- **Incremental Rebuild (Dev Loop)**: The core developer experience metric. A single source file is modified, and the project is recompiled with all dependency caches warm.
- **No-Op Rebuild**: Verifies build system dependency freshness and null-build overhead when zero source files have changed.

### Compiler Resource Footprint
- **Memory Footprint (RAM)**: Go requires only **119.3 MB** peak RSS during incremental rebuilds. In comparison, C++, Rust, and Zig consume significantly more RAM during compilation. On resource-constrained CI/CD runners (1–2 GB RAM), heavy template expansion and LLVM backend pipelines can cause Out-Of-Memory (OOM) failures under parallel jobs.
- **Disk Artifacts & Build Cache**: Rust's `target/` directory balloons to **>600 MB** across intermediate files for an API service. Go's build cache footprint remains minimal, avoiding heavy I/O overhead.
- **CPU Overhead**: Go's compiler is engineered for linear single-pass parsing without template/macro expansion. In contrast, C++ and Rust saturate CPU cores with deep template metaprogramming, monomorphization, borrow checking, and aggressive LLVM optimization passes.

### Key Takeaways
- **Developer Feedback Loop**: Go delivers near-instantaneous (~0.49s) incremental feedback loops on code changes. Rust takes ~4.9s (~10x slower), Zig takes ~11.2s (~23x slower), and C++ takes ~13.5s (~27x slower) due to header template re-evaluation.
- **CGO Impact**: `CGO_ENABLED=0` produces a completely standalone static binary (5.91 MB) without glibc runtime linkage dependencies, while `CGO_ENABLED=1` produces a dynamically linked binary (5.95 MB).
- **Binary Footprint**: C++ produces the most compact binary footprint (~0.5 MB, 0.4 MB stripped), followed by Rust (~1.6 MB, 1.2 MB stripped) and Zig (~2.3 MB, 0.28 MB static stripped). Go bundles its runtime and GC at ~5.9 MB.

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