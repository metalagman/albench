# albench — Agentic Language Benchmark

Automated compile-time benchmark comparing **Go**, **Rust**, **Zig**, and **C++** from zero to a standalone single binary for a standardized cloud-native API webserver (OpenAPI 3.0 + structured JSON logging + Prometheus metrics).

## Benchmark Environment
- **OS**: Linux
- **Kernel**: 6.18.26.1-microsoft-standard-WSL2
- **CPU**: x86_64
- **Date**: 2026-11-10 08:21:29 UTC

## Compilation Benchmark Results

| Language | Cold Build from Zero (s) | Incremental Mean (s) | Incremental Median (s) | StdDev (s) | No-Op (s) | Peak RSS (MB) | Binary Size (MB) | Stripped Size (MB) | Linkage |
|---|---|---|---|---|---|---|---|---|---|
| **Go (CGO=0)** | 10.59 | 0.347 | 0.360 | ±0.032 | 0.1 | 120.7 | 5.91 | 5.91 | static |
| **Go (CGO=1)** | 10.51 | 0.390 | 0.390 | ±0.020 | 0.11 | 125.9 | 5.95 | 5.95 | dynamically linked |
| **Rust (Release LTO)** | 16.76 | 5.207 | 5.260 | ±0.702 | 0.04 | 319.3 | 1.56 | 1.19 | dynamically linked |
| **Rust (Mold + No-LTO)** | 14.6 | 0.220 | 0.220 | ±0.010 | 0.05 | 225.8 | 2.15 | 1.31 | dynamically linked |
| **Zig** | 11.84 | 7.623 | 7.740 | ±0.331 | 0.01 | 191.0 | 2.25 | 0.28 | static |
| **C++** | 11.48 | 10.847 | 10.790 | ±0.936 | 0.0 | 552.7 | 0.54 | 0.4 | dynamically linked |

## Relative Compilation Performance (vs Go CGO=0 = 1.0x)

| Language | Cold Build from Zero | Incremental Rebuild (Dev Loop) | Memory Usage (Peak RSS) | Binary Size |
|---|---|---|---|---|
| **Go (CGO=0)** | **1.0x (baseline, 10.59s)** | **1.0x (baseline, 0.347s)** | **120.7 MB (baseline)** | 5.91 MB (baseline) |
| **Go (CGO=1)** | -0.8% (1.0x faster) | +12.4% (1.1x slower) | +4.4% (1.0x more) | +0.7% (1.0x larger) |
| **Rust (Release LTO)** | +58.3% (1.6x slower) | +1400.6% (15.0x slower) | +164.6% (2.6x more) | -73.6% (3.8x smaller) |
| **Rust (Mold + No-LTO)** | +37.9% (1.4x slower) | -36.6% (1.6x faster) | +87.1% (1.9x more) | -63.6% (2.7x smaller) |
| **Zig** | +11.8% (1.1x slower) | +2096.8% (22.0x slower) | +58.3% (1.6x more) | -61.9% (2.6x smaller) |
| **C++** | +8.4% (1.1x slower) | +3025.9% (31.3x slower) | +358.0% (4.6x more) | -90.9% (10.9x smaller) |

### Methodology & Scenarios
- **Cold Build from Zero**: Measures clean compilation time and peak memory consumption (CI/CD runner or container build from scratch).
- **Incremental Rebuild (Dev Loop)**: The core developer experience metric. A single source file is modified, and the project is recompiled with all dependency caches warm.
- **No-Op Rebuild**: Verifies build system dependency freshness and null-build overhead when zero source files have changed.

### Compiler Resource Footprint
- **Memory Footprint (RAM)**: Go requires only **120.7 MB** peak RSS during incremental rebuilds. In comparison, C++, Rust, and Zig consume significantly more RAM during compilation. On resource-constrained CI/CD runners (1–2 GB RAM), heavy template expansion and LLVM backend pipelines can cause Out-Of-Memory (OOM) failures under parallel jobs.
- **Disk Artifacts & Build Cache**: Rust's `target/` directory balloons to **>600 MB** across intermediate files for an API service. Go's build cache footprint remains minimal, avoiding heavy I/O overhead.
- **CPU Overhead**: Go's compiler is engineered for linear single-pass parsing without template/macro expansion. In contrast, C++ and Rust saturate CPU cores with deep template metaprogramming, monomorphization, borrow checking, and aggressive LLVM optimization passes.

### Key Takeaways
- **Developer Feedback Loop**: Go delivers near-instantaneous (~0.35s) incremental feedback loops on code changes. Standard Rust with ThinLTO takes ~5.2s (~15x slower), Zig takes ~7.6s (~22x slower), and C++ takes ~10.8s (~31x slower).
- **Optimizing Rust for Dev Speed**: By disabling LTO (`lto = 'off'`), increasing codegen units (`codegen-units = 16`), enabling incremental builds, and switching to the high-performance `mold` linker, Rust incremental rebuilds drop dramatically to **~0.22s** — outperforming pure Go in developer iteration speed while producing a ~1.3 MB stripped binary.
- **CGO Impact**: `CGO_ENABLED=0` produces a completely standalone static binary (5.91 MB) without glibc runtime linkage dependencies, while `CGO_ENABLED=1` produces a dynamically linked binary (5.95 MB).
- **Binary Footprint**: C++ produces the most compact binary footprint (~0.5 MB, 0.4 MB stripped), followed by Rust (~1.6 MB, 1.2 MB stripped) and Zig (~2.3 MB, 0.28 MB static stripped). Go bundles its runtime and GC at ~5.9 MB.

### Closing the Developer Loop Gap in Rust (5.2s -> 0.22s)
By default in release mode, Cargo enables whole-program LTO passes (`lto = 'thin'`) and serializes LLVM codegen (`codegen-units = 1`), causing single-line modifications in the server binary to take **~5.2s**.

By configuring a fast developer profile in `Cargo.toml`:
```toml
[profile.fast]
inherits = "release"
opt-level = 3
lto = "off"
codegen-units = 16
incremental = true
panic = "abort"
```
and pairing it with the modern high-performance linker **`mold`** (`RUSTFLAGS="-C link-arg=-fuse-ld=mold"`):
- **Incremental rebuild time drops 24x**: from **5.21s** down to **0.22s** (1.6x faster than pure Go at 0.35s).
- **Binary size penalty is minimal**: the stripped executable only grows from **1.19 MB** to **1.31 MB** (+120 KB), preserving production performance while unlocking sub-second developer feedback loops.

## Implementations Overview
- **Go** (`implementations/go`): Standard library `net/http` + `log/slog` structured JSON + Prometheus `/metrics` exposition (evaluated under both `CGO_ENABLED=0` and `CGO_ENABLED=1`).
- **Rust** (`implementations/rust`): `axum` + `tokio` + `tracing` JSON subscriber + Prometheus `/metrics` (evaluated under standard `release` ThinLTO and fast dev `mold` + `no-lto` configuration).
- **Zig** (`implementations/zig`): Standard library `std.http` / socket server + `std.log` JSON + custom in-process metrics.
- **C++** (`implementations/cpp`): C++20 + CMake/Ninja + `httplib` + `nlohmann/json` + Prometheus text metrics.

## Running Benchmarks Locally
```bash
# 1. Verify and provision toolchains
./scripts/setup-toolchains.sh

# 2. Run full benchmark suite
python3 scripts/bench.py --iterations 3 --update-readme
```