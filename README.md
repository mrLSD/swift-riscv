[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift CI](https://github.com/mrLSD/riscv-swift/actions/workflows/swift.yaml/badge.svg)](https://github.com/mrLSD/riscv-swift/actions/workflows/swift.yaml)

<center>
    <h1>mrLSD<code>/riscv-swift</code></h1>
</center>

Swift RISC-V implementation — a faithful replica of the F# reference
implementation ([mrLSD/riscv-fs](https://github.com/mrLSD/riscv-fs)): same
module structure, names, and observable semantics, in idiomatic
high-performance Swift.

## Status

- **ISA**: RV32I / RV64I base integer instruction set, the M extension
  (RV32M `MUL/MULH/MULHSU/MULHU/DIV/DIVU/REM/REMU` + RV64M
  `MULW/DIVW/DIVUW/REMW/REMUW`), the A extension (RV32A/RV64A
  `LR/SC` with width-checked reservations and all `AMO*` operations),
  and the C extension (all integer compressed instructions, IALIGN=2,
  PC advances by 2; the FP-compressed Zcf/Zcd encodings stay reserved
  until F/D land) — complete (decode, execute, traps, XLEN normalization).
- **Infrastructure**: machine state, sparse memory, ELF32/ELF64 loader
  (PT_LOAD + entry point, 4 MiB cap for untrusted inputs), run loop with
  step limit, CLI, application entry.
- **Tests**: Swift Testing suite ported from the reference (rv32i, rv64i
  base-I, unit, run) — 100% region/function/line coverage of the library
  (`scripts/coverage` gates CI).
- **Performance**: value-semantics state with fused `consuming` transitions
  (one state materialization per instruction), a word-verified PC-indexed
  decode cache and a generation-validated fetch page cache (both loop-local —
  self-modifying code stays bit-exact), cross-module-inlinable bit helpers,
  gated extension decoders, cached XLEN/IALIGN flags, branchless x0, and paged
  sparse memory accessed through `Span`/`MutableSpan` — ~74 MIPS on integer
  loops with full LTO (Apple M-series), ~14× the F# reference.

## Layout

| Swift | Replica of |
|---|---|
| `Sources/RISCV/Arch.swift` | `Arch.fs` |
| `Sources/RISCV/Bits.swift` | `Bits.fs` |
| `Sources/RISCV/MemoryMap.swift` | (F# `Map<int64, byte>` memory, paged + Span) |
| `Sources/RISCV/MachineState.swift` | `MachineState.fs` |
| `Sources/RISCV/DecodeI.swift` | `DecodeI.fs` |
| `Sources/RISCV/ExecuteI.swift` | `ExecuteI.fs` |
| `Sources/RISCV/DecodeM.swift` / `ExecuteM.swift` | `DecodeM.fs` / `ExecuteM.fs` |
| `Sources/RISCV/DecodeM64.swift` / `ExecuteM64.swift` | `DecodeM64.fs` / `ExecuteM64.fs` |
| `Sources/RISCV/DecodeA.swift` / `ExecuteA.swift` | `DecodeA.fs` / `ExecuteA.fs` |
| `Sources/RISCV/DecodeA64.swift` / `ExecuteA64.swift` | `DecodeA64.fs` / `ExecuteA64.fs` |
| `Sources/RISCV/DecodeC.swift` / `ExecuteC.swift` | `DecodeC.fs` / `ExecuteC.fs` |
| `Sources/RISCV/ExecuteI64.swift` | `ExecuteI64.fs` (the subset C delegates to) |
| `Sources/RISCV/Decoder.swift` | `Decoder.fs` |
| `Sources/RISCV/Run.swift` | `Run.fs` (ELF loader hand-written, no ELFSharp) |
| `Sources/RISCV/CLI.swift` | `CLI.fs` |
| `Sources/RISCV/Program.swift` | `Program.fs` |
| `Sources/riscv-swift/main.swift` | entry-point trampoline |

## Usage

```sh
swift run -c release riscv-swift -A rv32i program.elf
```

```
USAGE:
     risc-v [OPTIONS] file...
OPTIONS
     -A, --arch           RISC-V architecture (required), e.g. rv32i, rv64i
     -v                   Verbosity output
     -h, --help           Print help message
     -V, --version        Application version
```

## Development

```sh
swift build            # build
swift test             # run the test suite
./scripts/coverage  # tests + 100% coverage gate
```

## Benchmarks

Per-ISA throughput benchmarks (I/M/A on RV32 and RV64) drive non-terminating
guest loops through the real fetch/decode/execute pipeline with an exact
instruction budget:

```sh
swift run -c release riscv-bench                  # local, ~1s per repetition
swift run -c release riscv-bench --ci             # CI mode, whole suite < 3 min
swift run -c release riscv-bench --seconds 10 --reps 9   # deep local tuning
swift build -c release --experimental-lto-mode=full      # fastest build (+8%)
```

CI runs them on every push via `.github/workflows/bench.yaml` (the bench step
is hard-capped at 3 minutes; the binary additionally enforces an in-process
budget in `--ci` mode). Reference numbers (Apple M-series, release + LTO):
I-ALU ~74 MIPS, M mul/div ~57 MIPS, C-ALU ~37 MIPS, A AMO ~28 MIPS.

## Requirements

- Supported OS: `macOS 15.0` or above, or Linux
- Swift lang: `6.2` or above

### LICENSE: [MIT](LICENSE)
