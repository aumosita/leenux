# Leenux OS - Configuration and Usage

## Memory Configuration

**Current Setting**: 256 MB
- RAM Range: 0x80000000 - 0x90000000
- Stack Pointer: 0x90000000 (top of RAM)

## Running the Kernel

### Standard Execution
```bash
cd kernel
./build.sh
../bin/risc-emulator kernel.bin --memory 256
```

### Debug Mode
```bash
../bin/risc-emulator kernel.bin --memory 256 --debug --max-cycles 100
```

### Custom Options
```bash
# Custom memory size
../bin/risc-emulator kernel.bin --memory 512

# Multiple cores
../bin/risc-emulator kernel.bin --memory 256 --cores 4

# Parallel execution
../bin/risc-emulator kernel.bin --memory 256 --cores 4 --parallel
```

## Emulator Options

- `--memory N`: Set memory size in MB (default: 8)
- `--cores N`: Number of cores 1-8 (default: 1)
- `--max-cycles N`: Maximum cycles (default: 10000)
- `--parallel`: Enable true parallel execution
- `--debug`: Show instruction execution details

## UART Output

The emulator logs UART writes in debug output:
```
[UART write8: offset=0, value=72]  # 'H'
[UART TX: 72]
```

**Note**: UART output is not echoed to console by default. To see UART output, the emulator source would need to be modified to print transmitted characters to stdout.

## Project Structure

```
Leenux/
├── bin/
│   └── risc-emulator          # RISC-V emulator binary
├── Tools/
│   └── simple_assembler.py    # Custom RISC-V assembler
├── kernel/
│   ├── boot/
│   │   └── boot.s             # Boot loader (8 bytes)
│   ├── Sources/               # Swift sources (future)
│   ├── kernel_impl.s          # Current kernel (assembly)
│   ├── build.sh               # Build script
│   └── kernel.bin             # Final binary (92 bytes)
├── OS_ROADMAP.md             # Development roadmap
└── RELEASE_NOTES.md          # Emulator features
```
