// riscv-bench — performance benchmarks for every implemented ISA (I, M, A; RV32/RV64).
//
// Each workload is a small non-terminating guest loop placed at 0x80000000 and driven
// through the real fetch/decode/execute pipeline by `Run.runSteps(steps, state)`: the
// step budget makes the executed instruction count exact (the run always ends in a
// StepLimit trap — anything else means the workload is broken and the bench aborts).
//
// Modes:
//   swift run -c release riscv-bench            # local: ~1s per repetition, 5 reps
//   swift run -c release riscv-bench --ci       # CI:    ~0.25s per repetition, 3 reps,
//                                                #        hard 3-minute suite budget
//   --seconds <s>  target seconds per repetition (local tuning, any duration)
//   --reps <n>     repetitions per workload (median is reported)
//   --steps <n>    fixed instruction count per repetition (overrides calibration)

import Foundation
import RISCV

/// Write a diagnostic to standard error. The C global `stderr` is shared mutable
/// state that Swift 6 strict concurrency rejects on Linux/Glibc (it compiles only
/// because Darwin imports it differently); `FileHandle.standardError` is the
/// cross-platform, concurrency-safe path.
func printErr(_ message: String) {
    try? FileHandle.standardError.write(contentsOf: Data(message.utf8))
}

// ---------------------------------------------------------------------------
// Workloads
// ---------------------------------------------------------------------------

struct Workload {
    let name: String
    let arch: Architecture
    let archName: String
    /// Guest program as a 16-bit halfword stream loaded at 0x80000000
    /// (32-bit instructions contribute two halfwords, low first).
    let program: [UInt16]
    /// Pre-mapped data memory: (address, word value) pairs.
    let data: [(Int64, Int64)]
    /// Initial register values: (register, value) pairs.
    let regs: [(Int32, Int64)]

    init(_ name: String, _ arch: Architecture, _ archName: String, _ program: [UInt16], data: [(Int64, Int64)] = [], regs: [(Int32, Int64)] = []) {
        self.name = name
        self.arch = arch
        self.archName = archName
        self.program = program
        self.data = data
        self.regs = regs
    }
}

/// Splice a 32-bit instruction into the halfword stream (little-endian).
func w(_ instr: UInt32) -> [UInt16] {
    [UInt16(truncatingIfNeeded: instr), UInt16(truncatingIfNeeded: instr >> 16)]
}

