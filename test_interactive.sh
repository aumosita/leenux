#!/bin/bash
# Test interactive shell
(
    sleep 2
    echo 'help'
    sleep 1
    echo 'ls'
    sleep 1
    echo 'format'
    sleep 1
) | ./bin/risc-emulator kernel/kernel.bin --max-cycles 100000000 --memory 256 --debug 2>&1 | grep -v '^\[Core'
