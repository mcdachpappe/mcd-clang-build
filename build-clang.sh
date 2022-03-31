#!/usr/bin/env bash

# Script to build a toolchain specialized for Chips Kernel development

set -eo pipefail

# Colors
GRN='\033[01;32m' # green
RST='\033[0m'     # reset

# Alias for echo to handle escape codes like colors
function echo() {
    command echo -e "$@"
}

# Prints a statement in bold GRN
function msg() {
    echo
    echo " ${GRN}${1}${RST}"
}

# Start timer
DATE_START=$(date +"%s")

# Build LLVM
msg "[1/5] Building LLVM..."
./build-llvm.py \
    --clang-vendor "mcd" \
    --targets "ARM;AArch64;X86" \
    --use-good-revision \
    --defines CMAKE_C_FLAGS="-march=native -mtune=native" CMAKE_CXX_FLAGS="-march=native -mtune=native" \
    --pgo kernel-defconfig \
    --lto thin

# Build binutils // x86_64
msg "[2/5] Building binutils..."
./build-binutils.py \
    --targets arm aarch64 x86_64 \
    --march native

# Remove unused products
msg "[3/5] Removing unused products..."
rm -fr install/include
rm -f install/lib/*.a install/lib/*.la

# Strip remaining products
msg "[4/5] Stripping remaining products..."
for f in $(find install -type f -exec file {} \; | grep 'not stripped' | awk '{print $1}'); do
    strip "${f::-1}"
done

# Set executable rpaths so setting LD_LIBRARY_PATH isn't necessary
msg "[5/5] Setting library load paths for portability..."
for bin in $(find install -mindepth 2 -maxdepth 3 -type f -exec file {} \; | grep 'ELF .* interpreter' | awk '{print $1}'); do
    # Remove last character from file output (':')
    bin="${bin::-1}"

    patchelf --set-rpath "$ORIGIN/../lib" "$bin"
done

# End timer
DATE_END=$(date +"%s")

# Calculate time
DIFF=$((DATE_END - DATE_START))

# End
msg " Completed in $((DIFF / 60)) minute(s) and $((DIFF % 60)) seconds."
