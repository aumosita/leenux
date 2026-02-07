#!/bin/bash
# Quick test script for all 15 Leenux commands

echo "🧪 Leenux OS - Command Testing Script"
echo "======================================"
echo ""

# Note: This is a test script template
# Actual testing will be done interactively via Swift Terminal

COMMANDS=(
    "help"
    "echo Hello Leenux!"
    "uname"
    "ls"
    "ls /dev"
    "ls /proc"
    "cat /proc/meminfo"
    "cat /proc/cpuinfo"
    "pwd"
    "free"
    "malloc 256"
    "memtest"
    "format"
    "df"
    "touch test.txt"
    "mkdir documents"
)

echo "Commands to test interactively:"
echo ""
for cmd in "${COMMANDS[@]}"; do
    echo "  > $cmd"
done

echo ""
echo "Run Swift Terminal:"
echo "  ./bin/leenux-terminal"
echo ""
echo "Then paste each command above to test."