// Instruction words below are cross-checked against the test-suite encodings.
let workloads: [Workload] = {
    // addi x1,x0,0 ; lui x2,0x1000 ; loop: addi x1,x1,1 ; blt x1,x2,loop
    let aluLoop = [0x0000_0093, 0x0100_0137, 0x0010_8093, 0xFE20_CEE3].flatMap(w)
    // jal x0,+4 ; jal x0,-4  (an endless 2-jump chase)
    let jumpLoop = [0x0040_006F, 0xFFDF_F06F].flatMap(w)
    // lui x2,0x1000 ; addi x1,x0,0 ; lui x3,0x10 ; loop: sw x1,0(x3) ; lw x4,0(x3) ;
    // addi x1,x1,1 ; blt x1,x2,loop          (x3 = 0x10000: arch-independent address)
    let memLoop = [0x0100_0137, 0x0000_0093, 0x0001_01B7, 0x0011_A023, 0x0001_A203, 0x0010_8093, 0xFE20_CAE3].flatMap(w)
    // lui x2,0x1000 ; addi x1,x0,0 ; loop: mul x4,x1,x2 ; divu x5,x2,x1 ; addi x1,x1,1 ; blt
    let mulDivLoop = [0x0100_0137, 0x0000_0093, 0x0220_8233, 0x0211_52B3, 0x0010_8093, 0xFE20_CAE3].flatMap(w)
    // lui x2,0x1000 ; addi x1,x0,0 ; loop: mulh x4,x1,x2 ; mulhu x5,x1,x2 ; addi ; blt
    // (exercises the 128-bit software high-multiply on RV64)
    let mulhLoop = [0x0100_0137, 0x0000_0093, 0x0220_9233, 0x0220_B2B3, 0x0010_8093, 0xFE20_CAE3].flatMap(w)
    // lui x2,0x1000 ; addi x1,x0,0 ; loop: mulw x4,x1,x2 ; divw x5,x2,x1 ; addi ; blt
    let mulwLoop = [0x0100_0137, 0x0000_0093, 0x0220_823B, 0x0211_42BB, 0x0010_8093, 0xFE20_CAE3].flatMap(w)
    // lui x1,0x10 ; addi x2,x0,1 ; loop: amoadd.w x3,x2,(x1) ; jal x0,-4
    let amoWLoop = [0x0001_00B7, 0x0010_0113, 0x0020_A1AF, 0xFFDF_F06F].flatMap(w)
    // lui x1,0x10 ; addi x2,x0,1 ; loop: amoadd.d x3,x2,(x1) ; jal x0,-4
    let amoDLoop = [0x0001_00B7, 0x0010_0113, 0x0020_B1AF, 0xFFDF_F06F].flatMap(w)
    // lui x1,0x10 ; addi x2,x0,1 ; loop: lr.w x3,(x1) ; sc.w x4,x2,(x1) ; jal x0,-8
    let lrScLoop = [0x0001_00B7, 0x0010_0113, 0x1000_A1AF, 0x1820_A22F, 0xFF9F_F06F].flatMap(w)

    // ---- compressed (C) programs: 16-bit halfwords directly ----
    // c.addi x8,1 ; c.j -2
    let cAluLoop: [UInt16] = [0x0405, 0xBFFD]
    // c.j +2 ; c.j -2  (an endless 2-jump chase, 16-bit)
    let cJumpLoop: [UInt16] = [0xA009, 0xBFFD]
    // c.swsp x8,0(sp) ; c.lwsp x9,0(sp) ; c.j -4    (sp preset to 0x10000)
    let cMemLoop: [UInt16] = [0xC022, 0x4482, 0xBFF5]
    // c.addi x8,1 (16-bit) ; addi x9,x9,1 (32-bit) ; c.j -6  — mixed-width stream
    let mixedLoop: [UInt16] = [0x0405] + w(0x0014_8493) + [0xBFED]

    let word: [(Int64, Int64)] = [(0x10000, 0)]
    let dword: [(Int64, Int64)] = [(0x10000, 0), (0x10004, 0)]

    return [
        Workload("I  alu (addi/blt)", .RV32i, "rv32i", aluLoop),
        Workload("I  alu (addi/blt)", .RV64i, "rv64i", aluLoop),
        Workload("I  jumps (jal)", .RV32i, "rv32i", jumpLoop),
        Workload("I  jumps (jal)", .RV64i, "rv64i", jumpLoop),
        Workload("I  memory (sw/lw)", .RV32i, "rv32i", memLoop),
        Workload("I  memory (sw/lw)", .RV64i, "rv64i", memLoop),
        Workload("M  mul/divu", .RV32im, "rv32im", mulDivLoop),
        Workload("M  mul/divu", .RV64im, "rv64im", mulDivLoop),
        Workload("M  mulh/mulhu (128-bit sw)", .RV64im, "rv64im", mulhLoop),
        Workload("M64 mulw/divw", .RV64im, "rv64im", mulwLoop),
        Workload("A  amoadd.w", .RV32ia, "rv32ia", amoWLoop, data: word),
        Workload("A  amoadd.w", .RV64ia, "rv64ia", amoWLoop, data: word),
        Workload("A64 amoadd.d", .RV64ia, "rv64ia", amoDLoop, data: dword),
        Workload("A  lr.w/sc.w", .RV64ia, "rv64ia", lrScLoop, data: word),
        Workload("C  alu (c.addi/c.j)", .RV32ic, "rv32ic", cAluLoop),
        Workload("C  alu (c.addi/c.j)", .RV64ic, "rv64ic", cAluLoop),
        Workload("C  jumps (c.j)", .RV32ic, "rv32ic", cJumpLoop),
        Workload("C  memory (c.swsp/c.lwsp)", .RV32ic, "rv32ic", cMemLoop, regs: [(2, 0x10000)]),
        Workload("C  mixed 16/32-bit stream", .RV32ic, "rv32ic", mixedLoop),
    ]
}()

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

func makeState(_ w: Workload) -> MachineState {
    var m = InitMachineState(.empty, w.arch, false).setRunState(.Run)
    for (i, half) in w.program.enumerated() {
        m = m.storeMemoryHalfWord(0x8000_0000 + Int64(i * 2), Int64(half))
    }
    for (addr, value) in w.data {
        m = m.storeMemoryWord(addr, value)
    }
    for (reg, value) in w.regs {
        m = m.setRegister(reg, value)
    }
    return m
}

