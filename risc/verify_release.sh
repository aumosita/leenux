#!/bin/bash

# RISC-V Emulator Release Verification Script
# Version 1.0.0

set -e

EMULATOR="./release/risc-emulator"
FAILED=0
PASSED=0

echo "========================================"
echo " RISC-V Emulator Release Verification"
echo "========================================"
echo ""

# Check if emulator exists
if [ ! -f "$EMULATOR" ]; then
    echo "❌ Emulator not found: $EMULATOR"
    echo "   Run: swift build -c release && cp .build/release/risc-emulator release/"
    exit 1
fi

echo "✅ Emulator found: $EMULATOR"
echo ""

# Test function
run_test() {
    local name=$1
    local program=$2
    local expected_pattern=$3
    
    echo -n "Testing $name... "
    
    if $EMULATOR "$program" 2>&1 | grep -q "$expected_pattern"; then
        echo "✅ PASS"
        ((PASSED++))
    else
        echo "❌ FAIL"
        ((FAILED++))
    fi
}

echo "Running tests..."
echo "----------------"

# Basic tests
run_test "Arithmetic" "Examples/01_arithmetic.bin" "Core halted"
run_test "Memory" "Examples/02_memory.bin" "Core halted"
run_test "Branches" "Examples/03_branches.bin" "Core halted"
run_test "Function Call" "Examples/04_function_call.bin" "Core halted"
run_test "Comprehensive" "Examples/05_comprehensive.bin" "Core halted"

# M Extension tests
run_test "M Extension Simple" "Examples/09_m_extension_simple.bin" "Core halted"
run_test "M Division" "Examples/07_m_extension_division.bin" "Core halted"
run_test "M GCD" "Examples/08_m_extension_gcd.bin" "Core halted"

# Control flow tests
run_test "Branch Loop" "Examples/11_branch_loop.bin" "Core halted"
run_test "UART Output" "Examples/uart_test.bin" "Hello, RISC-V"

echo ""
echo "========================================"
echo " Test Results"
echo "========================================"
echo "Passed: $PASSED"
echo "Failed: $FAILED"
echo ""

if [ $FAILED -eq 0 ]; then
    echo "🎉 All tests passed! Release is ready."
    echo ""
    echo "Next steps:"
    echo "1. Review DOCS/OS_ROADMAP.md"
    echo "2. Install RISC-V GCC toolchain:"
    echo "   brew install riscv-gnu-toolchain"
    echo "3. Start Phase 2: OS Development"
    exit 0
else
    echo "❌ Some tests failed. Please fix before release."
    exit 1
fi
