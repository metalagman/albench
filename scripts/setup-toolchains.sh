#!/usr/bin/env bash
set -euo pipefail

mkdir -p "$HOME/.local/bin"
export PATH="$HOME/.local/bin:$HOME/.cargo/bin:$PATH"

echo "=== Checking and provisioning toolchains for albench ==="

# 1. Check Go
if command -v go >/dev/null 2>&1; then
    echo "✓ Go found: $(go version)"
else
    echo "ERROR: Go compiler not found on PATH" >&2
    exit 1
fi

# 2. Check C++ Compiler
if command -v g++ >/dev/null 2>&1; then
    echo "✓ C++ compiler found: $(g++ --version | head -n 1)"
elif command -v clang++ >/dev/null 2>&1; then
    echo "✓ C++ compiler found: $(clang++ --version | head -n 1)"
else
    echo "ERROR: Neither g++ nor clang++ found on PATH" >&2
    exit 1
fi

# 3. Provision / Check CMake
if command -v cmake >/dev/null 2>&1; then
    echo "✓ CMake found: $(cmake --version | head -n 1)"
else
    echo "Installing CMake standalone binary to ~/.local/..."
    CMAKE_VERSION="3.30.5"
    CMAKE_TAR="cmake-${CMAKE_VERSION}-linux-x86_64.tar.gz"
    curl -fsSL -o "/tmp/${CMAKE_TAR}" "https://github.com/Kitware/CMake/releases/download/v${CMAKE_VERSION}/${CMAKE_TAR}"
    tar -xzf "/tmp/${CMAKE_TAR}" -C "$HOME/.local" --strip-components=1
    rm -f "/tmp/${CMAKE_TAR}"
    echo "✓ CMake installed: $(cmake --version | head -n 1)"
fi

# 4. Provision / Check Ninja
if command -v ninja >/dev/null 2>&1; then
    echo "✓ Ninja found: $(ninja --version)"
else
    echo "Installing Ninja standalone binary to ~/.local/bin..."
    NINJA_URL="https://github.com/ninja-build/ninja/releases/download/v1.12.1/ninja-linux.zip"
    curl -fsSL -o "/tmp/ninja.zip" "${NINJA_URL}"
    python3 -c "import zipfile; zipfile.ZipFile('/tmp/ninja.zip').extract('ninja', path='$HOME/.local/bin')"
    chmod +x "$HOME/.local/bin/ninja"
    rm -f "/tmp/ninja.zip"
    echo "✓ Ninja installed: $(ninja --version)"
fi

# 5. Provision / Check Rust & Cargo
if command -v cargo >/dev/null 2>&1 && command -v rustc >/dev/null 2>&1; then
    echo "✓ Rust found: $(rustc --version) / $(cargo --version)"
else
    echo "Installing Rust via rustup to ~/.cargo/..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal
    # shellcheck source=/dev/null
    source "$HOME/.cargo/env"
    echo "✓ Rust installed: $(rustc --version) / $(cargo --version)"
fi

# 6. Provision / Check Zig
if [ -f "$HOME/.local/zig" ] && [ ! -f "$HOME/.local/bin/zig" ]; then
    ln -sf "$HOME/.local/zig" "$HOME/.local/bin/zig"
fi

if command -v zig >/dev/null 2>&1; then
    echo "✓ Zig found: $(zig version)"
else
    echo "Installing Zig 0.13.0 standalone binary to ~/.local/..."
    ZIG_VERSION="0.13.0"
    ZIG_TAR="zig-linux-x86_64-${ZIG_VERSION}.tar.xz"
    curl -fsSL -o "/tmp/${ZIG_TAR}" "https://ziglang.org/download/${ZIG_VERSION}/${ZIG_TAR}"
    tar -xf "/tmp/${ZIG_TAR}" -C "$HOME/.local" --strip-components=1
    ln -sf "$HOME/.local/zig" "$HOME/.local/bin/zig"
    rm -f "/tmp/${ZIG_TAR}"
    echo "✓ Zig installed: $(zig version)"
fi

echo "=========================================================="
echo "All 4 toolchains (Go, Rust, Zig, C++) and build tools verified!"