/// Run exactly `steps` instructions; returns the wall-clock seconds.
/// Aborts the whole bench if the workload does not end in the StepLimit trap
/// (i.e. it crashed or halted early and the measurement would be meaningless).
func runOnce(_ w: Workload, steps: Int) -> Double {
    let m = makeState(w)
    let clock = ContinuousClock()
    var final: MachineState? = nil
    let elapsed = clock.measure {
        final = Run.runSteps(steps, m)
    }
    guard final?.RunState == .Trap(.StepLimit) else {
        FileHandle.standardError.write(Data("FATAL: workload '\(w.name)' [\(w.archName)] ended in \(String(describing: final?.RunState)) instead of StepLimit\n".utf8))
        exit(2)
    }
    return Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) * 1e-18
}

func median(_ xs: [Double]) -> Double {
    let s = xs.sorted()
    return s.count % 2 == 1 ? s[s.count / 2] : (s[s.count / 2 - 1] + s[s.count / 2]) / 2
}

struct Options {
    var secondsPerRep = 1.0
    var reps = 5
    var fixedSteps: Int? = nil
    var ci = false
    /// Hard wall-clock budget for the whole suite in CI mode (seconds).
    var ciBudget = 180.0
}

func parseOptions() -> Options {
    var o = Options()
    var it = CommandLine.arguments.dropFirst().makeIterator()
    while let arg = it.next() {
        switch arg {
        case "--ci":
            o.ci = true
            o.secondsPerRep = 0.25
            o.reps = 3
        case "--seconds":
            guard let v = it.next(), let s = Double(v), s > 0 else { printErr("--seconds needs a positive number\n"); exit(1) }
            o.secondsPerRep = s
        case "--reps":
            guard let v = it.next(), let r = Int(v), r > 0 else { printErr("--reps needs a positive integer\n"); exit(1) }
            o.reps = r
        case "--steps":
            guard let v = it.next(), let n = Int(v), n > 0 else { printErr("--steps needs a positive integer\n"); exit(1) }
            o.fixedSteps = n
        default:
            printErr("usage: riscv-bench [--ci] [--seconds s] [--reps n] [--steps n]\n")
            exit(1)
        }
    }
    return o
}

// ---------------------------------------------------------------------------
// Main
// ---------------------------------------------------------------------------

let options = parseOptions()
let suiteClock = ContinuousClock()
let suiteStart = suiteClock.now

print("riscv-bench — \(options.ci ? "CI" : "local") mode: \(options.reps) reps, target \(options.secondsPerRep)s/rep")
print(String(repeating: "-", count: 78))
print(padRightB("workload", 28) + padRightB("arch", 8) + padRightB("steps", 12) + padRightB("median", 10) + padRightB("best MIPS", 10) + "median MIPS")
print(String(repeating: "-", count: 78))

var totalInstructions = 0.0
var totalSeconds = 0.0

for w in workloads {
    // Calibrate: estimate throughput with a short run, then size the repetition
    // so it lasts ~secondsPerRep (clamped to keep CI deterministic and bounded).
    let steps: Int
    if let fixed = options.fixedSteps {
        steps = fixed
    } else {
        let calibrationSteps = 1_000_000
        let t = runOnce(w, steps: calibrationSteps)
        let mips = Double(calibrationSteps) / t
        steps = max(1_000_000, min(200_000_000, Int(mips * options.secondsPerRep)))
    }

    var times: [Double] = []
    for _ in 0 ..< options.reps {
        times.append(runOnce(w, steps: steps))
    }
    let med = median(times)
    let best = times.min()!
    totalInstructions += Double(steps) * Double(options.reps)
    totalSeconds += times.reduce(0, +)

    print(
        padRightB(w.name, 28) +
        padRightB(w.archName, 8) +
        padRightB("\(steps)", 12) +
        padRightB(String(format: "%.3fs", med), 10) +
        padRightB(String(format: "%.1f", Double(steps) / best / 1e6), 10) +
        String(format: "%.1f", Double(steps) / med / 1e6)
    )
}

let suiteElapsed = suiteClock.now - suiteStart
let suiteSeconds = Double(suiteElapsed.components.seconds) + Double(suiteElapsed.components.attoseconds) * 1e-18
print(String(repeating: "-", count: 78))
print(String(format: "TOTAL: %.0fM instructions in %.1fs wall (%.1f MIPS aggregate)",
             totalInstructions / 1e6, suiteSeconds, totalInstructions / totalSeconds / 1e6))

if options.ci && suiteSeconds > options.ciBudget {
    printErr(String(format: "FATAL: CI bench suite took %.1fs — over the %.0fs budget\n", suiteSeconds, options.ciBudget))
    exit(3)
}

/// Local right-pad (the library's padRight is internal to RISCV).
func padRightB(_ s: String, _ width: Int) -> String {
    s.count >= width ? s + " " : s + String(repeating: " ", count: width - s.count)
}
